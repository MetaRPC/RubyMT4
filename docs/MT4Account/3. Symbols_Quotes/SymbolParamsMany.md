# 🧾 Symbol Specifications

> **Request:** the **full specification** of one symbol — or **every** symbol — in one call (`SymbolParamsManyInfo`): digits, point, volumes, contract size, margins, swaps, sessions and more.

**API Information:**

* **Low-level API:** `MT4Account#symbol_params_many` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `SymbolParamsMany`

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `SymbolParamsMany(SymbolParamsManyRequest) → SymbolParamsManyReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#symbol_params_many(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The complete trading spec for a symbol: how many digits, the point size, min/max/step volume, contract size, margin and swap rules, session times.
* **Why you need it.** Position sizing, rounding prices/volumes, validating stops, margin estimates.
* **One or all.** Pass a symbol for a single spec; pass nothing for the whole book.

> ⚠️ **PascalCase accessors.** This message's fields are Capitalised: `p.Digits`, `p.Point`, `p.VolumeMin`, `p.TradeContractSize`, `p.SymbolName`… The friendly [`MT4Service#symbol_params`](../../MT4Service/MT4Service.Overview.md) returns a snake_case `SymbolSpec` struct instead.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # With `symbol`: that symbol's spec (SymbolParamsManyInfo) or nil if unknown.
  # Without `symbol`: ALL symbols' specs in one call ([SymbolParamsManyInfo]).
  def symbol_params_many(symbol = nil, timeout: 120)
end
```

**Request message:** `SymbolParamsManyRequest { string symbol_name = 1; … }` — the SDK sets `symbol_name` when you pass a symbol, or leaves it blank for all.

**Reply message:** `SymbolParamsManyReply { oneof response { SymbolParamsManyData data = 1; Error error = 2; } }` — `SymbolParamsManyData { repeated SymbolParamsManyInfo symbol_infos = 1; … }`. With a symbol the SDK returns the matching info (or the first, or `nil`); without, the whole array.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `symbol` | `String` / `nil` | `nil` | One symbol's spec, or `nil` for **all** symbols. |
| `timeout` | `Integer` | `120` | Per-call deadline (the full list is large). |

---

## ⬆️ Output — `SymbolParamsManyInfo` (key fields)

The message carries 67 fields; the ones you'll use most:

**Identity & pricing**

| Accessor | Type | Description |
|----------|------|-------------|
| `SymbolName` | `String` | Symbol name. |
| `SymDescription` | `String` | Human description. |
| `Path` | `String` | Market Watch tree path. |
| `Digits` | `Integer` | Price decimal places. |
| `Point` | `Float` | Point size (`10 ** -Digits`). |
| `Bid` | `Float` | Last bid. |
| `CurrencyBase` / `CurrencyProfit` / `CurrencyMargin` | `String` | Base / profit / margin currencies. |

**Volumes & contract**

| Accessor | Type | Description |
|----------|------|-------------|
| `VolumeMin` / `VolumeMax` / `VolumeStep` | `Float` | Min / max / step lot size. |
| `TradeContractSize` | `Float` | Units per lot (e.g. `100000`). |
| `TradeTickValue` / `TradeTickSize` | `Float` | Money per tick / price per tick. |

**Trading rules**

| Accessor | Type | Description |
|----------|------|-------------|
| `TradeStopsLevel` | `Integer` | Min SL/TP distance (points). |
| `TradeFreezeLevel` | `Integer` | Freeze distance (points). |
| `TradeMode` | `Symbol` | `SP_ENUM_SYMBOL_TRADE_MODE` — see below. |
| `TradeExeMode` | `Symbol` | `SP_ENUM_SYMBOL_TRADE_EXECUTION` — see below. |
| `TradeCalcMode` | `Symbol` | `SP_ENUM_TRADE_CALC_MODE` — see below. |

**Swaps & margins**

| Accessor | Type | Description |
|----------|------|-------------|
| `SwapLong` / `SwapShort` | `Float` | Swap per long / short lot. |
| `MarginInitial` / `MarginMaintenance` | `Float` | Initial / maintenance margin. |

> The full set (session volumes, limits, margin-rate variants, timestamps) is best explored offline: `ruby examples/demos/helpers/17_protobuf_inspector.rb SymbolParamsManyInfo`.

---

## 🧱 Related enums (from proto)

### `SP_ENUM_SYMBOL_TRADE_MODE` — `TradeMode`

```protobuf
enum SP_ENUM_SYMBOL_TRADE_MODE {
  SYMBOL_TRADE_MODE_DISABLED  = 0;  // trading disabled
  SYMBOL_TRADE_MODE_LONGONLY  = 1;  // buys only
  SYMBOL_TRADE_MODE_SHORTONLY = 2;  // sells only
  SYMBOL_TRADE_MODE_CLOSEONLY = 3;  // close positions only
  SYMBOL_TRADE_MODE_FULL      = 4;  // full access
}
```

### `SP_ENUM_SYMBOL_TRADE_EXECUTION` — `TradeExeMode`

```protobuf
enum SP_ENUM_SYMBOL_TRADE_EXECUTION {
  SYMBOL_TRADE_EXECUTION_REQUEST  = 0;  // request execution
  SYMBOL_TRADE_EXECUTION_INSTANT  = 1;  // instant execution
  SYMBOL_TRADE_EXECUTION_MARKET   = 2;  // market execution
  SYMBOL_TRADE_EXECUTION_EXCHANGE = 3;  // exchange execution
}
```

### `SP_ENUM_TRADE_CALC_MODE` — `TradeCalcMode`

```protobuf
enum SP_ENUM_TRADE_CALC_MODE {
  SYMBOL_TRADE_MARGINE_CALC_MODE_FOREX   = 0;  // forex
  SYMBOL_TRADE_MARGINE_CALC_MODE_FUTURES = 1;  // futures
  SYMBOL_TRADE_MARGINE_CALC_MODE_CFD     = 2;  // CFD
}
```

---

## 🧩 Notes & Tips

* **Round volumes to `VolumeStep`** and clamp to `[VolumeMin, VolumeMax]` before `order_send`.
* **Respect `TradeStopsLevel`** — SL/TP closer than this many points from price are rejected (`mql_code 130`).
* **`Point` vs pip** — a 5-digit FX symbol's pip is `10 * Point`.
* **Unknown symbol** → `nil` (single) or absent from the array (all).
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) One symbol

```ruby
p = acct.symbol_params_many("EURUSD")
puts "digits #{p.Digits}  point #{p.Point}  vol #{p.VolumeMin}–#{p.VolumeMax} step #{p.VolumeStep}"
puts "contract #{p.TradeContractSize}  min stop #{p.TradeStopsLevel} pts  mode #{p.TradeMode}"
```

### 2) Round a volume to the symbol's step

```ruby
p = acct.symbol_params_many("EURUSD")
raw = 0.037
vol = ((raw / p.VolumeStep).floor * p.VolumeStep).clamp(p.VolumeMin, p.VolumeMax)
puts "rounded volume: #{vol}"
```

### 3) All symbols → a lookup

```ruby
specs = acct.symbol_params_many.to_h { |p| [p.SymbolName, p] }
puts "XAUUSD contract: #{specs['XAUUSD']&.TradeContractSize}"
```

### 4) Tradable only

```ruby
acct.symbol_params_many.select { |p| p.TradeMode == :SYMBOL_TRADE_MODE_FULL }
    .first(5).each { |p| puts p.SymbolName }
```

---

## 📚 See Also

* [TickValueWithSize](./TickValueWithSize.md) — just the money-per-tick for sizing.
* [Quote](./Quote.md) — the live price.
* **Friendly layer:** [`MT4Service#symbol_params`](../../MT4Service/MT4Service.Overview.md) → a snake_case `SymbolSpec` struct.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
