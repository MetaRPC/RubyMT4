# RubyMT4 — fleet audit (MT4, prod gateway `mt4.mrpc.pro:443`)

Audited 2026-10-20 against `VantageFX-Demo` login 893310151 (demo, USD, 1:100, 381 symbols). Every
step of `fleet/runners/ruby-mt4/smoke/smoke.rb` passes on Windows (Ruby 3.3.12, grpc 1.83.1,
protobuf 4.36.1) and on the Debian 12 VPS (Ruby 3.1.2, grpc 1.80.0, protobuf 4.35.1). Read this before
implementing a strategy on the `ruby-mt4` runner.

**Verdict: usable — after the fixes below.** The upstream gem as vendored was NOT a working SDK: its
`Client` was a mock (hard-coded 10 000 USD account, `rand` tickets, no network call anywhere) and its
generated protobuf files could not be loaded on any current `google-protobuf`. Both are fixed in
`lib/RubyMT4` (and mirrored + committed in `C:/git/setup_RubyMT4`).

**MT4 is not MT5.** There are no positions, no deals, no retcodes: a filled market order IS the
position, its `ticket` is what you modify/close, rejections arrive as exceptions with an MQL4 error
number, and a partial close creates a *new* ticket. Details in §6.

---

## 1. Install / reference

Not on rubygems. Reference the vendored gem by path (relative to your Gemfile):

```ruby
# Gemfile
source "https://rubygems.org"
gem "metarpc_mt4", path: "../../../../lib/RubyMT4"   # from fleet/runners/ruby-mt4/<thing>/
gem "bigdecimal", ">= 3.1", "< 4"                     # keep Ruby's bundled bigdecimal (no native build)
```

Runtime dependencies (declared in the gemspec): `grpc >= 1.60`, `google-protobuf >= 4.26`,
`googleapis-common-protos-types >= 1.4`. Ruby >= 3.1.

```ruby
require "bundler/setup"
require "metarpc_mt4"      # defines MetaRPC::MT4::Client (alias MetaRPC::MT4::Account) and Mt4TermApi::* messages
```

The gem adds its own `package/` directory to `$LOAD_PATH` (the generated `*_pb.rb` files require each
other by bare name), so nothing else is needed. **Never commit a `Gemfile.lock` from a runner folder**:
the Windows lock pins gem versions that do not exist on the VPS (`fleet/runners/**/Gemfile.lock` is
gitignored; if a stale one is present on the VPS, `rm Gemfile.lock` and re-run).

### Build / run — Windows

```powershell
# one-off: gems are prebuilt for x64-mingw-ucrt, no MSYS2 needed
gem install grpc google-protobuf googleapis-common-protos-types
cd C:\git\trading-bots\fleet\runners\ruby-mt4\smoke
$env:MRPC_API_KEY="mrpc_live_..."; $env:MT4_LOGIN="893310151"; $env:MT4_PASSWORD="..."; $env:MT4_SERVER="VantageFX-Demo"
bundle exec ruby smoke.rb
```
(`bundle install` tries to fetch a newer `bigdecimal` and fails without MSYS2; `bundle exec` resolves
against the installed gems and works.)

### Build / run — VPS (Debian 12, Ruby 3.1.2, rubygems 3.3.15, bundler 2.6.9)

```bash
# one-off, already done on back.mrpc.pro (≈45 min: the prebuilt x86_64-linux grpc gem needs rubygems ≥ 3.3.22, so grpc 1.80 compiles from source)
nice gem install --no-document grpc google-protobuf googleapis-common-protos-types
cd /opt/fleet-audit/RubyMT4/fleet/runners/ruby-mt4/smoke      # or /opt/fleet/fleet/runners/ruby-mt4/smoke
rm -f Gemfile.lock
MRPC_API_KEY=... MT4_LOGIN=893310151 MT4_PASSWORD=... MT4_SERVER=VantageFX-Demo bundle exec ruby smoke.rb
```
Offline unit tests: `cd lib/RubyMT4 && ruby -Ilib test/test_client.rb` (10 runs, 31 assertions).
Copy to the VPS: `tar -C C:/git/trading-bots -cf - fleet/runners/ruby-mt4/smoke lib/RubyMT4 | ssh ... 'tar -C /opt/fleet-audit/RubyMT4 -xf -'`.
No build step: Ruby + the vendored `package/` run as-is on Linux (no path-separator / case issues found).

---

## 2. Copy-pasteable call signatures (all verified live on prod)

### Connect (ConnectEx by server name, stable terminal id)

```ruby
# STABLE id per strategy: uuid5(DNS namespace, strategy id) -> same terminal reused on every run.
tid  = MetaRPC::MT4::Client.uuid5(MetaRPC::MT4::Client::NAMESPACE_DNS, "fleet-audit-RubyMT4")  # "ceed89e3-6059-5c78-b9b2-ddae14d7754d"
acct = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"], id: tid, timeout: 60)

begin
  data = acct.connect(893310151, "password", server: "VantageFX-Demo", name: "S101", timeout_seconds: 120)
  # data: Mt4TermApi::ConnectData  (terminal_instance_guid = "mt4_live_<id-without-dashes>", terminal_type = :MT4)
rescue MetaRPC::MT4::InvalidLoginError => e
  # broker rejected the credentials -> terminal for this strategy, NEVER retry
rescue MetaRPC::MT4::ApiError, GRPC::BadStatus => e
  # transient: back off and retry connect
end
acct.metadata   # => {"apikey"=>..., "id"=>tid}  sent with every RPC
```
Connect costs ~15 s when the gateway has to start the MT4 terminal (cold), 0.1–0.2 s when the terminal
bound to `id` is already alive (re-runs). The routing key is the `id` you send; `acct.server_guid` holds
the gateway's alias.

Also available: `acct.connect_by_host(login, pwd, host:, port:)` (raw trade-server address),
`acct.check_connect` (CheckConnectData: health_check.is_alive / api_is_alive / terminal_is_connected_to_mt_server),
`acct.connect_state` (state "Connected"/"WrongPassword"/"Unreachable"/..., is_connected, server, account),
`acct.reconnect(force: false)`, `acct.disconnect(delete: false)`, `acct.accounts` (every terminal under the
API key, no `id` needed: terminal_id, login, server, name, state, is_connected).
**Do not disconnect at the end of a run** — leave the terminal bound to the stable id.
`HealthService.HealthCheck` is UNIMPLEMENTED on prod (gRPC status 12); it is not exposed.

### Account summary + DEMO guard

```ruby
s = acct.account_summary            # Mt4TermApi::AccountSummaryData
s.account_login        # 893310151
s.account_balance      # 100000.0
s.account_equity       # 100000.0
s.account_currency     # "USD"
s.account_leverage     # 100
s.account_trade_mode   # :ACCOUNT_TRADE_MODE_DEMO | :ACCOUNT_TRADE_MODE_CONTEST | :ACCOUNT_TRADE_MODE_REAL
s.account_company_name # "Vantage Markets (Pty) Ltd"
s.account_credit; s.is_investor; s.account_user_name
s.server_time_utc      # Google::Protobuf::Timestamp (.to_time); server_time is broker-tz
s.server_utc_offset_seconds   # 10800 on VantageFX (UTC+3); nil until the first live quote arrives
abort "not demo" unless acct.demo?  # == account_trade_mode == :ACCOUNT_TRADE_MODE_DEMO
```
There is no AccountInfoDouble/Integer/String on MT4; margin/free margin come from `on_opened_orders_profit`
(account_info.margin / free_margin / margin_level) or TradeStats.

### Symbols / quote

```ruby
acct.symbols                             # ["EURUSD", ...] all 381 names on the server (one call, ~200 ms)
acct.symbol_exist("EURUSD")              # convenience over #symbols (fetches the list)
acct.symbol_select("EURUSD", true)       # add to Market Watch -> true/false (needed before quote/orders on fresh terminals)

q = acct.quote("EURUSD")                 # Mt4TermApi::QuoteData  <- PRICES COME FROM HERE (alias symbol_info_tick)
q.bid; q.ask; q.high; q.low; q.date_time_utc (Timestamp, .to_time); q.date_time (broker tz)
# reject quotes with bid <= 0 or ask <= 0 (fresh Market-Watch symbol) and bid == ask (demo feeds publish them)
acct.quote_many(%w[EURUSD XAUUSD BTCUSD]) # [QuoteData]

sp = acct.symbol_spec("EURUSD")          # MetaRPC::MT4::SymbolSpec (nil if unknown) <- SPECS COME FROM HERE
sp.digits (5)  sp.point (1e-5)  sp.contract_size (100000.0)
sp.volume_min (0.01)  sp.volume_max (100.0)  sp.volume_step (0.01)
sp.stops_level (0 on VantageFX)  sp.freeze_level  sp.tick_size  sp.tick_value
sp.trade_mode   # :SYMBOL_TRADE_MODE_FULL / _DISABLED / _LONGONLY / _SHORTONLY / _CLOSEONLY
sp.exe_mode     # :SYMBOL_TRADE_EXECUTION_MARKET / _INSTANT / _REQUEST / _EXCHANGE
sp.calc_mode    # :SYMBOL_TRADE_MARGINE_CALC_MODE_FOREX / _FUTURES / _CFD
sp.currency_base; sp.currency_profit; sp.currency_margin; sp.swap_long; sp.swap_short; sp.description; sp.path; sp.selected
sp.raw          # the Mt4TermApi::SymbolParamsManyInfo underneath: fields are CAPITALISED there (raw.Digits, raw.Point,
                # raw.VolumeMin, raw.TradeContractSize, raw.TradeStopsLevel, raw.TradeMode, raw.SymbolName, raw.Bid ...)
acct.symbol_params("EURUSD")             # the raw message; acct.symbol_params_many -> all symbols' raw specs in ONE call
acct.tick_value_with_size(%w[EURUSD XAUUSD])   # [SymbolTickValueWithSizeInfo: symbolName TradeTickValue TradeTickSize TradeContractSize]
```

### Bars

```ruby
bars = acct.last_bars("EURUSD", timeframe: :M1, count: 50)       # newest 50 bars, oldest first (widens the window over weekends)
bars = acct.bars("EURUSD", timeframe: :H1, from_utc: Time.now - 3*86400, to_utc: Time.now)   # explicit range, auto-paged (page_size: 1000)
b = bars.last   # Mt4TermApi::QuoteHistoryBar
b.time_utc (unix s)  b.time (unix s, broker tz)  b.open b.high b.low b.close  b.tick_volume  b.spread (points)  b.real_volume (0 on MT4)
# timeframe: :M1 :M5 :M15 :M30 :H1 :H4 :D1 :W1 :MN1  (MT4 has exactly these nine; Client::TIMEFRAMES maps to QHB_PERIOD_*)
# QUOTE_HISTORY_NOT_READY (terminal still downloading from the broker) is retried 10x with 1 s pauses inside #bars.
acct.quote_history("EURUSD", timeframe: :M5, from_utc: Time.now - 3600)   # legacy MarketInfo.QuoteHistory ([HistoryQuote], Timestamp time_utc); deprecated on the gateway
```
The last bar is the still-forming one. `price_history` is an alias of `bars`.

### Tick stream (subscribe / unsubscribe)

```ruby
sub = acct.on_symbol_tick(%w[EURUSD XAUUSD]) do |t|   # runs on a background thread
  # t: Mt4TermApi::OnSymbolMqlTickInfo  t.symbol t.bid t.ask t.last t.volume t.time_utc (Timestamp) t.time (broker tz) t.time_msc t.time_msc_utc
end
sleep 10
sub.cancel          # clean unsubscribe (gRPC cancel + thread join); sub.count = ticks received; sub.error = exception if the stream died
sub.alive?

n = acct.each_tick(["EURUSD"], seconds: 10) { |t| ... }     # blocking convenience: returns tick count
acct.on_trade { |ev| ... }                                  # OnTradeData: ev.event_data.new_orders / updated_orders(.previous/.current) / removed_orders / new_history_orders, ev.account_info
acct.on_opened_orders_profit(interval_ms: 1000) { |d| ... } # periodic P/L of open orders + account_info (balance equity margin free_margin margin_level)
acct.on_opened_orders_tickets(interval_ms: 1000) { |d| ... }# d.position_tickets / d.pending_order_tickets
```
A stream that ends by itself (server restart, terminal recycled) sets `sub.error` (a `GRPC::BadStatus`)
and the thread exits; resubscribe in your loop. Measured: EURUSD 0.3–1.2 ticks/s at 00:35–00:45 UTC
(Asian session, quiet).

### Orders

```ruby
r = acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.01, magic: 600101, comment: "S101", slippage: 20)
# type: :buy :sell :buy_limit :sell_limit :buy_stop :sell_stop (or the raw OC_OP_* symbol); price: required for pendings, ignored for market
# optional: stop_loss:, take_profit:, expiration_utc: (pendings); slippage is in POINTS (default 0 -> requotes possible on fast markets)
r.ticket          # 439635621  -> this IS the position ticket; > 0 means filled (there is no retcode)
r.price; r.volume; r.open_time_utc (Timestamp)
acct.buy("EURUSD", 0.01, magic: 600101, comment: "S101", slippage: 20)   # shorthand; acct.sell likewise

m = acct.order_modify(ticket: r.ticket, stop_loss: 1.1203, take_profit: 1.1233)   # pendings: + price:, expiration_utc:
m.order_was_modified   # true

c = acct.order_close(ticket: r.ticket, slippage: 20)          # full close; lots: 0.01 for partial; pending ticket -> delete
c.mode                 # :OCD_MARKET_ORDER / :OCD_PENDING_ORDER ;  c.history_order_comment
acct.order_close_by(ticket:, opposite_ticket:)                # close a buy with a sell of the same symbol
```
**Rejections raise `MetaRPC::MT4::ApiError`** — there is no "returned_code 10009" on MT4. `e.mql_code`
is the MQL4 trade error (130 invalid stops, 131 invalid volume, 132 market closed, 133 trade disabled,
134 not enough money, 136 off quotes, 138 requote, 4108 invalid ticket, ...), `e.code` the gateway's
string code, `e.error` the full `Mt4TermApi::Error`. Exact shapes seen on prod are in §6.
Round volume to `volume_step` and clamp to `[volume_min, volume_max]` yourself.

### Open orders / filtering by magic

```ruby
acct.positions(magic: 600101)                    # [Mt4TermApi::OpenedOrderInfo] open MARKET orders (OO_OP_BUY/OO_OP_SELL) with that magic
acct.positions(magic: 600101, symbol: "EURUSD")
acct.pending_orders(magic: 600101)               # open pending orders (OO_OP_BUYLIMIT / SELLLIMIT / BUYSTOP / SELLSTOP)
o.ticket o.symbol o.order_type o.lots o.open_price o.stop_loss o.take_profit o.profit o.swap o.commision (sic) o.magic_number o.comment
o.open_time_utc (Timestamp) o.expiration_time_utc o.account_login
acct.opened_orders                               # everything, unfiltered (sort: :SORT_BY_OPEN_TIME_ASC | _DESC | :SORT_BY_ORDER_TICKET_ID_ASC | _DESC)
acct.opened_orders_tickets                       # [Integer]
```
The gateway has no server-side magic filter; every runner filters `magic_number == own magic`.

### History

```ruby
rows = acct.orders_history(from_utc: Time.now.utc - 3600)            # [Mt4TermApi::HistoryOrderInfo], auto-follows next_page_token
# range is on the order's OPEN time; sort: :HISTORY_SORT_BY_CLOSE_TIME_ASC (default) | _DESC | :HISTORY_SORT_BY_OPEN_TIME_ASC | _DESC | :HISTORY_SORT_BY_ORDER_TICKET_ID_ASC | _DESC
rows.each do |o|
  o.ticket o.symbol o.order_type o.lots o.open_price o.close_price o.profit o.swap o.commision o.magic_number o.comment
  o.open_time_utc o.close_time_utc (Timestamps; .to_time)
end
mine = rows.select { |o| o.magic_number == 600101 }     # magic survives into history; comment may be rewritten by the broker (see §6)
```
`order_history` is an alias. Balance/credit operations are not in this list (MT4 keeps them as orders of
type 6; the gateway's enum only has 0–5 and such rows did not appear in the audit range).

### Errors / reconnect

```ruby
rescue MetaRPC::MT4::InvalidLoginError   # terminal; log and stop the strategy (error_code/message matching INVALID_LOGIN|WrongPassword|INVALID_ACCOUNT)
rescue MetaRPC::MT4::ApiError => e       # e.error (Mt4TermApi::Error): type, error_code, error_message, mql_error_code, mql_error_int_code, mql_error_description; e.code; e.mql_code
rescue GRPC::DeadlineExceeded, GRPC::Unavailable, GRPC::Internal, GRPC::Unimplemented => e   # transport/gateway: back off (1,2,4,...60 s) then acct.connect(...) again with the SAME id
```
There is no automatic reconnect in the client (by design: the host owns the back-off policy). The
per-RPC deadline is `timeout:` (default 60 s; connect uses `timeout_seconds + 30`; bars/history/symbols 120 s;
`acct.timeout = 20` changes it at runtime). Calling `connect` again with the same `id` revives the same
terminal (0.1 s if it is alive, ~15 s if it has to be recreated).

---

## 3. Bugs found and fixed (all in `lib/RubyMT4`, mirrored to `C:/git/setup_RubyMT4` and committed there)

| # | Bug | Fix |
|---|---|---|
| 1 | **Generated `package/*_pb.rb` used the legacy `DescriptorPool.generated_pool.build do add_file ... add_message` DSL**, removed in google-protobuf 4.x. `require "mrpc-mt4-error_pb"` fails with `undefined method 'build' for an instance of Google::Protobuf::DescriptorPool` on every current gem; the package was unloadable. It also lacked the `Accounts` and `QuoteHistory` services the gateway now serves. | Regenerated all 15 MT4 protos (the gateway's own `Mrpc.TerminalManager/proto/mt4/*.proto` + `internal/mt4-term-api-charts.proto`) with `grpc_tools_ruby_protoc` 1.84 → `add_serialized_file` form. Imports flattened (`mt4/` prefix dropped) to keep the flat `package/` layout. 29 files, loads on protobuf 4.35/4.36. |
| 2 | **`lib/metarpc_mt4/client.rb` was a mock**: `account_info` returned a hard-coded 10 000 USD account, `order_send` returned `rand(100000..999999)` tickets, `subscribe_quotes` was an empty method, `connect` only set a flag; no gRPC call anywhere while README/docs promised a working SDK. | Rewrote `MetaRPC::MT4::Client` as a real gRPC client (TLS, `apikey`+`id` metadata, oneof data/error unwrapping, server-streaming on a cancelable background thread, auto-paging for bars/history/accounts, snake_case `SymbolSpec`). Public surface documented above. Kept `compute_deterministic_id`, `connected?`, `disconnect(delete:)`, `last_disconnect_deleted` for compatibility. |
| 3 | `metarpc_mt4.gemspec` declared no runtime dependencies and did not ship `package/`, so a path/gem install had neither `grpc` nor the stubs. | Added `grpc`, `google-protobuf`, `googleapis-common-protos-types` deps, `package/**` to files, `require_paths = ["lib","package"]`, `required_ruby_version >= 3.1`. |
| 4 | `examples/quickstart.rb` and `test/test_client.rb` exercised the mock (asserting the fake 10 000 balance and the random ticket). | Rewritten: quickstart does connect/summary/quote/bars/stream (+ `TRADE=1` demo round-trip); tests are offline (metadata, uuid5 vs Python, message construction, error unwrapping, invalid-login detection, SymbolSpec mapping, unknown-symbol nil): `10 runs, 31 assertions, 0 failures`. |
| 5 | README said `gem install rubymt4` (no such gem) and documented a `TRIAL` key flow. | README install/run sections now show the path dependency, the deps and the env vars. |
| 6 | `HealthService.HealthCheck` is in the proto but answers `GRPC::Unimplemented` (status 12) on prod. | Not exposed by the client (comment in code); use `check_connect` / `connect_state`. |

Found while writing the client (not bugs in the vendored code, but easy to get wrong):
`SymbolParamsManyInfo` field names are Capitalised (`Digits`, `Point`, `VolumeMin`, `SymbolName`, `Bid`),
except `is_selected`, `visible`, `session_*`, `volume*` — hence `symbol_spec`; `SymbolsData.SymbolNameInfos`
is capitalised too; `OnSymbolTickReply.data.symbol_tick`; `OrderSendRequest` uses `stoploss`/`takeprofit`/
`magic_number`/`operation_type`, `OrderModifyRequest` uses `order_ticket`/`new_stop_loss`/`new_take_profit`/
`new_price`, `OrderCloseDeleteRequest` uses `order_ticket`/`lots`/`closing_price`; the opened-orders sort enum is
`SORT_BY_OPEN_TIME_ASC` while history sort is `HISTORY_SORT_BY_CLOSE_TIME_ASC`; `QuoteHistory.Bars` needs
`from_time_utc` (unix seconds, not a Timestamp) and `to_time_utc: 0` means "now"; the legacy
`QuoteHistoryRequest` uses camelCase `fromTimeUtc`/`toTimeUtc` Timestamps.

---

## 4. Performance (prod, VantageFX-Demo, EURUSD, 00:35–00:45 UTC, Asian session)

| Metric | Windows (Ruby 3.3.12, grpc 1.83.1) | VPS (Ruby 3.1.2, grpc 1.80.0) |
|---|---|---|
| connect, cold (terminal created) | 14.7 s | — (terminal already alive) |
| connect, warm (same id, terminal alive) | 0.18–0.23 s | 0.11 s |
| account_summary | 105–133 ms | 16 ms |
| symbols (381 names) + symbol_select + quote + symbol_spec | 221–339 ms | 474 ms |
| last_bars 50×M1 (QuoteHistory.Bars) | 36–379 ms | 57 ms |
| tick stream EURUSD | 7–12 ticks / 10 s | 3 ticks / 10 s |
| order_send market → filled (+ OpenedOrders confirm) | 319–545 ms | 687 ms |
| order_modify / order_close | 395–518 ms / 323–330 ms | 755 ms / 362 ms |
| orders_history (1 h) | 37–84 ms | 47 ms |
| process RSS after the whole run | 36.4–36.8 MB | 38.1 MB |
| total smoke runtime (incl. 10 s stream) | 11.7 s warm / 27.0 s cold | 12.6 s |

Memory: one `Client` = one gRPC channel per service stub (9 stubs max, lazily created); the Ruby grpc gem's
thread pool is shared. A host running the fleet's MT4 Ruby strategies on a handful of terminals should stay
well under 150 MB. Streams run on Ruby threads and hold the GVL only while decoding.

---

## 5. VPS run (back.mrpc.pro, Debian 12, 2026-10-20 00:43 UTC)

```
terminal id: ceed89e3-6059-5c78-b9b2-ddae14d7754d
PASS connect (108 ms) guid=mt4_live_ceed89e360595c78b9b2ddae14d7754d type=MT4
PASS account (16 ms) login=893310151 balance=99999.5 equity=99999.5 currency=USD leverage=1:100 mode=ACCOUNT_TRADE_MODE_DEMO company="Vantage Markets (Pty) Ltd" utc_offset_s=10800
PASS symbols (474 ms) 381 symbols; EURUSD bid=1.12182 ask=1.12196 digits=5 point=1.0e-05 contract=100000.0 vol_min=0.01 vol_step=0.01 vol_max=100.0 stops_level=0 trade_mode=SYMBOL_TRADE_MODE_FULL exe=SYMBOL_TRADE_EXECUTION_MARKET quote_time_utc=2026-10-20 00:43:02 UTC
PASS bars (57 ms) 50 M1 bars, first=2026-10-19 23:54:00 UTC last: time_utc=2026-10-20 00:43:00 UTC o=1.12182 h=1.12182 l=1.12182 c=1.12182 v=2 spread=0
PASS stream (10050 ms) 3 ticks in 10s (0.3/s), first="EURUSD 1.12182/1.12196 @2026-10-20 00:43:02 UTC"
PASS order_open (687 ms) EURUSD ticket=439637667 price=1.12195 vol=0.01 open_time_utc=2026-10-20 00:43:28 UTC; open order: type=OO_OP_BUY lots=0.01 magic=599999 comment="fleet-audit" profit=-0.13
PASS order_modify (755 ms) ticket=439637667 sl=1.12032 tp=1.12332 modified=true; order now sl=1.12032 tp=1.12332
PASS order_close (362 ms) ticket=439637667 mode=OCD_MARKET_ORDER history_comment=""; remaining audit orders=[]
PASS history (47 ms) 7 closed orders opened in the last hour; audit: ticket=439637667 OO_OP_BUY EURUSD 0.01@1.12195->1.12195 pnl=-0.13 magic=599999 comment="fleet-audit" closed=2026-10-20 00:43:29 UTC
INFO rss=38.1 MB runtime=12.6 s ruby=3.1.2 grpc=1.80.0 protobuf=4.35.1
ALL PASS
```
Linux-only problem found: the Windows `Gemfile.lock` (bigdecimal 3.1.5, googleapis-common-protos-types 1.23.0)
made bundler 2.6.9 fail with `Could not find ... in locally installed gems`; fixed by not shipping lock files
(`.gitignore`) and `rm -f Gemfile.lock` before `bundle exec`. No code change was needed for Linux.

---

## 6. Things a strategy implementer must know

- **Stable `id`**: `Client.uuid5(Client::NAMESPACE_DNS, strategy.id)` (identical to Python's
  `uuid.uuid5(uuid.NAMESPACE_DNS, ...)`, verified byte-for-byte). Never `SecureRandom.uuid` per run.
- **DEMO guard**: `account_summary.account_trade_mode == :ACCOUNT_TRADE_MODE_DEMO` before any order
  (the enum has no `MRPC_` prefix on MT4).
- **Orders, not positions.** `order_send(...).ticket` is the position; `positions(magic:)` is just the
  open market orders (`OO_OP_BUY/OO_OP_SELL`) filtered by `magic_number`. Pendings are separate
  (`pending_orders`). Hedging is the norm on MT4: a buy and a sell on the same symbol are two tickets.
- **No retcodes.** Success = no exception and `ticket > 0` / `order_was_modified == true` /
  `mode == :OCD_MARKET_ORDER`. Failure = `MetaRPC::MT4::ApiError` with `e.mql_code` (MQL4 trade errors
  130/131/132/134/136/138...). Handle `GRPC::BadStatus` separately (transport).
- **Partial close creates a NEW ticket.** Closing 0.01 of a 0.02 order closes the original ticket (history
  comment `"to #<new>"`) and the remaining 0.01 lives on under a new ticket with comment `"from #<old>"`,
  same magic. Re-read `positions(magic:)` after any partial close; never cache tickets across it.
- **Broker rewrites comments.** A deleted pending shows `comment: "cancelled"`, partial closes show
  `"to #…"`/`"from #…"`, SL/TP hits show `"[sl]"`/`"[tp]"`. **Filter history by `magic_number`, not by
  comment.** Magic survives everything.
- **Enums are Ruby symbols** (`:OO_OP_BUY`, `:OC_OP_SELL`, `:ACCOUNT_TRADE_MODE_DEMO`,
  `:SYMBOL_TRADE_MODE_FULL`, `:QHB_PERIOD_M5`); compare with symbols, not ints. Open-order types use the
  `OO_OP_` prefix, send types `OC_OP_`, stream types `SUB_OP_` — same numbering (0 buy, 1 sell, 2 buy limit,
  3 sell limit, 4 buy stop, 5 sell stop).
- **Times**: `*_utc` fields are the ones to use (`time_utc` unix seconds on bars; `Timestamp` elsewhere →
  `.to_time`). The non-suffixed fields are broker-server local time (VantageFX = UTC+3,
  `server_utc_offset_seconds`). Requests take `from_utc:/to_utc:` (`Time` or Integer).
- **Volume**: clamp to `[volume_min, volume_max]`, round to `volume_step` (`(v / step).round * step`).
  0.001 lots is rejected by the broker, not by the gateway.
- **Stops**: `stops_level` is 0 on VantageFX but not everywhere; place SL/TP at least `stops_level * point`
  away from the current bid/ask (and on the correct side) or you get mql 130.
- **Slippage is in points** and defaults to 0: pass `slippage: 20` (or more on gold/crypto) on market
  orders to avoid requotes (138) on fast markets.
- **Fresh terminal + symbol not in Market Watch**: `symbol_select` then poll `quote` until bid/ask > 0.
- **Timeframes**: only M1 M5 M15 M30 H1 H4 D1 W1 MN1 exist on MT4. Use `last_bars` for "the latest N";
  `bars` for explicit ranges (auto-paged, oldest first; first request for a new symbol/period may take a
  few seconds while the terminal downloads).
- **Streams** run on background threads; do not call unary RPCs from inside the tick block if you need
  ordering guarantees — push to a `Queue` and consume in the strategy loop.
- **One Client per account**; stubs are cached per client. Create a fresh `Client` after a fatal error.
- **Do not `disconnect`** on shutdown (the fleet keeps terminals alive); `disconnect(delete: true)` only
  when retiring a strategy for good.
- **Unknown symbol**: `symbol_spec`/`symbol_params` return nil; `quote` raises `ApiError` (mql 4220 via
  SymbolSelect). Check `acct.symbols.include?(name)` once at start-up and cache the list.
- VantageFX-Demo symbol universe (381): FX majors/crosses, XAUUSD/XAGUSD (stops_level 20 points on gold),
  indices (DJ30, DJ30.r/.v/ft variants), stock CFDs (AAPL, TSLA, ...), crypto crosses (BTCUSD 24h, contract
  size 1, swap_long −20). Exact names in §7.

---

## 7. Live probe transcript (error shapes, pendings, partial close, on_trade)

Run 2026-10-20 00:44 UTC on Windows against the same account (the probe script is not part of the repo; every
call it made is in §2). Abridged, values verbatim:

```
connect 202 ms (warm)
connect_state: {state:"Connected", is_connected:true, is_alive:true, api_is_alive:true, server:"VantageFX-Demo", account:893310151}
check_connect: {health_check:{is_alive:true, api_is_alive:true, terminal_is_connected_to_mt_server:true}}
accounts under key: 15; mine: [["mt4_live_ceed89e360595c78b9b2ddae14d7754d", "fleet-audit-RubyMT4", "Connected", true]]
quote_many: [["EURUSD", 1.12183, 1.12196], ["XAUUSD", 4135.89, 4136.1], ["BTCUSD", 81705.07, 81722.03]]
XAUUSD spec: digits=2 point=0.01 contract_size=100.0 volume_min=0.01 volume_step=0.01 stops_level=20 freeze_level=20 tick_value=1.0
             trade_mode=:SYMBOL_TRADE_MODE_FULL exe=:SYMBOL_TRADE_EXECUTION_MARKET calc=:SYMBOL_TRADE_MARGINE_CALC_MODE_FOREX currency_base="XAU" path="Forex Gold\XAUUSD"
BTCUSD spec: digits=2 point=0.01 contract_size=1.0 volume_min=0.01 stops_level=0 tick_value=0.01 calc=:SYMBOL_TRADE_MARGINE_CALC_MODE_FUTURES
             swap_long=-20.0 swap_short=0.0 path="Crypto Currency\BTCUSD"          (24h; quoted on a Monday 00:44 UTC)
tick_value_with_size: [{symbolName:"EURUSD", TradeTickValue:1.0, TradeTickSize:1.0e-05, TradeContractSize:100000.0}, {symbolName:"XAUUSD", TradeTickValue:1.0, TradeTickSize:0.01, TradeContractSize:100.0}]
H1 bars 3d: 28 first=2026-10-18 21:00 UTC last=2026-10-20 00:00 UTC   (b.time (broker) = 03:00 -> UTC+3 confirmed)
legacy quote_history M5 1h: 12 bars
symbols: 381 incl. stock CFDs (AAPL, TSLA, ABNB, ABBVIE ...), indices (DJ30, DJ30.r, DJ30.v, DJ30ft ...), crypto crosses (BTCUSD, BTCEUR, BTCJPY, ETHEUR ...)

rejected order (buy with SL above ask) -> ApiError code="MQL4_CUSTOM_EXECUTION_FAILED" mql_code=0 type=MQL_CUSTOM_EXECUTION
                                           msg="Incorrect stop loss. Should be less than 1.12196000"       <- gateway-side validation, mql_code 0
bad volume (0.001)                      -> ApiError code="MQL4_EXECUTION_FAILED" mql_code=131
                                           msg="Command failed on mql4 script side. Function: OrderSend. ErrInvalidTradeVolume 131 invalid trade volume"   <- broker-side, MQL number set
quote("NOPE")                           -> ApiError code="MQL4_EXECUTION_FAILED" msg="... Function: SymbolSelect. ErrNoResult 4220 symbol select error"
symbol_params("NOPE")                   -> nil   (gateway: EXECUTION_ERROR_IN_INTERNAL_GRPC_SERVICE "Symbol pair name does not exist", mapped to nil by the client)

buy_limit placed ticket=439637787 price=1.11196 (requested 1.11196)
pending_orders(magic): [[439637787, :OO_OP_BUYLIMIT, 1.11196]]; positions(magic): 0
order_modify(price:) on the pending -> order_was_modified=true
order_close(ticket:) on the pending -> mode=:OCD_PENDING_ORDER        (history comment becomes "cancelled")
on_trade events (3):  OrderUpdate new=[439637787] | OrderUpdate upd=[439637787] | OrderUpdate rem=[439637787] hist=[439637787]
partial close 0.01 of a 0.02 sell ticket=439637817 -> mode=:OCD_MARKET_ORDER history_order_comment="to #439637818"
remaining after partial: [[439637818, 0.01, "from #439637817"]]      <- NEW ticket, same magic
history last 15 min (magic 599999): [.. [439637787, :OO_OP_BUYLIMIT, 0.01, "cancelled"], [439637817, :OO_OP_SELL, 0.01, "to #439637818"], [439637818, :OO_OP_SELL, 0.01, "from #439637817"] ..]
```

Error-code cheat sheet (`e.code` → meaning): `MQL4_CUSTOM_EXECUTION_FAILED` = the gateway's own pre-trade check
failed (message is human-readable, `mql_code` 0); `MQL4_EXECUTION_FAILED` = the MQL4 side failed (`mql_code`
= MQL4 error, message contains `Function: <name>` and the `Err...` name); `EXECUTION_ERROR_IN_INTERNAL_GRPC_SERVICE` =
gateway-internal (unknown symbol in SymbolParamsMany); `QUOTE_HISTORY_NOT_READY` = bars still downloading (retried
by `bars`); `CONNECT_EX_INVALID_LOGIN_ERROR` / `WrongPassword` = terminal, never retry; `TERMINAL_API_TIMEOUT`
= the terminal did not answer in time (transient).
