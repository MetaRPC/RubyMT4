# 📊 Aggregated Trade Statistics

> **Request:** a full performance report (`StatsData`) computed over your trading history since a start time — drawdowns, profit factor, Sharpe ratio, expectancy, win/loss split and more.

**API Information:**

* **Low-level API:** `MT4Account#trade_stats` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradeStats`
* **Proto definition:** `TradeStats` (defined in `mt4-term-api-trade-stats.proto`)

### RPC

* **Service:** `mt4_term_api.TradeStats`
* **Method:** `TradeStats(TradeStatsRequest) → TradeStatsReply`
* **Low-level client (generated):** `Mt4TermApi::TradeStats::Stub#trade_stats(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** One RPC that scans your closed-trade history and returns dozens of aggregate metrics.
* **Why you need it.** Performance reports, strategy scorecards, risk dashboards — without pulling every deal yourself.
* **Window.** Pass a start time (`from_utc` or broker-local `from`); omit it for the whole account history.

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # Aggregated trading statistics since `from_utc` (or broker-local `from`).
  # Returns the raw StatsData; raises ApiError on failure.
  def trade_stats(from_utc: nil, from: nil) -> Mt4TermApi::StatsData
end
```

**Request message:**

```protobuf
TradeStatsRequest {
  string from     = 1;  // broker server time, "yyyy-MM-ddTHH:mm:ss"
  string from_utc = 2;  // UTC ISO-8601
}
```

> **⚠️ The window bound is a STRING, not a Timestamp.** Send **one** of `from` / `from_utc`, or neither for full history. The SDK converts a Ruby `Time` to the ISO string for you — `trade_stats(from_utc: Time.now.utc - 86_400)`.

**Reply message:** `TradeStatsReply { oneof response { StatsData data = 1; Error error = 2; } }`

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `from_utc` | `Time` / `String` / `Integer` / `nil` | `nil` | Window start in **UTC**. A `Time`/epoch is converted to ISO-8601 for you. |
| `from` | `Time` / `String` / `nil` | `nil` | Window start in **broker server time** (`yyyy-MM-ddTHH:mm:ss`). Use instead of `from_utc`, not both. |

Runs on a **120 s** deadline (it scans history).

---

## ⬆️ Output — `StatsData`

**Headline scalars:**

| Field | Type | Description |
| ----- | ---- | ----------- |
| `trades` | `Integer` | Number of closed trades counted. |
| `profit_factor` | `Float` | Gross profit ÷ gross loss (`> 1` = profitable). |
| `sharpe_ratio` | `Float` | Risk-adjusted return. |
| `standard_deviation` | `Float` | Dispersion of trade results. |
| `ghpr` | `Float` | Geometric holding-period return. |
| `growth_percent` | `Float` | Account growth over the window, %. |
| `pips` | `Float` | Net pips. |
| `lots` | `Float` | Total volume traded, lots. |
| `comissions` | `Float` | Total commissions (proto spelling: `comissions`). |
| `deposits` / `withdrawals` | `Float` | Cash in / out over the window. |
| `average_trade_length` | `String` | Mean holding time (human-readable). |
| `max_balance_drawdown_raw` / `_relative` | `Float` | Deepest balance drawdown (money / fraction). |
| `max_equity_drawdown_raw` / `_relative` | `Float` | Deepest equity drawdown (money / fraction). |

**Nested messages** (each carries a value plus context):

| Field | Message | What it holds |
| ----- | ------- | ------------- |
| `summary` | `TradeSummaryData` | `open_trades`, `open_profit`, `day_profit`, `week_profit`, `month_profit`, `total_profit`. |
| `profitability` | `ProfitabilityData` | `won_trades`, `won_trades_percent`, `lost_trades`, `lost_trades_percent`. |
| `average_win` / `average_lost` | money value | Mean win / loss. |
| `longs_won` / `shorts_won` | won/total split | Long- vs short-side win rate. |
| `best_trade` / `worst_trade` | money value | Largest single win / loss. |
| `best_trade_pips` / `worst_trade_pips` | pip value | Best / worst in pips. |
| `z_score` / `expectancy` | value | Streak significance / expected value per trade. |
| `markets` | `[…]` (repeated) | Per-symbol breakdown. |

> Explore the exact nested fields offline with the [Protobuf Inspector](../../All_Guides/PROTOBUF_INSPECTOR_GUIDE.md): `ruby examples/demos/helpers/17_protobuf_inspector.rb StatsData`.

---

## 🧩 Notes & Tips

* **One window bound.** Pass `from_utc` **or** `from`, never both.
* **Proto spelling.** The commission field is `comissions` (single "m") — a server-side spelling, kept as-is.
* **Empty history.** With no trades in the window, counts are `0` and ratios may be `0` / `NaN`-like — guard before dividing.
* **Errors are exceptions:** wrap in `begin/rescue` for `MetaRPC::MT4::ApiError`.

---

## 🔗 Usage Examples

### 1) Basic report

```ruby
st = acct.trade_stats(from_utc: Time.now.utc - 30 * 24 * 3600)
puts "Trades: #{st.trades}"
puts "Profit factor: #{st.profit_factor.round(2)}"
puts "Sharpe: #{st.sharpe_ratio.round(2)}"
puts "Total P/L: #{st.summary.total_profit.round(2)}"
```

### 2) Win/loss split

```ruby
p = acct.trade_stats(from_utc: Time.now.utc - 7 * 24 * 3600).profitability
puts "Won #{p.won_trades} (#{p.won_trades_percent.round(1)}%) / Lost #{p.lost_trades} (#{p.lost_trades_percent.round(1)}%)"
```

### 3) Drawdown guard

```ruby
st = acct.trade_stats   # full history
if st.max_equity_drawdown_relative > 0.3
  puts "⚠️ Equity drawdown exceeded 30% at some point"
end
```

### 4) Scorecard line

```ruby
st = acct.trade_stats(from_utc: Time.now.utc - 90 * 24 * 3600)
puts format("90d | %d trades | PF %.2f | growth %.1f%% | maxDD %.1f%%",
            st.trades, st.profit_factor, st.growth_percent, st.max_equity_drawdown_relative * 100)
```

### 5) Error handling

```ruby
def safe_stats(acct, **win)
  acct.trade_stats(**win)
rescue MetaRPC::MT4::ApiError, GRPC::BadStatus => e
  warn "stats failed: #{e.message}"
  nil
end
```

---

## 📚 See Also

* [TradeStatsEquityHistory](./TradeStatsEquityHistory.md) — these stats **plus** the equity/balance chart.
* [EquityHistory](./EquityHistory.md) — just the equity-curve points.
* [TradeUnrealizedPL](./TradeUnrealizedPL.md) — per-order unrealized-P/L extrema.
* [AccountSummary](./AccountSummary.md) — current balance/equity snapshot.

---

**Back to:** [Account Information — Overview](./Account_Information.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
