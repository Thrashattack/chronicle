# Wallet

A JRuby Rails example using Chronicle's Datomic Client API to model a wallet while recording every balance change as a time-stamped `WalletEntry`. The current balance and its full history are visible together.

Start the shared Datomic stack from `examples/README.md`. The Compose stack builds a JRuby 10 wallet container, loads the Datomic distribution jars from `/opt/datomic`, and connects to the peer server on `8998` using the Datomic Client API. Open `http://localhost:3000`. The native SQLite fallback is available to the MRI examples, not the JRuby wallet.
