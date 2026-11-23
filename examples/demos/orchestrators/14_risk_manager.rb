# ══════════════════════════════════════════════════════════════════════════════
# FILE: 14_risk_manager.rb — ORCHESTRATOR: RISK MONITOR / KILL-SWITCH
# ──────────────────────────────────────────────────────────────────────────────
# PURPOSE:
#   Poll the account a few times and, if the floating drawdown breaches a limit,
#   flatten everything. SAFE BY DEFAULT: dry_run only reports what WOULD happen.
#
# STRATEGY LOGIC:
#   A kill-switch caps the worst case: when floating losses reach a fraction of the
#   balance, close every open order at once rather than hoping for a recovery.
#
#   ORCHESTRATOR: composes balance + equity + count_orders + close_all.
#
# WHAT THIS DEMO COVERS:
#   1. POLICY   - define the drawdown limit and mode
#   2. MONITOR  - balance / equity / profit / count_orders on a loop
#   3. ENFORCE  - close_all when the limit is breached
#
# TUNABLES:  dry_run (false = actually flatten) · max_drawdown (fraction) · checks
#
# RUN:  ruby examples/demos/main.rb 14     (SAFE by default: dry_run reporting)
# ══════════════════════════════════════════════════════════════════════════════

Demos.register("14", "Risk manager          - monitor account / kill-switch") do |sugar, _cfg|
  dry_run = true          # true = report only, never close
  max_drawdown = 0.50     # kill-switch at 50% of balance lost (floating)
  checks = 3

  Demos.sub("1. policy")
  puts format("  max floating drawdown: %.0f%% of balance   mode: %s",
              max_drawdown * 100, dry_run ? "DRY-RUN (report only)" : "ARMED (will flatten)")

  checks.times do |i|
    sleep 1

    # ──────────────────────────────────────────────────────────────────────────────
    #  2.1  balance        — realized funds (excludes floating P/L).
    #  2.2  equity         — balance + credit + floating P/L; the live account value.
    #  2.3  profit         — floating P/L (equity − balance − credit).
    #  2.4  count_orders   — how many market orders are at risk right now.
    #       Drawdown = max(0, -floating) / balance.
    # ──────────────────────────────────────────────────────────────────────────────
    balance  = sugar.balance
    equity   = sugar.equity
    floating = sugar.profit
    dd = balance.zero? ? 0.0 : (floating.negative? ? -floating / balance : 0.0)
    open = sugar.count_orders

    Demos.sub("check #{i + 1}/#{checks}")
    puts format("  balance %.2f  equity %.2f  floating %.2f  drawdown %.1f%%  orders %d",
                balance, equity, floating, dd * 100, open)

    # ──────────────────────────────────────────────────────────────────────────────
    #  3.1  close_all — the kill-switch. Fires once drawdown ≥ the limit; in dry_run
    #       we only report what WOULD happen.
    # ──────────────────────────────────────────────────────────────────────────────
    if dd >= max_drawdown
      if dry_run
        puts "  #{Demos::C[:yellow]}KILL-SWITCH would fire (dry-run): close all #{open} orders#{Demos::C[:reset]}"
      else
        puts "  #{Demos::C[:yellow]}KILL-SWITCH firing: closing all orders#{Demos::C[:reset]}"
        sugar.close_all
      end
      break
    end
  end
  puts "  done — within risk limits."
end
