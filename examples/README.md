# Chronicle examples

Three small Rails applications demonstrate how Chronicle models can keep immutable history beside an Active Record workflow:

- `news_feed`: publish and update news stories while browsing their revision history.
- `wallet`: record deposits and withdrawals while inspecting the balance at each point in time.
- `animal_tracker`: use the JRuby Peer API to record coordinates and draw an animal's historical path.

The news feed uses CRuby and Datomic REST, the wallet uses JRuby and Datomic Client API, and the animal tracker uses JRuby and Datomic Peer API. The shared Compose stack installs the official Datomic distribution inside its container and runs the transactor, peer server, REST service, and all three apps.

## Start Datomic

Datomic Pro is distributed as an archive rather than an official Docker image. The Compose build downloads the configured Datomic Pro distribution into the container:

```bash
docker compose -f examples/docker-compose.yml up -d
curl -k https://localhost:8001/data/
```

The Datomic distribution is downloaded and installed during the image build. The peer server listens on `8998` for the wallet's official Client API connection and the animal tracker's direct Peer API connection. The REST service listens on `8001` for the CRuby news-feed example; the transactor uses `4334` and `4335`.

## Run an app

From either app directory:

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

The examples use Chronicle's Datomic connection by default. Set `CHRONICLE_USE_DATOMIC=false` to use the SQLite fallback without starting Datomic. Open `http://localhost:3000`.

The wallet is the JRuby example and should be run through Compose so it can load the Datomic client jars:

```bash
docker compose -f examples/docker-compose.yml up --build
```

The centralized services are available at `http://localhost:3001` (news feed), `http://localhost:3000` (wallet), and `http://localhost:3002` (animal tracker).
