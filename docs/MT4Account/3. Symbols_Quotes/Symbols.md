# 🔤 Listing Symbols

> **Request:** the names of **all symbols** the server offers (`[String]`).

**API Information:**

* **Low-level API:** `MT4Account#symbols` (alias `symbol_list`) (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.MarketInfo`
* **Proto definition:** `Symbols`

### RPC

* **Service:** `mt4_term_api.MarketInfo`
* **Method:** `Symbols(SymbolsRequest) → SymbolsReply`
* **Low-level client (generated):** `Mt4TermApi::MarketInfo::Stub#symbols(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Every tradable symbol name known to the terminal (the broker's full list, not just Market Watch).
* **Why you need it.** Validate a symbol exists, build a picker, iterate instruments.
* **Returns `[String]`.** The SDK maps `data.SymbolNameInfos` to plain symbol-name strings.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Names of all symbols known to the terminal. Returns [String]; raises ApiError.
  def symbols -> Array<String>
  alias symbol_list symbols
end
```

**Request message:** `SymbolsRequest {}` *(empty)*

**Reply message:** `SymbolsReply { oneof response { SymbolsData data = 1; Error error = 2; } }` — `SymbolsData { repeated SymbolNameInfo SymbolNameInfos = 1; }`, where `SymbolNameInfo { string symbol_name; int32 symbol_index; }`. The SDK returns the `symbol_name`s.

---

## 🔽 Input

**No parameters.** Runs on a **120 s** deadline (the list can be large).

---

## ⬆️ Output — `[String]`

An array of symbol names (e.g. `"EURUSD"`, `"XAUUSD"`, `"#AA"`). Order follows the server list.

> Need the index alongside each name? Reach the raw reply via the generated stub, or read `SymbolNameInfo.symbol_index`.

---

## 🧩 Notes & Tips

* **Full broker list** — not limited to Market Watch. A name being here doesn't mean it's selected; call [`symbol_select`](./SymbolSelect.md) before quoting if `bid/ask` come back `0`.
* **Membership check** — `acct.symbols.include?("EURUSD")` is the MT4 way to ask "does it exist?" (there is no dedicated `symbol_exist` RPC; [`MT4Service#symbol_exist?`](../../MT4Service/MT4Service.Overview.md) wraps this).
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Basic

```ruby
names = acct.symbols
puts "total #{names.size}, first #{names.first}"
```

### 2) Does a symbol exist?

```ruby
exists = acct.symbols.include?("EURUSD")
puts exists ? "yes" : "no"
```

### 3) Filter a family

```ruby
usd = acct.symbols.select { |s| s.include?("USD") }
puts "USD pairs: #{usd.size}"
```

---

## 📚 See Also

* [SymbolSelect](./SymbolSelect.md) — add a symbol to Market Watch before quoting.
* [Quote](./Quote.md) · [QuoteMany](./QuoteMany.md) — live prices.
* [SymbolParamsMany](./SymbolParamsMany.md) — full specs for all symbols.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
