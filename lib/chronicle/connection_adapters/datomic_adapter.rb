# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  module ConnectionAdapters
    class DatomicAdapter < AbstractAdapter
      ADAPTER_NAME = 'Datomic'

      class << self
        def quote_column_name(name)
          "\"#{name.to_s.gsub('"', '""')}\""
        end

        def quote_table_name(name)
          name.to_s.split('.').map { |part| quote_column_name(part) }.join('.')
        end
      end

      attr_reader :transport

      def initialize(config = {})
        super
        @config = config
        @transport = Chronicle::Transport.build(config)
        @transport.connect!
      end

      def adapter_name
        ADAPTER_NAME
      end

      def quote_column_name(name)
        "\"#{name.to_s.gsub('"', '""')}\""
      end

      def quote_table_name(name)
        name.to_s.split('.').map { |part| quote_column_name(part) }.join('.')
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

      def tables(_name = nil)
        datomic_models.map(&:table_name).uniq
      end

      alias data_sources tables

      def data_source_exists?(name)
        tables.include?(name.to_s)
      end

      alias table_exists? data_source_exists?

      def primary_keys(table_name)
        data_source_exists?(table_name) ? ['id'] : []
      end

      def column_definitions(table_name)
        model = ActiveRecord::Base.descendants.find { |klass| klass.table_name == table_name.to_s }
        attributes = model.respond_to?(:datomic_attributes) ? model.datomic_attributes : {}
        attributes.keys.unshift(:id).uniq.map do |name|
          type = name == :id ? :bigint : attributes.dig(name, :type)
          type = :datetime if type == :instant
          column_type = %i[integer bigint].include?(type) ? ActiveRecord::Type.lookup(:integer, limit: 8) : ActiveRecord::Type.lookup(type || :value)
          ActiveRecord::ConnectionAdapters::Column.new(name.to_s, column_type, nil)
        end
      end

      def new_column_from_field(_table_name, field, _definitions)
        return field if field.is_a?(ActiveRecord::ConnectionAdapters::Column)

        ActiveRecord::ConnectionAdapters::Column.new(field.to_s, ActiveRecord::Type::Value.new, nil)
      end

      # Executes a Datalog query or raw datom query
      def execute(query, name = nil)
        log(query.to_s, name || 'DATOMIC') do
          db_snapshot = @transport.db
          @transport.q(query, db_snapshot)
        end
      end

      # Standard Active Record exec_query interface
      def exec_query(query, name = 'DATOMIC', binds = [], prepare: false, async: false, time_travel: nil, **_options)
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
      def select_all(relation_or_query, name = nil, binds = [], prepare: false, async: false, time_travel: nil, **_options)
        if relation_or_query.respond_to?(:to_datalog)
          query_data = relation_or_query.to_datalog
          exec_query(query_data[:query], name, query_data[:bindings], time_travel:)
        elsif relation_or_query.is_a?(Hash) && relation_or_query[:query]
          exec_query(relation_or_query[:query], name, relation_or_query[:bindings] || [], time_travel:)
        else
          exec_query(relation_or_query, name, binds, time_travel:)
        end
      end

      def ensure_model_schema(model_class)
        return if !model_class.respond_to?(:datomic_attributes) || model_class.datomic_attributes.empty?

        namespace = model_class.table_name.singularize
        attributes = model_class.datomic_attributes.dup
        if model_class.respond_to?(:record_timestamps) && model_class.record_timestamps
          attributes[:created_at] ||= { type: :instant, options: {} }
          attributes[:updated_at] ||= { type: :instant, options: {} }
        end
        schema_datoms = attributes.map do |attribute, definition|
          type = datomic_type(definition[:type])
          raise Chronicle::SchemaError, "Unsupported Datomic attribute type: #{definition[:type]}" unless type

          options = definition[:options] || {}
          datom = Chronicle::Schema.create_attribute(namespace, attribute, type, options)
          datom[':db/index'] = true if options[:index]
          datom[':db/unique'] = ":db.unique/#{options[:unique]}" if %i[identity value].include?(options[:unique])
          datom.transform_values { |value| value.is_a?(String) && value.start_with?(':') ? value.to_sym : value }
        end
        @transport.transact(schema_datoms)
      end

      # Transacts new or updated entities into Datomic
      def insert(model_or_statement, attributes_or_name = nil, *args, **options)
        if model_or_statement.is_a?(Arel::InsertManager)
          statement = model_or_statement.ast
          table_name = statement.relation.name
          model_class = ActiveRecord::Base.descendants.find { |klass| klass.table_name == table_name }
          values = statement.values.expr.first
          attributes = statement.columns.zip(values).to_h do |column, value|
            normalized_value = value.respond_to?(:value) ? value.value : value
            normalized_value = nil if normalized_value.is_a?(ActiveModel::Type::Value)
            [column.name, normalized_value]
          end
          entity_id = insert_entity(model_class, attributes)
          returning = options[:returning]
          primary_key = args[0]
          return returning.map { |column| column.to_s == primary_key.to_s ? entity_id : attributes[column.to_s] } if returning

          return entity_id
        end

        insert_entity(model_or_statement, attributes_or_name)
      end

      def insert_entity(model_class, attributes)
        ensure_model_schema(model_class)
        namespace = model_class.table_name.singularize
        temp_id = attributes['id'] || attributes[:id] || 'chronicle_temp_id'

        datoms = attributes.map do |k, v|
          next if k.to_s == 'id' || v.nil?

          [:'db/add', temp_id, :":#{namespace}/#{k}", v]
        end.compact

        tx_result = @transport.transact(datoms)
        tempids = tx_result&.dig(:tempids) || tx_result&.dig('tempids') || {}
        tempids[temp_id] || tempids[temp_id.to_sym] || temp_id
      end

      # Updates existing entity attributes
      def update(model_or_statement, entity_id_or_name = nil, attributes = nil)
        if model_or_statement.is_a?(Arel::UpdateManager)
          statement = model_or_statement.ast
          table_name = statement.relation.name
          model_class = ActiveRecord::Base.descendants.find { |klass| klass.table_name == table_name }
          entity_id = statement.wheres.filter_map do |predicate|
            next unless predicate.is_a?(Arel::Nodes::Equality) && predicate.left.name.to_s == 'id'

            value = predicate.right
            value.respond_to?(:value) ? value.value : value
          end.first
          values = statement.values.to_h do |assignment|
            [assignment.left.expr.name, assignment.right.value]
          end
          update_entity(model_class, entity_id, values)
          return 1
        end

        update_entity(model_or_statement, entity_id_or_name, attributes)
      end

      def update_entity(model_class, entity_id, attributes)
        ensure_model_schema(model_class)
        namespace = model_class.table_name.singularize

        datoms = attributes.map do |k, v|
          next if k.to_s == 'id'

          [:'db/add', entity_id, :":#{namespace}/#{k}", v]
        end.compact

        @transport.transact(datoms)
      end

      # Retracts an entity entirely from current database state
      def delete(statement_or_entity_id, *_args)
        if statement_or_entity_id.is_a?(Arel::DeleteManager)
          statement = statement_or_entity_id.ast
          table_name = statement.relation.name
          model_class = ActiveRecord::Base.descendants.find { |klass| klass.table_name == table_name }
          entity_id = statement.wheres.filter_map do |predicate|
            next unless predicate.is_a?(Arel::Nodes::Equality) && predicate.left.name.to_s == 'id'

            value = predicate.right
            value.respond_to?(:value) ? value.value : value
          end.first
          return delete_entity(model_class, entity_id)
        end

        delete_entity(nil, statement_or_entity_id)
      end

      def delete_entity(_model_class, entity_id)
        datoms = [[:'db/retractEntity', entity_id]]
        @transport.transact(datoms)
        1
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

      def datomic_models
        ActiveRecord::Base.descendants.reject(&:abstract_class?)
      end

      def datomic_type(type)
        {
          string: 'string', integer: 'long', bigint: 'long', float: 'double', boolean: 'boolean',
          instant: 'instant', datetime: 'instant', ref: 'ref', uuid: 'uuid', bytes: 'bytes', uri: 'uri'
        }[type.to_sym]
      end

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
