# 💱 Getting Many Quotes

> **Request:** the last tick for **several symbols** in one call (`[QuoteData]`).

**API Information:**

* **Low-level API:** `MT4Account#quote_many` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.MarketInfo`
* **Proto definition:** `QuoteMany`

### RPC

* **Service:** `mt4_term_api.MarketInfo`
* **Method:** `QuoteMany(QuoteManyRequest) → QuoteManyReply`
* **Low-level client (generated):** `Mt4TermApi::MarketInfo::Stub#quote_many(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Bid/ask for a batch of symbols in a single round-trip.
* **Why you need it.** A watchlist / dashboard — one call instead of N `quote` calls.
* **Returns `[QuoteData]`.** Same fields as [`quote`](./Quote.md).

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Last ticks for several symbols in one call. Returns [QuoteData]; raises ApiError.
  def quote_many(symbols) -> Array<Mt4TermApi::QuoteData>
end
```

**Request message:** `QuoteManyRequest { repeated string symbols = 1; }`

**Reply message:** `QuoteManyReply { oneof response { QuoteManyData data = 1; Error error = 2; } }` — `QuoteManyData { repeated QuoteData quotes = 1; }`. The SDK returns `quotes` as an array.

---

## 🔽 Input

| Argument | Type | Description |
|----------|------|-------------|
| `symbols` | `Array<String>` (or a single `String`) | Symbols to quote. The SDK wraps a lone string in an array. |

---

## ⬆️ Output — `[QuoteData]`

One [`QuoteData`](./Quote.md#output-quotedata) per symbol: `symbol`, `bid`, `ask`, `high`, `low`, `date_time`, `date_time_utc`. Order follows the request; a cold symbol may come back with `bid/ask = 0`.

---

## 🧩 Notes & Tips

* **Cheaper than a loop** — one request, one response for the whole batch.
* **Warm up first** — `symbol_select` each new symbol (or call `tick_value_with_size`, which adds them) to avoid `0/0`.
* **Match by `symbol`** — index the result by `q.symbol`, don't assume positional alignment if some are unknown.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Watchlist snapshot

```ruby
acct.quote_many(%w[EURUSD GBPUSD USDJPY]).each do |q|
  puts format("%-8s %s / %s", q.symbol, q.bid, q.ask)
end
```

### 2) Index by symbol

```ruby
by = acct.quote_many(%w[EURUSD GBPUSD]).to_h { |q| [q.symbol, q] }
puts "EURUSD ask: #{by['EURUSD']&.ask}"
```

### 3) Spread scan

```ruby
acct.quote_many(acct.symbols.first(20)).each do |q|
  spread = (q.ask - q.bid)
  puts "#{q.symbol}: #{spread.round(5)}" if spread.positive?
end
```

---

## 📚 See Also

* [Quote](./Quote.md) — single-symbol version.
* [SymbolSelect](./SymbolSelect.md) — warm up symbols first.
* **Friendly layer:** [`MT4Service#quote_many`](../../MT4Service/MT4Service.Overview.md) → `Quote` structs with `spread`.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
