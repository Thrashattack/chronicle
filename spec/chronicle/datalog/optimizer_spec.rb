# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle::Datalog::Optimizer do
  let(:dummy_model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      include Chronicle::Model

      datomic_attribute :name, :string
      datomic_attribute :email, :string, unique: :identity
      datomic_attribute :age, :integer
    end
  end

  describe ".optimize" do
    it "reorders high-selectivity indexed/unique attributes to top of :where clause" do
      # Relation where age > 21 is added first, email (unique) second
      rel = dummy_model.where(dummy_model.arel_table[:age].gt(21)).where(email: "alice@example.com")
      compiled = Chronicle::Datalog::Compiler.compile(rel)

      optimized = described_class.optimize(compiled, dummy_model)
      where_clause = optimized[:query][optimized[:query].index(:where) + 1..]

      # Unique attribute :user/email should appear before the greater_than predicate expression
      email_pattern_idx = where_clause.index { |pat| pat.is_a?(Array) && pat[1] == :":user/email" }
      gt_pred_idx = where_clause.index { |pat| pat.is_a?(Array) && pat.first.is_a?(Array) && pat.first.first == :> }

      expect(email_pattern_idx).to be < gt_pred_idx
    end

    it "places scalar predicate expressions after basic triple patterns" do
      compiled_query = {
        query: [:find, "?e", :in, "$", "?param_1", :where, [[:>, "?var_age", 21]], ["?e", :":user/name", "?param_1"]],
        bindings: ["Alice"],
        find_vars: ["?e"]
      }

      optimized = described_class.optimize(compiled_query, dummy_model)
      where_clause = optimized[:query][optimized[:query].index(:where) + 1..]

      # Triple pattern should precede function predicate
      expect(where_clause.first).to eq(["?e", :":user/name", "?param_1"])
      expect(where_clause.last).to eq([[:>, "?var_age", 21]])
    end
  end
end
