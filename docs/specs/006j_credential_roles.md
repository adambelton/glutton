# 006j — Credential action ownership

Status: Ready for review  
Owner: Identity / credentials

## Goal

Credential authentication/reset actions and recovery permission are owned by User behaviour while workflows retain transaction, session revocation and delivery orchestration. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Keep input validation at credential/token boundaries. Centralize registered authentication and reset permission/actions. Replace HTTP subtype checks with action permission and identity comparison. Preserve anti-enumeration, same-account conflict, exact token expiry, validation and all-session revocation. Replace reflective method-availability tests and incidental snapshots with outcome checks; retain security payload inspection and focused failure injection.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- No registration transition rewrite, session transport policy, root construction, schema or other domains.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity test/integration/password_recovery_test.rb test/integration/sign_in_test.rb test/models/user_registered_test.rb` passed 92 tests/901 assertions. Final combined Identity/Library run passed 183 tests/1,571 assertions, including validation boundaries, replay/expiry, same-account recovery conflict, rollback, transport errors and concurrent resets.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

Registered credential authentication and password-reset mutation/session revocation are model-owned actions. User permissions express whether reset is supported and whether the current user may perform recovery for a target user. Workflow services retain token lookup, locks and delivery orchestration; HTTP uses permission and identity comparison rather than subtype checks. Replaced reflective token-method checks with token redemption/action outcomes and explicit rejection/no-session-change tests. Preserved token payload privacy inspection, exact expiration, anti-enumeration and narrow persistence-failure injection; those verify real security/rollback contracts rather than subtype dispatch.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Pending.
