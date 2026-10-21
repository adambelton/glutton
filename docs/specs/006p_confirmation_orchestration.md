# 006p — Simplify registration confirmation

Status: Merged  
Owner: Identity / registration

## Goal

Give confirmation one transaction coordinator and one shared eligibility rule (audit A2 and the authorized complexity reduction).

## Scope

- CompleteRegistration owns source-before-pending locking, fresh token validation, optional browser-owned attachment and transition. CompleteBrowserRegistration preserves its public entry point as a delegate. PendingRegistration resolves its confirmation token and owns confirmation access for an actual user; GET and locked completion call those same behaviours. Preserve direct/guest completion, Session result, RegistrationUnavailable/RegistrationConflict failures, replay/expiry, uniqueness and rollback. Add optional browser context to the existing Identity coordinator only; no cross-domain contracts change.

## Scope restrictions

- No submission/delivery/session-concern rewrite, schema, lifetime, token format, UI copy, account merging, other-domain changes or general authorization framework. GET must not attach or mutate. Anonymous confirmation may claim a linked guest as before. Always recheck fresh state under locks; do not authorize mutation from a prior GET result.
- No automatic acceptance or merge. User authorized these fixes on 20 October 2026.

## Acceptance criteria

- **AC1:** GET and completion agree for anonymous, matching/unrelated guest, browser-owned unattached request and registered users; stale/expired and concurrent state changes cannot grant access; failed completion rolls back attachment.  
  Check: Run model/read-resolution and browser integration tests, registration concurrency/retention tests and full repository checks; inspect call graph for nested completion/attachment workflow removal.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/pending_registration_test.rb test/services/identity test/integration/registration_flow_test.rb test/services/library/retention_test.rb test/services/library/watched_concurrency_test.rb` passed 104 tests / 922 assertions before the additional confirmation regressions. With those regressions, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/registration_browser_operations_test.rb test/services/identity/complete_registration_concurrency_test.rb test/integration/registration_flow_test.rb test/services/film_knowledge` passed 64 tests / 1,194 assertions. Full CI below includes final code and all new tests.
- **AC2:** Changes stay within this owner and the stated scope; actual evidence and limitations are recorded.  
  Check: inspect scoped diff; record reproducible commands/results and mark Ready for review.  
  Result: Passed — Scoped diff inspected; no other-domain implementation changes within this task. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed: 232 tests / 2,633 assertions, zero failures/errors/skips (seed 41651); RuboCop 127 files clean; gem/importmap audits clean; Brakeman zero errors/warnings. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

PendingRegistration now owns token resolution and confirmation access for an actual user. GET delegates those checks without attachment; it still resolves the browser identity first so deleted-account failures remain explicit. CompleteRegistration owns a single source-before-pending transaction, fresh locked token resolution, browser-owned attachment and account transition. CompleteBrowserRegistration preserves its established entry point as a delegate; it no longer starts a transaction or calls AttachRegistration. Existing non-confirmation attachment callers retain their operation. Tests cover GET/POST conflicts, GET without attachment, concurrent browser completion, rollback after attachment and explicit retry, alongside existing expiry/replay/cleanup/claim compatibility. No broad submission, delivery or session-concern rewrite. A request invalid on both token and browser eligibility now resolves token failure first; valid-token eligibility failures retain RegistrationConflict. No access is granted by either failure.

Verification used isolated local test records and deterministic fake providers. Local database/process/network checks required approved sandbox elevation. No live mail, live TMDB request, deployment, hosted CI, PR or merge occurred.

Owner acceptance / merge: Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge.

Publication authorization: On 20 October 2026, the owner requested a PR for online review. Acceptance and merge remain pending.
