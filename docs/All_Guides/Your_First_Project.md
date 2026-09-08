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

Install the package:

```bash
gem install metarpc-mt4
```

---

## Step 2: Write Your Trading Code

Create your main application file and paste the following snippet:

```
require 'metarpc_mt4'

account = MetaRPC::MT4Account.new(user: user, password: password, host: grpc_server)
account.connect_by_server_name(server_name, 'EURUSD', 30)
summary = account.account_summary
puts "Balance: #{summary.account_balance}, Equity: #{summary.account_equity}" 
```

---

## Step 3: Run the Program

Run your application:

```bash
# Verify connection output
# Balance: 10000.00, Equity: 10000.00
```

---

## 🚀 Next Steps

Congratulations! You have successfully established a direct gRPC connection to MetaTrader 4. Next:
- Explore **[gRPC Streaming](GRPC_STREAM_MANAGEMENT.md)** to listen to live ticks.
- Check the **[API Reference](../API_Reference/MT4Account.md)** for all 40+ available terminal methods.
- Learn about high-level risk management and auto-normalization in **[MT4Sugar](../API_Reference/MT4Sugar.md)**.
