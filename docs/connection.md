# Connection & Authentication

Managing MT4 sessions with `MetaRPC::MT4::Client`.

```ruby
require 'metarpc_mt4'

client = MetaRPC::MT4::Client.new('mt4.broker.com', 443)
client.connect(100234, 'password')

if client.connected?
  puts "Online and ready!"
end

client.disconnect
```
