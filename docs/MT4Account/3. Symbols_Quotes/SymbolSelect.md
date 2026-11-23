# ➕ Market Watch — Select a Symbol

> **Request:** add (or remove) a symbol from **Market Watch** so the terminal streams its quotes. Returns `true`/`false`.

**API Information:**

* **Low-level API:** `MT4Account#symbol_select` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.MarketInfo`
* **Proto definition:** `SymbolSelect`

### RPC

* **Service:** `mt4_term_api.MarketInfo`
* **Method:** `SymbolSelect(SymbolSelectRequest) → SymbolSelectReply`
* **Low-level client (generated):** `Mt4TermApi::MarketInfo::Stub#symbol_select(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** Shows (`select: true`) or hides (`select: false`) a symbol in Market Watch.
* **Why you need it.** A symbol must be selected before the terminal has a live quote for it — otherwise `quote` can briefly answer `bid/ask = 0`.
* **Returns `Boolean`** — the SDK returns `data.success`.

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Add (select=true) / remove a symbol from Market Watch. Returns true/false.
  def symbol_select(symbol, select = true) -> Boolean
end
```

**Request message:**

```protobuf
SymbolSelectRequest {
  string symbol = 1;
  bool   select = 2;
}
```

**Reply message:** `SymbolSelectReply { oneof response { SymbolSelectData data = 1; Error error = 2; } }` — `SymbolSelectData { bool success = 1; }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `symbol` | `String` | **required** | Symbol name (e.g. `"EURUSD"`). |
| `select` | `Boolean` | `true` | `true` adds to Market Watch, `false` removes. |

---

## ⬆️ Output — `Boolean`

`true` when the operation succeeded. Removing a symbol that has open orders / positions may return `false`.

---

## 🧩 Notes & Tips

* **Call it before quoting a fresh symbol.** `tick_value_with_size` also adds symbols as a side effect.
* **Idempotent** — selecting an already-selected symbol is fine.
* **Can't remove busy symbols** — a symbol with open orders usually stays in Market Watch (`false`).
* **Errors are exceptions:** wrap in `begin/rescue`.

---

## 🔗 Usage Examples

### 1) Add then quote

```ruby
acct.symbol_select("GBPUSD")
q = acct.quote("GBPUSD")
puts "#{q.bid}/#{q.ask}"
```

### 2) Ensure a set is watched

```ruby
%w[EURUSD GBPUSD USDJPY].each { |s| acct.symbol_select(s) }
```

### 3) Remove when done

```ruby
ok = acct.symbol_select("GBPUSD", false)
puts ok ? "removed" : "still in use"
```

---

## 📚 See Also

* [Quote](./Quote.md) — read the price after selecting.
* [Symbols](./Symbols.md) — the full list of names.
* **Friendly layer:** [`MT4Service#select_symbol`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
