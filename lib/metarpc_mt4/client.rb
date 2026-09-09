require "digest"

module MetaRPC
  module MT4
    class Client
      attr_reader :host, :port, :api_key, :id

      def self.compute_deterministic_id(user, password)
        raw = Digest::SHA256.digest("#{user}:#{password}")
        le = raw[0..15].bytes
        le[0], le[1], le[2], le[3] = le[3], le[2], le[1], le[0]
        le[4], le[5] = le[5], le[4]
        le[6], le[7] = le[7], le[6]
        format(
          "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
          *le
        )
      end

      def initialize(host = "mt4.mrpc.pro", port = 443, api_key: nil, id: nil)
        @host = host
        @port = port
        @api_key = api_key || ENV["MRPC_API_KEY"]
        @id = id
        @connected = false
      end

      def get_id(login = nil, password = nil)
        if login && password
          @id = self.class.compute_deterministic_id(login, password)
        end
        @id
      end

      def connect(login, password)
        @id ||= self.class.compute_deterministic_id(login, password)
        @connected = true
        true
      end

      def connected?
        @connected
      end

      def disconnect
        @connected = false
      end

      def account_info
        {
          login: 100234,
          currency: "USD",
          balance: 10000.0,
          equity: 10000.0,
          margin: 0.0,
          free_margin: 10000.0,
          leverage: 100,
          name: "Demo Account",
          server: @host
        }
      end

      def subscribe_quotes(symbols, &block)
        # Yields Quote objects
      end

      def order_send(symbol:, cmd:, lots:, price: nil, stop_loss: nil, take_profit: nil, comment: nil)
        {
          ticket: rand(100000..999999),
          error_code: 0,
          price: price || 1.0850,
          lots: lots,
          comment: comment || "Executed"
        }
      end

      def order_modify(ticket:, stop_loss: nil, take_profit: nil)
        true
      end

      def order_close(ticket:, lots:)
        true
      end
    end
  end
end
