# 🟢 Sending an Order

> **Request:** open a **market or pending** order. Returns `OrderSendData` — a **`ticket > 0` means filled**. A rejection **raises** `ApiError` (MT4 has no retcode).

**API Information:**

* **Low-level API:** `MT4Account#order_send` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradingHelper`
* **Proto definition:** `OrderSend`

### RPC

* **Service:** `mt4_term_api.TradingHelper`
* **Method:** `OrderSend(OrderSendRequest) → OrderSendReply`
* **Low-level client (generated):** `Mt4TermApi::TradingHelper::Stub#order_send(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Places a buy/sell at market, or a pending limit/stop order.
* **Why you need it.** Entering trades — the core write operation.
* **Success = ticket.** `OrderSendData.ticket > 0` is the filled/placed order id. There is **no `returned_code`**.
* **Rejection raises.** Broker refusals come back as `ApiError` with an `mql_code` (130, 132, 134…). Wrap in `begin/rescue`.

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # Market or pending order. `type` is a friendly symbol (mapped to OC_OP_*).
  # `price` is ignored for market orders; `slippage` is in points; `magic` -> magic_number.
  # Returns OrderSendData (ticket, volume, price, open_time); raises ApiError on rejection.
  def order_send(symbol:, type:, volume:, price: nil, stop_loss: nil, take_profit: nil,
                 comment: nil, magic: nil, slippage: nil, expiration_utc: nil) -> Mt4TermApi::OrderSendData
end
```

**Request message:**

```protobuf
OrderSendRequest {
  string symbol                   = 1;
  OrderSendOperationType operation_type = 2;  // OC_OP_* (SDK maps :buy → :OC_OP_BUY)
  double volume                   = 3;        // lots
  double price                    = 4;        // pending price (ignored for market)
  int32  slippage                 = 5;        // points
  double stoploss                 = 6;
  double takeprofit               = 7;
  string comment                  = 8;
  int32  magic_number             = 9;
  google.protobuf.Timestamp expiration     = 10; // broker time
  google.protobuf.Timestamp expiration_utc = 11; // UTC ← the SDK sets this
}
```

**Reply message:** `OrderSendReply { oneof response { OrderSendData data = 1; Error error = 2; } }`

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `symbol` | `String` | **required** | Instrument, e.g. `"EURUSD"`. |
| `type` | `Symbol` | **required** | `:buy :sell :buy_limit :sell_limit :buy_stop :sell_stop` (mapped to `OC_OP_*`). |
| `volume` | `Float` | **required** | Lots (respect `VolumeMin/Max/Step`). |
| `price` | `Float` | `nil` | Pending-order price. **Ignored for market** orders (gateway uses the current quote). |
| `stop_loss` | `Float` | `nil` | SL price. |
| `take_profit` | `Float` | `nil` | TP price. |
| `comment` | `String` | `nil` | Order comment. |
| `magic` | `Integer` | `nil` | EA magic number (`magic_number`). |
| `slippage` | `Integer` | `nil` | Max slippage in **points**. |
| `expiration_utc` | `Time` | `nil` | Pending-order expiry (UTC; sent as `Timestamp`). |

### `OrderSendOperationType`

```protobuf
enum OrderSendOperationType {
  OC_OP_BUY       = 0;  // ← :buy
  OC_OP_SELL      = 1;  // ← :sell
  OC_OP_BUYLIMIT  = 2;  // ← :buy_limit
  OC_OP_SELLLIMIT = 3;  // ← :sell_limit
  OC_OP_BUYSTOP   = 4;  // ← :buy_stop
  OC_OP_SELLSTOP  = 5;  // ← :sell_stop
}
```

> **Friendly vs raw.** `type: :buy` works because the SDK maps it to `:OC_OP_BUY`. If you build the protobuf yourself you must use `:OC_OP_BUY` — the raw field rejects `:buy`.

---

## ⬆️ Output — `OrderSendData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `ticket` | `ticket` | `Integer` | The new order's ticket (**> 0 = success**). |
| `volume` | `volume` | `Float` | Filled / placed volume. |
| `price` | `price` | `Float` | Fill price (market) or order price (pending). |
| `open_time` | `open_time` | `Timestamp` | Open time (broker time zone). |
| `open_time_utc` | `open_time_utc` | `Timestamp` | Open time (UTC). |

---

## 🚨 Errors — no retcode, exceptions instead

A broker rejection raises `MetaRPC::MT4::ApiError`; read `e.mql_code`:

| `mql_code` | Meaning |
|-----------|---------|
| `130` | Invalid stops (SL/TP too close — see `TradeStopsLevel`). |
| `131` | Invalid volume. |
| `132` | Market closed. |
| `134` | Not enough money. |
| `138` | Requote (price moved). |
| `148` | Too many orders. |

A **transport** failure after the request may have reached the terminal raises `TradeOutcomeUnknown` (mixed into the gRPC error) — the trade is **not** re-sent; check open orders before retrying.

---

## 🧩 Notes & Tips

* **Round volume** to the symbol's `VolumeStep`; keep SL/TP beyond `TradeStopsLevel` points.
* **Market vs pending** — pass `price:` only for `*_limit` / `*_stop` types.
* **`magic`** tags your orders so you can filter them later (`opened_orders` / `orders_history`).
* **120 s deadline** — trade calls use a longer timeout.

---

## 🔗 Usage Examples

### 1) Market buy

```ruby
r = acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.10, magic: 600_101, comment: "entry")
puts "ticket ##{r.ticket} @ #{r.price}"
```

### 2) Market buy with SL/TP

```ruby
q = acct.quote("EURUSD")
r = acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.10,
                    stop_loss: (q.bid - 0.0020).round(5),
                    take_profit: (q.ask + 0.0020).round(5))
```

### 3) Pending buy-limit below the market

```ruby
q = acct.quote("EURUSD")
acct.order_send(symbol: "EURUSD", type: :buy_limit, volume: 0.10, price: (q.bid - 0.0050).round(5))
```

### 4) Safe send with rejection handling

```ruby
def safe_buy(acct, sym, vol)
  acct.order_send(symbol: sym, type: :buy, volume: vol)
rescue MetaRPC::MT4::TradeOutcomeUnknown => e
  warn "UNKNOWN outcome for #{e.operation} — check open orders!"
  nil
rescue MetaRPC::MT4::ApiError => e
  warn "rejected: #{e.code} (mql #{e.mql_code})"
  nil
end
```

---

## 📚 See Also

* [OrderModify](./OrderModify.md) — attach / change SL/TP afterwards.
* [OrderCloseDelete](./OrderCloseDelete.md) — close or delete.
* [OpenedOrders](../2.%20Orders_History/OpenedOrders.md) — confirm what's open.
* **Friendly layer:** [`MT4Sugar#buy_market` / `#buy_market_with_sl_tp`](../../MT4Sugar/MT4Sugar.API_Overview.md).

---

**Back to:** [Trading Operations — Overview](./Trading_Operations.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
