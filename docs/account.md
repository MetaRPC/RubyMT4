# Account Information

```ruby
acc = client.account_info
puts "Login:       #{acc[:login]}"
puts "Balance:     #{acc[:balance]}"
puts "Equity:      #{acc[:equity]}"
puts "Free Margin: #{acc[:free_margin]}"
puts "Leverage:    1:#{acc[:leverage]}"
```
