# 003 — Session-bound guest access

Status: Ready for review  
Owner: Identity / guest sessions

## Goal

Resolve an active guest from a protected Rails browser session and explicitly create a guest when a later personal action needs one. Reject expired/deleted identities on subsequent requests. Depends on merged task 002's `GuestUser` persistence and polymorphic `User#active?`. No product-domain implementation is included.

Read [the implementation plan](../implementation_plan.md), [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md) before implementation.

## Scope

- Add a small Identity-owned controller concern, available to controllers through `ApplicationController`, with two explicit synchronous operations as specified below. Use existing Rails encrypted/signed session storage; store only the internal user ID as identity state, never an ID supplied through request parameters.
- Use a browser-session cookie with no persistent expiry/Max-Age. Retain HttpOnly and SameSite=Lax protections and Secure in production. Browser closure/restoration is browser-controlled; the server's activity check remains authoritative.
- Resolve identity anew on every request and memoize only within that request. Call `active?` to decide activity. Missing/invalid identities and expired guests yield no current identity and clear stale identity state. A session referencing `DeletedUser` fails explicitly with HTTP 410 and an account-deleted message, including on repeated requests; it must never silently create a guest. Retain that reference until an explicit session reset so subsequent actions cannot bypass the failure.
- Explicitly create a guest only when requested by an operation needing to save personal activity. Reading identity or visiting the current scaffold must never create a user. Reset the Rails session before binding a newly created identity; no guest lifetime renewal.
- Verify the concern through an isolated test controller/routes. Do not add a production demo endpoint or change product behaviour to exercise it.

### Identity-owned synchronous interface

- `current_user`: no caller-supplied identity input. Resolve the user ID from the protected Rails session and return the persisted active `User` subtype, or `nil` for absent, invalid, missing or expired guest identity. A deleted identity raises the concern’s `AccountDeleted` error, rendered as HTTP 410 with an explicit message. Do not create records. Guest inactivity uses its deadline; deleted-account handling distinguishes its failure reason without granting access. Clear stale identity state for missing/expired identities; retain the deleted-account reference to keep subsequent actions explicitly rejected. Do not expose lookup errors as user-not-found pages. Unexpected database failures propagate rather than being mistaken for an absent identity.
- `ensure_guest_user!`: no identity input. Return `current_user` if active; if identity is absent/invalid/missing or an expired guest, persist a new `GuestUser`, reset the Rails session and bind its ID. Return the persisted guest. Do not return or rebind an old inactive identity. Failed creation propagates the save error and leaves no new session identity. Repeated calls in one request and sequential requests with the resulting cookie reuse the same user. Simultaneous first requests before a cookie is established may create separate guests; cross-request deduplication is outside this task.
- These are Identity provider operations. Later domain controllers consume them in their own tasks, apply their own ownership checks and guard personal operations with `active?`. This task adds no consumer and grants no access to arbitrary records merely because an identity exists.

## Scope restrictions

- Only Identity session resolution/creation, cookie configuration, tests and task documentation. No changes to Library, Ratings, Recommendations or Film knowledge, including UI/wiring or capability modules.
- No automatic global guest-creation callback, registration, credentials, email confirmation, sign-in/out UI, permanent login cookies, session table, deletion transitions, cleanup jobs, new dependencies or generic integration layer.
- Do not change task 002's STI hierarchy, creation timestamp or 24-hour policy. Do not add a stored expiry or extend lifetime on requests. Deleted identities remain inactive; there is no restoration flow.
- No tab-specific storage or browser-close deletion promise. Losing a cookie loses access to that guest; entering an email or supplying a user ID cannot recover it.
- Keep the Rails scaffold route and response unchanged. Test scaffolding must stay in tests; retain CSRF protections on state-changing requests.
- No deployment, real mail, paid services, publication or merge is authorized by writing this spec. The owner approved implementation and subsequently authorized committing, pushing a branch and opening a GitHub PR for review. No merge is authorized.

## Acceptance criteria

- **AC1:** Identity lookup and ordinary scaffold requests with no session return no identity and create no users. Explicit creation returns a persisted guest; repeat calls/requests reuse it without changing `created_at`.  
  Check: Add focused integration tests using an isolated Identity test controller; exercise lookup, explicit creation and reuse and assert user counts and IDs. Run `bin/rails test test/integration/user_sessions_test.rb`.  
  Result: Passed — `bin/rails test test/integration/user_sessions_test.rb`: 11 tests/112 assertions, no failures/errors. Lookup and home requests create no users; explicit creation and repeated calls/requests reuse the guest and preserve creation time.
- **AC2:** Separate browser clients have isolated guests. User IDs supplied in query/body parameters do not change identity; missing/tampered cookies cannot access an existing guest.  
  Check: Use separate Rails integration sessions and real cookie round trips, including tampering and supplied-ID attempts; run the focused integration test file. Do not rely only on directly stubbing the session.  
  Result: Passed — same focused command: two browser clients retain distinct IDs; query/body user IDs do not select another user; missing and tampered cookies return no identity.
- **AC3:** A guest resolves just before its deadline and resolves to nil exactly at/after it. A record removed from the database resolves to nil; a session-bound record changed to `DeletedUser` returns HTTP 410 on lookup and actions in every browser still holding that identity, with no guest creation. Explicit creation afterward produces a different guest, without reviving the old record.  
  Check: Frozen-time boundary tests and changes between requests, asserting cleared stale identity, new IDs and unchanged old timestamps; run the focused integration test file.  
  Result: Passed — same focused command: guest lookup succeeds just before expiry, returns nil at/after it, and clears stored identity. Missing records allow explicit replacements. Two browser clients holding the same deleted-account identity receive HTTP 410 with the account-deleted message on repeated GETs and POSTs; no guest is created.
- **AC4:** New guest binding resets the old Rails session. Failed creation binds no identity, and unexpected database failures are surfaced rather than silently creating a replacement guest.  
  Check: Focused tests assert removal of a prior session marker and inject creation/lookup failures at the persistence boundary. Record exact commands and results.  
  Result: Passed — same focused command: a seeded session marker is removed by new binding; injected creation failure yields Rails’ 422 response with no user or identity created; injected database connection failure propagates. Failure injection is test-local and restored afterward.
- **AC5:** Cookie responses have browser-session lifetime, HttpOnly and SameSite=Lax, and Secure under production-equivalent HTTPS configuration. No production test endpoint or CSRF exception is introduced.  
  Check: Inspect actual Set-Cookie headers in integration tests (including HTTPS/Secure configuration), route/config diff and CSRF handling. Record exact commands and results.  
  Result: Passed — same focused command: actual cookie headers contain HttpOnly/SameSite=Lax and omit Expires/Max-Age; a separate HTTPS integration client wrapped in ActionDispatch::SSL (the existing production force_ssl middleware) receives Secure. A tokenless POST is rejected without creating a user. Production routes/config have no changes.
- **AC6:** Existing scaffold and full checks pass within the specified scope.  
  Check: Run `bin/ci` and `git diff --check`; inspect the implementation diff for excluded features and unrelated edits.  
  Result: Passed — `bin/ci`: 29 Ruby files linted, gem/importmap audits clear, Brakeman zero warnings/errors, 22 tests/149 assertions with no failures/errors. `git diff --check` passed; implementation changes are limited to the Identity concern, its ApplicationController inclusion and isolated integration tests.

## Implementation notes

Implemented private `current_user` and `ensure_guest_user!` methods in `Identity::UserSessions`, included by ApplicationController. Resolution checks a session-held integer ID, checks for a deleted-account identity and raises `AccountDeleted` (rendered as HTTP 410), otherwise calls polymorphic `active?`, clears missing/expired references and memoizes only for the request. Creation persists first, resets the Rails session and binds the new ID. Existing encrypted cookie storage and production SSL middleware already supply the required cookie settings, so no configuration change was needed.

Integration tests use temporary test-only routes/controller with CSRF protection enabled; normal routes are restored after each test. Initial test attempts exposed an unavailable optional mock library and Rails’ conversion of validation failures to 422 responses. Removed the dependency and aligned failure assertions with that response; the final focused and full runs passed as recorded above.

No scope deviations. No production probe endpoint, product consumer, schema change, credential flow or cleanup job was added. Registered sessions and registration remain separate tasks. Cookie possession supplies temporary guest access, not verified email identity. The owner subsequently requested a GitHub PR; commit and branch publication are authorized for that purpose. Owner acceptance and merge remain pending.

Owner acceptance / merge: Pending.
