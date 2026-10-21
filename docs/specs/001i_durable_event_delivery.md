# 001i — Durable domain-event delivery

Status: Ready for review  
Owner: Foundation / event delivery

## Goal

Implement the approved asynchronous design's delivery foundation: PostgreSQL outbox, durable Rails jobs, per-subscriber ordering and atomic receipts. No product-domain publishers or subscribers in this task; Library publication remains 012a. Read docs/domain_events.md and the implementation plan.

## Scope

- Enable Active Job with GoodJob in the same PostgreSQL database, normal migrations and bin/jobs. An after-commit dispatcher enqueue uses GoodJob notifications for prompt delivery; a recurring 30-second sweep recovers missed enqueue and retry work. Configure external worker execution and direct PostgreSQL connections; no embedded production worker or experimental pooling mode. Do not run development/production workers or deploy scheduling during verification.
- DomainEventStream belongs to a user and has unique publisher/stream-key identity and monotonic sequence. DomainEvent stores immutable UUID envelope, schema version, sequence, occurrence/correlation/causation and JSON object payload. EventDelivery stores each subscriber/event's progress and receipt. Required foreign keys, uniqueness and check constraints enforce storage invariants.
- `DomainEvents::Publish.call(user_id:, publisher:, stream_key:, name:, payload:, schema_version: 1, correlation_id: nil, causation_id: nil)` requires an enclosing application transaction. Resolve/lock active User, allocate stream sequence and save event. Publisher workflows must lock user before other rows. Source rollback removes event and sequence increment. Missing/inactive owner fails explicitly. Stream identity survives product-row deletion/recreation.
- Explicit code registry: stable subscriber name, publisher, accepted event names and handler. Handler receives event: and fresh user:, performs bounded local database work and returns :processed or :ignored. No payload constantization, production dummy subscribers or dynamic external handlers.
- Review follow-up: centralize Library, Ratings and Recommendations publisher identifiers in `DomainEvents::PublishingDomains` and use those constants in delivery tests. Keep the existing publisher API/storage and do not add domain handlers or a new validation policy. Verify with the existing focused delivery/backend suite and Ruby style checks.
- `DomainEvents::Dispatch.call(limit: 100)` discovers missing deliveries from retained events, then processes a bounded due batch. New subscribers bootstrap from retained matching events. Missing, failed and delayed predecessor receipts block later matching stream events for that subscriber only; unrelated subscribers/streams proceed.
- User-before-delivery locking and atomic handler writes/receipt prevent duplicate committed effects. Retry StandardError failures after rolling back handler writes in a savepoint. Exponential delay starts at 5 seconds, caps at 5 minutes; 10 attempts becomes failed/manual retry. Store only exception class, never private exception text/payload. Fatal termination rolls back the transaction, leaving work discoverable. Connection/framework failures outside recovery propagate to backend.
- Expired/deleted users get skipped receipts without handler invocation. Foundation-owned user-to-stream-to-event-to-delivery cascades remove payloads on physical cleanup; no Identity changes. In-place claim retains stream ownership. Jobs carry no private payload or user ID.
- Initial retention: no age-based active-owner purge, so future consumers can bootstrap. Physical user deletion purges dependent infrastructure rows. Monitor size and outstanding age. Active-owner compaction needs a later explicit subscriber checkpoint/bootstrap policy; no silent loss and no promise of permanent history.
- Developer status/retry tasks expose counts, oldest pending age, failure IDs/classes only. Manual retry resets only failed work. Completed receipts cannot be reset for accidental replay; an explicitly approved new subscriber name can rebuild from retained events.

## Scope restrictions

- Foundation only; no product-domain application changes, real domain handlers or Identity callbacks. Consume established User activity/locking and scoped FK cleanup contracts.
- No broker, event sourcing, general workflow engine, network handler calls, new hosting, deployment, publication or merge. Database writes during verification are test-only.
- Handler transactions must not perform external side effects; separate jobs for deferred AI. Domain contracts own payload meaning and minimal data; transport validates JSON objects and never logs payloads. Operational diagnostics are developer-only.

## Acceptance criteria

- **AC1:** Source state, event and sequence commit/rollback together; envelope and constraints hold.
  Check: publication/rollback/retry, transaction requirement, unavailable user, concurrent appends, immutability and direct storage constraints.
  Result: Passed — full CI (`RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`) includes the publication, storage and concurrent append tests in `test/services/domain_events/`: 292 tests / 3,020 assertions overall, no failures/errors/skips.
- **AC2:** Independent ordered subscribers retry safely and commit effects exactly once per receipt.
  Check: handler-write rollback, retries/backoff/manual recovery, blocked predecessor, duplicate workers on separate connections, unrelated stream progress and late subscriber bootstrap.
  Result: Passed — the same CI run covers independent retries, failed/missing predecessors, manual recovery, concurrent delivery, hard interruption and bootstrap. Focused command: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/domain_events test/jobs/dispatch_domain_events_job_test.rb` passed 20 tests / 125 assertions, including the operational status test.
- **AC3:** Durable polling and retention work.
  Check: persisted GoodJob job and actual backend execution in test DB, job after process failure/retry, real Identity claim/cleanup, skip expired/deleted owners, cascading deletion with shared films retained.
  Result: Passed — `test/jobs/dispatch_domain_events_job_test.rb` persists and executes real GoodJob jobs, kills a separate worker process with SIGKILL and verifies recovery with one committed effect. Claim, expiry and physical cleanup checks passed in the same CI run. The initial crash-test failure was caused by a frozen parent clock behind the child clock; using real time resolved it. No development/production worker or deployment was run.
- **AC4:** Operational and repository checks pass.
  Check: scoped tests (record paths), `RAILS_ENV=test bin/rails db:migrate`, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record actual commands/results and document worker/status/retry operations.
  Result: Passed — test-only migrations applied; full CI passed (292 tests / 3,020 assertions, 164 Ruby files clean, dependency audits and Brakeman clean). `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading (existing test mail-preview directory excluded). `RAILS_ENV=test bin/jobs --help` and `git diff --check` passed. Status coverage checks undiscovered work and sanitized failure details. See `docs/domain_event_operations.md` for reproducible worker/status/retry commands.

- **AC5 (review follow-up):** Production publisher identifiers are shared constants used by delivery tests, including the separate worker process.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/domain_events test/jobs/dispatch_domain_events_job_test.rb`; scoped RuboCop and `git diff --check`.
  Result: Passed — 20 tests / 125 assertions, no failures/errors/skips; four changed Ruby files clean and whitespace check passed. Full CI results above precede this constants-only follow-up.

## Implementation notes

Implemented the outbox, immutable event envelope, ordered independent receipts, bounded dispatcher, sanitized failure reporting, retry/status operations and GoodJob worker configuration. Replaced the unmerged Solid Queue dependency/configuration/schema; its test tables were rolled back before applying the generated GoodJob migration. After-commit enqueue provides notification-driven wakeups, with a 30-second recovery sweep. The registry remains empty. GoodJob dashboard access and deployment are excluded. Owner approved asynchronous design and implementation. Owner selected GoodJob after comparing backend recovery, dashboard and connection requirements; same database keeps event/receipt/local effect transactions atomic. Domain publisher/subscriber tasks remain separate.

Owner acceptance / merge: Pending.

Worker smoke check: `RAILS_ENV=test bin/jobs --idle-timeout=2` exited successfully against the test database. Cron remained disabled in test; this verifies external worker startup/shutdown, not a deployed scheduler or end-to-end notification latency.
