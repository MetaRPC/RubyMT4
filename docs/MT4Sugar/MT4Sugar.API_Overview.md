# MT4Sugar — High-Level API Overview

> One-line helpers for everyday trading: connect, read balances, quote, buy/sell, manage orders, size risk, stream. The friendliest layer — built on **[MT4Service](../MT4Service/MT4Service.Overview.md)**, which is built on **[MT4Account](../MT4Account/MT4Account.Master.Overview.md)**.

**🧩 API Layer:** **HIGH-LEVEL** — maximum convenience, minimum boilerplate.

---

## 🧱 One call builds the whole stack

```ruby
require "metarpc_mt4"

mt4 = MetaRPC::MT4::MT4Sugar.create("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
mt4.connect(1235959737, "password", server: "EGlobal-Demo")

r = mt4.buy_market("EURUSD", 0.10)
mt4.modify_sl_tp(r.ticket, stop_loss: 1.0850, take_profit: 1.1000)
puts "balance #{mt4.balance.round(2)}"
```

* `MT4Sugar.create(host = "mt4.mrpc.pro", port = 443, **opts)` → builds `MT4Sugar → MT4Service → MT4Account` (`opts`: `api_key:`, `id:`, `timeout:`).
* `mt4.service` → the mid layer · `mt4.account` → the low layer. Drop down any time.
* `MetaRPC::MT4::Client` aliases `MT4Sugar` — a drop-in friendly entry point.

---

## 🛑 How errors surface

MT4 has **no trade retcode**. Trading one-liners (`buy_market`, `close_order`, …) return the result `*Data`; a filled order has a **`ticket > 0`**:

```ruby
r = mt4.buy_market("EURUSD", 0.10)
puts r.ticket.positive? ? "✅ ##{r.ticket}" : "❌ not filled"
```

A **rejection raises** `MetaRPC::MT4::ApiError` — read `e.mql_code` (130 invalid stops · 132 market closed · 134 no money · 138 requote). A transport failure after the request may have reached the terminal raises a `TradeOutcomeUnknown`-marked error — **don't blindly retry a trade**. Read helpers (`balance`, `bid`, `connected?`) return plain values.

---

## 📁 Method groups

| # | Group | What's inside |
| - | ----- | ------------- |
| 1 | **[Connection](./1.%20Connection.md)** | `connect` · `connect_by_host` · `connect_proxy` · `quick_connect` · `get_id` · `connected?` · `reconnect` · `disconnect` · `check_connect` · `connect_state` · `connection_status` |
| 2 | **[Money & Account](./2.%20Money_Account.md)** | `balance` · `equity` · `margin` · `free_margin` · `margin_level` · `credit` · `profit` · `account_info` · `account_summary` · `demo?` · `accounts` · `server_timezone` |
| 3 | **[Prices & Quotes](./3.%20Prices_Quotes.md)** | `bid` · `ask` · `spread` · `price` · `quotes` |
| 4 | **[Simple Trading](./4.%20Simple_Trading.md)** | `buy_market`/`sell_market` (`buy`/`sell`) · `buy_limit`/`sell_limit` · `buy_stop`/`sell_stop` |
| 5 | **[Trading with SL/TP](./5.%20Trading_SLTP.md)** | `buy_market_with_sl_tp` · `sell_market_with_sl_tp` · raw `order_send`/`order_modify`/`order_close` |
| 6 | **[Order Management](./6.%20Order_Management.md)** | `close_order` · `close_all` · `close_all_by_symbol` · `cancel_order` · `cancel_all_pending` · `close_by` · `modify_sl` · `modify_tp` · `modify_sl_tp` |
| 7 | **[Order Information](./7.%20Order_Information.md)** | `open_orders` · `pending` · `order` · `orders_by_symbol` · `has_order?` · `count_orders` · `total_profit` · `profit_by_symbol` · `open_tickets` |
| 8 | **[History & Statistics](./8.%20History_Statistics.md)** | `order_history` · `trade_stats` · `trade_stats_equity_history` · `equity_history` · `trade_unrealized_pl` |
| 9 | **[Symbol Information](./9.%20Symbol_Information.md)** | `symbol_info` · `all_symbols` · `symbol_available?` · `select_symbol` · `symbol_digits` · `symbol_point` · `min_stop_level` · `bars` · `last_bars` · `tick_value_with_size` · `all_symbol_specs` |
| 10 | **[Risk Management](./10.%20Risk_Management.md)** | `required_margin` · `max_lot` · `pip_value` |
| 11 | **[Streaming](./11.%20Streaming.md)** | `subscribe_ticks` · `on_trade` · `on_opened_orders_profit` · `on_tickets` · `on_connect_state` · `each_tick` |

---

## 🧮 Pips on MT4

Pip size = `point × (digits == 3 || digits == 5 ? 10 : 1)`. So on 5-digit EURUSD one pip = `0.0001`, on 3-digit JPY pairs one pip = `0.01`. Read `point` / `digits` with [`symbol_point`](./9.%20Symbol_Information.md) / [`symbol_digits`](./9.%20Symbol_Information.md).

> **Risk helpers are estimates.** MT4 has no server-side margin/profit calc RPC, so `required_margin` / `max_lot` / `pip_value` are computed **locally** from the symbol spec + account leverage — treat them as approximations, not broker-exact figures.

---

## 📚 See also

* **Down:** [MT4Service — Overview](../MT4Service/MT4Service.Overview.md) · [MT4Account — Master Overview](../MT4Account/MT4Account.Master.Overview.md).
* **Reference:** [Return Codes](../All_Guides/RETURN_CODES_REFERENCE.md) · [Sync vs Async](../All_Guides/SYNC_VS_ASYNC.md).
