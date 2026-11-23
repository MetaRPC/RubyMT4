# Glossary

> The MT4, trading and SDK terms you'll meet in these docs, grouped by kind.

---

## 🏗️ Architectural terms

**Three-layer architecture** — the SDK is three decoupled layers, each owning the one below (`sugar.service` → `MT4Service`, `service.account` → `MT4Account`). See the [Project Map](./PROJECT_MAP.md).

**MT4Account** — the low-level layer. Raw gRPC: you pass protobuf `*Request` messages and read `*Reply` / `*Data` replies via their snake_case accessors. Owns the channel, the gRPC stubs, auth metadata, reconnect and streaming. → [overview](../MT4Account/MT4Account.Master.Overview.md)

**MT4Service** — the mid layer. Same calls, but it builds the protobuf from plain arguments and returns typed Ruby `Struct`s (`Account`, `Quote`, `SymbolSpec`). → [overview](../MT4Service/MT4Service.Overview.md)

**MT4Sugar** — the high layer. One-line helpers (`buy_market`, `close_all`) with smart defaults; trade helpers return the result data (a filled order has `ticket > 0`). → [overview](../MT4Sugar/MT4Sugar.API_Overview.md)

**Struct (DTO)** — the plain Ruby `Struct` objects `MT4Service` returns instead of protobuf (`Account`, `Quote`, `SymbolSpec`), with read-only attribute methods.

**ApiError** — the error raised when the gateway or terminal reports a problem (`MetaRPC::MT4::ApiError`). `InvalidLoginError` flags never-retry auth failures; `TradeOutcomeUnknown` marks a trade whose result is uncertain after a transport failure. See [Return Codes → the error model](./RETURN_CODES_REFERENCE.md).

**Subscription** — what a streaming method returns (`MetaRPC::MT4::Subscription`): call `cancel` to stop the stream; `count` / `error` report its state.

**Client / Account aliases** — `MetaRPC::MT4::Client` aliases `MT4Sugar`; `MetaRPC::MT4::Account` aliases `MT4Account`.

---

## 💎 Ruby-specific concepts

**Blocks for streams** — a streaming method yields each payload to the block you pass, and returns a `Subscription` to stop it.

```ruby
sub = mt4.on_symbol_tick("EURUSD") { |t| puts "#{t.bid} / #{t.ask}" }
# later:
sub.cancel
```

**Keyword arguments** — optional parameters are passed by name, not position.

```ruby
mt4.connect(1235959737, "password", server: "EGlobal-Demo")
mt4.buy_market_with_sl_tp("EURUSD", 0.01, sl: 1.0820, tp: 1.0920, comment: "demo")
```

**Enums as symbols** — protobuf enums are Ruby symbols, both in and out (`:ACCOUNT_TRADE_MODE_DEMO`, `:OO_OP_BUY`, `:OC_OP_BUY`). See the [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md).

```ruby
o = mt4.open_orders.first
o.order_type           # => :OO_OP_BUY   (a symbol)
```

**Typed Structs vs protobuf stubs** — the low layer returns generated protobuf objects (snake_case accessors like `o.order_type`, `o.profit`); the mid/high layers unwrap or filter them for you. Discover real field names with the [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md).

```ruby
d  = mt4.account.opened_orders   # low: [OpenedOrderInfo] protobuf (market + pending)
ps = mt4.service.positions       # mid: only the market orders (positions), filtered
```

**Error handling — `begin / rescue`** — wrap calls that can fail; rescue `MetaRPC::MT4::ApiError` (or its subclasses).

```ruby
begin
  mt4.buy_market("EURUSD", 0.01)
rescue MetaRPC::MT4::ApiError => e
  warn "trade failed: #{e.code} (mql #{e.mql_code})"
end
```

**Connection & cleanup** — `connect` / `quick_connect` opens the terminal session; `disconnect` closes it and (with `delete: true`) **frees the terminal** (a trial allows one per IP). Use `ensure`.

```ruby
begin
  # …
ensure
  mt4.disconnect
end
```

---

## 🎓 Trading terms

### Account

**Balance** — closed-trade money; excludes floating P/L. **Equity** — balance + credit + floating P/L; moves with open orders. **Margin** — funds locked to hold orders. **Free margin** — equity − margin; available to open more. **Margin level** — equity / margin × 100 (%); low levels risk a **stop-out**. **Leverage** — the multiplier (1:100) setting margin need. **Trade mode** — `DEMO`, `CONTEST` or `REAL`.

### Instruments & prices

**Symbol** — a tradable instrument (`EURUSD`, `XAUUSD`). **Bid / Ask** — sell / buy price; **spread** = ask − bid. **Digits** — decimal places (5 for EURUSD, 3 for JPY). **Tick** — one price update (`quote` / `on_symbol_tick`). MT4 quotes carry bid/ask/high/low (no `last`).

### Orders (the MT4 model)

> **MT4 has orders, not positions.** An open **market order IS the position** — there is no separate position object, and **no "deals"** list.

**Order** — an instruction to trade. **Market** fills now (`:buy` / `:sell`); **pending** (`:buy_limit` / `:sell_limit` / `:buy_stop` / `:sell_stop`) waits for a price. **Ticket** — the numeric id you modify / close; `order_send` returns it (**`ticket > 0` = filled**). **Order type** — two enums by context: `OrderSendOperationType` `OC_OP_*` (when *sending*), and `OpenedOrderType` `OO_OP_*` (when *reading* the open book; `OO_OP_BUY/SELL` are market = positions, the `...LIMIT/STOP` are pending, `OO_OP_BALANCE/CREDIT` are ledger rows). **SL / TP** — stop-loss / take-profit auto-close levels. **Magic number** — a client id tagging a strategy's orders. **No retcode** — unlike MT5, MT4 has no `returned_code`; a rejection **raises** `ApiError` with an `mql_code`. See [Return Codes](./RETURN_CODES_REFERENCE.md).

---

## 📦 Technical concepts

**Point** — the smallest price increment (`0.00001` on 5-digit EURUSD). **Pip** — the conventional move unit; on a 3- or 5-digit symbol `pip = point × 10`, so one pip on EURUSD = `0.0001`. **Tick value / tick size** — the money value of one tick, and the price change one tick represents — inputs for P&L and sizing ([`tick_value_with_size`](../MT4Account/3.%20Symbols_Quotes/TickValueWithSize.md)).

**Lot / volume** — trade size in lots (`0.01` = micro). Must obey **volume limits** (`volume_min` / `volume_max` / `volume_step`). **Contract size** — units of the base instrument per 1.0 lot.

**Risk-based sizing** — picking the lot so a stop of N pips loses a fixed amount. MT4 has **no server-side calc RPC**, so the SDK estimates locally: [`pip_value`](../MT4Sugar/10.%20Risk_Management.md), `required_margin` and `max_lot`. **Risk amount** = `balance × risk_percent / 100`. **Required margin** — margin a prospective order needs (leverage-based estimate). **Drawdown** — the drop from a peak to current equity, %.

**Stops level** (`TradeStopsLevel`) — minimum distance, in points, SL/TP may sit from the market; closer → `mql_code 130` (invalid stops).

**Trailing stop** — a stop that ratchets in your favour, never back ([orchestrator](../Strategies/Orchestrators/TrailingStop.md)). **Breakeven** — moving the stop to entry once in profit. **Hedging** — holding BUY and SELL on one symbol at once. **Grid trading** — bracketing price with pending orders ([orchestrator](../Strategies/Orchestrators/GridTrader.md)). **Scalping** — many small short-lived trades. **Kill-switch** — close everything on a drawdown/margin breach ([risk manager](../Strategies/Orchestrators/RiskManager.md)).

---

## 🔌 gRPC & protocol terms

**gRPC** — the RPC protocol the SDK speaks to `mt4.mrpc.pro:443` (HTTP/2 + protobuf over TLS).

**Protobuf** — the binary message format. On the low layer you build `*Request` messages and read `*Reply` replies via snake_case accessors; `MT4Service` hides this behind typed Structs. The generated stubs live in `package/`.

**Streaming pattern** — a server stream delivered via a block: a streaming method yields each payload and returns a `Subscription`. See [gRPC Stream Management](./GRPC_STREAM_MANAGEMENT.md).

**Gateway** — the MetaRPC service (`mt4.mrpc.pro`) bridging the SDK to MT4 terminals and managing sessions. **Terminal** — the MT4 instance your account runs on behind the gateway. **Session / terminal instance guid** — the id obtained on `connect` (ConnectEx), attached with your API key to every later call automatically (on `mt4.account.server_guid`). **API key** — your MetaRPC key; pass it to `MT4Sugar.create(...)`, or use `"TRIAL"`.

---

## See also

* [Project Map](./PROJECT_MAP.md) · [MT4 for Beginners](./MT4_For_Beginners.md) · [Getting Started](./GETTING_STARTED.md) · [Return Codes](./RETURN_CODES_REFERENCE.md) · [SDK Ecosystem](./SDK_Ecosystem.md)
