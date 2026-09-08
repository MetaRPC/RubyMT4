# Trading & Orders

Opening, modifying, and closing orders.

```ruby
# Open order
order = client.order_send(
  symbol: 'EURUSD',
  cmd: :buy,
  lots: 0.1,
  stop_loss: 1.0800,
  take_profit: 1.0950
)

# Modify order
client.order_modify(
  ticket: order[:ticket],
  stop_loss: 1.0820,
  take_profit: 1.0960
)

# Close order
client.order_close(
  ticket: order[:ticket],
  lots: 0.1
)
```
