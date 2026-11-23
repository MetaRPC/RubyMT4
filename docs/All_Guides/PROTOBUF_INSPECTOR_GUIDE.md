# Protobuf Inspector — Interactive Type Explorer

> A small offline tool that reads the generated MT4 protobuf stubs and tells you the **real** field names, types and enum values — so you never guess an accessor again.

The generated stubs under `package/*_pb.rb` are the raw contract. When you need to know *"what's the exact accessor on this reply?"* or *"what are the valid values of this enum?"*, the inspector answers from the descriptors themselves — no connection, no API key, no trades.

**Source:** `examples/demos/helpers/17_protobuf_inspector.rb`

---

## 🏁 Running it

It's a standalone helper (it does **not** go through the demo menu, which connects first):

```bash
# interactive REPL
ruby examples/demos/helpers/17_protobuf_inspector.rb

# one-shot — pass a command as arguments, get the answer, exit
ruby examples/demos/helpers/17_protobuf_inspector.rb OrderSendData
ruby examples/demos/helpers/17_protobuf_inspector.rb enum OrderSendOperationType
ruby examples/demos/helpers/17_protobuf_inspector.rb field order_type
ruby examples/demos/helpers/17_protobuf_inspector.rb search Tick
```

The REPL opens on a summary of what it discovered:

```
================================================================
MT4 PROTOBUF INSPECTOR (Ruby)
================================================================
  219 message types · 26 enums discovered
  Type 'help' for commands, 'list' to browse, 'exit' to quit.

>
```

> **Offline & safe.** It only `require`s the `package/*_pb.rb` message stubs and reads their descriptors. It never opens a channel. You can run it with no credentials at all.

---

## 🧰 Commands

| Command | What it shows | Example |
|---------|---------------|---------|
| `list [--msg\|--enum]` | all message types and/or enums | `list --enum` |
| `<TypeName>` | a message's fields (name · type · label · #) | `OpenedOrderInfo` |
| `search <text>` | message **and** enum names containing `<text>` | `search Order` |
| `field <name>` | which messages carry a field named `<name>` | `field order_type` |
| `findtype <type>` | every field of a proto type, grouped by message | `findtype double` |
| `enum <Name>` | an enum's values (sorted by number) | `enum OrderSendOperationType` |
| `whereenum <Name>` | which message fields use an enum | `whereenum OpenedOrderType` |
| `stats` | type / field / enum counts | `stats` |
| `help` or `?` | the command list | `help` |
| `exit` / `quit` / `q` | leave the REPL | `exit` |

Name lookups are **fuzzy**: exact → case-insensitive exact → a single partial match → otherwise it lists the candidates.

---

## 🔎 Worked examples (real output)

### A message's fields — `<TypeName>`

Fields print as **name · proto-type · label · field-number**. Message/enum fields show their subtype inline (`enum<…>` / `message<…>`). This is how you catch the naming gotchas the stubs hide — e.g. `SymbolTickValueWithSizeInfo` uses **PascalCase/camelCase** accessors:

```
> SymbolTickValueWithSizeInfo

TYPE: SymbolTickValueWithSizeInfo   (5 fields)
================================================================
  index              int32                            (#1)
  symbolName         string                           (#2)   ← i.symbolName, not i.symbol_name
  TradeTickValue     double                           (#3)   ← i.TradeTickValue, not i.trade_tick_value
  TradeTickSize      double                           (#4)
  TradeContractSize  double                           (#5)
```

The field **name is the accessor** you call in Ruby.

> 🐛 **A real MT4 spelling gotcha.** The commission field is spelled **`commision`** (single "m") on `OpenedOrderInfo` / `HistoryOrderInfo`, but **`commission`** (double "s") on the streamed `OnOpenedOrdersProfitOrderInfo`. And the streamed row's profit is `order_profit`, not `profit`. One `OnOpenedOrdersProfitOrderInfo` lookup settles it.

### Which message has a field? — `field <name>`

```
> field order_type

FIELD 'order_type'
────────────────────────────────────────────────────────────────
exact match in (2): HistoryOrderInfo, OpenedOrderInfo
```

So both the open book and history rows expose **`order_type`** — the kind of check this command ends in seconds.

### An enum's values — `enum <Name>`

```
> enum OrderSendOperationType

ENUM: OrderSendOperationType
================================================================
  OC_OP_BUY       = 0
  OC_OP_SELL      = 1
  OC_OP_BUYLIMIT  = 2
  OC_OP_SELLLIMIT = 3
  OC_OP_BUYSTOP   = 4
  OC_OP_SELLSTOP  = 5
```

### Where is an enum used? — `whereenum <Name>`

```
> whereenum OpenedOrderType

ENUM 'OpenedOrderType' used in (2 fields)
================================================================
  HistoryOrderInfo.order_type
  OpenedOrderInfo.order_type
```

### All fields of a type — `findtype <type>`

```
> findtype double

FIELDS OF TYPE 'double' (… in … messages)
================================================================
  AccountSummaryData: account_balance, account_equity, account_credit, account_margin, account_margin_free, account_margin_level
  QuoteData: bid, ask, high, low
  …
```

Valid type names are the proto scalar/compound types: `double`, `float`, `string`, `bool`, `int32`, `int64`, `uint32`, `uint64`, `message`, `enum`.

### Counts — `stats`

```
> stats
================================================================
  message types : 219
  message fields: 874
  enums         : 26
  enum values   : 252
```

---

## 🧭 The "three order_type enums" gotcha

`search order` reveals why a BUY constant that works in one call fails in another — the API has **separate order-type enums per context**:

| Enum | Use it for | Values |
|------|------------|--------|
| `OrderSendOperationType` | `order_send` (opening/placing orders) | `OC_OP_*` |
| `OpenedOrderType` | reading `opened_orders` / `orders_history` | `OO_OP_*` |
| `SUB_ORDER_OPERATION_TYPE` | streaming events (`on_trade`, `on_opened_orders_profit`) | `SUB_OP_*` |

When a call rejects your enum, `whereenum <Name>` confirms whether that enum is even accepted by the message you're building. The friendly `:buy/:sell/...` only works on the Service/Sugar trade helpers — the raw `order_send` field needs `:OC_OP_BUY`. See [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md).

---

## 📦 Common use cases

1. **"`undefined method` on a reply."** Run `<ReplyType>` and read the real field names — e.g. `symbolName` / `TradeTickValue` (camel/Pascal), `commision` (single "m").
2. **"What value do I pass for the order type?"** `enum OrderSendOperationType` (and mind the context table above).
3. **"Which request/reply do I need?"** `search <keyword>` lists both messages and enums matching the name.
4. **"Which messages even have this field?"** `field <name>` — exact and partial hits with the real field spelling.
5. **"Where is this enum accepted?"** `whereenum <Name>` before you build the request.

---

## ℹ️ How it works

Ruby's protobuf runtime exposes a **descriptor** on every generated type. The inspector walks the `Mt4TermApi` namespace, classifies each constant as a message (`Google::Protobuf::Descriptor`) or an enum (`Google::Protobuf::EnumDescriptor`), and reads fields (`name`, `type`, `label`, `number`, `subtype`) and enum pairs straight from those descriptors. That's why it's always in sync with the stubs — there's no hand-maintained list to drift.

Because Ruby descriptors carry field numbers, proto types, labels and subtypes, this inspector reports **more** than the raw getter/setter names you'd see in some other SDKs — you get the full field shape.

---

## See Also

* [MT4Account overview](../MT4Account/MT4Account.Master.Overview.md) — the documented API over these stubs
* [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md) — which enum belongs to which call
* [Return Codes & errors](./RETURN_CODES_REFERENCE.md) — the error model and `mql_code`
* [Getting Started → raw gRPC](./GETTING_STARTED.md) — taking only the `package/` stubs

---

**Tip:** reach for the inspector the moment a field or enum name is in doubt — one `field` or `enum` lookup is faster than reading a stub by hand.
