# Synchronous vs Asynchronous Methods - When to Use What (Ruby)

> Understanding execution models in RubyMT4: non-blocking streaming vs synchronous execution.

---

## 🎯 Quick Comparison

Supports standard synchronous execution for background jobs (Sidekiq/Resque) and non-blocking streaming via Fiber/Async.

| Aspect | Asynchronous Pattern | Synchronous Call |
|--------|----------------------|------------------|
| **Thread Blocking** | ❌ Non-blocking (high concurrency) | ✅ Blocks current thread |
| **Throughput** | ✅ Handles thousands of events/sec | ❌ Limited by thread pool |
| **Real-Time Data** | ✅ Perfect for tick & trade streams | ⚠️ Inefficient for streams |
| **Simplicity** | Requires async runtime awareness | Simple, linear execution |
| **Recommended for** | Automated bots, microservices, GUIs | CLI scripts, notebooks, one-offs |

---

## 🚀 When to Use Asynchronous Methods (Recommended)

### 1. Market Data Streaming
Market ticks arrive at microsecond intervals during peak sessions. Asynchronous handlers ensure zero tick drops without freezing your execution thread:

```
account = MetaRPC::MT4Account.new(user: user, password: password, host: grpc_server)
account.connect_by_server_name(server_name, 'EURUSD', 30)
summary = account.account_summary
puts "Balance: #{summary.account_balance}, Equity: #{summary.account_equity}" 
```

### 2. High-Frequency Order Execution
When operating across multiple currency pairs simultaneously, asynchronous dispatch allows your bot to send orders concurrently rather than sequentially.

---

## 💡 Summary

Always prefer asynchronous paradigms for production bots, multi-symbol trading, and background services. Use synchronous wrappers for quick setup scripts, testing, or exploratory analysis.
