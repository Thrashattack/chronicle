# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chronicle::Datalog::Compiler do
  let(:relation) { User.all }

  describe '.compile' do
    context 'with simple equality conditions' do
      it 'compiles single attribute equality into a Datalog query and bindings' do
        rel = User.where(name: 'Alice')
        result = described_class.compile(rel)

        expect(result[:query]).to include(:find, '?e', :in, '$', '?param_1', :where)
        expect(result[:query]).to include(['?e', :':user/name', '?param_1'])
        expect(result[:bindings]).to eq(['Alice'])
      end

      it 'compiles multiple attribute equality conditions' do
        rel = User.where(name: 'Alice', active: true)
        result = described_class.compile(rel)

        expect(result[:query]).to include(['?e', :':user/name', '?param_1'])
        expect(result[:query]).to include(['?e', :':user/active', '?param_2'])
        expect(result[:bindings]).to eq(['Alice', true])
      end
    end

    context 'with comparison operators (greater than, less than)' do
      it 'compiles greater_than predicates into Datalog comparison expressions' do
        rel = User.where(User.arel_table[:age].gt(21))
        result = described_class.compile(rel)

        expect(result[:query]).to include(['?e', :':user/age', '?var_age'])
        expect(result[:query]).to include([[:>, '?var_age', 21]])
      end

      it 'compiles less_than_or_equal predicates' do
        rel = User.where(User.arel_table[:age].lteq(65))
        result = described_class.compile(rel)

        expect(result[:query]).to include(['?e', :':user/age', '?var_age'])
        expect(result[:query]).to include([[:<=, '?var_age', 65]])
      end
    end

    context 'with IN collection predicates' do
      it 'compiles IN predicates into vector bindings' do
        rel = User.where(name: %w[Alice Bob])
        result = described_class.compile(rel)

        expect(result[:query]).to include(['?in_vec_1', '...'])
        expect(result[:bindings]).to eq([%w[Alice Bob]])
      end
    end

    context 'with custom projections (.select)' do
      it 'adjusts :find clause and adds attribute patterns' do
        rel = User.select(:name, :email).where(active: true)
        result = described_class.compile(rel)

        expect(result[:find_vars]).to eq(['?name', '?email'])
        expect(result[:query]).to include(:find, '?name', '?email')
        expect(result[:query]).to include(['?e', :':user/name', '?name'])
        expect(result[:query]).to include(['?e', :':user/email', '?email'])
      end
    end

    context 'with time-travel options (as_of / since)' do
      it 'preserves time-travel options on the relation for execution' do
        time = Time.now
        rel = User.as_of(time).where(active: true)
        expect(rel.time_travel_options[:as_of]).to eq(time)

        compiled = described_class.compile(rel)
        expect(compiled[:query]).to include(['?e', :':user/active', '?param_1'])
      end
    end
  end
end
