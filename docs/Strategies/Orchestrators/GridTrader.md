# 🪜 Grid Trader Orchestrator

> Bracket the market with a symmetric grid of pending orders, list them, then remove them. ⚠ Places real (demo) pending orders, then cancels them.

**Demo:** `examples/demos/orchestrators/13_grid_trader.rb` · **Run:** `ruby examples/demos/main.rb 13`

---

## 💡 What it is

A grid surrounds the current price with pending orders so you're positioned **whichever way the market breaks**. This demo shows the mechanics — it **places** the grid and then **removes** it (no position management), so you can see how limits and stops bracket the market.

---

## 🧠 Strategy logic

At each level `i` (spaced `step_pts` apart from the market) it places **four** pending orders:

| Order | Where | Fires when… |
|-------|-------|-------------|
| `buy_limit` | below the market | price **dips** into it (join the pullback) |
| `sell_limit` | above the market | price **rallies** into it (fade the spike) |
| `buy_stop` | above the market | price **breaks out up** |
| `sell_stop` | below the market | price **breaks down** |

Limits **face** the market (mean-reversion); stops **break out** with momentum. Whichever zone price enters, an order triggers.

---

## 🧱 Composed from (MT4Sugar)

| Step | Methods |
|------|---------|
| **Place** | [`price`](../../MT4Sugar/3.%20Prices_Quotes.md) · [`buy_limit`/`sell_limit`/`buy_stop`/`sell_stop`](../../MT4Sugar/4.%20Simple_Trading.md) |
| **List** | [`pending(symbol:)`](../../MT4Sugar/7.%20Order_Information.md) |
| **Remove** | [`cancel_order(ticket)`](../../MT4Sugar/6.%20Order_Management.md) (deletes a pending) |

---

## 🔧 Code walkthrough

```ruby
levels = 2         # per side
step_pts = 300     # spacing, points
q = sugar.price(sym)

placed = []
(1..levels).each do |i|
  buy_price  = (q.bid - i * step_pts * point).round(digits)   # below
  sell_price = (q.ask + i * step_pts * point).round(digits)   # above
  b  = sugar.buy_limit(sym,  vol, buy_price)
  s  = sugar.sell_limit(sym, vol, sell_price)
  bs = sugar.buy_stop(sym,   vol, sell_price)   # breakout up
  ss = sugar.sell_stop(sym,  vol, buy_price)    # breakout down
  placed.push(b.ticket, s.ticket, bs.ticket, ss.ticket)   # MT4: keep the tickets
end

# remove the grid — cancel_order on a pending ticket deletes it
placed.each { |t| sugar.cancel_order(t) rescue nil }
```

---

## ⚙️ Tunables

| Name | Meaning |
|------|---------|
| `levels` | number of price levels per side |
| `step_pts` | spacing between levels, in points (wider = fewer, farther orders) |

**Make it real:** keep the grid live, watch fills via [`on_trade`](../../MT4Sugar/11.%20Streaming.md), and add take-profit / stop-loss and a [`close_all_by_symbol`](../../MT4Sugar/6.%20Order_Management.md) exit.

---

## 🛠️ Make it your own — and how it combines

**Why it's shaped this way.** Limits face the market (mean-reversion), stops ride the breakout — the grid is **direction-agnostic**, which is why it's a good *entry* engine when you have no directional view. The demo only places & removes the grid so you see the geometry; the money is in how you *manage* the fills.

**What to consider when you adapt it:**

* **Spacing vs the symbol.** `step_pts` should scale with volatility and the symbol's `min_stop_level` / spread — a grid tighter than the spread just churns.
* **Manage the fills.** A placed grid is only half a strategy. Watch fills with [`on_trade`](../../MT4Sugar/11.%20Streaming.md), attach SL/TP (or hand them to a trailing stop), and cap exposure (a grid can accumulate open lots fast).
* **Cancel the opposite side.** When a breakout fires one side, usually cancel the other pendings (`cancel_order`) so you're not left with a straddle.
* **Total-exposure guard.** Sum `open_orders` lots and stop adding levels past a limit.

**How it combines.** Grid is an **entry** block → feed its fills into the [Trailing Stop](./TrailingStop.md) manager, and *always* run the [Risk Manager](./RiskManager.md) above it — an un-supervised grid caught in a trend is how accounts blow up.

---

## ⚠️ Safety

Places `4 × levels` pending orders and deletes them. Demo accounts only. A level may trigger before removal — the demo guards each `cancel_order` with `rescue`.

---

## 📚 See also

* [Trailing Stop](./TrailingStop.md) · [Risk Manager](./RiskManager.md) · [Adaptive Preset](../Presets/AdaptiveMarketMode.md)
* [MT4Sugar · Simple Trading](../../MT4Sugar/4.%20Simple_Trading.md)

**Back to:** [Strategies — Master Overview](../Strategies.Master.Overview.md)
