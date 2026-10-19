# 006c — Password recovery

Status: Merged  
Owner: Identity / recovery

## Goal

A confirmed registered user can request a password-reset email and explicitly set a new password through its expiring link. A successful reset invalidates every existing session and requires fresh sign-in. Depends on credential/session rules and the mail/browser conventions established by tasks 004, 005a, 006 and 006f. No other domain contract is consumed.

Read the implementation plan, product brief (Accounts and privacy), architecture brief (section 11), task 006f and root AGENTS.md before implementation.

## Scope

### Token and reset operation

- Enable Rails' native `has_secure_password` reset-token support on RegisteredUser only, with an explicit 15-minute expiry. Keep GuestUser, DeletedUser and PendingRegistration ineligible. Use the existing password-salt binding so changing the digest invalidates all earlier reset links. Do not introduce custom signing, a reset-token table, plaintext-token persistence or a new dependency. The readable token payload must not expose email, plaintext password or the full password digest.
- Add `Identity::ResetPassword.call(token:, password:, password_confirmation:)`. Resolve and lock the token's RegisteredUser, revalidate purpose/expiry/password binding under that lock, and require active/confirmed status. Return the updated RegisteredUser after success. Expected malformed/invalid/expired/replayed/unavailable-account tokens raise a named Identity-owned `PasswordResetUnavailable` error without account details; invalid new credentials raise RecordInvalid with the model's localized errors. Unexpected database failures propagate.
- Assign the supplied password/confirmation and enforce the existing policy (required nonblank password and confirmation, minimum 15 characters, bcrypt maximum 72 bytes). Do not let a blank password reuse the existing digest and count as a successful reset. No password history, complexity changes or current-password challenge is required for this token-authorized operation.
- Save the new digest and revoke all Session rows for that account in one transaction. A failed save or failed revocation restores both the old digest and sessions; invalid credentials leave the token usable until expiry. Concurrent redemption permits one successful password change: the changed digest invalidates the waiting request's token. No automatic retry after failure and no new authentication Session on reset.

### Request and mail delivery

- Add a forgot-password link on the existing sign-in page and a small email request form. Use existing RegisteredUser email normalization/lookup; only a confirmed registered account may receive a reset email. Unknown addresses, guests and pending requests cause no account/session creation and no mail. Valid accepted requests return the same neutral result whether an eligible account exists; entering an email never authenticates or claims an account.
- Add `Identity::RequestPasswordReset.call(email_address:)` to look up the eligible user and synchronously call `Identity::AccountMailer.password_reset(recipient:, reset_url:).deliver_now` with its stored email and fresh token. Do not expose a target user ID in the public request interface. Return no account details. Requesting a link does not change credentials, revoke sessions or invalidate earlier unexpired links; the first successful password change invalidates them all.
- Use explicit APP_ORIGIN, never Host/redirect input, with the established production HTTPS/development localhost rules. Reuse those rules without coupling recovery to registration attempt counters; extract only a minimal Identity-owned origin helper if necessary and preserve registration behaviour/tests. Build a reset link for the exact stored recipient/token.
- SMTP runs outside database transactions and locks. Known SMTP/network failures show a localized retryable delivery failure with no provider details; do not claim the email was sent. Unexpected errors propagate. Successful neutral messaging must not promise inbox receipt. This means ordinary request responses are neutral, while a real transport failure is reported honestly; registration already explicitly exposes registered-email availability. No queue, automatic resend or delivery-tracking infrastructure.
- Before lookup/delivery, apply Rails limits of ten reset requests per three minutes per IP and one request per minute per normalized-email fingerprint, including unknown addresses. Use a nonreversible SHA-256 cache key rather than raw email. Reuse the per-worker memory-store approach and document restart/multiple-worker limitations; no new durable counters/tables or shared-cache deployment in this task. Multi-worker abuse controls remain a release requirement.

### Browser update and identity handling

- Use conventional Rails request/new/create and reset/edit/update actions with native forms. GET/HEAD reset links only validate/read and render; they never change a password, consume a link, revoke a session or send mail. PATCH/POST update requires a valid CSRF token and the reset token in a hidden field. Do not persist reset tokens/passwords in cookies, flash or local storage, or accept user/email identifiers to select the target account.
- Missing/invalid/expired/replayed links show one localized unavailable result with request-again/sign-in options. Invalid password input returns 422 with validation feedback, empty password fields and the same still-valid token. Render explicit confirmation of the password update through the form submission; no account transition from simply loading an email link.
- With no current identity, permit valid token use. A browser signed in to that same registered account may reset it; afterward clear its identity cookie and rotate Rails/CSRF state because its Session was revoked. A browser signed in as a different registered account receives a conflict requiring sign-out/another browser before mutation, without consuming the token or switching accounts. Deleted browser identities retain their existing explicit failure until sign-out.
- A current unrelated guest may reset the registered account authorized by the token without merging activity, claiming that guest or replacing its browser identity. Preserve that guest/pending state until the person explicitly signs in using the existing sign-in action. This operation changes the token's account password, not the browser's identity.
- Successful update redirects to sign-in with one localized success notice. Require the new password to sign in; the old password and every old registered-session cookie fail. There is no automatic login, arbitrary return URL, guest merge or permanent guest retention.
- Apply a separate limit of ten reset-update attempts per three minutes per IP before mutation. Use existing persistent-cookie settings when the user later signs in; do not add a session TTL.
- All UI, accessibility labels, validation messages and mail copy use locale entries. Add no-store/no-referrer to recovery pages and preserve full token-bearing URL/parameter/password filtering. Use small Rails controllers and domain-owned operations, standard model validations and explicit `.nil?`/`.present?` checks. No duplicate status banners/actions.

## Scope restrictions

- Identity recovery only. No product-domain records, rating/library changes, account deletion, registered email change, profile/settings screen, authenticated password-change workflow or alternate login provider.
- Preserve registration/guest deadlines, in-place claim, pending attachment and delivery behaviour. Only RegisteredUser gains reset-token generation; other model types must remain ineligible. Updating the earlier test that explicitly asserted RegisteredUser had no reset-token method is an intentional change to that earlier task's deferred capability, not a relaxation for guests.
- No reset-request audit model, generic notification/security framework, jobs, webhook, deployment, paid service, DNS/tunnel configuration or retention scheduler. No global SMTP change.
- No automatic live email or external communication authorized by this draft. Tests use local transport/intercepted SMTP. Any later manual live verification uses an owner-designated test account and records acceptance, inbox receipt and browser completion separately.
- Implementation authorized by the owner; publication and merge remain separate.

## Acceptance criteria

- **AC1:** Only eligible registered accounts receive purpose-bound 15-minute reset tokens; requesting mail never changes access.  
  Check: Model/service tests verify exact expiry, wrong purpose/tampering, invalidated digest binding, absence of sensitive payload markers, normalized lookup and ineligible/unknown inputs. Mail assertions verify exact stored recipient, trusted URL, neutral ordinary responses, no Session/User/PendingRegistration changes, no SMTP transaction and honest transport failure.  
  Result: Passed — native-token tests cover expiry at 900 seconds, wrong purpose/tampering, digest invalidation and payload privacy. Request tests cover normalized exact recipient/trusted URL, no identity mutations, ineligible inputs and sanitized transport failures. Nontransactional transport test acquires the same account row with FOR UPDATE NOWAIT on another connection and confirms no open transaction during delivery.
- **AC2:** Password update validates policy, atomically changes credentials/revokes every target session and rejects replay.  
  Check: `bin/rails test test/services/identity/reset_password_test.rb`; cover blanks, missing/mismatched confirmation, 14/15-character and 72/73-byte/multibyte boundaries. Verify failed validation preserves digest/sessions and token usability; successful reset rejects old password/token, authenticates the new password and leaves no target sessions. Inject revocation failure to prove full rollback. Use separate connections and controlled synchronization for duplicate redemption.  
  Result: Passed — reset service tests cover blank/nil passwords, absent/mismatched confirmation, 14/15 characters, 72/73 bytes and multibyte boundaries. Validation leaves digest/sessions/token intact; success deletes all target sessions, preserves unrelated sessions and invalidates both issued links. Injected SQL deletion failure rolls back the digest. A separate-connection test observes the waiting PostgreSQL lock and proves exactly one redemption succeeds.
- **AC3:** The browser flow requires an explicit CSRF-protected update and preserves identity boundaries.  
  Check: Real browser-session tests with CSRF enabled cover forgot-password/request/form, GET/HEAD no effects, invalid CSRF, missing/expired/replayed tokens, invalid password rerender and fixed success redirect. Test same-account cookie/CSRF clearing, other registered-account conflict, guest/pending preservation, deleted-account failure and old-cookie replay in another browser after reset. Assert no automatic authentication and subsequent successful new-password sign-in.  
  Result: Passed — CSRF-enabled integration tests cover GET/HEAD without effects, missing CSRF, invalid/expired/replayed links, empty password rerenders, one success notice and fresh sign-in. Same-account recovery clears cookie/CSRF state; old cookies fail in another browser. Different accounts conflict, deleted bindings return 410, and unrelated guest/pending browser state survives without switching or merging.
- **AC4:** Limits and privacy prevent uncontrolled sends and credential/token leakage without changing registration.  
  Check: IP/email-fingerprint request limits (including unknown emails), exact cooldown/IP-window boundaries, reset-update 429 before writes, hostile Host/redirect input, log-marker assertions for full GET URLs/forms/SMTP errors/cache keys, cookie contents, no-store/no-referrer and localized semantic controls. Run existing registration/session/mailer tests unchanged except the deliberately enabled registered reset capability.  
  Result: Passed — integration tests cover normalized unknown-address cooldown and reopening at 60 seconds, separate request/update IP budgets and reopening at 180 seconds, trusted origin despite hostile Host/redirect parameters, sanitized retryable SMTP failure, no-store/no-referrer, empty password fields, filtered token GET URLs/forms/email logs and no token in browser cookies. Existing registration, session, origin and mail tests pass in the full suite. Limits remain per-worker and reset on restart.
- **AC5:** Existing application checks and documentation remain accurate.  
  Check: `bin/rails zeitwerk:check`, focused recovery tests, `PARALLEL_WORKERS=1 CI=true bin/ci`, `git diff --check`; update README/plan and record actual commands/results. Distinguish local transport simulation from any optional authorized inbox/browser verification. No deployment required.  
  Result: Passed — PARALLEL_WORKERS=1 CI=true bin/ci: 145 tests, 1,418 assertions, zero failures/errors/skips; RuboCop 82 files clean; gem/importmap audits clear; Brakeman zero warnings. bin/rails zeitwerk:check passed application eager loading (existing development mail-preview directory is outside eager-load paths). git diff --check passed. README, product/architecture briefs and plan updated. Automated verification used local transport. Owner subsequently confirmed password reset in the browser on 19 October 2026; inbox receipt was not separately reported. Hosted GitHub CI subsequently passed: [run 39311608925](https://github.com/adambelton/glutton/actions/runs/39311608925). No deployment was performed.

## Implementation notes

Implemented conventional PasswordResetsController new/create/edit/update actions, native forms and localized copy. RegisteredUser alone enables Rails reset tokens; password presence is enforced in the reset validation context. Identity::RequestPasswordReset and Identity::ResetPassword own delivery and the transactional reset operation. Identity::MailOrigin extracts the existing origin policy without altering confirmation delivery. No schema change or dependency was needed.

Reproduce automated verification from the repository root:

```sh
PARALLEL_WORKERS=1 bin/rails test test/services/identity/reset_password_test.rb test/services/identity/request_password_reset_test.rb test/services/identity/password_recovery_concurrency_test.rb test/integration/password_recovery_test.rb
PARALLEL_WORKERS=1 CI=true bin/ci
bin/rails zeitwerk:check
git diff --check
```

Focused recovery verification passed: 21 tests, 263 assertions, zero failures/errors/skips. Tests use in-memory mail or intercepted transport and local PostgreSQL. The serial-worker override avoids the previously observed macOS native parallel-fork crash. No implementation scope deviation.

Manual verification — 19 October 2026: owner reported “Password reset confirmed in the browser.” Browser completion is confirmed by the owner; inbox receipt was not separately reported. The agent sent no live messages during implementation.

Release prerequisites from prior tasks still apply: shared abuse controls for multi-worker operation and pending/guest/activity retention cleanup are separate work. This task does not claim those are complete.

Owner acceptance / merge: Owner authorized PR and merge after CI. [PR #14](https://github.com/adambelton/glutton/pull/14) merged after hosted CI passed on 19 October 2026; squash commit `6abef84f09d8f03f877256667a939c86286e0f93`.
