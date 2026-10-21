# 013 — Ratings queue and dismissal

Status: Accepted — owner approved PR and merge after CI on 21 October 2026  
Owner: Ratings / presentations

## Goal

Select films from a Ratings-owned queue and let the user dismiss a film from automatic rating rotation. Maintain one user/film record, without presentation history or a separate seen/unseen question. This supersedes the initial task 013 implementation following owner review.

Read the implementation plan, product brief sections 2/3.1, architecture brief sections 4/5/6 and docs/domain_events.md. This approved revision supersedes their earlier seen/unseen response and presentation-history proposals.

## Scope

- One `RatingFilm` is a persistent candidate for its user, regardless of whether future admission comes from a Library watched event or a catalogue batch. Store user, film, non-null `dismissed` boolean (default false), and standard Rails timestamps only. No presentation or viewing timestamps, history, current selection or session state.
- `Ratings::NextCandidates.call(user_id:, limit: 5)` returns an array of up to `limit` undismissed candidates ordered by created_at then ID; return an empty array on exhaustion. Validate the external limit as an integer from 1 to 100. Selection is read-only; unfinished candidates retain their position across sessions. Older unfinished candidates precede newly admitted watched films. This replaces the previous watched-first policy.
- Add `dismissed` and `pending` scopes. Task 014 must add the actual `has_many :ratings` association plus `rated` / `unrated` scopes, and extend `pending` to exclude rated candidates. No ratings table exists yet; do not add dummy scopes or speculative rating storage to this task. All persisted candidates in this task are unrated, so `pending` currently filters dismissal only.
- `Ratings::Dismiss.call(user_id:, rating_film_id:)` delegates model-owned dismissal, setting dismissed true and returning the same row. No prior presentation is required. Repeated dismissal raises `Ratings::DismissalUnavailable`; missing/foreign rows raise `Ratings::FilmUnavailable`.
- Dismissal excludes only automatic rating rotation, without inferring viewing or recommendation interest, changing Library or emitting events. Future Library admission must preserve existing records, dismissal and creation time. Task 019 handles explicit rating entry from Library; this task adds no reopening or UI.
- Batch replenishment remains separate until catalogue selection policy is agreed. Do not automatically admit catalogue/Library records or implement event subscribers. Future replenishment fills only the shortfall and excludes all existing user/film records, including rated and dismissed candidates.
- Services refresh and lock user then RatingFilm for dismissal. Selection locks the owner while materializing the batch to serialize with cleanup/claim/dismissal, without reserving candidates. Missing/expired/deleted owners raise `Ratings::IdentityUnavailable`. Concurrent reads can return the same candidates; concurrent dismissals have one success and one explicit duplicate failure.
- Required references, unique user/film identity and non-null dismissal are enforced by the database, with model validation. Owner deletion cascades candidates, guest claim preserves IDs and dismissal, Film references stay restrictive. No Identity changes.

## Scope restrictions

- Ratings only; no changes to other domain implementations. No numeric ratings, expressions, recommendations, jobs, UI, routes, event consumers/publishers, targeted-entry implementation, catalogue admission or presentation analytics.
- No new history table, generic state machine, STI hierarchy, dismissal reason or boolean unseen/not-interested flags. No bootstrap for this new project.
- Only migrate the test database during verification. Replace the unmerged task migration after rolling it back there; no production operations or deployed-data migration is needed.
- All new application-authored text belongs in Rails locales. Keep this task separate from rating submission and explicit Library entry, while recording the agreed policy for those later tasks.

## Acceptance criteria

- **AC1:** Batches are bounded, oldest-first, owner-isolated and exclude dismissed candidates without mutating selection state.
  Check: created_at/ID ties, default/explicit limits and invalid input, unfinished candidates across calls, exhaustion and no automatic catalogue/Library admission.
  Result: Passed — `PARALLEL_WORKERS=1 bin/rails test test/models/rating_persistence_test.rb test/services/ratings`: 19 tests / 95 assertions across AC1–AC3. Covers oldest-first ties, default/explicit/invalid limits, owner isolation, no catalogue/Library admission and stable unfinished candidates without selection writes.
- **AC2:** Model-owned dismissal has explicit atomic outcomes and only affects Ratings.
  Check: dismissal without presentation, duplicates/missing/foreign/inactive failures, no Library/events, rollback and injected persistence failure.
  Result: Passed — focused tests cover dismissal without prior presentation, duplicate/missing/foreign/inactive failures, unchanged Library/event counts, outer rollback and a database failure rescued inside an outer transaction.
- **AC3:** Storage and lifecycle invariants hold.
  Check: references, unique user/film, boolean default/non-null and scopes; separate connections for concurrent reads/dismissal, expiry, cleanup and claim; real Identity retention behavior.
  Result: Passed — focused schema/model tests cover references, uniqueness, default/non-null boolean and dismissed/pending scopes. Six separate-connection tests cover concurrent reads, duplicate dismissal, expiry while waiting, cleanup before dismissal, claim before dismissal and claim racing cleanup.
- **AC4:** Repository checks pass.
  Check: `PARALLEL_WORKERS=1 bin/rails test test/models/rating_persistence_test.rb test/services/ratings`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`; strict locale checks and test-only migration replacement.
  Result: Passed — replaced the unmerged migration in the test database only using `RAILS_ENV=test bin/rails db:migrate:down VERSION=20261021180000` then `RAILS_ENV=test bin/rails db:migrate`. Focused tests: 19 / 95 assertions. Full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 320 tests / 3,270 assertions, no failures/errors/skips; RuboCop 178 files clean, gem/importmap audits clean, Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion notice. `git diff --check` passed. Strict locale tests passed.

## Implementation notes

Owner approved oldest-first batches and scopes after reviewing the earlier single-record design. This removes all extra timestamps and single-current-film restrictions. The previous implementation's passing checks do not verify this revision. `rated` / `unrated` require the actual rating relationship in task 014; catalogue replenishment and Library admission remain separate implementations.

Implemented `RatingFilm.dismissed` / `.pending`, model-owned dismissal and `Ratings::NextCandidates` (default five, maximum 100). Removed all nonstandard timestamps and current-presentation constraints. Updated queue, persistence and concurrency tests. No other domain implementation changed.

Scope naming follow-up: replaced `undismissed` with `pending` in the model, batch query and existing scope assertions. Re-ran `PARALLEL_WORKERS=1 bin/rails test test/models/rating_persistence_test.rb test/services/ratings`: 19 tests / 95 assertions passed. `git diff --check` passed. Final full CI rerun after the naming change passed on 21 October 2026: 320 tests / 3,270 assertions, style and security checks clean.

Owner acceptance: Approved on 21 October 2026. Merge: Pending CI and PR merge.
