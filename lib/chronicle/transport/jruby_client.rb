# frozen_string_literal: true

module Chronicle
  module Transport
    class JRubyClient < Base
      attr_reader :connection, :current_basis_t

      def initialize(config = {})
        super
        @endpoint = config[:client_endpoint] || config['client_endpoint'] || 'localhost:8998'
        @access_key = config[:access_key] || config['access_key'] || 'chronicle-dev'
        @secret = config[:secret] || config['secret'] || 'chronicle-dev-secret'
        @db_name = config[:db_name] || config['db_name'] || datomic_db_name(config[:uri] || config['uri'])
        @api = nil
      end

      def connect!
        Chronicle::Resilience.with_retry do
          @client = api.client(
            'server-type' => :peer_server,
            'access-key' => @access_key,
            'secret' => @secret,
            'endpoint' => @endpoint,
            'validate-hostnames' => false
          )
          @connection = api.connect(@client, 'db-name' => @db_name)
          @connected = true
        end
      end

      def transact(tx_data)
        Chronicle::Resilience.with_retry do
          result = api.transact(@connection, 'tx-data' => tx_data)
          @current_basis_t = result['db-after']['basis-t'] || result[:'db-after'][:'basis-t']
          result
        end
      end

      def q(query, *args)
        Chronicle::Resilience.with_retry do
          api.q('query' => query, 'args' => [api.db(@connection), *args])
        end
      end

      def db(as_of: nil, since: nil)
        database = api.db(@connection)
        database = api.as_of(database, as_of) if as_of
        database = api.since(database, since) if since
        database
      end

      def basis_t
        @current_basis_t || api.db(@connection)['t'] || 0
      end

      private

      def api
        @api ||= ClojureApi.new
      end

      def datomic_db_name(uri)
        uri.to_s.split('/').last
      end

      class ClojureApi
        def initialize
          raise Chronicle::Error, 'JRubyClient requires JRuby' unless Chronicle::Transport.jruby?

          load_datomic_jars
          @clojure = Java::ClojureJavaApi::Clojure
          @clojure.var('clojure.core', 'require').invoke(
            @clojure.var('clojure.core', 'symbol').invoke('datomic.client.api')
          )
        end

        def client(config)
          invoke('client', clojure_map(config))
        end

        def connect(client, config)
          invoke('connect', client, clojure_map(config))
        end

        def transact(connection, config)
          ruby_value(invoke('transact', connection, clojure_map(config)))
        end

        def q(config)
          ruby_value(invoke('q', clojure_map(config)))
        end

        def db(connection)
          invoke('db', connection)
        end

        def as_of(database, value)
          invoke('as-of', database, value)
        end

        def since(database, value)
          invoke('since', database, value)
        end

        private

        def load_datomic_jars
          datomic_home = ENV['DATOMIC_HOME'] || '/opt/datomic'
          Dir[File.join(datomic_home, 'lib', '*.jar')].each { |jar| require jar }
        end

        def invoke(function, *)
          var('datomic.client.api', function).invoke(*)
        end

        def var(namespace, function)
          @clojure.var(namespace, function)
        end

        def keyword(value)
          var('clojure.core', 'keyword').invoke(value.to_s.tr('_', '-'))
        end

        def clojure_map(hash)
          entries = hash.flat_map { |key, value| [keyword(key), clojure_value(value)] }
          var('clojure.core', 'hash-map').invoke(*entries)
        end

        def clojure_value(value)
          case value
          when Hash
            clojure_map(value)
          when Array
            Java::ClojureLang::PersistentVector.create(value.map { |item| clojure_value(item) })
          when Symbol
            symbol_name = value.to_s
            return keyword(symbol_name.delete_prefix(':')) if symbol_name.start_with?(':')
            return var('clojure.core', 'symbol').invoke(symbol_name) if symbol_name.start_with?('?', '$')
            return var('clojure.core', 'symbol').invoke(symbol_name) if %w[> >= < <= !=].include?(symbol_name)

            keyword(symbol_name)
          when String
            return var('clojure.core', 'symbol').invoke(value) if value.start_with?('?', '$')
            return keyword(value.delete_prefix(':')) if value.start_with?(':')

            value
          else
            value
          end
        end

        def ruby_value(value)
          return value.map { |item| ruby_value(item) } if value.respond_to?(:to_a) && !value.respond_to?(:key?)
          if value.respond_to?(:each_pair)
            return value.each_with_object({}) do |(key, item), result|
              result[key.to_s.delete_prefix(':')] = ruby_value(item)
            end
          end

          value
        end
      end
    end
  end
end
