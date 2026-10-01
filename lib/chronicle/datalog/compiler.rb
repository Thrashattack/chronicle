# frozen_string_literal: true

module Chronicle
  module Datalog
    class Compiler
      attr_reader :relation, :model

      def self.compile(relation)
        new(relation).compile
      end

      def initialize(relation)
        @relation = relation
        @model = relation.klass
        @find_clause = [:find, '?e']
        @in_clause = [:in, '$']
        @where_clause = []
        @bindings = []
        @var_counter = 0
      end

      def compile
        namespace = model.table_name.singularize

        # 1. Process custom select / projections if specified
        process_projections(namespace)

        # 2. Process includes / eager_load for preloading associations via Datomic pull
        process_includes(namespace)

        # 3. Process predicates in relation
        process_where_clause(namespace)

        # 4. Assemble Datalog data structure
        datalog_query = @find_clause + @in_clause + [:where] + @where_clause

        {
          query: datalog_query,
          bindings: @bindings,
          find_vars: @find_clause[1..],
          pull_spec: @pull_spec
        }
      end

      private

      def process_includes(namespace)
        includes_list = []
        includes_list += relation.includes_values if relation.respond_to?(:includes_values) && relation.includes_values.present?
        includes_list += relation.eager_load_values if relation.respond_to?(:eager_load_values) && relation.eager_load_values.present?

        return if includes_list.blank?

        @pull_spec = build_pull_spec(includes_list, namespace)
        @find_clause = [:find, [:pull, '?e', @pull_spec]]
      end

      def build_pull_spec(includes_list, namespace)
        spec = ['*']
        includes_list.flatten.compact.each do |item|
          case item
          when Symbol, String
            ident = ":#{namespace}/#{item}"
            spec << { ident => ['*'] }
          when Hash
            item.each do |parent_key, child_item|
              parent_ident = ":#{namespace}/#{parent_key}"
              child_ns = parent_key.to_s.singularize
              child_spec = build_pull_spec([child_item], child_ns)
              spec << { parent_ident => child_spec }
            end
          end
        end
        spec
      end

      def process_projections(namespace)
        select_values = relation.select_values if relation.respond_to?(:select_values)
        return unless select_values.present? && select_values.none? { |s| s.to_s == '*' }

        find_vars = select_values.map do |col|
          col_name = col.is_a?(Arel::Nodes::Node) ? col.name : col.to_s
          var_name = "?#{col_name}"
          # Add attribute pattern to retrieve attribute value
          @where_clause << ['?e', ":#{namespace}/#{col_name}".to_sym, var_name]
          var_name
        end
        @find_clause = [:find] + find_vars
      end

      def process_where_clause(namespace)
        where_predicates = extract_predicates

        where_predicates.each do |pred|
          process_predicate(pred, namespace)
        end
      end

      def extract_predicates
        if relation.respond_to?(:where_clause)
          relation.where_clause.send(:predicates)
        else
          []
        end
      end

      def process_predicate(pred, namespace)
        case pred
        when Arel::Nodes::Equality
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          param_var = "?param_#{next_var_id}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, param_var]
          @in_clause << param_var
          @bindings << val

        when Arel::Nodes::GreaterThan
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          var_name = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, var_name]
          @where_clause << [[:>, var_name, val]]

        when Arel::Nodes::GreaterThanOrEqual
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          var_name = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, var_name]
          @where_clause << [[:>=, var_name, val]]

        when Arel::Nodes::LessThan
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          var_name = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, var_name]
          @where_clause << [[:<, var_name, val]]

        when Arel::Nodes::LessThanOrEqual
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          var_name = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, var_name]
          @where_clause << [[:<=, var_name, val]]

        when Arel::Nodes::NotEqual
          attr_name = pred.left.name
          val = unwrap_value(pred.right)
          param_var = "?param_#{next_var_id}"
          var_name = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, var_name]
          @where_clause << [[:!=, var_name, param_var]]
          @in_clause << param_var
          @bindings << val

        when Arel::Nodes::In
          attr_name = pred.left.name
          values = unwrap_value(pred.right).map { |v| unwrap_value(v) }
          param_var = "?in_vec_#{next_var_id}"
          val_var = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, val_var]
          @where_clause << [val_var, param_var]
          @in_clause << [param_var, '...']
          @bindings << values

        when Arel::Nodes::HomogeneousIn
          attr_name = pred.attribute.name
          values = pred.values.map { |value| unwrap_value(value) }
          param_var = "?in_vec_#{next_var_id}"
          val_var = "?var_#{attr_name}"

          @where_clause << ['?e', ":#{namespace}/#{attr_name}".to_sym, val_var]
          @where_clause << [val_var, param_var]
          @in_clause << [param_var, '...']
          @bindings << values

        when String
          @where_clause << pred
        end
      end

      def unwrap_value(val)
        if val.respond_to?(:value)
          val.value
        else
          val
        end
      end

      def next_var_id
        @var_counter += 1
      end
    end
  end
end
