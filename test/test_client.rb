require "minitest/autorun"
require_relative "../lib/metarpc_mt4"

class TestMetaRPCMT4Client < Minitest::Test
  def setup
    @client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: "mrpc_test_key")
  end

  def test_initial_state
    refute @client.connected?
    assert_equal "mt4.mrpc.pro", @client.host
    assert_equal 443, @client.port
    assert_equal "mrpc_test_key", @client.api_key
  end

  def test_get_id_generation
    token = @client.get_id(100234, "password")
    assert token
    assert_equal token, @client.id
  end

  def test_connect_and_disconnect
    assert @client.connect(1001, "password")
    assert @client.connected?
    assert @client.id

    @client.disconnect
    refute @client.connected?
  end

  def test_account_info
    @client.connect(1001, "password")
    info = @client.account_info
    assert_equal 100234, info[:login]
    assert_equal "USD", info[:currency]
    assert_equal 10000.0, info[:balance]
    assert_equal "mt4.mrpc.pro", info[:server]
  end

  def test_order_lifecycle
    @client.connect(1001, "password")
    res = @client.order_send(
      symbol: "EURUSD",
      cmd: 0,
      lots: 0.1,
      price: 1.0850,
      comment: "Test trade"
    )
    assert_equal 0, res[:error_code]
    assert_equal 0.1, res[:lots]
    assert_equal 1.0850, res[:price]
    assert res[:ticket] > 0

    assert @client.order_modify(ticket: res[:ticket], stop_loss: 1.0800)
    assert @client.order_close(ticket: res[:ticket], lots: 0.1)
  end
end
