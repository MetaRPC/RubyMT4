# Your First Project

> Build a small, complete RubyMT4 script: connect, quote, trade with risk sizing, and report.

---

## 1 · Set up

```bash
mkdir mt4-bot && cd mt4-bot
```

Point Bundler at the repo (the gem isn't on RubyGems), then install:

```ruby
# Gemfile
source "https://rubygems.org"
gem "metarpc_mt4", git: "https://github.com/MetaRPC/RubyMT4.git"
gem "grpc", "~> 1.84.1" if Gem.win_platform?   # Windows: prebuilt binary
```

```bash
bundle install
```

Create `bot.rb`. (Prefer the ready-made examples? `git clone` the repo and read `examples/demos/` — see [Getting Started](./GETTING_STARTED.md).)

---

## 2 · Connect

```ruby
require "metarpc_mt4"

mt4 = MetaRPC::MT4::MT4Sugar.create("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
mt4.quick_connect(
  ENV["MT4_LOGIN"].to_i,
  ENV["MT4_PASSWORD"],
  ENV["MT4_SERVER"],          # e.g. EGlobal-Demo
)
puts "connected? #{mt4.connected?}"
```

> Need the `MRPC_API_KEY`? Register at [https://mrpc.pro/signup](https://mrpc.pro/signup) — your key is provisioned automatically and shown in the [MT4 Client API Explorer](https://mrpc.pro/explorer/mt4-client) (*Copy key*). See [Getting Started → API Key](./GETTING_STARTED.md). (Or pass `"TRIAL"` for keyless access while testing.)

---

## 3 · Look at the market

```ruby
symbol = "EURUSD"
q = mt4.price(symbol)
pips = (q.spread / mt4.symbol_point(symbol) / 10).round(1)
puts "#{symbol}  bid #{q.bid}  ask #{q.ask}  #{pips} pips"
```

---

## 4 · Trade with risk sizing

```ruby
digits = mt4.symbol_digits(symbol)
pip    = mt4.symbol_point(symbol) * 10          # 1 pip on a 5-digit symbol
sl     = (q.bid - 20 * pip).round(digits)       # 20-pip stop
tp     = (q.ask + 40 * pip).round(digits)       # 40-pip target

# Size so the 20-pip stop risks ~1% of balance.
# pip_value = money per pip per 1.0 lot (a LOCAL estimate — MT4 has no server-side calc RPC).
pv   = mt4.pip_value(symbol)
lots = [((mt4.balance * 0.01) / (pv * 20)).round(2), 0.01].max

# Can we afford the margin? (required_margin is also a local leverage-based estimate)
if mt4.required_margin(symbol, lots, q.ask) > mt4.free_margin
  abort "not enough free margin for #{lots} lots"
end

r = mt4.buy_market_with_sl_tp(symbol, lots, sl: sl, tp: tp, comment: "first-project")
puts r.ticket.positive? ? "opened ##{r.ticket} with #{lots} lots" : "not filled"
```

> **MT4 has no retcode.** A filled order returns `OrderSendData` with `ticket > 0`; a rejection **raises** `MetaRPC::MT4::ApiError` (read `e.mql_code`). Wrap the trade in `begin/rescue` in real code.

---

## 5 · Manage & report

```ruby
puts "open orders: #{mt4.count_orders}"
puts "floating P/L: #{mt4.total_profit.round(2)}"

# tidy up for the demo
mt4.close_all

# today's realized result (MT4: closed orders — there is no separate "deals" list)
from   = Time.now.utc - 24 * 3600
closed = mt4.order_history(from_utc: from).reject { |o| %i[OO_OP_BALANCE OO_OP_CREDIT].include?(o.order_type) }
puts "today: #{closed.size} closed orders, net #{closed.sum(&:profit).round(2)}"
```

---

## 6 · Run it

```bash
MT4_LOGIN=1235959737 MT4_PASSWORD=secret MT4_SERVER=EGlobal-Demo \
MRPC_API_KEY=YOUR_KEY bundle exec ruby bot.rb
```

---

## Where to go next

* Stream live prices → [gRPC Streaming](./GRPC_STREAM_MANAGEMENT.md).
* Strategy loops → [Strategies](../Strategies/Strategies.Master.Overview.md).
* Full helper list → [MT4Sugar API](../MT4Sugar/MT4Sugar.API_Overview.md).
