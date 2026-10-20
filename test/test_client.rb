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
