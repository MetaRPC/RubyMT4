# ══════════════════════════════════════════════════════════════════════════════
# FILE: 16_adaptive_preset.rb — PRESET: ANALYSE MARKET → PICK AN ORCHESTRATOR
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Read two cheap market signals (spread + recent volatility) and recommend which
#   orchestrator (11 / 13 / 14) fits current conditions. READ-ONLY analysis.
#
# DECISION LOGIC:
#   • wide spread            → 14 Risk manager (illiquid: don't enter, watch risk)
#   • high volatility (ATR)  → 11 Trailing stop (ride a move)
#   • calm / range-bound     → 13 Grid trader (harvest the range)
#
# WHAT THIS DEMO COVERS:
#   1. SIGNALS - spread(symbol) + last_bars(symbol, timeframe:, count:)  → volatility
#   2. DECIDE  - map the signals to a recommended orchestrator
#
# TUNABLES:  the thresholds (50 pts spread, 400 pts ATR) and the H1 lookback (24).
#
# RUN:  ruby examples/demos/main.rb 16     (SAFE: read-only analysis)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("16", "Adaptive preset       - analyse market → pick an orchestrator") do |sugar, cfg|
  sym = cfg.test_symbol
  point = sugar.symbol_point(sym) || 0.0001    # point size, to express spread/ranges in points

  Demos.sub("1. market signals")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  spread(symbol) — ask − bid; divide by point for a points figure. Wide spread
  #       = costly/illiquid conditions (a reason NOT to enter actively).
  #  1.2  last_bars(symbol, timeframe:, count:) — last 24 H1 candles. We average each
  #       bar's (high − low) range as a simple ATR-style VOLATILITY proxy.
  # ──────────────────────────────────────────────────────────────────────────────
  spread_pts = (sugar.spread(sym) / point).round
  bars = sugar.last_bars(sym, timeframe: :H1, count: 24)
  ranges = bars.map { |b| (b.high - b.low) / point }
  atr_pts = ranges.empty? ? 0 : (ranges.sum / ranges.size).round
  puts format("  %s  spread %d pts   avg H1 range (24h) %d pts", sym, spread_pts, atr_pts)

  Demos.sub("2. recommendation")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  Route the signals to a playbook (see DECISION LOGIC in the header).
  #       A real preset would then LAUNCH that orchestrator; here we just print it.
  # ──────────────────────────────────────────────────────────────────────────────
  pick =
    if spread_pts > 50
      ["14 Risk manager", "spread is wide — avoid active entries, just monitor risk"]
    elsif atr_pts > 400
      ["11 Trailing stop", "high volatility — ride a move with a trailing stop"]
    else
      ["13 Grid trader", "calm, range-bound — harvest the range with a pending grid"]
    end
  puts "  → run demo [#{pick[0]}]"
  puts "    why: #{pick[1]}"
end
