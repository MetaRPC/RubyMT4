require "metarpc_mt4"

client = MetaRPC::MT4::Client.new("mt4.broker.com", 443)

puts "Connecting to MT4..."
if client.connect(100234, "password")
  puts "Connected!"

  acc = client.account_info
  puts "Balance: #{acc[:balance]} #{acc[:currency]}"

  order = client.order_send(
    symbol: "EURUSD",
    cmd: :buy,
    lots: 0.1,
    comment: "Ruby Algo"
  )
  puts "Order placed! Ticket: ##{order[:ticket]}"
end
