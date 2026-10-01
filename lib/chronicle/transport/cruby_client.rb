# frozen_string_literal: true

require 'faraday'
require 'json'

module Chronicle
  module Transport
    class CRubyClient < Base
      attr_reader :connection, :current_basis_t

      def initialize(config = {})
        super
        @endpoint = config[:client_endpoint] || config['client_endpoint'] || 'http://localhost:8989'
        @uri = config[:uri] || config['uri']
        @connection = Faraday.new(url: @endpoint) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end

      def connect!
        Chronicle::Resilience.with_retry do
          response = @connection.post('/api/connect', { uri: @uri })
          raise Chronicle::ConnectionError, "Failed to connect to Datomic Client HTTP API at #{@endpoint}" unless response.success?

          true
        end
      end

      def transact(tx_data)
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
        Chronicle::Resilience.with_retry do
          payload = { uri: @uri, query:, args: }
          response = @connection.post('/api/query', payload)
          raise Chronicle::Error, "Datomic Query Error: #{response.body}" unless response.success?

          response.body['results'] || []
        end
      end

      def db(as_of: nil, since: nil)
        { uri: @uri, as_of:, since:, basis_t: @current_basis_t }
      end

      def basis_t
        @current_basis_t || 0
      end
    end
  end
end
