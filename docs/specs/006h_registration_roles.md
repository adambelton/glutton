# 006h — Registration role ownership

Status: Ready for review  
Owner: Identity / registration

## Goal

Registration eligibility and lifetime belong to the current User role; existing registration services coordinate locking and type transitions. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Replace eligibility-by-UserGuest selection with locked User resolution and can_register?. Keep registration lifetime on PendingRegistration; linked-user lifetime is private and consulted only through active?. Move pending attachment rules to PendingRegistration. Keep existing public ID arguments, browser ownership, conflict/unavailable outcomes and guest-before-pending lock order. Update registration-specific HTTP gates and affected outcome tests.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- Do not change sessions/cookie presentation, credential recovery, User root construction, Film knowledge, schema or established external contracts beyond the owner-directed registration reminder copy.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — Registration model/operation/browser checks passed initially with 90 tests/850 assertions. After all Identity changes, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models test/services/identity test/integration test/controllers test/migrations test/services/library` passed 183 tests/1,571 assertions, including real separate-connection claim/cleanup/expiry races and Library compatibility.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

User defaults deny registration; UserGuest supplies active persisted permission and the unchanged 24-hour deadline. Registration operations resolve locked User roles rather than UserGuest selections. PendingRegistration owns attachment/availability and asks the fresh linked user whether it is active; transition operations separately ask registration permission; its existing guest_user association now loads User roles without renaming the established ID/schema contract. CompleteRegistration retains sibling/destination knowledge, becomes!, validated save context, session replacement and pending consumption. Registration-specific HTTP gates use action permission. Storage constraints, external token validation and narrow duplicate-email exception recovery are retained. No cross-domain contract changed.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Pending.

PR review correction: remove the remaining UserRegistered class guard from duplicate-email validation recovery. Scope recovery to the target user save, check failed-object identity rather than its class, and preserve propagation of unrelated validation failures (including nested callback failures). Verify existing conflict/rollback/concurrency outcomes and add a focused foreign-record failure regression. Verification: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/complete_registration_test.rb test/services/identity/complete_registration_concurrency_test.rb` passed 12 tests/134 assertions; full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 220 tests/2,559 assertions, zero failures/errors/skips, style/security checks clean. `git diff --check` passed.

Expiry encapsulation correction: remove User#registration_expires_at and PendingRegistration#guest_expires_at. PendingRegistration#expires_at is solely its own creation + 24 hours; active? additionally consults a fresh linked User#active?. Registration eligibility remains a separate can_register? question in transition workflows. Keep guest expiry calculation inside UserGuest; cleanup selects through model-owned expiry scopes and checks active? under existing locks rather than deriving another model's deadline. Reminder UI shows only the registration deadline and localized general temporary-activity copy. This owner-directed change supersedes earlier effective-deadline display/lifetime wording. Update exact-boundary, cleanup, token issuance and rendered-copy tests. Verification: focused `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/user_test.rb test/models/pending_registration_test.rb test/services/identity test/integration/registration_flow_test.rb` passed 100 tests/896 assertions. Full CI passed 220 tests/2,560 assertions, zero failures/errors/skips; style (122 files) and security checks clean; git diff --check passed.
