# 🔁 Close By (Opposite Order)

> **Request:** close one market order **by an opposite** one on the same symbol — netting them out in a single operation. Returns `OrderCloseByData`.

**API Information:**

* **Low-level API:** `MT4Account#order_close_by` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradingHelper`
* **Proto definition:** `OrderCloseBy`

### RPC

* **Service:** `mt4_term_api.TradingHelper`
* **Method:** `OrderCloseBy(OrderCloseByRequest) → OrderCloseByReply`
* **Low-level client (generated):** `Mt4TermApi::TradingHelper::Stub#order_close_by(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Closes a buy against a sell (or vice-versa) on the **same symbol** in one shot, instead of closing each at market.
* **Why you need it.** Net out a hedge; exit both legs at one price; avoid paying the spread twice.
* **Returns `OrderCloseByData`** (`close_price`, `profit`, `close_time`). A rejection raises `ApiError`.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Close one market order by an opposite one on the same symbol.
  # Returns OrderCloseByData; raises ApiError on rejection.
  def order_close_by(ticket:, opposite_ticket:) -> Mt4TermApi::OrderCloseByData
end
```

**Request message:**

```protobuf
OrderCloseByRequest {
  int32 ticket_to_close            = 1;
  int32 opposite_ticket_closing_by = 2;
}
```

**Reply message:** `OrderCloseByReply { oneof response { OrderCloseByData data = 1; Error error = 2; } }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ticket` | `Integer` | **required** | The order to close (`ticket_to_close`). |
| `opposite_ticket` | `Integer` | **required** | The **opposite-direction** order on the **same symbol** that closes it (`opposite_ticket_closing_by`). |

> Both tickets must be **open market orders**, on the **same symbol**, in **opposite** directions (one buy, one sell).

---

## ⬆️ Output — `OrderCloseByData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `close_price` | `close_price` | `Float` | Price at which the pair was closed. |
| `profit` | `profit` | `Float` | Realized P/L of the operation. |
| `close_time` | `close_time` | `Timestamp` | Close time (broker time zone). |
| `close_time_utc` | `close_time_utc` | `Timestamp` | Close time (UTC). |

---

## 🧩 Notes & Tips

* **Same symbol, opposite side** — mismatched symbols or same-direction tickets are rejected.
* **Unequal volumes** — the larger order is partially closed; a remainder order may stay open.
* **Guard with rescue** — either ticket may already be closed → `ApiError`.
* **Exactly once** — a transport failure raises `TradeOutcomeUnknown`; check before retrying.

---

## 🔗 Usage Examples

### 1) Net out a hedge

```ruby
buy  = acct.order_send(symbol: "EURUSD", type: :buy,  volume: 0.10)
sell = acct.order_send(symbol: "EURUSD", type: :sell, volume: 0.10)
out  = acct.order_close_by(ticket: buy.ticket, opposite_ticket: sell.ticket)
puts "closed by @ #{out.close_price}, P/L #{out.profit.round(2)}"
```

### 2) Find an opposite order automatically

```ruby
MARKET = %i[OO_OP_BUY OO_OP_SELL]
orders = acct.opened_orders.select { |o| MARKET.include?(o.order_type) && o.symbol == "EURUSD" }
buy  = orders.find { |o| o.order_type == :OO_OP_BUY }
sell = orders.find { |o| o.order_type == :OO_OP_SELL }
acct.order_close_by(ticket: buy.ticket, opposite_ticket: sell.ticket) if buy && sell
```

---

## 📚 See Also

* [OrderCloseDelete](./OrderCloseDelete.md) — close / delete a single order.
* [OrderSend](./OrderSend.md) — open the legs first.
* **Friendly layer:** [`MT4Sugar#close_by`](../../MT4Sugar/MT4Sugar.API_Overview.md).

---

**Back to:** [Trading Operations — Overview](./Trading_Operations.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
