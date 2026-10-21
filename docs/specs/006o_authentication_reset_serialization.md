# 006o — Serialize authentication with password recovery

Status: Merged  
Owner: Identity / sessions

## Goal

Prevent an in-flight old-password sign-in from surviving a completed password reset (audit A1).

## Scope

- Wrap credential verification and session creation in one user-locking transaction. Keep credential validation on UserRegistered and existing Authenticate inputs, Session/nil results and unexpected failure propagation.

## Scope restrictions

- No registration, cookie, password policy, schema, other-domain or delivery changes. No new authentication framework or model classification checks.
- No automatic acceptance or merge. User authorized these fixes on 20 October 2026.

## Acceptance criteria

- **AC1:** Both orderings serialize: sign-in first is revoked by reset; reset first rejects old credentials and allows the replacement password.  
  Check: Run deterministic separate-connection tests of both orderings, existing authentication/recovery/sign-in tests, then repository checks.  
  Result: Passed — Added deterministic PostgreSQL tests for both orderings. Before the fix, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/password_recovery_concurrency_test.rb` failed with an active Session where nil was expected (4 runs, 8 assertions, one failure). After the fix, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/authenticate_test.rb test/services/identity/password_recovery_concurrency_test.rb test/services/identity/reset_password_test.rb test/integration/sign_in_test.rb test/integration/password_recovery_test.rb` passed 32 tests / 384 assertions, zero failures/errors/skips.
- **AC2:** Changes stay within this owner and the stated scope; actual evidence and limitations are recorded.  
  Check: inspect scoped diff; record reproducible commands/results and mark Ready for review.  
  Result: Passed — Scoped diff inspected; no other-domain implementation changes within this task. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed: 232 tests / 2,633 assertions, zero failures/errors/skips (seed 41651); RuboCop 127 files clean; gem/importmap audits clean; Brakeman zero errors/warnings. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

Authenticate now applies the user row lock to model-owned credential verification and keeps it through session issuance in one transaction. Recovery already uses that lock. Both concurrent orderings are exercised with separate PostgreSQL connections and observable session/password outcomes. No password policy, model credential rule, schema or transport changes. The original race probe remains historical audit evidence; the new regression tests verify the corrected serialization without that probe's old timing assumption.

Verification used isolated local test records and deterministic fake providers. Local database/process/network checks required approved sandbox elevation. No live mail, live TMDB request, deployment, hosted CI, PR or merge occurred.

Owner acceptance / merge: Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge.

Publication authorization: On 20 October 2026, the owner requested a PR for online review. Acceptance and merge remain pending.
