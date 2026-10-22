# 012b — Library facts without classification

Status: Ready for review — implemented 22 October 2026  
Owner: Library / event publication

## Goal

Publish Library actions without exposing their resulting internal classification. Consumers react to event names and internal user/film identity.

## Scope

- Remove classification from LibraryFilm.publish_event! and all callers, including derived watched publication.
- Publish schema v1 with exactly user_id and film_id. Preserve event names, stream identity/sequence, atomicity and causal links. Owner confirmed there is no historical data to support; correct v1 in place without a version bump or compatibility path.
- Update publication contract and exact-payload regression tests. Task 017 already consumes only the required identifiers, without interpreting classification; its contract is unchanged.

## Scope restrictions

- Library only; no Foundation changes, payload rewrites, migration, event-name changes or user-action changes. No Ratings runtime change is needed; existing consumer integration tests verify the corrected payload.
- No general event schema framework or unrelated cleanup.

## Acceptance criteria

- **AC1:** Every direct and derived Library event uses the minimal v1 payload with unchanged atomicity/causality.
  Check: Library publication and rating-consumer regression tests including exact payload/version, source rollback and causal linkage.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/ratings test/services/domain_events test/jobs`: 148 tests / 1,329 assertions. Exact direct/derived v1 payloads contain only user_id and film_id; atomicity, causal linkage and both consumer suites passed.
- **AC2:** Documentation and validation reflect the final contract.
  Check: code search for classification arguments, focused style, whitespace and combined regression checks with the existing task 017 consumer.
  Result: Passed — targeted RuboCop on LibraryFilm, Library services and changed publication/consumer tests: 16 files, no offenses. `git diff --check` passed. No classification keyword arguments remain in app/test. Publication and event-design docs updated.

## Implementation notes

Owner explicitly confirmed there is no historical data; v1 is corrected in place. No version compatibility, payload rewrite or backfill is introduced. No deployment or migrations.

Owner acceptance / merge: Pending.

Final combined verification before PR: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed on the final implementation (384 tests / 4,010 assertions; style and security checks clean). This includes all handler/entry-point renames and removal of classification. `git diff --check` passed.
