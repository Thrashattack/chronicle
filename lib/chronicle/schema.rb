# frozen_string_literal: true

require_relative "schema/table_definition"

module Chronicle
  class Schema
    class << self
      def create_attribute(entity_name, attribute_name, value_type, options = {})
        ident = ":#{entity_name.to_s.underscore}/#{attribute_name}"
        cardinality = options[:cardinality] == :many ? ":db.cardinality/many" : ":db.cardinality/one"
        type_str = ":db.type/#{value_type}"

        schema_datom = {
          ":db/ident" => ident,
          ":db/valueType" => type_str,
          ":db/cardinality" => cardinality
        }

        schema_datom[":db/unique"] = ":db.unique/identity" if options[:unique] == :identity
        schema_datom[":db/doc"] = options[:doc] if options[:doc]

        schema_datom
      end

      def define(entity_name, &block)
        table_def = TableDefinition.new(entity_name)
        yield(table_def) if block_given?
        table_def.to_datoms
      end

      def drop_attribute_datom(entity_name, attribute_name, timestamp = Time.now.strftime("%Y%m%d%H%M%S"))
        old_ident = ":#{entity_name.to_s.underscore}/#{attribute_name}"
        new_ident = ":deprecated.#{entity_name.to_s.underscore}.#{timestamp}/#{attribute_name}"

        {
          ":db/id" => old_ident,
          ":db/ident" => new_ident,
          ":db/doc" => "DEPRECATED and dropped via Chronicle migration at #{timestamp}"
        }
      end

      def deprecate_attribute_datom(entity_name, attribute_name, reason: "Deprecated in migration")
        ident = ":#{entity_name.to_s.underscore}/#{attribute_name}"
        {
          ":db/id" => ident,
          ":db/doc" => "DEPRECATED: #{reason}"
        }
      end

      def rename_attribute_datom(entity_name, old_name, new_name)
        old_ident = ":#{entity_name.to_s.underscore}/#{old_name}"
        new_ident = ":#{entity_name.to_s.underscore}/#{new_name}"

        {
          ":db/id" => old_ident,
          ":db/ident" => new_ident
        }
      end
    end
  end

  module MigrationExtension
    def create_datomic_schema(entity_name, &block)
      datoms = Chronicle::Schema.define(entity_name, &block)
      transport = Chronicle::Transport.client
      transport.transact(datoms)
    end

    def drop_datomic_attribute(entity_name, attribute_name)
      datom = Chronicle::Schema.drop_attribute_datom(entity_name, attribute_name)
      transport = Chronicle::Transport.client
      transport.transact([datom])
    end

    def deprecate_datomic_attribute(entity_name, attribute_name, reason: "Deprecated")
      datom = Chronicle::Schema.deprecate_attribute_datom(entity_name, attribute_name, reason: reason)
      transport = Chronicle::Transport.client
      transport.transact([datom])
    end

    def rename_datomic_attribute(entity_name, old_name, new_name)
      datom = Chronicle::Schema.rename_attribute_datom(entity_name, old_name, new_name)
      transport = Chronicle::Transport.client
      transport.transact([datom])
    end
  end
end

if defined?(ActiveRecord::Migration)
  ActiveRecord::Migration.include(Chronicle::MigrationExtension)
end
