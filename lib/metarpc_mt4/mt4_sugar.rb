# ══════════════════════════════════════════════════════════════════════════════
# MT4Sugar — High-Level MetaTrader 4 One-Liners
# ══════════════════════════════════════════════════════════════════════════════
#
# The top layer of the three-layer stack:
#     MT4Account  →  MT4Service  →  MT4Sugar (this file)
#
# One-liners with smart defaults: connect, read money and prices, trade, and size
# orders. Wraps an MT4Service (which wraps an MT4Account); reach the layers below
# with #service and #account. MT4 has ORDERS, not positions: an open market order
# IS the position, and its ticket is what you modify / close.
#
#     mt4 = MetaRPC::MT4::MT4Sugar.create(api_key: ENV["MRPC_API_KEY"])
#     mt4.connect(893310151, "pwd", server: "VantageFX-Demo")
#     mt4.bid("EURUSD"); t = mt4.buy_market("EURUSD", 0.01); mt4.close_order(t.ticket)
#
# METHOD GROUPS:
# ──────────────────────────────────────────────────────────────────────────────
#
# 1. CONSTRUCTION (3 methods)
#    • create / account / service - Build the stack, reach the layers below
#
# 2. CONNECTION (11 methods)
#    • connect / connect_by_host / quick_connect / connect_proxy - Connect
#    • get_id                                     - Resolve the session id
#    • connected? / reconnect / disconnect        - Lifecycle
#    • check_connect / connect_state / connection_status - Health checks
#
# 3. MONEY & ACCOUNT — reads (11 methods)
#    • balance / equity / margin / free_margin / margin_level / profit / credit
#    • account_info / demo?
#    • accounts          - Terminals owned by the API key
#    • server_timezone   - Broker server UTC offset
#
# 4. PRICES — reads (5 methods)
#    • bid / ask / spread / price / quotes
#
# 5. SIMPLE TRADING (6 methods)
#    • buy_market / sell_market (aliases buy / sell)
#    • buy_limit / sell_limit / buy_stop / sell_stop
#
# 6. TRADING WITH SL/TP (2 methods)
#    • buy_market_with_sl_tp / sell_market_with_sl_tp
#
# 7. RAW TRADING (3 methods)
#    • order_send / order_modify / order_close
#
# 8. ORDER MANAGEMENT (9 methods)
#    • close_order / close_all / close_all_by_symbol / close_by
#    • cancel_order / cancel_all_pending
#    • modify_sl / modify_tp / modify_sl_tp
#
# 9. ORDER INFORMATION (9 methods)
#    • open_orders / pending / order / orders_by_symbol
#    • has_order? / count_orders / total_profit / profit_by_symbol / open_tickets
#
# 10. HISTORY & STATS (5 methods)
#    • order_history / trade_stats / trade_stats_equity_history
#    • equity_history / trade_unrealized_pl
#
# 11. SYMBOL INFORMATION (11 methods)
#    • symbol_info / all_symbols / symbol_available? / select_symbol
#    • symbol_digits / symbol_point / min_stop_level
#    • bars / last_bars / tick_value_with_size / all_symbol_specs
#
# 12. RISK MANAGEMENT (3 methods)
#    • required_margin - Estimated margin for an order (leverage-based)
#    • max_lot         - Largest lot that fits free margin
#    • pip_value       - Value of one pip per lot
#
# 13. STREAMS (6 methods)
#    • subscribe_ticks / on_trade / on_opened_orders_profit
#    • on_tickets / on_connect_state / each_tick
#
# ══════════════════════════════════════════════════════════════════════════════

require_relative "mt4_service"

module MetaRPC
  module MT4
    # HIGH-LEVEL layer — one-liners with smart defaults over {MT4Service} / {MT4Account}.
    #
    # The fastest way to connect, read money and prices, trade, and size orders. It
    # wraps an MT4Service (which wraps an MT4Account) and exposes short helpers —
    # `balance`, `bid`, `buy_market`, `close_order`, ... — while still delegating the
    # full typed/raw API, so this one object does the whole job.
    #
    #   mt4 = MetaRPC::MT4::MT4Sugar.create(api_key: ENV["MRPC_API_KEY"])
    #   mt4.connect(893310151, "pwd", server: "VantageFX-Demo")
    #   mt4.balance                       # => 10000.0
    #   mt4.bid("EURUSD")                 # => 1.0831
    #   t = mt4.buy_market("EURUSD", 0.01)
    #   mt4.close_order(t.ticket)
    #
    # Reach the layers below with {#service} and {#account}.
    class MT4Sugar
      attr_reader :service

      # ════════════════════════════════════════════════════════════════════════════
      #region CONSTRUCTION
      # ════════════════════════════════════════════════════════════════════════════

      # Wrap an existing MT4Service, or build the whole stack from the same arguments.
      def initialize(service = nil, **opts)
        @service = service.is_a?(MT4Service) ? service : MT4Service.new(**opts)
      end

      # Build the whole stack: MT4Sugar -> MT4Service -> MT4Account.
      #
      #   MT4Sugar.create(api_key: ENV["MRPC_API_KEY"], id: stable_uuid)
      def self.create(host = MT4Account::DEFAULT_HOST, port = MT4Account::DEFAULT_PORT, **opts)
        new(MT4Service.new(MT4Account.new(host, port, **opts)))
      end

      # The MT4Account underneath (raw gRPC).
      def account = @service.account

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region CONNECTION
      # ════════════════════════════════════════════════════════════════════════════

      # Connect by broker server name (keyword `server:` kept for drop-in use).
      def connect(login, password, server:, **opts) = @service.connect(login, password, server: server, **opts)
      def connect_by_host(login, password, host:, port:, **opts) = @service.connect_by_host(login, password, host: host, port: port, **opts)
      # Positional-server shorthand.
      def quick_connect(login, password, server) = @service.connect(login, password, server: server)
      def connected? = @service.connected?
      def reconnect(force: false) = @service.reconnect(force: force)
      def disconnect(delete: false, reason: nil) = @service.disconnect(delete: delete, reason: reason)
      # Connect through a proxy (SOCKS/HTTP).
      def connect_proxy(login, password, **opts) = @service.connect_proxy(login, password, **opts)
      # Resolve the terminal session id for a login/password (no connect needed).
      def get_id(login = nil, password = nil) = @service.get_id(login, password)
      # Health checks.
      def check_connect = @service.check_connect
      def connect_state = @service.connect_state
      def connection_status = @service.connection_status

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region MONEY (READS)
      # ════════════════════════════════════════════════════════════════════════════

      # MT4 has no AccountInfoDouble RPC — money comes from one AccountSummary read.
      def balance      = account_summary.account_balance
      def equity       = account_summary.account_equity
      def margin       = account_summary.account_margin
      def free_margin  = account_summary.account_margin_free
      def margin_level = account_summary.account_margin_level
      def credit       = account_summary.account_credit
      # Floating P/L (MT4: Equity = Balance + Credit + Floating).
      def profit       = (s = account_summary; s.account_equity - s.account_balance - s.account_credit)
      def account_info = @service.account_info
      def account_summary = @service.account_summary
      def demo? = @service.demo?
      # Terminals owned by the API key (list).
      def accounts(**opts) = @service.accounts(**opts)
      # Broker server UTC offset (ServerTimezoneData).
      def server_timezone = @service.server_timezone

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region PRICES (READS)
      # ════════════════════════════════════════════════════════════════════════════

      def bid(symbol)    = @service.quote(symbol).bid
      def ask(symbol)    = @service.quote(symbol).ask
      def spread(symbol) = (q = @service.quote(symbol); q.ask - q.bid)
      def price(symbol)  = @service.quote(symbol)   # Quote struct (bid/ask/high/low/spread/time_utc)
      def quotes(symbols) = @service.quote_many(symbols)   # [Quote] for several symbols at once

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region SIMPLE TRADING
      # ════════════════════════════════════════════════════════════════════════════

      def buy_market(symbol, volume, **kw)  = @service.order_send(symbol: symbol, type: :buy,  volume: volume, **kw)
      def sell_market(symbol, volume, **kw) = @service.order_send(symbol: symbol, type: :sell, volume: volume, **kw)
      alias buy buy_market
      alias sell sell_market

      def buy_limit(symbol, volume, price, **kw)  = @service.order_send(symbol: symbol, type: :buy_limit,  volume: volume, price: price, **kw)
      def sell_limit(symbol, volume, price, **kw) = @service.order_send(symbol: symbol, type: :sell_limit, volume: volume, price: price, **kw)
      def buy_stop(symbol, volume, price, **kw)   = @service.order_send(symbol: symbol, type: :buy_stop,   volume: volume, price: price, **kw)
      def sell_stop(symbol, volume, price, **kw)  = @service.order_send(symbol: symbol, type: :sell_stop,  volume: volume, price: price, **kw)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region TRADING WITH SL/TP
      # ════════════════════════════════════════════════════════════════════════════

      def buy_market_with_sl_tp(symbol, volume, sl:, tp:, **kw)  = @service.order_send(symbol: symbol, type: :buy,  volume: volume, stop_loss: sl, take_profit: tp, **kw)
      def sell_market_with_sl_tp(symbol, volume, sl:, tp:, **kw) = @service.order_send(symbol: symbol, type: :sell, volume: volume, stop_loss: sl, take_profit: tp, **kw)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region RAW TRADING PASSTHROUGH
      # ════════════════════════════════════════════════════════════════════════════

      # Drop-in with the old flat client / full control when a helper is too narrow.
      def order_send(symbol:, type:, volume:, **opts) = @service.order_send(symbol: symbol, type: type, volume: volume, **opts)
      def order_modify(ticket:, **opts) = @service.order_modify(ticket: ticket, **opts)
      def order_close(ticket:, **opts)  = @service.order_close(ticket: ticket, **opts)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region ORDER MANAGEMENT
      # ════════════════════════════════════════════════════════════════════════════

      # Close a market order (lots nil = full close, else partial) by ticket.
      def close_order(ticket, lots: nil, slippage: 10) = @service.order_close(ticket: ticket, lots: lots, slippage: slippage)
      # Close every open MARKET order.
      def close_all(slippage: 10) = open_orders.map { |o| close_order(o.ticket, slippage: slippage) }
      # Close all market orders on a symbol.
      def close_all_by_symbol(symbol, slippage: 10) = orders_by_symbol(symbol).map { |o| close_order(o.ticket, slippage: slippage) }
      # Delete a pending order by ticket.
      def cancel_order(ticket) = @service.order_close(ticket: ticket)
      # Delete every pending order.
      def cancel_all_pending = pending.map { |o| cancel_order(o.ticket) }
      # Close one market order by an opposite one on the same symbol.
      def close_by(ticket, opposite_ticket) = @service.order_close_by(ticket: ticket, opposite_ticket: opposite_ticket)
      def modify_sl(ticket, stop_loss)   = @service.order_modify(ticket: ticket, stop_loss: stop_loss)
      def modify_tp(ticket, take_profit) = @service.order_modify(ticket: ticket, take_profit: take_profit)
      def modify_sl_tp(ticket, stop_loss:, take_profit:) = @service.order_modify(ticket: ticket, stop_loss: stop_loss, take_profit: take_profit)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region ORDER INFORMATION
      # ════════════════════════════════════════════════════════════════════════════

      # Open MARKET orders (= positions on MT4), filter by magic and/or symbol.
      def open_orders(magic: nil, symbol: nil) = @service.positions(magic: magic, symbol: symbol)
      # Pending orders, filter by magic and/or symbol.
      def pending(magic: nil, symbol: nil) = @service.pending_orders(magic: magic, symbol: symbol)
      # One open order by ticket (market or pending).
      def order(ticket) = @service.opened_orders.find { |o| o.ticket == ticket }
      def orders_by_symbol(symbol) = @service.positions(symbol: symbol)
      def has_order?(symbol) = orders_by_symbol(symbol).any?
      def count_orders = open_orders.size
      def total_profit = open_orders.sum(&:profit)
      def profit_by_symbol(symbol) = orders_by_symbol(symbol).sum(&:profit)
      # Tickets only (open + pending orders), cheaply.
      def open_tickets = @service.opened_tickets

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region HISTORY & STATS
      # ════════════════════════════════════════════════════════════════════════════

      def order_history(from_utc:, **opts) = @service.order_history(from_utc: from_utc, **opts)
      def trade_stats(from_utc: nil, from: nil) = @service.trade_stats(from_utc: from_utc, from: from)
      def trade_stats_equity_history(from_utc: nil, from: nil, exclude_same_bars: false) = @service.trade_stats_equity_history(from_utc: from_utc, from: from, exclude_same_bars: exclude_same_bars)
      def equity_history(from_utc: nil, from: nil, exclude_same_bars: false) = @service.equity_history(from_utc: from_utc, from: from, exclude_same_bars: exclude_same_bars)
      def trade_unrealized_pl(from_utc: nil, from: nil) = @service.trade_unrealized_pl(from_utc: from_utc, from: from)

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region SYMBOL INFORMATION
      # ════════════════════════════════════════════════════════════════════════════

      def symbol_info(symbol) = @service.symbol_params(symbol)
      def all_symbols = @service.symbols
      def symbol_available?(symbol) = @service.symbol_exist?(symbol)
      # Show (select=true) / hide a symbol in Market Watch.
      def select_symbol(symbol, select = true) = @service.select_symbol(symbol, select)
      def symbol_digits(symbol) = symbol_info(symbol)&.digits
      def symbol_point(symbol)  = symbol_info(symbol)&.point
      def min_stop_level(symbol) = symbol_info(symbol)&.stops_level
      def bars(symbol, **opts) = @service.bars(symbol, **opts)
      def last_bars(symbol, timeframe: :M1, count: 50) = @service.last_bars(symbol, timeframe: timeframe, count: count)
      # Tick value / size / contract size for sizing (several symbols).
      def tick_value_with_size(symbols) = @service.tick_value_with_size(symbols)
      # Full spec of every symbol in one call ([SymbolSpec]).
      def all_symbol_specs = @service.symbol_params_all

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region RISK MANAGEMENT
      # ════════════════════════════════════════════════════════════════════════════

      # ESTIMATED margin to open `volume` lots of `symbol` at `price` (leverage-based:
      # volume * contract_size * price / leverage). MT4 has no server-side calc RPC and
      # brokers apply their own margin rules (fixed, hedged, per-instrument), so treat
      # this as an approximation for forex-style symbols, not an exact figure.
      def required_margin(symbol, volume, price)
        spec = symbol_info(symbol) or return nil
        lev = account_summary.account_leverage.to_f
        return nil if lev <= 0 || spec.contract_size.to_f <= 0
        volume * spec.contract_size * price / lev
      end

      # Largest volume that fits in free margin for `symbol` at `price`, rounded down to
      # the symbol's volume step. Returns 0.0 when one lot already exceeds free margin.
      def max_lot(symbol, price)
        per_lot = required_margin(symbol, 1.0, price)
        return 0.0 if per_lot.nil? || per_lot <= 0
        step = (symbol_info(symbol)&.volume_step || 0.01)
        raw = free_margin / per_lot
        (raw / step).floor * step
      end

      # Value of one pip per 1.0 lot for `symbol` (tick_value scaled from tick to pip).
      def pip_value(symbol)
        spec = symbol_info(symbol) or return nil
        return spec.tick_value if spec.tick_size.to_f <= 0 || spec.point.to_f <= 0
        pip = spec.digits.to_i == 3 || spec.digits.to_i == 5 ? spec.point * 10 : spec.point
        spec.tick_value * (pip / spec.tick_size)
      end

      #endregion

      # ════════════════════════════════════════════════════════════════════════════
      #region STREAMS
      # ════════════════════════════════════════════════════════════════════════════

      def subscribe_ticks(symbols, &block) = @service.subscribe_ticks(symbols, &block)
      def on_trade(&block) = @service.on_trade(&block)
      def on_opened_orders_profit(interval_ms: 1000, &block) = @service.on_opened_orders_profit(interval_ms: interval_ms, &block)
      def on_tickets(interval_ms: 1000, &block) = @service.on_tickets(interval_ms: interval_ms, &block)
      def on_connect_state(terminal_ids = nil, &block) = @service.on_connect_state(terminal_ids, &block)
      def each_tick(symbols, seconds:, &block) = @service.each_tick(symbols, seconds: seconds, &block)

      #endregion
    end

    # Backward-compatible aliases.
    #   Client  -> the friendly high-level layer (drop-in for the old flat client)
    #   Account -> the raw low-level layer
    Client = MT4Sugar
    Account = MT4Account
  end
end
