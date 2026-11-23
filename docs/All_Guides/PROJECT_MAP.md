# 🗺️ Project Map

> The whole project as one annotated tree, with links. **Links point to section *overviews*, never individual method pages** — open an overview to drill down into its methods. The API layers live here and on the [home page](../index.md) cards (they're intentionally kept out of the left sidebar).

---

## 🧱 The three layers

RubyMT4 is built in three decoupled layers. Your code can enter at any level, and each layer **owns** the one beneath it (`sugar.service` → the `MT4Service`, `service.account` → the `MT4Account`). `MetaRPC::MT4::Client` aliases `MT4Sugar`; `Account` aliases `MT4Account`.

| Layer | Source | What it does | Overview |
| ----- | ------ | ------------ | -------- |
| **3 · MT4Sugar** | `lib/metarpc_mt4/mt4_sugar.rb` | One-line helpers: `buy_market`, `close_all`, risk sizing, SL/TP. 11 groups. | [MT4Sugar overview](../MT4Sugar/MT4Sugar.API_Overview.md) |
| **2 · MT4Service** | `lib/metarpc_mt4/mt4_service.rb` | Typed facade: plain args in, typed Ruby Structs out (`Account`, `Quote`, `SymbolSpec`). No protobuf. 5 groups. | [MT4Service overview](../MT4Service/MT4Service.Overview.md) |
| **1 · MT4Account** | `lib/metarpc_mt4/mt4_account.rb` | Low-level gRPC: protobuf request/reply, connect/session, streaming. Everything builds on it. 5 groups. | [MT4Account overview](../MT4Account/MT4Account.Master.Overview.md) |

```
Your code  →  MT4Sugar  →  MT4Service  →  MT4Account  →  gRPC  →  mt4.mrpc.pro:443  →  MT4 terminal
```

---

## 🌳 Repository tree

- **`RubyMT4/`** — repo root (the `metarpc_mt4` gem + runnable demos + docs)
  - **`lib/`** — the gem's Ruby source
    - `metarpc_mt4.rb` — entry point: requires all layers; defines `MetaRPC::MT4`
    - `metarpc_mt4/mt4_account.rb` — **Layer 1** → [MT4Account overview](../MT4Account/MT4Account.Master.Overview.md)
    - `metarpc_mt4/mt4_service.rb` — **Layer 2** (+ `Account` / `Quote` / `SymbolSpec` Structs) → [MT4Service overview](../MT4Service/MT4Service.Overview.md)
    - `metarpc_mt4/mt4_sugar.rb` — **Layer 3** (+ `Client` / `Account` aliases) → [MT4Sugar overview](../MT4Sugar/MT4Sugar.API_Overview.md)
    - `metarpc_mt4/errors.rb` — `ApiError` / `InvalidLoginError` / `TradeOutcomeUnknown` → [Return Codes & errors](./RETURN_CODES_REFERENCE.md)
    - `metarpc_mt4/subscription.rb` — the stream handle (`cancel` / `count` / `error`)
    - `metarpc_mt4/version.rb` — the gem version
  - **`package/`** — generated protobuf stubs (`mt4-term-api-*_pb.rb`, `*_services_pb.rb`) — the raw contract → [Protobuf Inspector](./PROTOBUF_INSPECTOR_GUIDE.md)
  - **`examples/`** — runnable code → [Getting Started](./GETTING_STARTED.md)
    - `quickstart.rb` — smallest connect-and-trade example
    - **`demos/`** — the demo suite (interactive menu via `main.rb`)
      - `main.rb` — the menu / launcher (`ruby examples/demos/main.rb [N]`)
      - **`config/`** — `config.json` (login/password/server/symbol/volume) · `config.rb` (loads it + env vars)
      - **`helpers/`** — `connection.rb` (loads the SDK, connects, the demo registry) · `17_protobuf_inspector.rb` (offline descriptor explorer)
      - **`lowlevel/`** — raw `MT4Account` → [overview](../MT4Account/MT4Account.Master.Overview.md)
        - `01_general_operations.rb` · `02_trading_operations.rb` · `03_streaming_methods.rb`
      - **`service/`** — typed `MT4Service` → [overview](../MT4Service/MT4Service.Overview.md)
        - `04_service_demo.rb` · `05_service_streaming.rb`
      - **`sugar/`** — one-liner `MT4Sugar` → [overview](../MT4Sugar/MT4Sugar.API_Overview.md)
        - `06_sugar_basics.rb` · `07_sugar_trading.rb` · `08_sugar_positions.rb` · `09_sugar_history.rb` · `10_sugar_advanced.rb`
      - **`orchestrators/`** — strategy loops → [Strategies](../Strategies/Strategies.Master.Overview.md)
        - `11_trailing_stop.rb` · `13_grid_trader.rb` · `14_risk_manager.rb`
      - **`presets/`** — `16_adaptive_preset.rb` (adaptive market mode)
      - **`usercode/`** — `18_usercode.rb` (sandbox for your own snippets)
  - **`test/`** — the `test_client.rb` suite
  - **`docs/`** — this documentation site (mkdocs-material) — see the map below
  - `metarpc_mt4.gemspec` · `Gemfile` · `mkdocs.yml` — gem / docs config

---

## 📚 Documentation tree

- **`docs/`**
  - [Home](../index.md) — landing page (cards into the three layers + Trade Copier)
  - **`All_Guides/`** — the guides in the left nav (Getting Started, MT4 for Beginners, Your First Project, SDK Ecosystem, Glossary, Sync vs Async, gRPC Stream Management, Enums, Return Codes, Protobuf Inspector, UserCode Sandbox)
  - **`MT4Account/`** — low-level gRPC docs → [overview](../MT4Account/MT4Account.Master.Overview.md) *(per-method pages inside)*
  - **`MT4Service/`** — typed facade docs → [overview](../MT4Service/MT4Service.Overview.md) *(per-group pages inside)*
  - **`MT4Sugar/`** — one-liner docs → [overview](../MT4Sugar/MT4Sugar.API_Overview.md) *(per-group pages inside)*
  - **`Strategies/`** — orchestrators & the adaptive preset → [overview](../Strategies/Strategies.Master.Overview.md)
  - `Guide_Images/` · `styles/` · `javascripts/` · `includes/` — assets & theme

> The `MT4Account/`, `MT4Service/` and `MT4Sugar/` folders hold the detail pages but are **not in the left sidebar** — reach them from the home cards or the overview links above. Each overview is the index into its own pages.

---

## 🎮 Running the demos

The demos (laid out in the tree above) run from one menu — pass a number to run one directly:

```bash
ruby examples/demos/main.rb          # interactive menu
ruby examples/demos/main.rb 6        # sugar basics
ruby examples/demos/main.rb 11       # trailing-stop orchestrator
```

Config comes from `examples/demos/config/config.json` or the env vars `MT4_LOGIN` / `MT4_PASSWORD` / `MT4_SERVER` / `MT4_SYMBOL` / `MT4_VOLUME` / `MRPC_API_KEY`.

---

## 🎯 Which layer should you use?

- **Most trading apps → [MT4Sugar](../MT4Sugar/MT4Sugar.API_Overview.md).** One-liners, risk-based sizing and SL/TP keep your code short and safe.
- **Custom execution → [MT4Service](../MT4Service/MT4Service.Overview.md).** Typed calls when you manage your own flow.
- **Protocol-level control → [MT4Account](../MT4Account/MT4Account.Master.Overview.md).** Raw protobuf requests and streams.
- **New to MT4?** → [MT4 for Beginners](./MT4_For_Beginners.md), then [Getting Started](./GETTING_STARTED.md).
- **Mirror trades to other accounts?** → [SDK Ecosystem → Trade Copier](./SDK_Ecosystem.md).
