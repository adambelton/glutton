# 006m — Pending registration lifetime constant

Status: Merged  
Owner: Identity / registration lifetime

## Goal

A shorter pending-registration lifetime is defined once and used by its expiry logic and tests. Guest expiry remains independent and internal to UserGuest.

## Scope

- Add PendingRegistration::EXPIRY_DURATION and use it in expires_at and expired scope. Use a one-hour default, selected by the owner and used as the sole deadline for both registration and confirmation links.
- Replace remaining registration-relative 24-hour ages/travel/assertions with that constant or the registration-owned deadline. Keep guest duration independent.
- Remove the separate confirmation-token expires_in timer. Bind token validity to registration active state and its own deadline, so token lookup and every issuance/redemption flow reject expired requests; resending never renews the original deadline.
- Preserve registration/token expiry enforcement, bounded cleanup, guest continuity, locks, conflict outcomes and localized reminder deadline rendering.

## Scope restrictions

- No change to guest duration, password-reset lifetime, schema, external services, other domains, deployment or merge. Update PR #21 for review only.
- Do not couple request lifetime to guest lifetime or change password-reset token expiry. Confirmation expiry unification is explicitly owner-directed. Tests may arrange valid near-deadline fixtures but must still verify exact boundaries and meaningful failures.

## Acceptance criteria

- **AC1:** One shorter request-duration constant governs registration expiry, query selection and expiry-sensitive tests.
  Check: focused model/registration/browser/cleanup tests, including exact boundary and fresh linked guest survival. Search remaining 24-hour values and verify only the guest policy constant retains that value in runtime code.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/pending_registration_test.rb test/services/identity test/integration/registration_flow_test.rb test/controllers/concerns/identity/user_sessions_test.rb`: 101 tests, 912 assertions, zero failures/errors/skips. Initial and reissued links work immediately before the original deadline and fail exactly at it. `rg -n '24\.hours|23\.hours|25\.hours|26\.hours|expires_in: 1.hour' app test` finds only the guest policy constant.
- **AC2:** Independent lifetimes and repository checks pass.
  Check: full CI, whitespace checks and temporary shorter/longer policy test runs with the selected default restored afterward. Record actual results here.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 225 tests, 2,585 assertions, zero failures/errors/skips; RuboCop 125 files clean; dependency audits clean; Brakeman zero warnings/errors. Temporarily set PendingRegistration::EXPIRY_DURATION to `30.minutes` and `2.hours`, running `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` each time: both passed 225 tests / 2,585 assertions. Restored `1.hour` before full CI. `git diff --check` passed.

## Implementation notes

Owner requested a substantially shorter pending lifetime and constant reuse; duration preference was requested while independent test cleanup proceeded; the owner selected one hour. The owner then requested one expiry owner for registration and its confirmation links; the independent token timer is removed.

Owner acceptance / merge: Accepted by owner and merged in [PR #21](https://github.com/adambelton/glutton/pull/21) on 20 October 2026; verified merge commit `0fa54269df0140451ab19ac5b665fb64d6cc3c50`.
