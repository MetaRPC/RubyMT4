# ══════════════════════════════════════════════════════════════════════════════
# FILE: config.rb — DEMO CONNECTION SETTINGS
# ──────────────────────────────────────────────────────────────────────────────
# Loads demo credentials from config/config.json and overlays environment
# variables (env wins). Never commit real credentials — prefer the MT4_* env vars.
#
# ENV VARS (override the JSON file):
#   MT4_LOGIN · MT4_PASSWORD · MT4_SERVER · MT4_HOST · MT4_PORT ·
#   MT4_SYMBOL · MT4_VOLUME · MRPC_API_KEY
#
# USAGE:
#   require_relative "config/config"
#   cfg = Demos.load_config   # => Demos::Config(user, password, server, host, port, ...)
# ══════════════════════════════════════════════════════════════════════════════

require "json"

module Demos
  Config = Struct.new(:user, :password, :server, :host, :port, :api_key,
                      :test_symbol, :test_volume, keyword_init: true)

  # API key passed on the command line (set by main.rb from ARGV); overrides env + file.
  @api_key_override = nil
  def self.api_key_override=(key)
    @api_key_override = (key.nil? || key.empty? ? nil : key)
  end

  def self.load_config
    file = {}
    path = File.join(__dir__, "config.json")
    file = JSON.parse(File.read(path)) if File.exist?(path)

    env = ENV
    num = ->(v, d) { v.nil? || v.empty? ? d : v.to_f }
    int = ->(v, d) { v.nil? || v.empty? ? d : v.to_i }

    Config.new(
      user:        int.call(env["MT4_LOGIN"], (file["user"] || 0).to_i),
      password:    env["MT4_PASSWORD"] || file["password"] || "",
      server:      env["MT4_SERVER"] || file["mt_cluster"] || "MetaQuotes-Demo",
      host:        env["MT4_HOST"] || file["host"] || "mt4.mrpc.pro",
      port:        int.call(env["MT4_PORT"], (file["port"] || 443).to_i),
      api_key:     @api_key_override || env["MRPC_API_KEY"] || file["api_key"] || "",
      test_symbol: env["MT4_SYMBOL"] || file["test_symbol"] || "EURUSD",
      test_volume: num.call(env["MT4_VOLUME"], (file["test_volume"] || 0.01).to_f)
    )
  end
end
