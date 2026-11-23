# UserCode Sandbox

> Your blank canvas inside the demo suite — `sugar` arrives already connected, so you write only the trading logic.

---

## 🏁 Quick start

1. Open `examples/demos/usercode/18_usercode.rb`.
2. Write your code inside the registered block (below the `write your code below` marker).
3. Run it:

```bash
ruby examples/demos/main.rb 18
```

That's it — the menu connects once, then hands your block a live, connected `sugar`.

The sandbox as it ships:

```ruby
Demos.register("18", "Sandbox - your own code (edit 18_usercode.rb)") do |sugar, cfg|
  sym = cfg.test_symbol

  # ─── write your code below ───
  puts "  balance #{format('%.2f', sugar.balance)}   #{sym} bid #{sugar.bid(sym)}"

  #   q    = sugar.service.quote(sym)
  #   tick = sugar.account.quote(sym)
  #   sugar.buy_market(sym, cfg.test_volume)   # ⚠ trades on a demo account
end
```

> Keep it **read-only** while experimenting, or use tiny volumes on a **demo** account.

---

## 🎁 What's already set up

The block receives two arguments:

| Argument | What it is |
|----------|------------|
| `sugar` | a connected `MT4Sugar` — the high-level one-liners |
| `cfg` | the loaded config: `cfg.test_symbol`, `cfg.test_volume`, `cfg.user`, `cfg.server`, … |

And from `sugar` you can reach every layer:

```ruby
sugar            # MT4Sugar  — one-liners
sugar.service    # MT4Service — typed Structs (Quote, Account, SymbolSpec)
sugar.account    # MT4Account — raw gRPC / protobuf
```

No `connect` call, no API key handling — the launcher did it. Config comes from `examples/demos/config/config.json` or the `MT4_LOGIN` / `MT4_PASSWORD` / `MT4_SERVER` / `MT4_SYMBOL` / `MT4_VOLUME` env vars.

---

## 🧩 Mixing the three layers

All three are live at once — drop down whenever the sugar layer doesn't expose what you need:

```ruby
# High — MT4Sugar
bal = sugar.balance                       # => Float

# Mid — MT4Service (typed Struct)
q = sugar.service.quote("EURUSD")         # Quote(bid, ask, high, low, spread, time_utc)

# Low — MT4Account (raw protobuf)
tick = sugar.account.quote("EURUSD")      # raw Mt4TermApi::QuoteData
```

---

## 📘 Quick reference (MT4Sugar)

```ruby
# ── Account ──────────────────────────────────────────────
sugar.balance            # Float
sugar.equity             # balance + credit + floating P/L
sugar.free_margin        # available to open more
sugar.margin_level       # %
sugar.account_info       # Struct(login, balance, currency, leverage, …)
sugar.demo?              # true on a demo account

# ── Prices ───────────────────────────────────────────────
sugar.bid("EURUSD")      # Float
sugar.ask("EURUSD")
sugar.spread("EURUSD")
sugar.price("EURUSD")    # Quote(bid, ask, high, low, spread, time_utc)

# ── Market orders (return OrderSendData — ticket > 0 = filled) ──
r = sugar.buy_market("EURUSD", 0.01)
r = sugar.sell_market("EURUSD", 0.01)
r = sugar.buy_market_with_sl_tp("EURUSD", 0.01, sl: 1.0820, tp: 1.0920)

# ── Pending orders ───────────────────────────────────────
sugar.buy_limit("EURUSD", 0.01, 1.0850)
sugar.sell_stop("EURUSD", 0.01, 1.0750)

# ── Orders (MT4: a market order IS the position) ─────────
sugar.open_orders(symbol: "EURUSD")      # Array
sugar.count_orders
sugar.total_profit
sugar.has_order?("EURUSD")
sugar.close_order(ticket)
sugar.close_all
sugar.close_all_by_symbol("EURUSD")
sugar.cancel_order(ticket)               # delete a pending
sugar.modify_sl_tp(ticket, stop_loss: 1.0830, take_profit: 1.0930)

# ── History & stats (need from_utc:) ─────────────────────
sugar.order_history(from_utc: Time.now.utc - 24 * 3600)
sugar.trade_stats(from_utc: Time.now.utc - 7 * 86_400)

# ── Symbols & risk sizing (local estimates — no server calc) ──
sugar.symbol_digits("EURUSD")
sugar.symbol_point("EURUSD")
sugar.min_stop_level("EURUSD")
sugar.pip_value("EURUSD")                                # money per pip per lot
sugar.required_margin("EURUSD", 0.10, sugar.ask("EURUSD"))
sugar.max_lot("EURUSD", sugar.ask("EURUSD"))

# ── Streaming (block + Subscription) ─────────────────────
sub = sugar.subscribe_ticks("EURUSD") { |t| puts t.bid }   # sub.cancel to stop
n   = sugar.each_tick("EURUSD", seconds: 5) { |t| puts t.bid }  # blocking
```

Full lists: [MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md) · [MT4Service](../MT4Service/MT4Service.Overview.md) · [MT4Account](../MT4Account/MT4Account.Master.Overview.md).

---

## ✅ Checking a trade

MT4 has **no retcode**: a filled order returns `OrderSendData` with a **`ticket > 0`**; a rejection **raises** `MetaRPC::MT4::ApiError`:

```ruby
begin
  r = sugar.buy_market(sym, cfg.test_volume)
  puts r.ticket.positive? ? "opened ##{r.ticket} @ #{r.price}" : "not filled"
rescue MetaRPC::MT4::TradeOutcomeUnknown => e
  warn "uncertain — check open orders before retrying: #{e.message}"
rescue MetaRPC::MT4::ApiError => e
  warn "trade error: #{e.mql_code} #{e.error.mql_error_description}"
end
```

See [Return Codes & the error model](./RETURN_CODES_REFERENCE.md) for the full picture.

---

## 📝 A complete sandbox example

Risk-size a trade to ~1% of balance, open it, then report:

```ruby
Demos.register("18", "Sandbox - your own code") do |sugar, cfg|
  sym = cfg.test_symbol
  q   = sugar.price(sym)
  pip = sugar.symbol_point(sym) * 10
  dig = sugar.symbol_digits(sym)

  sl  = (q.bid - 20 * pip).round(dig)                     # 20-pip stop
  tp  = (q.ask + 40 * pip).round(dig)

  # pip_value = money per pip per lot (a LOCAL estimate — MT4 has no calc RPC)
  lots = [((sugar.balance * 0.01) / (sugar.pip_value(sym) * 20)).round(2), 0.01].max

  if sugar.required_margin(sym, lots, q.ask) > sugar.free_margin
    puts "  not enough free margin for #{lots} lots"
  else
    r = sugar.buy_market_with_sl_tp(sym, lots, sl: sl, tp: tp)
    puts r.ticket.positive? ? "  opened ##{r.ticket} (#{lots} lots)" : "  not filled"
  end

  puts "  open: #{sugar.count_orders}  floating P/L: #{sugar.total_profit.round(2)}"
end
```

---

## 💡 Tips & common mistakes

1. **Start read-only.** `sugar.balance`, `sugar.price(sym)`, `sugar.open_orders` can't hurt anything — learn the shapes first.
2. **Trade on demo, tiny volumes.** Use `cfg.test_volume` (0.01) and confirm `sugar.demo?` before trading.
3. **Success is the `ticket`.** A filled `buy_market` returns `ticket > 0`; a rejection **raises** (there is no retcode). Wrap trades in `begin/rescue`.
4. **Don't re-raise an uncertain trade blindly.** On `trade_outcome_unknown?`, check `open_orders` first — the SDK never auto-resends a trade.
5. **Enum values are symbols** (`:OO_OP_BUY`, `:OC_OP_BUY`), not constants — see [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md).
6. **Unsure of a field or enum name?** Ask the [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md).

---

## See Also

- [MT4Sugar API](../MT4Sugar/MT4Sugar.API_Overview.md) · [MT4Service](../MT4Service/MT4Service.Overview.md) · [MT4Account](../MT4Account/MT4Account.Master.Overview.md)
- [Return Codes & errors](./RETURN_CODES_REFERENCE.md) · [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md) · [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md)
- [Your First Project](./Your_First_Project.md) — a standalone script version of the same idea
