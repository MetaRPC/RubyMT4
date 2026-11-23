# MT4Service — Mid-Level API Overview

> A convenient wrapper over **[MT4Account](../MT4Account/MT4Account.Master.Overview.md)** that returns **plain Ruby objects (Structs) and plain arguments** instead of protobuf messages.

**🧩 API Layer:** **MID-LEVEL** — the balance between low-level ([MT4Account](../MT4Account/MT4Account.Master.Overview.md)) and high-level ([MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md)).

---

## ⚠️ Same calls, cleaner results

MT4Service and MT4Account make the **same gRPC calls** — the difference is the **return shape**, not the logic.

```ruby
# Low-level (MT4Account) — you read the protobuf quote:
t = account.quote("EURUSD")
spread = t.ask - t.bid

# Mid-level (MT4Service) — you get a tidy Quote struct:
q = service.quote("EURUSD")       # Quote(symbol, bid, ask, high, low, spread, time_utc)
spread = q.spread
```

**What the mid layer does for you**

* ✅ Builds the protobuf `*Request` from plain arguments.
* ✅ Returns typed Ruby **Structs** where they add value — `Account`, `Quote`, `SymbolSpec`.
* ✅ Auto-pages history reads and hands back ready arrays.
* ✅ Splits open orders into **positions** (market) and **pending** — `positions(magic:, symbol:)` / `pending_orders(...)`.
* ✅ Keeps the raw protobuf `*Data` where the full shape matters (orders, stats) — one hop from the low layer.

Both layers are equally valid — pick the altitude you prefer. For one-liners, go up again to [MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md).

---

## 🏗️ Architecture layers

```
┌─────────────────────────────────────────────┐
│  MT4Sugar      one-liners, risk-based sizing│  ← highest
├─────────────────────────────────────────────┤
│  MT4Service    plain args → typed structs   │  ← YOU ARE HERE
├─────────────────────────────────────────────┤
│  MT4Account    raw protobuf / gRPC          │  ← lowest
└─────────────────────────────────────────────┘
```

Each layer **owns** the one below it: `MT4Sugar` owns an `MT4Service`, which owns an `MT4Account`. From here you can always drop down with `service.account`.

---

## 🧱 Construction & lifecycle

```ruby
require "metarpc_mt4"

# Build a fresh MT4Account underneath, or wrap one you already have:
service = MetaRPC::MT4::MT4Service.new(api_key: ENV["MRPC_API_KEY"])
# service = MetaRPC::MT4::MT4Service.new(existing_account)

service.connect(1235959737, "password", server: "EGlobal-Demo")

a = service.account_info            # Account struct
puts "#{a.login}  #{a.balance} #{a.currency}  1:#{a.leverage}"

service.disconnect
```

* `MT4Service.new(account = nil, **opts)` → wraps `account`, or builds a fresh `MT4Account` from `**opts` (`api_key:`, `id:`, `host`, `port`, `timeout:`).
* `service.account` → the underlying `MT4Account` (drop down a layer any time).

### Connection & session helpers (delegated to `MT4Account`)

| Method | What it does |
|--------|--------------|
| `connect(login, password, server:, **opts)` | Connect by broker **server name** (ConnectEx). |
| `connect_by_host(login, password, host:, port:, **opts)` | Connect by raw **host:port**. |
| `connect_proxy(login, password, **opts)` | Connect through a **proxy**. |
| `get_id(login, password)` | Resolve the terminal session **id** (GetId). |
| `connected?` | Local connected flag. |
| `check_connect` / `connect_state` / `connection_status` | **Health checks**. |
| `reconnect(force:)` | Re-establish the broker connection. |
| `disconnect(delete:, reason:)` | Stop the terminal (`delete: true` removes it). |
| `close` | Release local gRPC channels. |

> **Tuning timeouts.** Unary reads use the underlying `account.timeout` (seconds, default `60`); set `service.account.timeout = 30` to change it.

---

## 📁 Method groups (feature methods)

| # | Group | Methods |
| - | ----- | ------- |
| 1 | **[Account & Stats](./1.%20Account_Information.md)** (9) | `account_info` · `account_summary` · `demo?` · `accounts` · `server_timezone` · `trade_stats` · `trade_stats_equity_history` · `equity_history` · `trade_unrealized_pl` |
| 2 | **[Orders & History](./2.%20Orders_History.md)** (5) | `opened_orders` · `opened_tickets` · `positions` · `pending_orders` · `order_history` |
| 3 | **[Symbols & Quotes](./3.%20Symbols_Quotes.md)** (12) | `quote` · `quote_many` · `tick` · `symbols` · `symbol_exist?` · `select_symbol` · `symbol_params` · `symbol_params_all` · `tick_value_with_size` · `bars` · `last_bars` · `quote_history` |
| 4 | **[Trading Operations](./4.%20Trading_Operations.md)** (6) | `order_send` · `buy` · `sell` · `order_modify` · `order_close` · `order_close_by` |
| 5 | **[Streaming Methods](./5.%20Streaming_Methods.md)** (6) | `subscribe_ticks` · `on_trade` · `on_opened_orders_profit` · `on_tickets` · `on_connect_state` · `each_tick` |

---

## 🧾 The typed objects (Structs)

`MT4Service` returns three `Struct`s; everything else is the raw protobuf `*Data` (one hop from [MT4Account](../MT4Account/MT4Account.Master.Overview.md)).

| Struct | From | Fields |
| --- | ---- | ------ |
| **`Account`** | `account_info` | `login, balance, equity, currency, leverage, trade_mode, company, server_time_utc` |
| **`Quote`** | `quote`, `quote_many` | `symbol, bid, ask, high, low, spread, time_utc` |
| **`SymbolSpec`** | `symbol_params`, `symbol_params_all` | `name, digits, point, contract_size, volume_min/max/step, stops_level, freeze_level, tick_size, tick_value, trade_mode, exe_mode, calc_mode, currency_base/profit/margin, swap_long/short, description, path, selected, bid, time_utc, raw` |

Raw protobuf still comes back from: `opened_orders` / `positions` / `pending_orders` (`OpenedOrderInfo`), `order_send` (`OrderSendData`), `tick` (`QuoteData`), `bars` (`QuoteHistoryBar[]`), the stats methods (`StatsData` / `EquityPointData[]`), `order_history` (`HistoryOrderInfo[]`).

---

## 💡 Usage examples

### 1) Account snapshot

```ruby
a = service.account_info
puts "##{a.login} · #{a.balance} #{a.currency} · 1:#{a.leverage}"
```

### 2) Current price

```ruby
q = service.quote("EURUSD")
puts "Bid #{q.bid}, Ask #{q.ask}, Spread #{q.spread.round(5)}"
```

### 3) Place an order (MT4: ticket > 0 = filled)

```ruby
r = service.order_send(symbol: "EURUSD", type: :buy, volume: 0.1, stop_loss: 1.08, take_profit: 1.09)
puts r.ticket.positive? ? "✅ order ##{r.ticket}" : "❌ not filled"
```

### 4) Live price + floating P&L

```ruby
t = service.subscribe_ticks("EURUSD") { |q| puts "tick #{q.bid} #{q.ask}" }
p = service.on_opened_orders_profit { |d| puts "floating: #{d.opened_orders_with_profit_updated.sum(&:order_profit).round(2)}" }
# later: t.cancel; p.cancel
```

---

## 📊 Low-level vs mid-level

| Aspect | MT4Account (low) | MT4Service (mid) |
| ------ | ---------------- | ---------------- |
| Arguments | plain args, builds `*Request` | plain args |
| Return | protobuf `*Data` | `Struct` (where it helps) or `*Data` |
| Quotes | `quote` → `QuoteData` | `quote` → `Quote(bid, ask, spread, …)` |
| Account | `account_summary` → `*Data` | `account_info` → `Account` struct |
| Specs | `symbol_params_many` → PascalCase | `symbol_params` → `SymbolSpec` (snake_case) |
| Orders | one list, filter by `order_type` | `positions` / `pending_orders` split for you |
| History | manual paging | auto-paged arrays |
| Best for | every field, full control | everyday app code |

---

## 🔧 Best practices

1. **Handle errors with `begin/rescue`.** Every method raises on failure — a server rejection raises `MetaRPC::MT4::ApiError` (carrying the `mql` code), a transport failure raises the gRPC error.

   ```ruby
   begin
     a = service.account_info
   rescue MetaRPC::MT4::ApiError => e
     warn "failed: #{e.message}"
   end
   ```

2. **MT4 has no trade retcode.** `order_send` returns `OrderSendData` with a **`ticket > 0` when filled**; a rejection **raises** (`e.mql_code`: 130/132/134…). A transport failure after the request may have reached the terminal is raised as a `TradeOutcomeUnknown`-marked error — do not blindly retry.

3. **Tune the timeout** via `service.account.timeout` (seconds) for slow links or heavy history pulls.

4. **Always `cancel`** streaming subscriptions when done — they run on a background thread and don't stop on their own.

5. **Free the terminal** with `service.disconnect(delete: true)` at the end of a one-shot run (a trial allows one terminal per IP).

---

## 📚 Related

- **Down:** [MT4Account — Master Overview](../MT4Account/MT4Account.Master.Overview.md) — raw protobuf, full control.
- **Up:** [MT4Sugar — API Overview](../MT4Sugar/MT4Sugar.API_Overview.md) — one-line helpers.
- **Groups:** [Account & Stats](./1.%20Account_Information.md) · [Orders & History](./2.%20Orders_History.md) · [Symbols & Quotes](./3.%20Symbols_Quotes.md) · [Trading](./4.%20Trading_Operations.md) · [Streaming](./5.%20Streaming_Methods.md).
- **Reference:** [Return Codes](../All_Guides/RETURN_CODES_REFERENCE.md) · [Sync vs Async](../All_Guides/SYNC_VS_ASYNC.md).

---

## 🎯 Summary

MT4Service is the everyday layer: the **same gRPC calls** as MT4Account, but plain arguments in and tidy Ruby objects out — typed `Account` / `Quote` / `SymbolSpec` Structs, auto-paged history, positions split from pendings, no manual request building. Drop to MT4Account for full control, go up to MT4Sugar for one-liners.
