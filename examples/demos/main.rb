#!/usr/bin/env ruby
# ══════════════════════════════════════════════════════════════════════════════
# FILE: main.rb — ENTRY POINT FOR ALL RUBYMT4 DEMOS
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                   RubyMT4 — MetaTrader 4 gRPC Client                        ║
# ╚════════════════════════════════════════════════════════════════════════════╝
#
# Interactive menu (or direct launch) for the examples. Connects once, then runs
# the selected demo at the chosen abstraction level.
#
# LEARNING PROGRESSION:
#   1) LOW-LEVEL  (MT4Account)  → lowlevel/      raw gRPC / protobuf
#   2) MID-LEVEL  (MT4Service)  → service/       friendly structs, plain args
#   3) HIGH-LEVEL (MT4Sugar)    → sugar/         one-liners, risk sizing
#   4) ORCHESTRATORS            → orchestrators/ full trade lifecycles
#   5) PRESETS                  → presets/       adaptive systems
#   6) SANDBOX                  → usercode/      write your own
#
# USAGE:
#   ruby examples/demos/main.rb            # interactive menu
#   ruby examples/demos/main.rb 6          # run demo [6] directly
#   ruby examples/demos/main.rb 7 <API_KEY>   # pass an API key as the 2nd arg
#
# Credentials: examples/demos/config/config.json or the MT4_* env vars.
# ══════════════════════════════════════════════════════════════════════════════

require_relative "helpers/connection"

# Load every demo (each file registers itself into Demos::REGISTRY).
Dir[File.join(__dir__, "{lowlevel,service,sugar,orchestrators,presets,usercode}", "*.rb")].sort.each do |f|
  require f
end

def print_menu
  c = Demos::C
  line = "═" * 78
  puts "\n#{c[:cyan]}#{line}\n  RubyMT4 DEMOS\n#{line}#{c[:reset]}"
  Demos::REGISTRY.keys.sort_by(&:to_i).each do |id|
    d = Demos::REGISTRY[id]
    mark = d[:warn] ? "#{c[:yellow]}⚠#{c[:reset]} " : "  "
    puts "  [#{id.rjust(2)}] #{mark}#{d[:label]}"
  end
  puts "\n  [0] exit"
end

def run_demo(id, sugar, cfg)
  entry = Demos::REGISTRY[id.to_s]
  return false unless entry
  entry[:run].call(sugar, cfg)
  true
end

def main
  args = ARGV
  direct = args[0]
  Demos.api_key_override = args[1] if args[1]

  cfg = Demos.load_config
  if cfg.user.to_i.zero? || cfg.password.to_s.empty?
    warn "No credentials. Fill examples/demos/config/config.json or set MT4_LOGIN / MT4_PASSWORD / MT4_SERVER."
    exit 2
  end

  sugar = nil
  begin
    sugar = Demos.connect(cfg)

    if direct && direct != "menu"
      unless run_demo(direct, sugar, cfg)
        warn "Unknown demo: #{direct}"
        exit 1
      end
      return
    end

    loop do
      print_menu
      print "\n  Select: "
      choice = ($stdin.gets || "0").strip
      break if %w[0 exit quit].include?(choice)
      begin
        puts "  Unknown choice." unless run_demo(choice, sugar, cfg)
      rescue StandardError => e
        warn "#{Demos::C[:yellow]}  demo error:#{Demos::C[:reset]} #{e.message}"
      end
      print "\n  Press Enter to return to the menu…"
      $stdin.gets
    end
  rescue StandardError => e
    warn "Fatal: #{e.message}"
    exit 1
  ensure
    Demos.disconnect_quiet(sugar) if sugar
  end
end

main if $PROGRAM_NAME == __FILE__
