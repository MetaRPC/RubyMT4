# Return Codes & the Error Model

> How RubyMT4 tells you a trade's result. **MT4 has no retcode:** a filled order returns `OrderSendData` with `ticket > 0`; a rejection **raises** `ApiError` carrying an MQL4 error code; and `TradeOutcomeUnknown` marks a trade whose fate is uncertain.

---

## 🛡️ MT4 has no `returned_code`

Unlike MT5, there is **no `returned_code`** field. A trading operation either:

* **succeeds** → returns its `*Data` with a **`ticket > 0`** (for `order_send`) or a success flag, or
* **is rejected** → **raises** `MetaRPC::MT4::ApiError`, whose `mql_code` tells you why (130 invalid stops, 132 market closed, 134 not enough money, 138 requote…).

```ruby
begin
  r = mt4.buy_market("EURUSD", 0.01)       # returns OrderSendData
  puts r.ticket.positive? ? "opened ##{r.ticket} @ #{r.price}" : "not filled"
rescue MetaRPC::MT4::ApiError => e
  puts "rejected: #{e.code} (mql #{e.mql_code} #{e.error.mql_error_code})"
end
```

> **Golden rule:** *a trade that raised did **not** fill; a trade that returned a `ticket > 0` did.* Read-only calls (prices, symbols, balance) also raise on failure and otherwise return data.

---

## 🧭 The three outcomes of a trade call

| Outcome | How it surfaces | What it means |
|---------|-----------------|---------------|
| **Done** | returns `OrderSendData`, `ticket > 0` | the broker executed it |
| **Rejected** | raises `MetaRPC::MT4::ApiError` | broker said no — reason in `e.mql_code` / `e.error.mql_error_description` |
| **Uncertain** | raises a `TradeOutcomeUnknown`-marked error (or an `ApiError` with `trade_outcome_unknown?`) | request may or may not have executed — **do not blindly retry** |

So a complete trade looks like:

```ruby
begin
  r = mt4.buy_market_with_sl_tp("EURUSD", 0.01, sl: 1.0820, tp: 1.0920)
  puts r.ticket.positive? ? "opened ##{r.ticket} @ #{r.price}" : "not filled"
rescue MetaRPC::MT4::TradeOutcomeUnknown => e
  warn "UNCERTAIN — check open orders before retrying: #{e.message}"
rescue MetaRPC::MT4::ApiError => e
  warn "trade error: #{e.mql_code} #{e.error.mql_error_description}"
end
```

---

## 📥 What the trade data carries

Trade one-liners return the operation's `*Data`:

```
> OrderSendData              # ruby examples/demos/helpers/17_protobuf_inspector.rb OrderSendData
  ticket        int32     ← > 0 means FILLED (the order = position id)
  volume        double
  price         double
  open_time     Timestamp
  open_time_utc Timestamp
```

`OrderModifyData` carries `order_was_modified` (bool); `OrderCloseDeleteData` carries `mode` (`:OCD_MARKET_ORDER` / `:OCD_PENDING_ORDER`). None of them carry a retcode — **success is the `ticket` / flag, failure is an exception.**

---

## ❗ The error object (`MetaRPC::MT4::ApiError`)

When the gateway answers with the error branch, the SDK raises `MetaRPC::MT4::ApiError`, wrapping the protobuf `Error`. Useful accessors:

| On the error | Gives |
|--------------|-------|
| `e.message` | the full formatted string (code, type, MQL code + description) |
| `e.code` | the gateway `error_code` **string** (e.g. `"MRPC_TIMEOUT"`, `"API_KEY_INVALID"`, `"CONNECT_EX_INVALID_LOGIN_ERROR"`) |
| `e.mql_code` | the numeric MQL4 error (e.g. `130`) — alias for `e.error.mql_error_int_code` |
| `e.error.mql_error_code` | the same as an enum symbol (e.g. `:ERR_INVALID_STOPS`) |
| `e.error.mql_error_description` | human MQL4 error text |
| `e.error.type` | the gateway error class (`:MRPC`, `:MRPC_TIMEOUT`, `:TERMINAL_API_TIMEOUT`, `:MQL_EXECUTION`…) |
| `e.api_key_error?` | `true` for `API_KEY_INVALID` / `API_KEY_REQUIRED` — never retry |
| `e.trade_outcome_unknown?` | `true` when the trade's result is uncertain (see below) |

Subclass **`InvalidLoginError < ApiError`** is raised by `connect` when the broker rejects the login — never retry it.

```ruby
rescue MetaRPC::MT4::InvalidLoginError
  abort "bad login/password/server"
rescue MetaRPC::MT4::ApiError => e
  case e.mql_code
  when 134 then warn "not enough money — reduce volume"
  when 132 then warn "market closed — try during trading hours"
  when 130 then warn "stops too close — widen SL/TP (TradeStopsLevel)"
  when 138, 135 then warn "requote / price changed — resend with a fresh price"
  else warn "error #{e.code}: #{e.error.mql_error_description}"
  end
end
```

---

## ⚠️ `TradeOutcomeUnknown` — the one you must not retry blindly

A trade call can fail **after** the request may already have reached the terminal (a gateway/terminal timeout, or a transport drop like gRPC `UNAVAILABLE` / `DEADLINE_EXCEEDED`). The trade **may or may not** have executed. The SDK **never re-sends a trade automatically**.

Two ways it reaches you, both answering `trade_outcome_unknown? == true`:

```ruby
begin
  r = mt4.buy_market("EURUSD", 0.01)
rescue MetaRPC::MT4::TradeOutcomeUnknown => e   # transport failure, mixed into the GRPC error
  warn e.to_s
  # check whether it actually opened before doing anything:
  o = mt4.open_orders(symbol: "EURUSD").max_by(&:ticket)
  # decide to keep it or send again — never retry unconditionally
rescue MetaRPC::MT4::ApiError => e
  retry_safely unless e.trade_outcome_unknown?  # in-band timeout (mql 128, MRPC_TIMEOUT…)
end
```

In-band uncertainty is flagged for trade RPCs when the gateway code is a timeout (`MRPC_TIMEOUT`, `TERMINAL_API_TIMEOUT`, `COMMAND_TIMEOUT_EXCEEDED`, `TERMINAL_API_CALL_TIMEOUT`), the error `type` is `:MRPC_TIMEOUT` / `:TERMINAL_API_TIMEOUT`, or the MQL code is **`128` (`ERR_TRADE_TIMEOUT`)**.

---

## 📋 MQL4 error codes (`MqlErrorCode`)

MT4's `mql_code` is a standard **MQL4** runtime/trade error (not an MT5 `TRADE_RETCODE_*`). These are the trade-relevant ones, exactly as the enum defines them in `package/`. List them all with `ruby examples/demos/helpers/17_protobuf_inspector.rb enum MqlErrorCode`.

### Server / connection — retry with a delay

| Code | Name | Meaning |
|------|------|---------|
| 4 | `ERR_SERVER_BUSY` | trade server busy |
| 6 | `ERR_NO_CONNECTION` | no connection to the trade server |
| 8 | `ERR_TOO_FREQUENT_REQUESTS` | too many requests |
| 128 | `ERR_TRADE_TIMEOUT` | trade timed out — **uncertain outcome** |
| 136 | `ERR_OFF_QUOTES` | no prices right now |
| 137 | `ERR_BROKER_BUSY` | broker busy |
| 141 | `ERR_TOO_MANY_REQUESTS` | too many requests |
| 146 | `ERR_TRADE_CONTEXT_BUSY` | trade context busy |

### Requote — resend with a fresh price

| Code | Name |
|------|------|
| 135 | `ERR_PRICE_CHANGED` |
| 138 | `ERR_REQUOTE` |

### Validation — fix the request

| Code | Name | Common cause |
|------|------|--------------|
| 3 | `ERR_INVALID_TRADE_PARAMETERS` | malformed request |
| 129 | `ERR_INVALID_PRICE` | price breaks symbol rules |
| 130 | `ERR_INVALID_STOPS` | SL/TP too close (TradeStopsLevel) |
| 131 | `ERR_INVALID_TRADE_VOLUME` | volume < min / > max / wrong step |
| 145 | `ERR_TRADE_MODIFY_DENIED` | modification too close to market / frozen |
| 147 | `ERR_TRADE_EXPIRATION_DENIED` | expiration not allowed by the broker |

### Restrictions — check trading conditions

| Code | Name |
|------|------|
| 132 | `ERR_MARKET_CLOSED` |
| 133 | `ERR_TRADE_DISABLED` |
| 139 | `ERR_ORDER_LOCKED` |
| 140 | `ERR_LONG_POSITIONS_ONLY_ALLOWED` |
| 148 | `ERR_TRADE_TOO_MANY_ORDERS` |
| 149 | `ERR_TRADE_HEDGE_PROHIBITED` |
| 150 | `ERR_TRADE_PROHIBITED_BY_FIFO` |

### Money / account

| Code | Name |
|------|------|
| 64 | `ERR_ACCOUNT_DISABLED` |
| 65 | `ERR_INVALID_ACCOUNT` |
| 134 | `ERR_NOT_ENOUGH_MONEY` |

> The enum also defines the full MQL4 runtime range (`4000+`, e.g. `ERR_WRONG_FUNCTION_POINTER`) — those are MQL program errors, not trade rejections, and rarely surface through the API.

---

## 🔁 A retry pattern

MT4 raises on rejection, so categorise by `mql_code` and let `trade_outcome_unknown?` gate the uncertain ones:

```ruby
REQUOTE   = [135, 138].freeze
TEMPORARY = [4, 6, 8, 136, 137, 141, 146].freeze

def buy_with_retry(mt4, symbol, volume, tries: 3)
  tries.times do |i|
    begin
      r = mt4.buy_market(symbol, volume)
      return r if r.ticket.positive?
    rescue MetaRPC::MT4::TradeOutcomeUnknown
      raise                               # never auto-retry an uncertain trade
    rescue MetaRPC::MT4::ApiError => e
      raise e if e.trade_outcome_unknown?
      code = e.mql_code
      raise e unless REQUOTE.include?(code) || TEMPORARY.include?(code)  # permanent → stop
      sleep(REQUOTE.include?(code) ? 0.1 : i + 1)                        # requote fast, temp backoff
    end
  end
  nil
end
```

---

## 📑 Quick category reference

| Category | MQL4 codes | Action |
|----------|-----------|--------|
| Success | *(no code — `ticket > 0`)* | continue |
| Requote | 135, 138 | resend immediately with a fresh price |
| Temporary | 4, 6, 8, 136, 137, 141, 146 | retry with a delay |
| Uncertain | 128 (+ MRPC_TIMEOUT / transport drop) | **check open orders, don't blind-retry** |
| Validation | 3, 129, 130, 131, 145, 147 | fix the request |
| Restrictions | 132, 133, 139, 140, 148, 149, 150 | check conditions |
| Money / account | 64, 65, 134 | reduce volume / check account |

---

## See Also

* [Glossary → ApiError / Subscription](./GLOSSARY.md) · [ENUMs Reference](./ENUMS_USAGE_REFERENCE.md)
* [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md) — `enum MqlErrorCode` lists every code
* [MT4Sugar → Simple Trading](../MT4Sugar/4.%20Simple_Trading.md) · [Getting Started](./GETTING_STARTED.md)
