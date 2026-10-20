Gem::Specification.new do |spec|
  spec.name          = "metarpc_mt4"
  spec.version       = "1.0.0"
  spec.authors       = ["MetaRPC"]
  spec.email         = ["info@metarpc.pro"]

  spec.summary       = "MetaTrader 4 Ruby SDK for algorithmic trading automation"
  spec.description   = "Ruby gRPC client for the MetaRPC MT4 gateway (mt4.mrpc.pro): connect, quotes, bars, tick streams, orders, history."
  spec.homepage      = "https://metarpc.github.io/RubyMT4/"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb", "package/**/*.rb", "README.md"]
  # package/ holds the generated *_pb.rb files, which require each other by bare name.
  spec.require_paths = ["lib", "package"]

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_dependency "grpc", ">= 1.60"
  spec.add_dependency "google-protobuf", ">= 4.26"
  spec.add_dependency "googleapis-common-protos-types", ">= 1.4"
end
