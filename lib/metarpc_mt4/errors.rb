require "grpc"

module MetaRPC
  module MT4
    # Raised when the gateway answers with the `error` branch of a reply oneof
    # (MQL4 trade error, validation error, terminal timeout, ...).
    class ApiError < StandardError
      # Trade RPCs: an in-band timeout of one of these leaves the trade's outcome unknown.
      TRADE_RPCS = %i[order_send order_modify order_close_delete order_close_by].freeze
      IN_BAND_TIMEOUT_CODES = %w[MRPC_TIMEOUT TERMINAL_API_TIMEOUT COMMAND_TIMEOUT_EXCEEDED TERMINAL_API_CALL_TIMEOUT].freeze

      attr_reader :error, :rpc_name

      def initialize(error, rpc_name = nil)
        @error = error
        @rpc_name = rpc_name
        super("#{rpc_name}: #{error.error_code} #{error.error_message} " \
              "(type=#{error.type} mql=#{error.mql_error_code}/#{error.mql_error_int_code} " \
              "#{error.mql_error_description})".strip)
      end

      # Gateway error code string, e.g. "CONNECT_EX_INVALID_LOGIN_ERROR", "QUOTE_HISTORY_NOT_READY".
      def code = error.error_code

      # MQL4 numeric trade/runtime error (130 invalid stops, 132 market closed, 134 no money, ...).
      def mql_code = error.mql_error_int_code

      # The API key was refused (API_KEY_INVALID / API_KEY_REQUIRED): retrying or reconnecting does not help.
      def api_key_error? = "#{code} #{error.error_message}".match?(/API_KEY_(INVALID|REQUIRED)/i)

      # The outcome of a trade call is unknown: it timed out on the gateway or in the terminal
      # (COMMAND_TIMEOUT_EXCEEDED, TERMINAL_API_CALL_TIMEOUT, MRPC_TIMEOUT, ...) or MT4 answered 128
      # (ERR_TRADE_TIMEOUT). The trade may or may not have been executed: check the open orders before sending it again.
      def trade_outcome_unknown?
        return true if code == TradeOutcomeUnknown::CODE
        return false unless TRADE_RPCS.include?(rpc_name&.to_sym)
        IN_BAND_TIMEOUT_CODES.include?(code) || %i[MRPC_TIMEOUT TERMINAL_API_TIMEOUT].include?(error.type) || mql_code == 128
      end
    end

    # Raised by connect when the broker rejects the login. Never retry this.
    class InvalidLoginError < ApiError; end

    # A trade call (order_send, order_modify, order_close / order_delete, order_close_by) failed at the transport
    # level - gRPC UNAVAILABLE, DEADLINE_EXCEEDED, UNKNOWN or INTERNAL - after the request may already have reached
    # the terminal: the trade may or may not have been executed. The SDK never re-sends a trade: check the open
    # orders (and the history) before sending it again.
    # It is mixed into the GRPC::BadStatus the call raised, so the error keeps its class (GRPC::Unavailable, ...),
    # its gRPC code, details and metadata: existing `rescue GRPC::BadStatus` / `rescue GRPC::Unavailable` handlers
    # still catch it, and `rescue MetaRPC::MT4::TradeOutcomeUnknown` catches exactly this condition.
    module TradeOutcomeUnknown
      CODE = "TRADE_OUTCOME_UNKNOWN".freeze
      GRPC_CODES = [GRPC::Core::StatusCodes::UNAVAILABLE, GRPC::Core::StatusCodes::DEADLINE_EXCEEDED,
                    GRPC::Core::StatusCodes::UNKNOWN, GRPC::Core::StatusCodes::INTERNAL].freeze

      # The trade call (e.g. "OrderSend") and the transport error's own message.
      attr_reader :operation, :transport_message

      def error_code = CODE
      def trade_outcome_unknown? = true

      def to_s
        name = GRPC::Core::StatusCodes.constants.find { |c| GRPC::Core::StatusCodes.const_get(c) == code } || code
        "#{CODE}: #{operation} failed with gRPC #{name} after the request may have reached the terminal; " \
          "the trade may or may not have been executed. It was NOT re-sent automatically: check open positions/orders " \
          "before retrying. (#{transport_message})"
      end

      # Marks a trade call's transport failure; returns it (the same object).
      def self.mark(err, operation)
        message = err.to_s
        err.extend(self)
        err.instance_variable_set(:@operation, operation)
        err.instance_variable_set(:@transport_message, message)
        err
      end

      # True for a transport failure after which a trade's outcome is unknown (not a refused API key).
      def self.applies?(err)
        GRPC_CODES.include?(err.code) && !err.details.to_s.match?(/API_KEY_(INVALID|REQUIRED)/i)
      end
    end
  end
end
