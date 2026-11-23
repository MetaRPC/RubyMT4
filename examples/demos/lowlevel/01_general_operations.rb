# ══════════════════════════════════════════════════════════════════════════════
# FILE: 01_general_operations.rb — LOW-LEVEL (MT4Account) GENERAL OPERATIONS
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   The raw gRPC client. Each call maps 1:1 to an RPC and returns the protobuf
#   `*Data` message. READ-ONLY: account, symbols, a quote and some bars.
#
# WHAT THIS DEMO COVERS:
#   1. ACCOUNT   - account_summary / server_timezone / accounts
#   2. SYMBOLS   - symbols / symbol_select / quote / quote_many
#   3. MARKET    - symbol_params_many / bars
#   4. DETAILS   - tick_value_with_size
#
# RUN:  ruby examples/demos/main.rb 1      (SAFE: read-only)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("1", "General operations    - account & symbols (raw MT4Account)") do |sugar, cfg|
  acct = sugar.account   # the raw MT4Account
  sym = cfg.test_symbol

  Demos.sub("1. account")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  account_summary — all account data in one call (AccountSummaryData):
  #       account_login, account_balance, account_equity, account_currency,
  #       account_leverage, account_margin, account_margin_free, account_company_name.
  # ──────────────────────────────────────────────────────────────────────────────
  s = acct.account_summary
  puts format("  #%s  balance %.2f %s  leverage 1:%d  %s",
              s.account_login, s.account_balance, s.account_currency, s.account_leverage, s.account_company_name)
  puts format("  equity %.2f  margin %.2f  free %.2f", s.account_equity, s.account_margin, s.account_margin_free)

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.2  server_timezone — broker server UTC offset (ServerTimezoneData):
  #       server, utc_offset_seconds, source. Every *_utc field = server time − offset.
  #  1.3  accounts — terminals owned by the API key (auto-paged list).
  # ──────────────────────────────────────────────────────────────────────────────
  tz = acct.server_timezone
  puts format("  server tz: %s  offset %ds", tz.server, tz.utc_offset_seconds)
  puts "  terminals on this key: #{acct.accounts.size}"

  Demos.sub("2. symbols")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  symbols              — names of all symbols (server list)   → [String]
  #  2.2  symbol_select(s)     — add the symbol to Market Watch       → true/false
  #  2.3  quote(symbol)        — last tick (QuoteData: bid, ask, high, low, time).
  #  2.4  quote_many(symbols)  — last ticks for several symbols at once.
  # ──────────────────────────────────────────────────────────────────────────────
  all = acct.symbols
  puts "  symbols total #{all.size}   first #{all.first}"
  acct.symbol_select(sym)
  t = acct.quote(sym)
  puts format("  %s tick: bid %s  ask %s  high %s  low %s", sym, t.bid, t.ask, t.high, t.low)
  qm = acct.quote_many([sym, all.first])
  puts "  quote_many got #{qm.size} quotes"

  Demos.sub("3. market data")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  symbol_params_many(symbol) — one symbol's full spec (SymbolParamsManyInfo,
  #       PascalCase fields: Digits, Point, VolumeMin, VolumeStep, TradeContractSize).
  #       Without an argument it returns EVERY symbol's spec in one call.
  # ──────────────────────────────────────────────────────────────────────────────
  p = acct.symbol_params_many(sym)
  puts format("  %s spec: digits %d  point %s  vol_min %s  vol_step %s",
              sym, p.Digits, p.Point, p.VolumeMin, p.VolumeStep) if p

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.2  bars(symbol, timeframe:, from_utc:, to_utc:) — OHLC bars, oldest first.
  #       timeframe: :M1 .. :MN1. Returns [QuoteHistoryBar] (time_utc, o/h/l/c, spread).
  # ──────────────────────────────────────────────────────────────────────────────
  from = Time.now.to_i - 7 * 24 * 3600
  bars = acct.bars(sym, timeframe: :H1, from_utc: from, to_utc: 0).last(5)
  puts "  last #{bars.size} H1 bars:"
  bars.each { |b| puts format("    o %s  h %s  l %s  c %s", b.open, b.high, b.low, b.close) }

  Demos.sub("4. details: sizing")

  # ──────────────────────────────────────────────────────────────────────────────
  #  4.1  tick_value_with_size(symbols) — tick value / size / contract size (sizing).
  #       [SymbolTickValueWithSizeInfo]: symbolName, TradeTickValue, TradeTickSize,
  #       TradeContractSize. Adds the symbols to Market Watch as a side effect.
  # ──────────────────────────────────────────────────────────────────────────────
  tv = acct.tick_value_with_size(sym).first
  puts format("  tick value %s  tick size %s  contract %s",
              tv.TradeTickValue, tv.TradeTickSize, tv.TradeContractSize) if tv
end
