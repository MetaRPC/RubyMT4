require "digest"
require "grpc"
require "google/protobuf/well_known_types"

# Generated protobuf / gRPC stubs live in <gem root>/package and require each
# other by bare file name, so that directory has to be on the load path.
MT4_PACKAGE_DIR = File.expand_path("../../package", __dir__)
$LOAD_PATH.unshift(MT4_PACKAGE_DIR) unless $LOAD_PATH.include?(MT4_PACKAGE_DIR)

%w[
  mrpc-mt4-error_pb
  mt4-term-api-connection_services_pb
  mt4-term-api-accounts_services_pb
  mt4-term-api-account-helper_services_pb
  mt4-term-api-market-info_services_pb
  mt4-term-api-quote-history_services_pb
  mt4-term-api-subscriptions_services_pb
  mt4-term-api-trading-helper_services_pb
  mt4-term-api-trade-stats_services_pb
  mt4-term-api-health-check_services_pb
  mt4-term-api-server-timezone_services_pb
].each { |f| require f }

module MetaRPC
  module MT4
    # Raised when the gateway answers with the `error` branch of a reply oneof
    # (MQL4 trade error, validation error, terminal timeout, ...).
    class ApiError < StandardError
      attr_reader :error

      def initialize(error, rpc_name = nil)
        @error = error
        super("#{rpc_name}: #{error.error_code} #{error.error_message} " \
              "(type=#{error.type} mql=#{error.mql_error_code}/#{error.mql_error_int_code} " \
              "#{error.mql_error_description})".strip)
      end

      # Gateway error code string, e.g. "CONNECT_EX_INVALID_LOGIN_ERROR", "QUOTE_HISTORY_NOT_READY".
      def code = error.error_code

      # MQL4 numeric trade/runtime error (130 invalid stops, 132 market closed, 134 no money, ...).
      def mql_code = error.mql_error_int_code
    end

    # Raised by connect when the broker rejects the login. Never retry this.
    class InvalidLoginError < ApiError; end

    # Plain snake_case view of one symbol's specification (see Client#symbol_spec).
    SymbolSpec = Struct.new(
      :name, :digits, :point, :contract_size, :volume_min, :volume_max, :volume_step,
      :stops_level, :freeze_level, :tick_size, :tick_value, :trade_mode, :exe_mode, :calc_mode,
      :currency_base, :currency_profit, :currency_margin, :swap_long, :swap_short,
      :description, :path, :selected, :bid, :time_utc, :raw, keyword_init: true
    )

    # Thin, honest wrapper over the MetaRPC MT4 gRPC gateway (mt4.mrpc.pro:443).
    #
    #   acct = MetaRPC::MT4::Client.new(api_key: ENV["MRPC_API_KEY"], id: stable_uuid)
    #   acct.connect(893310151, "pwd", server: "VantageFX-Demo", name: "S101")
    #   s = acct.account_summary            # Mt4TermApi::AccountSummaryData
    #   q = acct.quote("EURUSD")            # Mt4TermApi::QuoteData (bid/ask)
    #   r = acct.order_send(symbol: "EURUSD", type: :buy, volume: 0.01, magic: 600101, comment: "S101")
    #
    # Every RPC returns the `data` message of the reply (never the reply wrapper)
    # and raises ApiError when the reply carries an error, GRPC::BadStatus on
    # transport / gateway failures. MT4 has orders, not positions: an open market
    # order IS the position, and its ticket is what you modify / close.
    class Client
      DEFAULT_HOST = "mt4.mrpc.pro"
      DEFAULT_PORT = 443

      # QuoteHistory.Bars timeframes (value = bar length in minutes, like MQL4 ENUM_TIMEFRAMES).
      TIMEFRAMES = {
        M1: :QHB_PERIOD_M1, M5: :QHB_PERIOD_M5, M15: :QHB_PERIOD_M15, M30: :QHB_PERIOD_M30,
        H1: :QHB_PERIOD_H1, H4: :QHB_PERIOD_H4, D1: :QHB_PERIOD_D1, W1: :QHB_PERIOD_W1, MN1: :QHB_PERIOD_MN1
      }.freeze
      TIMEFRAME_MINUTES = { M1: 1, M5: 5, M15: 15, M30: 30, H1: 60, H4: 240, D1: 1440, W1: 10_080, MN1: 43_200 }.freeze

      # Legacy MarketInfo.QuoteHistory timeframes (different enum, same periods).
      LEGACY_TIMEFRAMES = {
        M1: :QH_PERIOD_M1, M5: :QH_PERIOD_M5, M15: :QH_PERIOD_M15, M30: :QH_PERIOD_M30,
        H1: :QH_PERIOD_H1, H4: :QH_PERIOD_H4, D1: :QH_PERIOD_D1, W1: :QH_PERIOD_W1, MN1: :QH_PERIOD_MN1
      }.freeze

      ORDER_TYPES = {
        buy: :OC_OP_BUY, sell: :OC_OP_SELL,
        buy_limit: :OC_OP_BUYLIMIT, sell_limit: :OC_OP_SELLLIMIT,
        buy_stop: :OC_OP_BUYSTOP, sell_stop: :OC_OP_SELLSTOP
      }.freeze

      MARKET_ORDER_TYPES = %i[OO_OP_BUY OO_OP_SELL].freeze

      attr_reader :host, :port, :api_key, :id, :login, :server, :name, :last_disconnect_deleted, :server_guid
      attr_accessor :timeout

      # Deterministic RFC-4122-looking id derived from login+password (used when
      # the caller gives no id). Prefer passing a stable `id:` per strategy.
      def self.compute_deterministic_id(user, password)
        raw = Digest::SHA256.digest("#{user}:#{password}")
        le = raw[0..15].bytes
        le[0], le[1], le[2], le[3] = le[3], le[2], le[1], le[0]
        le[4], le[5] = le[5], le[4]
        le[6], le[7] = le[7], le[6]
        format("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x", *le)
      end

      # UUID v5 (SHA-1, RFC 4122) of `name` under `namespace` (a uuid string).
      # Use it to derive a STABLE terminal id per strategy, e.g.
      #   Client.uuid5(Client::NAMESPACE_DNS, "fleet-audit-RubyMT4")
      # (byte-identical to Python's uuid.uuid5(uuid.NAMESPACE_DNS, name)).
      NAMESPACE_DNS = "6ba7b810-9dad-11d1-80b4-00c04fd430c8".freeze
      def self.uuid5(namespace, name)
        ns = [namespace.delete("-")].pack("H*")
        h = Digest::SHA1.digest(ns + name).bytes[0, 16]
        h[6] = (h[6] & 0x0f) | 0x50
        h[8] = (h[8] & 0x3f) | 0x80
        hex = h.pack("C*").unpack1("H*")
        "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
      end

      # @param id [String, nil] terminal instance id to reuse. Strongly recommended:
      #   the gateway keeps one terminal per id; a fresh id per run orphans terminals.
      # @param timeout [Numeric] per-RPC deadline in seconds (streams are exempt).
      def initialize(host = DEFAULT_HOST, port = DEFAULT_PORT, api_key: nil, id: nil, timeout: 60, channel_args: {})
        @host = host
        @port = port
        @api_key = api_key || ENV["MRPC_API_KEY"]
        raise ArgumentError, "api_key is required (pass api_key: or set MRPC_API_KEY)" if @api_key.nil? || @api_key.empty?

        @id = id
        @timeout = timeout
        @connected = false
        @channel_args = {
          "grpc.keepalive_time_ms" => 30_000,
          "grpc.keepalive_timeout_ms" => 10_000,
          "grpc.keepalive_permit_without_calls" => 1,
          "grpc.max_receive_message_length" => 64 * 1024 * 1024
        }.merge(channel_args)
        @creds = port == 443 ? GRPC::Core::ChannelCredentials.new : :this_channel_is_insecure
        @stubs = {}
        @channels = [] # the channels behind @stubs, so #close can release them
      end

      def target = "#{@host}:#{@port}"

      def connected? = @connected

      # gRPC metadata attached to every call: APIKey + terminal id.
      def metadata
        md = { "apikey" => @api_key }
        md["id"] = @id if @id
        md
      end

      # ---------------------------------------------------------------- connection

      # ConnectEx: connect by broker server (cluster) name, e.g. "VantageFX-Demo".
      # Creates the terminal on the gateway (or reuses the one bound to `id`).
      # Returns Mt4TermApi::ConnectData (terminal_instance_guid, terminal_type).
      # Raises InvalidLoginError for bad credentials (do NOT retry that one).
      def connect(login, password, server:, name: nil, timeout_seconds: 120, expiration: nil)
        @login = Integer(login)
        @server = server
        @name = name
        @id ||= self.class.compute_deterministic_id(@login, password)
        req = Mt4TermApi::ConnectExRequest.new(user: @login, password: password, mt_cluster_name: server,
                                               timeout_seconds: timeout_seconds)
        req.name = name if name
        req.expiration = expiration if expiration
        data = call(:connection, :connect_ex, req, timeout: timeout_seconds + 30)
        # The gateway may answer with its own alias; keep sending the id we chose:
        # it is the routing key and stays stable across runs.
        @server_guid = data.terminal_instance_guid
        @connected = true
        data
      rescue ApiError => e
        raise InvalidLoginError.new(e.error, "ConnectEx") if invalid_login?(e)
        raise
      end
      alias connect_ex connect
      alias connect_by_server_name connect

      # Connect by raw host:port of the broker trade server (no cluster lookup).
      def connect_by_host(login, password, host:, port:, name: nil, timeout_seconds: 120)
        @login = Integer(login)
        @server = "#{host}:#{port}"
        @name = name
        @id ||= self.class.compute_deterministic_id(@login, password)
        req = Mt4TermApi::ConnectRequest.new(user: @login, password: password, host: host, port: port,
                                             timeout_seconds: timeout_seconds)
        req.name = name if name
        data = call(:connection, :connect, req, timeout: timeout_seconds + 30)
        @server_guid = data.terminal_instance_guid
        @connected = true
        data
      rescue ApiError => e
        raise InvalidLoginError.new(e.error, "Connect") if invalid_login?(e)
        raise
      end
      alias connect_by_host_port connect_by_host

      def check_connect = call(:connection, :check_connect, Mt4TermApi::CheckConnectRequest.new)
      def connect_state = call(:connection, :connect_state, Mt4TermApi::ConnectStateRequest.new)
      def connection_status = call(:connection, :connection_status, Mt4TermApi::ConnectionStatusRequest.new)
      def reconnect(force: false) = call(:connection, :reconnect, Mt4TermApi::ReconnectRequest.new(force_reconnection: force), timeout: 180)
      # NOTE: HealthService.HealthCheck answers UNIMPLEMENTED on the prod gateway; use check_connect / connect_state.

      # Stops the terminal on the gateway. delete: true also removes it from the
      # account list (the next connect with the same id creates a fresh one).
      def disconnect(delete: false, reason: nil)
        req = Mt4TermApi::DisconnectRequest.new
        req.delete = delete
        req.reason = reason if reason
        data = call(:connection, :disconnect, req)
        @connected = false
        @last_disconnect_deleted = delete
        data
      end

      # Close every gRPC channel this client opened (streams on them end with
      # GRPC::Cancelled or an error). Purely local: the terminal on the gateway is NOT stopped
      # (use #disconnect for that). A later call on this client would open fresh channels.
      def close
        chans = @channels
        @channels = []
        @stubs = {}
        @connected = false
        chans.each do |ch|
          ch.close
        rescue StandardError
          nil
        end
        chans.size
      end

      # Terminals owned by the API key (no `id` needed). [Mt4TermApi::AccountsListItem]-like rows.
      def accounts(include_stopped: false, page_size: 200)
        req = Mt4TermApi::AccountsListRequest.new(include_stopped: include_stopped, page_size: page_size)
        out = []
        loop do
          data = call(:accounts, :list, req)
          out.concat(data.accounts.to_a)
          break if data.next_page_token.to_s.empty?
          req.page_token = data.next_page_token
        end
        out
      end

      # ------------------------------------------------------------------- account

      # Mt4TermApi::AccountSummaryData: account_login, account_balance, account_equity,
      # account_currency, account_leverage, account_trade_mode (:ACCOUNT_TRADE_MODE_DEMO /
      # _CONTEST / _REAL), account_company_name, account_user_name, account_credit,
      # is_investor, server_time (broker tz), server_time_utc, server_utc_offset_seconds.
      def account_summary = call(:account_helper, :account_summary, Mt4TermApi::AccountSummaryRequest.new)

      def demo? = account_summary.account_trade_mode == :ACCOUNT_TRADE_MODE_DEMO

      # Mt4TermApi::ServerTimezoneData: server, utc_offset_seconds (broker server time minus UTC),
      # source (:SERVER_TIMEZONE_SOURCE_LIVE / _LAST_VALIDATED / _UNKNOWN), validated_utc. Answered by
      # the platform from what it already knows, so it is cheap; every *_utc field of the API is the
      # broker server time minus this offset.
      def server_timezone = call(:server_timezone, :server_timezone, Mt4TermApi::ServerTimezoneRequest.new)

      # ------------------------------------------------------------------- symbols

      # Add (select=true) / remove a symbol from Market Watch. Returns true/false.
      def symbol_select(symbol, select = true) = call(:market_info, :symbol_select, Mt4TermApi::SymbolSelectRequest.new(symbol: symbol, select: select)).success

      # Names of all symbols known to the terminal (server list), as Strings.
      def symbols = call(:market_info, :symbols, Mt4TermApi::SymbolsRequest.new, timeout: 120).SymbolNameInfos.map(&:symbol_name)
      alias symbol_list symbols

      def symbol_exist(symbol) = symbols.include?(symbol)

      # Mt4TermApi::QuoteData: symbol, bid, ask, high, low, date_time (broker tz), date_time_utc.
      # PRICES COME FROM HERE. A symbol freshly added to Market Watch can answer 0/0 for a moment.
      def quote(symbol) = call(:market_info, :quote, Mt4TermApi::QuoteRequest.new(symbol: symbol))
      alias symbol_info_tick quote

      # [Mt4TermApi::QuoteData] for several symbols in one call.
      def quote_many(symbols) = call(:market_info, :quote_many, Mt4TermApi::QuoteManyRequest.new(symbols: Array(symbols))).quotes.to_a

      # Raw spec of one symbol (Mt4TermApi::SymbolParamsManyInfo). NOTE: most of its
      # fields are Capitalised (p.Digits, p.Point, p.VolumeMin, p.TradeContractSize,
      # p.TradeStopsLevel, p.TradeMode, p.SymbolName ...). Prefer #symbol_spec.
      # nil when the symbol is unknown.
      def symbol_params(symbol)
        data = call(:account_helper, :symbol_params_many, Mt4TermApi::SymbolParamsManyRequest.new(symbol_name: symbol))
        data.symbol_infos.find { |s| s.SymbolName == symbol } || data.symbol_infos.first
      rescue ApiError => e
        # prod answers EXECUTION_ERROR_IN_INTERNAL_GRPC_SERVICE "Symbol pair name does not exist" for unknown names
        raise unless e.error.error_message =~ /does not exist/i
        nil
      end

      # All symbols' raw specs in ONE call.
      def symbol_params_many = call(:account_helper, :symbol_params_many, Mt4TermApi::SymbolParamsManyRequest.new, timeout: 120).symbol_infos.to_a

      # snake_case SymbolSpec of one symbol (nil when unknown). Use this for sizing/stops.
      def symbol_spec(symbol)
        p = symbol_params(symbol)
        p && self.class.spec_of(p)
      end

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

      # Tick value / tick size / contract size for named symbols (adds them to Market Watch).
      def tick_value_with_size(symbols) = call(:account_helper, :tick_value_with_size, Mt4TermApi::TickValueWithSizeRequest.new(symbol_names: Array(symbols))).infos.to_a

      # -------------------------------------------------------------------- bars

      # OHLC bars via QuoteHistory.Bars, oldest first, paged automatically.
      # Returns [Mt4TermApi::QuoteHistoryBar]: time (unix s, broker tz), time_utc (unix s),
      # open, high, low, close, tick_volume, spread, real_volume (0 on MT4).
      # timeframe: :M1 :M5 :M15 :M30 :H1 :H4 :D1 :W1 :MN1 (or a QHB_PERIOD_* symbol).
      # The terminal fetches history from the broker on demand; QUOTE_HISTORY_NOT_READY
      # is retried `not_ready_retries` times with a 1 s pause.
      def bars(symbol, timeframe: :M1, from_utc:, to_utc: nil, page_size: 1000, not_ready_retries: 10)
        tf = TIMEFRAMES.fetch(timeframe.to_sym, timeframe)
        req = Mt4TermApi::QuoteHistoryBarsRequest.new(symbol: symbol, timeframe: tf, from_time_utc: from_utc.to_i,
                                                      to_time_utc: (to_utc || 0).to_i, page_size: page_size)
        out = []
        loop do
          data = begin
            call(:quote_history, :bars, req, timeout: 120)
          rescue ApiError => e
            raise unless e.code == "QUOTE_HISTORY_NOT_READY" && (not_ready_retries -= 1) >= 0
            sleep 1
            retry
          end
          out.concat(data.bars.to_a)
          break if data.next_page_token.to_s.empty?
          req.page_token = data.next_page_token
        end
        out
      end
      alias price_history bars

      # The newest `count` bars (oldest first). Widens the lookback window until
      # enough bars exist (weekends / holidays), up to ~64x the nominal span.
      def last_bars(symbol, timeframe: :M1, count: 50)
        minutes = TIMEFRAME_MINUTES.fetch(timeframe.to_sym)
        span = count * minutes * 60 * 2
        now = Time.now.to_i
        result = []
        7.times do
          result = bars(symbol, timeframe: timeframe, from_utc: now - span, to_utc: 0)
          break if result.size >= count
          span *= 2
        end
        result.last(count)
      end

      # Legacy MarketInfo.QuoteHistory (deprecated on the gateway; unpaged).
      # Returns [Mt4TermApi::HistoryQuote] with Timestamp `time`/`time_utc`.
      def quote_history(symbol, timeframe: :M1, from_utc:, to_utc: Time.now.utc)
        tf = LEGACY_TIMEFRAMES.fetch(timeframe.to_sym, timeframe)
        req = Mt4TermApi::QuoteHistoryRequest.new(symbol: symbol, timeframe: tf, fromTimeUtc: ts(from_utc), toTimeUtc: ts(to_utc))
        call(:market_info, :quote_history, req, timeout: 120).historical_quotes.to_a
      end

      # ------------------------------------------------------------------ streams

      # Handle for a running server-stream. #cancel stops it; #join waits.
      class Subscription
        attr_reader :count
        attr_accessor :error, :thread

        def initialize(op)
          @op = op
          @count = 0
        end

        # Cancel the stream and wait for the reader thread to finish.
        def cancel
          @op.cancel
          @thread&.join(5)
        end

        def join(limit = nil) = @thread.join(limit)
        def alive? = @thread&.alive? || false
        def bump! = @count += 1
      end

      # Subscribe to ticks. Yields Mt4TermApi::OnSymbolMqlTickInfo (symbol, bid, ask,
      # last, volume, time (Timestamp, broker tz), time_utc, time_msc, time_msc_utc) on a
      # background thread. Returns a Subscription; call .cancel to unsubscribe cleanly.
      def on_symbol_tick(symbols, &block)
        req = Mt4TermApi::OnSymbolTickRequest.new(symbol_names: Array(symbols))
        stream(:subscriptions, :on_symbol_tick, req) { |reply| block.call(reply.data.symbol_tick) }
      end
      alias subscribe_ticks on_symbol_tick
      alias subscribe_quotes on_symbol_tick

      # Trade events (orders opened/modified/closed). Yields Mt4TermApi::OnTradeData
      # (event_data.new_orders / updated_orders / removed_orders / new_history_orders, account_info).
      def on_trade(&block) = stream(:subscriptions, :on_trade, Mt4TermApi::OnTradeRequest.new) { |r| block.call(r.data) }

      # Open orders' P/L every `interval_ms`. Yields OnOpenedOrdersProfitData.
      def on_opened_orders_profit(interval_ms: 1000, &block)
        req = Mt4TermApi::OnOpenedOrdersProfitRequest.new(timer_period_milliseconds: interval_ms)
        stream(:subscriptions, :on_opened_orders_profit, req) { |r| block.call(r.data) }
      end
      alias on_position_profit on_opened_orders_profit

      # Open order tickets every `interval_ms`. Yields OnOpenedOrdersTicketsData.
      def on_opened_orders_tickets(interval_ms: 1000, &block)
        req = Mt4TermApi::OnOpenedOrdersTicketsRequest.new(pull_interval_milliseconds: interval_ms)
        stream(:subscriptions, :on_opened_orders_tickets, req) { |r| block.call(r.data) }
      end

      # Blocking variant: iterate ticks for `seconds`, then return the count.
      def each_tick(symbols, seconds:, &block)
        n = 0
        sub = on_symbol_tick(symbols) { |t| n += 1; block&.call(t) }
        sleep seconds
        sub.cancel
        raise sub.error if sub.error && !sub.error.is_a?(GRPC::Cancelled)
        n
      end

      # ------------------------------------------------------------------- trading

      # Market or pending order. type: :buy/:sell/:buy_limit/:sell_limit/:buy_stop/:sell_stop
      # (or an OC_OP_* symbol). price is ignored for market orders (the gateway uses the
      # current quote); slippage is in points. magic -> magic_number.
      # Returns Mt4TermApi::OrderSendData (ticket, volume, price, open_time, open_time_utc).
      # A rejected order raises ApiError (e.mql_code: 130 invalid stops, 132 market closed,
      # 134 not enough money, 138 requote, ...). There is no retcode: ticket > 0 means filled.
      def order_send(symbol:, type:, volume:, price: nil, stop_loss: nil, take_profit: nil, comment: nil,
                     magic: nil, slippage: nil, expiration_utc: nil)
        req = Mt4TermApi::OrderSendRequest.new(symbol: symbol, operation_type: ORDER_TYPES.fetch(type.to_sym, type), volume: volume)
        req.price = price if price
        req.stoploss = stop_loss if stop_loss
        req.takeprofit = take_profit if take_profit
        req.comment = comment if comment
        req.magic_number = magic if magic
        req.slippage = slippage if slippage
        req.expiration_utc = ts(expiration_utc) if expiration_utc
        call(:trading_helper, :order_send, req, timeout: 120)
      end

      def buy(symbol, volume, **kw) = order_send(symbol: symbol, type: :buy, volume: volume, **kw)
      def sell(symbol, volume, **kw) = order_send(symbol: symbol, type: :sell, volume: volume, **kw)

      # Modify SL/TP of an open order, or price/SL/TP/expiration of a pending order.
      # Returns Mt4TermApi::OrderModifyData (order_was_modified). Rejections raise ApiError.
      def order_modify(ticket:, stop_loss: nil, take_profit: nil, price: nil, expiration_utc: nil)
        req = Mt4TermApi::OrderModifyRequest.new(order_ticket: ticket)
        req.new_stop_loss = stop_loss if stop_loss
        req.new_take_profit = take_profit if take_profit
        req.new_price = price if price
        req.new_expiration_utc = ts(expiration_utc) if expiration_utc
        call(:trading_helper, :order_modify, req, timeout: 120)
      end

      # Close a market order (lots nil = full close, else partial) or delete a pending order.
      # Returns Mt4TermApi::OrderCloseDeleteData (mode :OCD_MARKET_ORDER / :OCD_PENDING_ORDER,
      # history_order_comment). Rejections raise ApiError.
      def order_close(ticket:, lots: nil, price: nil, slippage: 10)
        req = Mt4TermApi::OrderCloseDeleteRequest.new(order_ticket: ticket)
        req.lots = lots if lots
        req.closing_price = price if price
        req.slippage = slippage if slippage
        call(:trading_helper, :order_close_delete, req, timeout: 120)
      end
      alias order_close_delete order_close
      alias order_delete order_close

      # Close one market order by an opposite one on the same symbol.
      def order_close_by(ticket:, opposite_ticket:)
        call(:trading_helper, :order_close_by, Mt4TermApi::OrderCloseByRequest.new(ticket_to_close: ticket, opposite_ticket_closing_by: opposite_ticket), timeout: 120)
      end

      # All open orders (market + pending). [Mt4TermApi::OpenedOrderInfo]: ticket, symbol,
      # order_type (:OO_OP_BUY/:OO_OP_SELL/:OO_OP_BUYLIMIT...), lots, open_price, stop_loss,
      # take_profit, profit, swap, commision (sic), magic_number, comment, open_time_utc, expiration_time_utc.
      def opened_orders(sort: :SORT_BY_OPEN_TIME_ASC) = call(:account_helper, :opened_orders, Mt4TermApi::OpenedOrdersRequest.new(sort_type: sort)).order_infos.to_a

      def opened_orders_tickets = call(:account_helper, :opened_orders_tickets, Mt4TermApi::OpenedOrdersTicketsRequest.new).tickets.to_a

      # Open MARKET orders (= positions on MT4), filtered client-side by magic and/or symbol.
      def positions(magic: nil, symbol: nil)
        opened_orders.select do |o|
          MARKET_ORDER_TYPES.include?(o.order_type) && (magic.nil? || o.magic_number == magic) && (symbol.nil? || o.symbol == symbol)
        end
      end

      # Pending orders, filtered client-side by magic and/or symbol.
      def pending_orders(magic: nil, symbol: nil)
        opened_orders.reject { |o| MARKET_ORDER_TYPES.include?(o.order_type) }
                     .select { |o| (magic.nil? || o.magic_number == magic) && (symbol.nil? || o.symbol == symbol) }
      end

      # Closed / deleted orders whose OPEN time is in [from_utc, to_utc], auto-paged.
      # [Mt4TermApi::HistoryOrderInfo]: ticket symbol order_type lots open_price close_price
      # profit swap commision magic_number comment open_time_utc close_time_utc.
      def orders_history(from_utc:, to_utc: Time.now.utc, sort: :HISTORY_SORT_BY_CLOSE_TIME_ASC, page_size: 1000)
        req = Mt4TermApi::OrdersHistoryRequest.new(input_sort_mode: sort, input_from_utc: ts(from_utc), input_to_utc: ts(to_utc), page_size: page_size)
        out = []
        loop do
          data = call(:account_helper, :orders_history, req, timeout: 120)
          out.concat(data.orders_info.to_a)
          break if data.next_page_token.to_s.empty?
          req.page_token = data.next_page_token
        end
        out
      end
      alias order_history orders_history

      # ----------------------------------------------------------------- internals

      def ts(t)
        return t if t.is_a?(Google::Protobuf::Timestamp)
        Google::Protobuf::Timestamp.new(seconds: t.to_i, nanos: 0)
      end

      def invalid_login?(e)
        "#{e.code} #{e.error.error_message}" =~ /INVALID_LOGIN|WrongPassword|WRONG_PASSWORD|INVALID_ACCOUNT|invalid account|wrong password/i
      end

      def stub(name)
        @stubs[name] ||= begin
          klass = {
            connection: Mt4TermApi::Connection::Stub,
            accounts: Mt4TermApi::Accounts::Stub,
            account_helper: Mt4TermApi::AccountHelper::Stub,
            market_info: Mt4TermApi::MarketInfo::Stub,
            quote_history: Mt4TermApi::QuoteHistory::Stub,
            subscriptions: Mt4TermApi::SubscriptionService::Stub,
            trading_helper: Mt4TermApi::TradingHelper::Stub,
            trade_stats: Mt4TermApi::TradeStats::Stub,
            server_timezone: Mt4TermApi::ServerTimezone::Stub
          }.fetch(name)
          # Create the channel explicitly (exactly as ClientStub would) and keep it, so #close
          # can release it instead of leaving it to the GC.
          ch = GRPC::ClientStub.setup_channel(nil, target, @creds, @channel_args.dup)
          @channels << ch
          klass.new(target, @creds, channel_override: ch, channel_args: @channel_args)
        end
      end

      # Unary call: sends metadata, unwraps the data/error oneof.
      def call(service, rpc, request, timeout: @timeout)
        reply = stub(service).public_send(rpc, request, metadata: metadata, deadline: Time.now + timeout)
        unwrap(reply, rpc)
      end

      def unwrap(reply, rpc)
        return reply unless reply.respond_to?(:response)
        case reply.response
        when :error then raise ApiError.new(reply.error, rpc)
        when :data then reply.data
        else reply
        end
      end

      # Server-streaming call on a background thread; yields each reply.
      def stream(service, rpc, request)
        op = stub(service).public_send(rpc, request, metadata: metadata, return_op: true)
        sub = Subscription.new(op)
        sub.thread = Thread.new do
          begin
            op.execute.each do |reply|
              raise ApiError.new(reply.error, rpc) if reply.respond_to?(:response) && reply.response == :error
              sub.bump!
              yield reply
            end
          rescue GRPC::Cancelled
            # expected on cancel
          rescue StandardError => e
            sub.error = e
          end
        end
        sub.thread.report_on_exception = false
        sub
      end
    end

    Account = Client
  end
end
