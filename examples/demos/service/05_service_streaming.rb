# ══════════════════════════════════════════════════════════════════════════════
# FILE: 05_service_streaming.rb — MID-LEVEL (MT4Service) STREAMING
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   The same tick stream as the raw layer, but through MT4Service's friendlier
#   helpers. READ-ONLY (~6s total).
#
# WHAT THIS DEMO COVERS:
#   1. TICKS (blocking)  - each_tick(symbols, seconds:)
#   2. TICKS (callback)  - subscribe_ticks(symbols) + .cancel
#
# RUN:  ruby examples/demos/main.rb 5      (SAFE: read-only, ~6s)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("5", "Service streaming     - typed tick streams (~6s)") do |sugar, cfg|
  svc = sugar.service
  sym = cfg.test_symbol

  Demos.sub("1. each_tick — blocking for 3s")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  each_tick(symbols, seconds:) — subscribe, pump the block for `seconds`,
  #       cancel cleanly, and return the tick count. The simplest way to sample ticks.
  # ──────────────────────────────────────────────────────────────────────────────
  n = svc.each_tick(sym, seconds: 3) do |tick|
    puts format("    %-8s bid %s  ask %s", tick.symbol, tick.bid, tick.ask)
  end
  puts "  each_tick counted #{n} ticks"

  Demos.sub("2. subscribe_ticks — manual cancel after 3s")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  subscribe_ticks(symbols) { |tick| ... } — returns a Subscription you cancel
  #       yourself; good when the stream runs alongside other work on your thread.
  # ──────────────────────────────────────────────────────────────────────────────
  got = 0
  sub = svc.subscribe_ticks(sym) { |_t| got += 1 }
  sleep 3
  sub.cancel
  puts "  subscribe_ticks received #{got} ticks (#{sub.count} total)"
end
