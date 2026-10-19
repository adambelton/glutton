# Glutton

Source: [adambelton/glutton](https://github.com/adambelton/glutton).

A horror discovery app. This initial scaffold contains a home page and Rails health endpoint, with PostgreSQL and server-rendered Hotwire views. Product features are planned separately.

## Prerequisites

- Ruby **3.4.11** (see `.ruby-version`) and Bundler **2.6.9**.
- PostgreSQL **17** running locally (verified with **17.9**).
- The local PostgreSQL role matching your OS username must have permission to create databases. For another local connection, use standard `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` environment variables; do not commit credentials.

Rails **8.1.4** and all gem versions are locked in `Gemfile.lock`. The frontend uses importmap, so Node.js is not required. No external API keys are needed for default local operation.

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

Read root `AGENTS.md` before implementation. Each subsequent task needs its own scoped spec. See the implementation plan for completed Identity work and remaining product workflows.

## GitHub CI

Pull requests and pushes to `main` run `bin/ci` through GitHub Actions, using
`.ruby-version` and a disposable PostgreSQL 17 service. The same checks run locally
with `bin/ci`; PostgreSQL must already be available locally. Hosted runs need no
repository secrets and do not deploy the app.

## Identity mail

Action Mailer composes confirmation and password-reset messages. Registration,
confirmation redemption and password reset workflows are separate tasks.

In development, visit `/rails/mailers` and select either Identity account preview.
Both HTML and plain-text views use synthetic recipients/links and never send mail.
Previews are disabled in test and production.

Default delivery uses Rails' in-memory test transport. To enable actual Resend
SMTP delivery in development, add these to the ignored `.env.development` file
(dotenv-rails loads it on boot), then restart Rails:

```dotenv
MAIL_DELIVERY=resend
MAIL_FROM=noreply@your-verified-domain.example
RESEND_API_KEY=your-api-key
```

Production uses process environment variables with the same names. Test always
uses local delivery, even if live variables are supplied. Set `MAIL_DELIVERY=test`
to explicitly disable network delivery. Missing live settings or unknown modes
fail at boot. SMTP uses port 587 with required STARTTLS and certificate verification;
credentials, recipients and message bodies are excluded from Action Mailer logs.
No queue, automatic retry or delivery tracking is configured; delivery errors
propagate to the caller.

Provider contract (synchronous sending is explicit):

```ruby
Identity::AccountMailer.confirmation(
  recipient: "reader@example.test",
  confirmation_url: "https://example.test/confirmation?token=example"
).deliver_now
Identity::AccountMailer.password_reset(
  recipient: "reader@example.test",
  reset_url: "https://example.test/password/reset?token=example"
).deliver_now
```

These example recipients/links are for local previews/tests only. For live
verification use an owner-designated recipient and a synthetic HTTPS example link;
mail composition does not implement token redemption or change any account.
Callers must supply the authorized recipient/link. Invalid recipients and URLs
raise `ArgumentError` when the lazy mail object is processed. Links require HTTPS;
HTTP on localhost is allowed in development when SMTP delivery is disabled. No arbitrary recipient lookup occurs.
Confirm inbox receipt and inspect message headers for SPF, DKIM and DMARC passing;
SMTP acceptance alone does not prove receipt. Do not paste credentials or token
links into logs or committed files.
