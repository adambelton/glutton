# 020a — Retain completed-rating status in Library

Status: Withdrawn — owner correction on 26 October 2026  
Owner: Library / rating-event consumption

## Withdrawal decision

Domains share read access to the same data; the boundary protects ownership of mutations, invariants and lifecycle. Reading Rating or RatingFilm from Library is allowed. A duplicated rated flag and event-consumer extension are unnecessary for the watched screen. Proceed with [task 020](020_library_watched_view.md), deriving the display from Ratings-owned data. Nothing in this proposal was implemented.

The sections below preserve the withdrawn proposal for context and are not implementation requirements.

## Original proposed goal

Library can distinguish a watched film with a completed rating from one still awaiting rating, using its own state derived from Ratings events. This is the small prerequisite for task 020’s watched Library screen and its link to the task 019 rating destination.

The existing consumer establishes watched state from RatingSubmitted but discards the fact that a rating exists. Watched alone cannot distinguish a manually recorded viewing from a completed rating. The draft incorrectly assumed that reading Rating or RatingFilm from Library would violate the domain boundary; the owner explicitly rejected that assumption.

Read the implementation plan, specs 016/016a and 019, docs/ratings_event_publication.md, docs/library_event_publication.md and the Foundation delivery contract. Consume the existing RatingSubmitted v1 event using only its event identity and user/film identifiers. No new publisher contract or synchronous Ratings query is required.

## Scope

### Library-owned completion state

- Add a non-null `rated` boolean on LibraryFilm, default false. It records that Library has received completed-rating evidence; it is not the rating value or a copy of Ratings records. Keep the existing STI classes and user/film uniqueness.
- Public watched creation/transition starts unrated. Watchlist/not-interested activity does not manufacture completed-rating evidence. Existing rules already prevent a watched film from transitioning into those unwatched states; preserve those rules.
- A received RatingSubmitted establishes watched if necessary and records rated=true. The Library model owns its state-changing action and permission rules; the consumer coordinates admission/transitions and delegates. Do not add caller class tests or put sibling transitions into models.
- No rating value, rating ID, expression, score, timestamp, sequence watermark or separate projection table. A boolean is sufficient for the approved first-rating-only contract. No code clears completed-rating evidence in this task; future rating deletion/revision semantics require their own event decisions.

### Existing event consumer

Keep the existing `library.completed_ratings` subscription and handler namespace. The reaction becomes:

| Existing Library entry | Result | Publication |
| --- | --- | --- |
| Absent | Create watched, record rated | One FilmMarkedWatched |
| To watch or not interested | Transition to watched, record rated | One FilmMarkedWatched |
| Watched, unrated | Record rated | No additional watched event |
| Watched, rated | No change | No event |

- An actual viewing transition or completed-rating status change returns processed. An already-satisfied fact returns ignored with unchanged timestamps. Preserve explicit duplicate failures for public user actions; handler retries may remain idempotent at the system boundary.
- The viewing transition, rated flag, any derived watched event and delivery receipt commit together under the established user/receipt locks. Failure rolls all effects back and follows existing retry rules. Derived watched facts retain existing correlation/causation and unchanged payloads.
- Do not publish a new event for the rated flag: no consumer currently needs one. Do not copy rating values or query Ratings models. Do not split the subscription, add a replay framework or alter Foundation delivery.
- Normal dispatch can consume unprocessed retained facts. This project has no production historical data to migrate; do not add legacy reconciliation or reset processed receipts. Already-processed receipts will not be replayed by the schema migration. Tests must establish state using actual delivery after the change, not presume old receipt replay.

### Lifecycle and eventual consistency

- Registration claim preserves the same Library entry and completion flag. Existing physical user cleanup removes it. Film catalogue data remains shared and unchanged.
- Until event delivery completes, Library may show a film as awaiting rating even if Ratings has saved it. Task 019’s destination handles already-rated entry explicitly. Do not add synchronous reads or optimistic cross-domain writes to conceal that delay.
- Record the updated reaction/receipt semantics in Library publication and delivery documentation. Only change descriptions relevant to this consumer.

## Scope restrictions

- Library owns this task: one boolean and the existing consumer/model behaviour needed to maintain it. No Ratings runtime changes, RatingFilm/Rating references, event payload/version changes, Foundation changes or generic integration framework.
- No Library routes, views, pagination or rating link yet. Task 020 implements that separately against this established state and task 019’s browser destination.
- No watchlist/dismissal UI, catalogue selection/import, rating replacement/deletion, expression changes, recommendations or scoring.
- No extra status reasons, source IDs, historical data migration or mass event replay. Migrate the test database only during verification; no deployment.
- Preparing this draft does not authorize implementation.

## Acceptance criteria

- **AC1:** Library retains completed-rating evidence according to the reaction table.
  Check: real RatingSubmitted delivery for absent, to-watch, not-interested, watched-unrated and watched-rated entries. Verify rated flag, watched behaviour, unchanged user/film identity and exact derived event counts. Manually recorded watched entries remain unrated. Use opaque/minimal event payloads as existing consumer tests do; rating values remain outside Library’s contract.
  Result: Not run — draft only.
- **AC2:** Updates and receipts are atomic and repeat-safe.
  Check: injected persistence/publication failure rolls back the transition, completion flag, event and successful receipt; retry succeeds once. Repeated facts/completed receipts preserve rated state and no-op timestamps. Concurrent delivery and watched activity yield one Library entry with completed evidence and only actual watched-transition events.
  Result: Not run — draft only.
- **AC3:** State respects ownership, lifecycle and storage rules.
  Check: default false and non-null storage, model boolean validation, guest claim retention and inactive-owner delivery/cleanup using established operations. No cross-user mutation, Ratings model reads or value interpretation. Record actual test migration command and outcome.
  Result: Not run — draft only.
- **AC4:** Verification and consumer documentation match final behaviour.
  Check: focused Library model/service/delivery/concurrency tests; existing Ratings interaction regressions; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record actual counts/results and any limitations, including no replay of previously completed receipts. No browser walkthrough is required for this service-only task.
  Result: Not run — draft only.

## Implementation notes

Not implemented. The proposed boolean and consumer extension await owner review. Task 020 remains the Library-owned watched/rated screen and Ratings link; this prerequisite keeps its UI work from also introducing event-derived state.

Owner acceptance / merge: Withdrawn; no implementation or merge.
