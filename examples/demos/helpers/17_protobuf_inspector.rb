#!/usr/bin/env ruby
# frozen_string_literal: true

# ══════════════════════════════════════════════════════════════════════════════
# FILE: 17_protobuf_inspector.rb — INTERACTIVE PROTOBUF TYPES INSPECTOR
#
# PURPOSE:
#   Explore the generated MT4 protobuf stubs at runtime — message fields and enum
#   values — without guessing names. Answer "what's the real accessor?" (e.g.
#   magic_number, not magic; TradeTickValue in PascalCase; order_type, not type)
#   and "what are this enum's values?" straight from the descriptors, offline.
#
# OFFLINE: loads package/*_pb.rb only; no connection, no API key, no trades.
#
# RUN (REPL):     ruby examples/demos/helpers/17_protobuf_inspector.rb
# RUN (one-shot): ruby examples/demos/helpers/17_protobuf_inspector.rb OrderSendData
#                 ruby examples/demos/helpers/17_protobuf_inspector.rb enum OC_Order_Type
#                 ruby examples/demos/helpers/17_protobuf_inspector.rb search Tick
#
# COMMANDS (REPL):
#   list [--msg|--enum]   list message types / enums
#   <TypeName>            show a message's fields (name · type · label · #)
#   search <text>         find message/enum names containing <text>
#   field <name>          which messages carry a field named <name>
#   findtype <type>       all fields of a proto type (double, string, int64, enum…)
#   enum <Name>           show an enum's values
#   whereenum <Name>      which message fields use enum <Name>
#   stats                 counts
#   help / ?              this help
#   exit / quit / q       leave
#
# Ruby descriptors expose the field NAME (= the accessor you call), its proto
# type, label (repeated/optional), field number and, for message/enum fields, the
# subtype — richer than the raw getters you'd guess. See the matching guide:
# docs/All_Guides/PROTOBUF_INSPECTOR_GUIDE.md
# ══════════════════════════════════════════════════════════════════════════════

require "google/protobuf"

PKG_DIR = File.expand_path("../../../package", __dir__)

# ── discover message types & enums from every *_pb.rb stub ──────────────────────
TYPES = {} # "Name" => Google::Protobuf::Descriptor
ENUMS = {} # "Name" => Google::Protobuf::EnumDescriptor

def load_stubs
  $LOAD_PATH.unshift(PKG_DIR) unless $LOAD_PATH.include?(PKG_DIR)
  Dir[File.join(PKG_DIR, "*_pb.rb")].reject { |f| f.end_with?("_services_pb.rb") }.sort.each do |f|
    require File.basename(f, ".rb")
  rescue StandardError, LoadError
    # skip a stub that fails to load in isolation; others still work
  end

  return unless defined?(Mt4TermApi)

  Mt4TermApi.constants.each do |c|
    val = Mt4TermApi.const_get(c)
    if val.is_a?(Class) && val.respond_to?(:descriptor) &&
       val.descriptor.is_a?(Google::Protobuf::Descriptor)
      TYPES[c.to_s] = val.descriptor
    elsif val.is_a?(Module) && val.respond_to?(:descriptor) &&
          val.descriptor.is_a?(Google::Protobuf::EnumDescriptor)
      ENUMS[c.to_s] = val.descriptor
    end
  end
end

# ── helpers ─────────────────────────────────────────────────────────────────────
def line(char = "─") = char * 64

# A field's proto type, with the short subtype name for message/enum fields.
def field_type(fd)
  base = fd.type.to_s
  sub  = (fd.subtype.name.split(".").last if %i[message enum group].include?(fd.type) && fd.subtype)
  sub ? "#{base}<#{sub}>" : base
end

def resolve(map, name)
  return name if map.key?(name)

  lc = name.downcase
  exact = map.keys.find { |k| k.downcase == lc }
  return exact if exact

  partial = map.keys.select { |k| k.downcase.include?(lc) }.sort
  return partial.first if partial.size == 1
  if partial.size > 1
    puts "\n[!] Multiple match '#{name}':\n  #{partial.first(15).join("\n  ")}"
  end
  nil
end

# ── commands ────────────────────────────────────────────────────────────────────
def cmd_list(arg)
  if arg != "--enum"
    puts "\nMESSAGE TYPES (#{TYPES.size})\n#{line}"
    TYPES.keys.sort.each_with_index { |n, i| puts format("  %3d. %s", i + 1, n) }
  end
  return unless arg != "--msg"

  puts "\nENUMS (#{ENUMS.size})\n#{line}"
  ENUMS.keys.sort.each_with_index { |n, i| puts format("  %3d. %s", i + 1, n) }
end

def cmd_type(name)
  key = resolve(TYPES, name)
  unless key
    puts "\n[!] Message type '#{name}' not found (try: search #{name})" unless ENUMS.key?(name)
    return cmd_enum(name) if resolve(ENUMS, name)

    return
  end
  desc = TYPES[key]
  fields = desc.to_a
  puts "\nTYPE: #{key}   (#{fields.size} fields)\n#{line("=")}"
  if fields.empty?
    puts "  (no fields)"
  else
    width = fields.map { |fd| fd.name.length }.max
    fields.sort_by(&:number).each do |fd|
      label = fd.label == :repeated ? "repeated" : ""
      puts format("  %-#{width}s  %-22s %-9s (#%d)", fd.name, field_type(fd), label, fd.number)
    end
  end
end

def cmd_enum(name)
  key = resolve(ENUMS, name)
  unless key
    puts "\n[!] Enum '#{name}' not found (try: search #{name})"
    return
  end
  puts "\nENUM: #{key}\n#{line("=")}"
  pairs = ENUMS[key].to_a.sort_by { |(_n, v)| v }
  width = pairs.map { |(n, _v)| n.to_s.length }.max || 0
  pairs.each { |(n, v)| puts format("  %-#{width}s = %d", n, v) }
end

def cmd_search(query)
  lc = query.downcase
  msgs  = TYPES.keys.select { |n| n.downcase.include?(lc) }.sort
  enums = ENUMS.keys.select { |n| n.downcase.include?(lc) }.sort
  puts "\nMATCHES for '#{query}'\n#{line}"
  puts "messages (#{msgs.size}): #{msgs.join(", ")}"  unless msgs.empty?
  puts "enums    (#{enums.size}): #{enums.join(", ")}" unless enums.empty?
  puts "  (none)" if msgs.empty? && enums.empty?
end

# Which message types carry a field named (or containing) <name>?
def cmd_field(name)
  lc = name.downcase
  exact   = []
  partial = []
  TYPES.each do |tname, desc|
    desc.each do |fd|
      exact   << tname           if fd.name == name
      partial << "#{tname} (#{fd.name})" if fd.name != name && fd.name.downcase.include?(lc)
    end
  end
  puts "\nFIELD '#{name}'\n#{line}"
  puts "exact match in (#{exact.size}): #{exact.sort.uniq.join(", ")}" unless exact.empty?
  puts "\npartial (#{partial.size}): #{partial.sort.uniq.first(40).join(", ")}" unless partial.empty?
  puts "  (none)" if exact.empty? && partial.empty?
end

# All fields whose proto type is <type> (double / string / int64 / message / enum …), grouped by message.
def cmd_findtype(type)
  want = type.downcase
  hits = {}
  TYPES.each do |tname, desc|
    names = desc.select { |fd| fd.type.to_s == want }.map(&:name)
    hits[tname] = names unless names.empty?
  end
  puts "\nFIELDS OF TYPE '#{type}' (#{hits.values.sum(&:size)} in #{hits.size} messages)\n#{line("=")}"
  if hits.empty?
    puts "  (none — try: double, string, int64, uint64, int32, bool, message, enum)"
  else
    hits.keys.sort.first(40).each { |tname| puts "  #{tname}: #{hits[tname].join(", ")}" }
    puts "  … (#{hits.size - 40} more messages)" if hits.size > 40
  end
end

# Which message fields are typed with enum <Name>?
def cmd_whereenum(name)
  key = resolve(ENUMS, name)
  unless key
    puts "\n[!] Enum '#{name}' not found (try: search #{name})"
    return
  end
  hits = []
  TYPES.each do |tname, desc|
    desc.each do |fd|
      hits << "#{tname}.#{fd.name}" if fd.type == :enum && fd.subtype && fd.subtype.name.split(".").last == key
    end
  end
  puts "\nENUM '#{key}' used in (#{hits.size} fields)\n#{line("=")}"
  puts hits.empty? ? "  (used by no message field)" : hits.sort.map { |h| "  #{h}" }.join("\n")
end

def cmd_stats
  enum_vals = ENUMS.values.sum { |d| d.to_a.size }
  fields    = TYPES.values.sum { |d| d.to_a.size }
  puts "\nSTATS\n#{line("=")}"
  puts "  message types : #{TYPES.size}"
  puts "  message fields: #{fields}"
  puts "  enums         : #{ENUMS.size}"
  puts "  enum values   : #{enum_vals}"
end

def cmd_help
  puts "\nCOMMANDS\n#{line}"
  puts "  list [--msg|--enum]   list message types / enums"
  puts "  <TypeName>            show a message's fields (name · type · label · #)"
  puts "  search <text>         find message/enum names containing <text>"
  puts "  field <name>          which messages carry a field named <name>"
  puts "  findtype <type>       all fields of a proto type (double, string, int64, enum, message…)"
  puts "  enum <Name>           show an enum's values"
  puts "  whereenum <Name>      which message fields use enum <Name>"
  puts "  stats                 counts"
  puts "  help / ?              this help"
  puts "  exit / quit / q       leave"
end

def dispatch(input)
  cmd, *rest = input.strip.split(/\s+/)
  arg = rest.join(" ")
  case (cmd || "").downcase
  when ""               then nil
  when "list", "ls"     then cmd_list(arg)
  when "search", "find" then arg.empty? ? puts("[!] Usage: search <text>") : cmd_search(arg)
  when "field"          then arg.empty? ? puts("[!] Usage: field <name>") : cmd_field(arg)
  when "findtype"       then arg.empty? ? puts("[!] Usage: findtype <double|string|int64|…>") : cmd_findtype(arg)
  when "enum"           then arg.empty? ? puts("[!] Usage: enum <Name>") : cmd_enum(arg)
  when "whereenum"      then arg.empty? ? puts("[!] Usage: whereenum <Name>") : cmd_whereenum(arg)
  when "stats"          then cmd_stats
  when "help", "?"      then cmd_help
  else cmd_type(input.strip)
  end
end

# ── main ────────────────────────────────────────────────────────────────────────
load_stubs

if TYPES.empty? && ENUMS.empty?
  warn "[X] No protobuf stubs found under #{PKG_DIR}"
  exit 1
end

unless ARGV.empty?
  dispatch(ARGV.join(" ")) # one-shot
  exit 0
end

puts "#{line("=")}\nMT4 PROTOBUF INSPECTOR (Ruby)\n#{line("=")}"
puts "  #{TYPES.size} message types · #{ENUMS.size} enums discovered"
puts "  Type 'help' for commands, 'list' to browse, 'exit' to quit."

loop do
  print "\n> "
  input = $stdin.gets
  break if input.nil? # EOF / piped

  t = input.strip.downcase
  break if %w[exit quit q].include?(t)

  begin
    dispatch(input)
  rescue StandardError => e
    puts "[X] #{e.message}"
  end
end
puts "\n[+] bye"
