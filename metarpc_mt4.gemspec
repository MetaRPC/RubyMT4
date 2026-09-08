Gem::Specification.new do |spec|
  spec.name          = "metarpc_mt4"
  spec.version       = "1.0.0"
  spec.authors       = ["MetaRPC"]
  spec.email         = ["info@metarpc.pro"]

  spec.summary       = "MetaTrader 4 Ruby SDK for algorithmic trading automation"
  spec.description   = "Pure Ruby client for connecting directly to MetaTrader 4 servers without desktop terminal."
  spec.homepage      = "https://metarpc.github.io/RubyMT4/"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7.0"
end
