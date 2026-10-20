# Your First Project in 10 Minutes (Ruby)

> **Hands-on Quick Start** - Create a working trading project with MetaTrader 4 and RubyMT4 from scratch.

---

## Step 0: Obtain Your API Key

To connect to MetaRPC endpoints (`mt4.mrpc.pro:443`), obtain your API key:
1. Register for free at [https://mrpc.pro/signup](https://mrpc.pro/signup).
2. Generate your API token in your dashboard at [https://mrpc.pro/my](https://mrpc.pro/my).
3. Set your token in your environment or connection config.

---

## Step 1: Create Your Project

Create a new directory for your trading bot:

```bash
mkdir my_rubymt4_bot
cd my_rubymt4_bot
```

Get the SDK (it is not on a package registry):

```bash
git clone https://github.com/MetaRPC/RubyMT4.git
```

---

## Step 2: Write Your Trading Code

Create your main application file and paste the following snippet:

```ruby
require 'metarpc_mt4'

# API key from MRPC_API_KEY (or api_key:); id is a stable terminal id you keep per account.
client = MetaRPC::MT4::Client.new('mt4.mrpc.pro', 443, api_key: ENV['MRPC_API_KEY'], id: ENV['MT4_TERMINAL_ID'])

puts 'Connecting...'
client.connect(100234, 'my_pass', server: 'VantageFX-Demo', name: 'my-first-bot')
puts 'Connected!'

acc = client.account_summary
puts "Balance: #{acc.account_balance} #{acc.account_currency}"

# Open 0.01 Buy (demo accounts only!)
order = client.order_send(
  symbol: 'EURUSD',
  type: :buy,
  volume: 0.01,
  magic: 1,
  comment: 'Ruby Quickstart',
  slippage: 20
)

puts "Order executed! Ticket ##{order.ticket}"
client.order_close(ticket: order.ticket)
```

---

## Step 3: Run the Program

Run your application:

```bash
bundle install
bundle exec ruby examples/quickstart.rb
```

Run it from the cloned repository: its `examples/quickstart` does the same thing.

---

## 🚀 Next Steps

Congratulations! You have successfully established a direct gRPC connection to MetaTrader 4. Next:
- Explore **[gRPC Streaming](GRPC_STREAM_MANAGEMENT.md)** to listen to live ticks.
- Check the **[API Reference](../API_Reference/MT4Account.md)** for all 40+ available terminal methods.
- Learn about high-level risk management and auto-normalization in **[MT4Sugar](../API_Reference/MT4Sugar.md)**.
