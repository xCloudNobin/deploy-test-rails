# Taskboard (Rails)

A compact, idiomatic Rails taskboard built as a compatibility reference
deployment: SQLite storage, cookie sessions with password auth, a DB-backed
job queue with a worker command, validated CRUD with search/filter, CSRF
protection, and health/liveness/readiness endpoints for orchestrators.

## Stack

- Ruby 3.2.x, Rails 8.1, SQLite (`sqlite3` adapter)
- Puma (production-ready config in `config/puma.rb`)
- Minitest (default Rails test stack, no extra harness)

## Run locally

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed     # demo user: demo@example.com / password
bin/rails server      # http://localhost:3000
```

Sign in at `/session/new`, then create, edit, delete, search, and filter tasks
by status / priority / overdue.

## DB-backed jobs and worker command

Jobs live in the `jobs` table. Enqueue work programmatically:

```ruby
Job.create!(name: "notify", payload: { action: "echo", message: "hi" }.to_json)
```

Process them with the worker command:

```sh
bin/worker                   # run forever, polling for queued jobs
bin/worker --once            # drain currently-queued jobs, then exit
bin/worker --once --limit 5  # process at most 5 jobs, then exit
```

The worker claims a queued job, marks it processing, executes it, and records a
terminal state (`done` / `failed`) with `attempts`, `last_error`, and
`processed_at` back to the database.

## Health checks

- `GET /up` – Rails built-in liveness (200 when the app boots)
- `GET /health/live` – liveness
- `GET /health/ready` – readiness; 200 when the DB answers, 503 otherwise
- `GET /health/release` – release marker, read from the `RELEASE` file or
  the `RELEASE_VERSION` env var

These are public (no session required).

## Verifying

```sh
scripts/verify.sh
```

`verify.sh` is self-bounding (default 300s, tune with `VERIFY_TIMEOUT`): it prepares
databases, runs the test suite, boots Puma in production mode, probes every health
endpoint plus the anonymous redirect, proves the worker moves DB-backed jobs to a
terminal state, and confirms a task created through the UI survives a full server
restart (SQLite persistence).

## Environment

See `.env.example`. Rails does not auto-load `.env`; export the variables (or
use a process manager). Production needs `PORT`, `RAILS_ENV=production`, and a
secret (`RAILS_MASTER_KEY` or `SECRET_KEY_BASE`). The SQLite path can be set
with `DATABASE_PATH`.

## Production deployment (Puma)

```sh
RAILS_ENV=production SECRET_KEY_BASE=<generated> \
  WEB_CONCURRENCY=$(nproc) PORT=3000 bin/rails server
```

`WEB_CONCURRENCY > 1` enables preloading and per-worker DB connection boots;
one worker (default) works for smaller deployments.

## License

MIT. See [LICENSE](LICENSE).
