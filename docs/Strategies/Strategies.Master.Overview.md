# Strategies — Master Overview

> Orchestrators and presets built on **[MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md)** — small, readable strategy demos you can run and adapt.

---

## ⚠️ Educational demos only

Every orchestrator and preset here is a **demonstration template**, not a production trading system. They use simple signals, no real risk engine, and fixed parameters. **Run them on a demo account.** Before anything live: understand the algorithm, backtest, forward-test, and add real risk management.

---

## 🧩 What's an orchestrator vs a preset?

* **Orchestrator** — composes several [`MT4Sugar`](../MT4Sugar/MT4Sugar.API_Overview.md) one-liners into **one full strategy lifecycle** (open → manage → close). It runs a single playbook.
* **Preset** — the layer **above** orchestrators: it reads the market and **picks which orchestrator** fits right now. The "brain" / router.

```
Preset  ─ reads conditions ─▶  picks an Orchestrator  ─ composes ─▶  MT4Sugar one-liners
```

---

## 📁 Orchestrators

| # | Strategy | Idea | Trades? |
|---|----------|------|---------|
| 11 | **[Trailing Stop](./Orchestrators/TrailingStop.md)** | open, then ratchet the stop-loss up behind price, lock in profit | ⚠ yes (demo) |
| 13 | **[Grid Trader](./Orchestrators/GridTrader.md)** | bracket the market with pending limits + stops, then remove them | ⚠ yes (demo) |
| 14 | **[Risk Manager](./Orchestrators/RiskManager.md)** | monitor floating drawdown, flatten everything on breach (kill-switch) | dry-run by default |

## 📁 Presets

| # | Preset | Idea |
|---|--------|------|
| 16 | **[Adaptive Market Mode](./Presets/AdaptiveMarketMode.md)** | measure spread + volatility → recommend trailing / grid / risk-manager |

---

## 🟢 MT4 note — orders, not positions

On MT4 an open **market order is the position**, and there is **no retcode**: a filled order returns `OrderSendData` with `ticket > 0`. These demos therefore use [`open_orders`](../MT4Sugar/7.%20Order_Information.md) / [`close_order`](../MT4Sugar/6.%20Order_Management.md) (not "positions" / "close_position"), and read `r.ticket` after a trade. See [MT4Sugar — API Overview](../MT4Sugar/MT4Sugar.API_Overview.md).

---

## 🧩 Anatomy of an orchestrator

Every orchestrator is the **same four moving parts**, wired from `MT4Sugar` one-liners. Build your own by swapping any one part:

| Part | The question it answers | Sugar you'd reach for |
|------|-------------------------|-----------------------|
| **1 · Signal / trigger** | *When do I act?* | `bid` / `ask` / `spread`, `last_bars`, a clock |
| **2 · Sizing** | *How big?* | `pip_value`, `required_margin`, `max_lot` (or a fixed lot) |
| **3 · Entry** | *Place what order?* | `buy_market` / `buy_limit` / `buy_stop` / `*_with_sl_tp` |
| **4 · Manage → exit** | *How do I tend & close it?* | `open_orders`, `modify_sl` / `modify_sl_tp`, `close_order` / `close_all_by_symbol` |

```
signal ─▶ size ─▶ enter (keep the ticket) ─▶ manage in a loop ─▶ exit
```

The three demos each **stress a different part** — **Trailing Stop** = management, **Grid** = entry geometry, **Risk Manager** = a pure exit/supervisor loop with no entry. Recombine these parts and you have a new strategy.

---

## 🛠️ Building your own scenario — what to consider

A demo is a straight line; a real strategy is a **loop that survives surprises**. Before you adapt one, think through:

* **Entry conditions — be explicit.** What *exact* read makes you enter? Guard a cold symbol (`bid == 0` right after `select_symbol`) and a wide `spread(sym)` (skip costly moments).
* **Sizing & risk first, entry second.** Decide the money at risk *before* the order: `risk = balance * 0.01`, then lots from `pip_value` and your stop distance. Clamp to `volume_min` / `volume_step` and check `required_margin <= free_margin`.
* **Respect the symbol's rules.** SL/TP closer than `min_stop_level` points are rejected (`mql_code 130`); round prices to `symbol_digits`, volume to `volume_step`.
* **Trades raise — handle it.** MT4 has no retcode: a fill is `ticket > 0`, a rejection **raises** `ApiError` (read `e.mql_code`). Wrap every trade in `begin/rescue`. On `TradeOutcomeUnknown` **never blindly resend** — check `open_orders` first. See [Return Codes](../All_Guides/RETURN_CODES_REFERENCE.md).
* **Tag & reconcile.** Give every order a **`magic:`** number so you can find *your* orders (`open_orders(magic:)`) and not touch others'. On a restart, read what's already open **before** deciding to open more (idempotency).
* **Never loosen a stop.** A trailing ratchet only moves SL in your favour. Re-sending an identical SL/TP is also refused (`mql_code 1`) — only modify when the value actually changes.
* **Timing & the event loop.** A `sleep` loop is fine for a demo; for live, drive off a stream (`subscribe_ticks` / `on_opened_orders_profit`) and remember there is **no auto-reconnect** — watch `sub.error` and resubscribe.
* **Cleanup.** Cancel subscriptions in an `ensure`; decide whether a crash should leave orders open (a supervisor will close them) or flat.

---

## 🔗 Combining orchestrators & presets

Real systems compose these pieces. The patterns that matter:

* **Preset as a router** (what the Adaptive demo shows) — one place reads the market and **chooses** which orchestrator runs *now*: trend → trailing, range → grid, illiquid → stand down. Re-evaluate on a schedule; don't flip strategies every tick.
* **Risk Manager as a supervisor, not a strategy** — it has no entry. Run it **alongside** any orchestrator (its own thread / loop); it watches drawdown and `close_all` on breach, overriding everything else. The one you always keep on in production.
* **Isolate by `magic` + symbol** — two strategies on the same symbol will fight over the same `open_orders`. Give each its own magic number (and ideally its own symbol); filter every read/close by `magic:` so a strategy only ever touches its own orders.
* **Layer, don't nest blindly** — an *entry* orchestrator opens, a *management* one (trailing) tends, a *supervisor* (risk manager) caps the downside. Each acts on a clear slice of the book.
* **One connection, or one per worker** — a single `mt4` multiplexes reads fine; for several strategies trading hard in parallel, give each its own connection with a stable `id:` (see [Sync vs Async](../All_Guides/SYNC_VS_ASYNC.md)).

A minimal "real" shape — a supervisor always on, a preset choosing the playbook:

```ruby
mt4 = MetaRPC::MT4::MT4Sugar.create("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
mt4.connect(ENV["MT4_LOGIN"].to_i, ENV["MT4_PASSWORD"], server: ENV["MT4_SERVER"])

# 1) Supervisor in the background — ALWAYS on, overrides everything
Thread.new do
  loop do
    mt4.close_all if mt4.profit <= -(mt4.balance * 0.10)   # 10% floating-loss kill-switch
    sleep 2
  rescue MetaRPC::MT4::ApiError => e
    warn "supervisor: #{e.code}"
  end
end

# 2) A preset picks the playbook; the chosen orchestrator runs its open→manage→close loop,
#    tagging its orders with a magic number so it only touches its own.
mode = choose_mode(mt4, "EURUSD")       # your router — see the Adaptive preset
run_orchestrator(mode, mt4, "EURUSD", magic: 600_101)
```

> **Rule of thumb:** keep each orchestrator responsible for **one job on one slice of the book**, let a **preset** decide which runs, and let a **supervisor** cap the whole account. That separation is what makes scenarios safe to combine.

---

## ▶️ Running them

All are registered demos — launch from the interactive menu or directly:

```bash
ruby examples/demos/main.rb         # menu
ruby examples/demos/main.rb 11      # trailing stop
ruby examples/demos/main.rb 16      # adaptive preset (read-only)
```

Credentials come from `examples/demos/config/config.json` or the `MT4_*` env vars (see [Getting Started](../All_Guides/GETTING_STARTED.md)).

---

## 📚 See also

* **High-level API:** [MT4Sugar — API Overview](../MT4Sugar/MT4Sugar.API_Overview.md) — the one-liners these compose.
* **Ecosystem:** [The MetaRPC SDK family](../All_Guides/SDK_Ecosystem.md) — mirror a strategy across accounts with the Trade Copier.
* **Reference:** [Return Codes](../All_Guides/RETURN_CODES_REFERENCE.md).
