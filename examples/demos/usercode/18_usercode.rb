# ══════════════════════════════════════════════════════════════════════════════
# FILE: 18_usercode.rb — SANDBOX: YOUR OWN CODE
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   A blank canvas. `sugar` arrives already connected; write anything you like.
#   All three layers are available:
#       sugar            — MT4Sugar   (one-liners)
#       sugar.service    — MT4Service (typed facade)
#       sugar.account    — MT4Account (raw gRPC)
#
#   Keep it READ-ONLY while you experiment, or set volumes tiny on a demo account.
#
# RUN:  ruby examples/demos/main.rb 18
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("18", "Sandbox               - your own code (edit 18_usercode.rb)") do |sugar, cfg|
  sym = cfg.test_symbol

  Demos.sub("sandbox")
  # ─── write your code below ────────────────────────────────────────────────────
  puts "  balance #{format('%.2f', sugar.balance)}   #{sym} bid #{sugar.bid(sym)}"

  # Examples to try:
  #   q = sugar.service.quote(sym)
  #   tick = sugar.account.quote(sym)
  #   sugar.buy_market(sym, cfg.test_volume)   # ⚠ trades on a demo account
  # ──────────────────────────────────────────────────────────────────────────────
end
