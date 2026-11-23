# 📋 Listing Open Orders

> **Request:** every open order (market **and** pending) in full detail (`[OpenedOrderInfo]`). On MT4 an open market order **is** the position.

**API Information:**

* **Low-level API:** `MT4Account#opened_orders` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `OpenedOrders`

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `OpenedOrders(OpenedOrdersRequest) → OpenedOrdersReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#opened_orders(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The current book of open orders — market positions and working pendings together.
* **Why you need it.** Manage trades: read P/L, SL/TP, volume, magic; find a ticket to modify or close.
* **Returns an array.** The SDK unwraps the reply and returns `data.order_infos` as a ready array.

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # All open orders (market + pending), sorted by `sort`.
  # Returns [OpenedOrderInfo]; raises ApiError on failure.
  def opened_orders(sort: :SORT_BY_OPEN_TIME_ASC) -> Array<Mt4TermApi::OpenedOrderInfo>
end
```

**Request message:**

```protobuf
OpenedOrdersRequest {
  EnumOpenedOrderSortType sort_type = 1;
}
```

**Reply message:** `OpenedOrdersReply { oneof response { OpenedOrdersData data = 1; Error error = 2; } }` — `OpenedOrdersData { repeated OpenedOrderInfo order_infos = 1; }`. The SDK returns `order_infos` as an array.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sort` | `Symbol` (`EnumOpenedOrderSortType`) | `:SORT_BY_OPEN_TIME_ASC` | Server-side ordering of the result. |

### `EnumOpenedOrderSortType`

```protobuf
enum EnumOpenedOrderSortType {
  SORT_BY_OPEN_TIME_ASC       = 0;
  SORT_BY_OPEN_TIME_DESC      = 1;
  SORT_BY_ORDER_TICKET_ID_ASC = 2;
  SORT_BY_ORDER_TICKET_ID_DESC = 3;
}
```

---

## ⬆️ Output — `[OpenedOrderInfo]`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `ticket` | `ticket` | `Integer` | Order ticket (the id you modify / close). |
| `symbol` | `symbol` | `String` | Instrument. |
| `order_type` | `order_type` | `Symbol` | `OpenedOrderType` — market (`OO_OP_BUY/SELL`) or pending — see enum below. |
| `lots` | `lots` | `Float` | Volume in lots. |
| `open_price` | `open_price` | `Float` | Entry price (for pendings, the order price). |
| `stop_loss` | `stop_loss` | `Float` | SL price (`0` = none). |
| `take_profit` | `take_profit` | `Float` | TP price (`0` = none). |
| `profit` | `profit` | `Float` | Current floating P/L (account currency). |
| `swap` | `swap` | `Float` | Accrued swap. |
| `commision` | `commision` | `Float` | Commission (proto spelling: single "m"). |
| `magic_number` | `magic_number` | `Integer` | EA magic number (your strategy tag). |
| `comment` | `comment` | `String` | Order comment. |
| `open_time` | `open_time` | `Timestamp` | Open time (broker time zone). |
| `open_time_utc` | `open_time_utc` | `Timestamp` | Open time in UTC. |
| `expiration_time` | `expiration_time` | `Timestamp` | Pending-order expiry (broker time). |
| `expiration_time_utc` | `expiration_time_utc` | `Timestamp` | Pending-order expiry (UTC). |
| `position_index` | `position_index` | `Integer` | Internal index. |
| `sort_index` | `sort_index` | `Integer` | Index under the chosen `sort`. |
| `account_login` | `account_login` | `Integer` | Owning account login. |

### `OpenedOrderType`

```protobuf
enum OpenedOrderType {
  OO_OP_BUY       = 0;  // market  — this IS a position
  OO_OP_SELL      = 1;  // market  — this IS a position
  OO_OP_BUYLIMIT  = 2;  // pending
  OO_OP_SELLLIMIT = 3;  // pending
  OO_OP_BUYSTOP   = 4;  // pending
  OO_OP_SELLSTOP  = 5;  // pending
  OO_OP_BALANCE   = 6;  // non-trade book entry
  OO_OP_CREDIT    = 7;  // non-trade book entry
}
```

---

## 🧩 Notes & Tips

* **Market vs pending.** `OO_OP_BUY/SELL` are your open positions; the `...LIMIT/STOP` types are pending. `OO_OP_BALANCE/CREDIT` are ledger entries, not trades.
* **Filter in Ruby.** There is no server-side magic/symbol filter — select client-side (or use [`MT4Service#positions`](../../MT4Service/MT4Service.Overview.md)).
* **`0` SL/TP means none** — not price zero.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) List everything

```ruby
acct.opened_orders.each do |o|
  puts format("#%d %-8s %-12s lots %.2f  P/L %.2f", o.ticket, o.symbol, o.order_type, o.lots, o.profit)
end
```

### 2) Positions only (market orders)

```ruby
MARKET = %i[OO_OP_BUY OO_OP_SELL]
positions = acct.opened_orders.select { |o| MARKET.include?(o.order_type) }
puts "open positions: #{positions.size}, floating #{positions.sum(&:profit).round(2)}"
```

### 3) Pending orders for one symbol

```ruby
pending = acct.opened_orders.reject { |o| %i[OO_OP_BUY OO_OP_SELL OO_OP_BALANCE OO_OP_CREDIT].include?(o.order_type) }
pending.select { |o| o.symbol == "EURUSD" }.each { |o| puts "##{o.ticket} #{o.order_type} @ #{o.open_price}" }
```

### 4) Find a ticket by magic

```ruby
mine = acct.opened_orders.find { |o| o.magic_number == 600_101 }
puts mine ? "found ##{mine.ticket}" : "none"
```

### 5) Error handling

```ruby
def safe_open_orders(acct)
  acct.opened_orders
rescue MetaRPC::MT4::ApiError, GRPC::BadStatus => e
  warn "opened_orders failed: #{e.message}"
  []
end
```

---

## 📚 See Also

* [OpenedOrdersTickets](./OpenedOrdersTickets.md) — just the ticket numbers (cheap poll).
* [OrdersHistory](./OrdersHistory.md) — closed / deleted orders.
* **Modify / close:** [OrderModify](../4.%20Trading_Operations/OrderModify.md) · [OrderCloseDelete](../4.%20Trading_Operations/OrderCloseDelete.md).
* **Friendly layer:** [`MT4Service#positions` / `#pending_orders`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Orders & History — Overview](./Orders_History.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
