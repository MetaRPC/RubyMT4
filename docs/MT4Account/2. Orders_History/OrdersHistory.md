# 📜 Orders History

> **Request:** closed / deleted orders in a time window (`[HistoryOrderInfo]`), auto-paged. On MT4 this is the record of finished trades (there is no separate "deals" list).

**API Information:**

* **Low-level API:** `MT4Account#orders_history` (alias `order_history`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `OrdersHistory`

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `OrdersHistory(OrdersHistoryRequest) → OrdersHistoryReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#orders_history(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Your closed-order history between two times, returned as one flat array (the SDK follows the page token for you).
* **Why you need it.** P/L reports, trade journals, reconciliation, per-symbol or per-magic breakdowns.
* **Window.** `from_utc` is required; `to_utc` defaults to now.

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # Closed / deleted orders in [from_utc, to_utc], auto-paged.
  # Returns [HistoryOrderInfo]; raises ApiError on failure.
  def orders_history(from_utc:, to_utc: Time.now.utc,
                     sort: :HISTORY_SORT_BY_CLOSE_TIME_ASC, page_size: 1000) -> Array<Mt4TermApi::HistoryOrderInfo>
  alias order_history orders_history
end
```

**Request message:**

```protobuf
OrdersHistoryRequest {
  EnumOrderHistorySortType input_sort_mode = 1;
  google.protobuf.Timestamp input_from      = 2;  // broker time
  google.protobuf.Timestamp input_from_utc  = 3;  // UTC   ← the SDK sets this
  google.protobuf.Timestamp input_to        = 4;  // broker time
  google.protobuf.Timestamp input_to_utc    = 5;  // UTC   ← the SDK sets this
  int32  page_number    = 6;
  int32  items_per_page = 7;
  string page_token     = 8;   // ← the SDK follows this to page
  int32  page_size      = 9;
}
```

**Reply message:** `OrdersHistoryReply { oneof response { OrdersHistoryData data = 1; Error error = 2; } }` — `OrdersHistoryData { repeated HistoryOrderInfo orders_info = 1; int32 total_count = 2; string next_page_token = 3; }`. The SDK concatenates every page's `orders_info` and returns one array.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `from_utc` | `Time` / `Integer` / `Timestamp` | **required** | Window start (UTC). A Ruby `Time` is converted to `Timestamp`. |
| `to_utc` | `Time` / `Integer` / `Timestamp` | `Time.now.utc` | Window end (UTC). |
| `sort` | `Symbol` (`EnumOrderHistorySortType`) | `:HISTORY_SORT_BY_CLOSE_TIME_ASC` | Server-side ordering. |
| `page_size` | `Integer` | `1000` | Rows per page request (paging is automatic). |

### `EnumOrderHistorySortType`

```protobuf
enum EnumOrderHistorySortType {
  HISTORY_SORT_BY_OPEN_TIME_ASC        = 0;
  HISTORY_SORT_BY_OPEN_TIME_DESC       = 1;
  HISTORY_SORT_BY_CLOSE_TIME_ASC       = 2;  // default
  HISTORY_SORT_BY_CLOSE_TIME_DESC      = 3;
  HISTORY_SORT_BY_ORDER_TICKET_ID_ASC  = 4;
  HISTORY_SORT_BY_ORDER_TICKET_ID_DESC = 5;
}
```

> The window is matched against each order's time per the chosen sort mode. The SDK sends the **UTC** bounds (`input_from_utc` / `input_to_utc`).

---

## ⬆️ Output — `[HistoryOrderInfo]`

Like [`OpenedOrderInfo`](./OpenedOrders.md), **plus** close (`close_price` / `close_time`) fields:

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `ticket` | `ticket` | `Integer` | Order ticket. |
| `symbol` | `symbol` | `String` | Instrument. |
| `order_type` | `order_type` | `Symbol` | `OpenedOrderType` (same enum as open orders). |
| `lots` | `lots` | `Float` | Volume in lots. |
| `open_price` | `open_price` | `Float` | Entry price. |
| `close_price` | `close_price` | `Float` | Exit price. |
| `profit` | `profit` | `Float` | Realized P/L (account currency). |
| `swap` | `swap` | `Float` | Swap charged. |
| `commision` | `commision` | `Float` | Commission (proto spelling). |
| `stop_loss` / `take_profit` | `stop_loss` / `take_profit` | `Float` | SL / TP that were set. |
| `magic_number` | `magic_number` | `Integer` | EA magic number. |
| `comment` | `comment` | `String` | Order comment. |
| `open_time` / `open_time_utc` | … | `Timestamp` | Open time (broker / UTC). |
| `close_time` / `close_time_utc` | … | `Timestamp` | Close time (broker / UTC). |
| `account_login` | `account_login` | `Integer` | Owning account login. |

---

## 🧱 Related enums (from proto)

### `OpenedOrderType` (on `order_type`)

```protobuf
enum OpenedOrderType {
  OO_OP_BUY       = 0;  // was a market order (position)
  OO_OP_SELL      = 1;  // was a market order (position)
  OO_OP_BUYLIMIT  = 2;  // was pending
  OO_OP_SELLLIMIT = 3;  // was pending
  OO_OP_BUYSTOP   = 4;  // was pending
  OO_OP_SELLSTOP  = 5;  // was pending
  OO_OP_BALANCE   = 6;  // non-trade book entry (deposit/withdrawal)
  OO_OP_CREDIT    = 7;  // non-trade book entry (credit)
}
```

*(the input `sort` enum `EnumOrderHistorySortType` is listed in full under [Input](#input) above.)*

---

## 🧩 Notes & Tips

* **Auto-paged.** You get one flat array; the SDK follows `next_page_token` until the server stops.
* **Longer deadline.** History runs on a **120 s** deadline (it can be large).
* **`from_utc` is required** — pass a `Time` (converted for you); `to_utc` defaults to now.
* **Balance/credit rows** can appear with `order_type` `OO_OP_BALANCE` / `OO_OP_CREDIT` — skip them for pure trade P/L.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Last 7 days, net P/L

```ruby
hist = acct.orders_history(from_utc: Time.now.utc - 7 * 24 * 3600)
trades = hist.reject { |o| %i[OO_OP_BALANCE OO_OP_CREDIT].include?(o.order_type) }
puts "closed: #{trades.size}, net P/L #{trades.sum { |o| o.profit + o.swap + o.commision }.round(2)}"
```

### 2) Newest first

```ruby
acct.orders_history(from_utc: Time.now.utc - 24 * 3600, sort: :HISTORY_SORT_BY_CLOSE_TIME_DESC)
    .first(10).each { |o| puts format("#%d %-8s P/L %.2f", o.ticket, o.symbol, o.profit) }
```

### 3) Per-symbol breakdown

```ruby
by_sym = acct.orders_history(from_utc: Time.now.utc - 30 * 24 * 3600).group_by(&:symbol)
by_sym.each { |sym, rows| puts "#{sym}: #{rows.size} trades, #{rows.sum(&:profit).round(2)}" }
```

### 4) Per-magic (strategy) P/L

```ruby
acct.orders_history(from_utc: Time.now.utc - 30 * 24 * 3600)
    .group_by(&:magic_number)
    .each { |m, rows| puts "magic #{m}: #{rows.sum(&:profit).round(2)}" }
```

### 5) Error handling

```ruby
def safe_history(acct, **win)
  acct.orders_history(**win)
rescue MetaRPC::MT4::ApiError, GRPC::BadStatus => e
  warn "orders_history failed: #{e.message}"
  []
end
```

---

## 📚 See Also

* [OpenedOrders](./OpenedOrders.md) — the currently open orders (full detail).
* [OpenedOrdersTickets](./OpenedOrdersTickets.md) — open tickets only.
* **Stats:** [TradeStats](../1.%20Account_Information/TradeStats.md) — aggregate performance over history.
* **Friendly layer:** [`MT4Service#order_history`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Orders & History — Overview](./Orders_History.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
