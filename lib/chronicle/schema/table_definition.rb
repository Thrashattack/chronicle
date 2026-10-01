# frozen_string_literal: true

module Chronicle
  class Schema
    class TableDefinition
      attr_reader :entity_name, :attributes

      TYPE_MAPPINGS = {
        string: 'string',
        integer: 'long',
        bigint: 'long',
        float: 'double',
        boolean: 'boolean',
        datetime: 'instant',
        ref: 'ref',
        uuid: 'uuid',
        bytes: 'bytes',
        uri: 'uri'
      }.freeze

      def initialize(entity_name)
        @entity_name = entity_name.to_s.singularize
        @attributes = []
      end

      def string(name, **options)
        add_attribute(name, :string, **options)
      end

      def integer(name, **options)
        add_attribute(name, :integer, **options)
      end

      def bigint(name, **options)
        add_attribute(name, :bigint, **options)
      end

      def float(name, **options)
        add_attribute(name, :float, **options)
      end

      def boolean(name, **options)
        add_attribute(name, :boolean, **options)
      end

      def datetime(name, **options)
        add_attribute(name, :datetime, **options)
      end

      def ref(name, **options)
        add_attribute(name, :ref, **options)
      end

      def uuid(name, **options)
        add_attribute(name, :uuid, **options)
      end

      def timestamps
        datetime(:created_at)
        datetime(:updated_at)
      end

      def to_datoms
        @attributes.map do |attr|
          datomic_type = TYPE_MAPPINGS[attr[:type]] || 'string'
          cardinality = attr[:options][:cardinality] == :many || attr[:options][:array] ? ':db.cardinality/many' : ':db.cardinality/one'

          datom = {
            ':db/ident' => ":#{@entity_name}/#{attr[:name]}",
            ':db/valueType' => ":db.type/#{datomic_type}",
            ':db/cardinality' => cardinality
          }

          if attr[:options][:unique] == :identity
            datom[':db/unique'] = ':db.unique/identity'
          elsif attr[:options][:unique] == :value
            datom[':db/unique'] = ':db.unique/value'
          end

          datom[':db/index'] = true if attr[:options][:index]
          datom[':db/doc'] = attr[:options][:doc] if attr[:options][:doc]
          datom
        end
      end

      private

      def add_attribute(name, type, **options)
        @attributes << { name:, type:, options: }
      end
    end
  end
end
