# MT4Account · Streaming Methods — Overview

> Real-time server streams: **ticks**, **trade events**, **open-orders profit**, **ticket snapshots**, and **connect-state**. Each returns a `Subscription` handle; the SDK reads the stream on a background thread and calls your block for every payload.

Ticks / trades / profit / tickets live on `mt4_term_api.SubscriptionService`; connect-state on `mt4_term_api.Connection`. Each method yields its `*Data` payload to your block.

## 📁 What lives here

* **[OnSymbolTick](./OnSymbolTick.md)** — live **ticks** for one or more symbols (`OnSymbolMqlTickInfo`: bid, ask, time).
* **[OnTrade](./OnTrade.md)** — **trade events** when orders open / update / close (`OnTradeData`: new / updated / removed orders + account info).
* **[OnOpenedOrdersProfit](./OnOpenedOrdersProfit.md)** — open orders' **floating P/L** pushed on a timer (`OnOpenedOrdersProfitData`).
* **[OnOpenedOrdersTickets](./OnOpenedOrdersTickets.md)** — open **ticket snapshots** (positions + pendings) on a timer.
* **[OnConnectState](./OnConnectState.md)** — the terminal's **connection state** changes (`ConnectStateData`).

---

## 🧵 The Subscription contract

Every streaming method returns a `MetaRPC::MT4::Subscription`:

```ruby
sub = acct.on_symbol_tick("EURUSD") { |tick| puts "#{tick.bid}/#{tick.ask}" }
# … your program keeps running; the block fires on a background thread …
sub.cancel          # stop cleanly and wait (up to 5 s) for the reader thread
```

| Method | What it does |
|--------|--------------|
| `sub.cancel` | Cancel the stream and join the reader thread. |
| `sub.join(limit = nil)` | Block until the stream ends on its own (or `limit` seconds). |
| `sub.alive?` | Is the reader thread still running? |
| `sub.count` | How many payloads have been delivered. |
| `sub.error` | The exception that ended the stream, if any (not a clean `GRPC::Cancelled`). |

> **⚠️ Never call `sub.cancel` from inside the yielded block** — it would deadlock on its own reader thread. Set a flag and cancel from the main thread (or use a blocking helper like [`MT4Service#each_tick`](../../MT4Service/MT4Service.Overview.md)).

**No auto-reconnect.** If the stream drops, `sub.error` is set and the block stops — resubscribe yourself. Streams are **exempt from the per-call `timeout`** (they are long-lived).

---

## Quick choose

| If you need…                                | Use                         | Yields |
| ------------------------------------------- | --------------------------- | ------ |
| Live prices (event-driven)                  | `on_symbol_tick`            | `OnSymbolMqlTickInfo` |
| React when orders open/close                | `on_trade`                  | `OnTradeData` |
| Live floating P/L of open orders            | `on_opened_orders_profit`   | `OnOpenedOrdersProfitData` |
| Detect open/closed tickets cheaply          | `on_opened_orders_tickets`  | `OnOpenedOrdersTicketsData` |
| Watch the terminal's link health            | `on_connect_state`          | `ConnectStateData` |

---

## 🟢 Minimal pattern — run for N seconds

```ruby
got = 0
sub = acct.on_symbol_tick("EURUSD") { |_t| got += 1 }
sleep 5
sub.cancel
puts "received #{got} ticks (#{sub.count} total)"
```

Or the blocking convenience on the mid layer:

```ruby
n = sugar.service.each_tick("EURUSD", seconds: 5) { |t| puts "#{t.bid}/#{t.ask}" }
```

---

## See also

* **Poll instead of stream:** [Quote](../3.%20Symbols_Quotes/Quote.md) · [OpenedOrdersTickets](../2.%20Orders_History/OpenedOrdersTickets.md).
* **Friendly layer:** [`MT4Service#subscribe_ticks` / `#on_trade` / `#each_tick`](../../MT4Service/MT4Service.Overview.md).
* **Guide:** [gRPC Streaming](../../All_Guides/GRPC_STREAM_MANAGEMENT.md).

---

**Back to:** [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
