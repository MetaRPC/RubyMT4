# ══════════════════════════════════════════════════════════════════════════════
# FILE: 13_grid_trader.rb — ORCHESTRATOR: PENDING GRID
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Place a small symmetric grid of pending orders around the current price, list
#   them, then remove them all. ⚠ PLACES REAL (demo) PENDING ORDERS, then cancels.
#
# STRATEGY LOGIC:
#   A grid brackets the market so you're positioned whichever way it breaks. At each
#   level `i` (spaced `step_pts` apart) we place FOUR pending orders:
#     • buy_limit  below  — join a dip (price falls into it)
#     • sell_limit above  — fade a rally
#     • buy_stop   above  — ride an upside breakout
#     • sell_stop  below  — ride a downside breakdown
#   Whichever price zone the market enters, a pending order triggers. This demo only
#   PLACES and then REMOVES the grid (no position management) to show the mechanics.
#
#   ORCHESTRATOR: composes buy/sell_limit + buy/sell_stop + cancel_order(ticket).
#
# WHAT THIS DEMO COVERS:
#   1. PLACE   - price(symbol) + buy_limit / sell_limit / buy_stop / sell_stop
#   2. LIST    - pending(symbol:)   (pending orders on the book)
#   3. REMOVE  - cancel_order(ticket)   (deletes a pending order)
#
# TUNABLES:  levels (per side) · step_pts (spacing between levels, points)
#
# RUN:  ruby examples/demos/main.rb 13     (⚠ places & removes a pending grid)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("13", "Grid trader           - place & remove a pending grid", warn: true) do |sugar, cfg|
  sym = cfg.test_symbol
  vol = cfg.test_volume
  point = sugar.symbol_point(sym) || 0.0001    # point size, for level spacing
  digits = sugar.symbol_digits(sym) || 5       # decimals to round prices to
  levels = 2             # levels per side
  step_pts = 300         # spacing between levels, in points

  # ──────────────────────────────────────────────────────────────────────────────
  #  price(symbol) — snapshot bid/ask; the grid is built symmetrically around it.
  # ──────────────────────────────────────────────────────────────────────────────
  q = sugar.price(sym)
  Demos.sub("1. place grid around #{sym} (bid #{q.bid} / ask #{q.ask})")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  buy_limit(sym, vol, price)  — pending buy BELOW the market (join a dip).
  #  1.2  sell_limit(sym, vol, price) — pending sell ABOVE the market (fade a rally).
  #  1.3  buy_stop(sym, vol, price)   — pending buy ABOVE the market (breakout up).
  #  1.4  sell_stop(sym, vol, price)  — pending sell BELOW the market (breakdown).
  #       Each returns OrderSendData; keep .ticket so we can remove it afterwards.
  # ──────────────────────────────────────────────────────────────────────────────
  placed = []
  (1..levels).each do |i|
    buy_price  = (q.bid - i * step_pts * point).round(digits)   # below market
    sell_price = (q.ask + i * step_pts * point).round(digits)   # above market
    b  = sugar.buy_limit(sym, vol, buy_price, magic: 130_013, comment: "grid-bl#{i}")
    s  = sugar.sell_limit(sym, vol, sell_price, magic: 130_013, comment: "grid-sl#{i}")
    bs = sugar.buy_stop(sym, vol, sell_price, magic: 130_013, comment: "grid-bs#{i}")   # breakout up
    ss = sugar.sell_stop(sym, vol, buy_price, magic: 130_013, comment: "grid-ss#{i}")   # breakout down
    placed.push(b.ticket, s.ticket, bs.ticket, ss.ticket)
    puts format("  level %d: BUY_LIMIT %s  SELL_LIMIT %s  BUY_STOP %s  SELL_STOP %s",
                i, buy_price, sell_price, sell_price, buy_price)
  end

  Demos.sub("2. pending orders now on the book")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  pending(symbol:) — the working pending orders for this symbol.
  # ──────────────────────────────────────────────────────────────────────────────
  pend = sugar.pending(symbol: sym)
  puts "  pending on #{sym}: #{pend.size}"

  Demos.sub("3. remove the grid")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  cancel_order(ticket) — deletes a pending order. Guard each with rescue:
  #       a level may already have triggered/filled.
  # ──────────────────────────────────────────────────────────────────────────────
  placed.each do |ticket|
    out = sugar.cancel_order(ticket)
    puts "  removed ##{ticket}: mode #{out.mode}"
  rescue StandardError => e
    puts "  ##{ticket} already gone: #{e.message}"
  end
end
