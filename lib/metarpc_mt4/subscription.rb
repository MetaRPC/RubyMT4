module MetaRPC
  module MT4
    # Handle for a running server-stream. #cancel stops it; #join waits.
    #
    # Returned by every streaming method on MT4Account (on_symbol_tick, on_trade,
    # on_opened_orders_profit, on_opened_orders_tickets, on_connect_state). The
    # reader runs on a background thread; call #cancel to unsubscribe cleanly, or
    # #join to block until the stream ends on its own. You CANNOT call #cancel from
    # inside the yielded block (it would deadlock on the reader thread).
    class Subscription
      attr_reader :count
      attr_accessor :error, :thread

      def initialize(op)
        @op = op
        @count = 0
      end

      # Cancel the stream and wait (up to 5 s) for the reader thread to finish.
      def cancel
        @op.cancel
        @thread&.join(5)
      end

      def join(limit = nil) = @thread.join(limit)
      def alive? = @thread&.alive? || false
      def bump! = @count += 1
    end
  end
end
