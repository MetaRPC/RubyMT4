# Quickstart: connect to an MT4 demo account through the MetaRPC gateway, read the
# account, quote and bars, stream ticks for 5 s and (only when TRADE=1 and the account
# is DEMO) do a 0.01-lot buy / modify / close round-trip.
#
#   MRPC_API_KEY=mrpc_live_... MT4_LOGIN=893310151 MT4_PASSWORD=... MT4_SERVER=VantageFX-Demo \
#     ruby -I../lib examples/quickstart.rb          # or: bundle exec ruby examples/quickstart.rb
require "metarpc_mt4"

login    = Integer(ENV.fetch("MT4_LOGIN"))
password = ENV.fetch("MT4_PASSWORD")
server   = ENV.fetch("MT4_SERVER", "VantageFX-Demo")
symbol   = ENV.fetch("MT4_SYMBOL", "EURUSD")

# One STABLE terminal id per strategy: the gateway keeps one terminal per id.
id = MetaRPC::MT4::Client.uuid5(MetaRPC::MT4::Client::NAMESPACE_DNS, "quickstart-#{login}")
client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"], id: id)

begin
  data = client.connect(login, password, server: server, name: "quickstart")
  puts "connected: #{data.terminal_instance_guid} (#{data.terminal_type})"
rescue MetaRPC::MT4::InvalidLoginError => e
  abort "invalid login, not retrying: #{e.message}"
end

acc = client.account_summary
puts "account #{acc.account_login} #{acc.account_company_name}: balance=#{acc.account_balance} equity=#{acc.account_equity} " \
     "#{acc.account_currency} 1:#{acc.account_leverage} #{acc.account_trade_mode}"

client.symbol_select(symbol, true)
q = client.quote(symbol)
spec = client.symbol_spec(symbol)
puts "#{symbol}: bid=#{q.bid} ask=#{q.ask} digits=#{spec.digits} vol_min=#{spec.volume_min} contract=#{spec.contract_size}"

bars = client.last_bars(symbol, timeframe: :M5, count: 10)
bars.each { |b| puts "  #{Time.at(b.time_utc).utc} o=#{b.open} h=#{b.high} l=#{b.low} c=#{b.close} v=#{b.tick_volume}" }

n = client.each_tick([symbol], seconds: 5) { |t| puts "  tick #{t.symbol} #{t.bid}/#{t.ask}" }
puts "#{n} ticks in 5 s"

if ENV["TRADE"] == "1" && client.demo?
  r = client.order_send(symbol: symbol, type: :buy, volume: spec.volume_min, magic: 123_456, comment: "quickstart", slippage: 20)
  puts "opened ticket #{r.ticket} @ #{r.price}"
  dist = [spec.stops_level, 50].max * spec.point * 3
  client.order_modify(ticket: r.ticket, stop_loss: (r.price - dist).round(spec.digits), take_profit: (r.price + dist).round(spec.digits))
  puts "open orders with magic 123456: #{client.positions(magic: 123_456).map(&:ticket)}"
  c = client.order_close(ticket: r.ticket, slippage: 20)
  puts "closed: #{c.mode}"
  client.orders_history(from_utc: Time.now.utc - 600).select { |o| o.magic_number == 123_456 }.each do |o|
    puts "  history #{o.ticket} #{o.order_type} #{o.lots} #{o.open_price}->#{o.close_price} pnl=#{o.profit}"
  end
end
# No disconnect: leave the terminal bound to the stable id for the next run.
