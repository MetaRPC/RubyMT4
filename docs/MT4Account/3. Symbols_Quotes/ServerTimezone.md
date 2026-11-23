# 🕒 Getting the Server Time Zone

> **Request:** the broker server's UTC offset (`ServerTimezoneData`) from **MT4**. Answered cheaply from what the platform already knows.

**API Information:**

* **Low-level API:** `MT4Account#server_timezone` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.ServerTimezone`
* **Proto definition:** `ServerTimezone` (defined in `mt4-term-api-server-timezone.proto`)

### RPC

* **Service:** `mt4_term_api.ServerTimezone`
* **Method:** `ServerTimezone(ServerTimezoneRequest) → ServerTimezoneReply`
* **Low-level client (generated):** `Mt4TermApi::ServerTimezone::Stub#server_timezone(request, metadata:, deadline:)`

---

## 💬 Just the essentials

* **What it is.** The broker's offset from UTC, in seconds, plus how that figure was obtained.
* **Why you need it.** Every `*_utc` field of the API is the **broker server time minus this offset**. Use it to convert broker timestamps to/from UTC, and to label chart times correctly.
* **Cheap.** The platform answers from what it already knows — no round-trip to the broker.

---

## 🎯 Purpose

* Convert broker-local timestamps (`server_time`, bar `time`) to UTC and back.
* Align candle / session boundaries with the broker's trading day.
* Detect DST changes on the broker side (the offset shifts).

---

## 🧱 Signature

```ruby
require "metarpc_mt4"

class MetaRPC::MT4::MT4Account
  # Returns the broker server's UTC offset. Raises ApiError on failure.
  def server_timezone -> Mt4TermApi::ServerTimezoneData
end
```

**Request message:**

`ServerTimezoneRequest {}` *(empty message — the SDK builds it; `server_timezone` takes no arguments)*

**Reply message:**

```protobuf
ServerTimezoneReply {
  oneof response {
    ServerTimezoneData data = 1;
    Error error = 2;
  }
}
```

---

## 🔽 Input

**No parameters.** The SDK sends an empty `ServerTimezoneRequest`.

---

## ⬆️ Output — `ServerTimezoneData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `server` | `server` | `String` | Broker server / cluster name (e.g. `"EGlobal-Demo"`). |
| `utc_offset_seconds` | `utc_offset_seconds` | `Integer` | Broker server time minus UTC, in seconds (positive = ahead of UTC). |
| `source` | `source` | `Symbol` | How the offset was determined — see enum below. |
| `validated_utc` | `validated_utc` | `Timestamp` | When the offset was last validated (UTC). `.seconds` → unix seconds. |

---

## 🧱 Related enums (from proto)

### `SERVER_TIMEZONE_SOURCE`

```protobuf
enum SERVER_TIMEZONE_SOURCE {
  SERVER_TIMEZONE_SOURCE_UNKNOWN        = 0;  // not determined yet
  SERVER_TIMEZONE_SOURCE_LIVE           = 1;  // measured live against the server
  SERVER_TIMEZONE_SOURCE_LAST_VALIDATED = 2;  // last known good value
}
```

```ruby
tz = acct.server_timezone
fresh = tz.source == :SERVER_TIMEZONE_SOURCE_LIVE
```

---

## 🧩 Notes & Tips

* **Use it once, cache it.** The offset rarely changes within a session (only on broker DST shifts). Read it after connect and reuse.
* **`*_utc` fields already applied it.** Most API messages give you both broker-local and `*_utc` timestamps; you only need this call when you must convert a broker-local value yourself.
* **Errors are exceptions:** wrap in `begin/rescue` for `MetaRPC::MT4::ApiError`.

---

## 🔗 Usage Examples

### 1) Basic usage

```ruby
tz = acct.server_timezone
hours = tz.utc_offset_seconds / 3600.0
puts "#{tz.server}: UTC#{hours >= 0 ? '+' : ''}#{hours}  (source #{tz.source})"
```

### 2) Convert a broker-local timestamp to UTC

```ruby
tz = acct.server_timezone
broker_unix = acct.account_summary.server_time.seconds
utc = Time.at(broker_unix - tz.utc_offset_seconds).utc
puts "Broker time in UTC: #{utc.iso8601}"
```

### 3) Label bar times

```ruby
tz = acct.server_timezone
bars = acct.bars("EURUSD", timeframe: :H1, from_utc: Time.now.to_i - 86_400)
bars.last(3).each do |b|
  # bars already carry time_utc; this shows the broker-local equivalent
  broker = Time.at(b.time_utc + tz.utc_offset_seconds).utc
  puts "#{broker.strftime('%Y-%m-%d %H:%M')} (broker)  close #{b.close}"
end
```

---

## 📚 See Also

* [AccountSummary](../1.%20Account_Information/AccountSummary.md) — also carries `server_time` / `server_time_utc` / `server_utc_offset_seconds`.
* **Bars:** [Bars](./Bars.md) — OHLC history with `time` (broker) and `time_utc`.

---

**Back to:** [Symbols & Quotes — Overview](./Symbols_Quotes.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
