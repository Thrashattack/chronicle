# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  module ConnectionAdapters
    class DatomicAdapter < AbstractAdapter
      ADAPTER_NAME = 'Datomic'

      attr_reader :transport

      def initialize(config = {})
        super(config)
        @config = config
        @transport = Chronicle::Transport.build(config)
        @transport.connect!
      end

      def adapter_name
        ADAPTER_NAME
      end

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_ddl_transactions?
        false
      end

      # Executes a Datalog query or raw datom query
      def execute(query, name = nil)
        log(query.to_s, name || 'DATOMIC') do
          db_snapshot = @transport.db
          @transport.q(query, db_snapshot)
        end
      end

      # Standard Active Record exec_query interface
      def exec_query(query, name = 'DATOMIC', binds = [], prepare: false, async: false, time_travel: nil)
        log(query.to_s, name) do
          db_snapshot = @transport.db(
            as_of: time_travel&.dig(:as_of),
            since: time_travel&.dig(:since)
          )

          raw_results = @transport.q(query, db_snapshot, *binds)
          format_results(raw_results)
        end
      end

      # High-level query interface returning ActiveRecord::Result
      def select_all(relation_or_query, name = nil, binds = [], prepare: false, async: false, time_travel: nil)
        if relation_or_query.respond_to?(:to_datalog)
          query_data = relation_or_query.to_datalog
          exec_query(query_data[:query], name, query_data[:bindings], time_travel:)
        elsif relation_or_query.is_a?(Hash) && relation_or_query[:query]
          exec_query(relation_or_query[:query], name, relation_or_query[:bindings] || [], time_travel:)
        else
          exec_query(relation_or_query, name, binds, time_travel:)
        end
      end

      # Transacts new or updated entities into Datomic
      def insert(model_class, attributes)
        namespace = model_class.table_name.singularize
        temp_id = attributes['id'] || attributes[:id] || ':temp_id_1'

        datoms = attributes.map do |k, v|
          next if k.to_s == 'id' || v.nil?

          [':db/add', temp_id, ":#{namespace}/#{k}".to_sym, v]
        end.compact

        tx_result = @transport.transact(datoms)
        tx_result&.dig(:tempids, temp_id) || temp_id
      end

      # Updates existing entity attributes
      def update(model_class, entity_id, attributes)
        namespace = model_class.table_name.singularize

        datoms = attributes.map do |k, v|
          next if k.to_s == 'id'

          [':db/add', entity_id, ":#{namespace}/#{k}".to_sym, v]
        end.compact

        @transport.transact(datoms)
      end

      # Retracts an entity entirely from current database state
      def delete(entity_id)
        datoms = [[':db/retractEntity', entity_id]]
        @transport.transact(datoms)
      end

      def active?
        @transport.connected?
      end

      def reconnect!
        @transport.connect!
      end

      def disconnect!
        @transport.disconnect!
      end

      private

      def format_results(raw_results)
        return ActiveRecord::Result.new([], []) if raw_results.blank?

        if raw_results.first.is_a?(Array)
          cols = (0...raw_results.first.size).map { |i| "col_#{i}" }
          ActiveRecord::Result.new(cols, raw_results)
        elsif raw_results.first.is_a?(Hash)
          cols = raw_results.first.keys.map(&:to_s)
          rows = raw_results.map(&:values)
          ActiveRecord::Result.new(cols, rows)
        else
          ActiveRecord::Result.new(['value'], raw_results.map { |v| [v] })
        end
      end
    end
  end
end

# Register adapter with ActiveRecord
if defined?(ActiveRecord::ConnectionAdapters) && ActiveRecord::ConnectionAdapters.respond_to?(:register)
  ActiveRecord::ConnectionAdapters.register('datomic', 'ActiveRecord::ConnectionAdapters::DatomicAdapter',
                                            'chronicle/connection_adapters/datomic_adapter')
end
