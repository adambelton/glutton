# 012a — Library event publication

Status: Merged  
Owner: Library / event publication

## Goal

Make committed Library classification changes available through the established Foundation outbox. Consume task 001i's publication contract; preserve tasks 010–012's action results and failures. No consumers are implemented here.

## Scope

- Publish from the five established Library operations, in the transaction that creates, transitions or destroys the LibraryFilm. Lock/re-read the user before Library rows and outbox publication. A successful action emits exactly one action fact; a failed action emits none. Publication failure rolls back the action. Preserve existing return values, permissions and duplicate-action errors.
- Follow-up approved by owner: use the domain-owned `Library::EVENTS_PUBLISHING_DOMAIN` constant (value `library`) against Foundation task 001j’s open publisher contract. Do not define identifiers for unimplemented domains.
- Use `Library::EVENTS_PUBLISHING_DOMAIN` and `stream_key: "film:#{film_id}"`. One stream spans the user's entire Library relationship with that film, including row removal/recreation. The envelope sequence orders changes; LibraryFilm IDs and timestamps are not versions.
- Version 1 payloads contain `user_id`, `film_id` and `classification`. Identifiers are internal IDs; classification is `watched`, `to_watch`, `not_interested` or null for removal. No STI names, titles, email, ratings or user-authored text. The payload user must match the stream owner. Source sequence, schema version and occurrence time come from the envelope, not duplicate payload fields.

| Operation | Event name | Resulting classification |
| --- | --- | --- |
| RecordWatched | FilmMarkedWatched | watched |
| AddToWatchlist | FilmAddedToWatchlist | to_watch |
| MarkNotInterested | FilmMarkedNotInterested | not_interested |
| RemoveFromWatchlist | FilmRemovedFromWatchlist | null |
| RemoveNotInterested | FilmDismissalRemoved | null |

- A permitted transition publishes only its resulting action fact. For example, ToWatch-to-NotInterested does not invent a watchlist-removal action. Watched establishes seen evidence; NotInterested establishes unseen/no-intent evidence. Watchlist membership alone establishes neither seen nor unseen. Removal clears classification without retracting previously established viewing evidence.
- Define the five event names as frozen string constants in `Library::Events`, shared by publishers and tests. Each operation passes its resulting classification explicitly to `LibraryFilm#publish_event!`; subclasses do not expose an event-classification query.
- There are no existing project entries to migrate. Remove baseline publication, bootstrap service/command and their tests. Supported Library operations are the publication boundary; direct Active Record writes and fixtures are not public action APIs.
- Preserve model-owned permissions and service-owned subclass transitions. Retain Foundation's after-commit wakeup, independent deliveries, physical cleanup and guest-claim ownership. Direct actions start their own correlation; incoming causation belongs to later consumer tasks.
- Version 1 is an immutable published payload contract. Future incompatible shapes require a new schema version and explicit subscriber support.

## Scope restrictions

- Library only. Use the merged Foundation API without modifying its schema, dispatcher, registry or retries. No Ratings/Recommendations data or handlers, synchronous cross-domain callbacks, UI, new Identity behaviour or Film metadata work.
- Preserve permitted Library transitions. NotInterested-to-Watched system reconciliation remains task 016. No action requests/outcomes or changes to user-action idempotency.
- No baseline/backfill framework, deployment, scheduler changes or new event retention/compaction policy. Physical cleanup remains silent cascading deletion rather than a fabricated user Library action.
- No network operations or new external services. Verification uses the test database. Spec preparation does not authorize implementation.

## Acceptance criteria

- **AC1:** Each successful supported action publishes exactly one agreed v1 fact and retains its return value; invalid/duplicate actions publish nothing.
  Check: operation matrix covers creation, every permitted transition and both removals; assert payload, stream owner/key, event name/schema and meaningful failures. Publishers and tests use `Library::Events`.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library`: 55 tests / 423 assertions, zero failures/errors/skips. Event publication tests verify all five named facts and explicit classifications; publishers and tests share `Library::Events`.
- **AC2:** Source state, action event and stream sequence commit or roll back together.
  Check: force publication failure and outer rollback for creation, transition and removal; verify removal/recreation preserves sequence continuity and separate films/users remain independent.
  Result: Passed — the focused suite above verifies publication-failure rollback (including rescue by an outer caller), caller rollback, independent streams and consecutive sequences across removal/recreation.
- **AC3:** No baseline/bootstrap or subclass classification-query code remains; implementation stays within Library.
  Check: inspect runtime changes and references; run `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`.
  Result: Passed — full CI (`RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`): 301 tests / 3,175 assertions, zero failures/errors/skips; style and all security checks passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed for application code (the existing test mail preview directory is not eager loaded). `git diff --check` passed. Reference search confirmed removed APIs/event/command are absent from app, lib and test. Subclasses have no changes relative to main.

## Implementation notes

Owner clarified that this is a new project with no existing entries, and approved removing baseline/bootstrap and `event_classification`. This revision replaces the previous bootstrap scope and verification. Event publication remains atomic, using savepoints so an outer caller rescuing a publication failure cannot commit an unpublished source change. No consumers or production execution are included.

Publisher ownership follow-up: Library now declares `EVENTS_PUBLISHING_DOMAIN` in `app/services/library.rb` and uses it in publication and Library tests. Provider task 001j was verified independently first; Library focused tests passed 55 tests / 423 assertions, and final full CI was rerun after the naming and constant-layout follow-ups: 301 tests / 3,175 assertions, all checks passed.

Naming follow-up: use `library_film` throughout creation/transition/publication, updating the same role variable when needed. Re-ran `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library`: 55 tests / 423 assertions, zero failures/errors/skips; `git diff --check` passed. No new tests or behaviour changes.

Constant layout follow-up: publisher `Library::EVENTS_PUBLISHING_DOMAIN` and event names under `Library::Events` share `app/services/library.rb`; removed the separate event-names file. Library tests passed again (55 tests / 423 assertions), application autoload check and `git diff --check` passed.

Owner acceptance / merge: Accepted by the owner and merged via [PR #26](https://github.com/adambelton/glutton/pull/26) on 21 October 2026 at 16:49:30 UTC; squash commit `f4d911344a830b413fba9ea85aa2b44ce5b07a3e`. Hosted Repository checks passed on head `a703a329ec21302e2e57f8741f1e55e512715f73` before merge.
