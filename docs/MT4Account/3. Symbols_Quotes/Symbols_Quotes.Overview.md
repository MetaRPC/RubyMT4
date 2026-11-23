# MT4Account · Symbols & Quotes — Overview

> Everything market-data: the symbol list and Market Watch, live quotes (one or many), full symbol specs, tick value for sizing, OHLC bars, and the broker's time zone.

These methods are **read-only** except `symbol_select` (which toggles Market Watch). Quotes / symbols / bars live on `mt4_term_api.MarketInfo` and `mt4_term_api.QuoteHistory`; full specs and tick value on `mt4_term_api.AccountHelper`; the time zone on `mt4_term_api.ServerTimezone`. Each returns the raw `*Data`, or raises `ApiError`.

## 📁 What lives here

* **[Symbols](./Symbols.md)** — names of **all symbols** the server offers (`[String]`).
* **[SymbolSelect](./SymbolSelect.md)** — **add / remove** a symbol from Market Watch (`Boolean`).
* **[Quote](./Quote.md)** — the **last tick** for one symbol (`QuoteData`: bid, ask, high, low, time).
* **[QuoteMany](./QuoteMany.md)** — last ticks for **several symbols** in one call (`[QuoteData]`).
* **[SymbolParamsMany](./SymbolParamsMany.md)** — the **full specification** of one symbol, or all (`SymbolParamsManyInfo`): digits, point, volumes, contract size, margins, swaps, sessions.
* **[TickValueWithSize](./TickValueWithSize.md)** — **tick value / tick size / contract size** for position sizing.
* **[Bars](./Bars.md)** — **OHLC bars** via `QuoteHistory.Bars`, auto-paged.
* **[QuoteHistory](./QuoteHistory.md)** — the **legacy** `MarketInfo.QuoteHistory` bars (deprecated; prefer `Bars`).
* **[ServerTimezone](./ServerTimezone.md)** — the broker's **UTC offset**.

---

## 🧭 Plain English

* **Need prices?** → `quote` (one) or `quote_many` (several). Prices come from here.
* **Need the rules for sizing/stops?** → `symbol_params_many` (full spec) or `tick_value_with_size` (just the money-per-tick).
* **Need history to chart or backtest?** → `bars` (modern, paged). `quote_history` is the old endpoint kept for compatibility.
* **Need to convert broker times?** → `server_timezone`.
* **A symbol answers 0/0?** → it may not be in Market Watch yet — call `symbol_select` first.

---

## Quick choose

| If you need…                                | Use                     | Returns               |
| ------------------------------------------- | ----------------------- | --------------------- |
| All symbol names                            | `symbols`               | `[String]`            |
| Show/hide a symbol in Market Watch          | `symbol_select`         | `Boolean`             |
| Live price for one symbol                   | `quote`                 | `QuoteData`           |
| Live prices for many symbols                | `quote_many`            | `[QuoteData]`         |
| Full spec (digits, volumes, margins, swaps) | `symbol_params_many`    | `SymbolParamsManyInfo`(s) |
| Money value of one tick (sizing)            | `tick_value_with_size`  | `[SymbolTickValueWithSizeInfo]` |
| OHLC bars (chart / backtest)                | `bars`                  | `[QuoteHistoryBar]`   |
| Legacy OHLC bars                            | `quote_history`         | `[HistoryQuote]`      |
| Broker clock offset from UTC                | `server_timezone`       | `ServerTimezoneData`  |

---

## ❌ Cross-refs & gotchas

* **Add to Market Watch first.** A symbol freshly referenced can answer `bid/ask = 0` for a moment; `symbol_select(sym)` (and `tick_value_with_size`, which adds them too) warm it up.
* **Spec fields are PascalCase.** `SymbolParamsManyInfo` uses `p.Digits`, `p.Point`, `p.VolumeMin`, `p.TradeContractSize`… (not snake_case). The friendly [`MT4Service#symbol_params`](../../MT4Service/MT4Service.Overview.md) returns a snake_case `SymbolSpec` struct.
* **Two bar endpoints.** `bars` (QuoteHistory.Bars) is paged and uses **unix-seconds** `from_utc`/`to_utc` + `QHB_PERIOD_*` timeframes; `quote_history` (legacy) is unpaged and uses `Timestamp` + `QH_PERIOD_*`. Prefer `bars`.
* **`QUOTE_HISTORY_NOT_READY`.** The terminal fetches history on demand; `bars` retries this automatically.

---

## 🟢 Minimal snippets

```ruby
# Price for one symbol
q = acct.quote("EURUSD")
puts "bid #{q.bid} ask #{q.ask}"
```

```ruby
# Full spec (PascalCase accessors)
p = acct.symbol_params_many("EURUSD")
puts "digits #{p.Digits}  vol_min #{p.VolumeMin}  contract #{p.TradeContractSize}"
```

```ruby
# Last 100 M5 bars
bars = acct.bars("EURUSD", timeframe: :M5, from_utc: Time.now.to_i - 86_400)
puts "#{bars.size} bars, last close #{bars.last&.close}"
```

---

## 🧱 Enums used in Symbols & Quotes

| Where | Enum | Values |
|-------|------|--------|
| `bars(timeframe:)` | `QUOTE_HISTORY_TIMEFRAME` | `:QHB_PERIOD_M1` (1) · `_M5` (5) · `_M15` (15) · `_M30` (30) · `_H1` (60) · `_H4` (240) · `_D1` (1440) · `_W1` (10080) · `_MN1` (43200) — value = minutes |
| `quote_history(timeframe:)` | `ENUM_QUOTE_HISTORY_TIMEFRAME` | `:QH_PERIOD_M1` (0) · `_M5` (1) · `_M15` (2) · `_M30` (3) · `_H1` (4) · `_H4` (5) · `_D1` (6) · `_W1` (7) · `_MN1` (8) |

> You pass the friendly symbol (`:M1 … :MN1`) to `bars` / `quote_history`; the SDK maps it to the right enum. The `SymbolParamsManyInfo` spec also carries `TradeMode` / `TradeCalcMode` / `TradeExeMode` enums (see [SymbolParamsMany](./SymbolParamsMany.md)).

---

## See also

* **Account:** [Account Information — Overview](../1.%20Account_Information/Account_Information.Overview.md).
* **Trading:** [Trading Operations — Overview](../4.%20Trading_Operations/Trading_Operations.Overview.md).
* **Friendly layer:** [`MT4Service#quote` / `#symbol_params` / `#bars`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
