# 001k — Delivery status constants

Status: Ready for review  
Owner: Foundation / domain event delivery

## Goal

Give delivery statuses named constants and one shared terminal-status collection, preserving existing delivery behaviour. Owner authorized inclusion alongside task 014 on 21 October 2026; this remains a separate Foundation-owned change.

## Scope

- Define frozen PENDING, FAILED, PROCESSED, IGNORED and SKIPPED strings inside EventDelivery::Statuses, plus TERMINAL built from those constants.
- Reference constants from EventDelivery and Deliver. Reuse EventDelivery.completed in Dispatch's predecessor query and add EventDelivery.outstanding (pending or failed) for Status reporting.
- Replace stored-status literals in delivery, concurrency and job tests. The job test is one additional affected test file found during the full usage search.

## Scope restrictions

- No schema or stored-value changes, migrations, new statuses, retry/ordering changes, subscriptions or product-domain changes.
- Handler outcome symbols and dispatcher result keys retain their existing contract. Subscriber names and unrelated strings are not delivery statuses.
- Historical migration literals remain independent of runtime constants. No generic state framework or unrelated cleanup.

## Acceptance criteria

- **AC1:** Existing processing, ignored/skipped completion, retry, failure, stream ordering and recovery behaviours remain unchanged.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/domain_events test/jobs/dispatch_domain_events_job_test.rb`.
  Result: Passed — 25 tests / 158 assertions, zero failures/errors/skips. Existing tests cover processing, ignored/skipped outcomes, failure/retry, blocked predecessors, independent streams, concurrent delivery and job recovery.
- **AC2:** Repository checks pass with the combined pending Ratings changes.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`.
  Result: Passed — full CI: 339 tests / 3,497 assertions, zero failures/errors/skips; RuboCop 185 files clean, dependency audits clean and Brakeman zero warnings/errors. Application eager loading passed with the existing test/mailers/previews exclusion notice; `git diff --check` passed.

## Implementation notes

Implemented nested frozen status constants and the shared terminal collection across four production files and three test files. Dispatch uses the completed scope in its predecessor subquery; Status uses the outstanding scope. No schema, stored values, handler outcomes or delivery behaviour changed. No scope deviations beyond the explicitly recorded additional job-test references.

Review follow-up: reused `completed` in Dispatch via an owner-independent, subscriber-scoped event-ID subquery; added `outstanding` for pending/failed backlog reporting. The subquery selects non-null event IDs, preserving predecessor blocking before the limit. Added a backlog-age regression covering pending, failed and completed work. Re-ran the focused command and full CI above successfully; `git diff --check` passed.

Spec authorization: Owner approved this follow-up. Implementation acceptance / merge: Pending.
