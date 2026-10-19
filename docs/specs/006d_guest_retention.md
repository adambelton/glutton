# 006d — Expired Identity retention cleanup

Status: Ready for review  
Owner: Identity / retention

## Goal

Provide a bounded, repeatable cleanup command that physically deletes expired guests, their Identity-owned sessions and pending registrations, plus expired direct pending registrations. Preserve registered/deleted accounts and active guests under concurrent registration. Depends on tasks 002, 005, 006a, 006b and 006f. No other domain contract is consumed: there are currently no persisted product-activity records.

Read the implementation plan, product brief (Accounts and privacy), architecture brief (section 11), and the registration operations before implementation.

## Scope

### Expiry and deletion rules

- Keep the existing hard guest deadline `created_at + 24.hours`. A guest is eligible exactly at that deadline; activity, mail attempts and cleanup never extend it. Use existing `active?` semantics, without a new expiry column or lifecycle subtype.
- Physically delete expired GuestUser rows and their Session and PendingRegistration rows in one transaction per guest. Do not anonymise them into DeletedUser. Delete no RegisteredUser, DeletedUser or concrete User row, regardless of age; impose no registered-session TTL.
- Independently delete expired PendingRegistration rows, including direct signup with no guest and linked requests capped by the guest's original deadline. Use the existing `expires_at` policy: the earlier of pending creation plus 24 hours and linked guest creation plus 24 hours. A one-hour confirmation token expiring does not make the whole pending registration eligible for deletion; active requests must still be able to resend.
- Deleting a pending registration alone must preserve its guest and sessions. Never delete an account because it has an expired pending request or shares that request's email. Already completed registrations have no pending row and require no cleanup.
- Database expiry is enforced on access independently of this command. Cleanup is eventual; absence of an installed scheduler must not grant expired access or be represented as completed deletion.

### Bounded operation and concurrency

- Add `Identity::CleanupExpiredAccounts.call(batch_size: 100)`. Require an integer batch size from 1 through 1,000; reject invalid input before writes. Consider at most that many expired guest candidates and that many expired pending candidates per invocation, oldest first with ID as a stable tie-breaker. Select expiry candidates in SQL; do not load all users or all pending requests and filter in Ruby. No unbounded loop until the database is empty.
- Candidate selection is advisory. Re-read each guest under a row lock and recheck its current STI type and expiry before deleting anything. A guest upgraded to registered while cleanup waited must survive with its current sessions. A missing or no-longer-eligible candidate is a harmless skip.
- Use the same guest-before-pending lock order as preparation, attachment and completion. For a linked pending candidate, lock the referenced user first, then the pending row; recheck the link and deadline under those locks. If the link changed, skip and allow a later invocation to reconsider it. For direct pending candidates, lock and recheck the pending row. Do not lock a pending row and then acquire its guest lock.
- Guest cleanup deletes associated Identity rows before the user, satisfying the existing Session foreign key. Preserve referential integrity without disabling constraints or introducing global cascades. Pending-registration cascade behaviour may remain as established, but report deletions consistently.
- Return aggregate counts `{ guests_deleted:, pending_registrations_deleted: }`, counting pending rows removed both independently and with guests. Counts reflect committed deletion only. Concurrent runs must not count/delete the same row twice. No emails, digests, tokens or per-user IDs in routine command output.
- A persistence failure rolls back that candidate's complete transaction and propagates; do not swallow it, retry automatically, or continue claiming success. Earlier committed candidates remain deleted. Re-running is safe and continues remaining work. No whole-run transaction, SMTP call or network operation while holding locks.
- A confirmation completed before guest locking wins and preserves the registered identity. An expired guest cannot confirm under the existing rules; cleanup may remove it without making its old token usable. A mail attempt already reserved before cleanup may finish sending afterward; the resulting expired/deleted link remains unavailable. Do not add delivery coordination infrastructure to prevent that harmless late email.

### Operational entry point

- Add `bin/rails identity:cleanup_expired`, using the bounded default operation and aggregate-only output. Successful runs, including no-op runs, exit zero. Invalid configuration or persistence errors exit nonzero, without printing credentials or token-bearing records. Do not expose an HTTP cleanup endpoint.
- Document running the command every 15 minutes as the proposed operational cadence. One invocation processes one bounded batch in each category; a backlog can require subsequent invocations and there is no guaranteed deletion-within-15-minutes promise. Document manual invocation, batch limits, failure handling and safe re-run behaviour.
- This task supplies the command and its policy, not a deployed scheduler. Active Job is currently disabled and no queue infrastructure is installed; do not enable it or add a scheduling dependency for this operation. Scheduler installation and monitoring belong to a later deployment task using the established command.
- Update README and relevant brief/plan wording to distinguish implemented Identity cleanup, unconfigured scheduling and future product-activity deletion. Keep developer command diagnostics separate from localized user-facing application copy. Existing browser notices, missing-identity resolution and invalid-link responses should continue to work without new UI.

## Scope restrictions

- Identity records only. No changes to Library, Ratings, Recommendations or Film knowledge, including schema, callbacks, UI or invented deletion contracts. The current absence of product records makes this independently useful; it does not settle future activity-retention ownership.
- Before a future domain persists guest activity, agree that domain's deletion policy and synchronous deletion mechanism, and update retention in separately owned provider/consumer tasks. Do not silently drop a new foreign key, skip a domain's failure, or bypass constraints to make Identity deletion succeed. A foreign-key failure must leave that guest and its Identity rows intact.
- No registered-account deletion flow, restoration, session-age expiry, email collection/change, guest lifetime extension, new tables, migrations, token lifecycle changes or access-control changes.
- No generic retention framework, asynchronous domain events, jobs, queue backend, scheduler deployment, cron installation, distributed lock service, paid service or live email. No automatic deletion against development/production data as part of implementation verification; use isolated test records/databases.
- Owner approved implementation on 19 October 2026. Publication, deployment and merge remain separate.

## Acceptance criteria

- **AC1:** Exact expiry boundaries select only eligible Identity records.  
  Check: Frozen-time service tests cover one second before, exactly at and after 24 hours; active/expired guests with zero/multiple sessions; direct pending expiry; linked pending capped by an older guest; and a one-hour-old confirmation token whose pending registration remains active. Old registered/deleted users and their sessions survive. No user is selected by email.  
  Result: Passed — frozen-time service tests cover before/exact 24-hour guest expiry, direct pending expiry, linked guest deadline caps, active guests preserved when their pending row alone expires, and pending retention after the one-hour token lifetime. Old registered, deleted and base User identities and their Session rows survive. Guest and pending selection uses timestamps/foreign keys, never email.
- **AC2:** Deletion is bounded, atomic per candidate, idempotent and correctly counted.  
  Check: `PARALLEL_WORKERS=1 bin/rails test test/services/identity/cleanup_expired_accounts_test.rb`; test more candidates than each batch limit, stable oldest-first selection, aggregate counts including linked pending rows, invalid batch values before writes and zero-count re-runs. Inject failures after dependent deletion and at user deletion to prove full candidate rollback, including a foreign-key rejection. Verify previously committed candidates remain deleted and a subsequent invocation finishes safely.  
  Result: Passed — service tests cover stable oldest-first limits for both categories, aggregate pending counts, invalid batch inputs and the 1,000 upper bound, no-op repeats, dependent-delete failure rollback and test-only foreign-key rejection restoring all current-candidate rows. A separate-connection assertion proves earlier candidates stay committed after a later failure; a successful re-run finishes the failed candidate.
- **AC3:** Concurrent cleanup and registration preserve ownership and lifecycle invariants.  
  Check: Separate PostgreSQL connections with controlled row-lock synchronization test confirmation winning before a waiting cleanup, two cleanup runs considering the same guest/pending, and attachment/completion versus linked-pending cleanup using guest-before-pending order. Assert preserved registered identity/session, unavailable expired tokens, no double counts, no orphaned Identity rows and no deadlocks. Keep concurrency tests isolated and clean up only their own records.  
  Result: Passed — six nontransactional tests use separate PostgreSQL connections and observed lock waits. They cover confirmation winning before waiting guest cleanup, overlapping guest/direct-pending runs without double counts, attachment using guest-before-pending order, stale changed pending links skipped under locks, invalidated old confirmation tokens and earlier commits surviving failure. No orphaned Identity rows or deadlocks occurred.
- **AC4:** The command is safe to repeat and existing browser access fails appropriately after deletion.  
  Check: Invoke the rake task against isolated test data, asserting aggregate-only zero/nonzero exit behaviour and no private markers in output/errors. Browser-session tests replay a cleaned guest cookie and a cleaned pending confirmation link: neither restores deleted data; explicit new guest creation uses a fresh ID; registered/deleted-account behaviour remains unchanged. README states the proposed 15-minute cadence, bounded-backlog behaviour and that no scheduler is installed.  
  Result: Passed — test subprocesses execute the real bin/rails command against the current worker’s explicit test database. Successful and repeated runs return exact aggregate output/zero exit; simulated persistence/configuration failures return exit 1 with no private exception markers. Browser integration replays a cleaned guest cookie and confirmation link, rejects recovery and creates a fresh guest ID. Existing registered/deleted browser tests pass. README documents the proposed cadence/backlog and absent scheduler.
- **AC5:** Existing application checks pass and evidence is recorded accurately.  
  Check: Focused retention tests, `bin/rails zeitwerk:check`, `PARALLEL_WORKERS=1 CI=true bin/ci`, `git diff --check`. Record actual commands/results here, update plan to Ready for review and identify remaining scheduling/product-retention limitations. No network mail or real-data cleanup is required.  
  Result: Passed — PARALLEL_WORKERS=1 CI=true bin/ci: 162 tests, 1,537 assertions, zero failures/errors/skips. RuboCop: 87 files clean; gem/importmap audits: no vulnerabilities; Brakeman: zero warnings. bin/rails zeitwerk:check passed application eager loading; git diff --check passed. README, briefs and plan updated. Scheduler deployment and future product-activity deletion remain outside this task.

## Implementation notes

Implemented Identity::CleanupExpiredAccounts with bounded SQL candidate selection, guest-before-pending locks, fresh lifecycle/deadline checks and per-candidate transactions. The rake task emits aggregate counts or sanitized failure diagnostics and exits nonzero on failure. No schema changes, dependencies, queue or scheduler were added. Product/architecture briefs and README distinguish current Identity cleanup from future product retention and deployment scheduling. No scope deviation.

Reproduce verification from the repository root:

```sh
PARALLEL_WORKERS=1 bin/rails test test/tasks/identity_cleanup_test.rb test/integration/registration_flow_test.rb test/services/identity/cleanup_expired_accounts_test.rb test/services/identity/cleanup_expired_accounts_concurrency_test.rb
bin/rails zeitwerk:check
PARALLEL_WORKERS=1 CI=true bin/ci
git diff --check
```

The focused run passed 36 tests/359 assertions before the final three boundary assertions were added; the final full CI results under AC5 include them. Tests execute cleanup only against isolated test data. No command was run against development/production data, no real email was sent, and no scheduler was installed. Local CI uses one worker to avoid the previously observed macOS native parallel-fork crash. The existing development mail-preview directory remains outside eager-load paths; Zeitwerk reports application eager loading is good.

Owner acceptance / merge: Pending.
