# Getting Started with RubyMT4

## Prerequisites
- **Ruby 2.7+**
- Bundler

## Quickstart Example

```ruby
require 'metarpc_mt4'

client = MetaRPC::MT4::Client.new('mt4.broker.com', 443)

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
