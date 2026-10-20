# RubyMT4 SDK

> Idiomatic Ruby gem SDK for MetaTrader 4 algorithmic trading automation.

[![Docs](https://img.shields.io/badge/docs-RubyMT4-blue.svg)](https://metarpc.github.io/RubyMT4/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

📄 **Full Documentation**: [https://metarpc.github.io/RubyMT4/](https://metarpc.github.io/RubyMT4/)

---

## 📦 Installation

Not published on rubygems. Reference the gem by path from your `Gemfile` (the repository
ships the generated gRPC stubs in `package/`):

```ruby
source "https://rubygems.org"
gem "metarpc_mt4", path: "../path/to/RubyMT4"
```

Runtime dependencies (declared in the gemspec): `grpc >= 1.60`, `google-protobuf >= 4.26`,
`googleapis-common-protos-types >= 1.4`; Ruby >= 3.1. On Windows the gems are prebuilt
(`gem install grpc google-protobuf googleapis-common-protos-types`); on Debian 12 / Ruby 3.1
`gem install grpc` compiles from source (~45 min on 2 vCPU).

```ruby
require "metarpc_mt4"
client = MetaRPC::MT4::Client.new("mt4.mrpc.pro", 443, api_key: ENV["MRPC_API_KEY"], id: stable_uuid)
client.connect(login, password, server: "VantageFX-Demo", name: "my-bot")
client.account_summary.account_balance
client.quote("EURUSD").bid
client.order_send(symbol: "EURUSD", type: :buy, volume: 0.01, magic: 1, comment: "hi", slippage: 20).ticket
```

See `FLEET_AUDIT.md` for every verified call signature, and `examples/quickstart.rb`.

---

## 🏃 How to Run Examples

Clone the repository and run the quickstart example out-of-the-box:

```bash
git clone https://github.com/MetaRPC/RubyMT4.git
cd RubyMT4
bundle install

export MRPC_API_KEY="your_api_key_here"        # Windows PowerShell: $env:MRPC_API_KEY="your_api_key_here"
export MT4_LOGIN=893310151 MT4_PASSWORD=... MT4_SERVER=VantageFX-Demo
bundle exec ruby examples/quickstart.rb        # TRADE=1 adds a 0.01-lot demo round-trip
ruby -Ilib test/test_client.rb                 # offline unit tests
```

---

## 🔑 API Key & Authentication

Connecting to MetaRPC production endpoints (`mt4.mrpc.pro:443`) requires an API key:

1. **Sign Up**: Create an account for free at [https://mrpc.pro/signup](https://mrpc.pro/signup).
2. **Generate API Key**: In your MetaRPC Portal dashboard at [https://mrpc.pro/my](https://mrpc.pro/my), go to **API Keys** to generate and copy your personal API token.
3. **Configure Connection**: Pass your API key / token along with the server address (`mt4.mrpc.pro:443`) in your connection settings.

---

## 🆔 Automatic Account ID & Authentication

MetaRPC endpoints route calls using a terminal session identifier (`id`):
- When connecting via `Connect` / `ConnectEx`, the server automatically generates and returns a session GUID (`terminalInstanceGuid`).
- The SDK automatically captures this session ID and attaches both the `id` and `APIKey` headers on all subsequent calls (`AccountSummary`, `OrderSend`, streaming, etc.) — no manual `GetId` or `curl` calls required.
- Pass your API key directly to the Account/Client constructor or via the `MRPC_API_KEY` environment variable.

## 🌐 Production Endpoints

| Environment | Host | Port | Protocol |
| :--- | :--- | :--- | :--- |
| **Production** | `mt4.mrpc.pro` | `443` | TLS / gRPC |
| **Direct API UI (Swagger)** | `https://mt4.mrpc.pro/apiui` | `443` | HTTPS |
| **Portal Dashboard** | `https://mrpc.pro/my` | `443` | HTTPS |
| **Registration / API Key** | `https://mrpc.pro/signup` | `443` | HTTPS |

---

## 📄 Documentation & Guides

Explore comprehensive documentation at [https://metarpc.github.io/RubyMT4/](https://metarpc.github.io/RubyMT4/):
- 🚀 **Quick Start & First Project**
- 🔑 **Authentication & API Keys**
- 📡 **Live Market Data & gRPC Streaming**
- 💼 **Account Management & Order Execution**
- 📊 **Return Codes & Error Handling Reference**
