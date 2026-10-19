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

Action Mailer composes confirmation and password-reset messages. Registration and
confirmation and password recovery have browser flows.

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
HTTP on localhost is allowed in development, including with Resend. No arbitrary recipient lookup occurs.
Confirm inbox receipt and inspect message headers for SPF, DKIM and DMARC passing;
SMTP acceptance alone does not prove receipt. Do not paste credentials or token
links into logs or committed files.

## User-facing copy

Store application copy in `config/locales/en.yml` and use Rails `t` in views or
`I18n.t` in controllers/mailers. Share mail copy between text and HTML templates.
Use symbolic custom validation errors with Rails Active Model translations. English
is the initial locale; missing translations raise in development/test. Translate
at runtime rather than defining translated constants. Keep values plain text;
views escape them. Developer diagnostics and static emergency error pages do not
require application translation loading.

## Registration confirmation provider

Pending registrations expire 24 hours after creation, capped by a linked guest's
original deadline. `Identity::RegistrationConfirmation.token_for(pending_registration_id:)`
issues a purpose-bound one-hour token; it does not send email. Tokens contain no
email/password/digest, and credential changes or request replacement invalidate them.
`Identity::CompleteRegistration.call(token:)` returns a fresh Session after atomically
creating a confirmed registered account or upgrading the linked active guest,
revoking old guest sessions and deleting the pending request. Expected invalid,
expired/replayed or conflicting claims raise `Identity::RegistrationUnavailable`;
unexpected persistence failures propagate after rollback.

The registration browser flow consumes these Identity operations for initiation,
email link delivery, explicit confirmation and browser cookie binding.
Expired credential cleanup is also separate; expiry prevents access without claiming
that retained database records have been deleted.

## Registration browser flow

Open `/registration/new` to register, `/registration` to view pending verification
and resend an email, and the confirmation link to explicitly confirm with a POST.
Viewing a link does not register or sign in. Signing up as an existing guest keeps
its ID; beginning guest activity after signup attaches that browser's pending
request before the guest/session is committed. The current home page does not
save product activity; later Ratings UI will call the existing Identity entry point.

Set `APP_ORIGIN` in ignored `.env.development` or production process environment to
the application's trusted public HTTPS origin, e.g. `https://app.example.test`.
Do not use the incoming Host header. Production requires a usable HTTPS app origin; development also supports HTTP localhost, including with live Resend delivery.
registering a sending domain alone does not provide HTTPS application hosting.
Missing/invalid origin fails clearly on send without contacting SMTP. No HTTPS
hosting or tunnel is provisioned by this task. Development without SMTP can use:

```sh
MAIL_DELIVERY=test APP_ORIGIN=http://localhost:3000 bin/dev
```

This keeps messages in process memory; it does not send to an inbox. Automated
request tests inspect their in-memory messages and complete the browser flow.
For live development on this Mac, use the existing opt-in Resend variables plus
`APP_ORIGIN=http://localhost:3000`. Open emailed localhost links on this Mac. Obtain owner-designated recipient authorization before
manual live sends and report transport acceptance separately from inbox receipt.

Each pending request permits five send attempts, at least 60 seconds apart;
network failures count. Attempts are reserved in PostgreSQL before sending without
holding a transaction across SMTP. Exhausted requests can still use previously
received links or be replaced by a new submission. Rails also limits submission
and resend together to ten requests per three minutes per IP, and confirmation
POST separately to ten. These IP budgets are per worker and reset on restart;
shared/distributed abuse controls are required before multi-worker public release.

The browser remembers only its pending ID in its encrypted Rails session. The
verification reminder shows fixed expiry and temporary guest status. Registered
sign-in, successful confirmation and sign-out clear pending browser state. Email
links work in a different browser; an already signed-in account or unrelated guest
requires explicit sign-out or a different browser, with no automatic activity merge.
Registration pages disable caching and referrers. All copy uses locale entries.

New pending registrations reject normalized emails already held by a registered account
and direct the visitor to sign in. No new confirmation is sent; stale requests also
cannot resend once the email is registered. This form intentionally reveals account
existence, while final confirmation retains its database uniqueness protection.

## Password recovery

Use “Forgot your password?” on `/session/new` or open `/password_reset/new`.
Accepted requests give the same neutral response for known and unknown addresses;
only confirmed registered accounts receive mail. Links use `APP_ORIGIN` under the
same rules as confirmation. Viewing `/password_reset/edit?token=…` only renders a
form; a CSRF-protected PATCH changes the password. Rails-native tokens expire after
15 minutes and become invalid when the password changes.

`Identity::RequestPasswordReset.call(email_address:)` delivers synchronously outside
database transactions. `Identity::ResetPassword.call(token:, password:,
password_confirmation:)` locks and revalidates the token, enforces existing password
policy, and atomically changes the digest and deletes all target sessions. It returns
the registered user without signing in. Invalid links raise
`Identity::PasswordResetUnavailable`; invalid passwords raise `ActiveRecord::RecordInvalid`.
A successful browser reset redirects to sign-in. Other signed-in accounts conflict;
unrelated guests retain their identity and pending signup without merging activity.

Requests are limited to ten per IP per three minutes and one per normalized-email
SHA-256 fingerprint per minute, including unknown addresses. Updates have a separate
ten-attempt IP budget per three minutes. These are per-worker memory limits: restart
clears them and multiple workers do not share them. Shared release abuse controls
remain separate work. Tests use local transport; implementation has sent no live mail.
