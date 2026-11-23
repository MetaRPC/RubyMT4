# 📈 Trade Stats + Equity Charts

> **Request:** the full statistics report **and** the equity/balance chart series in one call (`StatsWithChartsData`).

**API Information:**

* **Low-level API:** `MT4Account#trade_stats_equity_history` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradeStats`
* **Proto definition:** `TradeStatsEquityHistory`

### RPC

* **Service:** `mt4_term_api.TradeStats`
* **Method:** `TradeStatsEquityHistory(TradeStatsEquityHistoryRequest) → TradeStatsEquityHistoryReply`
* **Low-level client (generated):** `Mt4TermApi::TradeStats::Stub#trade_stats_equity_history(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Everything [`trade_stats`](./TradeStats.md) returns, bundled with the **equity / balance chart points** and per-trade series — one round-trip for a complete report page.
* **Why you need it.** Draw an equity curve *and* show the headline numbers without two calls.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Stats + equity/balance charts since `from_utc` (or broker-local `from`).
  # `exclude_same_bars` drops consecutive flat chart points. Returns StatsWithChartsData.
  def trade_stats_equity_history(from_utc: nil, from: nil, exclude_same_bars: false) -> Mt4TermApi::StatsWithChartsData
end
```

**Request message:**

```protobuf
TradeStatsEquityHistoryRequest {
  string from              = 1;  // broker server time, "yyyy-MM-ddTHH:mm:ss"
  string from_utc          = 2;  // UTC ISO-8601
  bool   exclude_same_bars = 3;  // drop flat/duplicate chart points
}
```

**Reply message:** `TradeStatsEquityHistoryReply { oneof response { StatsWithChartsData data = 1; Error error = 2; } }`

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `from_utc` | `Time` / `String` / `nil` | `nil` | Window start in **UTC** (converted to ISO-8601 for you). |
| `from` | `Time` / `String` / `nil` | `nil` | Window start in **broker server time**. Use instead of `from_utc`. |
| `exclude_same_bars` | `Boolean` | `false` | Skip consecutive chart points with no change (smaller payload). |

Runs on a **120 s** deadline.

---

## ⬆️ Output — `StatsWithChartsData`

| Field | Type | Description |
| ----- | ---- | ----------- |
| `stats` | `StatsData` | The full stats object — see [TradeStats](./TradeStats.md) for every field. |
| `charts` | `[…]` (repeated) | Equity / balance chart points over the window. |
| `trades` | `[…]` (repeated) | Per-trade series used to build the charts. |
| `open_trades` | `[…]` (repeated) | Trades still open at the end of the window. |

> Field-level detail of the nested series is best explored offline: `ruby examples/demos/helpers/17_protobuf_inspector.rb StatsWithChartsData`.

---

## 🧩 Notes & Tips

* **One window bound** — `from_utc` **or** `from`, not both; omit for full history.
* **Use `exclude_same_bars: true`** for long windows to shrink the chart payload.
* **Just the curve?** If you don't need the stats, [`equity_history`](./EquityHistory.md) returns only the points.
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Report page: numbers + curve

```ruby
d = acct.trade_stats_equity_history(from_utc: Time.now.utc - 30 * 24 * 3600, exclude_same_bars: true)
puts "Trades #{d.stats.trades}  PF #{d.stats.profit_factor.round(2)}"
puts "Chart points: #{d.charts.size}  trades in series: #{d.trades.size}"
```

### 2) Still-open trades at window end

```ruby
d = acct.trade_stats_equity_history(from_utc: Time.now.utc - 7 * 24 * 3600)
puts "Open at end: #{d.open_trades.size}"
```

### 3) Error handling

```ruby
begin
  d = acct.trade_stats_equity_history(from_utc: Time.now.utc - 86_400)
rescue MetaRPC::MT4::ApiError => e
  warn "stats+charts failed: #{e.code}"
end
```

---

## 📚 See Also

* [TradeStats](./TradeStats.md) — the stats object without the charts.
* [EquityHistory](./EquityHistory.md) — just the equity-curve points.
* [TradeUnrealizedPL](./TradeUnrealizedPL.md) — per-order unrealized-P/L extrema.

---

**Back to:** [Account Information — Overview](./Account_Information.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
