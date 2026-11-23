# ══════════════════════════════════════════════════════════════════════════════
# FILE: 02_trading_operations.rb — LOW-LEVEL (MT4Account) TRADING OPERATIONS
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Raw trading against MT4Account. Open ONE tiny market order, modify its SL/TP,
#   then close it. ⚠ PLACES A REAL (demo) ORDER — run on a demo account only.
#   MT4 has NO retcode: order_send returns OrderSendData with ticket > 0 = filled.
#
# WHAT THIS DEMO COVERS:
#   1. SIZING  - tick_value_with_size  (MT4 has no server-side margin calc RPC)
#   2. OPEN    - order_send(symbol:, type:, volume:)
#   3. MANAGE  - order_modify (SL/TP) → order_close_delete
#
# RUN:  ruby examples/demos/main.rb 2      (⚠ opens & closes a tiny demo order)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("2", "Trading operations    - order_send/modify/close (raw)", warn: true) do |sugar, cfg|
  acct = sugar.account   # the raw MT4Account
  sym = cfg.test_symbol
  vol = cfg.test_volume

  Demos.sub("1. sizing")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  tick_value_with_size(symbols) — the money value of one tick, for position
  #       sizing. MT4 has no OrderCalcMargin/OrderCalcProfit RPC (unlike MT5), so
  #       sizing is done from the symbol's tick value / contract size locally.
  # ──────────────────────────────────────────────────────────────────────────────
  tv = acct.tick_value_with_size(sym).first
  puts format("  %s tick value %s  contract %s", sym, tv&.TradeTickValue, tv&.TradeContractSize)

  Demos.sub("2. open market order")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  order_send(symbol:, type:, volume:, **opts) — market or pending order.
  #       type: :buy/:sell/:buy_limit/... Returns OrderSendData(ticket, volume, price,
  #       open_time). ticket > 0 means FILLED. A rejection RAISES ApiError
  #       (e.mql_code: 130 invalid stops, 132 market closed, 134 no money, 138 requote).
  # ──────────────────────────────────────────────────────────────────────────────
  res = acct.order_send(symbol: sym, type: :buy, volume: vol, comment: "RubyMT4-demo02", magic: 200_002)
  puts format("  opened: ticket #%d  @ %s  vol %s", res.ticket, res.price, res.volume)
  ticket = res.ticket

  sleep 1

  Demos.sub("3. modify SL/TP, then close")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  order_modify(ticket:, stop_loss:, take_profit:) — set / change SL & TP.
  #       Returns OrderModifyData(order_was_modified).
  #  3.2  order_close_delete(ticket:, lots:) — close a market order (lots nil = full)
  #       or delete a pending one. Returns OrderCloseDeleteData(mode, ...).
  # ──────────────────────────────────────────────────────────────────────────────
  q = acct.quote(sym)
  digits = acct.symbol_params_many(sym)&.Digits || 5
  sl = (q.bid - 0.0020).round(digits)
  tp = (q.ask + 0.0020).round(digits)
  begin
    m = acct.order_modify(ticket: ticket, stop_loss: sl, take_profit: tp)
    puts "  modified ##{ticket}: #{m.order_was_modified} (SL #{sl} TP #{tp})"
  rescue MetaRPC::MT4::ApiError => e
    puts "  modify rejected: #{e.code} (mql #{e.mql_code})"
  end
  out = acct.order_close_delete(ticket: ticket)
  puts "  closed ##{ticket}: mode #{out.mode}"
end
