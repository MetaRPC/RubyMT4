# 🔴 Closing / Deleting an Order

> **Request:** **close** a market order (full or partial) or **delete** a pending order, by ticket. Returns `OrderCloseDeleteData` (`mode`, `history_order_comment`).

**API Information:**

* **Low-level API:** `MT4Account#order_close` (aliases `order_close_delete`, `order_delete`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradingHelper`
* **Proto definition:** `OrderCloseDelete`

### RPC

* **Service:** `mt4_term_api.TradingHelper`
* **Method:** `OrderCloseDelete(OrderCloseDeleteRequest) → OrderCloseDeleteReply`
* **Low-level client (generated):** `Mt4TermApi::TradingHelper::Stub#order_close_delete(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** One call that **closes** a market order or **deletes** a pending one — the server decides which by the ticket's type and tells you via `mode`.
* **Why you need it.** Exit trades; cancel pendings; take partial profits.
* **Returns `OrderCloseDeleteData`.** A rejection raises `ApiError`.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Close a market order (lots nil = full, else partial) or delete a pending order.
  # Returns OrderCloseDeleteData (mode, history_order_comment); raises ApiError.
  def order_close(ticket:, lots: nil, price: nil, slippage: 10) -> Mt4TermApi::OrderCloseDeleteData
  alias order_close_delete order_close
  alias order_delete order_close
end
```

**Request message:**

```protobuf
OrderCloseDeleteRequest {
  int32  order_ticket  = 1;
  double lots          = 2;  // nil/omit = full close; a value = partial close
  double closing_price = 3;  // optional; gateway uses the current quote if omitted
  int32  slippage      = 4;  // points
}
```

**Reply message:** `OrderCloseDeleteReply { oneof response { OrderCloseDeleteData data = 1; Error error = 2; } }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ticket` | `Integer` | **required** | Order to close / delete (`order_ticket`). |
| `lots` | `Float` | `nil` | **Partial** close volume; `nil` closes the whole order. Ignored when deleting a pending. |
| `price` | `Float` | `nil` | Closing price (`closing_price`); omit to use the current quote. |
| `slippage` | `Integer` | `10` | Max slippage in **points** (market close). |

---

## ⬆️ Output — `OrderCloseDeleteData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `mode` | `mode` | `Symbol` | What happened — `OrderCloseDeleteMode` (below). |
| `history_order_comment` | `history_order_comment` | `String` | The comment recorded on the resulting history order. |

### `OrderCloseDeleteMode`

```protobuf
enum OrderCloseDeleteMode {
  OCD_MARKET_ORDER  = 0;  // a market order was CLOSED
  OCD_PENDING_ORDER = 1;  // a pending order was DELETED
}
```

---

## 🧩 Notes & Tips

* **Full vs partial.** Omit `lots` to close everything; pass `lots: 0.05` to close part of a 0.10 position (the remainder stays open with a new ticket).
* **`mode` tells you the kind.** `:OCD_MARKET_ORDER` = a position was closed; `:OCD_PENDING_ORDER` = a pending was deleted.
* **Deleting a pending** — just pass its ticket; `lots`/`price`/`slippage` are ignored.
* **Guard with rescue** — a ticket may already be gone (filled/closed) → `ApiError`.
* **Exactly once** — a transport failure raises `TradeOutcomeUnknown`; check before retrying.

---

## 🔗 Usage Examples

### 1) Full close

```ruby
out = acct.order_close(ticket: 465_423_938)
puts "closed (#{out.mode})"            # OCD_MARKET_ORDER
```

### 2) Partial close

```ruby
acct.order_close(ticket: 465_423_938, lots: 0.05)   # halve a 0.10 position
```

### 3) Delete a pending order

```ruby
out = acct.order_delete(ticket: 465_424_047)
puts "deleted (#{out.mode})"           # OCD_PENDING_ORDER
```

### 4) Close every market order

```ruby
MARKET = %i[OO_OP_BUY OO_OP_SELL]
acct.opened_orders.select { |o| MARKET.include?(o.order_type) }.each do |o|
  acct.order_close(ticket: o.ticket)
rescue MetaRPC::MT4::ApiError => e
  warn "##{o.ticket}: #{e.code}"
end
```

---

## 📚 See Also

* [OrderSend](./OrderSend.md) — open the order.
* [OrderCloseBy](./OrderCloseBy.md) — net out two opposite orders.
* **Friendly layer:** [`MT4Sugar#close_order` / `#cancel_order` / `#close_all`](../../MT4Sugar/MT4Sugar.API_Overview.md).

---

**Back to:** [Trading Operations — Overview](./Trading_Operations.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
