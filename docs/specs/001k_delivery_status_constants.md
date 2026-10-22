# 001k — Delivery status constants and scopes

Status: Merged — PR #28 on 21 October 2026  
Owner: Foundation / domain event delivery

## Goal

Give delivery statuses named constants and status-selection scopes, preserving existing delivery behaviour. Owner authorized inclusion alongside task 014 on 21 October 2026; this remains a separate Foundation-owned change.

## Scope

- Define frozen PENDING, FAILED, PROCESSED, IGNORED and SKIPPED strings inside EventDelivery::Statuses. The completed scope groups the three completion statuses directly; no separate collection constant is needed.
- Reference constants from EventDelivery and Deliver. Reuse EventDelivery.completed in Dispatch's predecessor query and add EventDelivery.outstanding (pending or failed) for Status reporting.
- Reuse completed and outstanding for status-array queries, and failed for the status report, as subsequently requested by the owner. Keep existing subscription, discovery, ordering and predecessor queries in place.
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

Implemented named frozen statuses and the completed/outstanding/failed status scopes across four production files and three test files. Dispatch reuses completed in its existing predecessor subquery; Status reuses outstanding and failed. The single-use TERMINAL collection has been removed. No schema, stored values, handler outcomes or delivery behaviour changed.

Review correction: I interpreted the request for scopes too broadly and added subscription, discovery, ordering and readiness scopes without establishing that scope with the owner. Those additions have been removed, including all changes to DomainEvent. The backlog-age regression remains relevant to outstanding status reporting. After narrowing the change, the focused command passed 25 tests / 158 assertions and full CI passed 339 tests / 3,497 assertions with clean style/security checks. `git diff --check` passed.

Spec authorization: Owner approved this follow-up. Implementation acceptance / merge: Approved and merged; see merge evidence below.

Final owner clarification: scope extraction is limited to status-array queries. Removed the added failed scope as well. Focused delivery/job tests passed again (25 tests / 158 assertions), targeted RuboCop passed for the two changed Ruby files, and `git diff --check` passed. Full CI above predates this final removal.

Subsequent owner request: restored only EventDelivery.failed for use in DomainEvents::Status. Focused delivery/job tests passed (25 tests / 158 assertions); targeted RuboCop for both changed Ruby files and `git diff --check` passed. Full CI was not rerun for this scope extraction.

## Merge evidence

Owner approved and merged [PR #28](https://github.com/adambelton/glutton/pull/28) on 21 October 2026 at 19:18:59 UTC (20:18:59 BST), squash commit `18454ac916f3f208eb2a113a674b0664fee1b278`. GitHub Repository checks passed on exact head `01201d1f10704bcfe2b5800938ea68fb36fbfea2` before merge. Local main was fast-forwarded.
