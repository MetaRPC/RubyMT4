# 💹 Equity Curve Points

> **Request:** just the equity / balance curve (`[EquityPointData]`) over a window — the points you plot.

**API Information:**

* **Low-level API:** `MT4Account#equity_history` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.TradeStats`
* **Proto definition:** `EquityHistory`

### RPC

* **Service:** `mt4_term_api.TradeStats`
* **Method:** `EquityHistory(EquityHistoryRequest) → EquityHistoryReply`
* **Low-level client (generated):** `Mt4TermApi::TradeStats::Stub#equity_history(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The equity-curve points only — no aggregate stats.
* **Why you need it.** Plot an equity / balance chart; feed a drawdown or risk visual.
* **Returns an array.** The SDK unwraps the reply and returns `data.points` as a ready array.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Equity / balance curve points since `from_utc` (or broker-local `from`).
  # `exclude_same_bars` drops consecutive flat points. Returns [EquityPointData].
  def equity_history(from_utc: nil, from: nil, exclude_same_bars: false) -> Array<Mt4TermApi::EquityPointData>
end
```

**Request message:**

```protobuf
EquityHistoryRequest {
  string from              = 1;  // broker server time, "yyyy-MM-ddTHH:mm:ss"
  string from_utc          = 2;  // UTC ISO-8601
  bool   exclude_same_bars = 3;  // drop flat/duplicate points
}
```

**Reply message:** `EquityHistoryReply { oneof response { EquityHistoryData data = 1; Error error = 2; } }` — `EquityHistoryData { repeated EquityPointData points = 1; }`. The SDK returns `points` as an array.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `from_utc` | `Time` / `String` / `nil` | `nil` | Window start in **UTC** (converted to ISO-8601 for you). |
| `from` | `Time` / `String` / `nil` | `nil` | Window start in **broker server time**. Use instead of `from_utc`. |
| `exclude_same_bars` | `Boolean` | `false` | Skip consecutive points with no change. |

Runs on a **120 s** deadline.

---

## ⬆️ Output — `[EquityPointData]`

Each point:

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `time` | `time` | `Timestamp` | Point time (broker time zone). `.seconds` → unix. |
| `time_utc` | `time_utc` | `Timestamp` | The same moment in UTC. |
| `balance` | `balance` | `Float` | Account balance at this point. |
| `equity` | `equity` | `Float` | Account equity at this point. |
| `balance_drawdown_raw` | `balance_drawdown_raw` | `Float` | Balance drawdown (money). |
| `balance_drawdown_relative` | `balance_drawdown_relative` | `Float` | Balance drawdown (fraction). |
| `equity_drawdown_raw` | `equity_drawdown_raw` | `Float` | Equity drawdown (money). |
| `equity_drawdown_relative` | `equity_drawdown_relative` | `Float` | Equity drawdown (fraction). |
| `realized_pl` | `realized_pl` | `Float` | Realized P/L up to this point. |
| `unrealized_pl` | `unrealized_pl` | `Float` | Open-trade P/L at this point. |
| `cash_flow` | `cash_flow` | `Float` | Deposits / withdrawals at this point. |

---

## 🧩 Notes & Tips

* **One window bound** — `from_utc` **or** `from`; omit for full history.
* **`exclude_same_bars: true`** for long windows → fewer, more meaningful points.
* **Timestamps** are `Timestamp` — read `.seconds`, or convert with [`server_timezone`](../3.%20Symbols_Quotes/ServerTimezone.md).
* **Need the numbers too?** [`trade_stats_equity_history`](./TradeStatsEquityHistory.md) returns stats + charts together.

---

## 🔗 Usage Examples

### 1) Last balance & equity

```ruby
pts = acct.equity_history(from_utc: Time.now.utc - 7 * 24 * 3600)
last = pts.last
puts "#{pts.size} points, equity #{last&.equity&.round(2)} balance #{last&.balance&.round(2)}"
```

### 2) Max relative equity drawdown on the curve

```ruby
pts = acct.equity_history(from_utc: Time.now.utc - 30 * 24 * 3600, exclude_same_bars: true)
worst = pts.map(&:equity_drawdown_relative).max || 0.0
puts "Max equity drawdown on curve: #{(worst * 100).round(1)}%"
```

### 3) Export CSV

```ruby
require "csv"
CSV.open("equity.csv", "w") do |csv|
  csv << %w[time_utc balance equity]
  acct.equity_history(from_utc: Time.now.utc - 30 * 24 * 3600).each do |p|
    csv << [Time.at(p.time_utc.seconds).utc.iso8601, p.balance, p.equity]
  end
end
```

---

## 📚 See Also

* [TradeStats](./TradeStats.md) — aggregate metrics.
* [TradeStatsEquityHistory](./TradeStatsEquityHistory.md) — stats + charts in one call.
* [TradeUnrealizedPL](./TradeUnrealizedPL.md) — per-order unrealized-P/L extrema.

---

**Back to:** [Account Information — Overview](./Account_Information.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
