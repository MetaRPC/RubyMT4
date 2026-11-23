# ══════════════════════════════════════════════════════════════════════════════
# MT4Service — Mid-Level MetaTrader 4 Typed Facade
# ══════════════════════════════════════════════════════════════════════════════
#
# The mid layer of the three-layer stack:
#     MT4Account  →  MT4Service (this file)  →  MT4Sugar
#
# Wraps an MT4Account and hands you plain Ruby objects (Structs) and plain
# arguments instead of generated protobuf messages. Reads that span pages
# (history / bars) come back as ready arrays. The raw client is one hop away via
# #account. MT4 has ORDERS, not positions: an open market order IS the position.
#
# Returns tidy Structs: Quote(symbol, bid, ask, high, low, spread, time_utc),
# Account(login, balance, equity, currency, leverage, trade_mode, company,
# server_time_utc) and SymbolSpec (one symbol's full specification).
#
# METHOD GROUPS:
# ──────────────────────────────────────────────────────────────────────────────
#
# 1. CONNECTION (11 methods)
#    • connect                - Connect by broker server (cluster) name
#    • connect_by_host        - Connect by raw broker host:port
#    • connect_proxy          - Connect through a proxy
#    • get_id                 - Resolve the terminal session id
#    • connected?             - Connection status (local flag)
#    • reconnect              - Re-establish the broker connection
#    • disconnect             - Stop the terminal
#    • check_connect          - Verify the terminal is still attached
#    • connect_state          - Current connect state (one-shot)
#    • connection_status      - Current connection status
#    • close                  - Release channels (local only)
#
# 2. ACCOUNT & STATS (9 methods)
#    • account_info           - Typed Account snapshot (Struct)
#    • account_summary        - Raw AccountSummaryData (every field)
#    • demo?                  - Is this a demo account?
#    • accounts               - Terminals owned by the API key (list)
#    • server_timezone        - Broker server UTC offset
#    • trade_stats            - Aggregate trading statistics
#    • trade_stats_equity_history - Stats + equity / balance charts
#    • equity_history         - Equity / balance curve points
#    • trade_unrealized_pl    - Unrealized-P/L extrema
#
# 3. SYMBOLS & MARKET INFO (9 methods)
#    • quote                  - Typed best bid/ask (Quote struct)
#    • quote_many             - Typed quotes for several symbols
#    • tick                   - Raw QuoteData
#    • symbols                - Names of all symbols
#    • symbol_exist?          - Does a symbol exist?
#    • select_symbol          - Add / remove from Market Watch
#    • symbol_params          - Full spec of one symbol (SymbolSpec)
#    • symbol_params_all      - Full spec of every symbol (SymbolSpec[])
#    • tick_value_with_size   - Tick value / size / contract size
#
# 4. BARS (3 methods)
#    • bars                   - OHLC bars (oldest first)
#    • last_bars              - The newest N bars
#    • quote_history          - Legacy MarketInfo.QuoteHistory (deprecated)
#
# 5. STREAMS (6 methods)
#    • subscribe_ticks        - Stream ticks
#    • on_trade               - Stream trade events
#    • on_opened_orders_profit - Stream open orders' P/L on a timer
#    • on_tickets             - Stream open order ticket snapshots
#    • on_connect_state       - Stream connect-state changes
#    • each_tick              - Blocking: iterate ticks for N seconds
#
# 6. TRADING (6 methods)
#    • order_send             - Market or pending order
#    • buy / sell             - Market order shortcuts
#    • order_modify           - Modify SL / TP / price / expiration
#    • order_close            - Close a market order / delete a pending one
#    • order_close_by         - Close one order by an opposite one
#
# 7. ORDERS & HISTORY (5 methods)
#    • opened_orders          - All open orders (market + pending)
#    • opened_tickets         - Only the tickets (lightweight)
#    • positions              - Open MARKET orders (filter by magic / symbol)
#    • pending_orders         - Pending orders (filter by magic / symbol)
#    • order_history          - Closed / deleted orders
#
# ══════════════════════════════════════════════════════════════════════════════

require_relative "mt4_account"

module MetaRPC
  module MT4
    # MID-LEVEL layer — a typed facade over {MT4Account}.
    #
    # It wraps an MT4Account and hands you plain Ruby objects (Structs) and plain
    # arguments instead of generated protobuf messages: quotes become a {Quote}
    # struct, the account summary an {Account} struct, a symbol's spec a
    # {SymbolSpec}, and reads that span pages (history) come back as ready arrays.
    # Every low-level method is still one hop away via {#account}.
    #
    #   svc = MetaRPC::MT4::MT4Service.new(api_key: ENV["MRPC_API_KEY"])
    #   svc.connect(893310151, "pwd", server: "VantageFX-Demo")
    #   svc.account_info.balance        # => 10000.0
    #   q = svc.quote("EURUSD")         # Quote(bid:, ask:, high:, low:, spread:, time_utc:)
    #   svc.positions(magic: 600101)    # [Mt4TermApi::OpenedOrderInfo]  (market orders)
    class MT4Service
      # Tidy, read-only snapshots returned by the typed reads.
      Quote   = Struct.new(:symbol, :bid, :ask, :high, :low, :spread, :time_utc, keyword_init: true)
      Account = Struct.new(:login, :balance, :equity, :currency, :leverage, :trade_mode,
                           :company, :server_time_utc, keyword_init: true)

      # Plain snake_case view of one symbol's specification (see {#symbol_params}).
      SymbolSpec = Struct.new(
        :name, :digits, :point, :contract_size, :volume_min, :volume_max, :volume_step,
        :stops_level, :freeze_level, :tick_size, :tick_value, :trade_mode, :exe_mode, :calc_mode,
        :currency_base, :currency_profit, :currency_margin, :swap_long, :swap_short,
        :description, :path, :selected, :bid, :time_utc, :raw, keyword_init: true
      )

      attr_reader :account

      # Wrap an existing MT4Account, or build one from the same arguments.
      #
      #   MT4Service.new(existing_account)
      #   MT4Service.new(api_key: "...", id: "...")
      def initialize(account = nil, **opts)
        @account = account.is_a?(MT4Account) ? account : MT4Account.new(**opts)
      end

      # ════════════════════════════════════════════════════════════════════════════
      #region CONNECTION
      # ════════════════════════════════════════════════════════════════════════════

      # Connect by broker server (cluster) name.
      def connect(login, password, server:, **opts) = @account.connect(login, password, server: server, **opts)
      # Connect by raw broker host:port.
      def connect_by_host(login, password, host:, port:, **opts) = @account.connect_by_host(login, password, host: host, port: port, **opts)
      # Connect through a proxy.
      def connect_proxy(login, password, **opts) = @account.connect_proxy(login, password, **opts)
      # Resolve the terminal session id for a login/password (no connect needed).
      def get_id(login = nil, password = nil) = @account.get_id(login, password)
      # True once connected.
      def connected? = @account.connected?
      # Re-establish the terminal's broker connection.
      def reconnect(force: false) = @account.reconnect(force: force)
      # Stop the terminal (delete: true also removes it from the account list).
      def disconnect(delete: false, reason: nil) = @account.disconnect(delete: delete, reason: reason)
      # Verify the terminal is still attached (CheckConnectData).
      def check_connect = @account.check_connect
      # Current connect state, one-shot (ConnectStateData).
      def connect_state = @account.connect_state
      # Current connection status (ConnectionStatusData).
      def connection_status = @account.connection_status
      # Drop cached stubs / release channels (local only; does NOT stop the terminal).
      def close = @account.close

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region ACCOUNT & STATS
      # ════════════════════════════════════════════════════════════════════════════

      # Typed snapshot of the account.
      def account_info
        s = @account.account_summary
        Account.new(login: s.account_login, balance: s.account_balance, equity: s.account_equity,
                    currency: s.account_currency, leverage: s.account_leverage,
                    trade_mode: s.account_trade_mode, company: s.account_company_name,
                    server_time_utc: s.server_time_utc)
      end

      # Raw AccountSummaryData (every field), when you need more than {#account_info}.
      def account_summary = @account.account_summary

      # True when the account is a demo account.
      def demo? = @account.account_summary.account_trade_mode == :ACCOUNT_TRADE_MODE_DEMO

      # Terminals owned by the API key (auto-paged list of AccountsListItem-like rows).
      def accounts(include_stopped: false, page_size: 200) = @account.accounts(include_stopped: include_stopped, page_size: page_size)

      # Broker server UTC offset (Mt4TermApi::ServerTimezoneData).
      def server_timezone = @account.server_timezone

      # Aggregate trading statistics since `from_utc` (Mt4TermApi::StatsData).
      def trade_stats(from_utc: nil, from: nil) = @account.trade_stats(from_utc: from_utc, from: from)
      # Trading stats + equity / balance charts since `from_utc` (Mt4TermApi::StatsWithChartsData).
      def trade_stats_equity_history(from_utc: nil, from: nil, exclude_same_bars: false) = @account.trade_stats_equity_history(from_utc: from_utc, from: from, exclude_same_bars: exclude_same_bars)
      # Equity / balance curve points since `from_utc` ([Mt4TermApi::EquityPointData]).
      def equity_history(from_utc: nil, from: nil, exclude_same_bars: false) = @account.equity_history(from_utc: from_utc, from: from, exclude_same_bars: exclude_same_bars)
      # Unrealized-P/L extrema per open trade since `from_utc`.
      def trade_unrealized_pl(from_utc: nil, from: nil) = @account.trade_unrealized_pl(from_utc: from_utc, from: from)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region SYMBOLS & MARKET INFO
      # ════════════════════════════════════════════════════════════════════════════

      # Typed best bid/ask snapshot for a symbol.
      def quote(symbol)
        q = @account.quote(symbol)
        self.class.quote_of(q)
      end

      # Typed quotes for several symbols in one call.
      def quote_many(symbols) = @account.quote_many(symbols).map { |q| self.class.quote_of(q) }

      # Raw QuoteData (symbol, bid, ask, high, low, date_time, date_time_utc).
      def tick(symbol) = @account.quote(symbol)

      # Names of all symbols.
      def symbols = @account.symbol_list
      # Does the symbol exist on the server?
      def symbol_exist?(symbol) = @account.symbol_list.include?(symbol)
      # Show/hide a symbol in Market Watch.
      def select_symbol(symbol, select = true) = @account.symbol_select(symbol, select)

      # Full spec of one symbol ({SymbolSpec}), or nil if unknown.
      def symbol_params(symbol)
        p = @account.symbol_params_many(symbol)
        p && self.class.spec_of(p)
      end

      # Every symbol's spec in one call ([{SymbolSpec}]).
      def symbol_params_all = @account.symbol_params_many.map { |p| self.class.spec_of(p) }

      # Tick value / size / contract size for sizing.
      def tick_value_with_size(symbols) = @account.tick_value_with_size(symbols)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region BARS
      # ════════════════════════════════════════════════════════════════════════════

      # Price bars ([Mt4TermApi::QuoteHistoryBar]), oldest first.
      def bars(symbol, timeframe: :M1, from_utc:, to_utc: nil, page_size: 1000)
        @account.bars(symbol, timeframe: timeframe, from_utc: from_utc, to_utc: to_utc, page_size: page_size)
      end

      # The newest `count` bars (oldest first). Widens the lookback window until
      # enough bars exist (weekends / holidays), up to ~64x the nominal span.
      def last_bars(symbol, timeframe: :M1, count: 50)
        minutes = MT4Account::TIMEFRAME_MINUTES.fetch(timeframe.to_sym)
        span = count * minutes * 60 * 2
        now = Time.now.to_i
        result = []
        7.times do
          result = @account.bars(symbol, timeframe: timeframe, from_utc: now - span, to_utc: 0)
          break if result.size >= count
          span *= 2
        end
        result.last(count)
      end

      # Legacy MarketInfo.QuoteHistory (deprecated on the gateway, unpaged) — prefer {#bars}.
      def quote_history(symbol, timeframe: :M1, from_utc:, to_utc: Time.now.utc)
        @account.quote_history(symbol, timeframe: timeframe, from_utc: from_utc, to_utc: to_utc)
      end

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region STREAMS
      # ════════════════════════════════════════════════════════════════════════════

      # Tick stream (returns a Subscription).
      def subscribe_ticks(symbols, &block) = @account.on_symbol_tick(symbols, &block)
      # Trade-event stream.
      def on_trade(&block) = @account.on_trade(&block)
      # Open orders' P/L stream on a timer.
      def on_opened_orders_profit(interval_ms: 1000, &block) = @account.on_opened_orders_profit(interval_ms: interval_ms, &block)
      # Open order ticket snapshots stream on a timer.
      def on_tickets(interval_ms: 1000, &block) = @account.on_opened_orders_tickets(interval_ms: interval_ms, &block)
      # Terminal connect-state changes stream.
      def on_connect_state(terminal_ids = nil, &block) = @account.on_connect_state(terminal_ids || @account.id, &block)

      # Blocking variant: iterate ticks for `seconds`, then return the count.
      def each_tick(symbols, seconds:, &block)
        n = 0
        sub = @account.on_symbol_tick(symbols) { |t| n += 1; block&.call(t) }
        sleep seconds
        sub.cancel
        raise sub.error if sub.error && !sub.error.is_a?(GRPC::Cancelled)
        n
      end

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region TRADING
      # ════════════════════════════════════════════════════════════════════════════

      # Market or pending order (type: :buy/:sell/:buy_limit/...). Returns OrderSendData.
      def order_send(symbol:, type:, volume:, **opts) = @account.order_send(symbol: symbol, type: type, volume: volume, **opts)
      # Market buy / sell shortcuts.
      def buy(symbol, volume, **opts)  = @account.order_send(symbol: symbol, type: :buy,  volume: volume, **opts)
      def sell(symbol, volume, **opts) = @account.order_send(symbol: symbol, type: :sell, volume: volume, **opts)
      # Modify SL / TP / price / expiration.
      def order_modify(ticket:, **opts) = @account.order_modify(ticket: ticket, **opts)
      # Close a market order (lots nil = full) or delete a pending order.
      def order_close(ticket:, lots: nil, price: nil, slippage: 10) = @account.order_close(ticket: ticket, lots: lots, price: price, slippage: slippage)
      # Close one market order by an opposite one on the same symbol.
      def order_close_by(ticket:, opposite_ticket:) = @account.order_close_by(ticket: ticket, opposite_ticket: opposite_ticket)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region ORDERS & HISTORY
      # ════════════════════════════════════════════════════════════════════════════

      # All open orders (market + pending).
      def opened_orders(sort: :SORT_BY_OPEN_TIME_ASC) = @account.opened_orders(sort: sort)

      # Just the tickets of the open orders.
      def opened_tickets = @account.opened_orders_tickets

      # Open MARKET orders (= positions on MT4), filtered client-side by magic and/or symbol.
      def positions(magic: nil, symbol: nil)
        @account.opened_orders.select do |o|
          MT4Account::MARKET_ORDER_TYPES.include?(o.order_type) &&
            (magic.nil? || o.magic_number == magic) && (symbol.nil? || o.symbol == symbol)
        end
      end

      # Pending orders, filtered client-side by magic and/or symbol.
      def pending_orders(magic: nil, symbol: nil)
        @account.opened_orders.reject { |o| MT4Account::MARKET_ORDER_TYPES.include?(o.order_type) }
                .select { |o| (magic.nil? || o.magic_number == magic) && (symbol.nil? || o.symbol == symbol) }
      end

      # Closed / deleted orders between two UTC Times ([Mt4TermApi::HistoryOrderInfo]).
      def order_history(from_utc:, to_utc: Time.now.utc, sort: :HISTORY_SORT_BY_CLOSE_TIME_ASC, page_size: 1000)
        @account.orders_history(from_utc: from_utc, to_utc: to_utc, sort: sort, page_size: page_size)
      end

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region BUILDERS
      # ════════════════════════════════════════════════════════════════════════════

      # Build a {Quote} from a raw Mt4TermApi::QuoteData.
      def self.quote_of(q)
        Quote.new(symbol: q.symbol, bid: q.bid, ask: q.ask, high: q.high, low: q.low,
                  spread: (q.ask - q.bid), time_utc: q.date_time_utc)
      end

      # Build a {SymbolSpec} from a raw Mt4TermApi::SymbolParamsManyInfo (PascalCase fields).
      def self.spec_of(p)
        SymbolSpec.new(
          name: p.SymbolName, digits: p.Digits, point: p.Point, contract_size: p.TradeContractSize,
          volume_min: p.VolumeMin, volume_max: p.VolumeMax, volume_step: p.VolumeStep,
          stops_level: p.TradeStopsLevel, freeze_level: p.TradeFreezeLevel,
          tick_size: p.TradeTickSize, tick_value: p.TradeTickValue,
          trade_mode: p.TradeMode, exe_mode: p.TradeExeMode, calc_mode: p.TradeCalcMode,
          currency_base: p.CurrencyBase, currency_profit: p.CurrencyProfit, currency_margin: p.CurrencyMargin,
          swap_long: p.SwapLong, swap_short: p.SwapShort, description: p.SymDescription, path: p.Path,
          selected: p.is_selected, bid: p.Bid, time_utc: p.TimeUtc, raw: p
        )
      end

      #endregion
    end
  end
end
