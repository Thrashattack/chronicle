# frozen_string_literal: true

module Chronicle
  module Relation
    attr_accessor :time_travel_options

    def as_of(timestamp_or_tx)
      spawn.tap do |r|
        r.time_travel_options = (r.time_travel_options || {}).merge(as_of: timestamp_or_tx)
      end
    end

    def since(timestamp_or_tx)
      spawn.tap do |r|
        r.time_travel_options = (r.time_travel_options || {}).merge(since: timestamp_or_tx)
      end
    end

    def to_datalog
      Datalog::Compiler.compile(self)
    end

    def exec_queries
      return @records if loaded?

      # Compile Active Record relation into Datomic Datalog AST
      compiled = Datalog::Compiler.compile(self)

      # Obtain transport adapter and database snapshot
      adapter = klass.respond_to?(:chronicle_transport) ? klass.chronicle_transport : Chronicle::Transport.client
      db_snapshot = adapter.db(
        as_of: time_travel_options&.dig(:as_of),
        since: time_travel_options&.dig(:since)
      )

      # Query Datomic endpoint
      raw_results = adapter.q(compiled[:query], db_snapshot, *compiled[:bindings])

      # Map raw Datoms/tuples back into Active Record model instances using Hydrator
      @records = order_records(Hydrator.hydrate(klass, raw_results, compiled))
      @loaded = true
      @records
    end

    def size
      records.length
    end

    private

    def order_records(records)
      orderings = order_values.filter_map do |order|
        direction = order.is_a?(Arel::Nodes::Descending) ? -1 : 1
        expression = order.respond_to?(:expr) ? order.expr : order
        attribute = expression.name if expression.respond_to?(:name)
        [attribute.to_s, direction] if attribute && (attribute.to_s == 'id' || klass.datomic_attributes.key?(attribute.to_sym))
      end
      return records if orderings.empty?

      records.sort do |left, right|
        comparison = 0
        orderings.each do |attribute, direction|
          left_value = left.read_attribute(attribute)
          right_value = right.read_attribute(attribute)
          comparison = compare_order_values(left_value, right_value, direction)
          break unless comparison.zero?
        end
        comparison
      end
    end

    def compare_order_values(left, right, direction)
      return 0 if left.nil? && right.nil?
      return (left.nil? ? -1 : 1) * direction if left.nil? || right.nil?

      (left <=> right || 0) * direction
    end
  end
end
