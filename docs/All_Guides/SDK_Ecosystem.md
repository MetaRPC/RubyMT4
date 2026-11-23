# The MetaRPC SDK family

> Where RubyMT4 sits — and how it pairs with the **Trade Copier** to mirror a strategy across accounts.

MetaRPC ships two families of SDKs. They share the **same authentication** (an `ApiKey` sent as gRPC metadata plus an owner `user_key` in the body), the **same gRPC-over-TLS transport** to `*.mrpc.pro`, the same [mrpc.pro](https://mrpc.pro/explorer/mt4-client) portal and the same demo onboarding — but they do different jobs.

| Family | Job | Endpoint | SDKs |
| ------ | --- | -------- | ---- |
| **Terminal SDKs** | operate **one** trading account — connect, read, trade, stream | `mt4.mrpc.pro:443` (MT4) | **RubyMT4**, GoMT4, CSharpMT4, CppMT4, JavaMT4, PyMT4, NodeMT4 (+ MT5 variants) |
| **Copier SDKs** | mirror trades **between** accounts (master → followers) | `copy.mrpc.pro:443` | [RubyCopier](https://github.com/MetaRPC/RubyCopier), NodeCopier, GoCopier, CSharpCopier, PyCopier, … |

**RubyMT4 is a Terminal SDK.** When you want to *replicate* what happens on one account to others, reach for the **Copier** SDK — in Ruby that's **[RubyCopier](https://github.com/MetaRPC/RubyCopier)** (`metarpc_copier`).

---

## How RubyMT4 and RubyCopier relate

|  | **RubyMT4** (this SDK) | **RubyCopier** |
| --- | --- | --- |
| Scope | one account | a master → follower **pair** |
| Does | `connect`, quotes, `buy_market`, streams | `start` · `list` · `pause` · `remove` a copier |
| Endpoint | `mt4.mrpc.pro:443` | `copy.mrpc.pro:443` |
| Thinks in | ticks, orders (= positions on MT4) | risk sizing, pause/resume, copy logs |

**One sentence:** RubyMT4 is where trades are *produced and observed* on an account; RubyCopier is how they're *distributed* to followers.

### The bridge — a shared terminal session

A copier account carries an optional **`id`** — a terminal session GUID. That's exactly the value RubyMT4 obtains on connect: after `connect` / `connect_ex`, the session GUID (`terminal_instance_guid`) lives on **`mt4.account.server_guid`**. So an account you're already running with RubyMT4 can be enrolled into a copier without the copier reconnecting it — pass that GUID (hyphenated via `RubyCopier.to_hyphen_guid`) as the account `id`.

RubyCopier understands account **`type`** values `MT4` (and `MT5`, cTrader `CT`, TradeLocker `TL`) — the same MRPC-hosted terminals RubyMT4 drives.

---

## End-to-end: run a strategy on the master, replicate to a follower

```ruby
require "metarpc_mt4"
require "rubycopier"      # git clone'd alongside; see Install below

KEY = ENV["MRPC_API_KEY"]   # owner key — note: TRIAL is NOT accepted by the copier

# 1 · Operate the MASTER account with RubyMT4
master = MetaRPC::MT4::MT4Sugar.create("mt4.mrpc.pro", 443, api_key: KEY)
master.quick_connect(ENV["MASTER_LOGIN"].to_i, ENV["MASTER_PASSWORD"], "EGlobal-Demo")
master_session_id = RubyCopier.to_hyphen_guid(master.account.server_guid)  # the ConnectEx GUID → copier id

# 2 · Start a copier: MASTER → FOLLOWER (RubyCopier, on copy.mrpc.pro)
copier = RubyCopier::CopierService.new("copy.mrpc.pro:443", user_key: KEY)
rep = copier.start(
  risk_type:  "LotMultiplier",   # or "FixedLot" + risk_value "0.1"
  risk_value: "1.0",
  copy_sl: true, copy_tp: true,
  master: { type: "MT4", user: ENV["MASTER_LOGIN"].to_i, password: ENV["MASTER_PASSWORD"],
            server: "EGlobal-Demo", id: master_session_id },
  slave:  { type: "MT4", user: ENV["SLAVE_LOGIN"].to_i,  password: ENV["SLAVE_PASSWORD"],
            server: "EGlobal-Demo" },
)
abort "copier start failed: #{rep.error}" unless rep.ok
puts "copier ##{rep.copier_id} running"

# 3 · Trades you now place on the master via RubyMT4 replicate to the follower
master.buy_market("EURUSD", 0.01)
# … the copier mirrors the open (and the later close) onto the follower account

# 4 · Tidy up
copier.remove(rep.copier_id)
```

> **Install:** RubyCopier isn't on RubyGems — clone it (`git clone https://github.com/MetaRPC/RubyCopier.git && cd RubyCopier && bundle install`) and `require` its `lib/rubycopier`, or point a Gemfile at the repo: `gem "metarpc_copier", git: "https://github.com/MetaRPC/RubyCopier.git"`.

**Risk sizing** (the copier's `risk_type`): `FixedLot` · `LotMultiplier` · `BalanceMultiplier` · `FixedBalanceMultiplier` · `EquityMultiplier`. Plus `copy_sl` / `copy_tp` / `copy_pending_orders` / `reverse_copy`. Manage a running copier with `copier.list`, `copier.pause(id, paused: true)` and `copier.remove(id)`.

---

## 🧩 Notes & gotchas

- **Two services, two endpoints.** RubyMT4 talks to `mt4.mrpc.pro`; RubyCopier to `copy.mrpc.pro`. The copier is a *companion* service, not a replacement.
- **Owner key required for the copier.** `TRIAL` works for a first look on a terminal, but `CopierService.new` **raises** without a real owner `user_key`.
- **Transport success ≠ broker execution.** A successful `start` means the copier was created — confirm the follower actually opened the trade (RubyCopier's logs, or read the follower with RubyMT4's `open_orders`).
- **Demo-first.** Use disposable demo accounts for copier tests. Hosted terminals and running copiers are billed separately (see [pricing](https://mrpc.pro/#pricing)).

---

## See also

- **Copier SDK:** [RubyCopier on GitHub](https://github.com/MetaRPC/RubyCopier) · [RubyCopier docs](https://metarpc.github.io/RubyCopier/) · [Quickstart](https://metarpc.github.io/RubyCopier/quickstart/).
- **This SDK:** [Getting Started](./GETTING_STARTED.md) · [Project Map](./PROJECT_MAP.md) · [MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md).
