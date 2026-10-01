# frozen_string_literal: true

require 'faraday'
require 'json'
require 'uri'

Object.const_set('Bignum', Integer) unless Object.const_defined?('Bignum')
require 'edn'

module Chronicle
  module Transport
    class CRubyClient < Base
      attr_reader :connection, :current_basis_t

      def initialize(config = {})
        super
        @endpoint = config[:client_endpoint] || config['client_endpoint'] || 'http://localhost:8989'
        @uri = config[:uri] || config['uri']
        @rest = config[:rest] || config['rest']
        @storage_alias, @database_name = parse_datomic_uri(@uri) if @rest
        connection_options = { url: @endpoint }
        connection_options[:ssl] = { verify: false } if @endpoint.start_with?('https://') && config.fetch(:verify_ssl, false) == false
        @connection = Faraday.new(**connection_options) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end

      def connect!
        return rest_connect! if @rest

        Chronicle::Resilience.with_retry do
          response = @connection.post('/api/connect', { uri: @uri })
          raise Chronicle::ConnectionError, "Failed to connect to Datomic Client HTTP API at #{@endpoint}" unless response.success?

          true
        end
      end

      def transact(tx_data)
        return rest_transact(tx_data) if @rest

        Chronicle::Resilience.with_retry do
          payload = { uri: @uri, tx_data: }
          response = @connection.post('/api/transact', payload)
          raise Chronicle::TransactionError, "Datomic Transact Error: #{response.body}" unless response.success?

          body = response.body
          @current_basis_t = body['basis_t'] || body['db_after_t']
          { db_before: body['db_before'], db_after: body['db_after'], tx_data: body['tx_data'],
            basis_t: @current_basis_t }
        end
      end

      def q(query, *args)
        return rest_query(query, *args) if @rest

        Chronicle::Resilience.with_retry do
          payload = { uri: @uri, query:, args: }
          response = @connection.post('/api/query', payload)
          raise Chronicle::Error, "Datomic Query Error: #{response.body}" unless response.success?

          response.body['results'] || []
        end
      end

      def db(as_of: nil, since: nil)
        return { 'db/alias' => "#{@storage_alias}/#{@database_name}", 'as-of' => as_of, 'since' => since } if @rest

        { uri: @uri, as_of:, since:, basis_t: @current_basis_t }
      end

      def basis_t
        @current_basis_t || 0
      end

      private

      def parse_datomic_uri(uri)
        match = uri.to_s.match(%r{\Adatomic:([^:]+)://[^/]+/(.+)\z})
        raise ArgumentError, "Invalid Datomic URI: #{uri}" unless match

        match.captures
      end

      def rest_connect!
        Chronicle::Resilience.with_retry do
          response = @connection.post("/data/#{@storage_alias}/") do |request|
            request.headers['Content-Type'] = 'application/edn'
            request.headers['Accept'] = 'application/edn'
            request.body = edn('db-name' => @database_name)
          end
          raise Chronicle::ConnectionError, "Failed to connect to Datomic REST API at #{@endpoint}" unless response.success?

          true
        end
      end

      def rest_transact(tx_data)
        Chronicle::Resilience.with_retry do
          response = @connection.post("/data/#{@storage_alias}/#{@database_name}/") do |request|
            request.headers['Content-Type'] = 'application/edn'
            request.headers['Accept'] = 'application/edn'
            request.body = edn('tx-data' => tx_data)
          end
          raise Chronicle::TransactionError, "Datomic REST transaction failed: #{response.body}" unless response.success?

          parsed = EDN.read(response.body)
          @current_basis_t = parsed.dig('db-after', 'basis-t')
          parsed
        end
      end

      def rest_query(query, *args)
        Chronicle::Resilience.with_retry do
          response = @connection.post('/api/query') do |request|
            request.headers['Content-Type'] = 'application/edn'
            request.headers['Accept'] = 'application/edn'
            request.body = edn(q: query, args: args)
          end
          raise Chronicle::Error, "Datomic REST query failed: #{response.body}" unless response.success?

          EDN.read(response.body)
        end
      end

      def edn(value)
        case value
        when Hash
          "{#{value.map { |key, item| "#{edn_key(key)} #{edn(item)}" }.join(' ')}}"
        when Array
          "[#{value.map { |item| edn(item) }.join(' ')}]"
        when Symbol
          value.to_s.start_with?(':') ? value.to_s : ":#{value}"
        when String
          value.match?(/\A(?:\?|\$|\.\.\.)/) ? value : JSON.generate(value)
        when TrueClass, FalseClass, NilClass, Numeric
          value.to_s
        else
          JSON.generate(value.to_s)
        end
      end

      def edn_key(key)
        key_string = key.to_s
        key_string.start_with?(':') ? key_string : ":#{key_string}"
      end
    end
  end
end
