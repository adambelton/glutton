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
Expired Identity records can be removed with the bounded cleanup command below;
expiry prevents access independently of eventual physical deletion.

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

## Expired Identity cleanup

Run one bounded cleanup pass with:

```sh
bin/rails identity:cleanup_expired
```

This deletes at most 100 expired guest candidates and 100 expired pending-registration
candidates, oldest first, and prints only `guests_deleted` and
`pending_registrations_deleted` totals. The latter includes requests deleted with
guests. Guest sessions and pending registrations are deleted atomically with their
guest; independently expired pending requests do not delete their account or sessions.
Registered and deleted accounts are retained. Registered sessions have no age deadline.

`Identity::CleanupExpiredAccounts.call(batch_size: 100)` accepts integer batch sizes
from 1 to 1,000. It rechecks lifecycle/deadlines under locks and uses the same
owner-before-pending lock order as registration. Each candidate commits separately.
A failure exits nonzero with a sanitized diagnostic, rolls back that candidate and
stops; earlier deletions remain committed. Investigate the cause and rerun safely.
Repeated/concurrent runs do not double-count deleted records.

The proposed deployment cadence is every 15 minutes. No scheduler is installed by
this task, and Active Job remains disabled. A backlog may take multiple passes;
there is no guaranteed deletion delay. Expired access is rejected even when cleanup
has not run. No cleanup command was run against development/production data during
verification; tests use isolated test records.

The command deletes Identity-owned records and, through Library's scoped user
foreign-key cascade, that expired guest's LibraryFilm rows in the same transaction.
Shared Film records survive; claiming a guest in place preserves its Library rows.
Other product domains must agree their own deletion policy before persisting guest
activity. Unknown restrictive foreign-key dependents still fail safely and roll
back the current guest. The candidate batch limit does not bound the number of
Library rows deleted for one guest. Scheduler installation and monitoring remain
deployment work.

## Development film sample

Task 007 provides minimal film identities, not analyses or a validated production seed. After applying migrations, explicitly load the three-film sample in development:

```sh
bin/rails db:migrate
bin/rails film_knowledge:load_sample
```

The command creates Alien, The Thing and Get Out only when their TMDB IDs are absent. Re-running preserves internal IDs, existing metadata and unrelated films. It reports `sample_films=3`; this is the sample size, not a count of new inserts. The command rejects environments other than development before writing. It runs no API requests and is not called by application boot or `db:seed`. Failure rolls back the sample transaction; fix the cause and rerun.

Sample identity sources and verification limits are recorded in [task 007](docs/specs/007_film_catalogue.md). The films table stores one nullable release date, with year queries derived from date ranges; original titles and other descriptive values live in JSONB metadata. Sample release dates remain unknown until primary release dates are verified. The full 50-film catalogue, analyses, qualities and TMDB API import are separate work.

## Import a selected TMDB film

Configure the application read-access token in your ignored local `.env` file (development), or process environment elsewhere:

```dotenv
TMDB_API_READ_ACCESS_TOKEN=your_read_access_token
```

The separate TMDB API key is not used. Restart Rails/console after changing development configuration. Do not commit tokens or print them in console output.

After applying migrations, explicitly import one already-selected movie ID from `bin/rails console`:

```ruby
film = FilmKnowledge::ImportTmdbFilm.call(tmdb_id: 348)
```

Use a positive Integer, not a title, string ID or URL. An existing TMDB identity returns its current Film without a request or credential lookup, preserving local metadata and unknown dates. New identities use one HTTPS movie-details request in en-US; no search, refresh, media or analysis is fetched. The operation stores title, source primary release date (nullable), TMDB ID and metadata containing optional original_title and tmdb provenance (fetched_at/language). Year filtering uses the release date; no separate year is stored.

The client uses 5-second connect and 10-second read/write timeouts, with no automatic retries or redirects. Expected errors are `FilmKnowledge::InvalidTmdbId`, `TmdbConfigurationError`, `TmdbNotFound`, `InvalidTmdbResponse`, or `TmdbUnavailable` (all under FilmKnowledge). The latter exposes `reason`, including `authentication`, `rate_limited`, `timeout`, `transport` or `http_error`. Errors omit credentials and provider response bodies. Fix the cause before explicitly retrying; 429 is surfaced without a retry loop. Unexpected validation/database failures propagate. Concurrent imports reuse the same Film; failed inserts leave no partial record.

This operation is not called during boot or seeding. Automated tests use fake HTTP and isolated test records; no live request or development import was performed for task 008 verification. Live end-to-end verification remains outstanding. Search belongs to task 009.

## Search TMDB for a film

From Rails console, using the same ignored `TMDB_API_READ_ACCESS_TOKEN` configuration:

```ruby
page = FilmKnowledge::SearchTmdbFilms.call(query: "The Thing")
page = FilmKnowledge::SearchTmdbFilms.call(query: "The Thing", page: 2, primary_release_year: 1982)
page[:candidates]
```

Search returns `{ page:, total_pages:, total_results:, candidates: }`. Each candidate contains only `tmdb_id`, `title`, optional `original_title`, nullable `release_date` (a Date), and optional `original_language`. Provider order and distinct identities are preserved. An empty candidate list is a successful zero-result page. Malformed provider data rejects the whole page instead of returning partial selection data.

Queries must be nonblank Strings of at most 200 characters after outer whitespace is stripped; internal spacing and Unicode remain intact. Page must be an Integer from 1 through 500. Optional primary_release_year must be an Integer from 1000 through 9999: it filters upstream primary release year, rather than introducing another date/year value in our catalogue. Search requests one page in en-US with adult results excluded; it does not automatically fetch further pages or details, rank/select a film, or write any catalogue records.

After explicitly choosing a candidate, pass its integer TMDB ID to the existing import operation; import still retrieves and validates details independently:

```ruby
film = FilmKnowledge::ImportTmdbFilm.call(tmdb_id: selected_candidate.fetch(:tmdb_id))
```

Invalid inputs raise `FilmKnowledge::InvalidTmdbSearch` before credential lookup or HTTP. Provider/configuration failures use task 008's sanitized errors and timeout/retry policy; search 404 is `TmdbUnavailable` with reason `http_error`, while movie-details 404 remains `TmdbNotFound`. Queries, credentials and provider bodies are omitted from routine logs and errors. No UI or automatic import is included. Task 009 verification used fake HTTP only; live search compatibility remains unverified.

## Library watched state

Task 010 provides `LibraryFilm` backed by `library_films`, with `LibraryFilmWatched` as its only implemented STI subtype. One user/film relationship is enforced across types; an unclassified film has no relationship row. `watched_at` is the first time Glutton recorded watched confirmation, not the actual viewing date. Future watchlist/dismissal subtypes and transitions remain separate tasks.

After applying migrations, application code can call the synchronous Library operations with a persisted User obtained through Identity's current-user resolution and a persisted Film model:

```ruby
Library::FilmState.call(user: current_user, film:)
# => { film_id: ..., classification: :unclassified, watched_at: nil }
Library::RecordWatched.call(user: current_user, film:)
# => { film_id: ..., classification: :watched, watched_at: ... }
```

Repeated calls preserve relationship IDs and timestamps. Both operations re-read the owner under its user-row lock and reject inactive, missing or expired identities (`Library::IdentityUnavailable`); a nil, unpersisted or absent film raises `Library::FilmUnavailable`. Internal callers supply model behaviour; there are no concrete User/Film argument-class guards. They scope access to that owner, perform no imports or Ratings calls, and compose with an outer caller transaction. Persistence failures roll back and propagate; an explicit retry may succeed once the cause is fixed.

Deleting a user physically removes only their dependent Library rows through the Library-owned foreign key; shared films are not cascaded. Existing guest cleanup and in-place registration are unchanged. A restrictive dependent preventing deletion still rolls back Identity/Library changes for that guest. Registered-account deletion and retention for future activity remain separate decisions.

Task 010 verification uses isolated test data only; development/production migrations and watched writes were not performed. Apply `bin/rails db:migrate` before local use. There is no new UI, watchlist/dismissal flow or automatic guest creation in this task.
