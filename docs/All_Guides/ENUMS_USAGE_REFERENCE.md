# ENUMs Usage Reference — MT4Account

> Which low-level `MT4Account` methods take or return protobuf enums, and how you pass them in Ruby.

---

## 💎 How enums work in Ruby

In the Ruby protobuf runtime, **an enum value is a Ruby symbol** — both when you pass it in and when you read it back. There are no module constants to import (unlike Python/Node): you write the value's name as a `:SYMBOL`.

```ruby
# IN — a sort selector enum, passed as a symbol:
orders = mt4.account.opened_orders(sort: :SORT_BY_OPEN_TIME_ASC)   # EnumOpenedOrderSortType
bars   = mt4.account.bars("EURUSD", timeframe: :M5, from_utc: Time.now.to_i - 86_400)  # mapped to QHB_PERIOD_M5

# OUT — an enum-typed field reads back as a symbol:
acc = mt4.account.account_summary
acc.account_trade_mode        # => :ACCOUNT_TRADE_MODE_DEMO   (EnumAccountTradeMode)
mt4.account.opened_orders.first&.order_type   # => :OO_OP_BUY   (OpenedOrderType)
```

**Don't know a value's exact spelling?** List any enum with the [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md):

```bash
ruby examples/demos/helpers/17_protobuf_inspector.rb enum OpenedOrderType
ruby examples/demos/helpers/17_protobuf_inspector.rb whereenum OrderSendOperationType
```

> **Mind the context — order type lives in different enums per call.** When you **send** an order the field is `OrderSendOperationType` (`OC_OP_*`); when you **read** the open book or history it's `OpenedOrderType` (`OO_OP_*`); in **streams** it's `SUB_ORDER_OPERATION_TYPE` (`SUB_OP_*`). Same six directions, three different names.

---

## ✅ Summary

| Method Group | With enums | Total | % |
|--------------|-----------|-------|---|
| Account & Stats | 2 | 6 | 33% |
| Orders & History | 2 | 3 | 67% |
| Symbols & Quotes | 3 | 9 | 33% |
| Trading Operations | 2 | 4 | 50% |
| Streaming Methods | 2 | 5 | 40% |
| **Total** | **11** | **27** | **41%** |

> Plus the connection helper `connect_proxy`, which takes a `ProxyTypes` enum (4): `:None`, `:Https`, `:Socks4`, `:Socks5`.

---

## 👤 1. Account & Stats — 2/6 use enums

| Method | In / Out | Input enum | Output enum |
|--------|----------|------------|-------------|
| `account_summary` | 0 / 2 | — | `EnumAccountTradeMode` (3): `:ACCOUNT_TRADE_MODE_DEMO/_CONTEST/_REAL` · `EnumAccountMarginMode` (3): `:ACCOUNT_MARGIN_MODE_RETAIL_NETTING/_EXCHANGE/_RETAIL_HEDGING` |
| `server_timezone` | 0 / 1 | — | `SERVER_TIMEZONE_SOURCE` (3): `:SERVER_TIMEZONE_SOURCE_UNKNOWN/_LIVE/_LAST_VALIDATED` |
| `trade_stats` · `trade_stats_equity_history` · `equity_history` · `trade_unrealized_pl` | 0 / 0 | — | — *(plain numeric stats)* |

> MT4 has **no** `account_info_double/integer/string` (those are MT5) — read account values straight off `account_summary`.

---

## 📋 2. Orders & History — 2/3 use enums

| Method | In / Out | Input enum | Output enum |
|--------|----------|------------|-------------|
| `opened_orders` | 1 / 1 | `EnumOpenedOrderSortType` (4): `:SORT_BY_OPEN_TIME_ASC/_DESC`, `:SORT_BY_ORDER_TICKET_ID_ASC/_DESC` | `OpenedOrderType` (8) on `order_type` |
| `orders_history` | 1 / 1 | `EnumOrderHistorySortType` (6): `:HISTORY_SORT_BY_OPEN_TIME_*`, `:_CLOSE_TIME_*`, `:_ORDER_TICKET_ID_*` | `OpenedOrderType` (8) on `order_type` |
| `opened_orders_tickets` | 0 / 0 | — | — |

**`OpenedOrderType` (8):** `:OO_OP_BUY` (0), `:OO_OP_SELL` (1) *(market = positions)* · `:OO_OP_BUYLIMIT` (2), `:OO_OP_SELLLIMIT` (3), `:OO_OP_BUYSTOP` (4), `:OO_OP_SELLSTOP` (5) *(pending)* · `:OO_OP_BALANCE` (6), `:OO_OP_CREDIT` (7) *(ledger)*.

---

## 📊 3. Symbols & Quotes — 3/9 use enums

| Method | In / Out | Input enum | Output enum |
|--------|----------|------------|-------------|
| `symbols` · `symbol_select` · `quote` · `quote_many` · `tick_value_with_size` | 0 / 0 | — | — |
| `symbol_params_many` | 0 / 3 | — | in `SymbolParamsManyInfo`: `SP_ENUM_SYMBOL_TRADE_MODE` (5) on `TradeMode`, `SP_ENUM_SYMBOL_TRADE_EXECUTION` (4) on `TradeExeMode`, `SP_ENUM_TRADE_CALC_MODE` (3) on `TradeCalcMode` |
| `bars` | 1 / 0 | `QUOTE_HISTORY_TIMEFRAME` (`:QHB_PERIOD_M1 … :QHB_PERIOD_MN1`, value = minutes) | — |
| `quote_history` | 1 / 0 | `ENUM_QUOTE_HISTORY_TIMEFRAME` (`:QH_PERIOD_M1 … :QH_PERIOD_MN1`, ordinals 0–8) | — |

> You pass the **friendly** `:M1 … :MN1` to `bars` / `quote_history`; the SDK maps it to the right timeframe enum. The two timeframe enums differ (modern `QHB_PERIOD_*` vs legacy `QH_PERIOD_*`).

---

## 💰 4. Trading Operations — 2/4 use enums

| Method | In / Out | Input enum | Output enum |
|--------|----------|------------|-------------|
| `order_send` | 1 / 0 | `OrderSendOperationType` (6): `:OC_OP_BUY/_SELL/_BUYLIMIT/_SELLLIMIT/_BUYSTOP/_SELLSTOP` | — |
| `order_modify` | 0 / 0 | — | — |
| `order_close` (`order_close_delete`) | 0 / 1 | — | `OrderCloseDeleteMode` (2): `:OCD_MARKET_ORDER`, `:OCD_PENDING_ORDER` |
| `order_close_by` | 0 / 0 | — | — |

> The `MT4Service` / `MT4Sugar` trade helpers accept a **friendly** `type:` (`:buy`, `:sell_limit`, …) and map it to `OrderSendOperationType` (`:OC_OP_*`) for you — you only reach for the raw enum at the `MT4Account` level. The raw protobuf field **rejects** `:buy`; it needs `:OC_OP_BUY`.

---

## 📡 5. Streaming Methods — 2/5 use enums

| Method | In / Out | Output enums |
|--------|----------|--------------|
| `on_symbol_tick` · `on_opened_orders_tickets` · `on_connect_state` | 0 / 0 | — |
| `on_opened_orders_profit` | 0 / 2 | `MT4_SUB_ENUM_EVENT_GROUP_TYPE` (2): `:OrderProfit`, `:OrderUpdate` on `type` · `SUB_ORDER_OPERATION_TYPE` (6): `:SUB_OP_BUY …` on each order's `type` |
| `on_trade` | 0 / 2 | `MT4_SUB_ENUM_EVENT_GROUP_TYPE` (2) on `type` · `SUB_ORDER_OPERATION_TYPE` (6) on the order rows inside `event_data` |

---

## ⚠️ Special cases

1. **No MT5-style property selectors.** MT4 has no `*_info_double/integer/string` methods, so there are **no** `*PropertyType` input enums — you read fields directly off the result messages.
2. **No "deals" enums.** MT4 has orders, not positions/deals, so there is no deal-type / deal-entry enum family (those are MT5).
3. **Three order-type enums by context.** `OrderSendOperationType` (`OC_OP_*`, sending) · `OpenedOrderType` (`OO_OP_*`, reading) · `SUB_ORDER_OPERATION_TYPE` (`SUB_OP_*`, streaming). The friendly `:buy/:sell/...` only works on the Service/Sugar trade helpers.
4. **`mql_code` is not an enum field on the trade result.** A rejection raises `ApiError`; the numeric `e.mql_code` has its symbolic names in the `MqlErrorCode` enum. See [Return Codes](./RETURN_CODES_REFERENCE.md).

---

## See Also

- [1 · Account Information](../MT4Account/1.%20Account_Information/Account_Information.Overview.md)
- [2 · Orders & History](../MT4Account/2.%20Orders_History/Orders_History.Overview.md)
- [3 · Symbols & Quotes](../MT4Account/3.%20Symbols_Quotes/Symbols_Quotes.Overview.md)
- [4 · Trading Operations](../MT4Account/4.%20Trading_Operations/Trading_Operations.Overview.md)
- [5 · Streaming Methods](../MT4Account/5.%20Streaming_Methods/Streaming_Methods.Overview.md)
- [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md) · [Return Codes](./RETURN_CODES_REFERENCE.md)
