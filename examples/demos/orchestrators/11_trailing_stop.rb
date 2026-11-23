# ══════════════════════════════════════════════════════════════════════════════
# FILE: 11_trailing_stop.rb — ORCHESTRATOR: TRAILING STOP
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Open one tiny market order, ratchet its stop-loss up behind the price for a few
#   ticks, then close it. ⚠ PLACES A REAL (demo) ORDER, then closes it.
#
# STRATEGY LOGIC:
#   A trailing stop locks in profit: as the market rises, the SL follows at a fixed
#   distance below the bid but NEVER moves down. If price pulls back into the stop,
#   the broker closes the order at the best level reached.
#
#   ORCHESTRATOR: composes buy_market + open_orders + bid + modify_sl + close_order.
#
# WHAT THIS DEMO COVERS:
#   1. OPEN   - buy_market(symbol, volume) + open_orders(symbol:)
#   2. TRAIL  - bid(symbol) + modify_sl(ticket, price)   (ratchet-up loop)
#   3. CLOSE  - close_order(ticket)
#
# TUNABLES:  trail_pts (trail distance, points) · steps (how many ticks to trail)
#
# RUN:  ruby examples/demos/main.rb 11     (⚠ opens, trails, then closes)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("11", "Trailing stop         - open, trail SL, close", warn: true) do |sugar, cfg|
  sym = cfg.test_symbol
  vol = cfg.test_volume
  point = sugar.symbol_point(sym) || 0.0001    # price value of one point
  digits = sugar.symbol_digits(sym) || 5       # decimals to round the SL price to
  trail_pts = 150         # trail distance in points (SL sits this far below bid)
  steps = 6               # how many ticks to trail for

  Demos.sub("1. open")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  buy_market(symbol, volume, **opts) — open the market order we'll trail.
  #       Returns OrderSendData(ticket, price). ticket > 0 = filled (no retcode on MT4).
  #  1.2  open_orders(symbol:) — fetch the freshly opened order to get its ticket.
  # ──────────────────────────────────────────────────────────────────────────────
  res = sugar.buy_market(sym, vol, magic: 110_011, comment: "RubyMT4-trail")
  puts format("  opened order #%d @ %s", res.ticket, res.price)
  o = sugar.open_orders(symbol: sym).max_by(&:ticket)
  unless o
    puts "  no order to trail"
    next
  end

  Demos.sub("2. trail the stop-loss")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  bid(symbol)              — latest price we trail behind.
  #  2.2  modify_sl(ticket, price) — move the stop-loss of the open order.
  #       THE RATCHET: SL = bid − trail_pts·point, but only call modify_sl when the
  #       new SL is HIGHER than the best so far — never loosen a stop.
  # ──────────────────────────────────────────────────────────────────────────────
  best_sl = nil
  steps.times do |i|
    sleep 1
    bid = sugar.bid(sym)
    want = (bid - trail_pts * point).round(digits)   # candidate SL this tick
    if best_sl.nil? || want > best_sl
      best_sl = want
      begin
        sugar.modify_sl(o.ticket, want)              # ratchet up
        puts format("  step %d: bid %s → SL %s", i + 1, bid, want)
      rescue MetaRPC::MT4::ApiError => e
        puts format("  step %d: modify rejected (%s)", i + 1, e.code)
      end
    else
      puts format("  step %d: bid %s (SL held at %s)", i + 1, bid, best_sl)
    end
  end

  Demos.sub("3. close")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  close_order(ticket) — exit at the end of the demo (in a real run you'd let
  #       the trailing stop close the order when price pulls back into it).
  # ──────────────────────────────────────────────────────────────────────────────
  out = sugar.close_order(o.ticket)
  puts "  closed ##{o.ticket}: mode #{out.mode}"
end
