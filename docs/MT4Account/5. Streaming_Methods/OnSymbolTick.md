# 📡 Streaming Ticks

> **Stream:** live ticks for one or more symbols. Yields `OnSymbolMqlTickInfo` (bid, ask, time) on a background thread; returns a `Subscription`.

**API Information:**

* **Low-level API:** `MT4Account#on_symbol_tick` (aliases `subscribe_ticks`, `subscribe_quotes`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.SubscriptionService`
* **Proto definition:** `OnSymbolTick` (server-streaming)

### RPC

* **Service:** `mt4_term_api.SubscriptionService`
* **Method:** `OnSymbolTick(OnSymbolTickRequest) → stream OnSymbolTickReply`
* **Low-level client (generated):** `Mt4TermApi::SubscriptionService::Stub#on_symbol_tick(request, metadata:)`

---

## 💬 Just the essentials

* **What it is.** A push stream of ticks — no polling.
* **Why you need it.** Live prices for a dashboard, a scalping loop, or a signal engine.
* **Yields `OnSymbolMqlTickInfo`.** The SDK unwraps each reply to `reply.data.symbol_tick` and calls your block.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Subscribe to ticks for `symbols` (String or Array). Yields OnSymbolMqlTickInfo on a
  # background thread. Returns a Subscription; call .cancel to stop.
  def on_symbol_tick(symbols) { |tick| ... } -> MetaRPC::MT4::Subscription
end
```

**Request message:** `OnSymbolTickRequest { repeated string symbol_names = 1; }`

**Reply (stream):** `OnSymbolTickReply { OnSymbolTickData data; … }` — `OnSymbolTickData { OnSymbolMqlTickInfo symbol_tick; string terminal_instance_guid_id; }`. Your block receives the `symbol_tick`.

---

## 🔽 Input

| Argument | Type | Description |
|----------|------|-------------|
| `symbols` | `Array<String>` (or a single `String`) | Symbols to stream. A lone string is wrapped for you. |
| `&block` | block | Called with each `OnSymbolMqlTickInfo`. |

---

## ⬆️ Yielded — `OnSymbolMqlTickInfo`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `symbol` | `symbol` | `String` | The symbol this tick is for. |
| `bid` | `bid` | `Float` | Best bid. |
| `ask` | `ask` | `Float` | Best ask. |
| `last` | `last` | `Float` | Last price (often `0` on FX). |
| `volume` | `volume` | `Integer` | Tick volume. |
| `time` | `time` | `Timestamp` | Tick time (broker time zone). |
| `time_utc` | `time_utc` | `Timestamp` | Tick time (UTC). |
| `time_msc` | `time_msc` | `Integer` | Tick time in ms (broker). |
| `time_msc_utc` | `time_msc_utc` | `Integer` | Tick time in ms (UTC). |

---

## 🧩 Notes & Tips

* **Returns a `Subscription`** — keep it and call `sub.cancel` to stop. See the [Subscription contract](./Streaming_Methods.Overview.md#the-subscription-contract).
* **Don't `cancel` inside the block** — deadlocks. Cancel from the main thread.
* **Blocking convenience** — [`MT4Service#each_tick(symbols, seconds:)`](../../MT4Service/MT4Service.Overview.md) subscribes, pumps for N seconds, and cancels for you.
* **No auto-reconnect** — on a drop, `sub.error` is set; resubscribe yourself.

---

## 🔗 Usage Examples

### 1) Run for 5 seconds

```ruby
got = 0
sub = acct.on_symbol_tick("EURUSD") do |tick|
  got += 1
  puts "#{tick.symbol} #{tick.bid}/#{tick.ask}"
end
sleep 5
sub.cancel
puts "received #{got} (#{sub.count} total)"
```

### 2) Several symbols

```ruby
sub = acct.on_symbol_tick(%w[EURUSD GBPUSD]) { |t| puts "#{t.symbol} #{t.bid}" }
sleep 3
sub.cancel
```

### 3) Cancel from the main thread on a condition

```ruby
done = false
sub = acct.on_symbol_tick("EURUSD") { |t| done = true if t.bid >= 1.1000 }
sleep 0.1 until done || !sub.alive?
sub.cancel
```

---

## 📚 See Also

* [Quote](../3.%20Symbols_Quotes/Quote.md) — one-shot price (poll).
* [OnTrade](./OnTrade.md) — order events.
* **Friendly layer:** [`MT4Service#subscribe_ticks` / `#each_tick`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Streaming Methods — Overview](./Streaming_Methods.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
