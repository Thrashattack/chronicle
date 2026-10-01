# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Association Preloading via Datomic Pull' do
  describe 'Compiler pull specification' do
    it 'compiles relation.includes into Datomic pull find clause' do
      rel = User.all.includes(:organization)
      compiled = Chronicle::Datalog::Compiler.compile(rel)

      expect(compiled[:pull_spec]).to eq(['*', { ':user/organization' => ['*'] }])
      expect(compiled[:query]).to include([:pull, '?e', ['*', { ':user/organization' => ['*'] }]])
    end
  end

  describe 'Hydrator nested association targets' do
    it 'hydrates nested entity maps directly into association targets' do
      raw_results = [
        {
          ':db/id' => 101,
          ':user/name' => 'Alice',
          ':user/organization' => {
            ':db/id' => 500,
            ':organization/name' => 'Acme Corp'
          }
        }
      ]

      users = Chronicle::Hydrator.hydrate(User, raw_results)
      user = users.first

      expect(user.name).to eq('Alice')
      expect(user.id).to eq(101)

      # Verify nested association instance variable / target preloading
      org = user.instance_variable_get('@organization')
      expect(org).not_to be_nil
      expect(org.name).to eq('Acme Corp')
      expect(org.id).to eq(500)
    end
  end
end
