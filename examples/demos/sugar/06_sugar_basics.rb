# ══════════════════════════════════════════════════════════════════════════════
# FILE: 06_sugar_basics.rb — HIGH-LEVEL (MT4Sugar) BASICS DEMO
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   The simplest way to talk to MT4: one-liners for connection health, account
#   balances and prices. `sugar` arrives already connected (main.rb connected it).
#   Read-only — nothing is traded here (see 07 for trading).
#
# WHAT THIS DEMO COVERS:
#   1. CONNECTION       - connected?
#   2. BALANCE & MARGIN - balance / equity / free_margin / margin_level / profit
#   3. PRICES           - bid / ask / spread / price
#
# API LEVELS:
#   HIGH-LEVEL  (MT4Sugar)   - THIS FILE
#   MID-LEVEL   (MT4Service) - sugar.service
#   LOW-LEVEL   (MT4Account) - sugar.account
#
# RUN:  ruby examples/demos/main.rb 6      (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("6", "Sugar basics          - connection, balance, prices") do |sugar, cfg|
  sym = cfg.test_symbol

  Demos.sub("1. connection")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  connected?  — is the session up? Returns true after a successful connect.
  #       ▸ built from: sugar.connected? → service.connected? → account.connected?.
  #         It reads a LOCAL flag the SDK set on connect — it does NOT ping the server.
  #         For a live round-trip use sugar.check_connect / connect_state instead.
  # ──────────────────────────────────────────────────────────────────────────────
  puts "  connected? #{sugar.connected?}"

  Demos.sub("2. balance & margin (one-liners)")

  # ──────────────────────────────────────────────────────────────────────────────
  #  HOW THESE ARE BUILT — MT4 has NO AccountInfoDouble RPC (that's an MT5 feature),
  #  so every money one-liner just reads a field off ONE AccountSummary read:
  #      sugar.balance → service.account_summary → account.account_summary
  #                    → AccountHelper.AccountSummary RPC → AccountSummaryData.<field>
  #  (One call already carries balance/equity/margin — the helpers below don't re-fetch.)
  #
  #  2.1  balance      — AccountSummaryData.account_balance     realized, no floating P/L → Float
  #  2.2  equity       — AccountSummaryData.account_equity      balance + credit + floating → Float
  #  2.3  free_margin  — AccountSummaryData.account_margin_free room to open new orders   → Float
  #  2.4  margin_level — AccountSummaryData.account_margin_level equity / margin × 100     → Float
  #  2.5  profit       — COMPUTED by sugar: equity − balance − credit (no server P/L field) → Float
  # ──────────────────────────────────────────────────────────────────────────────
  puts format("  balance %.2f", sugar.balance)
  puts format("  equity  %.2f", sugar.equity)
  puts format("  free    %.2f", sugar.free_margin)
  puts format("  level   %.1f%%", sugar.margin_level)
  puts format("  profit  %.2f", sugar.profit)

  Demos.sub("3. prices")

  # ──────────────────────────────────────────────────────────────────────────────
  #  HOW THESE ARE BUILT — prices come from ONE RPC, MarketInfo.Quote. The sugar price
  #  readers all wrap service.quote, which turns the raw protobuf into a tidy Quote struct:
  #      sugar.price(sym) → service.quote(sym) → account.quote(sym) → MarketInfo.Quote RPC
  #                       → QuoteData → wrapped as Quote(symbol, bid, ask, high, low, spread, time_utc)
  #  (spread is COMPUTED as ask − bid when the Quote struct is built — no extra call.)
  #
  #  3.1  bid(sym) / ask(sym) — service.quote(sym).bid / .ask                           → Float
  #  3.2  spread(sym)         — service.quote(sym).spread  (ask − bid)                  → Float
  #  3.3  price(sym)          — the whole Quote struct (one call, all fields)           → Quote
  # ──────────────────────────────────────────────────────────────────────────────
  puts format("  %s bid %s  ask %s  spread %.5f", sym, sugar.bid(sym), sugar.ask(sym), sugar.spread(sym))
  p = sugar.price(sym)
  puts format("  price snapshot: bid %s  ask %s  high %s  low %s", p.bid, p.ask, p.high, p.low)
end
