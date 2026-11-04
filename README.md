# Glutton

Source: [adambelton/glutton](https://github.com/adambelton/glutton).

A horror discovery app built with Rails, PostgreSQL and server-rendered Hotwire views. Implemented capabilities include guest and registered identity, registration and password recovery, TMDB film search/import, and the Library watched operation. Film and Library operations currently have programmatic interfaces; rating, recommendation and Library browsing flows remain planned. See the [current implementation status](docs/implementation_plan.md#current-progress) for merged work and changes awaiting review.

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
- [Initial scaffold spec and verification evidence](README.md)
- [Working-record template](docs/task_template.md)

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

Pending registrations expire one hour after creation (`PendingRegistration::EXPIRY_DURATION`).
A linked guest must also remain active. `Identity::RegistrationConfirmation.token_for(pending_registration_id:)`
issues a purpose-bound token valid only while that registration remains active;
resending does not extend the original deadline. It does not send email. Tokens contain no
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
links work in a different browser. An unattached registration can upgrade the active
guest in the confirmation browser without that browser having started signup. A
registration already linked to a different guest, an already registered current user,
or a current guest with another linked pending request conflicts; no activity is merged.
The browser-held pending ID is used for signup/resend and guest creation, not confirmation.
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

## Internal superuser privilege

Identity stores a denied-by-default superuser permission on registered accounts.
Set the first superuser directly through the database after verifying the intended
registered account. There is no application bootstrap bypass. Make later changes
from a trusted `bin/rails console`, identifying both the existing superuser actor
and the target account:

```ruby
Identity::GrantSuperuser.call(user_id: verified_user_id, actor_user_id: acting_superuser_id)
Identity::RevokeSuperuser.call(user_id: verified_user_id, actor_user_id: acting_superuser_id)
```

Both operations load and lock actor and target in ascending ID order, authorize
the actor against current state and return the changed account. Ordinary, guest,
expired, deleted, missing or revoked actors cannot authorize changes; unauthorized
actors raise `Identity::SuperuserRequired`. Models also require an authorized actor.
Self-revocation is allowed; no last-superuser protection is imposed. Deleted
identities cannot retain superuser privilege. Registered-account deletion remains
future work and must clear that flag atomically with anonymization and session
revocation; it does not require a separate superuser actor.
Missing, guest and deleted identities raise `Identity::SuperuserUnavailable`.
Repeated grants raise `Identity::SuperuserAlreadyGranted`; repeated revocations
raise `Identity::SuperuserAlreadyRevoked`. Other validation/database failures
propagate. No email, seed, registration parameter or public endpoint grants access.

Consumers can read `current_user&.superuser?` as internal privilege state.
Feature-specific authorization is deferred to the features that need it. Guests
(including expired guests), deleted identities and ordinary accounts are denied. Re-read authoritative identity state for each request; do not
cache permission in sessions. Existing browser sessions see grant/revoke on the next
request without signing in again.

The original users migration and schema include this permission. For an existing
local database that already ran that migration, apply these additive changes once
from the console, preserving accounts and unrelated data, then run
`bin/rails db:schema:dump` (do not reset the database):

```ruby
connection = ActiveRecord::Base.connection
connection.transaction do
  connection.add_column(:users, :superuser, :boolean, null: false, default: false)
  connection.add_check_constraint(:users, "NOT superuser OR type = 'UserRegistered'",
    name: "only_registered_users_can_be_superusers")
end
```

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

## Quality vocabulary seed

After applying migrations, load the 235 provisional quality definitions and nine category defaults:

```sh
bin/rails db:migrate
bin/rails db:seed
```

The seed uses `config/quality_vocabulary.yml`, packaged from the retained baseline with original names, definitions and exclusions. Run it once against an empty catalogue: it inserts nine categories and 235 qualities in one transaction. It does not match, update or reuse existing records. An error rolls back the whole load; investigate the cause before trying again. It creates no films or film-quality associations and makes no provider calls. Film import with Wikipedia context is available separately; initial quality assignment and bulk catalogue execution remain to build.

Qualities use immutable names and database IDs; there is no separate quality key. Categories also use names and database IDs; their names remain editable. Both seed files are plain YAML lists, with vocabulary entries referring to category names during the one-time initial load. Existing name-only qualities remain valid; when a definition or exclusion is supplied, both must be nonblank. Definitions and exclusions remain editable within the same concept. 

## Import a selected TMDB film

Configure the application read-access token in your ignored local `.env` file (development), or process environment elsewhere:

```dotenv
TMDB_API_READ_ACCESS_TOKEN=your_read_access_token
```

The separate TMDB API key is not used. Restart Rails/console after changing development configuration. Do not commit tokens or print them in console output.

After applying migrations, explicitly import one already-selected movie ID from `bin/rails console`:

```ruby
film = Registry::ImportFilm.call(tmdb_id: 348)
```

Use the real import for development data as well.

Use a positive Integer, not a title, string ID or URL. This single operation retrieves TMDB details/external IDs, follows the Wikidata English Wikipedia sitelink, verifies the article's Wikidata identity, and fetches its exact revision. It returns only when `film.has_source_context?` is true. Callers supply no Wikipedia page ID. Search remains a separate read-only selection step.

`ImportFilm` coordinates `FetchTmdbFilm` and `FetchWikipediaContext`. Both return validated data using the selected TMDB ID, without requiring or writing a Film. The orchestrator gathers both results before constructing a Film, then calls `Registry::Film#import!(tmdb_data:, wikipedia_context:)` for one complete save. Film owns validation and field assignment through explicit arguments; there are no retrieval blocks or external storage checks. The independent fetchers can later supply fresh data to explicit on-demand update operations.

Physical column order is `id`, `title`, `release_date`, `tmdb_id`, `tmdb_metadata`, `wikidata_id`, `wikipedia_context`, `created_at`, `updated_at`.

The film retains title, nullable source release date, TMDB metadata/provenance in `tmdb_metadata`, a nullable indexed `wikidata_id`, and source material in `wikipedia_context`. That packet contains TMDB/Wikidata/page identity, language, title, revision ID/timestamp/URL, article/history URLs, retrieval time, licence name/URL and ordered `source_paragraphs` (`id`, `section`, `text`). The provider-specific JSON columns store their packets directly, without redundant `tmdb`/`wikipedia` wrappers. The Wikipedia packet retains its language-specific page/revision identity as provenance and its entity identity matches `wikidata_id`; the language-independent Wikidata identity can remain when context is purged. The current importer fetches English Wikipedia only; other languages can later resolve their articles through the same entity. Paragraph references P1… belong to that revision. Extraction preserves prose/order, normalises HTML entities/whitespace and removes citations, tables, navigation, reference/cast sections and standalone blockquotes. Readiness requires complete provenance and narrative under Plot, Synopsis, Story or Premise; it does not certify semantic completeness.

Import creates a new film only. An existing TMDB identity raises `Registry::ImportIncomplete` with stage `persistence` and reason `existing_film` before provider calls. Concurrent imports of that identity produce one success and an explicit conflict for the other caller. Existing records are never resumed, merged, refreshed or silently returned. Different film identities can fetch in parallel. Invoke import outside caller-owned write transactions.

Invalid selected IDs raise `Registry::InvalidTmdbId`. Known provider/coverage failures raise `Registry::ImportIncomplete`, exposing `stage` (`tmdb`, `wikidata`, `wikipedia`, `persistence`), `reason` and `tmdb_id`. Reasons distinguish duplicate film, missing identity/article, conflicting identity, insufficient narrative, configuration/authentication, rate limits, malformed/oversized responses, timeout and transport failure. Both source fetches must succeed before the initial insert; a failure creates no partial film. Fix the cause and retry explicitly. Unrelated validation/database failures propagate and roll back the insert. Source updates will be a separate workflow using the same fetchers; import never overwrites existing data. `tmdb_metadata` and `wikipedia_context` may be empty objects so later explicit model operations can purge either source while retaining its identifier. Purging does not permit re-import of that existing identity; readiness remains derived from the available inputs.

Each client configures its fixed HTTPS host and response-size limit on the provider-agnostic `ProviderRequest`. The transport accepts host/path/parameters/headers, parses JSON and raises sanitized transport errors; clients own response shape, API error interpretation and import-stage translation. Adding a provider requires no transport registry or provider-specific branch. Requests use a descriptive User-Agent, 5-second connect and 10-second read/write timeouts, a 30-second total request limit, streamed body caps (TMDB 2 MiB, Wikimedia 8 MiB), and no automatic retries or HTTP redirects. API-level article redirects are accepted only with matching Wikidata identity and revision/page checks. Errors omit credentials and provider bodies.

This operation serves both future bulk catalogue loading and on-demand import. It is not called during boot or vocabulary seeding and creates no Library entry, rating or quality assignment. Automated tests cover fake-HTTP search/selection/import, parsing, atomic creation, failures and explicit duplicate conflicts. A live development smoke test passed for five horror films through TMDB, Wikidata and Wikipedia; wider coverage and operational throughput remain unverified.

## Search TMDB for a film

From Rails console, using the same ignored `TMDB_API_READ_ACCESS_TOKEN` configuration:

```ruby
page = Registry::SearchTmdbFilms.call(query: "The Thing")
page = Registry::SearchTmdbFilms.call(query: "The Thing", page: 2, primary_release_year: 1982)
page[:candidates]
```

Search returns `{ page:, total_pages:, total_results:, candidates: }`. Each candidate contains only `tmdb_id`, `title`, optional `original_title`, nullable `release_date` (a Date), and optional `original_language`. Provider order and distinct identities are preserved. An empty candidate list is a successful zero-result page. Malformed provider data rejects the whole page instead of returning partial selection data.

Queries must be nonblank Strings of at most 200 characters after outer whitespace is stripped; internal spacing and Unicode remain intact. Page must be an Integer from 1 through 500. Optional primary_release_year must be an Integer from 1000 through 9999: it filters upstream primary release year, rather than introducing another date/year value in our catalogue. Search requests one page in en-US with adult results excluded; it does not automatically fetch further pages or details, rank/select a film, or write any catalogue records.

After explicitly choosing a candidate, pass its integer TMDB ID to the existing import operation; import still retrieves and validates details independently:

```ruby
film = Registry::ImportFilm.call(tmdb_id: selected_candidate.fetch(:tmdb_id))
```

Invalid inputs raise `Registry::InvalidTmdbSearch` before credential lookup or HTTP. Search retains `TmdbConfigurationError`, `InvalidTmdbResponse` and `TmdbUnavailable` errors, with the same sanitized timeout/retry policy. Search 404 is `TmdbUnavailable` with reason `http_error`; the complete import wraps movie-details 404 as `ImportIncomplete` (`tmdb`, `not_found`). Queries, credentials and provider bodies are omitted from routine logs and errors. No UI or automatic import is included. Automated search checks use fake HTTP. Live title/year searches selected the five films used in the development import smoke test.

## Load canonical films with initial qualities

Seed the quality vocabulary first and configure the existing TMDB, Wikipedia/Wikidata and TypeSafe credentials. `LoadFilm` coordinates the create-only source import and initial assignment in one call:

```ruby
result = Registry::LoadFilm.call(
  tmdb_id: selected_candidate.fetch(:tmdb_id),
  maximum_requests: 8,
  maximum_cost_usd: 0.02
)
result.fetch(:film)
result.fetch(:film_quality_eval).output
result.fetch(:film_qualities)
result.fetch(:warnings)
```

Request and cost limits apply to TypeSafe. They are required positive integer/finite decimal bounds; decimal amounts can be Integer, Float or BigDecimal values. Loading must start outside a database transaction. Both sources are acquired before Film creation, and import commits before quality evaluation. A source failure creates no Film. An assessment/application failure propagates while retaining the imported Film and any recorded evaluation. Zero supported qualities return a localized warning with the completed evaluation and empty quality list. Existing identities are explicit conflicts, including concurrent loads. Assess an already imported film through the separate assignment operation below.

For an explicit batch, supply the complete TMDB ID list and its limits:

```ruby
summary = Registry::LoadFilms.call(
  tmdb_ids: selected_tmdb_ids,
  maximum_films: 10,
  maximum_requests_per_film: 8,
  maximum_cost_usd_per_film: 0.02,
  maximum_cost_usd: 0.20
)
summary.fetch(:loaded_film_ids)
summary.fetch(:warnings)
summary.fetch(:limits)
```

The entire list is validated and copied before work starts. The batch rejects more than `maximum_films` or a worst-case allocation (`list size × per-film cost limit`) above the total cost ceiling, using exact decimal arithmetic. Duplicate IDs remain explicit attempts/conflicts and count toward that envelope. Unused allocations are not borrowed across films. `limits` reports the film count and maximum TypeSafe requests/cost for the validated list, rather than actual billed usage.

The batch runs films independently in list order, reports each import/assessment/unexpected failure or zero-quality warning, and continues. `loaded_film_ids` contains only films that finished with qualities. Warnings identify the TMDB ID and the persisted Film ID when available, without raw private exception text. `Registry::Film.without_qualities` finds imported films requiring assessment or intervention. Independent workers can call `LoadFilm` with their own explicit bounds; no scheduler, automatic catalogue execution or process pool is installed.

## Assign initial film qualities

Configure `TYPESAFE_API_KEY` in the ignored development environment and use the existing Langfuse configuration for tracing. The quality vocabulary must already be seeded and the film must have usable imported source data. From Rails console:

```ruby
result = Registry::AssignInitialFilmQualities.call(film_id: film.id)
result.fetch(:film_qualities)
result.fetch(:film_quality_eval) # persisted evaluation, including call history and application outcome
result.fetch(:film_quality_eval).output # complete persisted judgments, policies, call history and usage/cost
```

The service pins `jev-1.14.0` and uses the retained contextual-support questions. Code selects support >=0.60 within each category's maximum, descending support then Quality ID for ties. Category weights do not affect membership; ceilings are maxima. Evidence questions identify a directly supporting paragraph for each selected quality. Model judgments still need inspection; support is not an enjoyment score or proof of correctness.

Accepted state is persisted as `Registry::FilmQuality` records with a `film_quality_eval` reference. Evidence is stored only in the evaluation output; FilmQuality exposes no evidence reader. `Registry::FilmQualityEval` independently retains the evaluation: source/definition snapshots, ordered exact request/response pairs and call count, all probabilities, evidence, selection decisions (threshold/category ceiling/rank), model/policies, usage/cost and optional trace ID. Its output is immutable; a single application outcome records accepted association IDs or a safe failure reason. Langfuse is diagnostic telemetry, not a runtime dependency for reading evaluation evidence. Manual and pre-existing associations may have no evaluation; no history is fabricated for them. There is no receipt or status column on Film.

Existing associations fail explicitly instead of being overwritten. Provider work precedes short write locks; changed sources/vocabulary or intervening assignments prevent application. A failed write rolls back every new association while retaining the completed evaluation and its failure outcome. Stale evaluations are retained but not applied. Provider failures retain a failed evaluation with partial answers, safe errors and attempted-call history; requests blocked before sending are identified and excluded from the provider-call count. Usage/cost totals include validated responses only, and incomplete usage is flagged. Unparseable/transport failures have no JSON response to retain.

Requests have size/time/call/cost bounds and no automatic retries or long-context opt-in; the default client reserves a conservative cost allowance before each call and reconciles actual input-token usage afterward.

For an explicit batch, enqueue the Registry job with selected IDs:

```ruby
Registry::AssignInitialFilmQualitiesJob.perform_later(film_ids: selected_film_ids)
Registry::Film.without_qualities # films needing assessment or manual intervention
```

The job logs localized structured warnings for each film with zero qualities, an assessment error or an unexpected per-film failure, then continues with later films. Zero supported qualities retain a completed evaluation with an empty accepted association list; an explicit later request may assess the film again. The review query also includes films not assessed yet. Insufficient coverage currently means zero, matching that query; no higher minimum or category quota is inferred. The job does not schedule itself or automatically process the catalogue.


## Library watched state

Library uses `LibraryFilm` backed by `library_films`, with `LibraryFilmWatched` and a minimal `LibraryFilmToWatch` STI subtype. One user/film relationship is enforced across types; an unclassified film has no relationship row. Watchlist and dismissal actions use the same canonical relationship.

After applying migrations, application code can call the synchronous Library operation with the trusted current-user ID obtained through Identity and an existing film ID:

```ruby
library_film = Library::RecordWatched.call(user_id: current_user.id, film_id: film.id)
# => persisted library entry
```

Recording a to-watch entry as watched preserves its ID, ownership, film and creation time, returning the watched object. The source model declares `can_watch?`; the service executes the transition. A request for an entry with `can_watch? == false` raises `Library::AlreadyWatched` without changes, including repeated or concurrent requests after a successful transition. The operation re-reads the user under its user-row lock and rejects inactive, missing or expired identities (`Library::IdentityUnavailable`); a missing film ID raises `Library::FilmUnavailable`. Both records are resolved inside the transaction; Film is read without a row lock. The STI root rejects direct construction without enumerating allowed subclasses. It scopes access to that user, performs no imports or Ratings calls, and composes with an outer caller transaction. Persistence failures roll back and propagate; an explicit retry may succeed once the cause is fixed.

Deleting a user physically removes only their dependent Library rows through the Library-owned foreign key; shared films are not cascaded. Existing guest cleanup and in-place registration are unchanged. A restrictive dependent preventing deletion still rolls back Identity/Library changes for that guest. Registered-account deletion and retention for future activity remain separate decisions.

Apply the database migrations before local use. Library browsing and watchlist/dismissal actions use the existing identity and owned-entry contracts.
