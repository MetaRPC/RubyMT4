require_relative "metarpc_mt4/version"
require_relative "metarpc_mt4/errors"
require_relative "metarpc_mt4/subscription"
require_relative "metarpc_mt4/mt4_account"
require_relative "metarpc_mt4/mt4_service"
require_relative "metarpc_mt4/mt4_sugar"

module MetaRPC
  # Three-layer Ruby SDK for the MetaRPC MetaTrader 4 gateway (mt4.mrpc.pro):
  #
  #   MT4Account  - low-level, 1:1 gRPC (raw protobuf in/out)
  #   MT4Service  - mid-level, typed Ruby objects and plain arguments
  #   MT4Sugar    - high-level, one-line helpers with smart defaults
  #
  # `Client` aliases MT4Sugar (the friendly entry point); `Account` aliases MT4Account.
  module MT4
  end
end
