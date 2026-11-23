# MT4Account · Orders & History — Overview

> Everything about orders: what's **open right now** (market + pending), their **tickets**, and what's **closed** in history. On MT4 an open market order **is** the position.

These methods are **read-only**. All three live on `mt4_term_api.AccountHelper`. Each returns the raw `*Data` (read fields with snake_case accessors), or raises `ApiError`.

## 📁 What lives here

* **[OpenedOrders](./OpenedOrders.md)** — **all open orders** in full detail (`[OpenedOrderInfo]`): ticket, symbol, `order_type`, lots, open price, SL/TP, profit, swap, commission, magic, comment. Market **and** pending in one list.
* **[OpenedOrdersTickets](./OpenedOrdersTickets.md)** — **just the ticket numbers** (`[Integer]`) — the lightweight way to poll "what's open".
* **[OrdersHistory](./OrdersHistory.md)** — **closed / deleted orders** in a time window (`[HistoryOrderInfo]`), auto-paged.

---

## 🧭 Plain English — MT4 orders model

MT4 has **orders, not positions**. There is one list of open orders; what kind each is comes from `order_type`:

| `order_type` | Meaning |
|--------------|---------|
| `:OO_OP_BUY`, `:OO_OP_SELL` | **Market** orders — these *are* your open positions. |
| `:OO_OP_BUYLIMIT`, `:OO_OP_SELLLIMIT`, `:OO_OP_BUYSTOP`, `:OO_OP_SELLSTOP` | **Pending** orders — waiting to trigger. |
| `:OO_OP_BALANCE`, `:OO_OP_CREDIT` | Non-trade book entries (deposits / credit). |

So "open positions" = `opened_orders.select { |o| %i[OO_OP_BUY OO_OP_SELL].include?(o.order_type) }`. The friendly [`MT4Service#positions`](../../MT4Service/MT4Service.Overview.md) / `#pending_orders` do this split for you.

---

## Quick choose

| If you need…                                | Use                       | Returns                  |
| ------------------------------------------- | ------------------------- | ------------------------ |
| Full detail of every open order             | `opened_orders`           | `[OpenedOrderInfo]`      |
| Only the tickets of open orders (cheap poll)| `opened_orders_tickets`   | `[Integer]`              |
| Closed / deleted orders in a time window    | `orders_history`          | `[HistoryOrderInfo]`     |

---

## ❌ Cross-refs & gotchas

* **One list, two kinds.** `opened_orders` returns market **and** pending together — filter by `order_type`.
* **No separate deals.** Unlike MT5, MT4 has no deals list; `orders_history` is the record of closed orders.
* **History is paged.** `orders_history` auto-pages for you (follows `next_page_token`) and returns one flat array.
* **Window bounds are Timestamps** on `orders_history` (sent as `google.protobuf.Timestamp`) — the SDK accepts a Ruby `Time` and converts.
* **`commision` spelling** — the proto field is `commision` (single "m"), kept as-is.

---

## 🟢 Minimal snippets

```ruby
# Open market orders (= positions) and pending, split by type
all = acct.opened_orders
market  = all.select { |o| %i[OO_OP_BUY OO_OP_SELL].include?(o.order_type) }
pending = all.reject { |o| %i[OO_OP_BUY OO_OP_SELL OO_OP_BALANCE OO_OP_CREDIT].include?(o.order_type) }
puts "market #{market.size}, pending #{pending.size}"
```

```ruby
# Cheap poll — just the tickets
puts "open tickets: #{acct.opened_orders_tickets.inspect}"
```

```ruby
# Closed orders in the last 7 days
hist = acct.orders_history(from_utc: Time.now.utc - 7 * 24 * 3600)
puts "closed: #{hist.size}, net P/L #{hist.sum(&:profit).round(2)}"
```

---

## 🧱 Enums used in Orders & History

| Where | Enum | Values |
|-------|------|--------|
| `opened_orders(sort:)` input | `EnumOpenedOrderSortType` | `:SORT_BY_OPEN_TIME_ASC` (0) · `:..._OPEN_TIME_DESC` (1) · `:SORT_BY_ORDER_TICKET_ID_ASC` (2) · `:..._DESC` (3) |
| `orders_history(sort:)` input | `EnumOrderHistorySortType` | `:HISTORY_SORT_BY_OPEN_TIME_ASC` (0) · `_OPEN_TIME_DESC` (1) · `_CLOSE_TIME_ASC` (2) · `_CLOSE_TIME_DESC` (3) · `_ORDER_TICKET_ID_ASC` (4) · `_DESC` (5) |
| `order_type` output (both lists) | `OpenedOrderType` | `:OO_OP_BUY` (0) · `:OO_OP_SELL` (1) · `:OO_OP_BUYLIMIT` (2) · `:OO_OP_SELLLIMIT` (3) · `:OO_OP_BUYSTOP` (4) · `:OO_OP_SELLSTOP` (5) · `:OO_OP_BALANCE` (6) · `:OO_OP_CREDIT` (7) |

---

## See also

* **Place / close:** [Trading Operations — Overview](../4.%20Trading_Operations/Trading_Operations.Overview.md).
* **Friendly layer:** [`MT4Service#positions` / `#pending_orders` / `#order_history`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
