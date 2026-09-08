module MetaRPC
  module MT4
    class Client
      attr_reader :host, :port

      def initialize(host, port = 443)
        @host = host
        @port = port
        @connected = false
      end

      def connect(login, password)
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
