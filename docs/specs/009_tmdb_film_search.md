# 009 — Search TMDB for film selection

Status: Ready for review  
Owner: Film knowledge / search

## Goal

Return one page of disambiguated TMDB movie candidates for an explicit title query, so a caller can select a TMDB ID for the existing task 008 import operation. Depends on task 008, merged via PR #18. Consumes no other domain contract. Search performs no catalogue writes and makes no selection on behalf of a viewer.

Read the implementation plan, tasks 007/008, product brief section 5.1/5.1.1 and architecture brief section 9 before implementation.

## Scope

### Search operation and result

- Provide `FilmKnowledge::SearchTmdbFilms.call(query:, page: 1, primary_release_year: nil)`. Require a String query that is nonblank after stripping outer whitespace and at most 200 characters; preserve internal spacing, Unicode and punctuation. Require an Integer page from 1 through 500 (our explicit bound), and an optional Integer primary_release_year from 1000 through 9999. Reject invalid inputs with FilmKnowledge::InvalidTmdbSearch (ArgumentError) before credential access, network calls or writes. Do not infer a year from the query or coerce arbitrary strings.
- Make one request to the fixed HTTPS `/3/search/movie` endpoint, encoding query parameters with standard URI handling. Send query, requested page, language=en-US and include_adult=false; send primary_release_year only when supplied. This parameter filters upstream; it is not a separate year value returned by TMDB or a new Film column. Do not send region/year parameters that change the agreed date convention.
- Return a plain result hash `{ page:, total_pages:, total_results:, candidates: }`. Each candidate contains only `{ tmdb_id:, title:, original_title:, release_date:, original_language: }`. Preserve provider ordering; keep distinct IDs separate even when titles/date match. Do not add ranking, choose the first result, infer horror eligibility from genre labels, or consult viewer activity.
- Require positive Integer candidate IDs and nonblank String titles. Missing/null original_title or original_language maps to nil; supplied values must be Strings. Map missing/null/empty release_date to nil; otherwise require a real ISO YYYY-MM-DD date and return a Date, using the task 008 date convention. Display/filter years can later be derived from that date; do not return a fabricated date or persist a year.
- Require a JSON object with an Array results field and Integer page/total_pages/total_results values. The returned page must match the request and totals must be nonnegative. Accept an empty page, including page=1/total_pages=0/total_results=0. Malformed envelopes or any malformed candidate reject the entire response with InvalidTmdbResponse rather than silently returning partial selection data. Ignore unused payload fields.
- Return only the requested provider page, without automatically fetching further pages or movie details. Do not call the importer. A selected candidate's tmdb_id can subsequently be passed explicitly to ImportTmdbFilm; import still fetches/validates details rather than trusting a prior search response.

### Provider behaviour and failures

- Extend the existing narrow TmdbClient with a movie-search operation. Reuse its fixed host, bearer token configuration, TLS, finite 5-second connect/10-second read/write timeouts, no redirects and no automatic retries. Share only concrete request handling needed by these two operations; do not create a generic HTTP/provider framework. Preserve the public movie-details/import behaviour.
- Use existing TmdbConfigurationError, TmdbUnavailable and InvalidTmdbResponse semantics. Missing configuration fails before HTTP. Treat 401/403 as authentication, 429 as rate_limited, timeouts as timeout, transport/protocol failures as transport, and redirects/other non-success responses (including search 404) as http_error. A valid zero-result response is success, not a not-found exception. Preserve movie-details 404 => TmdbNotFound.
- Query strings, credentials, Authorization headers and raw provider bodies must not appear in routine application logs or surfaced exception messages/causes. Use static developer diagnostics or symbolic reasons; do not include the supplied query in errors. No user-facing UI/copy is introduced here.
- Document console invocation and paging/year-filter semantics in README. No automatic search during boot/seeding or import; no live request is needed for verification.

## Scope restrictions

- Film knowledge only. No Identity, Library, Ratings or Recommendations changes, session/user checks, viewer history, guest retention, application UI/routes, search form or import button. HTTP wiring must belong to a later explicitly scoped task, not be hidden in another domain.
- No Film schema/index changes, catalogue writes, refresh, metadata enrichment, media URLs/overviews, credit lookup, quality/analysis/JEV processing, autocomplete, local full-text search, caching, background jobs or multi-provider abstraction. No per-result requests or automatic import.
- Keep task 008's import and failure contracts compatible. Limit refactoring to request handling shared by details/search; do not move unrelated Identity infrastructure or rewrite the film sample loader.
- Tests use deterministic fake HTTP and isolated test data only. Do not read/print the live token, run live searches/imports, sign up/contact providers, purchase access, deploy, publish or merge during implementation. Optional live verification requires separate owner authorization. Record its absence honestly without adding a provider-approval gate.

## Acceptance criteria

- **AC1:** Valid searches return useful, separate selection candidates without persistence.  
  Check: Fake results containing remakes/shared titles, translated/original titles and unknown dates; verify exact normalized fields, provider order, distinct IDs and pagination totals. Valid zero results return an empty candidates array. Assert no Film writes and no details/import calls.  
  Result: Passed — fake search pages preserve provider order, distinct same-title/date IDs, translated/original titles/language, requested pagination and null unknown dates. The returned candidate keys are exact; unused overview/media fields are excluded. Tests assert no Film count changes and exactly one search request, with no details/import requests; a valid zero-result envelope returns an empty array.
- **AC2:** Input and payload boundaries are explicit.  
  Check: Cover blank/non-String/oversized queries, whitespace/Unicode handling, invalid page/year types and limits before configuration/HTTP. Validate missing/null/empty dates, valid leap dates and invalid dates/types. Reject bad envelopes, IDs/titles/optional metadata and mismatched pages without partial output.  
  Result: Passed — tests cover non-String/blank/oversized/invalid-encoding queries, page/year types and limits, outer-whitespace-only normalization, 200 Unicode characters and accepted bounds. Missing/null/empty dates, valid leap dates, malformed calendar dates, IDs/titles/optional metadata, invalid envelopes and mismatched pages are covered. An invalid candidate after a valid one rejects the whole page.
- **AC3:** Search shares bounded, credential-safe provider access without regressing import.  
  Check: Fake HTTP verifies exact endpoint, safe encoding of punctuation/ampersands/Unicode, optional primary_release_year, explicit page/language/adult parameters and one request. Cover credentials, 401/403/429/404/5xx, redirects, transport failures and malformed JSON; assert expected failure reasons and no secret/query/body markers in errors/causes or captured logs. Re-run all task 008 client/import/concurrency tests, including movie 404 behaviour.  
  Result: Passed — fake HTTP verifies the fixed TLS endpoint, safe round-trip encoding of Unicode/ampersands/punctuation, explicit page/language/include_adult and omission/inclusion of primary_release_year. Timeout/retry settings remain unchanged. Tests cover missing credentials, HTTP/redirect/transport/protocol/JSON failures; full exceptions and captured Rails logs exclude query, token, header and raw-body markers. All task 008 provider/import/concurrency tests pass, including details 404 => TmdbNotFound versus search 404 => http_error.
- **AC4:** The outcome remains scoped and passes repository verification.  
  Check: Run focused search/provider/import tests, `RAILS_ENV=test bin/rails zeitwerk:check`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` and `git diff --check`. Inspect changes for cross-domain/schema/UI/persistence additions; record README console steps and actual evidence here.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/film_knowledge`: 27 tests, 824 assertions, zero failures/errors/skips. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading (existing mail-preview exclusion remains). `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 198 tests, 2,431 assertions, zero failures/errors/skips; RuboCop 109 files clean; gem/importmap audits no vulnerabilities; Brakeman zero warnings/errors. `git diff --check` passed. No schema, UI, catalogue writes or other-domain implementation changes were added; README contains console and explicit-selection/import examples.

## Implementation notes

Implemented SearchTmdbFilms and InvalidTmdbSearch, with normalized input/payload validation and one-page candidate mapping. TmdbClient now shares its concrete fixed-host request handling between movie details and search; the new search path retains the existing timeout, retry and credential-sanitization policy. Query validation runs before credential lookup. No generic transport framework, dependency, model, schema or UI changes were introduced.

The first focused runs exposed an invalid test fixture that accidentally became valid after merging defaults, and a random-order test dependency on Net::HTTP being loaded. Corrected the fixture and explicitly required net/http in the existing fake-HTTP test helper; the final focused and full runs above pass. No live token was inspected or printed, no authenticated provider request occurred, and development/production data was untouched. Live search compatibility remains unverified. No material scope deviation.

Reproduce verification from the repository root:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/film_knowledge
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
git diff --check
```

This implementation exposes selection data only; UI and catalogue expansion remain separate. The 200-character query and 500-page bounds are application choices, not guarantees about provider coverage or limits. The optional primary_release_year parameter narrows provider search; primary release year is not an independently returned movie field.

References checked 20 October 2026: [TMDB movie search](https://developer.themoviedb.org/reference/search-movie) documents query, page, language, include_adult and primary_release_year; [search/details workflow](https://developer.themoviedb.org/docs/search-and-query-for-details) shows list results with IDs, titles, original language/title and release_date, followed by explicit details lookup. No authenticated search was performed while drafting.

Owner authorization: Spec approved on 20 October 2026.

Owner acceptance / merge: Pending review and merge.
