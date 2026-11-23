# ══════════════════════════════════════════════════════════════════════════════
# FILE: 09_sugar_history.rb — HIGH-LEVEL (MT4Sugar) HISTORY & STATS DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Read closed orders and aggregate trading statistics for a time window.
#   READ-ONLY. MT4 has one history list (orders) — no separate positions history.
#
# WHAT THIS DEMO COVERS:
#   1. ORDER HISTORY  - order_history(from_utc:)
#   2. TRADE STATS    - trade_stats(from_utc:) / equity_history(from_utc:)
#
# RUN:  ruby examples/demos/main.rb 9      (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("9", "Sugar history         - closed orders & trade stats (read-only)") do |sugar, _cfg|
  from = Time.now.utc - 30 * 24 * 3600   # last 30 days

  Demos.sub("1. order history")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  order_history(from_utc:, to_utc:) — closed / deleted orders, auto-paged.
  #       ▸ built from: service.order_history → account.orders_history → AccountHelper.OrdersHistory.
  #         WHY "auto-paged": the raw RPC returns pages with a next_page_token; MT4Account loops
  #         them and hands back ONE flat array — the sugar/service layers add nothing but the name.
  #         from_utc is sent as a google.protobuf.Timestamp (a Ruby Time is converted for you).
  #       [HistoryOrderInfo]: ticket, symbol, order_type, lots, open_price,
  #       close_price, profit, swap, commision, close_time_utc.
  # ──────────────────────────────────────────────────────────────────────────────
  hist = sugar.order_history(from_utc: from)
  puts "  closed orders (30d): #{hist.size}"
  hist.last(5).each { |o| puts format("    #%d %-8s lots %.2f P/L %.2f", o.ticket, o.symbol, o.lots, o.profit) }

  Demos.sub("2. trade statistics")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  trade_stats(from_utc:) — aggregate stats (StatsData): summary (open/day/
  #       week/month/total profit), profit_factor, sharpe_ratio, trades, growth_percent.
  #       ▸ built from: service.trade_stats → account.trade_stats → TradeStats.TradeStats RPC
  #         (a DIFFERENT service than order history). The server does the aggregation, not Ruby.
  #       NOTE: the window bound here is an ISO-8601 STRING (not a Timestamp) — MT4Account turns a
  #         Ruby Time into "yyyy-MM-ddThh:mm:ssZ" for you. (This string-vs-Timestamp split is MT4-specific.)
  #  2.2  equity_history(from_utc:) — the equity / balance curve ([EquityPointData]).
  #       ▸ built from: service.equity_history → account.equity_history → TradeStats.EquityHistory,
  #         returning data.points as a ready array.
  # ──────────────────────────────────────────────────────────────────────────────
  st = sugar.trade_stats(from_utc: from)
  puts format("  trades %d  profit_factor %.2f  total P/L %.2f",
              st.trades, st.profit_factor, st.summary&.total_profit || 0.0)
  eq = sugar.equity_history(from_utc: from)
  puts "  equity points (30d): #{eq.size}"
end
