# ✅ Getting an Account Summary

> **Request:** full account summary (`AccountSummaryData`) from **MT4**. Fetch all core account metrics in a single call.

**API Information:**

* **Low-level API:** `MT4Account#account_summary` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.AccountHelper`
* **Proto definition:** `AccountSummary` (defined in `mt4-term-api-account-helper.proto`)

### RPC

* **Service:** `mt4_term_api.AccountHelper`
* **Method:** `AccountSummary(AccountSummaryRequest) → AccountSummaryReply`
* **Low-level client (generated):** `Mt4TermApi::AccountHelper::Stub#account_summary(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** A single RPC returning full account state: balance, equity, credit, currency, leverage, trade mode, margin / free margin / margin level / margin mode, and server time.
* **Why you need it.** Fast dashboard / CLI status; double-check login / currency / leverage; connection heartbeat via `server_time`.
* **Sanity check.** If `account_login`, `account_currency`, `account_leverage`, `account_equity` are set → the connection is alive.

---

## 🎯 Purpose

Use it to display real-time account state and sanity-check connectivity:

* Dashboard / CLI status in one call.
* Verify balance & equity before trading.
* Terminal heartbeat via `server_time` / `server_time_utc` and `server_utc_offset_seconds`.

> **Prefer plain values?** [`MT4Service#account_info`](../../MT4Service/MT4Service.Overview.md) returns a friendly `Account` Struct (named fields, times as numbers) instead of protobuf.

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # Retrieves full account information in a single call.
  # Returns the raw AccountSummaryData (read fields with snake_case accessors);
  # raises ApiError on failure.
  def account_summary -> Mt4TermApi::AccountSummaryData
end
```

**Request message:**

`AccountSummaryRequest {}` *(empty message — the SDK builds it for you; `account_summary` takes no arguments)*

**Reply message:**

```protobuf
AccountSummaryReply {
  oneof response {
    AccountSummaryData data = 1;
    Error error = 2;
  }
}
```

`MT4Account` unwraps the `oneof`: it returns `data` on success and **raises** `ApiError` (carrying the server-side `Error`) otherwise.

---

## 🔽 Input

**No parameters.** `account_summary` takes no arguments — the SDK sends an empty `AccountSummaryRequest`.

**There is no per-call timeout argument.** Each call runs on the account's deadline (`timeout`, default `60` s). Tune it on the account:

```ruby
acct.timeout = 15   # seconds — deadline for ordinary read RPCs
```

---

## ⬆️ Output — `AccountSummaryData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `account_login` | `account_login` | `Integer` | Trading account login (ID). |
| `account_balance` | `account_balance` | `Float` | Balance excluding floating P/L. |
| `account_equity` | `account_equity` | `Float` | Equity = balance + credit + floating P/L. |
| `account_user_name` | `account_user_name` | `String` | Account holder name. |
| `account_leverage` | `account_leverage` | `Integer` | Leverage (e.g. `100` for 1:100). |
| `account_trade_mode` | `account_trade_mode` | `Symbol` | Demo / Contest / Real — see enum below. |
| `account_company_name` | `account_company_name` | `String` | Broker / company display name. |
| `account_currency` | `account_currency` | `String` | Deposit currency (e.g. `"USD"`). |
| `server_time` | `server_time` | `Timestamp` | Server time at response (broker time zone). `.seconds` → unix seconds. |
| `server_time_utc` | `server_time_utc` | `Timestamp` | The same moment in UTC. |
| `account_credit` | `account_credit` | `Float` | Credit amount (bonus funds). |
| `is_investor` | `is_investor` | `Boolean` | Connected with the investor (read-only) password. |
| `utc_server_time_shift_minutes` | `utc_server_time_shift_minutes` | `Integer` | Server offset from UTC (minutes). |
| `server_utc_offset_seconds` | `server_utc_offset_seconds` | `Integer` | Broker offset from UTC in seconds (positive = ahead). |
| `account_margin` | `account_margin` | `Float` | Margin currently used by open orders. |
| `account_margin_free` | `account_margin_free` | `Float` | Free margin available for new orders. |
| `account_margin_level` | `account_margin_level` | `Float` | Margin level in percent (`equity / margin × 100`); `0` when no margin is used. |
| `account_margin_mode` | `account_margin_mode` | `Symbol` | Margin mode — see enum below. |
| `account_trade_allowed` | `account_trade_allowed` | `Boolean` | Trading allowed for this account. |
| `account_trade_expert` | `account_trade_expert` | `Boolean` | Automated (EA) trading allowed. |

> **🧮 Floating profit:** the summary has no dedicated profit field — compute `account_equity - account_balance - account_credit` (MT4: Equity = Balance + Credit + Floating P/L).

---

## 🧱 Related enums (from proto)

> **💡 Enum usage note:** generated protobuf enums come back as Ruby **symbols**. Compare against the full constant, e.g. `s.account_trade_mode == :ACCOUNT_TRADE_MODE_DEMO`.

### `EnumAccountTradeMode`

```protobuf
enum EnumAccountTradeMode {
  ACCOUNT_TRADE_MODE_DEMO    = 0;  // demo / practice
  ACCOUNT_TRADE_MODE_CONTEST = 1;  // contest
  ACCOUNT_TRADE_MODE_REAL    = 2;  // real trading
}
```

```ruby
def trade_mode_to_s(mode)
  case mode
  when :ACCOUNT_TRADE_MODE_DEMO    then "DEMO"
  when :ACCOUNT_TRADE_MODE_CONTEST then "CONTEST"
  when :ACCOUNT_TRADE_MODE_REAL    then "REAL"
  else "UNKNOWN(#{mode})"
  end
end
```

### `EnumAccountMarginMode`

```protobuf
enum EnumAccountMarginMode {
  ACCOUNT_MARGIN_MODE_RETAIL_NETTING = 0;  // netting (one position per symbol)
  ACCOUNT_MARGIN_MODE_EXCHANGE       = 1;  // exchange margin
  ACCOUNT_MARGIN_MODE_RETAIL_HEDGING = 2;  // hedging (many orders per symbol) — typical MT4
}
```

---

## 🧩 Notes & Tips

* **Errors are exceptions:** a server-side rejection raises `MetaRPC::MT4::ApiError`; a transport failure raises the gRPC error. Wrap in `begin/rescue`.
* **Default timeout:** read RPCs use the account's `timeout` (default `60` s).
* **Timestamps:** `server_time` / `server_time_utc` are `google.protobuf.Timestamp`; read `.seconds` for unix seconds, or use the friendly `MT4Service#account_info` which returns numbers.
* **Session is automatic:** `connect` obtains the terminal id and the SDK attaches it to this call — you never pass it yourself.
* **No single-property getter on MT4:** there is no `account_info_double/integer/string` (that is MT5). Read the field you need off the summary.

---

## 🔗 Usage Examples

### 1) Basic usage

```ruby
require "metarpc_mt4"

acct = MetaRPC::MT4::MT4Account.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"])
acct.connect(1235959737, "password", server: "EGlobal-Demo")

s = acct.account_summary
puts "Account Login: #{s.account_login}"
puts "Balance: #{s.account_balance.round(2)} #{s.account_currency}"
puts "Equity: #{s.account_equity.round(2)}"
puts "Leverage: 1:#{s.account_leverage}"
```

### 2) Compact status line for a CLI

```ruby
def print_account_status(acct)
  s = acct.account_summary
  puts "Acc #{s.account_login} | #{s.account_currency} | " \
       "Bal #{s.account_balance.round(2)} | Eq #{s.account_equity.round(2)} | " \
       "Lev 1:#{s.account_leverage} | Mode #{trade_mode_to_s(s.account_trade_mode)}"
rescue MetaRPC::MT4::ApiError => e
  puts "❌ Error: #{e.message}"
end
# Output: Acc 1235959737 | USD | Bal 10000.0 | Eq 10050.25 | Lev 1:100 | Mode DEMO
```

### 3) Floating profit & margin health

```ruby
def print_health(acct)
  s = acct.account_summary
  floating = s.account_equity - s.account_balance - s.account_credit
  level = s.account_margin_level                    # 0 when flat

  puts "Floating P/L: #{floating.round(2)}"
  if level.zero?       then puts "No open margin"
  elsif level < 100    then puts "⚠️ Margin level critical!"
  elsif level < 200    then puts "⚠️ Low margin level"
  else                      puts "✅ Healthy margin level"
  end
end
```

### 4) Server time with timezone shift

```ruby
def print_server_time(acct)
  s = acct.account_summary
  utc    = Time.at(s.server_time_utc.seconds).utc
  broker = Time.at(s.server_time.seconds).utc
  puts "Server time (UTC): #{utc.iso8601}"
  puts "Server time (broker): #{broker.iso8601}"
  puts "Broker offset from UTC: #{s.server_utc_offset_seconds} seconds"
end
```

### 5) Structured data model

```ruby
AccountView = Struct.new(:login, :currency, :balance, :equity, :floating, :leverage, :trade_mode, :company, keyword_init: true)

def from_proto(s)
  AccountView.new(
    login: s.account_login, currency: s.account_currency,
    balance: s.account_balance, equity: s.account_equity,
    floating: s.account_equity - s.account_balance - s.account_credit,
    leverage: s.account_leverage, trade_mode: trade_mode_to_s(s.account_trade_mode),
    company: s.account_company_name
  )
end

p from_proto(acct.account_summary)
```

### 6) Error handling

```ruby
def try_get_summary(acct)
  acct.account_summary
rescue MetaRPC::MT4::ApiError, GRPC::BadStatus => e
  puts "Failed to get account summary: #{e.message}"
  nil
end
```

---

## 🔧 Common Patterns

### Health check

```ruby
def account_healthy?(acct)
  s = acct.account_summary
  s.account_login.positive? && !s.account_currency.empty? && s.account_leverage.positive?
rescue StandardError
  false
end
```

### Monitor account changes

```ruby
def monitor_account(acct, interval_s)
  loop do
    s = acct.account_summary
    puts "[#{Time.now.strftime('%H:%M:%S')}] Balance: #{s.account_balance.round(2)} | Equity: #{s.account_equity.round(2)}"
    sleep interval_s
  rescue MetaRPC::MT4::ApiError => e
    puts "❌ Error: #{e.message}"
  end
end
# Usage: monitor_account(acct, 5)
```

---

## 📚 See Also

* [TradeStats](./TradeStats.md) — aggregate performance metrics (drawdown, profit factor, Sharpe).
* [ServerTimezone](../3.%20Symbols_Quotes/ServerTimezone.md) — broker UTC offset for interpreting `*_utc` timestamps.
* **Friendly layer:** [`MT4Service#account_info`](../../MT4Service/MT4Service.Overview.md) → a named `Account` Struct.

---

**Back to:** [Account Information — Overview](./Account_Information.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
