# 🛡️ Risk Manager Orchestrator

> Poll the account, and if the floating drawdown breaches a limit, **flatten everything** (kill-switch). ✅ Safe by default — `dry_run` only reports what *would* happen.

**Demo:** `examples/demos/orchestrators/14_risk_manager.rb` · **Run:** `ruby examples/demos/main.rb 14`

---

## 💡 What it is

A kill-switch caps the worst case. Instead of hoping a losing book recovers, it watches the floating loss and, once it reaches a fraction of the balance, closes **every** open order at once. The demo ships in **dry-run** mode: it reports the breach but doesn't trade — flip one flag to arm it.

---

## 🧠 Strategy logic

Each check computes the floating drawdown as a fraction of balance:

```
floating = equity − balance − credit        # MT4 floating P/L (sugar.profit)
drawdown = floating < 0 ? -floating / balance : 0
```

and fires the kill-switch when it crosses the limit:

```
if drawdown ≥ max_drawdown
  dry_run ? report("would fire") : close_all
  stop
```

---

## 🧱 Composed from (MT4Sugar)

| Step | Methods |
|------|---------|
| **Monitor** | [`balance`](../../MT4Sugar/2.%20Money_Account.md) · [`equity`](../../MT4Sugar/2.%20Money_Account.md) · [`profit`](../../MT4Sugar/2.%20Money_Account.md) · [`count_orders`](../../MT4Sugar/7.%20Order_Information.md) |
| **Enforce** | [`close_all`](../../MT4Sugar/6.%20Order_Management.md) |

---

## 🔧 Code walkthrough

```ruby
dry_run = true          # true = report only, never close
max_drawdown = 0.50     # kill-switch at 50% of balance lost (floating)
checks = 3

checks.times do |i|
  sleep 1
  balance  = sugar.balance
  equity   = sugar.equity
  floating = sugar.profit                       # equity − balance − credit
  dd = balance.zero? ? 0.0 : (floating.negative? ? -floating / balance : 0.0)

  puts "balance #{balance.round(2)}  equity #{equity.round(2)}  drawdown #{(dd * 100).round(1)}%  orders #{sugar.count_orders}"

  if dd >= max_drawdown
    dry_run ? puts("KILL-SWITCH would fire") : sugar.close_all
    break
  end
end
```

---

## ⚙️ Tunables

| Name | Meaning |
|------|---------|
| `dry_run` | `true` = report only; `false` = actually flatten on breach |
| `max_drawdown` | drawdown limit as a fraction of balance (`0.50` = 50%) |
| `checks` | how many times the demo polls |

**Make it real:** run the loop continuously (or drive it from [`on_opened_orders_profit`](../../MT4Sugar/11.%20Streaming.md)), set `dry_run = false`, and add an alert (email / webhook) when the switch fires.

---

## 🛠️ Make it your own — and how it combines

**Why it's shaped this way.** It has **no entry on purpose** — it's a *supervisor*, the one component whose job is to be boring and always right. `dry_run` defaults `true` so you can watch it think before it's allowed to trade.

**What to consider when you adapt it:**

* **What triggers the switch.** Floating-drawdown vs balance is one rule; you might add an equity stop, a daily-loss limit, a margin-level floor (`margin_level < 150`), or a max-open-orders cap.
* **Run it continuously.** Replace the fixed `checks` loop with a real loop (or drive it from [`on_opened_orders_profit`](../../MT4Sugar/11.%20Streaming.md)) so it's always watching.
* **Arm it deliberately.** Flip `dry_run = false` only after you trust the thresholds on a demo; add an alert (log / webhook) when it fires.
* **It must win ties.** When the supervisor says *flat*, the entry strategies must not immediately re-open — gate them on a shared "halted" flag.

**How it combines.** Run it **alongside** every other orchestrator, on its own thread. It reads the *whole* account (not one `magic`), so it overrides all strategies at once — the account-level backstop in the layering model from the [Master Overview](../Strategies.Master.Overview.md#combining-orchestrators-presets).

---

## ⚠️ Safety

**Dry-run by default — reads only, never trades.** With `dry_run = false` it will [`close_all`](../../MT4Sugar/6.%20Order_Management.md) open orders on a breach. Test the armed version on a demo account with tiny orders.

---

## 📚 See also

* [Trailing Stop](./TrailingStop.md) · [Grid Trader](./GridTrader.md) · [Adaptive Preset](../Presets/AdaptiveMarketMode.md)
* [MT4Sugar · Money & Account](../../MT4Sugar/2.%20Money_Account.md)

**Back to:** [Strategies — Master Overview](../Strategies.Master.Overview.md)
