# Offline unit tests (no network): metadata, ids, message construction, error unwrapping.
#   cd lib/RubyMT4 && ruby -Ilib test/test_client.rb
require "minitest/autorun"
require_relative "../lib/metarpc_mt4"

class TestMetaRPCMT4Client < Minitest::Test
  def setup
    @client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: "mrpc_test_key", id: "11111111-2222-3333-4444-555555555555")
  end

  def test_initial_state
    refute @client.connected?
    assert_equal "mt4.mrpc.pro", @client.host
    assert_equal 443, @client.port
    assert_equal "mt4.mrpc.pro:443", @client.target
    assert_equal({ "apikey" => "mrpc_test_key", "id" => "11111111-2222-3333-4444-555555555555" }, @client.metadata)
  end

  def test_api_key_required
    old = ENV.delete("MRPC_API_KEY")
    assert_raises(ArgumentError) { MetaRPC::MT4::Client.new(api_key: nil) }
  ensure
    ENV["MRPC_API_KEY"] = old if old
  end

  def test_deterministic_id
    id = MetaRPC::MT4::Client.compute_deterministic_id(12_345_678, "demo_password")
    assert_equal "6ce74465-7aa9-3a79-2bd8-e40241b50c43", id
  end

  def test_uuid5_matches_python
    # python: uuid.uuid5(uuid.NAMESPACE_DNS, "fleet-audit-RubyMT4")
    assert_equal "ceed89e3-6059-5c78-b9b2-ddae14d7754d",
                 MetaRPC::MT4::Client.uuid5(MetaRPC::MT4::Client::NAMESPACE_DNS, "fleet-audit-RubyMT4")
  end

  def test_server_timezone_stub_loads
    assert Mt4TermApi::ServerTimezone::Stub
    assert_equal :SERVER_TIMEZONE_SOURCE_LIVE, Mt4TermApi::ServerTimezoneData.new(source: :SERVER_TIMEZONE_SOURCE_LIVE).source
    assert_equal 3, Mt4TermApi::HealthCheckReply.descriptor.lookup("serverTimeMscUtc").number
  end

  def test_generated_messages_load
    req = Mt4TermApi::ConnectExRequest.new(user: 893_310_151, password: "x", mt_cluster_name: "VantageFX-Demo", timeout_seconds: 120, name: "n")
    assert_equal 893_310_151, req.user
    assert_equal "VantageFX-Demo", req.mt_cluster_name
    o = Mt4TermApi::OrderSendRequest.new(symbol: "EURUSD", operation_type: :OC_OP_SELL, volume: 0.01, magic_number: 600_001, comment: "S001", slippage: 20)
    assert_equal :OC_OP_SELL, o.operation_type
    assert_equal 600_001, o.magic_number
    assert_equal :QHB_PERIOD_H1, MetaRPC::MT4::Client::TIMEFRAMES[:H1]
    assert_equal :OC_OP_BUYLIMIT, MetaRPC::MT4::Client::ORDER_TYPES[:buy_limit]
  end

  def test_unwrap_data_and_error
    ok = Mt4TermApi::QuoteReply.new(data: Mt4TermApi::QuoteData.new(symbol: "EURUSD", bid: 1.1, ask: 1.2))
    assert_equal 1.1, @client.unwrap(ok, :quote).bid
    bad = Mt4TermApi::OrderSendReply.new(error: Mt4TermApi::Error.new(error_code: "MQL_ERROR", error_message: "market closed", mql_error_int_code: 132))
    e = assert_raises(MetaRPC::MT4::ApiError) { @client.unwrap(bad, :order_send) }
    assert_equal "MQL_ERROR", e.code
    assert_equal 132, e.mql_code
    assert_match(/market closed/, e.message)
    plain = Mt4TermApi::HealthCheckReply.new(connected: true)
  end

  def test_invalid_login_detection
    err = Mt4TermApi::Error.new(error_code: "CONNECT_EX_INVALID_LOGIN_ERROR", error_message: "invalid account")
    assert @client.invalid_login?(MetaRPC::MT4::ApiError.new(err, "ConnectEx"))
    err2 = Mt4TermApi::Error.new(error_code: "TERMINAL_API_TIMEOUT", error_message: "timeout")
    refute @client.invalid_login?(MetaRPC::MT4::ApiError.new(err2, "ConnectEx"))
  end

  def test_symbol_spec_mapping
    raw = Mt4TermApi::SymbolParamsManyInfo.new(SymbolName: "EURUSD", Digits: 5, Point: 0.00001, VolumeMin: 0.01, VolumeStep: 0.01,
                                                VolumeMax: 100, TradeContractSize: 100_000, TradeStopsLevel: 0, TradeMode: :SYMBOL_TRADE_MODE_FULL)
    spec = MetaRPC::MT4::Client.spec_of(raw)
    assert_equal "EURUSD", spec.name
    assert_equal 5, spec.digits
    assert_equal 0.01, spec.volume_min
    assert_equal 100_000.0, spec.contract_size
    assert_equal :SYMBOL_TRADE_MODE_FULL, spec.trade_mode
    assert_same raw, spec.raw
  end

  def test_symbol_params_unknown_symbol_is_nil
    err = Mt4TermApi::Error.new(error_code: "EXECUTION_ERROR_IN_INTERNAL_GRPC_SERVICE", error_message: "Symbol pair name does not exist")
    stub = Object.new
    stub.define_singleton_method(:symbol_params_many) { |*_a, **_k| Mt4TermApi::SymbolParamsManyReply.new(error: err) }
    @client.instance_variable_get(:@stubs)[:account_helper] = stub
    assert_nil @client.symbol_params("NOPE")
    assert_nil @client.symbol_spec("NOPE")
  end

  def test_disconnect_flag_is_tracked_only_after_rpc
    assert_nil @client.last_disconnect_deleted
  end
end

# A trade is sent exactly once: a transport failure of a trade call is marked TradeOutcomeUnknown (the trade may
# have been executed), never re-sent. In-process gRPC server on localhost, no network.
class TestMetaRPCMT4TradeOutcome < Minitest::Test
  # Counts calls; the next call fails with `fail_next` (a GRPC::BadStatus) or answers `error_next` (an Error message).
  class FakeServer
    attr_accessor :fail_next, :error_next
    attr_reader :calls

    def initialize = @calls = Hash.new(0)

    def answer(rpc, reply_class, data)
      @calls[rpc] += 1
      if (f = @fail_next)
        @fail_next = nil
        raise f
      end
      if (e = @error_next)
        @error_next = nil
        return reply_class.new(error: e)
      end
      reply_class.new(data: data)
    end
  end

  FAKE = FakeServer.new

  class Trading < Mt4TermApi::TradingHelper::Service
    def order_send(_req, _call) = FAKE.answer(:order_send, Mt4TermApi::OrderSendReply, Mt4TermApi::OrderSendData.new(ticket: 88))
    def order_modify(_req, _call) = FAKE.answer(:order_modify, Mt4TermApi::OrderModifyReply, Mt4TermApi::OrderModifyData.new(order_was_modified: true))
    def order_close_delete(_req, _call) = FAKE.answer(:order_close_delete, Mt4TermApi::OrderCloseDeleteReply, Mt4TermApi::OrderCloseDeleteData.new)
    def order_close_by(_req, _call) = FAKE.answer(:order_close_by, Mt4TermApi::OrderCloseByReply, Mt4TermApi::OrderCloseByData.new)
  end

  class AccountHelper < Mt4TermApi::AccountHelper::Service
    def account_summary(_req, _call) = FAKE.answer(:account_summary, Mt4TermApi::AccountSummaryReply, Mt4TermApi::AccountSummaryData.new(account_login: 7))
  end

  class QuoteHistory < Mt4TermApi::QuoteHistory::Service
    def bars(_req, _call) = FAKE.answer(:bars, Mt4TermApi::QuoteHistoryBarsReply, Mt4TermApi::QuoteHistoryBarsData.new)
  end

  def self.port
    @port ||= begin
      server = GRPC::RpcServer.new
      port = server.add_http2_port("127.0.0.1:0", :this_port_is_insecure)
      [Trading, AccountHelper, QuoteHistory].each { |s| server.handle(s) }
      Thread.new { server.run }
      server.wait_till_running(10)
      Minitest.after_run { server.stop }
      port
    end
  end

  def setup
    @client = MetaRPC::MT4::Client.new("127.0.0.1", self.class.port, api_key: "k", id: "11111111-2222-3333-4444-555555555555", timeout: 10)
    FAKE.calls.clear
  end

  TRADES = {
    "OrderSend" => [:order_send, ->(c) { c.order_send(symbol: "EURUSD", type: :buy, volume: 0.1) }],
    "OrderModify" => [:order_modify, ->(c) { c.order_modify(ticket: 88, stop_loss: 1.0) }],
    "OrderCloseDelete" => [:order_close_delete, ->(c) { c.order_close(ticket: 88, lots: 0.05) }],
    "OrderCloseBy" => [:order_close_by, ->(c) { c.order_close_by(ticket: 88, opposite_ticket: 89) }]
  }.freeze

  def test_trade_transport_failure_is_sent_once_and_marked_trade_outcome_unknown
    TRADES.each do |operation, (rpc, run)|
      [GRPC::Unavailable, GRPC::DeadlineExceeded, GRPC::Unknown, GRPC::Internal].each do |klass|
        FAKE.calls.clear
        FAKE.fail_next = klass.new("connection reset")
        e = assert_raises(klass) { run.call(@client) } # still the gRPC error class callers rescue
        assert_equal({ rpc => 1 }, FAKE.calls, "#{operation} #{klass}")
        assert_kind_of MetaRPC::MT4::TradeOutcomeUnknown, e
        assert_equal klass.new.code, e.code
        assert_equal "connection reset", e.details
        assert_equal "TRADE_OUTCOME_UNKNOWN", e.error_code
        assert e.trade_outcome_unknown?
        assert_equal operation, e.operation
        assert_match(/\ATRADE_OUTCOME_UNKNOWN: #{operation} failed with gRPC [A-Z_]+ .*NOT re-sent.*connection reset/, e.message)
      end
    end
  end

  def test_in_band_trade_timeouts_are_unknown_outcomes
    TRADES.each do |operation, (rpc, run)|
      FAKE.calls.clear
      FAKE.error_next = Mt4TermApi::Error.new(error_code: "COMMAND_TIMEOUT_EXCEEDED", error_message: "terminal did not answer")
      e = assert_raises(MetaRPC::MT4::ApiError) { run.call(@client) }
      assert e.trade_outcome_unknown?, operation
      assert_equal({ rpc => 1 }, FAKE.calls)
    end
    send = -> { @client.order_send(symbol: "EURUSD", type: :buy, volume: 0.1) }
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "TERMINAL_API_CALL_TIMEOUT")
    assert assert_raises(MetaRPC::MT4::ApiError) { send.call }.trade_outcome_unknown?
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "X", type: :MRPC_TIMEOUT)
    assert assert_raises(MetaRPC::MT4::ApiError) { send.call }.trade_outcome_unknown?
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "MQL4_EXECUTION_FAILED", mql_error_int_code: 128)
    assert assert_raises(MetaRPC::MT4::ApiError) { send.call }.trade_outcome_unknown?
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "MQL4_EXECUTION_FAILED", mql_error_int_code: 134)
    refute assert_raises(MetaRPC::MT4::ApiError) { send.call }.trade_outcome_unknown?
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "COMMAND_TIMEOUT_EXCEEDED")
    refute assert_raises(MetaRPC::MT4::ApiError) { @client.account_summary }.trade_outcome_unknown?
  end

  def test_trade_refused_before_terminal_is_api_error_with_known_outcome
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "TERMINAL_INSTANCE_NOT_FOUND", error_message: "no terminal")
    e = assert_raises(MetaRPC::MT4::ApiError) { @client.order_send(symbol: "EURUSD", type: :buy, volume: 0.1) }
    assert_equal "TERMINAL_INSTANCE_NOT_FOUND", e.code
    refute e.trade_outcome_unknown?
    assert_equal({ order_send: 1 }, FAKE.calls)
  end

  def test_refused_api_key_is_one_call_with_its_code
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "API_KEY_INVALID", error_message: "Unknown API key")
    e = assert_raises(MetaRPC::MT4::ApiError) { @client.order_send(symbol: "EURUSD", type: :buy, volume: 0.1) }
    assert_equal "API_KEY_INVALID", e.code
    assert e.api_key_error?
    refute e.trade_outcome_unknown?
    assert_equal({ order_send: 1 }, FAKE.calls)
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "API_KEY_REQUIRED", error_message: "no key")
    assert assert_raises(MetaRPC::MT4::ApiError) { @client.account_summary }.api_key_error?
  end

  def test_transport_failure_naming_a_refused_key_is_not_marked
    FAKE.fail_next = GRPC::Unknown.new("API_KEY_INVALID")
    e = assert_raises(GRPC::Unknown) { @client.order_send(symbol: "EURUSD", type: :buy, volume: 0.1) }
    refute_kind_of MetaRPC::MT4::TradeOutcomeUnknown, e
    assert_equal({ order_send: 1 }, FAKE.calls)
  end

  def test_reads_keep_their_behaviour
    FAKE.fail_next = GRPC::Unavailable.new("down")
    e = assert_raises(GRPC::Unavailable) { @client.account_summary }
    refute_kind_of MetaRPC::MT4::TradeOutcomeUnknown, e
    assert_equal({ account_summary: 1 }, FAKE.calls)
    # bars still retries QUOTE_HISTORY_NOT_READY (a read) and then succeeds
    FAKE.error_next = Mt4TermApi::Error.new(error_code: "QUOTE_HISTORY_NOT_READY")
    assert_equal [], @client.bars("EURUSD", timeframe: :H1, from_utc: 0)
    assert_equal 2, FAKE.calls[:bars]
  end
end
