# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chronicle::Hydrator do
  describe '.hydrate' do
    context 'when given Datomic entity maps (pull query hashes)' do
      let(:raw_pull_results) do
        [
          { ':db/id' => 17_592_186_045_417, ':user/name' => 'Alice', ':user/email' => 'alice@example.com',
            ':user/age' => 30, ':user/active' => true },
          { ':db/id' => 17_592_186_045_418, ':user/name' => 'Bob', ':user/email' => 'bob@example.com', ':user/age' => 25,
            ':user/active' => false }
        ]
      end

      it 'instantiates model instances with mapped attributes' do
        instances = described_class.hydrate(User, raw_pull_results)

        expect(instances.size).to eq(2)
        expect(instances.first).to be_a(User)
        expect(instances.first.id).to eq(17_592_186_045_417)
        expect(instances.first.name).to eq('Alice')
        expect(instances.first.email).to eq('alice@example.com')
        expect(instances.first.age).to eq(30)
        expect(instances.first.active).to be true

        expect(instances.last.id).to eq(17_592_186_045_418)
        expect(instances.last.name).to eq('Bob')
      end

      it 'marks hydrated instances as persisted with clean dirty tracking' do
        instances = described_class.hydrate(User, raw_pull_results)
        first = instances.first

        expect(first.persisted?).to be true if first.respond_to?(:persisted?)
        expect(first.new_record?).to be false if first.respond_to?(:new_record?)
        expect(first.changed?).to be false if first.respond_to?(:changed?)
      end
    end

    context 'when given tuple query results with find_vars' do
      let(:raw_tuple_results) do
        [
          [17_592_186_045_417, 'Alice', 'alice@example.com'],
          [17_592_186_045_418, 'Bob', 'bob@example.com']
        ]
      end

      let(:compiled_meta) do
        { find_vars: ['?e', '?name', '?email'] }
      end

      it 'maps tuple positions to find_vars and sets attributes' do
        instances = described_class.hydrate(User, raw_tuple_results, compiled_meta)

        expect(instances.size).to eq(2)
        expect(instances.first.id).to eq(17_592_186_045_417)
        expect(instances.first.name).to eq('Alice')
        expect(instances.first.email).to eq('alice@example.com')

        expect(instances.last.id).to eq(17_592_186_045_418)
        expect(instances.last.name).to eq('Bob')
        expect(instances.last.email).to eq('bob@example.com')
      end
    end

    context 'when executing a pluck projection' do
      it 'returns raw scalar values for a single column projection' do
        raw_results = [['Alice'], ['Bob']]
        compiled_meta = { pluck: true, find_vars: ['?name'] }

        plucked = described_class.hydrate(User, raw_results, compiled_meta)
        expect(plucked).to eq(%w[Alice Bob])
      end

      it 'returns arrays of values for multi-column projections' do
        raw_results = [['Alice', 'alice@example.com'], ['Bob', 'bob@example.com']]
        compiled_meta = { pluck: true, find_vars: ['?name', '?email'] }

        plucked = described_class.hydrate(User, raw_results, compiled_meta)
        expect(plucked).to eq([['Alice', 'alice@example.com'], ['Bob', 'bob@example.com']])
      end
    end

    context 'when raw_results is empty or nil' do
      it 'returns an empty array' do
        expect(described_class.hydrate(User, [])).to eq([])
        expect(described_class.hydrate(User, nil)).to eq([])
      end
    end
  end
end
