# 🎟️ Streaming Ticket Snapshots

> **Stream:** the open **ticket numbers** (positions + pendings) pushed on a timer. Yields `OnOpenedOrdersTicketsData` on a background thread.

**API Information:**

* **Low-level API:** `MT4Account#on_opened_orders_tickets` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.SubscriptionService`
* **Proto definition:** `OnOpenedOrdersTickets` (server-streaming)

### RPC

* **Service:** `mt4_term_api.SubscriptionService`
* **Method:** `OnOpenedOrdersTickets(OnOpenedOrdersTicketsRequest) → stream OnOpenedOrdersTicketsReply`
* **Low-level client (generated):** `Mt4TermApi::SubscriptionService::Stub#on_opened_orders_tickets(request, metadata:)`

---

## 💬 Just the essentials

* **What it is.** A lightweight periodic push of just the open tickets — split into **positions** and **pending orders**.
* **Why you need it.** Cheaply detect when an order opens / closes without pushing full records; drive a "diff" against your last snapshot.
* **Yields `OnOpenedOrdersTicketsData`.**

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Open order tickets every `interval_ms`. Yields OnOpenedOrdersTicketsData on a
  # background thread. Returns a Subscription; call .cancel to stop.
  def on_opened_orders_tickets(interval_ms: 1000) { |data| ... } -> MetaRPC::MT4::Subscription
end
```

**Request message:** `OnOpenedOrdersTicketsRequest { int32 pull_interval_milliseconds = 1; }`

**Reply (stream):** `OnOpenedOrdersTicketsReply { OnOpenedOrdersTicketsData data; … }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `interval_ms` | `Integer` | `1000` | Push period in milliseconds (`pull_interval_milliseconds`). |
| `&block` | block | — | Called with each `OnOpenedOrdersTicketsData`. |

---

## ⬆️ Yielded — `OnOpenedOrdersTicketsData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `position_tickets` | `position_tickets` | `[Integer]` | Tickets of open **market** orders (positions). |
| `pending_order_tickets` | `pending_order_tickets` | `[Integer]` | Tickets of open **pending** orders. |
| `server_time` | `server_time` | `Timestamp` | Snapshot time (broker time zone). |
| `server_time_utc` | `server_time_utc` | `Timestamp` | Snapshot time (UTC). |
| `terminal_instance_guid_id` | `terminal_instance_guid_id` | `String` | Terminal session id. |

> Note: this stream **separates** positions from pendings (unlike the one-shot [`opened_orders_tickets`](../2.%20Orders_History/OpenedOrdersTickets.md), which returns a single combined array).

---

## 🧩 Notes & Tips

* **Diff pattern** — keep the previous `position_tickets` and compare to spot new / closed positions.
* **Cheap** — only integers cross the wire; use it as a change detector, then pull detail with `opened_orders` when the set changes.
* **Returns a `Subscription`** — `sub.cancel` to stop; don't cancel inside the block.

---

## 🔗 Usage Examples

### 1) Detect opens / closes

```ruby
prev = []
sub = acct.on_opened_orders_tickets(interval_ms: 1000) do |d|
  now = d.position_tickets.to_a
  (now - prev).each { |t| puts "opened  ##{t}" }
  (prev - now).each { |t| puts "closed  ##{t}" }
  prev = now
end
sleep 20
sub.cancel
```

### 2) Live counts

```ruby
sub = acct.on_opened_orders_tickets do |d|
  puts "positions #{d.position_tickets.size}  pending #{d.pending_order_tickets.size}"
end
sleep 5
sub.cancel
```

---

## 📚 See Also

* [OpenedOrdersTickets](../2.%20Orders_History/OpenedOrdersTickets.md) — one-shot combined ticket list.
* [OnOpenedOrdersProfit](./OnOpenedOrdersProfit.md) — P/L on a timer.
* **Friendly layer:** [`MT4Service#on_tickets`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Streaming Methods — Overview](./Streaming_Methods.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
