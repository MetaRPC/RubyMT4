# MT4Account · Account Information — Overview

> The account's money picture **and** trading statistics: a one-call snapshot, aggregated stats, the equity curve, and per-order unrealized-P/L extrema.

These methods are **read-only**. `account_summary` lives on `mt4_term_api.AccountHelper`; the four statistics methods on `mt4_term_api.TradeStats`. Each returns the raw `*Data` (read fields with snake_case accessors), or raises `ApiError`.

## 📁 What lives here

* **[AccountSummary](./AccountSummary.md)** — **all account info** at once (login, balance, equity, credit, leverage, currency, margin / free margin / margin level / margin mode, server time). Returns the `EnumAccountTradeMode` and `EnumAccountMarginMode` enums.
* **[TradeStats](./TradeStats.md)** — **aggregated trade statistics** (drawdowns, profit factor, Sharpe ratio, expectancy, win/loss split, trades, growth %). Returns `StatsData`.
* **[TradeStatsEquityHistory](./TradeStatsEquityHistory.md)** — the stats **plus** equity/balance chart points and per-trade series. Returns `StatsWithChartsData`.
* **[EquityHistory](./EquityHistory.md)** — **just the equity-curve points** (balance, equity, drawdowns, realized/unrealized P/L). Returns `[EquityPointData]`.
* **[TradeUnrealizedPL](./TradeUnrealizedPL.md)** — the **max / min unrealized P/L** reached per open order. Returns `[TradeUnrealizedExtremaData]`.

---

## 🧭 Plain English

* **account_summary** → the **one-stop shop** for a complete snapshot. One RPC, everything for a dashboard, a pre-trade affordability check, or a connection heartbeat. MT4 (unlike MT5) *does* return `account_margin`, `account_margin_free`, `account_margin_level` here.
* **trade_stats** → a **performance report**: win rate, drawdown, profit factor, Sharpe, expectancy — computed over your history since a start time.
* **trade_stats_equity_history** → the same stats **and** the equity/balance curve in one call.
* **equity_history** → **just the curve** — points you can plot.
* **trade_unrealized_pl** → how far each open trade **swung** (best/worst unrealized P/L and when).

> Rule of thumb: need the **account state** → `account_summary`; need **performance** → `trade_stats`; need a **chart** → `equity_history`.

---

## Quick choose

| If you need…                                      | Use                           | Returns                 | Enums used |
| ------------------------------------------------- | ----------------------------- | ----------------------- | ---------- |
| Complete account snapshot (all values)            | `account_summary`             | `AccountSummaryData`    | **Output:** `EnumAccountTradeMode`, `EnumAccountMarginMode` |
| Performance report                                | `trade_stats`                 | `StatsData`             | — |
| Stats + equity/balance charts                     | `trade_stats_equity_history`  | `StatsWithChartsData`   | — |
| Equity-curve points only                          | `equity_history`              | `[EquityPointData]`     | — |
| Per-order unrealized-P/L extrema                  | `trade_unrealized_pl`         | `[TradeUnrealizedExtremaData]` | — |

---

## ❌ Cross-refs & gotchas

* **Margin is in the summary** — `account_summary` already returns `account_margin`, `account_margin_free`, `account_margin_level` and `account_margin_mode`. MT4 has **no** `AccountInfoDouble` RPC (that is MT5), so there is no single-property getter — read the field off the summary.
* **Floating profit** — the summary carries no dedicated profit field; compute `account_equity − account_balance − account_credit` (MT4: Equity = Balance + Credit + Floating).
* **Stats window bound is a STRING** — the four statistics requests take an optional `from` (broker time, `yyyy-MM-ddTHH:mm:ss`) **or** `from_utc` (UTC ISO-8601) — send one, not both; omit for the full account history. The SDK converts a Ruby `Time` to the ISO string for you.
* **Timeouts** — stats run on a longer deadline (120 s) because they scan history; simple reads use the account's `timeout` (default `60` s).

---

## 🟢 Minimal snippets

```ruby
# Complete account snapshot
s = acct.account_summary
puts "Balance: #{s.account_balance.round(2)}, Equity: #{s.account_equity.round(2)}, Leverage: 1:#{s.account_leverage}"
```

```ruby
# Performance stats for the last 30 days
st = acct.trade_stats(from_utc: Time.now.utc - 30 * 24 * 3600)
puts "Trades: #{st.trades}  Profit factor: #{st.profit_factor.round(2)}  Total P/L: #{st.summary.total_profit.round(2)}"
```

```ruby
# Equity curve points
pts = acct.equity_history(from_utc: Time.now.utc - 7 * 24 * 3600)
puts "#{pts.size} points, last equity #{pts.last&.equity}"
```

```ruby
# How far each open trade swung
acct.trade_unrealized_pl(from_utc: Time.now.utc - 24 * 3600).each do |x|
  puts "##{x.ticket} #{x.symbol}: max +#{x.max_unrealized_pl.round(2)} / min #{x.min_unrealized_pl.round(2)}"
end
```

---

## 🧱 Enums used in Account Information

Only `account_summary` carries enums — the statistics methods return plain numeric fields.

| Method | Output enum | Accessor | Values |
|--------|-------------|----------|--------|
| **account_summary** | `EnumAccountTradeMode` | `account_trade_mode` | `:ACCOUNT_TRADE_MODE_DEMO` (0) · `:..._CONTEST` (1) · `:..._REAL` (2) |
| **account_summary** | `EnumAccountMarginMode` | `account_margin_mode` | `:ACCOUNT_MARGIN_MODE_RETAIL_NETTING` (0) · `:..._EXCHANGE` (1) · `:..._RETAIL_HEDGING` (2) |

```ruby
s = acct.account_summary
case s.account_trade_mode
when :ACCOUNT_TRADE_MODE_DEMO then puts "Demo account"
when :ACCOUNT_TRADE_MODE_REAL then puts "Real account"
end
```

---

## See also

* **Symbols & Quotes:** [Symbols & Quotes — Overview](../3.%20Symbols_Quotes/Symbols_Quotes.Overview.md) — prices, specs and the server time zone.
* **Friendly layer:** [`MT4Service#account_info`](../../MT4Service/MT4Service.Overview.md) returns a named `Account` Struct (plain fields, UTC times).

---

**Back to:** [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
