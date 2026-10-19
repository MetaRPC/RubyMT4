# Getting Started with RubyMT4

> **Preview: this SDK does not talk to the server yet.** `connect`, the account and order calls return simulated values (a fixed balance, made-up order tickets) and nothing is traded. For real MT4 accounts use the Python, Node.js, C#, Go or Java SDK, or the [REST API](https://mrpc.pro/docs-legacy/mt4-client-api).

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

MetaRPC endpoints require authentication and session management:
1. **`APIKey`**: Your personal authentication token from [https://mrpc.pro/my](https://mrpc.pro/my) (obtained by registering at [https://mrpc.pro/signup](https://mrpc.pro/signup)). Sent in the `APIKey` header.
2. **`id`**: A terminal session GUID returned by `Connect` / `ConnectEx` (`terminalInstanceGuid`).

> 💡 **Seamless Automation**: You do not need to call `GetId` or provide an `id` header when connecting. The server automatically generates a session GUID upon connection and returns it to the caller. The SDK automatically captures this session ID and attaches it alongside your `APIKey` to all subsequent requests and streaming subscriptions.

