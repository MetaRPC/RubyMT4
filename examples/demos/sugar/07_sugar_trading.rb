# ══════════════════════════════════════════════════════════════════════════════
# FILE: 07_sugar_trading.rb — HIGH-LEVEL (MT4Sugar) TRADING DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Open and immediately close ONE tiny market order with MT4Sugar one-liners.
#   ⚠ PLACES A REAL (demo) ORDER — run on a demo account only. Volume is cfg.test_volume.
#   MT4 has no retcode: a filled order returns OrderSendData with ticket > 0.
#
# WHAT THIS DEMO COVERS:
#   1. QUOTE    - price(symbol) before trading
#   2. OPEN     - buy_market(symbol, volume)
#   3. CLOSE    - close_order(ticket)
#   4. SL/TP    - buy_market_with_sl_tp + modify_sl_tp + close_all_by_symbol
#
# RUN:  ruby examples/demos/main.rb 7      (⚠ opens & closes a tiny demo order)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("7", "Sugar trading         - open & close a tiny demo order", warn: true) do |sugar, cfg|
  sym = cfg.test_symbol
  vol = cfg.test_volume

  Demos.sub("1. quote")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  price(symbol) — snapshot the market before sending an order.
  #       ▸ built from: service.quote(sym) → account.quote → MarketInfo.Quote → Quote struct.
  # ──────────────────────────────────────────────────────────────────────────────
  q = sugar.price(sym)
  puts format("  %s  bid %s  ask %s", sym, q.bid, q.ask)

  Demos.sub("2. open market order")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  buy_market(symbol, volume, **opts) — market buy at the current ask.
  #       ▸ built from: service.order_send(type: :buy) → account.order_send → TradingHelper.OrderSend.
  #         WHY it works: the friendly :buy is mapped to the raw enum :OC_OP_BUY inside MT4Account
  #         (the ORDER_TYPES table); `price` is omitted for a market order so the gateway fills at
  #         the live quote. **opts (comment:, magic:, slippage:, …) are passed straight through.
  #       Returns OrderSendData(ticket, volume, price, open_time). ticket > 0 = filled.
  #       Trading one-liners RAISE on a broker rejection — wrap in begin/rescue.
  # ──────────────────────────────────────────────────────────────────────────────
  res = sugar.buy_market(sym, vol, comment: "RubyMT4-demo07", magic: 700_007)
  puts format("  opened: ticket #%d  @ %s  vol %s", res.ticket, res.price, res.volume)

  sleep 1   # let the order settle before closing

  Demos.sub("3. close the order")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  open_orders(symbol:) — find the freshly opened order's ticket.
  #       ▸ built from: service.positions(symbol:) → account.opened_orders, kept to the MARKET
  #         types (:OO_OP_BUY/:OO_OP_SELL) and filtered by symbol in Ruby (one RPC, client-side filter).
  #  3.2  close_order(ticket)  — full close (lots: nil).
  #       ▸ built from: service.order_close(ticket:) → account.order_close_delete → TradingHelper.OrderCloseDelete.
  #         Returns OrderCloseDeleteData(mode) — :OCD_MARKET_ORDER when a position was closed.
  # ──────────────────────────────────────────────────────────────────────────────
  o = sugar.open_orders(symbol: sym).max_by(&:ticket)
  if o
    out = sugar.close_order(o.ticket)
    puts format("  closed #%d: mode %s", o.ticket, out.mode)
  else
    puts "  no open order found to close (already filled & closed?)"
  end

  Demos.sub("4. SL/TP helpers + close-all")

  # ──────────────────────────────────────────────────────────────────────────────
  #  4.1  buy_market_with_sl_tp(symbol, volume, sl:, tp:) — open with protective
  #       stop-loss / take-profit in one call. (sell_market_with_sl_tp is the mirror.)
  #       ▸ built from: service.order_send(type: :buy, stop_loss: sl, take_profit: tp) — the SAME
  #         OrderSend RPC as buy_market, just with the stoploss/takeprofit fields filled.
  #  4.2  modify_sl_tp(ticket, stop_loss:, take_profit:) — adjust the stops.
  #       ▸ built from: service.order_modify(ticket:, stop_loss:, take_profit:) → TradingHelper.OrderModify.
  #  4.3  close_all_by_symbol(symbol) — flatten every market order on a symbol.
  #       ▸ built from: orders_by_symbol(symbol).map { |o| close_order(o.ticket) } — a LOOP of
  #         close calls (one OrderCloseDelete per order), not a single server call.
  # ──────────────────────────────────────────────────────────────────────────────
  pt = sugar.price(sym)
  pip = (sugar.symbol_point(sym) || 0.0001) * 10
  dg = sugar.symbol_digits(sym) || 5
  sl = (pt.bid - 20 * pip).round(dg)
  tp = (pt.ask + 20 * pip).round(dg)
  r2 = sugar.buy_market_with_sl_tp(sym, vol, sl: sl, tp: tp, magic: 700_008, comment: "RubyMT4-sltp")
  puts format("  opened w/ SL %s TP %s: ticket #%d", sl, tp, r2.ticket)
  if (o2 = sugar.open_orders(symbol: sym).max_by(&:ticket))
    sugar.modify_sl_tp(o2.ticket, stop_loss: sl, take_profit: (pt.ask + 30 * pip).round(dg))
    puts "  modified ##{o2.ticket} (SL/TP)"
  end
  closed = sugar.close_all_by_symbol(sym)
  puts "  close_all_by_symbol(#{sym}): closed #{closed.size}"
end
