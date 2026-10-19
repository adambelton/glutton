# 005a — Session cookies and sign-in/out

Status: Merged  
Owner: Identity / sign-in flow

## Goal

Use task 005's shared Session records for browser identity and provide password sign-in/out for confirmed registered accounts, preserving explicit guest creation and deleted-account failures. Depends on tasks 003 and 005. No other domain is changed.

Read [the implementation plan](../implementation_plan.md), [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Existing Identity provider contracts: `Identity::Authenticate.call` returns a persisted registered Session or nil; unexpected persistence errors propagate. `Session.revoke(id:)` idempotently removes one authorized session; `Session#active?` evaluates fresh owner state.

## Scope

- Adapt `Identity::UserSessions` to resolve a protected cookie to a persisted Session, then its current active user. Preserve private `current_user` and `ensure_guest_user!`; add only the session binding/resolution helpers needed by these flows. Memoize within a request only.
- Replace the old Rails session `user_id` binding; never accept it as registered authentication or a user-ID recovery path. No deployed-user migration is required. Existing unbound guest cookies may lose access, consistent with temporary guest access; do not create a speculative compatibility layer.
- Guest cookies have browser-session lifetime. Registered cookies follow the Rails authentication generator's persistent signed-cookie convention (`permanent`), with no custom server-side TTL. Use HttpOnly, SameSite=Lax and Secure in production; reset Rails session/CSRF state when binding a different identity. Signed cookie contents never include credentials.
- Cookie payload contains the Session ID and bound user ID, protected by Rails signing. Only a matching active Session grants access. The user ID is also a diagnostic reference: a valid old cookie identifying a DeletedUser must continue to return HTTP 410 with “This account has been deleted.” even if its Session was revoked. A user-ID reference alone never grants access or creates a guest. Missing/invalid cookies return no identity; mismatched session/user references fail closed. Other revoked or expired-guest sessions yield no current user and clear stale binding.
- `ensure_guest_user!` reuses the current active identity; otherwise creates GuestUser and Session together in a database transaction before binding the cookie. No rows on lookup/page visits. A session-save failure rolls back the new guest and leaves no cookie pointing at it. Deleted-account failure must never fall through to guest creation.
- Add a minimal Identity-owned sign-in form and session routes: GET `/session/new`, POST `/session`, DELETE `/session`. Collect email/password only with appropriate autocomplete. On invalid credentials render the same generic error with status 422 and no password echo; keep an existing guest/registered binding unchanged. On success reset/bind the issued session and redirect to the existing home page with a sign-in notice. No product domain UI or navigation changes beyond minimal sign-in/status/sign-out links on the existing scaffold.
- Use task 005's authentication operation. Issuance and revocation of the prior bound Session happen in one database transaction; only after success replace browser state. Do not transfer guest activity or change the guest account. Failed persistence must leave the old binding usable and issue no partial replacement. Distinct browsers remain independent.
- Add Rails-native request limiting to POST sign-in: limit 10 attempts per 3 minutes per client IP, returning a generic 429 response. Use an explicitly configured in-process memory store, test it deterministically and document that the limit is per worker and resets on restart. No additional service/dependency in this task; reassess shared limits before a multi-worker public deployment.
- Sign-out revokes the currently bound Session, clears the identity cookie and resets Rails session state; repeated sign-out succeeds without creating a guest. The deleted-account page includes sign-out and sign-in actions. Sign-out also works from a stale deleted-account binding, allowing the person to explicitly clear it. The public sign-in form and credential submission remain usable from that binding; only valid credentials can establish a replacement identity. GET must not sign out or issue sessions.
- All state-changing endpoints retain CSRF protection. Personal/session responses must not be shared-cacheable. Existing email/password/token parameter filtering remains effective.

## Scope restrictions

- Identity HTTP/session handling only. Do not change task 005's provider implementation or add Library, Ratings, Recommendations, Film knowledge or domain capability wiring. A discovered provider defect needs a separately scoped revision.
- No registration/claim UI, email confirmation, password recovery, real mail, all-device logout, session-management dashboard, guest cleanup or account deletion implementation.
- No automatic guest creation on GET/global callbacks, guest merge, account recovery by email alone, custom crypto, new identity runtime, session TTL or guest deadline changes.
- Do not generate the complete authentication scaffold over existing models/controllers. Use existing providers and narrowly scoped Rails code. No unnecessary service wrappers or validation concerns.
- Prefer focused concern tests with a minimal host and a small integration suite exercising actual routes/cookies. Do not create production probe endpoints or disable CSRF to simplify tests.
- No deployment, paid services or external communication authorized. The owner approved implementation and subsequently authorized PR publication and merge after checking CI, including merging if hosted CI remains stalled.

## Acceptance criteria

- **AC1:** Explicit guest creation binds a server-side Session; subsequent requests reuse its identity without extra rows. Ordinary lookup/home requests create no users/sessions. Guest account expiry still ends access exactly at 24 hours.  
  Check: Focused concern tests plus real integration cookie round trips and frozen-time boundaries.  
  Result: Passed — final `PARALLEL_WORKERS=1 CI=true bin/ci` includes focused concern tests and real cookie integration tests: lookups/home create no rows, explicit guest issuance creates a user/session atomically and reuses identity, and fresh requests reject the guest exactly at its account deadline.
- **AC2:** Valid registered credentials bind a new Session, clear prior Rails session state and revoke only that browser's prior Session. Invalid credentials show a generic 422, preserve existing identity and create no session. Guest activity is never transferred.  
  Check: Integration tests with synthetic confirmed accounts and separate browser clients; inspect IDs/counts and unchanged guest attributes.  
  Result: Passed — final CI tests validate registered issuance, browser-specific prior-session revocation, independent clients, generic 422 errors without password echo, unchanged failed-login bindings and unchanged guest attributes during a guest-to-registered switch. Concern tests verify Rails session marker/legacy identity removal on binding.
- **AC3:** Missing/tampered cookies, supplied IDs, mismatched payload references and revoked sessions cannot authorize access. Cookie lifetime/flags differ appropriately for guest/registered identities, including Secure under production-equivalent HTTPS middleware.  
  Check: Inspect real Set-Cookie headers and integration requests with absent, modified and replayed cookie values. Revoked-cookie replay fails.  
  Result: Passed — final CI tests cover missing/tampered cookies, supplied IDs, mismatched signed references, revoked-cookie replay, guest cookies without persistent expiry and registered cookies with expiry. HttpOnly/SameSite=Lax headers and Secure through production SSL middleware are exercised for both modes.
- **AC4:** Deleted-account cookies return explicit HTTP 410 repeatedly across browsers, including after the Session is revoked, without guest creation. Explicit sign-out clears the binding; valid fresh sign-in can replace it.  
  Check: Integration tests with retained signed cookies, anonymised DeletedUser state and revoked Session rows; verify old user data is never returned.  
  Result: Passed — final CI tests retain signed cookies in two clients, delete/anonymise the owner and revoke the Session. Repeated lookup/actions report 410 without guest issuance. Sign-out clears the stale binding; fresh valid credentials can replace it. Deleted-account response includes sign-in/out controls.
- **AC5:** Sign-out revokes only the bound Session, resets browser state and is idempotent. CSRF failures reject sign-in/out without changing records. Rate limits return 429 at the defined threshold and permit attempts after the window.  
  Check: HTTP integration tests with CSRF enabled, separate clients and controlled time/store; verify tokens/passwords are not rendered or logged via parameter handling.  
  Result: Passed — final CI tests verify independent/idempotent sign-out, tokenless POST/DELETE rejection, 429 on attempt eleven and success after the 3-minute window. Existing parameter-filter tests pass; generic error views never echo passwords. Responses set Cache-Control to no-store.
- **AC6:** Guest/session issuance or identity-switch persistence failure leaves no partial replacement and does not invalidate the previous binding.  
  Check: Focused transaction/failure tests at existing provider boundaries, asserting records and browser state before/after failure.  
  Result: Passed — concern failure injection verifies Session-save failure rolls back the newly created guest and binds no cookie. Integration failure injection revokes the prior row and then raises within the sign-in transaction: new issuance and old revocation roll back together; the previous cookie and Session remain usable.
- **AC7:** Existing model/concern tests and full CI pass; no other-domain changes occur.  
  Check: Run focused concern/integration files, `CI=true bin/ci`, `bin/rails zeitwerk:check` and scoped `git diff --check`; record exact commands/results after implementation.  
  Result: Passed — focused command `bin/rails test test/controllers/concerns/identity/user_sessions_test.rb test/integration/user_sessions_test.rb test/integration/sign_in_test.rb` passed before final UI/HTTPS additions (21 tests/160 assertions). Final `PARALLEL_WORKERS=1 CI=true bin/ci` passed: 41 files linted, audits clear, Brakeman zero warnings/errors, 52 tests/378 assertions with no failures/errors. `bin/rails zeitwerk:check` and `git diff --check` passed. Default parallel local CI hit a native macOS/Ruby fork crash after crossing Rails’ 50-test threshold; single-worker verification is the passing result, not a claim that default parallel execution passed.

## Implementation notes

Implemented shared Session resolution/binding in `Identity::UserSessions`, replacing legacy user-ID session trust. Signed identity cookies carry matching Session/user references; the user reference is diagnostic only after revocation, preserving explicit account-deleted failures. Guest issuance is transactional; registered sign-in uses the existing authentication provider and revokes the previous bound Session in the same transaction before resetting browser state. No provider model/service implementation changed.

Added the singular session routes, minimal sign-in and deleted-account pages, and scaffold sign-in/status/sign-out controls. Deleted-account users can explicitly sign out or use fresh credentials without silently receiving a guest. All identity responses are no-store. Cookie flags/lifetimes follow the approved guest/registered distinction; no registered TTL was added.

Sign-in limiting uses Rails `rate_limit` with an explicit MemoryStore: 10 attempts per 3 minutes per client IP, per worker, reset on process restart. This is not a distributed limit; reassess shared storage before multi-worker public deployment. No extra dependency or external service was introduced.

Initial focused failures were test setup issues: a POST-specific CSRF token was incorrectly reused for DELETE, and Rack’s test cookie deletion needed a string key. Corrected those without disabling CSRF. The full suite then crossed Rails’ parallel threshold and hit a native macOS/Ruby fork crash; stopped that stalled run and completed the final full checks with `PARALLEL_WORKERS=1`. This local parallel-execution limitation remains; application tests, lint and audits passed as recorded above.

Naming follow-up: controller variables now use `created_session` inside the transaction and `new_session` for its result, replacing ambiguous `issued`/`authentication` names. `PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_test.rb` passed (8 tests/98 assertions); scoped whitespace checks passed.

No scope deviations. Registration/confirmation will later reuse binding after its own atomic claim; this task creates no confirmation shortcut. Guest creation still has no production endpoint until a later personal save invokes the concern. The owner subsequently authorized PR publication and merge, including if hosted CI remains stalled; record the actual hosted result without claiming an unrun check passed.

Owner acceptance / merge: Accepted by owner and merged via [PR #8](https://github.com/adambelton/glutton/pull/8) on 19 October 2026. Squash commit: `781977179cd1bf039874e39aa80ebddcb660cd7a`. Hosted CI remained queued and was not confirmed passing; the owner explicitly authorized merging while CI was stalled. Local verification evidence is recorded above.
