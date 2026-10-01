# Changelog

## 0.1.0

### Core

- Added Active Record integration through `Chronicle::Model`.
- Added Datomic attribute declarations and schema migration helpers.
- Added Datalog compilation for predicates, projections, `IN` values, and pull queries.
- Added association hydration from Datomic pull results.
- Added `.as_of` and `.since` time-travel relations.
- Added coordinated Datomic and relational transactions with compensating retractions.
- Added retry backoff, jitter, circuit breaking, and Fiber-aware sleeping.

### Transports

- Added CRuby transport support for Datomic REST with EDN requests and responses.
- Added JRuby Client API support through a Datomic peer server.
- Added JRuby Peer API support for direct transactor connections.
- Added explicit peer transport selection with `transport: peer`.
- Added Datomic jar loading for JRuby containers.

### Examples

- Added `news_feed`, a CRuby Rails application that displays story revisions.
- Added `wallet`, a JRuby Rails application that uses the Datomic Client API to track balance changes.
- Added `animal_tracker`, a JRuby Rails application that uses the Datomic Peer API to draw historical paths.
- Added a Docker Compose stack that installs the Datomic distribution in a container and runs the transactor, peer server, REST service, and all examples.

### Tooling and Release

- Raised the supported Ruby version to 3.4.5.
- Added RuboCop CI validation and a pre-commit quality hook.
- Added SimpleCov and Codecov reporting.
- Limited the published gem to library code and release documentation.
- Excluded specs, CI files, examples, and development files from the gem archive.
