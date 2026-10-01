# frozen_string_literal: true

module Chronicle
  module Datalog
    class Optimizer
      class << self
        def optimize(compiled_query, model = nil)
          new(compiled_query, model).optimize
        end
      end

      attr_reader :query, :bindings, :find_vars, :model

      def initialize(compiled_query, model = nil)
        @query = compiled_query[:query]
        @bindings = compiled_query[:bindings]
        @find_vars = compiled_query[:find_vars]
        @model = model
      end

      def optimize
        # Extract clauses
        find_idx = query.index(:find)
        in_idx = query.index(:in)
        where_idx = query.index(:where)

        find_part = query[find_idx...in_idx]
        in_part = query[in_idx...where_idx]
        where_part = query[(where_idx + 1)..]

        # Reorder where clauses for optimal AVET/EAVT index performance
        optimized_where = reorder_where_clauses(where_part)

        # Assemble optimized query
        optimized_query = find_part + in_part + [:where] + optimized_where

        {
          query: optimized_query,
          bindings: bindings,
          find_vars: find_vars,
          optimized: true
        }
      end

      private

      def reorder_where_clauses(clauses)
        # Separate pattern triples [?e :attr ?val] from predicate expressions [[> ?var val]]
        patterns = []
        predicates = []

        clauses.each do |c|
          if c.is_a?(Array) && c.first.is_a?(Array)
            # Predicate expression like [[:>, "?var_age", 21]] or [[":!=", ...]]
            predicates << c
          elsif c.is_a?(Array) && c.length == 3 && c.first == "?e"
            patterns << c
          else
            patterns << c
          end
        end

        # Sort patterns: indexed/unique attributes first (AVET seek), then general attributes
        sorted_patterns = patterns.sort_by do |pat|
          attr_sym = pat[1]
          if unique_or_indexed_attribute?(attr_sym)
            0 # Highest priority for AVET index seek
          else
            1
          end
        end

        # Patterns executed first to narrow candidate set, then predicates filter
        sorted_patterns + predicates
      end

      def unique_or_indexed_attribute?(attr_sym)
        return false unless model && model.respond_to?(:datomic_attributes)

        attr_name = attr_sym.to_s.split("/").last&.to_sym
        return false unless attr_name

        meta = model.datomic_attributes[attr_name]
        return false unless meta

        opts = meta[:options] || {}
        opts[:unique].present? || opts[:index] == true
      end
    end
  end
end
