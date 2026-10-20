# 006i — Browser session role ownership

Status: Ready for review  
Owner: Identity / browser sessions

## Goal

Browser session binding and visible user actions rely on model behaviour rather than concrete User subclasses. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Delegate deleted-account access outcome and session remembrance policy to User behaviour. Preserve pending continuity using registration permission. Use Rails polymorphic rendering for existing localized session UI and model-owned sign-out warning. Preserve cookie security, rotation, guest expiry and registered remembrance. Replace affected snapshots with named contract assertions.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- No registration transition mechanics, credential policy, root construction, schema or other domains.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/identity test/integration test/models/session_test.rb test/services/identity` passed 131 tests/1,188 assertions at the session-refactor stage. Final combined Identity/Library checks passed 183 tests/1,571 assertions, including cookie permanence/security, deleted-account response, expiry and pending browser continuity.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

User behaviour owns access rejection, sign-out warning and browser session remembrance. AccountDeleted is now an Identity error instead of a controller-nested class. Controller session binding uses those behaviours and registration permission; PendingRegistration owns browser availability. Home uses Rails polymorphic model partials, preserving existing localized guest/registered UI without runtime class switches. Session validation names its collaborator user and retains fresh database activity checks. Existing English locale keys are reused at runtime. Outcome tests preserve IDs/deadlines/session ownership instead of whole-row snapshots. No cookie security, rotation or registered server-session TTL policy changed; remembered browser expiry remains Rails' existing 20-year value.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Pending.
