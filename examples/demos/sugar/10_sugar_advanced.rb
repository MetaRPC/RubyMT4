# ══════════════════════════════════════════════════════════════════════════════
# FILE: 10_sugar_advanced.rb — HIGH-LEVEL (MT4Sugar) RISK SIZING DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Position sizing and pip maths with MT4Sugar. MT4 has NO server-side margin /
#   profit calc RPC, so these are LOCAL estimates from the symbol spec + leverage —
#   treat them as approximations, not broker-exact figures. READ-ONLY.
#
# WHAT THIS DEMO COVERS:
#   1. MARGIN & SIZING   - required_margin / max_lot
#   2. PIP VALUE         - pip_value
#
# RUN:  ruby examples/demos/main.rb 10     (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("10", "Sugar advanced        - risk sizing / pip value (read-only)") do |sugar, cfg|
  sym = cfg.test_symbol

  Demos.sub("1. margin & sizing (estimates)")

  # ──────────────────────────────────────────────────────────────────────────────
  #  WHY THESE ARE COMPUTED, NOT FETCHED — unlike MT5, MT4 has NO OrderCalcMargin /
  #  OrderCalcProfit RPC. So these sugar helpers do the maths LOCALLY from two reads:
  #  the symbol spec (service.symbol_params → SymbolSpec, from AccountHelper.SymbolParamsMany)
  #  and the account leverage (account_summary.account_leverage). Treat them as estimates.
  #
  #  1.1  required_margin(symbol, volume, price) — ESTIMATED margin for `volume` lots.
  #       ▸ formula: volume × spec.contract_size × price / leverage.
  #         Brokers apply their own margin rules (fixed/hedged/per-instrument), so it's a guide.
  #  1.2  max_lot(symbol, price) — largest lot that fits free margin.
  #       ▸ built from: free_margin / required_margin(1 lot), floored to spec.volume_step.
  # ──────────────────────────────────────────────────────────────────────────────
  ask = sugar.ask(sym)
  rm = sugar.required_margin(sym, cfg.test_volume, ask)
  puts format("  est. margin for %s lots of %s @ %s ≈ %.2f", cfg.test_volume, sym, ask, rm || 0.0)
  puts format("  max_lot @ %s ≈ %s", ask, sugar.max_lot(sym, ask))

  Demos.sub("2. pip value")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  pip_value(symbol) — the money value of one pip per 1.0 lot.
  #       ▸ built from the SymbolSpec: tick_value × (pip / tick_size), where pip = point × 10 on a
  #         5-/3-digit symbol (else point). Also a local computation — no server call.
  # ──────────────────────────────────────────────────────────────────────────────
  puts format("  %s pip value per lot ≈ %s", sym, sugar.pip_value(sym))

  # ──────────────────────────────────────────────────────────────────────────────
  #  spec one-liners used above — each reads ONE field off the same SymbolSpec:
  #  symbol_digits → spec.digits · symbol_point → spec.point · min_stop_level → spec.stops_level.
  #  (service.symbol_params → account.symbol_params_many → AccountHelper.SymbolParamsMany.)
  # ──────────────────────────────────────────────────────────────────────────────
  puts format("  %s digits %s  point %s  min stop %s pts",
              sym, sugar.symbol_digits(sym), sugar.symbol_point(sym), sugar.min_stop_level(sym))
end
