# News Feed

A Rails example using `Chronicle::Model` for news stories. Publishing or updating a story records a `NewsRevision`, so the current feed and the full update timeline remain visible together.

Start the shared Datomic stack from `examples/README.md`, then run `bundle install`, `bin/rails db:prepare`, and `bin/rails server`. The app uses the Datomic REST connection by default; set `CHRONICLE_USE_DATOMIC=false` for the SQLite fallback.
