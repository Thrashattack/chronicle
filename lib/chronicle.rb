# frozen_string_literal: true

require "active_record"
require "active_support/all"

require_relative "chronicle/version"
require_relative "chronicle/resilience"
require_relative "chronicle/transport"
require_relative "chronicle/connection_adapters/datomic_adapter"
require_relative "chronicle/datalog/compiler"
require_relative "chronicle/datalog/optimizer"
require_relative "chronicle/relation"
require_relative "chronicle/hydrator"
require_relative "chronicle/model"
require_relative "chronicle/schema"
require_relative "chronicle/transaction_coordinator"

if defined?(Rails::Railtie)
  require_relative "chronicle/railtie"
end

module Chronicle
  class Error < StandardError; end
  class ConnectionError < Error; end
  class TransactionError < Error; end
  class SchemaError < Error; end
  class CircuitBreakerError < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def reset_configuration!
      self.configuration = Configuration.new
    end
  end

  class Configuration
    attr_accessor :uri, :client_endpoint, :secret, :pool_size,
                  :max_retries, :retry_base_delay, :retry_max_delay,
                  :circuit_breaker_threshold, :circuit_breaker_cooldown

    def initialize
      @pool_size = 5
      @max_retries = 5
      @retry_base_delay = 0.1
      @retry_max_delay = 2.0
      @circuit_breaker_threshold = 5
      @circuit_breaker_cooldown = 10.0
    end
  end
end
