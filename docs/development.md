# Development guide

## Setup and verification

Use the Ruby version in [`.ruby-version`](../.ruby-version), the Bundler version in [`Gemfile.lock`](../Gemfile.lock), PostgreSQL 17 and Chrome for the browser suite. PostgreSQL must be running and the local role must be able to create databases. Rails honours the standard PostgreSQL connection environment variables.

```sh
bin/setup --skip-server
bin/dev
```

Open [localhost:3000](http://localhost:3000). `bin/dev` builds styles and starts Rails and GoodJob together. Use `bin/rails tailwindcss:watch` for live CSS builds. Manual work uses `glutton_development` and automated tests use `glutton_test`. Check any `DATABASE_URL` override before setup or test commands.

Use `bin/ci` for style, security, autoloading, Rails tests and the headless Chrome suite. GitHub Actions runs the same checks on pull requests and pushes to main. Dependency audits use network access. The `/up` endpoint checks whether Rails boots.

## Accounts and mail

Set `APP_ORIGIN` to the actual application origin for registration and recovery links. Development supports localhost and the `glutton.local` alias. For the alias, map `glutton.local` to `127.0.0.1` in the local hosts file. Production uses an HTTPS origin.

Development uses in-memory mail delivery by default. Use `/rails/mailers` for local previews. For authorized live delivery, set `MAIL_DELIVERY=resend`, `MAIL_FROM` to a verified sender and `RESEND_API_KEY` in the ignored development environment or production process environment. Tests use local delivery.

Bootstrap the first superuser directly in the database after verifying the registered account. Existing superusers can grant or revoke access with `Identity::AccountAdministration::GrantSuperuser` and `Identity::AccountAdministration::RevokeSuperuser`, supplying `user_id:` and `actor_user_id:`.

Run `bin/rails identity:cleanup_expired` for one bounded pass over expired guests and pending registrations. Guest deletion cascades through viewer-owned activity and preserves shared films. Expiry blocks access independently of cleanup. Production scheduling for this command remains open.

## Background processing

See [domain event operations](domain_event_operations.md) for worker configuration and delivery diagnostics. GoodJob schedules taste-profile refresh every 15 minutes in production. Superusers can inspect and queue a refresh of their own profile from Account. Operators can process pending requests from the console with `Ratings::TasteProfiling::ProcessProfileRefreshes.call`. See [AI configuration](ai_configuration.md) for provider setup.

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
film = Registry::CatalogueMaintenance::ImportFilm.call(tmdb_id: 348)
```

Use the real import for development data as well.

Use a positive Integer, not a title, string ID or URL. This single operation retrieves TMDB details/external IDs, follows the Wikidata English Wikipedia sitelink, verifies the article's Wikidata identity, and fetches its exact revision. It returns only when `film.has_source_context?` is true. Callers supply no Wikipedia page ID. Search remains a separate read-only selection step.

`ImportFilm` coordinates `FetchTmdbFilm` and `FetchWikipediaContext`. Both return validated data using the selected TMDB ID, without requiring or writing a Film. The orchestrator gathers both results before constructing a Film, then calls `Registry::Film#import!(tmdb_data:, wikipedia_context:)` for one complete save. Film owns validation and field assignment through explicit arguments; there are no retrieval blocks or external storage checks. The independent fetchers can later supply fresh data to explicit on-demand update operations.

Physical column order is `id`, `title`, `release_date`, `tmdb_id`, `tmdb_metadata`, `wikidata_id`, `wikipedia_context`, `created_at`, `updated_at`.

The film retains title, nullable source release date, TMDB metadata/provenance in `tmdb_metadata`, a nullable indexed `wikidata_id`, and source material in `wikipedia_context`. That packet contains TMDB/Wikidata/page identity, language, title, revision ID/timestamp/URL, article/history URLs, retrieval time, licence name/URL and ordered `source_paragraphs` (`id`, `section`, `text`). The provider-specific JSON columns store their packets directly, without redundant `tmdb`/`wikipedia` wrappers. The Wikipedia packet retains its language-specific page/revision identity as provenance and its entity identity matches `wikidata_id`; the language-independent Wikidata identity can remain when context is purged. The current importer fetches English Wikipedia only; other languages can later resolve their articles through the same entity. Paragraph references P1… belong to that revision. Extraction preserves prose/order, normalises HTML entities/whitespace and removes citations, tables, navigation, reference/cast sections and standalone blockquotes. Readiness requires complete provenance and narrative under Plot, Synopsis, Story or Premise; it does not certify semantic completeness.

Import creates a new film only. An existing TMDB identity raises `Registry::Errors::ImportIncomplete` with stage `persistence` and reason `existing_film` before provider calls. Concurrent imports of that identity produce one success and an explicit conflict for the other caller. Existing records are never resumed, merged, refreshed or silently returned. Different film identities can fetch in parallel. Invoke import outside caller-owned write transactions.

Invalid selected IDs raise `Registry::Errors::InvalidTmdbId`. Known provider/coverage failures raise `Registry::Errors::ImportIncomplete`, exposing `stage` (`tmdb`, `wikidata`, `wikipedia`, `persistence`), `reason` and `tmdb_id`. Reasons distinguish duplicate film, missing identity/article, conflicting identity, insufficient narrative, configuration/authentication, rate limits, malformed/oversized responses, timeout and transport failure. Both source fetches must succeed before the initial insert; a failure creates no partial film. Fix the cause and retry explicitly. Unrelated validation/database failures propagate and roll back the insert. Source updates will be a separate workflow using the same fetchers; import never overwrites existing data. `tmdb_metadata` and `wikipedia_context` may be empty objects so later explicit model operations can purge either source while retaining its identifier. Purging does not permit re-import of that existing identity; readiness remains derived from the available inputs.

Each client configures its fixed HTTPS host and response-size limit on the provider-agnostic `ProviderRequest`. The transport accepts host/path/parameters/headers, parses JSON and raises sanitized transport errors; clients own response shape, API error interpretation and import-stage translation. Adding a provider requires no transport registry or provider-specific branch. Requests use a descriptive User-Agent, 5-second connect and 10-second read/write timeouts, a 30-second total request limit, streamed body caps (TMDB 2 MiB, Wikimedia 8 MiB), and no automatic retries or HTTP redirects. API-level article redirects are accepted only with matching Wikidata identity and revision/page checks. Errors omit credentials and provider bodies.

This operation serves both future bulk catalogue loading and on-demand import. It is not called during boot or vocabulary seeding and creates no Library entry, rating or quality assignment. Automated tests cover fake-HTTP search/selection/import, parsing, atomic creation, failures and explicit duplicate conflicts. A live development smoke test passed for five horror films through TMDB, Wikidata and Wikipedia; wider coverage and operational throughput remain unverified.

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

Request and cost limits apply to TypeSafe. They are required positive integer/finite decimal bounds; decimal amounts can be Integer, Float or BigDecimal values. Loading must start outside a database transaction. Both sources are acquired before Film creation, and import commits before quality evaluation. A source failure creates no Film. An assessment/application failure propagates while retaining the imported Film and any recorded evaluation. Zero supported qualities return a localized warning with the completed evaluation and empty quality list. Existing identities are explicit conflicts, including concurrent loads. Assess an already imported film through the separate assignment operation below.

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

The service pins `jev-1.14.0` and uses the retained contextual-support questions. Code selects support >=0.60 within each category's maximum, descending support then Quality ID for ties. Category weights do not affect membership; ceilings are maxima. Initial assignment makes one bundled support request per film and collects no paragraph references. New evaluations retain empty paragraph evidence with a not-collected policy; historical paragraph evidence remains readable. Explicit manual-review evidence collection is deferred and should use one bundled request unless measured cost or provider limits justify splitting. Model judgments still need inspection; support is not an enjoyment score or proof of correctness.

Accepted state is persisted as `Registry::FilmQuality` records with a `film_quality_eval` reference. Any collected paragraph evidence is stored only in the evaluation output; FilmQuality exposes no evidence reader. `Registry::FilmQualityEval` independently retains the evaluation: source/definition snapshots, ordered sent requests in `input`, received responses and call count in `output`, all probabilities, evidence, selection decisions (threshold/category ceiling/rank), model/policies, usage/cost and optional trace ID. The evaluation is immutable. FilmQuality associations show what Registry applied. Langfuse is diagnostic telemetry, not a runtime dependency for reading evaluation evidence. Manual and pre-existing associations may have no evaluation; no history is fabricated for them. There is no receipt or status column on Film.

Existing associations fail explicitly instead of being overwritten. Provider work precedes short write locks; changed sources/vocabulary or intervening assignments prevent application. A failed write rolls back every new association while retaining the completed evaluation and its failure outcome. Stale evaluations are retained but not applied. Provider failures retain a failed evaluation with partial answers, safe errors and attempted-call history; requests blocked before sending are identified and excluded from the provider-call count. Usage/cost totals include validated responses only, and incomplete usage is flagged. Unparseable/transport failures have no JSON response to retain.

Requests have size/time/call/cost bounds and no automatic retries or long-context opt-in; the default client reserves a conservative cost allowance before each call and reconciles actual input-token usage afterward.

For an explicit batch, enqueue the Registry job with selected IDs:

```ruby
Registry::AssignInitialFilmQualitiesJob.perform_later(film_ids: selected_film_ids)
Registry::Film.without_qualities # films needing assessment or manual intervention
```

The job logs localized structured warnings for each film with zero qualities, an assessment error or an unexpected per-film failure, then continues with later films. Zero supported qualities retain a completed evaluation with an empty accepted association list; an explicit later request may assess the film again. The review query also includes films not assessed yet. Insufficient coverage currently means zero, matching that query; no higher minimum or category quota is inferred. The job does not schedule itself or automatically process the catalogue.
