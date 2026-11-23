# MT4Account · Trading Operations — Overview

> The four order RPCs: **send** a market or pending order, **modify** its SL/TP/price, **close or delete** it, and **close one order by an opposite** one.

All four live on `mt4_term_api.TradingHelper`. Each returns the raw `*Data`, or **raises** `ApiError` on rejection. These are the only methods that place or change orders.

## 📁 What lives here

* **[OrderSend](./OrderSend.md)** — open a **market or pending** order (`OrderSendData`: `ticket`, `price`, `volume`).
* **[OrderModify](./OrderModify.md)** — change **SL / TP** (market) or **price / SL / TP / expiration** (pending) → `OrderModifyData`.
* **[OrderCloseDelete](./OrderCloseDelete.md)** — **close** a market order (full / partial) or **delete** a pending one → `OrderCloseDeleteData`.
* **[OrderCloseBy](./OrderCloseBy.md)** — **close one market order by an opposite** one on the same symbol → `OrderCloseByData`.

---

## ⚠️ MT4 trade contract — read this first

* **No retcode.** Unlike MT5 there is **no `returned_code`**. `order_send` returns `OrderSendData` with a **`ticket > 0` when filled**. A rejection **raises** `MetaRPC::MT4::ApiError` — read `e.mql_code`.
* **Common `mql_code` rejections:** `130` invalid stops, `131` invalid volume, `132` market closed, `134` not enough money, `138` requote, `148` too many orders.
* **Exactly once.** A trade call is **never re-sent** by the SDK. A transport failure after the request may have reached the terminal is raised as `TradeOutcomeUnknown` (mixed into the gRPC error) — check your open orders before retrying. See [Return Codes](../../All_Guides/RETURN_CODES_REFERENCE.md).
* **An order IS the position.** Closing a market order closes the position; "deleting" applies to pending orders.

---

## 🧭 Order types — two different enums

| Context | Enum | Values |
|---------|------|--------|
| **Sending** an order (`order_send`) | `OrderSendOperationType` | `OC_OP_BUY` (0) · `OC_OP_SELL` (1) · `OC_OP_BUYLIMIT` (2) · `OC_OP_SELLLIMIT` (3) · `OC_OP_BUYSTOP` (4) · `OC_OP_SELLSTOP` (5) |
| **Reading** open orders (`opened_orders`) | `OpenedOrderType` | `OO_OP_BUY` (0) · `OO_OP_SELL` (1) · `OO_OP_BUYLIMIT` (2) … `OO_OP_BALANCE` (6) · `OO_OP_CREDIT` (7) |

> **Friendly aliases.** `order_send(type: :buy)` is mapped by the SDK to `:OC_OP_BUY`. The raw protobuf field needs the full `:OC_OP_*` symbol — `:buy` only works because the method translates it. Accepted friendly types: `:buy :sell :buy_limit :sell_limit :buy_stop :sell_stop`.

---

## Quick choose

| If you need…                                   | Use                   | Returns                 |
| ---------------------------------------------- | --------------------- | ----------------------- |
| Open a market / pending order                  | `order_send`          | `OrderSendData`         |
| Change SL / TP / price / expiration            | `order_modify`        | `OrderModifyData`       |
| Close a market order / delete a pending one    | `order_close_delete`  | `OrderCloseDeleteData`  |
| Net out two opposite orders on one symbol      | `order_close_by`      | `OrderCloseByData`      |

---

## 🟢 Minimal snippets

```ruby
# Market buy 0.10 lots
r = acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.10, magic: 600_101)
puts "filled ticket ##{r.ticket} @ #{r.price}"
```

```ruby
# Attach SL/TP, then close
acct.order_modify(ticket: r.ticket, stop_loss: 1.0800, take_profit: 1.1000)
out = acct.order_close_delete(ticket: r.ticket)   # full close
puts "closed (#{out.mode})"
```

```ruby
# Handle a rejection
begin
  acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.10, stop_loss: 1.5)
rescue MetaRPC::MT4::ApiError => e
  puts "rejected: #{e.code} (mql #{e.mql_code})"   # e.g. 130 invalid stops
end
```

---

## See also

* **Read orders:** [Orders & History — Overview](../2.%20Orders_History/Orders_History.Overview.md).
* **Sizing:** [TickValueWithSize](../3.%20Symbols_Quotes/TickValueWithSize.md) · [SymbolParamsMany](../3.%20Symbols_Quotes/SymbolParamsMany.md).
* **Friendly layer:** [`MT4Sugar`](../../MT4Sugar/MT4Sugar.API_Overview.md) — `buy_market`, `close_order`, `buy_market_with_sl_tp`, …

---

**Back to:** [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
