# 📊 OHLC Bars

> **Request:** OHLC price bars via `QuoteHistory.Bars`, oldest first, **auto-paged**. The modern history endpoint — prefer it over [`quote_history`](./QuoteHistory.md).

**API Information:**

* **Low-level API:** `MT4Account#bars` (alias `price_history`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.QuoteHistory`
* **Proto definition:** `Bars`

### RPC

* **Service:** `mt4_term_api.QuoteHistory`
* **Method:** `Bars(QuoteHistoryBarsRequest) → QuoteHistoryBarsReply`
* **Low-level client (generated):** `Mt4TermApi::QuoteHistory::Stub#bars(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Candles (open/high/low/close + tick volume + spread) for a symbol and timeframe, over a time window.
* **Why you need it.** Charts, indicators, backtests, volatility estimates.
* **Returns `[QuoteHistoryBar]`** oldest-first; the SDK follows the page token and retries `QUOTE_HISTORY_NOT_READY` for you.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # OHLC bars, oldest first, auto-paged. `from_utc`/`to_utc` are UNIX SECONDS
  # (to_utc nil/0 = up to now). Returns [QuoteHistoryBar]; raises ApiError.
  def bars(symbol, timeframe: :M1, from_utc:, to_utc: nil,
           page_size: 1000, not_ready_retries: 10) -> Array<Mt4TermApi::QuoteHistoryBar>
  alias price_history bars
end
```

**Request message:**

```protobuf
QuoteHistoryBarsRequest {
  string symbol                 = 1;
  QUOTE_HISTORY_TIMEFRAME timeframe = 2;
  int64  from_time              = 3;  // broker-time unix seconds
  int64  from_time_utc          = 4;  // UTC unix seconds   ← the SDK sets this
  int64  to_time                = 5;
  int64  to_time_utc            = 6;  // UTC unix seconds   ← the SDK sets this (0 = now)
  int32  page_size              = 7;
  string page_token             = 8;  // ← the SDK follows this to page
}
```

**Reply message:** `QuoteHistoryBarsReply { oneof response { QuoteHistoryBarsData data = 1; Error error = 2; } }` — `QuoteHistoryBarsData { repeated QuoteHistoryBar bars = 1; string next_page_token = 3; … }`. The SDK concatenates all pages.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `symbol` | `String` | **required** | Symbol name. |
| `timeframe` | `Symbol` | `:M1` | `:M1 :M5 :M15 :M30 :H1 :H4 :D1 :W1 :MN1` (mapped to `QHB_PERIOD_*`). |
| `from_utc` | `Integer` / `Time` | **required** | Window start, **UNIX SECONDS** (a `Time`'s `.to_i`). |
| `to_utc` | `Integer` / `nil` | `nil` | Window end, unix seconds; `nil`/`0` = up to now. |
| `page_size` | `Integer` | `1000` | Bars per page (paging is automatic). |
| `not_ready_retries` | `Integer` | `10` | Retries on `QUOTE_HISTORY_NOT_READY` (1 s apart). |

### `QUOTE_HISTORY_TIMEFRAME`

```protobuf
enum QUOTE_HISTORY_TIMEFRAME {       // value = minutes per bar
  QHB_PERIOD_M1 = 1;  QHB_PERIOD_M5  = 5;   QHB_PERIOD_M15 = 15;
  QHB_PERIOD_M30 = 30; QHB_PERIOD_H1 = 60;  QHB_PERIOD_H4  = 240;
  QHB_PERIOD_D1 = 1440; QHB_PERIOD_W1 = 10080; QHB_PERIOD_MN1 = 43200;
}
```

---

## ⬆️ Output — `[QuoteHistoryBar]`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `time` | `time` | `Integer` | Bar open time, **unix seconds** (broker time zone). |
| `time_utc` | `time_utc` | `Integer` | Bar open time, unix seconds (UTC). |
| `open` / `high` / `low` / `close` | … | `Float` | OHLC prices. |
| `tick_volume` | `tick_volume` | `Integer` | Number of ticks in the bar. |
| `spread` | `spread` | `Integer` | Spread in points. |
| `real_volume` | `real_volume` | `Integer` | Real volume (usually `0` on MT4). |

> **Times are plain unix seconds here** (not `Timestamp`). `Time.at(bar.time_utc).utc` gives a Ruby time.

---

## 🧩 Notes & Tips

* **`from_utc` is UNIX SECONDS**, not a `Timestamp` — pass `time.to_i` or an epoch. (The legacy [`quote_history`](./QuoteHistory.md) uses `Timestamp` instead.)
* **`to_utc: 0` (or `nil`)** means "up to now".
* **`QUOTE_HISTORY_NOT_READY`** — the terminal fetches history from the broker on demand; the SDK retries automatically (`not_ready_retries`).
* **Newest N bars** — easier via [`MT4Service#last_bars`](../../MT4Service/MT4Service.Overview.md), which widens the window until enough bars exist.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Last day of M5

```ruby
bars = acct.bars("EURUSD", timeframe: :M5, from_utc: Time.now.to_i - 86_400)
puts "#{bars.size} bars, last close #{bars.last&.close}"
```

### 2) A fixed window

```ruby
from = Time.utc(2026, 1, 1).to_i
to   = Time.utc(2026, 1, 8).to_i
acct.bars("EURUSD", timeframe: :H1, from_utc: from, to_utc: to).first(3).each do |b|
  puts "#{Time.at(b.time_utc).utc.strftime('%m-%d %H:%M')}  O#{b.open} C#{b.close}"
end
```

### 3) Simple ATR-style range

```ruby
bars = acct.bars("EURUSD", timeframe: :H1, from_utc: Time.now.to_i - 24 * 3600)
avg = bars.map { |b| b.high - b.low }.then { |r| r.empty? ? 0 : r.sum / r.size }
puts "avg H1 range: #{avg.round(5)}"
```

---

## 📚 See Also

* [QuoteHistory](./QuoteHistory.md) — the legacy (deprecated) bar endpoint.
* [Quote](./Quote.md) — the current tick.
* **Friendly layer:** [`MT4Service#bars` / `#last_bars`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
