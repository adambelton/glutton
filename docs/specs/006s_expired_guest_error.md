# 006s — Explicit expired-guest session failure

Status: Ready for review
Owner: Identity / guest lifecycle

## Goal

Give expired guests a specific inactive error through the existing User/Session contract, as requested by the owner.

## Scope

- UserGuest#inactive_error returns Identity::GuestExpired when expired, nil while active. Session.resume raises the supplied error using its existing fresh user lookup.
- The browser current_user boundary handles GuestExpired by clearing the expired cookie and returning nil, preserving existing expiry behaviour and allowing subsequent guest creation. Deleted-account handling remains unchanged.

## Scope restrictions

- Identity only; no Library changes, lifetime changes, schema, new screens/copy, registration transitions or cleanup changes.
- No generic error framework, deployment, publication or merge.

## Acceptance criteria

- **AC1:** Active guests resume normally; expired guests raise GuestExpired at and after the deadline, including with a missing session binding.
  Check: session boundary tests using UserGuest::EXPIRY_DURATION.
  Result: Passed — focused suite 27 tests/139 assertions; active resumption and exact/after-deadline failures verified.
- **AC2:** Existing browser expiry, deleted-account, cookie and guest recreation behaviour remains intact.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/session_test.rb test/integration/user_sessions_test.rb test/controllers/concerns/identity/user_sessions_test.rb` and `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`; `git diff --check`.
  Result: Passed — full CI 252 tests/2,769 assertions, zero failures/errors/skips; 135 Ruby files clean, dependency audits clean, Brakeman zero warnings/errors. Existing browser expiry and deleted-account tests pass. `git diff --check` passed.

## Implementation notes

Added the model-owned GuestExpired error and a narrow rescue at the browser session boundary. Session.resume remains unchanged and propagates the model-provided error. Existing browser fallback semantics are retained; no other-domain code changed.

Owner acceptance / merge: Pending.
