# 023 — Replace a rating while preserving its history

Status: Ready for review  
Owner: Ratings / revisions

## Goal

An active guest or registered user can replace their current rating with a new rating and expressions, without overwriting the previous submission. Exactly one rating remains current for the existing RatingFilm. This task supplies the domain operation; browser editing is a subsequent Ratings task.

Prerequisites: first submission (014), expressions (015), and existing owned-candidate resolution (019). Follow the agreed [scoring design](../ratings_scoring_design.md); qualities and profiles are not implemented yet.

## Scope

- Keep `RatingFilm#ratings` as history. Derive currentness from the highest Rating ID per RatingFilm, through a `current` scope and current-rating association. Replace the unique rating_film_id index with a nonunique (rating_film_id, id) index. Do not store a superseded flag. Existing ratings remain current.
- Provide `Ratings::ReviseRating.call(user_id:, rating_film_id:, previous_rating_id:, value:, expression_texts: [])`, returning the newly persisted Rating. The previous ID identifies the rating the caller intends to replace and prevents a stale submission from overwriting an intervening revision.
- Lock and freshly validate the active owner and exact owned RatingFilm, following existing submission lock order. Delegate replacement rules and persistence to model behaviour; the service coordinates the transaction. Never create a candidate here.
- Atomically create the replacement with the existing value constants, expression bounds, validation and nested-attributes handling. Preserve previous values and expressions. Inputs are a complete replacement: omitted expressions mean no expressions on the new rating, not copying previous expressions. An unchanged value is allowed, including when only expressions change.
- Require a current rating. Missing/foreign candidates use the existing candidate-unavailable failure; unavailable/inactive owners use IdentityUnavailable. Use Ratings::RevisionUnavailable for an unrated candidate and Ratings::StaleRating for a previous ID that is no longer current or does not belong to this candidate. A retry with the old ID fails explicitly. Preserve existing invalid-value/expression failures and localize new application-authored errors.
- Keep first submission's AlreadyRated behaviour, candidate flags/creation time, and rated/unrated/pending eligibility unchanged. A revised film stays rated and outside automatic rotation. Current-rating reads must exclude superseded records; history remains explicitly accessible.
- Publish no revision event until there is a demonstrated consumer need. Preserve the existing first-submission RatingSubmitted contract.

The owner approved these revision inputs and failures on 26 October 2026. No new subscriber is part of the task.

## Scope restrictions

- Ratings owns all changed behaviour. No Library, Recommendations, Identity or Foundation implementation changes, duplicate domain state, new integration layer or new subscription. Existing Library rated-status reads continue to work because the RatingFilm remains rated.
- No routes, controllers, forms, Library editing links or automatic changes to targeted first-rating entry. Scope browser replacement separately after this operation is established.
- No RatingQuality tables, scoring, profile recomputation, AI calls or deferred processing. Future derived records belong to their specific Rating; future aggregation and jobs must exclude superseded contributions. Do not implement speculative processing infrastructure now.
- No editing/deleting historical expressions, rating deletion, undo, history browser, arbitrary revision-number framework or extra timestamps. Task 024's expression-editing scope must be reconsidered against full replacement before it starts.
- Preserve existing retention and user-claim behaviour. No production deployment or external services.

## Acceptance criteria

- **AC1:** A valid replacement produces a new current Rating with its submitted expressions; the old Rating and expressions remain unchanged. Multiple sequential revisions preserve history and exactly one current rating.
  Check: model/service tests for registered and active guest owners, all supported values, empty/replaced expressions, same-value replacement, and repeated revisions. Assert persisted outcomes and association results.
  Result: Passed — final full CI: 452 tests / 4,930 assertions. Sequential replacements cover all values, original evidence retention, same-value and empty-expression replacement; claim/concurrency coverage verifies registered access beyond the guest deadline.
- **AC2:** Missing/foreign candidates, inactive owners, unrated candidates, stale previous IDs and invalid input fail without changing ratings, expressions, candidate state or events. Replaying a completed revision fails explicitly.
  Check: failure and rollback tests, including expired guests, removed candidates, malformed/bounded expressions, invalid value. Confirm no candidate creation and fresh state after failed transactions.
  Result: Passed — the final full CI command below covers missing/foreign/deleted candidates, absent/inactive/expired owners, unrated and stale/replayed IDs, invalid values and expression bounds, caller rollback, database expression failure. Each failure preserves the current rating and permits a valid retry where applicable.
- **AC3:** Two concurrent revisions of the same current rating produce one winner and one stale failure. Latest-ID selection returns exactly one current rating per candidate while retaining history. Owner/candidate locks serialize first submissions and revisions.
  Check: separate-connection PostgreSQL race tests, latest-selection tests across multiple candidates and migration verification from the existing one-rating schema. Verify existing rows remain current; document reversal limitations once history exists.
  Result: Passed — the final full CI command below includes real separate-connection PostgreSQL revision races with one winner and one stale failure, latest-ID selection across candidates with backdated timestamps, and migration down/up with an existing rating. Restoring the unique index fails at the database constraint if a candidate has history; transactional migration rollback preserves the records and history index. No custom down guard is needed.
- **AC4:** Replacement does not publish events or modify the existing first-submission event/stream. First-submission publication remains unchanged.
  Check: successful replacements and rollback preserve event and stream counts and sequence; run existing first-submission tests.
  Result: Passed — full CI verifies successful replacements create no events or streams, rollback/retry leaves the first event sequence unchanged, and existing first-submission publication tests pass.
- **AC5:** First submission, queue eligibility, existing Library rated presentation and guest claim/cleanup continue to work with multiple ratings and retained expressions.
  Check: focused Ratings and retention regressions, existing Library read/request regressions, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`. Record commands and actual results here after implementation.
  Result: Passed — full local CI command below: 452 tests / 4,930 assertions, zero failures/errors/skips, clean style/security checks. Includes Library rated display, existing browser requests, first submission, queue eligibility, guest claim and complete history/expression cleanup. Eager loading and whitespace checks passed.

## Implementation notes

Implemented the model-owned replacement action, transactional ReviseRating service, current-rating association/scope derived from highest ID, and a nonunique relationship/ID index. Added localized failures. Revision events are deferred until a consumer demonstrates a need. First submission and other domains' implementations are unchanged. The model uses its own savepoint so failed replacement also rolls back nested expression writes when called directly; the service transaction holds the owner/candidate locks through persistence.

Verification commands:
- Earlier focused suite passed 92 tests / 1,029 assertions before the latest-ID simplification; the final full CI below verifies the current implementation.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — passed, 452 tests / 4,930 assertions; style, dependency/importmap audit and Brakeman clean. Log: `/tmp/glutton023-no-revision-event-ci.log`.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed, with the existing mailer-preview exclusion notice.
- `git diff --check` — passed.

The first full CI run passed all tests but found one extra blank line in the concurrency test; corrected and rerun. Only the test database was migrated. No browser walkthrough was needed for this backend-only task; existing request tests ran. Browser replacement remains task 023a. Qualities, current-preference aggregation and late-job guards remain unimplemented future capabilities; no claim is made that scores or profiles are recomputed. No implementation-scope deviations.

Owner acceptance / merge: Pending. Spec approved on 26 October 2026; implementation ready for review.

Owner simplification: derive currentness from the highest Rating ID per candidate. No superseded column or partial unique index; existing owner/candidate locks retain stale/concurrent submission protection. Final verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 452 tests / 4,930 assertions with clean style/security checks. Eager loading and whitespace checks passed. The test-only original migration was reversed before applying the replacement migration; no deployed data or development database was changed.

Rollback simplification: removed the explicit history query/guard from `down`. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/rating_revision_persistence_test.rb` passed (3 tests / 15 assertions), including database uniqueness failure inside a migration-style transaction and preservation of history and its index. Targeted RuboCop and `git diff --check` passed. Full CI evidence above predates this migration-only refinement.

Owner deferral: removed the unused RatingRevised constant, publishing method and service call. No replacement event is emitted. Full CI after removal passed 452 tests / 4,930 assertions with clean style/security checks; the obsolete revision-publication failure test was removed.
