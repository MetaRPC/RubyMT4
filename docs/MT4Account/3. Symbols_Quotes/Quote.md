# 💱 Getting a Quote

> **Request:** the last tick for one symbol (`QuoteData`: bid, ask, high, low, time). **Prices come from here.**

**API Information:**

* **Low-level API:** `MT4Account#quote` (alias `symbol_info_tick`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.MarketInfo`
* **Proto definition:** `Quote`

### RPC

* **Service:** `mt4_term_api.MarketInfo`
* **Method:** `Quote(QuoteRequest) → QuoteReply`
* **Low-level client (generated):** `Mt4TermApi::MarketInfo::Stub#quote(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The latest bid/ask (plus session high/low and timestamps) for a single symbol.
* **Why you need it.** Price before trading, spread checks, live dashboards.
* **Returns `QuoteData`.** Read `bid` / `ask` with snake_case accessors.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Last tick for one symbol. Returns QuoteData; raises ApiError on failure.
  def quote(symbol) -> Mt4TermApi::QuoteData
  alias symbol_info_tick quote
end
```

**Request message:** `QuoteRequest { string symbol = 1; }`

**Reply message:** `QuoteReply { oneof response { QuoteData data = 1; Error error = 2; } }`

---

## 🔽 Input

| Argument | Type | Description |
|----------|------|-------------|
| `symbol` | `String` | Symbol name, e.g. `"EURUSD"`. |

---

## ⬆️ Output — `QuoteData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `symbol` | `symbol` | `String` | The symbol. |
| `bid` | `bid` | `Float` | Best bid. |
| `ask` | `ask` | `Float` | Best ask. |
| `high` | `high` | `Float` | Session high. |
| `low` | `low` | `Float` | Session low. |
| `date_time` | `date_time` | `Timestamp` | Tick time (broker time zone). |
| `date_time_utc` | `date_time_utc` | `Timestamp` | Tick time in UTC. |

> **Spread** = `ask - bid`. There is **no `last` or volume** field on MT4 `QuoteData` (those are MT5 tick fields).

---

## 🧩 Notes & Tips

* **Freshly added symbols** can answer `bid/ask = 0` for a moment — call [`symbol_select`](./SymbolSelect.md) first and retry.
* **No `last` price** — MT4 quotes carry bid/ask/high/low only.
* **Timestamps** are `Timestamp` — read `.seconds`.
* **Many at once?** Use [`quote_many`](./QuoteMany.md) instead of a loop.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Bid / ask / spread

```ruby
q = acct.quote("EURUSD")
puts "bid #{q.bid}  ask #{q.ask}  spread #{(q.ask - q.bid).round(5)}"
```

### 2) Guard against a cold symbol

```ruby
acct.symbol_select("XAUUSD")
q = acct.quote("XAUUSD")
q = acct.quote("XAUUSD") if q.bid.zero?   # one retry after select
puts "#{q.bid}/#{q.ask}"
```

### 3) Tick time in UTC

```ruby
q = acct.quote("EURUSD")
puts "as of #{Time.at(q.date_time_utc.seconds).utc.iso8601}"
```

---

## 📚 See Also

* [QuoteMany](./QuoteMany.md) — several symbols in one call.
* [SymbolSelect](./SymbolSelect.md) — warm up a symbol first.
* **Streaming:** [OnSymbolTick](../5.%20Streaming_Methods/OnSymbolTick.md) — push ticks instead of polling.
* **Friendly layer:** [`MT4Service#quote`](../../MT4Service/MT4Service.Overview.md) → a `Quote` struct with `spread`.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
