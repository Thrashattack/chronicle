# Chronicle

Chronicle connects the Datomic database to Ruby on Rails Active Record. It works with both CRuby and JRuby.

## Features

- **Active Record Integration**: Maps Active Record models, attributes, and associations to Datomic facts (`datoms`).
- **Runtime Transport Auto-Detection**: Uses Java Peer interop on JRuby and the HTTP Client API on CRuby.
- **Time-Travel Queries**: Queries past database states using `.as_of` and `.since`.
- **Cross-Database Transactions**: Coordinates transactions across Datomic and PostgreSQL with automatic compensating retractions.
- **Resilience & Circuit Breaker**: Retries failed calls with non-blocking Fiber delays and stops cascading failures with a circuit breaker.
- **Rails Tooling**: Includes migration and initializer generators.

## Installation

Add this line to your `Gemfile`:

```ruby
gem "chronicle", github: "Thrashattack/chronicle"
```

Then run:

```bash
bundle install
```

## Setup

### 1. Database Configuration (`config/database.yml`)

```yaml
development:
  primary:
    adapter: postgresql
    database: app_development
  datomic:
    adapter: datomic
    uri: datomic:dev://localhost:4334/chronicle_dev
    client_endpoint: http://localhost:8989
```

### 2. Initializer Generator

Run the initializer generator:

```bash
rails generate chronicle:initializer
```

This creates `config/initializers/chronicle.rb`:

```ruby
Chronicle.configure do |config|
  config.uri = ENV.fetch("DATOMIC_URI", "datomic:dev://localhost:4334/app_dev")
  
  if RUBY_ENGINE != "jruby"
    config.client_endpoint = ENV.fetch("DATOMIC_CLIENT_ENDPOINT", "http://localhost:8989")
  end

  config.max_retries = 5
end
```

### 3. Model Definition

```ruby
class HistoricalRecord < ActiveRecord::Base
  include Chronicle::Model

  connects_to database: { writing: :datomic, reading: :datomic }

  datomic_attribute :event_name, :string
  datomic_attribute :user_id, :integer, index: true
  datomic_attribute :payload, :string
end
```

## Migrations

Generate a migration file:

```bash
rails generate chronicle:migration create_historical_records event_name:string user_id:integer:index
```

This creates a migration file:

```ruby
class CreateHistoricalRecords < ActiveRecord::Migration[8.0]
  def change
    create_datomic_schema :historical_record do |t|
      t.string  :event_name
      t.integer :user_id, index: true
      t.timestamps
    end
  end
end
```

Run migrations:

```bash
bin/rails db:migrate
```

## Time-Travel Queries

Datomic stores facts immutably. Query historical states using `as_of` and `since`:

```ruby
# Query data as it existed 2 hours ago
past_record = HistoricalRecord.as_of(2.hours.ago).find_by(user_id: 42)

# Query data recorded since a transaction ID
new_records = HistoricalRecord.since(10040).where(event_name: "login")
```

## Cross-Database Transactions

Use `Chronicle::TransactionCoordinator` to write across Datomic and PostgreSQL in one step:

```ruby
Chronicle::TransactionCoordinator.transaction do |tx|
  # 1. Write fact to Datomic
  tx.datomic(record.to_datoms)

  # 2. Write pointer to PostgreSQL
  tx.postgres do
    AuditLog.create!(
      user_id: 42,
      datomic_basis_t: tx.basis_t
    )
  end
end
```

If the PostgreSQL write fails, Chronicle retracts the Datomic write automatically and raises an error.

## Running Tests

Run the RSpec test suite:

```bash
bundle exec rspec
```

## License

Chronicle is available as open source under the terms of the MIT License.
