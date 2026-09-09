# Getting Started with RubyMT4

## Prerequisites
- **Ruby 2.7+**
- Bundler

## Quickstart Example

```ruby
require 'metarpc_mt4'

client = MetaRPC::MT4::Client.new('mt4.mrpc.pro', 443)

puts 'Connecting...'
client.connect(100234, 'my_pass')
puts 'Connected!'

acc = client.account_info
puts "Balance: #{acc[:balance]} #{acc[:currency]}"

# Open 0.01 Buy
order = client.order_send(
  symbol: 'EURUSD',
  cmd: :buy,
  lots: 0.01,
  comment: 'Ruby Quickstart'
)

puts "Order executed! Ticket ##{order[:ticket]}"
```


> **Authentication Note**: Connecting to `mt4.mrpc.pro:443` requires a valid MetaRPC API key. Register for free at [https://mrpc.pro/signup](https://mrpc.pro/signup) and generate your token in [https://mrpc.pro/my](https://mrpc.pro/my).



---

## 🆔 Automatic Account ID & Authentication

MetaRPC endpoints require two credentials for all terminal operations:
1. **`APIKey`**: Your personal authentication token from [https://mrpc.pro/my](https://mrpc.pro/my) (obtained by registering at [https://mrpc.pro/signup](https://mrpc.pro/signup)). Sent in the `APIKey` header.
2. **`id`**: A deterministic account GUID derived from your MetaTrader `user` (login number) and `password`.

> 💡 **Seamless Automation**: You do not need to call `GetId` manually. The SDK automatically derives your deterministic account ID from your credentials upon initialization and attaches both the `id` and `APIKey` headers to all requests and streaming subscriptions.

