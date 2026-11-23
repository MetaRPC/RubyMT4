require "metarpc_mt4"

# MetaRPC MT4 Ruby SDK quickstart (real gRPC calls against mt4.mrpc.pro:443).
#
#   MRPC_API_KEY=... MT4_LOGIN=... MT4_PASSWORD=... MT4_SERVER=VantageFX-Demo \
#     bundle exec ruby examples/quickstart.rb
#
# Three layers, one object: MT4Sugar.create builds MT4Sugar -> MT4Service ->
# MT4Account. Reach down with `mt4.service` / `mt4.account` when you need to.
#
# Use a STABLE terminal id per account/strategy (uuid5 below): the gateway keeps
# one terminal per id, and a fresh id on every run orphans terminals.
#
# MT4 has ORDERS, not positions: an open market order IS the position, and there
# is no retcode — order_send returns OrderSendData with ticket > 0 when filled.

MT4 = MetaRPC::MT4

api_key  = ARGV[0] || ENV["MRPC_API_KEY"] || abort("set MRPC_API_KEY")
login    = (ENV["MT4_LOGIN"] || abort("set MT4_LOGIN")).to_i
password = ENV["MT4_PASSWORD"] || abort("set MT4_PASSWORD")
server   = ENV["MT4_SERVER"] || "MetaQuotes-Demo"
host     = ENV["MT4_HOST"] || "mt4.mrpc.pro"

terminal_id = MT4::MT4Account.uuid5(MT4::MT4Account::NAMESPACE_DNS, "quickstart-#{login}")
mt4 = MT4::MT4Sugar.create(host, 443, api_key: api_key, id: terminal_id)

puts "Connecting #{login}@#{server} ..."
begin
  mt4.connect(login, password, server: server, name: "ruby-quickstart")
rescue MT4::InvalidLoginError => e
  abort "Invalid login, not retrying: #{e.message}"
end

a = mt4.account_info
puts "Account #{a.login} (#{a.company}) balance=#{a.balance} #{a.currency} " \
     "equity=#{a.equity} leverage=1:#{a.leverage} mode=#{a.trade_mode}"

symbol = ENV["MT4_SYMBOL"] || "EURUSD"
mt4.select_symbol(symbol, true)             # Market Watch add
q = mt4.price(symbol)
puts "#{symbol} bid=#{q.bid} ask=#{q.ask} spread=#{q.spread.round(5)}"

bars = mt4.last_bars(symbol, timeframe: :M5, count: 10)
puts "last M5 close: #{bars.last&.close}"

puts "streaming ticks for 5 s ..."
n = mt4.each_tick([symbol], seconds: 5) { |t| puts "  #{t.symbol} #{t.bid}/#{t.ask}" }
puts "#{n} ticks"

if mt4.demo? && ENV["QUICKSTART_TRADE"] == "1"
  r = mt4.buy_market(symbol, 0.01, magic: 123_456, comment: "ruby-quickstart")
  puts "buy_market ticket=#{r.ticket} price=#{r.price} volume=#{r.volume}"
  if r.ticket.to_i.positive?
    sleep 1
    c = mt4.close_order(r.ticket)
    puts "close mode=#{c.mode}"
  end
end

puts "open orders: #{mt4.open_orders.map { |o| "#{o.symbol} #{o.order_type} #{o.lots} @#{o.open_price} magic=#{o.magic_number}" }.inspect}"
# Do not disconnect: the terminal stays bound to terminal_id and the next run reuses it.
