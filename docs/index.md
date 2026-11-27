---
title: "MetaTrader 4 API — Ruby SDK"
description: "MetaRPC RubyMT4 — Ruby SDK for MetaTrader 4 trading automation over gRPC. Connect, stream live ticks and orders, and execute trades from any Ruby application."
hide:
  - navigation
  - toc
---

# MetaTrader 4 API — Ruby SDK

> ℹ️ **Account ID / Session ID**: when connecting via `connect` / `connect_ex`, MetaRPC automatically generates a terminal session GUID and returns it in `terminal_instance_guid`. You do not need to call `get_id` or supply an `id` before connecting — subsequent calls (subscriptions, order requests) use this session id automatically.

!!! info "Use the MT4 SDK with MetaRPC"

    MetaRPC provides APIs and hosted terminal infrastructure for developers. Build your client on Windows, macOS or Linux; you control your broker accounts and trading decisions.

    Start with the API setup guide, try the browser playground, or connect a trade-copying workflow.

    [API setup and pricing](https://mrpc.pro/start/api?lang=en&utm_source=github&utm_medium=referral&utm_campaign=api_sdk_discovery&utm_content=rubymt4_setup)

    [Try the API playground](https://mrpc.pro/api?lang=en&utm_source=github&utm_medium=referral&utm_campaign=api_sdk_discovery&utm_content=rubymt4_playground#live-code)

    [Explore trade copying](https://mrpc.pro/start/copier?lang=en&utm_source=github&utm_medium=referral&utm_campaign=api_sdk_discovery&utm_content=rubymt4_copier)

    **Preview SDK:** check this SDK’s supported methods and test your integration on a demo account before relying on it.

<div class="hx-wrap" markdown="0">

<div class="hx-hero">
  <p class="hx-sub">Ruby SDK for MetaTrader 4 trading automation over gRPC — connect, stream live ticks and orders, and execute trades from any Ruby application.</p>
  <div class="hx-stats">
    <div class="hx-stat"><span class="hx-statV">3</span><span class="hx-statL">API Layers</span></div>
    <div class="hx-stat"><span class="hx-statV">gRPC</span><span class="hx-statL">protobuf + TLS</span></div>
    <div class="hx-stat"><span class="hx-statV">MT4</span><span class="hx-statL">Cloud Terminal</span></div>
    <div class="hx-stat"><span class="hx-statV">Ruby</span><span class="hx-statL">gem · blocks &amp; threads</span></div>
  </div>
</div>

<div class="hx-cards hx-cards-4">

  <a href="All_Guides/Your_First_Project/" class="hx-gc hx-orange">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Get Started</div>
      <div class="hx-gcTitle">Quick Start</div>
      <p class="hx-gcDesc">Your first project from scratch in 10 minutes. Connect, read your balance, place a trade.</p>
      <div class="hx-gcCount">10 min · hands-on</div>
    </div>
  </a>

  <a href="All_Guides/GETTING_STARTED/" class="hx-gc hx-blue">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Learn</div>
      <div class="hx-gcTitle">Getting Started</div>
      <p class="hx-gcDesc">New here? Start with setup, the API key, and an overview of how the SDK is organized.</p>
      <div class="hx-gcCount">setup · overview</div>
    </div>
  </a>

  <a href="All_Guides/PROJECT_MAP/" class="hx-gc hx-purple">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Architecture</div>
      <div class="hx-gcTitle">Project Map</div>
      <p class="hx-gcDesc">How the low-, mid- and high-level layers fit together, and where everything lives.</p>
      <div class="hx-gcCount">structure · layers</div>
    </div>
  </a>

  <a href="All_Guides/SDK_Ecosystem/" class="hx-gc hx-pink">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Ecosystem</div>
      <div class="hx-gcTitle">Trade Copier</div>
      <p class="hx-gcDesc">Mirror a strategy across accounts — how RubyMT4 pairs with RubyCopier (master → followers).</p>
      <div class="hx-gcCount">copier · master → followers</div>
    </div>
  </a>

</div>

<div class="hx-cards">

  <a href="MT4Account/MT4Account.Master.Overview/" class="hx-gc hx-teal">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Reference · Low-level</div>
      <div class="hx-gcTitle">MT4Account</div>
      <p class="hx-gcDesc">Direct gRPC / protobuf layer. Maximum control over every request and typed response.</p>
      <div class="hx-gcCount">raw gRPC · full control</div>
    </div>
  </a>

  <a href="MT4Service/MT4Service.Overview/" class="hx-gc hx-rose">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Reference · Mid-level</div>
      <div class="hx-gcTitle">MT4Service</div>
      <p class="hx-gcDesc">Friendly facade over MT4Account — plain arguments and typed Ruby Structs instead of protobuf.</p>
      <div class="hx-gcCount">friendly args · typed structs</div>
    </div>
  </a>

  <a href="MT4Sugar/MT4Sugar.API_Overview/" class="hx-gc hx-green">
    <div class="hx-gcTop"></div>
    <div class="hx-gcBody">
      <div class="hx-gcTag">Reference · High-level</div>
      <div class="hx-gcTitle">MT4Sugar</div>
      <p class="hx-gcDesc">One-liner operations, risk-based position sizing and smart defaults for fast strategies.</p>
      <div class="hx-gcCount">one-liners · risk sizing</div>
    </div>
  </a>

</div>

</div>
