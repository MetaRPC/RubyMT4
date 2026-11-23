# 🧠 Adaptive Market Mode Preset

> Read two cheap market signals — spread and recent volatility — and **recommend which orchestrator** fits current conditions. ✅ Read-only analysis.

**Demo:** `examples/demos/presets/16_adaptive_preset.rb` · **Run:** `ruby examples/demos/main.rb 16`

---

## 💡 What it is

A preset is the **router** above the orchestrators. Rather than always running one playbook, it looks at the market *now* and points you at the strategy that suits it: trend-follow when it's moving, harvest the range when it's calm, step back when it's illiquid. This demo prints the recommendation; a real preset would launch that orchestrator.

---

## 🧠 Decision logic

| Condition | Recommend | Why |
|-----------|-----------|-----|
| spread **> 50 pts** | **[14 Risk Manager](../Orchestrators/RiskManager.md)** | illiquid / costly — don't enter, just watch risk |
| ATR **> 400 pts** | **[11 Trailing Stop](../Orchestrators/TrailingStop.md)** | high volatility — ride a move with a trailing stop |
| otherwise (calm) | **[13 Grid Trader](../Orchestrators/GridTrader.md)** | range-bound — harvest the range with a pending grid |

Volatility is a simple ATR-style proxy: the average `high − low` of the last 24 H1 candles, in points.

---

## 🧱 Composed from (MT4Sugar)

| Step | Methods |
|------|---------|
| **Signals** | [`spread`](../../MT4Sugar/3.%20Prices_Quotes.md) · [`symbol_point`](../../MT4Sugar/9.%20Symbol_Information.md) · [`last_bars`](../../MT4Sugar/9.%20Symbol_Information.md) |
| **Decide** | plain Ruby `if/elsif` on the two signals |

---

## 🔧 Code walkthrough

```ruby
point = sugar.symbol_point(sym) || 0.0001

# 1. SIGNALS
spread_pts = (sugar.spread(sym) / point).round
bars = sugar.last_bars(sym, timeframe: :H1, count: 24)
ranges = bars.map { |b| (b.high - b.low) / point }
atr_pts = ranges.empty? ? 0 : (ranges.sum / ranges.size).round

# 2. DECIDE
pick =
  if    spread_pts > 50 then "14 Risk manager — spread wide, avoid entries"
  elsif atr_pts   > 400 then "11 Trailing stop — high volatility, ride it"
  else                        "13 Grid trader — calm, harvest the range"
  end
puts "→ #{pick}"
```

---

## ⚙️ Tunables

| Name | Meaning |
|------|---------|
| spread threshold (`50`) | points above which conditions are "too illiquid to enter" |
| ATR threshold (`400`) | points above which volatility is "high enough to trend-follow" |
| H1 lookback (`24`) | how many candles feed the volatility proxy |

**Make it real:** after choosing, actually launch that orchestrator (call its proc), re-evaluate on a schedule, and add more signals (session time, news windows, trend filters).

---

## 🛠️ Make it your own — and how it combines

**Why it's shaped this way.** A preset separates **"what are the conditions?"** from **"what do I do?"** — so you can change the playbook without touching the strategies, and vice-versa. The demo only *prints* the pick; a real preset *launches* it.

**What to consider when you adapt it:**

* **Signals are cheap — be generous.** Spread + ATR is a start; add a trend read (SMA slope from `last_bars`), a session / time-of-day filter, and a news / illiquidity guard.
* **Thresholds are symbol-specific.** The `50`-pt spread / `400`-pt ATR fit a major — derive them from the symbol (a fraction of its average range) rather than hard-coding.
* **Add hysteresis.** Don't switch on a single reading — require the condition to hold for N checks, or you'll flip-flop between grid and trailing right at the boundary.
* **Launch, then re-evaluate.** After picking, actually run that orchestrator's loop; re-run the preset on a **schedule** (not every tick) to decide whether to switch.

**How it combines.** The preset **sits on top** — it chooses which orchestrator *opens*. Keep the [Risk Manager](../Orchestrators/RiskManager.md) independent **below** it: the preset chooses offence, the supervisor is always-on defence. See the layering model in the [Master Overview](../Strategies.Master.Overview.md#combining-orchestrators-presets).

---

## ⚠️ Safety

**Read-only** — it only reads the spread and recent bars and prints a recommendation. It places no orders.

---

## 📚 See also

* Orchestrators it routes to: [Trailing Stop](../Orchestrators/TrailingStop.md) · [Grid Trader](../Orchestrators/GridTrader.md) · [Risk Manager](../Orchestrators/RiskManager.md)
* [MT4Sugar · Symbol Information](../../MT4Sugar/9.%20Symbol_Information.md)

**Back to:** [Strategies — Master Overview](../Strategies.Master.Overview.md)
