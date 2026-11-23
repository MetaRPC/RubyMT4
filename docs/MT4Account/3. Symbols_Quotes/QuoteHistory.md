# 🕰️ Quote History (Legacy)

> **Request:** OHLC bars via the **legacy** `MarketInfo.QuoteHistory` endpoint (`[HistoryQuote]`). **Deprecated** on the gateway and **unpaged** — prefer [`bars`](./Bars.md).

**API Information:**

* **Low-level API:** `MT4Account#quote_history` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.MarketInfo`
* **Proto definition:** `QuoteHistory`

### RPC

* **Service:** `mt4_term_api.MarketInfo`
* **Method:** `QuoteHistory(QuoteHistoryRequest) → QuoteHistoryReply`
* **Low-level client (generated):** `Mt4TermApi::MarketInfo::Stub#quote_history(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The older history call. Same idea as [`bars`](./Bars.md), but it uses `Timestamp` windows, a different timeframe enum, and returns everything in one shot (no paging).
* **Why it's here.** Compatibility with older code. **For new code use [`bars`](./Bars.md).**
* **Returns `[HistoryQuote]`.** The SDK returns `data.historical_quotes` as an array.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Legacy MarketInfo.QuoteHistory (deprecated, unpaged). `from_utc`/`to_utc` are
  # Ruby Times (sent as Timestamp). Returns [HistoryQuote]; raises ApiError.
  def quote_history(symbol, timeframe: :M1, from_utc:, to_utc: Time.now.utc) -> Array<Mt4TermApi::HistoryQuote>
end
```

**Request message:**

```protobuf
QuoteHistoryRequest {
  string symbol                       = 1;
  ENUM_QUOTE_HISTORY_TIMEFRAME timeframe = 2;
  google.protobuf.Timestamp fromTime     = 3;  // broker time
  google.protobuf.Timestamp fromTimeUtc  = 4;  // UTC   ← the SDK sets this
  google.protobuf.Timestamp toTime       = 5;  // broker time
  google.protobuf.Timestamp toTimeUtc    = 6;  // UTC   ← the SDK sets this
}
```

**Reply message:** `QuoteHistoryReply { oneof response { QuoteHistoryData data = 1; Error error = 2; } }` — `QuoteHistoryData { repeated HistoryQuote historical_quotes = 1; }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `symbol` | `String` | **required** | Symbol name. |
| `timeframe` | `Symbol` | `:M1` | `:M1 … :MN1` (mapped to `QH_PERIOD_*`). |
| `from_utc` | `Time` / `Integer` | **required** | Window start (UTC) — sent as `Timestamp`. |
| `to_utc` | `Time` / `Integer` | `Time.now.utc` | Window end (UTC). |

### `ENUM_QUOTE_HISTORY_TIMEFRAME`

```protobuf
enum ENUM_QUOTE_HISTORY_TIMEFRAME {   // note: ordinal values, not minutes
  QH_PERIOD_M1 = 0; QH_PERIOD_M5 = 1; QH_PERIOD_M15 = 2; QH_PERIOD_M30 = 3;
  QH_PERIOD_H1 = 4; QH_PERIOD_H4 = 5; QH_PERIOD_D1 = 6; QH_PERIOD_W1 = 7; QH_PERIOD_MN1 = 8;
}
```

---

## ⬆️ Output — `[HistoryQuote]`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `symbol` | `symbol` | `String` | The symbol. |
| `index` | `index` | `Integer` | Bar index. |
| `time` | `time` | `Timestamp` | Bar time (broker time zone). |
| `time_utc` | `time_utc` | `Timestamp` | Bar time (UTC). |
| `open` / `high` / `low` / `close` | … | `Float` | OHLC prices. |
| `tick_volume` | `tick_volume` | `Integer` | Tick volume. |
| `real_volume` | `real_volume` | `Integer` | Real volume (usually `0` on MT4). |
| `spread` | `spread` | `Integer` | Spread in points. |

> **Times are `Timestamp` here** (`.seconds`), unlike [`bars`](./Bars.md) which uses plain unix seconds.

---

## 🧩 Notes & Tips

* **Prefer `bars`.** This endpoint is deprecated, unpaged, and uses a different timeframe enum / time type. New code should call [`bars`](./Bars.md).
* **Window is `Timestamp`** — pass a Ruby `Time`; the SDK converts.
* **No paging** — a very wide window returns one large array (or may be capped server-side).
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Last day of H1 (legacy)

```ruby
rows = acct.quote_history("EURUSD", timeframe: :H1, from_utc: Time.now.utc - 86_400)
puts "#{rows.size} bars, last close #{rows.last&.close}"
```

### 2) Read times

```ruby
acct.quote_history("EURUSD", timeframe: :M15, from_utc: Time.now.utc - 3600).each do |b|
  puts "#{Time.at(b.time_utc.seconds).utc.strftime('%H:%M')}  C#{b.close}"
end
```

---

## 📚 See Also

* [Bars](./Bars.md) — the modern, paged bar endpoint (**use this**).
* [Quote](./Quote.md) — the current tick.
* **Friendly layer:** [`MT4Service#quote_history`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
