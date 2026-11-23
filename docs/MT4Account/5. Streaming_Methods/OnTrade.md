# 🔔 Streaming Trade Events

> **Stream:** fires whenever orders **open, update, or close**. Yields `OnTradeData` (new / updated / removed orders + a live account snapshot) on a background thread.

**API Information:**

* **Low-level API:** `MT4Account#on_trade` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.SubscriptionService`
* **Proto definition:** `OnTrade` (server-streaming)

### RPC

* **Service:** `mt4_term_api.SubscriptionService`
* **Method:** `OnTrade(OnTradeRequest) → stream OnTradeReply`
* **Low-level client (generated):** `Mt4TermApi::SubscriptionService::Stub#on_trade(request, metadata:)`

---

## 💬 Just the essentials

* **What it is.** A push stream of trade-book changes — you learn immediately when something fills, is modified, or closes.
* **Why you need it.** Keep a local order cache in sync; trigger follow-up logic on fills; audit activity.
* **Yields `OnTradeData`.** The SDK calls your block with each event payload.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Subscribe to trade events. Yields OnTradeData on a background thread.
  # Returns a Subscription; call .cancel to stop.
  def on_trade { |event| ... } -> MetaRPC::MT4::Subscription
end
```

**Request message:** `OnTradeRequest {}` *(empty)*

**Reply (stream):** `OnTradeReply { OnTradeData data; … }`.

---

## 🔽 Input

| Argument | Type | Description |
|----------|------|-------------|
| `&block` | block | Called with each `OnTradeData`. |

---

## ⬆️ Yielded — `OnTradeData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `type` | `type` | `Symbol` | Event group — `MT4_SUB_ENUM_EVENT_GROUP_TYPE` (`:OrderProfit` / `:OrderUpdate`). |
| `event_data` | `event_data` | `OnTadeEventData` | The order deltas (see below). |
| `account_info` | `account_info` | `OnEventAccountInfo` | Live account snapshot (balance, equity, margin, free_margin, profit, margin_level, login). |
| `terminal_instance_guid_id` | `terminal_instance_guid_id` | `String` | Terminal session id. |

### `event_data` — `OnTadeEventData`

| Field | Type | Description |
|-------|------|-------------|
| `new_orders` | `[OnTradeOrderInfo]` | Orders that just appeared (opened / placed). |
| `updated_orders` | `[OnTradeUpdatedOrderInfo]` | Orders whose SL/TP/price changed. |
| `removed_orders` | `[OnTradeOrderInfo]` | Orders that closed / were deleted. |
| `new_history_orders` | `[OnTradeOrderInfo]` | Newly archived history orders. |

> The proto message name is `OnTadeEventData` (a server-side spelling — kept as-is).

---

## 🧱 Related enums (from proto)

### `MT4_SUB_ENUM_EVENT_GROUP_TYPE` (on `type`)

```protobuf
enum MT4_SUB_ENUM_EVENT_GROUP_TYPE {
  OrderProfit = 0;  // a periodic profit update
  OrderUpdate = 1;  // an order opened / modified / closed
}
```

### `SUB_ORDER_OPERATION_TYPE` (on the order rows inside `event_data`)

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

* **Quiet until something happens.** No trades → no events; it's not a heartbeat.
* **`account_info` rides along** — each event carries a fresh balance/equity snapshot, handy for a live P/L panel.
* **Returns a `Subscription`** — `sub.cancel` to stop; don't cancel inside the block.
* **No auto-reconnect** — resubscribe on `sub.error`.

---

## 🔗 Usage Examples

### 1) Log opens and closes

```ruby
sub = acct.on_trade do |e|
  e.event_data.new_orders.each     { |o| puts "opened  ##{o.ticket}" }
  e.event_data.removed_orders.each { |o| puts "closed  ##{o.ticket}" }
end
sleep 30
sub.cancel
```

### 2) Live equity from events

```ruby
sub = acct.on_trade { |e| puts "equity #{e.account_info.equity.round(2)}" }
sleep 10
sub.cancel
```

### 3) Count events in a window

```ruby
n = 0
sub = acct.on_trade { |_e| n += 1 }
sleep 5
sub.cancel
puts "trade events: #{n}"
```

---

## 📚 See Also

* [OnOpenedOrdersProfit](./OnOpenedOrdersProfit.md) — floating P/L on a timer.
* [OpenedOrders](../2.%20Orders_History/OpenedOrders.md) — the current book (poll).
* **Friendly layer:** [`MT4Service#on_trade`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Streaming Methods — Overview](./Streaming_Methods.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
