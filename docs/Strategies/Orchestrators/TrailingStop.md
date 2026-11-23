# 🎯 Trailing Stop Orchestrator

> Open an order, then **ratchet its stop-loss up** behind the price to lock in profit as the market moves your way. ⚠ Places a real (demo) order.

**Demo:** `examples/demos/orchestrators/11_trailing_stop.rb` · **Run:** `ruby examples/demos/main.rb 11`

---

## 💡 What it is

A trailing stop is the simplest profit-protection strategy: you enter, and every tick you move the stop-loss to a fixed distance behind the current price — but **only upward**. If price keeps rising, the stop follows and your locked-in profit grows; if price pulls back into the stop, you're taken out with the gains you'd already secured.

---

## 🧠 Strategy logic

On each tick the orchestrator computes a candidate stop:

```
candidate_sl = bid − trail_pts × point
```

and applies the **ratchet rule** — move the stop there only if it's **higher** than the best stop so far:

```
if candidate_sl > best_sl    → modify_sl(ticket, candidate_sl)   # tighten
else                          → hold (never loosen)
```

That one-way ratchet is the whole idea: the stop can only improve, never give back ground.

---

## 🧱 Composed from (MT4Sugar)

| Step | Methods |
|------|---------|
| **Open** | [`buy_market`](../../MT4Sugar/4.%20Simple_Trading.md) · [`open_orders`](../../MT4Sugar/7.%20Order_Information.md) |
| **Trail** | [`bid`](../../MT4Sugar/3.%20Prices_Quotes.md) · [`modify_sl`](../../MT4Sugar/6.%20Order_Management.md) · [`symbol_point`](../../MT4Sugar/9.%20Symbol_Information.md) · [`symbol_digits`](../../MT4Sugar/9.%20Symbol_Information.md) |
| **Close** | [`close_order`](../../MT4Sugar/6.%20Order_Management.md) |

---

## 🔧 Code walkthrough

```ruby
point  = sugar.symbol_point(sym) || 0.0001
digits = sugar.symbol_digits(sym) || 5
trail_pts = 150      # stop sits this far below bid
steps = 6            # how many ticks to trail for

# 1. OPEN — buy, then grab the order's ticket (MT4: ticket > 0 = filled, no retcode)
res = sugar.buy_market(sym, vol, magic: 110_011)
o   = sugar.open_orders(symbol: sym).max_by(&:ticket)

# 2. TRAIL — ratchet the stop up, never down
best_sl = nil
steps.times do
  sleep 1
  bid  = sugar.bid(sym)
  want = (bid - trail_pts * point).round(digits)
  if best_sl.nil? || want > best_sl
    best_sl = want
    sugar.modify_sl(o.ticket, want)            # tighten only
  end
end

# 3. CLOSE — exit (a real run lets the stop do it)
sugar.close_order(o.ticket)
```

---

## ⚙️ Tunables

| Name | Meaning |
|------|---------|
| `trail_pts` | trail distance in points (smaller = tighter, gets stopped sooner) |
| `steps` | how many ticks the demo trails for |

**Make it real:** replace the fixed `steps` loop with a [`subscribe_ticks`](../../MT4Sugar/11.%20Streaming.md) stream and let the broker's stop close the order (drop the explicit `close_order`).

---

## 🛠️ Make it your own — and how it combines

**Why it's shaped this way.** The one-way ratchet (`want > best_sl`) *is* the strategy — a stop that can loosen isn't a trailing stop, it's a guess. The fixed `steps` loop exists only so the demo ends; a real trailing stop lives as long as the order does.

**What to consider when you adapt it:**

* **Trail distance vs noise.** Too tight (`trail_pts` small) and normal wiggle stops you out; too wide and you give profit back. Base it on volatility — a fraction of the recent ATR (`last_bars` high−low) — not a constant.
* **Only trail in profit.** Start trailing once price has moved your way by `trail_pts`, so the first stop sits at/above break-even — not from entry.
* **Respect `min_stop_level`.** A stop computed too close to the market is rejected (`mql_code 130`) — clamp the distance.
* **Drive it off ticks.** Replace the `sleep` loop with [`subscribe_ticks`](../../MT4Sugar/11.%20Streaming.md) so the stop reacts to every price, and let the broker's SL do the close (drop the explicit `close_order`).

**How it combines.** It's a **management** block — pair it with *any* entry (a grid fill, a breakout, a signal). Tag the order with a `magic:` and trail only orders with that magic so it never touches another strategy's trades. Keep a [Risk Manager](./RiskManager.md) running above it as the account-level backstop.

---

## ⚠️ Safety

Places one tiny market order and closes it. Demo accounts only. Respect the symbol's [`min_stop_level`](../../MT4Sugar/9.%20Symbol_Information.md) — a stop too close to price is rejected (`mql_code 130`).

---

## 📚 See also

* [Grid Trader](./GridTrader.md) · [Risk Manager](./RiskManager.md) · [Adaptive Preset](../Presets/AdaptiveMarketMode.md)
* [MT4Sugar · Order Management](../../MT4Sugar/6.%20Order_Management.md)

**Back to:** [Strategies — Master Overview](../Strategies.Master.Overview.md)
