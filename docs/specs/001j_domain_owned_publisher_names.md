# 001j — Domain-owned publisher names

Status: Merged
Owner: Foundation / event delivery

## Goal

Remove product-domain membership policy from event transport, as approved by the owner. Publishers own stable identifiers; Foundation enforces stream structure.

## Scope

- Remove DomainEventStream::PublishingDomains and inclusion validation; validate publisher presence instead.
- Remove only the database publisher allowlist with a new migration, preserving non-null/nonempty identity and unique user/publisher/stream constraints. Preserve historical migrations.
- The established Publish inputs/results/failures remain unchanged except new nonblank publisher names are accepted; blank publisher validation fails without events.
- Test Foundation with synthetic publisher names, including a new publisher through delivery and validation-bypassing storage checks.
- Library adopts its own identifier separately in task 012a after provider verification.

## Scope restrictions

No publisher registry, discovery, domain handlers, deployment, new domains or changes to delivery/retry/retention semantics. No product-domain changes in this task.

## Acceptance criteria

- **AC1:** A new publisher works without modifying Foundation; publisher streams remain independent and blank names fail.
  Check: focused Foundation delivery/job tests, including new-name delivery, blank validation, non-null/nonempty and unique database constraints.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/domain_events test/jobs/dispatch_domain_events_job_test.rb`: 24 tests / 155 assertions, zero failures/errors/skips. New synthetic publisher delivery and independent streams work; blank validation and non-null/nonempty/unique storage constraints remain enforced.
- **AC2:** Migration removes only the allowlist and application checks pass.
  Check: migrate the test database; run full CI, Rails autoload check and git diff check. Inspect schema.
  Result: Passed — `RAILS_ENV=test bin/rails db:migrate` applied 20261021170000 to the test database. Schema diff removes only the publisher allowlist. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 301 tests / 3,175 assertions, zero failures/errors/skips; style and security checks passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed for application code (existing test preview directory is not eager loaded); `git diff --check` passed.

## Implementation notes

Implemented after owner approval. Foundation tests use synthetic publisher identifiers without depending on product domains. An initial storage test used stale in-memory attributes after a rejected write; refreshing the test record fixed the assertion, and the focused suite passed before Library adoption. Only the test database was migrated. Migration rollback restores the old allowlist and will reject data using newer publisher names; no automatic deletion or renaming is allowed.

Owner acceptance / merge: Accepted by the owner and merged via [PR #26](https://github.com/adambelton/glutton/pull/26) on 21 October 2026 at 16:49:30 UTC; squash commit `f4d911344a830b413fba9ea85aa2b44ce5b07a3e`. Hosted Repository checks passed on head `a703a329ec21302e2e57f8741f1e55e512715f73` before merge.
