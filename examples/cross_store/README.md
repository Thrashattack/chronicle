# Cross-store example

This app demonstrates a Datomic entity referenced by a SQLite row:

- `DatomicCustomer` lives in Datomic.
- `Purchase` lives in SQLite.
- `purchases.customer_id` stores the Datomic entity ID and is validated against Datomic before the SQLite write.
- `Chronicle::TransactionCoordinator` writes the Datomic entity and SQLite row as one application workflow and sends a compensating Datomic retraction if the SQLite transaction fails.

Run it from the repository's shared Compose stack. The app is available at `http://localhost:3003`.
