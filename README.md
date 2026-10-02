# Chronicle

[![CI](https://github.com/Thrashattack/chronicle/actions/workflows/ci.yml/badge.svg)](https://github.com/Thrashattack/chronicle/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/Thrashattack/chronicle/branch/main/graph/badge.svg)](https://codecov.io/gh/Thrashattack/chronicle)
[![Gem Version](https://img.shields.io/gem/v/chronicle.svg)](https://rubygems.org/gems/chronicle)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.4.5-CC342D.svg)](https://www.ruby-lang.org/)

Chronicle connects Datomic to Ruby on Rails Active Record. It maps Active Record models to Datomic facts and exposes immutable history through normal Rails query patterns.

## Requirements

- Ruby 3.4.5 or newer.
- Rails Active Record 7.0 or newer.
- Datomic Pro for the Docker examples and JRuby integrations.
- Java 17 for the Datomic container.
- Java 21 for JRuby 10 workloads.

## Capabilities

- Active Record integration through `Chronicle::Model`.
- Datomic attributes with types and schema options.
- Datalog compilation for equality, comparison, `IN`, projection, and pull queries.
- Association preloading through Datomic pull results.
- Time travel with `.as_of` and `.since`.
- Datomic schema and migration helpers.
- Cross-database transactions with compensating Datomic retractions.
- Retry handling with exponential backoff and jitter.
- Circuit breaker support.
- Fiber-aware backoff when a Ruby scheduler is active.
- CRuby transport through Datomic REST using EDN.
- JRuby Client API transport through a Datomic peer server.
- JRuby Peer API transport with direct access to the Datomic transactor.
- Rails initializer and migration generators.

## Installation

Add Active Chronicle to the application Gemfile:

```ruby
gem "active-chronicle"
```

Then install the bundle:

```bash
bundle install
```

## Configuration

Generate an initializer:

```bash
bin/rails generate chronicle:initializer
```

Configure a Datomic connection in `config/database.yml`.

### CRuby and REST

Chronicle's CRuby transport uses Datomic's REST service. Datomic marks REST as a legacy interface, but it remains useful for existing integrations and supports the Ruby transport.

```yaml
datomic:
  adapter: datomic
  uri: datomic:dev://localhost:4334/app_dev
  client_endpoint: https://localhost:8001
  rest: true
```

### JRuby Client API

The Client API connects to a Datomic peer server. It requires the peer-server endpoint, access key, secret, and database name.

```yaml
datomic:
  adapter: datomic
  uri: datomic:dev://localhost:4334/app_dev
  client_endpoint: localhost:8998
  access_key: chronicle-dev
  secret: chronicle-dev-secret
```

### JRuby Peer API

The Peer API connects directly to the transactor. Select it with `transport: peer`.

```yaml
datomic:
  adapter: datomic
  uri: datomic:dev://localhost:4334/app_dev
  transport: peer
```

The included Compose examples mount the Datomic distribution at `/opt/datomic`.
Chronicle loads `peer-*.jar` from the distribution root and its dependencies from
`lib/*.jar`. Set `DATOMIC_HOME` when the distribution is installed elsewhere.
The Peer jar is not inside `lib`: for Datomic Pro 1.0.7705 it is
`/opt/datomic/peer-1.0.7705.jar`, corresponding to Maven artifact
`com.datomic:peer:1.0.7705`. Alternatively, resolve that artifact and its runtime
dependencies onto the application JVM classpath. Startup raises an error if
`datomic.Peer` cannot be resolved or `Peer.connect` returns no connection.

## Model Integration

Include `Chronicle::Model` and declare the attributes stored in Datomic:

```ruby
class DatomicRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :datomic, reading: :datomic }
end

class HistoricalRecord < DatomicRecord
  include Chronicle::Model

  datomic_attribute :event_name, :string
  datomic_attribute :user_id, :integer, index: true
  datomic_attribute :payload, :string
end
```

`connects_to` must be declared on an abstract Active Record class. Rails 8 rejects it on a concrete model. Keep SQLite-backed models on `ApplicationRecord` and inherit Datomic-backed models from the abstract Datomic base.

`Chronicle::Model` also provides `to_datoms`, `datomic_entity_id`, and model-level `.as_of` and `.since` query entry points.

## Schema and Migrations

Generate a Datomic migration:

```bash
bin/rails generate chronicle:migration create_historical_records \
  event_name:string user_id:integer:index
```

A generated migration uses the Chronicle table definition:

```ruby
class CreateHistoricalRecords < ActiveRecord::Migration[8.1]
  def change
    create_datomic_schema :historical_record do |table|
      table.string :event_name
      table.integer :user_id, index: true
      table.timestamps
    end
  end
end
```

Run it with:

```bash
bin/rails db:migrate
```

## Time Travel

Datomic never overwrites a fact. Each transaction produces a new database value and a transaction time. Chronicle exposes that history through relation scopes:

```ruby
past = HistoricalRecord.as_of(2.hours.ago).where(user_id: 42)
recent = HistoricalRecord.since(10040).where(event_name: "login")
```

The transport applies `as_of` and `since` to the Datomic database snapshot before it executes the query.

## Cross-Database Transactions

`Chronicle::TransactionCoordinator` coordinates a Datomic write and a relational write. If the relational operation fails, it sends compensating retractions to Datomic and raises `Chronicle::TransactionError`.

```ruby
Chronicle::TransactionCoordinator.transaction do |transaction|
  transaction.datomic(record.to_datoms)
  transaction.postgres do
    AuditLog.create!(datomic_basis_t: transaction.basis_t)
  end
end
```

## Examples

The repository contains three Rails applications. They are excluded from the published gem.

| Example | Ruby | Datomic API | Port | Purpose |
| --- | --- | --- | ---: | --- |
| `news_feed` | CRuby | REST | 3001 | Publish stories and inspect revision history. |
| `wallet` | JRuby 10 | Client API | 3000 | Record deposits and withdrawals over time. |
| `animal_tracker` | JRuby 10 | Peer API | 3002 | Record coordinates and draw the historical path on a map. |
| `cross_store` | CRuby | REST + SQLite | 3003 | Reference a Datomic customer from a SQLite purchase and benchmark coordinated writes. |

The Compose stack downloads and installs Datomic inside the Datomic container. It runs the transactor, peer server, REST service, and all four applications:

```bash
cd examples
docker compose up --build
```

Then open:

- `http://localhost:3000` for the wallet.
- `http://localhost:3001` for the news feed.
- `http://localhost:3002` for the animal tracker.
- `http://localhost:3003` for the cross-store example.

The Datomic peer server listens on port `8998`. The REST service listens on port `8001`. The transactor uses ports `4334` and `4335`.

Run the cross-store benchmark with:

```bash
docker compose -f examples/docker-compose.yml exec cross_store \
  bundle exec ruby benchmark/cross_store_benchmark.rb
```

## Development

Run the full local validation:

```bash
bundle exec rake quality
```

This runs RuboCop and RSpec. The tracked pre-commit hook runs the same checks:

```bash
git config core.hooksPath .githooks
```

The CI workflow runs RuboCop, RSpec, and uploads SimpleCov results to Codecov.

## Release Contents

The gem contains only `lib/`, `README.md`, `CHANGELOG.md`, and `LICENSE.txt`. It excludes specs, CI configuration, examples, the Gemfile, the Rakefile, and the gemspec.

Build the package with:

```bash
gem build chronicle.gemspec
```

## Support Notes

- The CRuby REST transport and the JRuby Client API transport use different Datomic endpoints.
- The JRuby Peer API requires the Datomic distribution jars and a JVM.
- The Docker examples use Datomic Pro distribution downloads. Review Datomic licensing and distribution terms before use.
- JRuby and Datomic containers are not required to run the CRuby unit test suite.

## License

Chronicle is available under the MIT License.
