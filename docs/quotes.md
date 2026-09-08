# Quotes & Market Data

Streaming tick quotes:

```ruby
client.subscribe_quotes(['EURUSD', 'GBPUSD']) do |quote|
  puts "[#{quote.symbol}] Bid: #{quote.bid} | Ask: #{quote.ask}"
end
```
