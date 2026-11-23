# 🎟️ Open Order Tickets

> **Request:** just the **ticket numbers** of the open orders (`[Integer]`) — the lightweight way to poll "what's open".

**API Information:**

* **Low-level API:** `MT4Account#opened_orders_tickets` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `OpenedOrdersTickets`

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `OpenedOrdersTickets(OpenedOrdersTicketsRequest) → OpenedOrdersTicketsReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#opened_orders_tickets(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Only the ticket ids of currently open orders — no detail payload.
* **Why you need it.** Cheap, frequent polling: detect when an order opens/closes without pulling full records; diff against a previous snapshot.
* **Returns an array of integers.** The SDK returns `data.tickets` as a ready array.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Only the tickets of the open orders. Returns [Integer]; raises ApiError on failure.
  def opened_orders_tickets -> Array<Integer>
end
```

**Request message:**

`OpenedOrdersTicketsRequest {}` *(empty — the SDK builds it; takes no arguments)*

**Reply message:** `OpenedOrdersTicketsReply { oneof response { OpenedOrdersTicketsData data = 1; Error error = 2; } }` — `OpenedOrdersTicketsData { repeated int32 tickets = 1; }`.

---

## 🔽 Input

**No parameters.**

---

## ⬆️ Output — `[Integer]`

An array of order ticket numbers (`Integer`). Empty when nothing is open.

---

## 🧩 Notes & Tips

* **Much cheaper than `opened_orders`** — use it for a fast heartbeat / change detector, then pull full detail only when the set changes.
* **Includes pendings.** Tickets cover market **and** pending orders (same as `opened_orders`).
* **Diff pattern** — keep the previous array and compare to spot new / closed tickets.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Basic

```ruby
tickets = acct.opened_orders_tickets
puts "open: #{tickets.size} → #{tickets.inspect}"
```

### 2) Detect changes between polls

```ruby
prev = acct.opened_orders_tickets
loop do
  sleep 2
  now = acct.opened_orders_tickets
  (now - prev).each { |t| puts "opened  ##{t}" }
  (prev - now).each { |t| puts "closed  ##{t}" }
  prev = now
end
```

### 3) Pull detail only for a specific ticket

```ruby
want = acct.opened_orders_tickets.min   # e.g. the oldest
o = acct.opened_orders.find { |x| x.ticket == want }
puts o ? "#{o.symbol} #{o.lots} lots" : "gone"
```

---

## 📚 See Also

* [OpenedOrders](./OpenedOrders.md) — the full detail for each open order.
* [OrdersHistory](./OrdersHistory.md) — closed / deleted orders.
* **Streaming:** [OnOpenedOrdersTickets](../5.%20Streaming_Methods/OnOpenedOrdersTickets.md) — the same ticket snapshot, pushed on a timer.

---

**Back to:** [Orders & History — Overview](./Orders_History.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
