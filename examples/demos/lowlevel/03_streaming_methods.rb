# ══════════════════════════════════════════════════════════════════════════════
# FILE: 03_streaming_methods.rb — LOW-LEVEL (MT4Account) STREAMING
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Server-streaming RPCs on MT4Account. Each returns a Subscription whose reader
#   runs on a background thread; call .cancel to stop. READ-ONLY (~6s total).
#   NOTE: you CANNOT call .cancel from inside the yielded block (it would deadlock).
#
# WHAT THIS DEMO COVERS:
#   1. TICKS         - on_symbol_tick(symbols) { |tick| ... }
#   2. TRADE EVENTS  - on_trade { |event| ... }
#   3. CONNECT STATE - on_connect_state { |state| ... }
#
# RUN:  ruby examples/demos/main.rb 3      (SAFE: read-only, ~6s)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("3", "Streaming             - raw tick + trade + state streams (~6s)") do |sugar, cfg|
  acct = sugar.account
  sym = cfg.test_symbol

  Demos.sub("1. tick stream (3s)")

  # ──────────────────────────────────────────────────────────────────────────────
  #  1.1  on_symbol_tick(symbols) { |tick| ... } — streams OnSymbolMqlTickInfo
  #       (symbol, bid, ask, last, volume, time_utc). Returns a Subscription.
  # ──────────────────────────────────────────────────────────────────────────────
  ticks = 0
  sub = acct.on_symbol_tick(sym) do |tick|
    ticks += 1
    puts format("    tick %-8s bid %s  ask %s", tick.symbol, tick.bid, tick.ask) if ticks <= 5
  end
  sleep 3
  sub.cancel
  puts "  received #{ticks} ticks (#{sub.count} total)"

  Demos.sub("2. trade-event stream (2s)")

  # ──────────────────────────────────────────────────────────────────────────────
  #  2.1  on_trade { |event| ... } — streams OnTradeData when orders open/modify/close
  #       (event_data.new_orders / updated_orders / removed_orders, account_info).
  #       Quiet unless something trades while we listen.
  # ──────────────────────────────────────────────────────────────────────────────
  events = 0
  ts = acct.on_trade { |_e| events += 1 }
  sleep 2
  ts.cancel
  puts "  trade events in 2s: #{events}"

  Demos.sub("3. connect-state stream (1s)")

  # ──────────────────────────────────────────────────────────────────────────────
  #  3.1  on_connect_state { |state| ... } — streams ConnectStateData (id, state,
  #       is_connected, is_alive, server). Useful to watch the terminal's link health.
  # ──────────────────────────────────────────────────────────────────────────────
  states = 0
  cs = acct.on_connect_state { |st| states += 1; puts "    state: #{st.state} connected=#{st.is_connected}" if states <= 2 }
  sleep 1
  cs.cancel
  puts "  connect-state messages: #{states}"
end
