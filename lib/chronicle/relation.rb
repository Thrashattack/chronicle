# frozen_string_literal: true

module Chronicle
  class Relation < ActiveRecord::Relation
    attr_accessor :time_travel_options

    def initialize(klass, table: klass.table_name, predicate_builder: klass.predicate_builder, values: {})
      super
      @time_travel_options = {}
    end

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
        as_of: time_travel_options[:as_of],
        since: time_travel_options[:since]
      )

      # Query Datomic endpoint
      raw_results = adapter.q(compiled[:query], db_snapshot, *compiled[:bindings])

      # Map raw Datoms/tuples back into Active Record model instances using Hydrator
      @records = Hydrator.hydrate(klass, raw_results, compiled)
      @loaded = true
      @records
    end
  end
end
