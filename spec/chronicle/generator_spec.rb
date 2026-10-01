# frozen_string_literal: true

require 'spec_helper'
require 'generators/chronicle/migration_generator'

RSpec.describe Chronicle::Generators::MigrationGenerator do
  describe '#entity_name' do
    it 'derives singular entity name from migration file name' do
      generator = described_class.new(['create_users'])
      expect(generator.send(:entity_name)).to eq('user')
    end
  end

  describe '#parse_attribute' do
    it 'parses field:type:option syntax' do
      generator = described_class.new(['create_users'])
      parsed = generator.send(:parse_attribute, 'email:string:uniq')

      expect(parsed[:name]).to eq('email')
      expect(parsed[:type]).to eq('string')
      expect(parsed[:options][:unique]).to eq(:identity)
    end
  end
end
