require "metarpc_mt4"

# Initialize client with production server and API key
api_key = ARGV[0] || ENV["MRPC_API_KEY"] || "TRIAL"
client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: api_key)

login = 100234
password = "demo_password"

begin
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
  end
ensure
  client.disconnect(delete: true)
  puts "\nDisconnected."
end
