# ══════════════════════════════════════════════════════════════════════════════
# FILE: 08_sugar_positions.rb — HIGH-LEVEL (MT4Sugar) ORDERS DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Read-only look at open orders through MT4Sugar one-liners. On MT4 an open
#   market order IS the position; pending orders are listed separately.
#
# WHAT THIS DEMO COVERS:
#   1. LISTING   - open_orders / count_orders / has_order? / pending
#   2. SUMMARIES - total_profit / profit_by_symbol / order(ticket) / open_tickets
#
# RUN:  ruby examples/demos/main.rb 8      (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("8", "Sugar positions       - list / inspect orders (read-only)") do |sugar, cfg|
  sym = cfg.test_symbol

  Demos.sub("1. listing")

  # ──────────────────────────────────────────────────────────────────────────────
  #  HOW THESE ARE BUILT — MT4 returns ONE open-orders list (market + pending together).
  #  The sugar helpers all wrap that single RPC and split/count/sum it in Ruby:
  #      sugar.open_orders → service.positions → account.opened_orders (AccountHelper.OpenedOrders)
  #                        → [OpenedOrderInfo], kept to market types (:OO_OP_BUY/:OO_OP_SELL).
  #  (So count_orders / has_order? / pending don't each hit the server — they filter the same list.)
  #
  #  1.1  open_orders(magic:, symbol:) — market orders, filtered client-side  → [OpenedOrderInfo]
  #  1.2  count_orders                 — open_orders.size
  #  1.3  has_order?(symbol)           — orders_by_symbol(symbol).any?
  #  1.4  pending(symbol:)             — service.pending_orders → opened_orders minus the market types
  # ──────────────────────────────────────────────────────────────────────────────
  orders = sugar.open_orders
  puts "  open market orders: #{sugar.count_orders}   pending: #{sugar.pending.size}"
  puts "  has #{sym} order? #{sugar.has_order?(sym)}"
  orders.first(5).each { |o| puts format("    #%d %-8s lots %.2f P/L %.2f", o.ticket, o.symbol, o.lots, o.profit) }

  Demos.sub("2. summaries")

  # ──────────────────────────────────────────────────────────────────────────────
  #  These are pure Ruby over the same lists — only open_tickets is its own cheap RPC:
  #  2.1  total_profit            — open_orders.sum(&:profit)                         (no extra call)
  #  2.2  profit_by_symbol(sym)   — orders_by_symbol(sym).sum(&:profit)              (no extra call)
  #  2.3  order(ticket)           — service.opened_orders.find { |o| o.ticket == t } (market OR pending)
  #  2.4  open_tickets            — service.opened_tickets → account.opened_orders_tickets
  #                                 (AccountHelper.OpenedOrdersTickets — just the ids, lightweight)
  # ──────────────────────────────────────────────────────────────────────────────
  puts format("  total floating P/L %.2f   %s P/L %.2f", sugar.total_profit, sym, sugar.profit_by_symbol(sym))
  tickets = sugar.open_tickets
  puts "  open tickets: #{tickets.size}"
  if (first = tickets.first) && (o = sugar.order(first))
    puts format("  order #%d: %s lots %.2f", o.ticket, o.symbol, o.lots)
  end
end
