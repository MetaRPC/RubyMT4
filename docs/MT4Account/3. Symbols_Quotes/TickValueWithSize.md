# 💵 Tick Value & Size

> **Request:** the **tick value / tick size / contract size** for one or more symbols — the money-per-tick you need for position sizing.

**API Information:**

* **Low-level API:** `MT4Account#tick_value_with_size` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `TickValueWithSize`

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `TickValueWithSize(TickValueWithSizeRequest) → TickValueWithSizeReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#tick_value_with_size(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** For each requested symbol: the monetary value of one tick, the tick size, and the contract size.
* **Why you need it.** Risk-based sizing: convert a stop distance (in ticks/points) into money, then into lots. MT4 has **no** server-side margin/profit calc RPC, so this is the sizing primitive.
* **Returns `[SymbolTickValueWithSizeInfo]`.** The SDK returns `data.infos` as an array. **Selecting the symbols is a side effect** (they're added to Market Watch).

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Tick value / size / contract size for named symbols (adds them to Market Watch).
  # Returns [SymbolTickValueWithSizeInfo]; raises ApiError on failure.
  def tick_value_with_size(symbols) -> Array<Mt4TermApi::SymbolTickValueWithSizeInfo>
end
```

**Request message:** `TickValueWithSizeRequest { repeated string symbol_names = 1; }`

**Reply message:** `TickValueWithSizeReply { oneof response { TickValueWithSizeData data = 1; Error error = 2; } }` — `TickValueWithSizeData { repeated SymbolTickValueWithSizeInfo infos = 1; }`.

---

## 🔽 Input

| Argument | Type | Description |
|----------|------|-------------|
| `symbols` | `Array<String>` (or a single `String`) | Symbols to measure. The SDK wraps a lone string in an array. |

---

## ⬆️ Output — `[SymbolTickValueWithSizeInfo]`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `index` | `index` | `Integer` | Position in the request. |
| `symbolName` | `symbolName` | `String` | Symbol (camelCase accessor). |
| `TradeTickValue` | `TradeTickValue` | `Float` | Money value of one tick per 1.0 lot (account currency). |
| `TradeTickSize` | `TradeTickSize` | `Float` | Price change of one tick. |
| `TradeContractSize` | `TradeContractSize` | `Float` | Units per lot. |

> **PascalCase/camelCase accessors** — `symbolName`, `TradeTickValue`, `TradeTickSize`, `TradeContractSize`.

---

## 🧩 Notes & Tips

* **Sizing formula.** Risk money ÷ (stop distance in ticks × `TradeTickValue`) = lots. Round to the symbol's `VolumeStep` (from [`symbol_params_many`](./SymbolParamsMany.md)).
* **Pip vs tick.** On a 5-/3-digit symbol a pip is 10 ticks — scale `TradeTickValue` accordingly for pip-based risk.
* **Side effect:** requested symbols are added to Market Watch (handy before quoting).
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Read tick value

```ruby
info = acct.tick_value_with_size("EURUSD").first
puts "tick value #{info.TradeTickValue}  tick size #{info.TradeTickSize}  contract #{info.TradeContractSize}"
```

### 2) Lots for a fixed money risk

```ruby
def lots_for_risk(acct, symbol, risk_money, stop_ticks)
  tv = acct.tick_value_with_size(symbol).first.TradeTickValue
  p  = acct.symbol_params_many(symbol)
  raw = risk_money / (stop_ticks * tv)
  ((raw / p.VolumeStep).floor * p.VolumeStep).clamp(p.VolumeMin, p.VolumeMax)
end
puts lots_for_risk(acct, "EURUSD", 50.0, 200)   # risk $50 over a 200-tick stop
```

### 3) Batch

```ruby
acct.tick_value_with_size(%w[EURUSD GBPUSD XAUUSD]).each do |i|
  puts format("%-8s tick value %.2f", i.symbolName, i.TradeTickValue)
end
```

---

## 📚 See Also

* [SymbolParamsMany](./SymbolParamsMany.md) — full spec incl. volume step for rounding.
* **Friendly layer:** [`MT4Sugar#pip_value` / `#max_lot` / `#required_margin`](../../MT4Sugar/MT4Sugar.API_Overview.md) — local sizing helpers built on this.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
