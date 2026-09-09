require "metarpc_mt4"

# Initialize client with production server and API key from https://mrpc.pro/signup
api_key = ENV["MRPC_API_KEY"] || "YOUR_API_KEY_HERE"
client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: api_key)

login = 100234
password = "demo_password"

puts "Connecting to MetaTrader 4 (mt4.mrpc.pro:443)..."
if client.connect(login, password)
  puts "Connected successfully! Account ID: #{client.id}"

  puts "\nStep 1: Query Account Info..."
  acc = client.account_info
  puts "Account: #{acc[:login]} (#{acc[:name]})"
  puts "Balance: #{acc[:balance]} #{acc[:currency]}"

  puts "\nStep 2: Execute Market Order..."
  order = client.order_send(
    symbol: "EURUSD",
    cmd: :buy,
    lots: 0.1,
    comment: "Ruby Algo"
  )
  puts "Order placed! Ticket: ##{order[:ticket]}"

  client.disconnect
  puts "\nDisconnected."
end
