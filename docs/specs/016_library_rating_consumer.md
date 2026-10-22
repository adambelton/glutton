# 016 — Establish watched Library state from completed ratings

Status: Ready for review — implemented 22 October 2026  
Owner: Library / rating-event consumer

## Goal

Consume retained and newly published RatingSubmitted v1 facts so an active owner's film becomes watched in Library. Commit any actual transition, its FilmMarkedWatched event and the delivery outcome atomically. One independently verifiable outcome: completed rating evidence converges Library to watched without duplicate effects.

Read the implementation plan, architecture brief's domain and event sections, docs/domain_events.md, docs/ratings_event_publication.md, docs/library_event_publication.md and docs/domain_event_operations.md. Use the existing Foundation subscription/delivery/publication contracts and Identity/catalogue roles. No Ratings source changes are needed.

## Scope

### Subscription contract and bootstrap

- Add one Library-owned handler with the established `call(event:, user:)` contract. The user supplied by Deliver is freshly locked and active; trust that role rather than repeating class checks. Keep the handler on the established delivery path.
- Define a stable Library-owned subscriber name and register it for Ratings::EVENTS_PUBLISHING_DOMAIN and Ratings::Events::RATING_SUBMITTED. The single explicit entry in DomainEvents::Subscriptions.all is use of the existing registration extension point; no Foundation behaviour or generic registry redesign is in scope.
- Accept schema version 1 only. Validate only user_id and film_id and consistency with stream owner and film stream key before writing. Rating values and other Ratings-specific fields are opaque to Library: do not require, enumerate or validate them, or require an exact payload key set. The Ratings publisher contract remains unchanged. Malformed facts, unsupported versions or a missing referenced Film fail explicitly and use existing retry/terminal-failure handling; never silently acknowledge them as applied. Do not read Rating, RatingFilm or RatingExpression to interpret or verify the fact, and do not expand its payload.
- Bootstrap through normal bounded dispatch of all retained matching events without a receipt for this subscriber, including events created before registration. Use existing per-stream ordering, retries and continuation. No snapshot, cursor table, source backfill, synthetic rating or deployment is needed. Document normal dispatch and status commands for catch-up.

### Library reconciliation and behaviour ownership

| Current Library state | Completed-rating outcome | New Library event |
| --- | --- | --- |
| No entry | Create watched entry | One FilmMarkedWatched |
| ToWatch | Transition existing entry to watched | One FilmMarkedWatched |
| NotInterested | Reconcile completed-viewing evidence by transitioning existing entry to watched | One FilmMarkedWatched |
| Watched | Preserve entry and timestamps; already satisfied | None |

- Return `:processed` for an actual change and `:ignored` for already watched. This is explicit system-workflow idempotency, not a change to user-action semantics. Public RecordWatched continues to reject duplicate watched actions and its existing unsupported transitions.
- Keep action-permission behaviour in Library models and STI transition mechanics in a Library transition service. Introduce only the behaviour needed to accept completed-viewing evidence. Do not identify subtypes in the handler or put sibling-class/persistence mechanics in subclasses. Do not broaden can_watch? merely to accommodate this system workflow.
- Re-read and lock the Library entry under the existing user lock. Preserve entry identity through transitions. Existing unique user/film storage remains the invariant; no additional projection, rating value, history or stream cursor columns are required for this monotonic watched fact.
- Completed rating establishes viewing regardless of unrelated Library stream sequence or wall-clock timestamps. A prior or concurrently recorded NotInterested/ToWatch action is reconciled to watched; once watched, public actions cannot turn it back into an unwatched state. Test both operation orders. A valid old rating fact remains viewing evidence even after a future replacement rating, so no superseded-rating lookup belongs here.

### Atomicity, causality and lifecycle

- Use Deliver's transaction for the handler's Library state change and delivery receipt. Publish FilmMarkedWatched through the established Library model/publication path in that transaction, retaining the exact v1 Library payload. A publication failure must roll back the transition and success receipt so retry can complete it once.
- Extend the Library publication helper only as needed to forward optional correlation_id and causation_id. Derived events retain the source correlation and use the source event ID as causation. Existing direct Library actions preserve their default correlation behaviour.
- Already-watched deliveries emit no event. Retrying a completed receipt, or independently receiving another valid completed-viewing fact, must not republish or mutate the watched row. Do not subscribe to Library's own output or install Ratings/Recommendations consumers.
- Foundation skips inactive owners and handles missing receipts after cleanup. Verify expired/deleted owners never gain Library activity, cleanup cannot race to resurrect activity, and guest claim preserves identity while pending delivery can complete. Use real Identity operations without modifying them.
- Use symbolic/localized application errors where applicable. Developer-only schema/contract diagnostics must not include raw payloads or private expression text. No external calls in handlers.

## Scope restrictions

- Library owns this task. Besides the explicit subscription entry, no Foundation runtime changes; no Ratings, Recommendations, Identity or Film runtime changes. Existing contracts may be called and exercised in integration tests.
- No RatingRevised support before that event's provider contract exists. Task 023 separately creates replacement ratings, atomically marks the previous rating superseded, and defines one-current-rating constraints and derived-score replacement.
- No rating qualities, expressions/profile processing, rating-value projection for Library views, rating queue changes, UI/routes, request/outcome events, periodic reconciliation framework, deployment or production worker changes.
- No generalized transition refactor, new baseline events, source SQL backfill or broad scope cleanup. Retained-event bootstrap is sufficient for this new project's supported event-producing operations.
- Only test-database changes during verification. Spec preparation does not authorize implementation.

## Acceptance criteria

- **AC1:** Supported completed-rating facts establish watched state according to the table without changing public action failures.
  Check: absent/ToWatch/NotInterested/Watched cases through real delivery, preserved entry identity, no-op timestamps, exactly one event only for changes, unchanged public operation regressions. Verify exact derived v1 payload and correlation/causation. Original Ratings rows remain unchanged.
  Result: Passed — consumer and existing public Library tests verify all four states, preserved transition identity and ignored timestamps, exact v1 payload/causality and unchanged public duplicate/intent failures. A real Ratings submission retains its rating value and original expressions after dispatch.
- **AC2:** Failed or repeated processing cannot leave partial or duplicate effects.
  Check: inject publication failure and verify transition/event/success receipt rollback, then retry; completed-receipt redelivery and another valid viewing fact; unsupported schema, malformed payload/stream mismatch and missing Film use retry/failure outcomes without Library writes. Test registered subscription filtering and ordering through dispatch.
  Result: Passed — injected database publication failure rolls back the transition and successful receipt; retry commits once. Completed receipt redelivery and another viewing fact do not duplicate events. Unsupported versions reach terminal failure, malformed contracts and missing Film retry without writes. Production-registry dispatch filters publisher/name and handles ordered retained facts.
- **AC3:** Retained-event catch-up and concurrent activity converge safely.
  Check: events predating subscription are delivered via the production registry and bounded dispatch, reruns do not duplicate results; race handler against local Library intent actions in both orders; separate-connection duplicate delivery; guest expiry, cleanup and claim with existing Identity operations. Assert final watched state or legitimate skipped/missing outcome, no resurrected owner activity and no repeated derived events.
  Result: Passed — separate-connection tests cover competing delivery, watchlist and NotInterested committed before delivery, intent actions waiting behind delivery, expiry, physical cleanup and registration claim. Retained events catch up in bounded batches with no duplicate effects. Operational notes clarify that no processed work in one batch does not prove the backlog is drained.
- **AC4:** Verification and operations guidance reflect actual checks.
  Check: record focused Library consumer/public-operation and Foundation regression test commands/results; run `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`. Update event/operations documentation to identify the installed subscriber, retained-event catch-up and failures; do not claim deployment. Record any schema changes and test-only migration commands, if needed.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/domain_events test/jobs`: 96 tests / 714 assertions. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 364 tests / 3,740 assertions, style and all security checks passed. `RAILS_ENV=test bin/rails zeitwerk:check`: application eager loading passed with existing test/mailers/previews exclusion notice. `git diff --check` passed. No migration or schema change; no development/production database changes or deployment.

## Implementation notes

Implemented Library::ConsumeRating and one explicit production subscription. The handler is the Library transition service: it validates the versioned event, locks current Library state under Deliver's user lock, uses model-owned can_confirm_watched? permission, coordinates STI persistence and publishes the actual change. Existing RecordWatched remains unchanged. Library publication accepts optional causal IDs. Foundation transport behaviour is unchanged.

Approval: owner approved task 016 on 22 October 2026. No scope deviations. Only Library runtime code and the agreed subscription extension point changed; docs also record prior PR merge evidence and the already-agreed replacement-rating design.

Verification limitations and corrections: the first focused invocation omitted PARALLEL_WORKERS=1 and the local pg driver segfaulted during parallel-worker startup; the hung parent was stopped. All final checks used the project's established single-worker configuration, with explicit separate-connection thread tests for concurrency. One initial catch-up assertion assumed frozen created_at timestamps would sort events by source sequence; corrected the test to create successive retained events at distinct times. The transport's existing bounded discovery behaviour is documented rather than changed. No live worker was deployed or exercised against production.

Owner acceptance / merge: Pending.

Owner review correction: removed duplicated rating choices and rating-value validation from the consumer. Library validates only the event envelope and identifiers needed to apply viewing evidence; rating_id and other unused fields are also opaque. Synthetic consumer tests exercise that minimal dependency; the existing real Ratings submission integration test still verifies the actual published contract. Verification: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/domain_events test/jobs` passed (97 tests / 716 assertions). Targeted RuboCop on the consumer and both consumer test files passed; `git diff --check` passed. Full CI results above predate this focused correction; full CI was not rerun.
