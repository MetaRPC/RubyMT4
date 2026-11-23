# ══════════════════════════════════════════════════════════════════════════════
# FILE: 04_service_demo.rb — MID-LEVEL (MT4Service) DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   The typed facade: plain Ruby Structs and arguments instead of protobuf.
#   Reached via sugar.service. READ-ONLY: account snapshot, a quote, orders.
#
# WHAT THIS DEMO COVERS:
#   1. ACCOUNT  - account_info (Account struct) / demo?
#   2. QUOTES   - quote(symbol) (Quote struct) / symbol_params (SymbolSpec)
#   3. ORDERS   - positions(magic:, symbol:) / pending_orders
#
# RUN:  ruby examples/demos/main.rb 4      (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("4", "Service demo          - typed account / quote / orders") do |sugar, cfg|
  svc = sugar.service   # the MT4Service
  sym = cfg.test_symbol

  Demos.sub("1. account")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  account_info — typed snapshot Account(login, balance, equity, currency,
  #       leverage, trade_mode, company, server_time_utc).
  #  1.2  demo?        — true on a demo account.
  # ──────────────────────────────────────────────────────────────────────────────
  a = svc.account_info
  puts format("  #%s  %.2f %s  leverage 1:%d  demo? %s", a.login, a.balance, a.currency, a.leverage, svc.demo?)

  Demos.sub("2. quotes & specs")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  quote(symbol)        — Quote(symbol, bid, ask, high, low, spread, time_utc).
  #  2.2  symbol_params(symbol)— full SymbolSpec (digits, point, volume_min/step,
  #       contract_size, currency_base/profit, swap_long/short), or nil if unknown.
  # ──────────────────────────────────────────────────────────────────────────────
  q = svc.quote(sym)
  puts format("  %s  bid %s  ask %s  spread %.5f", q.symbol, q.bid, q.ask, q.spread)
  sp = svc.symbol_params(sym)
  puts format("  spec: digits %d  vol_min %s  vol_step %s  contract %s", sp.digits, sp.volume_min, sp.volume_step, sp.contract_size) if sp

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.3  select_symbol / symbol_exist? — typed predicates.
  #  2.4  symbol_params_all — full SymbolSpec of every symbol (array).
  # ──────────────────────────────────────────────────────────────────────────────
  svc.select_symbol(sym)
  puts "  exists? #{svc.symbol_exist?(sym)}   total specs #{svc.symbol_params_all.size}"

  Demos.sub("3. orders")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  positions(magic:, symbol:) — open MARKET orders (= positions on MT4),
  #       filtered in Ruby. Returns [OpenedOrderInfo] (ticket, symbol, lots, profit).
  #  3.2  pending_orders(magic:, symbol:) — the working pending orders.
  # ──────────────────────────────────────────────────────────────────────────────
  positions = svc.positions
  pend = svc.pending_orders
  puts "  open market orders: #{positions.size}   pending: #{pend.size}"
  positions.first(5).each { |o| puts format("    #%d %-8s lots %.2f P/L %.2f", o.ticket, o.symbol, o.lots, o.profit) }
end
