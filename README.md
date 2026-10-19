# Glutton

Source: [adambelton/glutton](https://github.com/adambelton/glutton).

A horror discovery app. This initial scaffold contains a home page and Rails health endpoint, with PostgreSQL and server-rendered Hotwire views. Product features are planned separately.

## Prerequisites

- Ruby **3.4.11** (see `.ruby-version`) and Bundler **2.6.9**.
- PostgreSQL **17** running locally (verified with **17.9**).
- The local PostgreSQL role matching your OS username must have permission to create databases. For another local connection, use standard `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` environment variables; do not commit credentials.

Rails **8.1.4** and all gem versions are locked in `Gemfile.lock`. The frontend uses importmap, so Node.js is not required. No external API keys are needed.

## Setup

From the project root:

```sh
ruby -v
bundle -v
pg_isready -h localhost
bundle install
bin/setup --skip-server
```

Setup prepares `glutton_development` and `glutton_test`, then clears development logs and temporary files. It can be repeated without resetting the databases. Do not set `DATABASE_URL` to an unrelated database: it overrides Rails' named database configuration. Use only disposable app test data in `glutton_test`.

PostgreSQL must already be running. On this machine the existing service is Homebrew `postgresql@17`; if stopped, start it with `brew services start postgresql@17`. Installing Ruby or PostgreSQL is outside the setup script.

## Run and stop

```sh
bin/dev
```

Open [Glutton](http://localhost:3000) or the [health endpoint](http://localhost:3000/up). Stop the foreground server with **Ctrl-C**. To choose another port, use `bin/dev -p 3001`.

`/up` checks that Rails boots; it does not check PostgreSQL. Check the development database explicitly with:

```sh
bin/rails runner 'puts "#{ActiveRecord::Base.connection.adapter_name}: #{ActiveRecord::Base.connection.select_value("SELECT current_database()")}"'
```

## Verify

```sh
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check --update
bin/importmap audit
```

Or run the combined local checks with `bin/ci`. Dependency audits require network access. Brakeman runs the locked scanner version; `bin/brakeman --ensure-latest` optionally checks whether a newer scanner exists. Updating the scanner is a deliberate dependency update rather than a prerequisite for every local scan.

The smoke tests check the home page, Hotwire import map, health route and isolated PostgreSQL test connection. To manually verify a running server:

```sh
curl --fail http://localhost:3000/
curl --fail http://localhost:3000/up
```

## Working documents

- [Product brief](docs/product_brief.md)
- [Architecture brief](docs/architecture_brief.md)
- [Implementation plan](docs/implementation_plan.md)
- [Initial scaffold spec and verification evidence](docs/specs/001_initial_scaffold.md)
- [Task spec template](docs/task_template.md)

Read root `AGENTS.md` before implementation. Each subsequent task needs its own scoped spec. Authentication, provider integrations, domain models, background processing and deployment remain future work.

## GitHub CI

Pull requests and pushes to `main` run `bin/ci` through GitHub Actions, using
`.ruby-version` and a disposable PostgreSQL 17 service. The same checks run locally
with `bin/ci`; PostgreSQL must already be available locally. Hosted runs need no
repository secrets and do not deploy the app.
