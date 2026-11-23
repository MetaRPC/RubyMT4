# MT4Account — Master Overview

> One page to **orient fast**: what lives where, how to choose the right API, and jump links to every **overview** and **method spec** in this docs set.

`MetaRPC::MT4::MT4Account` (from the `metarpc_mt4` gem) is the **low-level** layer — a thin, 1:1-with-the-wire client. Each method maps to a single gRPC RPC: you pass the plain arguments, it builds the generated protobuf `*Request`, sends it with the APIKey + terminal-id metadata, and returns the reply's `*Data` payload — or raises `MetaRPC::MT4::ApiError`. It owns the gRPC channel, the service stubs, the auth metadata and the connection lifecycle.

It exposes **26 feature methods across 5 groups** (plus the connection helpers in [Constructor & connection](#constructor-connection) below). Defined in `lib/metarpc_mt4/mt4_account.rb`.

```ruby
require "metarpc_mt4"
acct = MetaRPC::MT4::MT4Account.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
```

!!! note "When to use this layer"
    Use `MT4Account` when you need a field the friendly layers do not expose, or full control over the exact request. For everyday work prefer [`MT4Service`](../MT4Service/MT4Service.Overview.md) (plain args + typed Structs) or [`MT4Sugar`](../MT4Sugar/MT4Sugar.API_Overview.md) (one-liners).

---

## 🚦 Start here — Section Overviews

* **[1. Account Information](./1.%20Account_Information/Account_Information.Overview.md)**
  Account snapshot (balance / equity / margin / leverage) **and** trading statistics — aggregate stats, equity curve, unrealized-P/L extrema.

* **[2. Orders & History](./2.%20Orders_History/Orders_History.Overview.md)**
  Open orders (market + pending), their tickets, and closed-order history.

* **[3. Symbols & Quotes](./3.%20Symbols_Quotes/Symbols_Quotes.Overview.md)**
  Symbols, Market Watch, live quotes, full specs, tick value, OHLC bars and the server time zone.

* **[4. Trading Operations](./4.%20Trading_Operations/Trading_Operations.Overview.md)**
  Send, modify, close and close-by — the four order RPCs.

* **[5. Streaming Methods](./5.%20Streaming_Methods/Streaming_Methods.Overview.md)**
  Real-time streams: ticks, trade events, orders-profit, ticket snapshots, connect-state.

---

## 🧭 How to pick a method

| If you need…                        | Group                 | Typical methods                                                        |
| ----------------------------------- | --------------------- | --------------------------------------------------------------------- |
| Account snapshot                    | Account Information   | `account_summary`                                                     |
| Performance stats / equity curve    | Account Information   | `trade_stats`, `equity_history`, `trade_unrealized_pl`             |
| Open orders / tickets / history     | Orders & History      | `opened_orders`, `opened_orders_tickets`, `orders_history`           |
| Live quotes / symbol specs          | Symbols & Quotes      | `quote`, `quote_many`, `symbol_params_many`, `symbol_select`         |
| OHLC bars / server time zone        | Symbols & Quotes      | `bars`, `quote_history`, `server_timezone`                          |
| Place / modify / close an order     | Trading Operations    | `order_send`, `order_modify`, `order_close_delete`, `order_close_by` |
| Real-time updates                   | Streaming Methods     | `on_symbol_tick`, `on_trade`, `on_connect_state`                    |

---

## 🔌 Usage pattern (raw gRPC)

Every method is called on an `MT4Account`. It owns the gRPC channel, sends the terminal id and API key as metadata, and unwraps the reply — returning the protobuf `*Data` payload or **raising** an error.

```ruby
require "metarpc_mt4"

# Create the client (prepares the gRPC channel; api_key from MRPC_API_KEY)
acct = MetaRPC::MT4::MT4Account.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])

# Connect the terminal (ConnectEx by broker server name).
# The gateway returns a terminal session GUID; later calls reuse it automatically.
acct.connect(1235959737, "password", server: "EGlobal-Demo")

# Call a method: returns the *Data payload, or raises ApiError / a gRPC error.
s = acct.account_summary
puts "Balance: #{s.account_balance} #{s.account_currency}"
```

Every method follows the same shape:

* **Proto Service/Method:** `Service.Method(Request) → Reply`
* **Client call:** `acct.method(args)` returns the `*Data` payload.
* **Reply structure:** the reply carries either a `data` payload or an `error`; `MT4Account` returns the `data` and turns `error` into a raised **`ApiError`**.
* **Errors are exceptions** — there are no error return values; wrap calls in `begin/rescue`.

**Field access:** the generated protobuf messages expose **snake_case** readers — `s.account_balance`, not `getAccountBalance()`. A few symbol-spec messages use **PascalCase** accessors (`p.Digits`, `p.VolumeMin`); the friendly `MT4Service` layer normalizes these into plain Ruby Structs for you.

**Timestamps:** proto uses `google.protobuf.Timestamp` (read `.seconds`) on some messages and raw unix seconds on others (bars). `MT4Service` returns numbers / UTC instead.

**Streaming methods:** return a `Subscription` handle. The SDK reads the stream on a background thread and invokes your block for each payload; call `subscription.cancel` to stop.

---

## 🔐 Constructor & connection

The connection helpers are **not** separate method pages — they are the session plumbing every other call builds on. Create the client, then connect:

```ruby
acct = MetaRPC::MT4::MT4Account.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"], id: stable_uuid)

# Connect by broker server (cluster) name — ConnectEx:
acct.connect(1235959737, "password", server: "EGlobal-Demo", name: "my-bot")
```

| Helper | What it does |
|--------|--------------|
| `connect(login, password, server:, name:, …)` | Connect by broker **server name** (ConnectEx). Aliases: `connect_ex`, `connect_by_server_name`. Raises `InvalidLoginError` on bad credentials. |
| `connect_by_host(login, password, host:, port:, …)` | Connect by the broker trade server's raw **host:port** (Connect). |
| `connect_proxy(login, password, host:, port:, proxy_host:, proxy_port:, proxy_type:, …)` | Connect through a SOCKS/HTTP **proxy**. |
| `get_id(login, password)` | Resolve the terminal session **id** without connecting (GetId). |
| `check_connect` / `connect_state` / `connection_status` | **Health checks** — is the terminal still attached / its current state. |
| `reconnect(force:)` | Re-establish the broker connection with the stored parameters. |
| `disconnect(delete:, reason:)` | Stop the terminal (`delete: true` removes it from the account list). |
| `accounts(include_stopped:, page_size:)` | List the **terminals** owned by this API key (auto-paged). |
| `close` | Release the local gRPC channels (does **not** stop the terminal on the gateway). |

> **`connect_proxy` enum — `ProxyTypes` (4):** `:None` (0) · `:Https` (1) · `:Socks4` (2) · `:Socks5` (3). Pass one as `proxy_type:`.

Pass a **stable `id:`** per strategy so re-runs reuse one terminal instead of orphaning a new one. The gateway returns a session GUID on connect; the SDK attaches it (+ your api key) to every later call and stream automatically — you never pass it yourself. See [Getting Started](../All_Guides/GETTING_STARTED.md).

---

## 📚 Full index · all method specs

### 1 · Account Information · [Overview](./1.%20Account_Information/Account_Information.Overview.md)
* [AccountSummary](./1.%20Account_Information/AccountSummary.md) — all account data in one call.
* [TradeStats](./1.%20Account_Information/TradeStats.md) · [TradeStatsEquityHistory](./1.%20Account_Information/TradeStatsEquityHistory.md)
* [EquityHistory](./1.%20Account_Information/EquityHistory.md) · [TradeUnrealizedPL](./1.%20Account_Information/TradeUnrealizedPL.md)

### 2 · Orders & History · [Overview](./2.%20Orders_History/Orders_History.Overview.md)
* [OpenedOrders](./2.%20Orders_History/OpenedOrders.md) · [OpenedOrdersTickets](./2.%20Orders_History/OpenedOrdersTickets.md) · [OrdersHistory](./2.%20Orders_History/OrdersHistory.md)

### 3 · Symbols & Quotes · [Overview](./3.%20Symbols_Quotes/Symbols_Quotes.Overview.md)
* [Symbols](./3.%20Symbols_Quotes/Symbols.md) · [SymbolSelect](./3.%20Symbols_Quotes/SymbolSelect.md) · [Quote](./3.%20Symbols_Quotes/Quote.md) · [QuoteMany](./3.%20Symbols_Quotes/QuoteMany.md)
* [SymbolParamsMany](./3.%20Symbols_Quotes/SymbolParamsMany.md) · [TickValueWithSize](./3.%20Symbols_Quotes/TickValueWithSize.md)
* [Bars](./3.%20Symbols_Quotes/Bars.md) · [QuoteHistory](./3.%20Symbols_Quotes/QuoteHistory.md) · [ServerTimezone](./3.%20Symbols_Quotes/ServerTimezone.md)

### 4 · Trading Operations · [Overview](./4.%20Trading_Operations/Trading_Operations.Overview.md)
* [OrderSend](./4.%20Trading_Operations/OrderSend.md) · [OrderModify](./4.%20Trading_Operations/OrderModify.md)
* [OrderCloseDelete](./4.%20Trading_Operations/OrderCloseDelete.md) · [OrderCloseBy](./4.%20Trading_Operations/OrderCloseBy.md)

### 5 · Streaming Methods · [Overview](./5.%20Streaming_Methods/Streaming_Methods.Overview.md)
* [OnSymbolTick](./5.%20Streaming_Methods/OnSymbolTick.md) · [OnTrade](./5.%20Streaming_Methods/OnTrade.md)
* [OnOpenedOrdersProfit](./5.%20Streaming_Methods/OnOpenedOrdersProfit.md) · [OnOpenedOrdersTickets](./5.%20Streaming_Methods/OnOpenedOrdersTickets.md) · [OnConnectState](./5.%20Streaming_Methods/OnConnectState.md)

---

## 🏗️ API Architecture

### Layer 1: MT4Account (Low-Level) — You are here!

**What:** direct protobuf/gRPC communication with the MT4 terminal. Plain arguments in, protobuf `*Data` out; complete access to every MT4 function; highest control. **Location:** `lib/metarpc_mt4/mt4_account.rb`.

### Layer 2: MT4Service

**What:** a friendly facade over `MT4Account` — plain arguments and typed Ruby Structs (`Account`, `Quote`, `SymbolSpec`…). No protobuf. **Location:** `lib/metarpc_mt4/mt4_service.rb` → [overview](../MT4Service/MT4Service.Overview.md).

### Layer 3: MT4Sugar

**What:** high-level convenience API — one-liners, risk-based position sizing, smart defaults. **Location:** `lib/metarpc_mt4/mt4_sugar.rb` → [overview](../MT4Sugar/MT4Sugar.API_Overview.md).

Each layer **owns** the one below it: `MT4Sugar` owns an `MT4Service`, which owns an `MT4Account`. From Sugar you can always reach down with `sugar.service` and `sugar.account`. (`MetaRPC::MT4::Client` aliases `MT4Sugar`; `MetaRPC::MT4::Account` aliases `MT4Account`.)

---

## 💡 Key concepts

* **Errors are exceptions.** A server-side rejection raises `MetaRPC::MT4::ApiError` (carrying the `mql` error code); a transport failure raises the gRPC error. There are no error return values.
* **Session id is automatic.** `connect` (ConnectEx) obtains a terminal session GUID; the SDK attaches it (+ your api key) to every later call and stream. Pass a **stable `id:`** per strategy so the gateway reuses one terminal.
* **MT4 has ORDERS, not positions.** An open **market order IS the position**; its `ticket` is what you modify / close. Pending orders live in the same list, told apart by `order_type` (`OO_OP_BUY/SELL` = market, the `...LIMIT/STOP` variants = pending). There are no separate "deals".
* **No trade retcode.** Unlike MT5, MT4 has no `returned_code`: `order_send` returns `OrderSendData` with a **`ticket > 0` when the order is filled**; a rejection **raises** `ApiError` (read `e.mql_code`: 130 invalid stops, 132 market closed, 134 not enough money, 138 requote). See [Return Codes](../All_Guides/RETURN_CODES_REFERENCE.md).

---

"Trade safe, code clean, and may your gRPC streams always flow smoothly."
