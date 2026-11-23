# 💰 Streaming Open-Orders Profit

> **Stream:** the floating P/L of every open order, pushed on a timer. Yields `OnOpenedOrdersProfitData` on a background thread.

**API Information:**

* **Low-level API:** `MT4Account#on_opened_orders_profit` (alias `on_position_profit`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.SubscriptionService`
* **Proto definition:** `OnOpenedOrdersProfit` (server-streaming)

### RPC

* **Service:** `mt4_term_api.SubscriptionService`
* **Method:** `OnOpenedOrdersProfit(OnOpenedOrdersProfitRequest) → stream OnOpenedOrdersProfitReply`
* **Low-level client (generated):** `Mt4TermApi::SubscriptionService::Stub#on_opened_orders_profit(request, metadata:)`

---

## 💬 Just the essentials

* **What it is.** A periodic push (every `interval_ms`) of each open order's current profit, plus a live account snapshot.
* **Why you need it.** A live P/L panel without polling `opened_orders` in a loop.
* **Yields `OnOpenedOrdersProfitData`.**

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Open orders' P/L every `interval_ms`. Yields OnOpenedOrdersProfitData on a
  # background thread. Returns a Subscription; call .cancel to stop.
  def on_opened_orders_profit(interval_ms: 1000) { |data| ... } -> MetaRPC::MT4::Subscription
  alias on_position_profit on_opened_orders_profit
end
```

**Request message:** `OnOpenedOrdersProfitRequest { int32 timer_period_milliseconds = 1; }`

**Reply (stream):** `OnOpenedOrdersProfitReply { OnOpenedOrdersProfitData data; … }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `interval_ms` | `Integer` | `1000` | Push period in milliseconds (`timer_period_milliseconds`). |
| `&block` | block | — | Called with each `OnOpenedOrdersProfitData`. |

---

## ⬆️ Yielded — `OnOpenedOrdersProfitData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `type` | `type` | `Symbol` | Event group (`MT4_SUB_ENUM_EVENT_GROUP_TYPE`). |
| `opened_orders_with_profit_updated` | … | `[OnOpenedOrdersProfitOrderInfo]` | One row per open order (see below). |
| `account_info` | `account_info` | `OnEventAccountInfo` | Live account snapshot. |
| `terminal_instance_guid_id` | `terminal_instance_guid_id` | `String` | Terminal session id. |

### `OnOpenedOrdersProfitOrderInfo` (per order)

| Field | Type | Description |
|-------|------|-------------|
| `ticket` | `Integer` | Order ticket. |
| `symbol` | `String` | Instrument. |
| `type` | `Symbol` | `SUB_ORDER_OPERATION_TYPE`. |
| `lots` | `Float` | Volume. |
| `open_price` | `Float` | Entry price. |
| `order_profit` | `Float` | **Current floating P/L** (note: `order_profit`, not `profit`). |
| `swap` | `Float` | Accrued swap. |
| `commission` | `Float` | Commission (here spelled `commission`, double "s"). |
| `stop_loss` / `take_profit` | `Float` | SL / TP. |
| `magic_number` | `Integer` | EA magic. |
| `comment` | `String` | Order comment. |
| `open_time` / `open_time_utc` | `Timestamp` | Open time. |

---

## 🧱 Related enums (from proto)

### `MT4_SUB_ENUM_EVENT_GROUP_TYPE` (on `type`)

```protobuf
enum MT4_SUB_ENUM_EVENT_GROUP_TYPE {
  OrderProfit = 0;  // a periodic profit update (this stream)
  OrderUpdate = 1;  // an order opened / modified / closed
}
```

### `SUB_ORDER_OPERATION_TYPE` (on each order's `type`)

```protobuf
enum SUB_ORDER_OPERATION_TYPE {
  SUB_OP_BUY       = 0;
  SUB_OP_SELL      = 1;
  SUB_OP_BUYLIMIT  = 2;
  SUB_OP_SELLLIMIT = 3;
  SUB_OP_BUYSTOP   = 4;
  SUB_OP_SELLSTOP  = 5;
}
```

---

## 🧩 Notes & Tips

* **Field name is `order_profit`** on the streamed rows (the static `opened_orders` list uses `profit`).
* **Commission spelling differs** — `commission` here vs `commision` on `OpenedOrderInfo`.
* **Tune `interval_ms`** — 1000 ms is plenty for a UI; lower it only if you really need sub-second updates.
* **Returns a `Subscription`** — `sub.cancel` to stop; don't cancel inside the block.

---

## 🔗 Usage Examples

### 1) Live total floating P/L

```ruby
sub = acct.on_opened_orders_profit(interval_ms: 1000) do |d|
  total = d.opened_orders_with_profit_updated.sum(&:order_profit)
  puts "floating P/L: #{total.round(2)}  (equity #{d.account_info.equity.round(2)})"
end
sleep 10
sub.cancel
```

### 2) Per-order rows

```ruby
sub = acct.on_opened_orders_profit do |d|
  d.opened_orders_with_profit_updated.each do |o|
    puts format("#%d %-8s %.2f", o.ticket, o.symbol, o.order_profit)
  end
end
sleep 5
sub.cancel
```

---

## 📚 See Also

* [OnOpenedOrdersTickets](./OnOpenedOrdersTickets.md) — ticket snapshots on a timer.
* [OpenedOrders](../2.%20Orders_History/OpenedOrders.md) — full detail (poll).
* **Friendly layer:** [`MT4Service#on_opened_orders_profit`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Streaming Methods — Overview](./Streaming_Methods.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
