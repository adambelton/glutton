# 008 — Import one selected TMDB film

Status: Merged  
Owner: Film knowledge / import

## Goal

Given an explicitly selected TMDB movie ID, return the existing Glutton Film or fetch and persist one minimal film identity without duplicates. Depends on task 007 (merged via PR #17). Consumes no other domain contract. Search is task 009; this task does not select a film on a viewer's behalf.

Read the implementation plan, task 007 spec, product brief sections 5.1/5.1.1 and architecture brief section 9 before implementation.

## Scope

### Import operation and consistency

- Provide `FilmKnowledge::ImportTmdbFilm.call(tmdb_id:)`, accepting a positive Integer and returning a persisted Film. Reject invalid input before any network request or write; do not coerce arbitrary strings, infer IDs from titles, or accept URLs.
- Look up tmdb_id first. If already present, return the existing Film unchanged without fetching TMDB or requiring credentials. This is import, not refresh: preserve existing local titles, dates and metadata, including task 007 samples. Never merge a film without an external ID based on a matching title/date.
- For a missing ID, fetch exactly that movie's details through a narrow Film knowledge TMDB client, outside any database transaction or lock. Require a matching positive integer response ID and a nonblank string title. Reject mismatched identities or malformed responses before writing.
- Map TMDB title, ID and primary release_date to existing Film columns. Missing/null/empty release_date maps to nil; a supplied nonempty value must be an actual ISO YYYY-MM-DD calendar date, otherwise reject the response. No separate year column, regional release-date lookup, inferred January 1 or earliest-premiere claim.
- Store only a supplied string original_title plus minimal source provenance in metadata: a tmdb object with fetched_at (UTC ISO8601) and language (en-US). A missing/null original title is omitted; a non-string value is invalid. Do not duplicate ID/title/release_date in JSONB or store the full provider payload. Ignore unused response fields.
- Insert one validated Film atomically. Repeated or concurrent imports of the same ID return the same persisted internal identity; different IDs remain different works even with identical title/date. Use task 007's unique index; handle only the specific duplicate-identity race by re-reading the winner. Do not hide unrelated validation or persistence errors. A failed import leaves no partial film. A failed request can be retried explicitly; do not create an import-history table or retry framework.

### TMDB request and failure behaviour

- Use the fixed HTTPS movie-details endpoint `https://api.themoviedb.org/3/movie/{movie_id}` with language=en-US and an application read-access bearer token from `TMDB_API_READ_ACCESS_TOKEN`. Do not accept an arbitrary host/URL or send credentials in query strings. Use a small adapter and existing/standard Ruby HTTP support; no generic provider abstraction or new HTTP dependency without a concrete need.
- Set finite connect/read timeouts (5 and 10 seconds), disable automatic retries and do not follow redirects. Make at most one request per import attempt. No transaction or row lock spans the network call.
- Missing/blank configuration raises a sanitized configuration error before making the request. Use FilmKnowledge::InvalidTmdbId (ArgumentError), FilmKnowledge::TmdbConfigurationError, FilmKnowledge::TmdbNotFound, FilmKnowledge::TmdbUnavailable and FilmKnowledge::InvalidTmdbResponse. TmdbUnavailable exposes a symbolic reason such as authentication, rate_limited, timeout, transport or http_error. Preserve unexpected database failures rather than wrapping every exception. These are local Film knowledge operation failures, not a new cross-domain contract.
- Treat 404 as not found; 401/403 as provider authentication failure; 429 as rate limited; transport failures/timeouts, redirects and other non-success statuses as provider failure. Provider failures may expose a safe symbolic reason to developer callers, never the token, Authorization header, raw response body or credential-bearing exception message. No automatic sleep/retry on 429.
- Successful HTTP responses must decode to a JSON object and pass identity/field checks. No write occurs on HTTP, decoding or mapping failure. Document how to configure credentials and invoke from Rails console; no automatic import during boot/seeding.

## Scope restrictions

- Film knowledge only. No Identity/Library/Ratings/Recommendations changes, user associations, guest-retention work, UI/routes, TMDB search, CLI bulk import, jobs, refresh/enrichment or media fetching.
- No JEV, analyses, qualities, assessments, synopsis/credits/artwork/trailer ingestion, full 50-film seed or additional providers. Do not send TMDB content to AI services.
- No new tables, Film columns, metadata indexes, custom metadata accessors or generic integration layer. Existing metadata is preserved for already-imported films.
- Automated tests must use deterministic fake HTTP responses and isolated test records; no live API credentials, network calls or real-data imports are required to pass. Do not sign up for TMDB, contact providers, purchase access, deploy, publish or run an import against development/production as part of this task. Optional live verification requires separate owner authorization and an owner-provided credential; absent live verification is a recorded limitation, not a reason to claim it ran.
- The existing decision to proceed with TMDB remains in force; do not add a new provider-approval gate. This task does not settle later refresh/retention/licensing or public attribution presentation.

## Acceptance criteria

- **AC1:** New import persists exactly the selected identity and minimal fields.  
  Check: Fake a valid movie-details response; assert returned Film, mapped title/date, original-title metadata, source timestamp/language and exclusion of unrelated payload fields. Cover unknown dates/titles, actual calendar-date validation, ID mismatch, invalid JSON/top-level shapes and invalid field types. All failures leave the database unchanged.  
  Result: Passed — focused import/client tests cover exact identity/title/date/provenance mapping, optional/null original title behaviour, omission of unused data, missing/null/empty dates, valid leap date and malformed ID/title/date/JSON/response shapes. Failures leave no Film. Focused final run: 14 tests, 365 assertions, zero failures/errors/skips.
- **AC2:** Existing and concurrent identities deduplicate without overwriting local data.  
  Check: Repeated import returns the same ID; existing film with edited title/date/metadata returns unchanged with no HTTP/configuration access. Separate PostgreSQL connections importing the same previously absent ID return one Film; distinct IDs with identical title/date remain distinct. Inject persistence failure to verify no partial write and a later explicit retry succeeds.  
  Result: Passed — existing films return unchanged without client/configuration access. Two separate PostgreSQL connections are synchronized after uniqueness validation to exercise a real unique-index collision and return one ID. A second race commits the winner during fetch and verifies validation-race recovery preserves its metadata. Distinct/unlinked identities remain separate. An injected after-create persistence failure rolls back, then an explicit retry succeeds; an unrelated primary-key collision propagates.
- **AC3:** Provider/configuration failures are bounded, explicit and credential-safe.  
  Check: Fake requests verify exact fixed endpoint, language, bearer header, finite timeouts, no redirects and no automatic retries. Cover invalid IDs, missing credentials, 401/403/404/429/5xx, redirects and transport failures; assert exception types/reasons, no writes and no secret/raw-body markers in surfaced errors or captured logs.  
  Result: Passed — fake HTTP asserts host/port/path, en-US, bearer/Accept headers, TLS, 5-second connect and 10-second read/write timeouts, max_retries=0 and one request. Tests cover bad IDs/configuration, 401/403/404/429/redirects/5xx, timeouts/socket/SSL/protocol failures and invalid/missing JSON bodies. Sanitized full exception chains and captured Rails logs contain neither fake credentials nor raw provider-body markers. No live credentials were read by the fake clients.
- **AC4:** Import remains local to Film knowledge and repository checks pass.  
  Check: Run focused client/import tests including concurrency, `RAILS_ENV=test bin/rails zeitwerk:check`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` and `git diff --check`. Inspect diff for cross-domain changes and record reproducible configuration/console steps in README. Record live-verification limits honestly.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/film_knowledge/tmdb_client_test.rb test/services/film_knowledge/import_tmdb_film_test.rb test/services/film_knowledge/import_tmdb_film_concurrency_test.rb`: 14 tests/365 assertions. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 188 tests/1,992 assertions, no failures/errors/skips; RuboCop 105 files clean; gem/importmap audits no vulnerabilities; Brakeman zero warnings/errors. `git diff --check` passed. No model/schema or other-domain implementation changed.

## Implementation notes

Implemented ImportTmdbFilm, a small Net::HTTP TmdbClient and the scoped failure classes. The importer checks existing identity before client/configuration access, validates the selected payload, maps only agreed fields, and saves inside a short transaction/savepoint after network completion. Duplicate recovery is limited to the named TMDB unique index or the exact tmdb_id uniqueness validation; unrelated validation/database errors propagate. No table, column, gem or cross-domain implementation changes were made.

README documents ignored local token configuration, console invocation, failure reasons, no automatic retries and preservation of existing films. Tests inject fake HTTP at the client boundary and use isolated PostgreSQL records. Concurrency tests clean only their own film ID. No live API request, development/production import, deployment or publication occurred. The owner reported the read-access token is configured locally; it was not inspected or printed. Live response compatibility remains unverified. A write timeout of 10 seconds supplements the agreed connect/read bounds. No material scope deviation.

Reproduce verification from the repository root:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/film_knowledge/tmdb_client_test.rb test/services/film_knowledge/import_tmdb_film_test.rb test/services/film_knowledge/import_tmdb_film_concurrency_test.rb
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
git diff --check
```

Provider references checked 20 October 2026: [movie details](https://developer.themoviedb.org/reference/movie-details), [search/details workflow and response example](https://developer.themoviedb.org/docs/search-and-query-for-details), [rate limiting](https://developer.themoviedb.org/docs/rate-limiting). The details reference documents a bearer Authorization header and language default en-US. The rate-limit guidance requires respecting 429; this task surfaces it without retry infrastructure. No authenticated request has been made.

Owner authorization: Spec approved on 20 October 2026.

Owner acceptance / merge: Owner approved publication and merge after hosted CI passes. Merged via [PR #18](https://github.com/adambelton/glutton/pull/18) on 20 October 2026 at 10:16:48 UTC after Repository checks passed for commit `96339987e5a9738b293ba242e1cd8458ae79d3fc`; squash merge `b367a1b629c3d450e3e2707176c9d5ae993b394e`.
