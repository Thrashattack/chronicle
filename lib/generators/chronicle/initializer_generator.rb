# frozen_string_literal: true

require "rails/generators"

module Chronicle
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer_file
        create_file "config/initializers/chronicle.rb", <<~RUBY
          # frozen_string_literal: true

          # Chronicle Active Record Datomic Extension Configuration
          Chronicle.configure do |config|
            # Datomic database connection URI
            config.uri = ENV.fetch("DATOMIC_URI", "datomic:dev://localhost:4334/chronicle_development")

            # CRuby Transport Options (Datomic Client HTTP API)
            if RUBY_ENGINE != "jruby"
              config.client_endpoint = ENV.fetch("DATOMIC_CLIENT_ENDPOINT", "http://localhost:8989")
              config.secret = ENV.fetch("DATOMIC_CLIENT_SECRET", nil)
            end

            # Connection Pool Size
            config.pool_size = ENV.fetch("DATOMIC_POOL_SIZE", 5).to_i
          end
        RUBY
      end
    end
  end
end
