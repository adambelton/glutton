# 007 — Minimal film catalogue

Status: Ready for review  
Owner: Film knowledge / catalogue

## Goal

Persist Glutton-owned film identities and minimal identifying metadata, with a small repeatable local sample that later Library and Ratings tasks can reference. Depends on task 001; consumes no other domain contracts.

Read the implementation plan, product brief sections 4, 5.1 and 8, and architecture brief sections 3, 4 and 8 before implementation.

## Scope

- Add a plain Rails Film model and films table with a stable internal primary key, title, nullable release_date, optional TMDB movie ID, JSONB metadata (non-null object, default {}) and timestamps. Require a nonblank title; require any TMDB ID to be a positive integer. Enforce uniqueness of a present TMDB ID in both model validation and a database unique index.
- Keep different works distinct even when titles or release dates match. Do not use title/year uniqueness, fuzzy matching or fabricated external identifiers. A missing release date is unknown, not an invented January 1 date. Store one release date and derive year filtering with a date range; do not add a separate year column. The release date represents the source primary release date when imported, not an independently verified earliest premiere. Original title and other non-query metadata belong in metadata; do not duplicate identity/date columns there or add speculative JSON indexes or accessors.
- Store titles as film metadata, not locale keys. Use symbolic validation errors and English locale entries for any new application-authored validation copy.
- Add a small, explicit local sample of three recognisable films with known distinct TMDB identities, using identity/title/date data only. Record source URLs and identify this as development sample metadata, not reviewed analyses or a validated production seed. Verify those identity fields against sources during implementation. Sample dates may remain null until a primary release date is verified; keep existing local dates/metadata untouched.
- Provide an explicit development-only sample command, separate from automatic application boot and ordinary production seeding. Repeated execution must reuse films by TMDB ID, preserve internal IDs and leave existing film metadata and unrelated records unchanged. Fail clearly outside development before writing. Test the sample-loading operation against isolated test records; do not populate the owner's development database during verification.
- Use ordinary Rails persistence and a small sample-loading operation only where needed for repeatability. No generic catalogue service or abstract provider interface.

## Scope restrictions

- Film knowledge only. Do not change Identity, Library, Ratings or Recommendations, add user associations, or invent cross-domain contracts. Film records contain no viewer activity and require no guest-retention changes.
- No JEV setup, model calls, quality vocabulary, quality validation, film–quality associations, analyses, research generation or analysis schema. Qualities remain provisional and expected to evolve; validating the starting vocabulary is not a prerequisite for this task.
- No complete 50-film seed, search/import HTTP flow, TMDB API client/key/signup, external communication, paid service, media download, posters, trailers, synopsis, credits, enrichment, jobs or deployment. Task 008 owns selected-identity import; task 009 owns search under the existing sequence.
- No application UI, routes or navigation. Do not overwrite unrelated project documents or existing seed content. No development/production data writes as part of implementation verification.

## Acceptance criteria

- **AC1:** Films retain stable Glutton identity and minimal metadata without conflating distinct works.  
  Check: Model tests cover valid minimal/full records, unknown release date, blank title, invalid TMDB IDs, JSON object round-tripping/default/shape validation, date-range year filtering at year boundaries, and two distinct films sharing a title/date. Verify persistence and reload.  
  Result: Passed — focused tests persist/reload minimal and full records, preserve literal titles, allow same-title/date works, and test nullable dates. JSONB defaults are independent objects, nested values round-trip, invalid shapes fail model validation/database checks, and a half-open date range selects exactly one release year including boundary dates.
- **AC2:** External identity deduplication survives bypassing model validation.  
  Check: Model tests reject duplicate TMDB IDs and accept multiple films without one; a direct database write proves the unique index rejects a duplicate present ID.  
  Result: Passed — validation rejects duplicate TMDB IDs; a direct insert inside a savepoint raises ActiveRecord::RecordNotUnique. Multiple films with no TMDB ID are accepted.
- **AC3:** The sample is explicit, repeatable and limited to local development.  
  Check: Isolated tests run the sample operation twice and confirm exactly three sample identities with unchanged internal IDs; an existing sample identity with edited metadata and an unrelated film remain unchanged. Verify the command's environment guard rejects non-development execution before writes. Record the three source URLs and identity checks here. Do not run the command against the owner's development database.  
  Result: Passed — sample tests repeat with stable IDs and unchanged local title/date/nested metadata, preserve unrelated records and exercise the actual task guard under test/production without writes. Sample original titles are stored in metadata; release dates remain null. No development sample was loaded.
- **AC4:** The change fits Rails conventions and existing checks.  
  Check: Run focused film/sample tests, `bin/rails zeitwerk:check`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` and `git diff --check`. Check any new validation copy with missing-translation errors enabled. Record actual commands/results, update the plan and mark completed implementation Ready for review.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_test.rb test/services/film_knowledge/load_development_sample_test.rb`: 10 tests, 76 assertions, no failures/errors/skips. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading (existing mail-preview exclusion remains). `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 174 tests, 1,627 assertions, no failures/errors/skips; RuboCop 94 files clean; gem/importmap audits no vulnerabilities; Brakeman zero warnings/errors. Locale full-message checks pass under strict missing translations. `git diff --check` passed.

## Implementation notes

Implemented Film with title, one nullable release_date, optional TMDB identity, JSONB metadata and timestamps. Original title lives in metadata. Metadata must be an object at both model/database levels; it defaults to {}. No release-year column, speculative indexes or metadata accessors were added. Year filtering is verified using a date-range query. Symbolic Rails validations and the unique TMDB index remain. Added English attribute labels, a small transactional FilmKnowledge::LoadDevelopmentSample operation and `film_knowledge:load_sample` rake task. Existing sample identities are looked up before creation, so local edits and IDs survive repeats. README documents explicit local invocation and restrictions; db/seeds.rb and application boot are unchanged.

Sample identity evidence, checked 20 October 2026:

- Alien, TMDB 348: [TMDB identity](https://www.themoviedb.org/movie/348-alien?language=pt-MZ) and [studio title/release reference](https://www.20thcenturystudios.com/movies/alien). The canonical English TMDB page could not be fetched; the indexed localized record identifies Alien (1979), ID 348.
- The Thing, TMDB 1091: [TMDB identity/original title](https://www.themoviedb.org/movie/1091-the-thing?language=es-MX) and [ACMI catalogue identity](https://www.acmi.net.au/works/61585--the-thing/). The canonical English TMDB page could not be fetched; the indexed localized record exposes original title The Thing and the ACMI record identifies tmdb-movie-1091.
- Get Out, TMDB 419430: [TMDB title and identity](https://www.themoviedb.org/movie/419430-get-out), read directly.

These sources verify the selected works, not a production research corpus. Sample titles and original titles use the English original work names. All three sample release dates remain null until primary release dates are verified. The source primary date is a provider convention, not a claim of earliest premiere. No invented dates, API credentials, analysis text or media are included. This small sample is not a representative or validated 50-film seed.

Reproduce checks from the repository root:

```sh
RAILS_ENV=test bin/rails db:migrate
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_test.rb test/services/film_knowledge/load_development_sample_test.rb
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
git diff --check
```

The initial focused run exposed Rails blank-ID casting and a create-or-find interaction with uniqueness validation; the final implementation uses ordinary optional-ID casting and find-or-create lookup, and the repeated focused/full runs above pass. No development/production database writes or sample loading occurred during verification. Tests temporarily select the development environment only around the sample operation while retaining their isolated test database connection. Schema migration was applied only to test. Apply `bin/rails db:migrate` before using this change in development; populate the sample only by explicit command. Owner-directed schema revision: replace original_title/original_release_date columns with metadata/release_date, retaining a single date and querying year through ranges. The uncommitted migration was revised after reversal in test only. JEV and quality vocabulary validation remain deferred.

Owner authorization: Task spec approved on 20 October 2026. Implementation authorized and started.

Owner acceptance / merge: Pending review and merge.
