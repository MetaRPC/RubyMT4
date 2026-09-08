# RubyMT4 SDK

Welcome to the **RubyMT4 SDK** documentation. This gem provides an idiomatic Ruby interface connecting directly to MetaTrader 4 servers without requiring a local MT4 desktop terminal or Wine.

## Key Features

- **Pure Ruby Implementation**: Zero native extensions or Wine overhead.
- **Block-Based Quote Streaming**: Stream real-time ticks using standard Ruby blocks.
- **Full Trade Execution**: Market orders, limit & stop orders, SL/TP trailing, and closing.
- **Account Monitoring**: Live equity, margin, leverage, and trade history.

## Architecture

```mermaid
graph TD
    A[Ruby Application] -->|Socket I/O| B[MetaRPC::MT4::Client]
    B -->|Encrypted Protocol| C[MetaTrader 4 Server]
    C -->|Quotes Callback| B
    C -->|Order Confirmations| B
    B -->|Ruby Block Yield| A
```

## Quick Installation

Add to your Gemfile:

```ruby
gem 'metarpc_mt4', git: 'https://github.com/MetaRPC/RubyMT4.git'
```

And run:

```bash
bundle install
```

See [Getting Started](getting-started.md) to start trading.
