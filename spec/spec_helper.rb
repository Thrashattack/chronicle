# frozen_string_literal: true

require 'simplecov'
require 'active_chronicle'
require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.integer :age
    t.boolean :active, default: true
    t.integer :organization_id
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.integer :user_id
    t.string :title
    t.text :body
    t.timestamps
  end

  create_table :audit_logs, force: true do |t|
    t.string :action
    t.integer :datomic_basis_t
    t.string :user_email
    t.timestamps
  end

  create_table :historical_records, force: true do |t|
    t.string :event_name
    t.integer :user_id
    t.string :payload
    t.timestamps
  end

  create_table :articles, force: true do |t|
    t.string :title
    t.string :payload
    t.integer :view_count
    t.timestamps
  end

  create_table :organizations, force: true do |t|
    t.string :name
    t.timestamps
  end
end

class User < ActiveRecord::Base
  self.table_name = 'users'
  include Chronicle::Model

  datomic_attribute :name, :string
  datomic_attribute :age, :integer
  datomic_attribute :email, :string
  datomic_attribute :organization_id, :integer
  belongs_to :organization, optional: true
end

class Organization < ActiveRecord::Base
  self.table_name = 'organizations'
  include Chronicle::Model

  datomic_attribute :name, :string
  has_many :users
end

class Article < ActiveRecord::Base
  self.table_name = 'articles'
  include Chronicle::Model

  datomic_attribute :title, :string
  datomic_attribute :payload, :string
  datomic_attribute :view_count, :integer
end

class HistoricalRecord < ActiveRecord::Base
  self.table_name = 'historical_records'
  include Chronicle::Model

  datomic_attribute :event_name, :string
  datomic_attribute :user_id, :integer
  datomic_attribute :payload, :string
end

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  track_files 'lib/**/*.rb'
end

RSpec.configure do |config|
  config.before(:each) do
    Chronicle::Resilience.reset_circuit_breaker!
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
end
