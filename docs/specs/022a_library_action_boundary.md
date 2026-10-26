# 022a — Existing-entry Library actions

Status: Ready for review  
Owner: Library / action boundary

## Goal

Give each Library user action one existing-entry contract. Remove overlapping wrappers and implicit creation from user actions; retain the established Ratings-event creation workflow.

## Scope

- Consolidate RecordWatched, AddToWatchlist, MarkNotInterested, RemoveFromWatchlist and RemoveNotInterested to accept user_id and library_film_id. Lock the fresh active owner and exact owned relationship once; reject missing/foreign/stale IDs, delegate permissions to the model, transition/remove and publish atomically.
- Remove WatchFilm, WatchlistFilm, DismissFilm, RemoveWatchlistFilm and RemoveNotInterestedFilm wrappers. Update controllers, tests and current documentation.
- Preserve model-owned permissions, existing transition failures and subtype-transition service ownership. No create-if-missing branch in user actions.
- Preserve Ratings-event creation, causal publication, retry and reconciliation unchanged. Recommendations acceptance creation remains future work, not a fabricated consumer.
- Document future TMDB search → explicit Add to watchlist → create → redirect to the resulting LibraryFilm ID as a separately scoped creation entry point. Library detail GET only accepts an existing relationship ID and never creates.

## Scope restrictions

- No search UI, creation endpoint, new event, recommendation implementation, migration or generic service/transition framework. No aliases retaining film-ID mutation APIs. Other domains' production code remains unchanged; adjust dependent test setup for the changed Library contract.

## Acceptance criteria

- **AC1:** One service per user action, requiring an owned existing relationship; permissions and atomic events are retained.
  Check: transition/removal success, unsupported and duplicate actions, missing/foreign/deleted/replaced IDs, fresh identities, rollback/publication failure, concurrent removal and state changes.
  Result: Passed — consolidated operation tests cover all five actions, permissions, owner/entry absence, stale replacement IDs, identity expiry/claim, caller rollback, persistence/publication failures and retries. Real PostgreSQL concurrency tests cover repeated actions and removal/transition ordering.
- **AC2:** Creating a Library relationship remains confined to the current receiving event workflow.
  Check: real Ratings event creates watched once and reconciles existing entries; user actions and GET never create. Preserve event consumer/concurrency/retention tests; remove obsolete public-creation expectations.
  Result: Passed — production creation-site inspection finds only Library::EventHandlers::Ratings::RatingSubmitted. Real event consumer and concurrency tests verify creation, reconciliation, causal publication and retries. Retention tests preserve watched/watchlist/not-interested claim/cleanup coverage; old user-action creation expectations were replaced with explicit fixture setup and missing-entry rejection tests.
- **AC3:** Existing HTTP journeys continue to work with consolidated services.
  Check: Library requests and full CI, eager loading and whitespace; inspect all production creation sites and obsolete wrapper/film-ID calls.
  Result: Passed — focused Library/consumer/request suite: 86 tests / 939 assertions before final extra retention/failure checks. Final full CI: 436 tests / 4,752 assertions, zero failures/errors/skips; style/security checks clean. Eager loading and whitespace checks passed. All controller actions call the consolidated operations with library_film_id; no old wrapper classes remain.

## Implementation notes

Owner explicitly approved revisiting the old operation contracts rather than preserving redundant wrappers. Prior specs record historical behaviour; this spec supersedes their film-based user-action creation contracts. Owner acceptance / merge: Pending.


Implemented five direct user-action services and removed the five overlapping wrappers. The existing Ratings consumer is unchanged; it is the only production LibraryFilm creation site. No endpoint was added for future search/watchlist creation. Domain event names and payloads are unchanged.

Verification commands:
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/ratings/library_consumer_test.rb test/integration/library_details_test.rb test/integration/library_dismissal_actions_test.rb` — focused pass, 86 tests / 939 assertions.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — final pass, 436 tests / 4,752 assertions, no failures/errors/skips.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed, with existing mailer-preview exclusion notice.
- `git diff --check` — passed.

Test counts changed because overlapping operation/concurrency suites and obsolete create-if-missing expectations were consolidated around the new contract. Persistence failures, exact guest expiry, registered access, claim/cleanup retention, publication/stream ordering, consumer creation, ownership and removal races remain covered. This service-only refinement used request regressions rather than repeating the earlier browser walkthrough; UI and routes are unchanged.
