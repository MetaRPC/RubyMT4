# gRPC Streaming & Subscription Management

> How real-time server streams work in RubyMT4 — subscribe with a block, stop cleanly with `cancel`, and never leak a reader thread.

This guide covers:

- ✅ **How to subscribe** to market-data and trade-event streams
- ✅ **How to stop** a stream without leaking its background thread
- ✅ **Patterns** from a 5-second snapshot to a managed background service
- ✅ **The model** behind every stream (one thread + a `Subscription`)
- ✅ **Error handling** and best practices

---

## The model in one picture

Every streaming method takes a **block** and immediately returns a `MetaRPC::MT4::Subscription`. The actual reading happens on a **background thread** the SDK spawns for you — your block is called once per message as it arrives, while your main code keeps running.

```
your block  ◄──yields each message──  background Thread  ◄──gRPC server stream──  mt4.mrpc.pro:443
     ▲                                        │
     └──────────  sub.cancel  stops the thread (and joins it, up to 5 s)
```

There is **no polling and no async/await** — Ruby threads do the work. A `Subscription` is the handle you keep to stop it (`cancel`), wait on it (`join`), check it (`alive?`, `count`, `error`). This is the whole lifecycle; master `cancel` and you're done.

> **No auto-reconnect.** If the stream drops, the reader thread ends and `sub.error` is set — the SDK does **not** resubscribe for you. Re-open it yourself if you need resilience.

---

## Quick Start — the simplest subscription

```ruby
require "metarpc_mt4"

mt4 = MetaRPC::MT4::MT4Sugar.create("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
mt4.quick_connect(1235959737, "password", "EGlobal-Demo")

# on_symbol_tick / subscribe_ticks yields each tick to the block, returns a Subscription
sub = mt4.subscribe_ticks("EURUSD") do |t|
  puts "#{t.symbol}  bid #{t.bid}  ask #{t.ask}"
end

sleep 5        # let it stream for 5 seconds while the main thread does other work
sub.cancel     # stop cleanly — cancels the stream and joins the reader thread
puts "received #{sub.count} ticks"
```

**When to use:** quick examples, testing, short monitoring sessions.

> `subscribe_ticks` (sugar/service) and `on_symbol_tick` (account) are the same stream — the sugar name just reads better. The block receives a tick (`symbol`, `bid`, `ask`, `last`, `volume`, `time`, `time_utc`), not a wrapper. (MT4 ticks carry bid/ask — `last` is usually `0` on FX.)

---

## Available streaming methods

All of these take a block and return a `Subscription`. They exist on **`MT4Account`** (raw) and are re-exposed by **`MT4Service`** / **`MT4Sugar`** under friendlier names.

| Method (Account) | Sugar / Service name | Yields | What it streams |
|------------------|----------------------|--------|-----------------|
| `on_symbol_tick(symbols)` | `subscribe_ticks(symbols)` | a tick | real-time bid/ask per symbol |
| `on_trade` | `on_trade` | `OnTradeData` | orders opened / modified / closed |
| `on_opened_orders_profit(interval_ms:)` | `on_opened_orders_profit(...)` | `OnOpenedOrdersProfitData` | open orders' P/L, every `interval_ms` |
| `on_opened_orders_tickets(interval_ms:)` | `on_tickets(interval_ms:)` | tickets snapshot | open position & pending-order tickets |
| `on_connect_state(terminal_ids)` | `on_connect_state(...)` | `ConnectStateData` | the terminal's connect-state changes |

Plus a **blocking** convenience that streams ticks for a fixed time and returns the count (no `Subscription` to manage):

```ruby
n = mt4.each_tick("EURUSD", seconds: 5) { |t| puts t.bid }   # blocks 5 s, then returns n
```

**Reference:** [Streaming Methods overview](../MT4Account/5.%20Streaming_Methods/Streaming_Methods.Overview.md) · [MT4Sugar → Streaming](../MT4Sugar/11.%20Streaming.md). **Run it:** `ruby examples/demos/main.rb 3` (raw) · `ruby examples/demos/main.rb 5` (service).

---

## Patterns (simple → advanced)

### Pattern 1 — Time-boxed snapshot

The blocking `each_tick` is the shortest path when you just want N seconds of data:

```ruby
count = mt4.each_tick(["EURUSD", "GBPUSD"], seconds: 10) do |t|
  puts "#{t.symbol}: #{t.bid}"
end
puts "#{count} ticks in 10s"
```

### Pattern 2 — Count-limited (stop after N messages)

Keep the `Subscription` and `cancel` it from inside the block once you've seen enough:

```ruby
sub = nil
seen = 0
sub = mt4.subscribe_ticks("EURUSD") do |t|
  seen += 1
  puts "[#{seen}] #{t.bid}"
  Thread.new { sub.cancel } if seen >= 50   # cancel off the reader thread
end
sub.join        # wait for it to finish
```

> **Why `Thread.new { sub.cancel }`?** `cancel` joins the reader thread, so calling it *from* that same thread would deadlock. Cancel from the main thread (Pattern 3) or hand it off to a short-lived thread as above.

### Pattern 3 — Condition-based stop (from the main thread)

Signal with a flag; the main thread does the `cancel`:

```ruby
target_hit = false
sub = mt4.subscribe_ticks("EURUSD") { |t| target_hit = true if t.bid > 1.10000 }

sleep 0.1 until target_hit || !sub.alive?
sub.cancel
puts target_hit ? "target reached after #{sub.count} ticks" : "stream ended early"
```

### Pattern 4 — Background service with guaranteed cleanup

Wrap the lifetime in `begin/ensure` so the stream is always stopped, even on error or `Ctrl-C`:

```ruby
sub = mt4.on_opened_orders_profit(interval_ms: 1000) do |data|
  data.opened_orders_with_profit_updated.sort_by { |o| -o.order_profit }.first(5).each do |o|
    puts "#{o.symbol}  #{o.order_profit.round(2)}"
  end
end

begin
  sleep 30            # run the service for 30 s (or loop your own logic here)
ensure
  sub.cancel          # ALWAYS stop it
end
```

---

## Multiple concurrent streams

Each subscription is independent (its own thread), so just open several and cancel them all. Collect the handles so cleanup is one loop:

```ruby
subs = []
subs << mt4.subscribe_ticks("EURUSD") { |t| puts "[TICK] #{t.bid}" }
subs << mt4.on_trade              { |_e| puts "[TRADE] event" }
subs << mt4.on_opened_orders_profit(interval_ms: 2000) { |d| puts "[P/L] #{d.opened_orders_with_profit_updated.size} orders" }

begin
  sleep 30
ensure
  subs.each(&:cancel)   # stop every stream
end
```

---

## Error handling

A stream's reader thread swallows the expected `GRPC::Cancelled` on `cancel`. Any **other** error is stored on the subscription as `sub.error` (it does not raise in your main thread), and the thread ends — so a stream can stop on its own:

```ruby
sub = mt4.subscribe_ticks("EURUSD") { |t| handle(t) }
sleep 10
sub.cancel

if sub.error
  warn "stream failed: #{sub.error.class}: #{sub.error.message}"   # e.g. a MetaRPC::MT4::ApiError
end
```

Check `sub.alive?` to see whether a stream is still running, and `sub.count` for how many messages it has delivered. A per-message error reported by the server (a `*Reply` with an error) is raised **inside** the thread as `MetaRPC::MT4::ApiError` and lands in `sub.error`. See [Return Codes & the error model](./RETURN_CODES_REFERENCE.md).

---

## Best practices

### ✅ DO

1. **Always keep the `Subscription`** a streaming method returns — it's your only handle to stop it.
2. **Always `cancel`** when done (wrap long-lived streams in `begin/ensure`).
3. **Cancel from the main thread** (or a throwaway thread), never from inside the reader block — `cancel` joins the thread.
4. **Prefer `each_tick`** for simple time-boxed sampling — it manages the subscription for you.
5. **Check `sub.error`** after a stream you expected to keep running has stopped — there is no auto-reconnect.
6. **Collect handles** (`subs << …`) when running several streams, so cleanup is one `each(&:cancel)`.

### ❌ DON'T

1. **Don't drop the handle** (`mt4.subscribe_ticks(...) { }` with no `sub =`) — you can never stop that thread.
2. **Don't call `sub.cancel` inside its own block** — it deadlocks (join-on-self). Signal a flag or spawn a thread.
3. **Don't forget `ensure`** — an exception in your loop would otherwise leave the reader thread running.
4. **Don't assume a stream is alive** — the server or network can end it; re-check `alive?` / `error` and resubscribe if needed.

---

## See Also

* [Streaming Methods overview](../MT4Account/5.%20Streaming_Methods/Streaming_Methods.Overview.md) — every stream, with its payload fields
* [`OnSymbolTick`](../MT4Account/5.%20Streaming_Methods/OnSymbolTick.md) · [`OnTrade`](../MT4Account/5.%20Streaming_Methods/OnTrade.md) — per-method references
* [MT4Sugar → Streaming](../MT4Sugar/11.%20Streaming.md) — the friendly `subscribe_ticks` / `each_tick` helpers
* [Glossary → Subscription](./GLOSSARY.md) · [Return Codes & errors](./RETURN_CODES_REFERENCE.md)

---

**Remember:** one block, one background thread, one `Subscription`. Keep the handle, `cancel` in an `ensure`, and your streaming code stays leak-free. 🚀
