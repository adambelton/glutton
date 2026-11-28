# Development guide

## Setup and verification

Use the Ruby version in [`.ruby-version`](../.ruby-version), the Bundler version in [`Gemfile.lock`](../Gemfile.lock), PostgreSQL 17 and Node 22 for the browser suite. PostgreSQL must be running and the local role must be able to create databases. Rails honours the standard PostgreSQL connection environment variables.

```sh
bin/setup --skip-server
bin/dev
```

Open [localhost:3000](http://localhost:3000). `bin/dev` builds styles and starts Rails and GoodJob together. Use `bin/rails tailwindcss:watch` for live CSS builds. Manual work uses `glutton_development` and automated tests use `glutton_test`. Check any `DATABASE_URL` override before setup or test commands.

Rails replays all migrations when `db:prepare` creates a database and applies pending migrations to an existing one. This installs PostgreSQL objects defined in migrations, including the Community report deletion triggers. Schema dumps are disabled. Use `RAILS_ENV=test bin/rails db:prepare` to set up or update the test database on its own. To discard that test database and rebuild it from migrations, use `RAILS_ENV=test bin/rails db:migrate:reset`.

Use `bin/ci` for style, security, autoloading, Rails tests and the Capybara system suite. GitHub Actions runs the same checks on pull requests and pushes to main. Dependency audits use network access. The `/up` endpoint checks whether Rails boots.

GitHub Actions runs `bin/ci` in the test environment. Its setup step replays migrations on the empty PostgreSQL database, and both test suites run serially against that same database.

### Browser tests

Capybara uses Playwright Chromium for Rails system tests. Install the test dependencies and run the suite with the normal Rails command.

```sh
npm ci --prefix test/playwright
(cd test/playwright && npx playwright install chromium)
bin/rails test:system
```

On Linux, use `npx playwright install --with-deps chromium` in `test/playwright` to install the system libraries too. When updating the Ruby Playwright client, keep the npm Playwright version aligned with the client's supported CLI version.

Let Capybara wait for the expected state after navigation or a Turbo update. Check what the user can do and see, such as whether a synopsis reveals its text and collapses with Escape. Use geometry when the behaviour under test is a layout requirement, such as controls fitting on a mobile row without overlap. Compare the elements involved directly and use fixed dimensions when a specific size is part of the design contract. Use the viewport helpers to set the page size and restore it after the check.

Use Playwright's clock for browser timer behaviour. Hold a stubbed response until the test observes the pending state when checking a loading indicator.

Run with `GLUTTON_PLAYWRIGHT_TRACE=1` to retain traces from failed tests in `tmp/playwright-traces/`. The [CI workflow](../.github/workflows/ci.yml) uploads traces and screenshots when a browser test fails.

## Git workflow in Zed

Open the main Glutton checkout in Zed and keep the active task branch checked out there while working. Zed shows the files and Git status of that checkout. Use another worktree only at the owner’s explicit request.

Once the PR merges, check local changes and preserve any unrelated edits or untracked files before switching branches. Fetch `origin`, switch the main checkout to `main`, and run `git merge --ff-only origin/main`. Verify that `HEAD` matches `origin/main` and that `git status --short` shows only unrelated local work. The [repository instructions](../AGENTS.md#git-worktree-and-zed) apply this workflow to every task.

## Accounts and mail

Set `APP_ORIGIN` to the actual application origin for registration and recovery links. Development supports localhost and the `glutton.local` alias. For the alias, map `glutton.local` to `127.0.0.1` in the local hosts file. Production uses an HTTPS origin.

Development uses in-memory mail delivery by default. Use `/rails/mailers` for local previews. For authorized live delivery, set `MAIL_DELIVERY=resend`, `MAIL_FROM` to a verified sender and `RESEND_API_KEY` in the ignored development environment or production process environment. Tests use local delivery.

Bootstrap the first superuser directly in the database after verifying the registered account. Existing superusers can grant or revoke access with `Identity::AccountAdministration::GrantSuperuser` and `Identity::AccountAdministration::RevokeSuperuser`, supplying `user_id:` and `actor_user_id:`.

Run `bin/rails identity:cleanup_expired` for one bounded pass over expired guests and pending registrations. Guest deletion cascades through viewer-owned activity and preserves shared films. Expiry blocks access independently of cleanup. Production scheduling for this command remains open.

## Protected curation preview

Run `bin/rails community:seed_protected_curation` against the local development database. It prints the seeded post path. The task uses the Community-enabled account `hello@adambelton.com` and two horror films already marked Watched by that account.

The two local preview accounts are `curation-reader-one@example.test` and `curation-reader-two@example.test`. New fixture accounts use the development-only password `local-curation-preview`. The seed reuses the accounts and curation on later runs and preserves changes made to the curation.

## CommunityUser staging cutover

Use one cutover window with staging account and Community writes paused. Take a pre-cutover database backup, then run the export with the old schema. Run these commands from an application shell connected to the intended database. The export can be piped through Rails runner on the legacy release.

```sh
bin/rails runner - export /private/path/community-users.json < script/community_user_transfer.rb
# Deploy the new application and run its schema migrations.
bin/rails runner script/community_user_transfer.rb import /private/path/community-users.json
```

Bring the same private export into the post-deploy shell before importing. It contains public profile data and attribution IDs. Conduct acceptance stays on the registered account. Import checks the original IDs against the renamed CommunityUser references, restores profiles and validates the three foreign keys. It can be rerun with the same export. Check profile settings, posting eligibility and existing attribution before resuming writes. A fresh database starts with the new structure.

## Background processing

See [domain event operations](domain_event_operations.md) for worker configuration and delivery diagnostics. GoodJob schedules taste-profile refresh every 15 minutes in production. Superusers can inspect and queue a refresh of their own profile from Account. Operators can process pending requests from the console with `Ratings::TasteProfiling::ProcessProfileRefreshes.call`. See [AI configuration](ai_configuration.md) for provider setup.

Public film imports with ready Wikipedia source context enqueue initial quality assignment on `registry_assignment`. The `bin/dev` worker includes that queue. Workers configured with an explicit queue list need to include it to process public imports.

Community notifications use the `default` queue, which `bin/dev` also consumes.

## Quality vocabulary seed

After applying migrations, load the 235 provisional quality definitions and nine category defaults:

```sh
bin/rails db:migrate
bin/rails db:seed
```

The seed uses `config/quality_vocabulary.yml`, packaged from the retained baseline with original names, definitions and exclusions. Run it once against an empty catalogue: it inserts nine categories and 235 qualities in one transaction. It does not match, update or reuse existing records. An error rolls back the whole load; investigate the cause before trying again. It creates no films or film-quality associations and makes no provider calls. Film import and initial quality assignment are available separately. Bulk catalogue execution remains to build.

Qualities use immutable names and database IDs; there is no separate quality key. Categories also use names and database IDs; their names remain editable. Both seed files are plain YAML lists, with vocabulary entries referring to category names during the one-time initial load. Existing name-only qualities remain valid; when a definition or exclusion is supplied, both must be nonblank. Definitions and exclusions remain editable within the same concept. 

## Import a selected TMDB film

Configure the application read-access token in your ignored local `.env` file (development), or process environment elsewhere:

```dotenv
TMDB_API_READ_ACCESS_TOKEN=your_read_access_token
```

The separate TMDB API key is not used. Restart Rails/console after changing development configuration. Do not commit tokens or print them in console output.

After applying migrations, explicitly import one already-selected movie ID from `bin/rails console`:

```ruby
film = Registry::CatalogueMaintenance::ImportFilm.call(tmdb_id: 348)
```

Use the real import for development data as well.

Use a positive Integer, not a title, string ID or URL. This single operation retrieves TMDB details/external IDs, follows the Wikidata English Wikipedia sitelink, verifies the article's Wikidata identity, and fetches its exact revision. Verified TMDB metadata is sufficient to create the film. When the Wikipedia source is unavailable or fails verification, the import stores an empty Wikipedia context and retains any verified Wikidata ID. Callers supply no Wikipedia page ID. Search remains a separate read-only selection step.

`ImportFilm` coordinates `FetchTmdbFilm` and `FetchWikipediaContext`. Both return validated data using the selected TMDB ID, without requiring or writing a Film. The orchestrator gathers both results before constructing a Film, then calls `Registry::Film#import_with_available_sources!(tmdb_data:, wikidata_id:, wikipedia_context:)` for one atomic save. Film owns validation and field assignment through explicit arguments; there are no retrieval blocks or external storage checks. The independent fetchers can later supply fresh data to explicit on-demand update operations.

Physical column order is `id`, `title`, `release_date`, `tmdb_id`, `tmdb_metadata`, `wikidata_id`, `wikipedia_context`, `created_at`, `updated_at`.

The film retains title, nullable source release date, TMDB metadata/provenance in `tmdb_metadata`, a nullable indexed `wikidata_id`, and source material in `wikipedia_context`. That packet contains TMDB/Wikidata/page identity, language, title, revision ID/timestamp/URL, article/history URLs, retrieval time, licence name/URL and ordered `source_paragraphs` (`id`, `section`, `text`). The provider-specific JSON columns store their packets directly, without redundant `tmdb`/`wikipedia` wrappers. The Wikipedia packet retains its language-specific page/revision identity as provenance and its entity identity matches `wikidata_id`; the language-independent Wikidata identity can remain when context is purged. The current importer fetches English Wikipedia only; other languages can later resolve their articles through the same entity. Paragraph references P1… belong to that revision. Extraction preserves prose/order, normalises HTML entities/whitespace and removes citations, tables, navigation, reference/cast sections and standalone blockquotes. Readiness requires complete provenance and narrative under Plot, Synopsis, Story or Premise; it does not certify semantic completeness.

Import creates a new film only. An existing TMDB identity raises `Registry::Errors::ImportIncomplete` with stage `persistence` and reason `existing_film` before provider calls. Concurrent imports of that identity produce one success and an explicit conflict for the other caller. Existing records are never resumed, merged, refreshed or silently returned. Different film identities can fetch in parallel. Invoke import outside caller-owned write transactions.

Invalid selected IDs raise `Registry::Errors::InvalidTmdbId`. Import failures use `Registry::Errors::ImportIncomplete` with a stage, reason and TMDB ID. A failed TMDB details fetch prevents creation. A handled Wikipedia lookup or verification failure uses the empty-context fallback. Once a film exists, re-importing the same TMDB ID returns an existing-film conflict. Wikipedia context refresh needs a separate source update workflow. Unrelated validation or database failures propagate and roll back the insert. The model can purge either source packet while retaining its identifier. Readiness is derived from the stored inputs.

Each client configures its fixed HTTPS host and response-size limit on the provider-agnostic `ProviderRequest`. The transport accepts host/path/parameters/headers, parses JSON and raises sanitized transport errors; clients own response shape, API error interpretation and import-stage translation. Adding a provider requires no transport registry or provider-specific branch. Requests use a descriptive User-Agent, 5-second connect and 10-second read/write timeouts, a 30-second total request limit, streamed body caps (TMDB 2 MiB, Wikimedia 8 MiB), and no automatic retries or HTTP redirects. API-level article redirects are accepted only with matching Wikidata identity and revision/page checks. Errors omit credentials and provider bodies.

Use this operation for source-only catalogue loading and on-demand import. It creates no Library entry, rating or quality assignment. Automated tests cover fake-HTTP search/selection/import, parsing, atomic creation, failures and explicit duplicate conflicts.

### Bulk source imports

Batch provider reads wherever the API supports it. Request TMDB movie details, videos and external IDs together with `append_to_response=videos,external_ids`. Batch Wikidata sitelinks and English Wikipedia identity, rights and latest-revision queries across titles. Fetch each selected article at its exact revision and retain Registry’s per-film validation and atomic write. The single-film importer accepts source clients from the batch runner. [TMDB append to response](https://developer.themoviedb.org/docs/append-to-response) · [MediaWiki revisions API](https://www.mediawiki.org/wiki/API:Revisions)

Use one shared request limit across Wikidata and Wikipedia, including retries and individual fallbacks. Recheck the provider’s current limit before each run. The staging import used up to three concurrent Wikimedia requests and spaced request starts at least 450 ms apart, about 133 per minute at most, below the published 200 per minute for clients identified by User-Agent alone. Honour `Retry-After` on throttled responses when available and back off before retrying. [Wikimedia rate limits](https://www.mediawiki.org/wiki/Wikimedia_APIs/Rate_limits)

Resume from the manifest IDs missing in the target Registry. Verify the final IDs and source readiness, and retain unresolved provider errors by film ID. Run JEV assignment separately when its cost and scope have been agreed.

## Search TMDB for a film

From Rails console, using the same ignored `TMDB_API_READ_ACCESS_TOKEN` configuration:

```ruby
page = Registry::Sources::SearchTmdbFilms.call(query: "The Thing")
page = Registry::Sources::SearchTmdbFilms.call(query: "The Thing", page: 2, primary_release_year: 1982)
page[:candidates]
```

Search returns `{ page:, total_pages:, total_results:, candidates: }`. Each candidate contains only `tmdb_id`, `title`, optional `original_title`, nullable `release_date` (a Date), and optional `original_language`. Provider order and distinct identities are preserved. An empty candidate list is a successful zero-result page. Malformed provider data rejects the whole page instead of returning partial selection data.

Queries must be nonblank Strings of at most 200 characters after outer whitespace is stripped; internal spacing and Unicode remain intact. Page must be an Integer from 1 through 500. Optional primary_release_year must be an Integer from 1000 through 9999: it filters upstream primary release year, rather than introducing another date/year value in our catalogue. Search requests one page in en-US with adult results excluded; it does not automatically fetch further pages or details, rank/select a film, or write any catalogue records.

After explicitly choosing a candidate, pass its integer TMDB ID to the existing import operation; import still retrieves and validates details independently:

```ruby
film = Registry::CatalogueMaintenance::ImportFilm.call(tmdb_id: selected_candidate.fetch(:tmdb_id))
```

Invalid inputs raise `Registry::Errors::InvalidTmdbSearch` before credential lookup or HTTP. Search retains `TmdbConfigurationError`, `InvalidTmdbResponse` and `TmdbUnavailable` errors, with the same sanitized timeout/retry policy. Search 404 is `TmdbUnavailable` with reason `http_error`; the complete import wraps movie-details 404 as `ImportIncomplete` (`tmdb`, `not_found`). Queries, credentials and provider bodies are omitted from routine logs and errors. Search and import are available through operator commands. Automated search checks use fake HTTP. Live title/year searches selected the five films used in the development import smoke test.

## Load canonical films with initial qualities

Seed the quality vocabulary first and configure the existing TMDB, Wikipedia/Wikidata and TypeSafe credentials. `LoadFilm` coordinates the create-only source import and initial assignment in one call:

```ruby
result = Registry::CatalogueMaintenance::LoadFilm.call(
  tmdb_id: selected_candidate.fetch(:tmdb_id),
  maximum_requests: 1,
  maximum_cost_usd: 0.02
)
result.fetch(:film)
result.fetch(:film_quality_eval).output
result.fetch(:film_qualities)
result.fetch(:warnings)
```

Request and cost limits apply to TypeSafe. They are required positive integer/finite decimal bounds; decimal amounts can be Integer, Float or BigDecimal values. Loading must start outside a database transaction. The source lookups finish before Film creation, and import commits before quality evaluation. With verified TMDB metadata and no ready Wikipedia context, the loader retains the film and returns a readiness warning without running assignment. An assessment/application failure propagates while retaining the imported Film and any recorded evaluation. Zero supported qualities return a localized warning with the completed evaluation and empty quality list. Existing identities are explicit conflicts, including concurrent loads. Assess an already imported film through the separate assignment operation below.

For an explicit batch, supply the complete TMDB ID list and its limits:

```ruby
summary = Registry::CatalogueMaintenance::LoadFilms.call(
  tmdb_ids: selected_tmdb_ids,
  maximum_films: 10,
  maximum_requests_per_film: 1,
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
result = Registry::QualityManagement::AssignInitialFilmQualities.call(film_id: film.id)
result.fetch(:film_qualities)
result.fetch(:film_quality_eval) # persisted evaluation, including request and response history
result.fetch(:film_quality_eval).output # complete persisted judgments, policies, call history and usage/cost
```

The service pins `jev-1.14.0` and uses the retained contextual-support questions. Code selects support >=0.60 within each category's maximum, descending support then Quality ID for ties. Category weights do not affect membership; ceilings are maxima. Initial assignment makes one bundled support request per film and collects no paragraph references. The request includes Wikipedia paragraphs and the stored TMDB overview when present, with separate source fields. New evaluations retain empty paragraph evidence with a not-collected policy; historical paragraph evidence remains readable. Explicit manual-review evidence collection is deferred and should use one bundled request unless measured cost or provider limits justify splitting. Model judgments still need inspection; support is not an enjoyment score or proof of correctness.

Accepted state is persisted as `Registry::FilmQuality` records with a `film_quality_eval` reference. Any collected paragraph evidence is stored only in the evaluation output; FilmQuality exposes no evidence reader. `Registry::FilmQualityEval` independently retains the evaluation: source/definition snapshots, ordered sent requests in `input`, received responses and call count in `output`, all probabilities, evidence, selection decisions (threshold/category ceiling/rank), model/policies, usage/cost and optional trace ID. The evaluation is immutable. FilmQuality associations show what Registry applied. Langfuse is diagnostic telemetry, not a runtime dependency for reading evaluation evidence. Manual and pre-existing associations may have no evaluation; no history is fabricated for them. There is no receipt or status column on Film.

Existing associations fail explicitly instead of being overwritten. Provider work precedes short write locks; changed sources/vocabulary or intervening assignments prevent application. A failed write rolls back every new association while retaining the completed evaluation and its failure outcome. Stale evaluations are retained but not applied. Provider failures retain a failed evaluation with partial answers, safe errors and attempted-call history; requests blocked before sending are identified and excluded from the provider-call count. Usage/cost totals include validated responses only, and incomplete usage is flagged. Unparseable/transport failures have no JSON response to retain.

Requests have size/time/call/cost bounds and no automatic retries or long-context opt-in; the default client reserves a conservative cost allowance before each call and reconciles actual input-token usage afterward.

For an explicit batch, enqueue the Registry job with selected IDs:

```ruby
Registry::AssignInitialFilmQualitiesJob.perform_later(film_ids: selected_film_ids)
Registry::Film.without_qualities # films needing assessment or manual intervention
```

The job logs localized structured warnings for each film with zero qualities, an assessment error or an unexpected per-film failure, then continues with later films. Zero supported qualities retain a completed evaluation with an empty accepted association list; an explicit later request may assess the film again. The review query also includes films not assessed yet. Insufficient coverage currently means zero, matching that query; no higher minimum or category quota is inferred. The job does not schedule itself or automatically process the catalogue.
