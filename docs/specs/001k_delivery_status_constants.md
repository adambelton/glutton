# 001k — Delivery status constants

Status: Ready for review  
Owner: Foundation / domain event delivery

## Goal

Give delivery statuses named constants and one shared terminal-status collection, preserving existing delivery behaviour. Owner authorized inclusion alongside task 014 on 21 October 2026; this remains a separate Foundation-owned change.

## Scope

- Define frozen PENDING, FAILED, PROCESSED, IGNORED and SKIPPED strings inside EventDelivery::Statuses, plus TERMINAL built from those constants.
- Reference constants from EventDelivery, Deliver, Status and Dispatch. Bind TERMINAL into the existing predecessor SQL query.
- Replace stored-status literals in delivery, concurrency and job tests. The job test is one additional affected test file found during the full usage search.

## Scope restrictions

- No schema or stored-value changes, migrations, new statuses, retry/ordering changes, subscriptions or product-domain changes.
- Handler outcome symbols and dispatcher result keys retain their existing contract. Subscriber names and unrelated strings are not delivery statuses.
- Historical migration literals remain independent of runtime constants. No generic state framework or unrelated cleanup.

## Acceptance criteria

- **AC1:** Existing processing, ignored/skipped completion, retry, failure, stream ordering and recovery behaviours remain unchanged.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/domain_events test/jobs/dispatch_domain_events_job_test.rb`.
  Result: Passed — 24 tests / 155 assertions, zero failures/errors/skips. Existing tests cover processing, ignored/skipped outcomes, failure/retry, blocked predecessors, independent streams, concurrent delivery and job recovery.
- **AC2:** Repository checks pass with the combined pending Ratings changes.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`.
  Result: Passed — full CI: 338 tests / 3,494 assertions, zero failures/errors/skips; RuboCop 185 files clean, dependency audits clean and Brakeman zero warnings/errors. Application eager loading passed with the existing test/mailers/previews exclusion notice; `git diff --check` passed.

## Implementation notes

Implemented nested frozen status constants and the shared terminal collection across four production files and three test files. Dispatch binds the collection into its existing predecessor query. No schema, stored values, handler outcomes or delivery behaviour changed. No scope deviations beyond the explicitly recorded additional job-test references.

Spec authorization: Owner approved this follow-up. Implementation acceptance / merge: Pending.
