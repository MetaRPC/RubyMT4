# 📉 Unrealized-P/L Extrema

> **Request:** the maximum and minimum unrealized P/L each open order reached over a window (`[TradeUnrealizedExtremaData]`) — how far every trade swung before you were in it.

**API Information:**

* **Low-level API:** `MT4Account#trade_unrealized_pl` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradeStats`
* **Proto definition:** `TradeUnrealizedPL`

### RPC

* **Service:** `mt4_term_api.TradeStats`
* **Method:** `TradeUnrealizedPL(TradeUnrealizedPLRequest) → TradeUnrealizedPLReply`
* **Low-level client (generated):** `Mt4TermApi::TradeStats::Stub#trade_unrealized_pl(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Per-order **max / min floating P/L** and the time each extreme happened.
* **Why you need it.** Measure MFE/MAE (maximum favorable / adverse excursion) — did your stop sit too tight, your target too far?
* **Returns an array.** The SDK returns `data.extrema` as a ready array.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Unrealized-P/L extrema per open order since `from_utc` (or broker-local `from`).
  # Returns [TradeUnrealizedExtremaData].
  def trade_unrealized_pl(from_utc: nil, from: nil) -> Array<Mt4TermApi::TradeUnrealizedExtremaData>
end
```

**Request message:**

```protobuf
TradeUnrealizedPLRequest {
  string from     = 1;  // broker server time, "yyyy-MM-ddTHH:mm:ss"
  string from_utc = 2;  // UTC ISO-8601
}
```

**Reply message:** `TradeUnrealizedPLReply { oneof response { TradeUnrealizedPLData data = 1; Error error = 2; } }` — `TradeUnrealizedPLData { repeated TradeUnrealizedExtremaData extrema = 1; }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `from_utc` | `Time` / `String` / `nil` | `nil` | Window start in **UTC** (converted to ISO-8601 for you). |
| `from` | `Time` / `String` / `nil` | `nil` | Window start in **broker server time**. Use instead of `from_utc`. |

Runs on a **120 s** deadline.

---

## ⬆️ Output — `[TradeUnrealizedExtremaData]`

Each entry:

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `ticket` | `ticket` | `Integer` | Order ticket. |
| `symbol` | `symbol` | `String` | Instrument. |
| `max_unrealized_pl` | `max_unrealized_pl` | `Float` | Best floating P/L reached (MFE). |
| `max_unrealized_time` | `max_unrealized_time` | `Timestamp` | When the max was reached (broker time). |
| `max_unrealized_time_utc` | `max_unrealized_time_utc` | `Timestamp` | The same moment in UTC. |
| `min_unrealized_pl` | `min_unrealized_pl` | `Float` | Worst floating P/L reached (MAE). |
| `min_unrealized_time` | `min_unrealized_time` | `Timestamp` | When the min was reached (broker time). |
| `min_unrealized_time_utc` | `min_unrealized_time_utc` | `Timestamp` | The same moment in UTC. |

---

## 🧩 Notes & Tips

* **One window bound** — `from_utc` **or** `from`; omit for full history.
* **MFE/MAE analysis** — compare `max_unrealized_pl` against each trade's realized result to spot targets left on the table, and `min_unrealized_pl` to spot stops nearly hit.
* **Timestamps** are `Timestamp` — read `.seconds`.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) List extrema per order

```ruby
acct.trade_unrealized_pl(from_utc: Time.now.utc - 24 * 3600).each do |x|
  puts format("#%d %-8s  MFE +%.2f  MAE %.2f", x.ticket, x.symbol, x.max_unrealized_pl, x.min_unrealized_pl)
end
```

### 2) Worst adverse excursion

```ruby
rows = acct.trade_unrealized_pl(from_utc: Time.now.utc - 7 * 24 * 3600)
worst = rows.min_by(&:min_unrealized_pl)
puts "Deepest drawdown: ##{worst&.ticket} #{worst&.symbol} #{worst&.min_unrealized_pl&.round(2)}" if worst
```

### 3) Time-to-peak

```ruby
acct.trade_unrealized_pl(from_utc: Time.now.utc - 86_400).each do |x|
  t = Time.at(x.max_unrealized_time_utc.seconds).utc
  puts "##{x.ticket} peaked at #{t.strftime('%H:%M')} (+#{x.max_unrealized_pl.round(2)})"
end
```

---

## 📚 See Also

* [TradeStats](./TradeStats.md) — aggregate performance metrics.
* [EquityHistory](./EquityHistory.md) — the equity-curve points.
* [OpenedOrders](../2.%20Orders_History/OpenedOrders.md) — the currently open orders.

---

**Back to:** [Account Information — Overview](./Account_Information.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
