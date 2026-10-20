# 006r — Confirm an unattached registration with the current guest

Status: Ready for review  
Owner: Identity / registration

## Goal

Allow a valid confirmation token for an unattached registration to upgrade the current active guest, including when signup began in another browser.

## Scope

- Remove pending_registration_id from confirmation operations and authorization; token identifies the registration, current identity identifies the guest.
- Permit unattached registration or matching linked guest; reject a different linked guest and registered current users. Preserve anonymous completion.
- Preserve the existing conflicting-pending-request rejection when the current guest already has another linked pending registration; no implicit replacement or merge.
- Verify real separate-browser GET/POST, guest/session continuity, conflicts, rollback and concurrent claims. Update PR #22.

## Scope restrictions

- Identity only. Keep browser pending-registration tracking for signup, resend and guest creation.
- No schema, expiry, token format, auto-login, cross-domain or ordinary attachment contract changes. GET never attaches; POST retains user-before-pending locking and atomic rollback.
- No deployment, live email, acceptance or merge.

## Acceptance criteria

- **AC1:** Signup in one browser can be confirmed in another browser with an active guest and no matching pending ID; GET is read-only and POST upgrades that guest and revokes its old sessions.
  Check: service and separate-browser integration tests, initially against the old implementation, then after the fix.
  Result: Passed — before the fix, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/registration_flow_test.rb --name /signup_in_another_browser/` failed (expected 200, actual 409; 1 test / 5 assertions). After the fix, `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/identity/registration_browser_operations_test.rb test/services/identity/complete_registration_concurrency_test.rb test/integration/registration_flow_test.rb` passed 40 tests / 388 assertions. The integration uses separate browser sessions without copying cookies.
- **AC2:** Linked-other-guest, registered-user and conflicting pending-request cases fail without mutation; expiry, replay, anonymous completion, rollback and concurrent completion remain safe.
  Check: existing and updated confirmation/concurrency tests; full local CI.
  Result: Passed — full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 235 tests / 2,662 assertions, zero failures/errors/skips (seed 45777). Includes competing different guests, existing same-guest concurrency, expired/registered identities, linked-other-guest conflicts, conflicting pending requests and rollback/retry. RuboCop 127 files clean; dependency audits clean; Brakeman zero errors/warnings.
- **AC3:** Confirmation has no pending-registration ID argument; tracking outside confirmation remains; evidence and plan are updated.
  Check: scoped diff, reference search, git diff --check and PR publication.
  Result: Passed — confirmation controller/services and authorization no longer accept or read pending_registration_id; ordinary signup, resend and guest attachment retain it. Scoped diff inspected and `git diff --check` passed. README, architecture and plan updated. PR #22 remains the authorized review destination.

## Implementation notes

Removed the pending ID argument through the confirmation call chain. Authorization now requires a user who can register and an unattached request or matching linked user. POST retains existing attachment checks, locking and transaction semantics. Replaced the synthetic cookie-copy test with the actual separate-browser flow; added competing-guest and conflicting-state coverage. The existing prohibition on replacing another pending request linked to the current guest remains unchanged. No schema or UI copy changes. Verification used isolated test records and fake/local mail; no live mail, deployment, owner acceptance or merge.

Owner acceptance / merge: Pending.
