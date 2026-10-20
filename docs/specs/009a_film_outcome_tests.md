# 009a — Film knowledge outcome tests

Status: Ready for review  
Owner: Film knowledge / verification

## Goal

Import/sample tests assert specific promised outcomes instead of whole-row snapshots. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Replace whole-attribute comparisons with named identity/title/date/metadata/timestamp preservation and race-winner assertions. Keep importer deduplication and development sample ensure semantics.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- Tests only; no Film knowledge runtime/API changes, live TMDB calls, Identity changes or schema changes.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_test.rb test/services/film_knowledge` passed 34 tests/891 assertions, including real unique-index races, local metadata retention, initial sample content and repeated sample/import calls. No live TMDB requests.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

Replaced full attribute snapshots in importer/sample tests with explicit title/date/metadata, identity and timestamp preservation assertions. Catalogue field round-trip testing now selects named contract fields directly. Existing import/sample system deduplication semantics, provider failure propagation, HTTP fakes and schema checks are retained. No Film knowledge runtime, client, API or schema change.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Pending.
