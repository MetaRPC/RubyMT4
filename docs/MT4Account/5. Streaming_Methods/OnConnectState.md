# 🔌 Streaming Connect-State

> **Stream:** the terminal's **connection state** as it changes. Yields `ConnectStateData` on a background thread. Lives on the **Connection** service (not SubscriptionService).

**API Information:**

* **Low-level API:** `MT4Account#on_connect_state` (from the `metarpc_mt4` gem)
* **gRPC service:** `mt4_term_api.Connection`
* **Proto definition:** `OnConnectState` (server-streaming)

### RPC

* **Service:** `mt4_term_api.Connection`
* **Method:** `OnConnectState(OnConnectStateRequest) → stream OnConnectStateReply`
* **Low-level client (generated):** `Mt4TermApi::Connection::Stub#on_connect_state(request, metadata:)`

---

## 💬 Just the essentials

* **What it is.** A push stream that reports the terminal's link health — connected / alive / server / last error — whenever it changes.
* **Why you need it.** Watchdog: detect a dropped broker link, surface reconnect status, drive an "online" indicator.
* **Yields `ConnectStateData`.**

---

## 🧱 Signature

```ruby
class MetaRPC::MT4::MT4Account
  # Terminal connect-state changes. `terminal_ids` is a repeated field; defaults to
  # this client's own id (accepts a single id or an array). Yields ConnectStateData
  # on a background thread. Returns a Subscription; call .cancel to stop.
  def on_connect_state(terminal_ids = @id) { |state| ... } -> MetaRPC::MT4::Subscription
end
```

**Request message:** `OnConnectStateRequest { repeated string terminal_ids = 1; }`

> **`terminal_ids` is REPEATED.** The SDK wraps your value with `Array(...)`, so `on_connect_state("id")`, `on_connect_state(["id1","id2"])`, or the default (this client's own id) all work.

**Reply (stream):** `OnConnectStateReply { ConnectStateData data; … }`.

---

## 🔽 Input

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `terminal_ids` | `String` / `Array<String>` | this client's `id` | Which terminal(s) to watch. |
| `&block` | block | — | Called with each `ConnectStateData`. |

---

## ⬆️ Yielded — `ConnectStateData`

| Field (proto) | Ruby accessor | Type | Description |
| ------------- | ------------- | ---- | ----------- |
| `id` | `id` | `String` | Terminal session id this state is for. |
| `state` | `state` | `String` | Human-readable state (e.g. `"Connected"`). |
| `is_connected` | `is_connected` | `Boolean` | Linked to the broker. |
| `is_alive` | `is_alive` | `Boolean` | Terminal process alive. |
| `api_is_alive` | `api_is_alive` | `Boolean` | API bridge alive. |
| `server` | `server` | `String` | Broker server / cluster. |
| `account` | `account` | `Integer` | Account login. |
| `error_message` | `error_message` | `String` | Last error, if any. |
| `timestamp` | `timestamp` | `Timestamp` | When this state was observed. |

---

## 🧩 Notes & Tips

* **Different service.** Unlike the other streams, this one is on `mt4_term_api.Connection`.
* **Defaults to your terminal** — omit `terminal_ids` to watch the one you connected.
* **Pairs with `reconnect`** — on `is_connected == false`, you might call [`reconnect`](../MT4Account.Master.Overview.md#constructor-connection) and keep watching.
* **Returns a `Subscription`** — `sub.cancel` to stop; don't cancel inside the block.

---

## 🔗 Usage Examples

### 1) Watch link health

```ruby
sub = acct.on_connect_state do |st|
  puts "#{st.state}  connected=#{st.is_connected} alive=#{st.is_alive} server=#{st.server}"
end
sleep 10
sub.cancel
```

### 2) Alert on disconnect

```ruby
sub = acct.on_connect_state do |st|
  warn "⚠️ link down: #{st.error_message}" unless st.is_connected
end
sleep 30
sub.cancel
```

### 3) Watch several terminals

```ruby
ids = acct.accounts.map(&:id) rescue [acct.id]
sub = acct.on_connect_state(ids) { |st| puts "#{st.id}: #{st.state}" }
sleep 5
sub.cancel
```

---

## 📚 See Also

* **Health checks (one-shot):** `check_connect` / `connect_state` / `connection_status` — see [Constructor & connection](../MT4Account.Master.Overview.md#constructor-connection).
* **Friendly layer:** [`MT4Service#on_connect_state`](../../MT4Service/MT4Service.Overview.md).

---

**Back to:** [Streaming Methods — Overview](./Streaming_Methods.Overview.md) · [MT4Account — Master Overview](../MT4Account.Master.Overview.md)
