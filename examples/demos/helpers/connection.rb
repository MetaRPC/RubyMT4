# ══════════════════════════════════════════════════════════════════════════════
# FILE: connection.rb — DEMO CONNECTION HELPER & DEMO REGISTRY
# ──────────────────────────────────────────────────────────────────────────────
# One place that (1) loads the SDK, (2) connects a MT4Sugar (which exposes all
# three layers via sugar / sugar.service / sugar.account), (3) provides the small
# console helpers every demo uses (section / sub), and (4) holds the demo
# REGISTRY each demo file registers itself into.
#
# Every demo receives an already-connected `sugar` and the loaded `cfg`.
# ══════════════════════════════════════════════════════════════════════════════

# The SDK (lib/metarpc_mt4.rb). Exposes MT4Account / MT4Service / MT4Sugar / errors.
$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))
require "metarpc_mt4"
require_relative "../config/config"

module Demos
  # ANSI colors (no-op if the terminal does not support them).
  C = { reset: "\e[0m", green: "\e[32m", cyan: "\e[36m", yellow: "\e[33m", dim: "\e[2m" }.freeze

  # A boxed section header.
  def self.section(title)
    line = "═" * 78
    puts "\n#{C[:cyan]}#{line}\n  #{title}\n#{line}#{C[:reset]}"
  end

  # A sub-step label inside a demo.
  def self.sub(title)
    puts "\n#{C[:yellow]}── #{title} ──#{C[:reset]}"
  end

  # ── Demo registry ───────────────────────────────────────────────────────────
  # id (String) -> { label:, warn:, run: proc(sugar, cfg) }
  REGISTRY = {}

  # Register a demo. `warn: true` marks a demo that places/cancels real (demo) orders.
  def self.register(id, label, warn: false, &block)
    REGISTRY[id.to_s] = { label: label, warn: warn, run: block }
  end

  # Build a MT4Sugar and connect it (ConnectEx by broker server name).
  def self.connect(cfg = load_config)
    section("CONNECTION")
    if cfg.user.to_i.zero? || cfg.password.to_s.empty?
      raise "No credentials. Fill examples/demos/config/config.json or set MT4_LOGIN / MT4_PASSWORD / MT4_SERVER."
    end
    sugar = MetaRPC::MT4::MT4Sugar.create(cfg.host, cfg.port, api_key: (cfg.api_key.empty? ? nil : cfg.api_key))
    puts "#{C[:dim]}→ Connecting #{cfg.user} @ #{cfg.server} (#{cfg.host}:#{cfg.port}) …#{C[:reset]}"
    sugar.connect(cfg.user, cfg.password, server: cfg.server, timeout_seconds: 120)
    puts "#{C[:green]}  ✓ Connected — terminal id #{sugar.account.id}#{C[:reset]}"
    sugar
  end

  # Drop the channel (keeps the terminal warm on the gateway).
  def self.disconnect_quiet(sugar)
    sugar.account.close
  rescue StandardError
    # ignore
  end
end
