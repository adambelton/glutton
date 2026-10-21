# 009b — Consolidate TMDB boundary rules

Status: Merged  
Owner: Film knowledge / provider boundary

## Goal

Give shared TMDB date and search-input rules one implementation (audit A3).

## Scope

- Share strict optional ISO date parsing between import/search. Move search parameter normalization out of the concrete client into a small Film knowledge boundary object. Remove redundant validation in the class-level client delegate; operation and direct instance-client entry points each retain validation before requests. Preserve public keyword arguments, results and failures.

## Scope restrictions

- No model/schema, provider behaviour, network call, live credentials, UI, Identity/Library changes, generic provider framework or unchecked-input flags. Independent public entry points may validate the same normalized input to preserve their existing contracts.
- No automatic acceptance or merge. User authorized these fixes on 20 October 2026.

## Acceptance criteria

- **AC1:** Import/search agree on missing, empty, valid and malformed dates; operation and direct-client searches reject invalid input and preserve normalized requests without writes or extra HTTP calls.  
  Check: Run existing fake-HTTP import/search/date/parameter/concurrency tests and repository checks; inspect source to confirm single date/parser rule definitions.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/registration_browser_operations_test.rb test/services/identity/complete_registration_concurrency_test.rb test/integration/registration_flow_test.rb test/services/film_knowledge` passed 64 tests / 1,194 assertions, including the existing fake-HTTP date, malformed payload, search normalization, direct-client validation and import concurrency tests. Source inspection with `rg -n "validate_search!|Date.iso8601|query.strip.length" app` confirms one date parser and one search-input rule definition.
- **AC2:** Changes stay within this owner and the stated scope; actual evidence and limitations are recorded.  
  Check: inspect scoped diff; record reproducible commands/results and mark Ready for review.  
  Result: Passed — Scoped diff inspected; no other-domain implementation changes within this task. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed: 232 tests / 2,633 assertions, zero failures/errors/skips (seed 41651); RuboCop 127 files clean; gem/importmap audits clean; Brakeman zero errors/warnings. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

TmdbReleaseDate.parse supplies shared nil/empty/strict-calendar-date semantics. TmdbSearchParameters.normalize owns search keyword validation independently of the concrete transport. SearchTmdbFilms and direct TmdbClient instances use it; the class client delegate no longer validates a third time. The operation and direct client deliberately remain safe independent entry points, retaining a second check when composed rather than adding bypass flags or altering the keyword contract. No new tests mirror extracted helpers: existing public-operation tests verify their effects. No live TMDB requests, schema changes or other-domain modifications.

Verification used isolated local test records and deterministic fake providers. Local database/process/network checks required approved sandbox elevation. No live mail, live TMDB request, deployment, hosted CI, PR or merge occurred.

Owner acceptance / merge: Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge.

Publication authorization: On 20 October 2026, the owner requested a PR for online review. Acceptance and merge remain pending.
