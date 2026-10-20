# 006h — Registration role ownership

Status: Ready for review  
Owner: Identity / registration

## Goal

Registration eligibility and lifetime belong to the current User role; existing registration services coordinate locking and type transitions. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Replace eligibility-by-UserGuest selection with locked User resolution and can_register?. Delegate linked request lifetime to the user. Move pending attachment rules to PendingRegistration. Keep existing public ID arguments, browser ownership, conflict/unavailable outcomes and guest-before-pending lock order. Update registration-specific HTTP gates and affected outcome tests.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- Do not change sessions/cookie presentation, credential recovery, User root construction, Film knowledge, schema, locales or established external contracts.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — Registration model/operation/browser checks passed initially with 90 tests/850 assertions. After all Identity changes, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models test/services/identity test/integration test/controllers test/migrations test/services/library` passed 183 tests/1,571 assertions, including real separate-connection claim/cleanup/expiry races and Library compatibility.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

User defaults deny registration; UserGuest supplies active persisted permission and the unchanged 24-hour deadline. Registration operations resolve locked User roles rather than UserGuest selections. PendingRegistration owns attachment/availability and asks the fresh linked user for eligibility/lifetime; its existing guest_user association now loads User roles without renaming the established ID/schema contract. CompleteRegistration retains sibling/destination knowledge, becomes!, validated save context, session replacement and pending consumption. Registration-specific HTTP gates use action permission. Storage constraints, external token validation and narrow duplicate-email exception recovery are retained. No cross-domain contract changed.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Pending.
