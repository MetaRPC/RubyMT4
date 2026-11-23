# ✏️ Modifying an Order

> **Request:** change the **SL / TP** of a market order, or the **price / SL / TP / expiration** of a pending order. Returns `OrderModifyData` (`order_was_modified`).

**API Information:**

* **Low-level API:** `MT4Account#order_modify` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradingHelper`
* **Proto definition:** `OrderModify`

### RPC

* **Service:** `mt4_term_api.TradingHelper`
* **Method:** `OrderModify(OrderModifyRequest) → OrderModifyReply`
* **Low-level client (generated):** `Mt4TermApi::TradingHelper::Stub#order_modify(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Updates SL/TP (and, for pendings, price & expiration) of an existing order by ticket.
* **Why you need it.** Trailing stops, break-even moves, retargeting a pending order.
* **Returns `OrderModifyData`** — check `order_was_modified`. A rejection raises `ApiError`.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Modify SL/TP (market) or price/SL/TP/expiration (pending). Only the fields you pass change.
  # Returns OrderModifyData (order_was_modified); raises ApiError on rejection.
  def order_modify(ticket:, stop_loss: nil, take_profit: nil, price: nil, expiration_utc: nil) -> Mt4TermApi::OrderModifyData
end
```

**Request message:**

```protobuf
OrderModifyRequest {
  int32  order_ticket                    = 1;
  double new_price                       = 2;  // pending only
  double new_stop_loss                   = 3;
  double new_take_profit                 = 4;
  google.protobuf.Timestamp new_expiration     = 5; // broker time
  google.protobuf.Timestamp new_expiration_utc = 6; // UTC ← the SDK sets this
}
```

**Reply message:** `OrderModifyReply { oneof response { OrderModifyData data = 1; Error error = 2; } }` — `OrderModifyData { bool order_was_modified = 1; }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ticket` | `Integer` | **required** | The order to modify (`order_ticket`). |
| `stop_loss` | `Float` | `nil` | New SL price (`new_stop_loss`). |
| `take_profit` | `Float` | `nil` | New TP price (`new_take_profit`). |
| `price` | `Float` | `nil` | New **pending** price (`new_price`). Ignored for market orders. |
| `expiration_utc` | `Time` | `nil` | New pending expiry (UTC; sent as `Timestamp`). |

> Only the fields you pass are set on the request; omit the rest.

---

## ⬆️ Output — `OrderModifyData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `order_was_modified` | `order_was_modified` | `Boolean` | `true` when the change was applied. |

---

## 🧩 Notes & Tips

* **Respect `TradeStopsLevel`.** SL/TP closer than the symbol's stops level raises `mql_code 130`.
* **"No changes" rejection.** Re-sending identical SL/TP can be refused (`mql_code 1`); only modify when the value actually changes (trailing-stop ratchet pattern).
* **Market vs pending.** `price` only applies to pending orders.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Attach SL/TP to a market order

```ruby
acct.order_modify(ticket: 465_423_938, stop_loss: 1.0800, take_profit: 1.1000)
```

### 2) Move stop to break-even

```ruby
o = acct.opened_orders.find { |x| x.ticket == 465_423_938 }
acct.order_modify(ticket: o.ticket, stop_loss: o.open_price) if o
```

### 3) Trailing-stop ratchet (never loosen)

```ruby
best = nil
loop do
  sleep 1
  bid  = acct.quote("EURUSD").bid
  want = (bid - 150 * 0.0001).round(5)
  if best.nil? || want > best
    best = want
    acct.order_modify(ticket: 465_423_938, stop_loss: want)
  end
end
```

### 4) Re-price a pending order

```ruby
acct.order_modify(ticket: 465_424_047, price: 1.0950)
```

---

## 📚 See Also

* [OrderSend](./OrderSend.md) — open the order first.
* [OrderCloseDelete](./OrderCloseDelete.md) — close / delete.
* **Friendly layer:** [`MT4Sugar#modify_sl` / `#modify_sl_tp`](../../MT4Sugar/MT4Sugar.API_Overview.md).

---

**Back to:** [Trading Operations — Overview](./Trading_Operations.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
