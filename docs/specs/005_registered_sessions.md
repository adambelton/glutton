# 005 — Shared user sessions

Status: Merged  
Owner: Identity / sessions

## Goal

Provide one revocable server-side Session model for guests and registered users, with credential-free guest issuance and password-authenticated registered issuance, independently verifiable without controllers or cookies. Depends on merged tasks 004 and 004a. This is the Identity provider for the separately scoped sign-in/out HTTP task 005a; no other domain contracts are consumed or changed.

Read [the implementation plan](../implementation_plan.md), [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md).

## Scope

- Add a minimal `Session` Active Record model in `app/models/session/session.rb` and its table with an internal ID, required user foreign key and timestamps. Each issued browser session has one record, allowing different browsers to sign out independently. Use a new migration; do not rewrite merged migrations. Explicitly collapse the session model-family directory in the existing autoload initializer, preserving the top-level Session constant.
- Follow Rails authentication conventions without an application-imposed registered-session TTL. Session age does not invalidate it; sign-out/revocation removes the server-side session. Do not add expiry columns or deadline calculations, or change registered users’ own `active?`. Task 005a will use the Rails authentication generator’s persistent signed-cookie convention rather than invent a separate cookie duration.
- Guest issuance uses `Session.create!(user: guest)` with an existing persisted active GuestUser. It returns the persisted Session or raises a validation/persistence error; it never upgrades the account. Creating a fresh guest and its session together belongs to task 005a and must be atomic there. Session issuance does not extend the guest’s account deadline.
- Add one explicit Identity authentication operation, `Identity::Authenticate.call(email_address:, password:)`, returning a persisted Session for valid confirmed registered credentials, or nil for invalid credentials. No caller-supplied user ID, confirmation state, timestamps or session ID.
- Use Rails `authenticate_by` on RegisteredUser rather than a custom password comparison; preserve normalization and use the established credential validations. Reject non-string/blank inputs without creating users/sessions. Do not reveal whether an email exists. Unexpected database errors propagate; authentication failure and infrastructure failure are distinct.
- Sessions created through this operation must belong to an active confirmed RegisteredUser. The operation must not create users, upgrade guests, attach guest activity or change account timestamps/credentials. The Session model accepts existing persisted owners based solely on their polymorphic `active?`, rejecting expired guests/deleted users without subtype or credential checks; the database enforces a non-null valid user foreign key.
- Session `active?` requires a persisted, unrevoked session and an existing persisted owner whose `active?` returns true. Credential invariants remain with user models/database constraints, not Session. Session age is irrelevant; guest account age still controls its 24-hour expiry. Load current owner state rather than relying on a subtype cached before deletion; define request boundaries by fresh persisted lookup. A revoked session, expired-guest session or deleted-owner session cannot authorize access. Keep the owner's identity available on retained session rows so task 005a can produce the existing explicit account-deleted failure.
- Revocation removes the specified Session row. It is idempotent for an already-removed ID and affects no other browser session. Expose `Session.revoke(id:)` for an already-authorized internal session ID: return true whether the row was removed or already absent; propagate unexpected database errors. This is not a public arbitrary-ID endpoint. Never infer authorization merely from possession of a numeric database ID.
- Test with model/operation tests and synthetic guests and confirmed registered accounts. Rails signed/encrypted cookie transport and access authorization are task 005a's responsibility; a Session record itself is not a bearer credential.

## Scope restrictions

- Identity only: persistence, authentication/session operations and tests. No Library, Ratings, Recommendations or Film knowledge changes, capability modules or generic repository/integration layer.
- No controllers, views, routes, cookies, global authentication callbacks, rate limiter, sign-in/out UI, session list UI, mail, registration, guest claim, email confirmation, recovery or deletion transition. Task 005a owns HTTP rate limits and session transport; those remain required before public sign-in is available.
- Do not change guest lifetime, registered/deleted activity predicates or task 003's established guest-session interface in this task.
- No extra IP/user-agent tracking fields, custom password cryptography, raw-password persistence or routine credential logging. Built-in validations remain in models; an operation exists here to coordinate actual authentication and session issuance, not to wrap every persistence call.
- No time-based session expiry, session cleanup job or all-device logout. The guest’s fixed 24-hour deadline remains unchanged.
- No deployment, real user data, paid services or external communication authorized. The owner approved implementation and subsequently authorized committing, publishing a PR and merging it after hosted CI succeeds.

## Acceptance criteria

- **AC1:** Correct normalized credentials produce a persisted Session referencing the existing registered ID. Incorrect, unknown, malformed, blank or non-string credentials return nil and create no session or user.  
  Check: `bin/rails test test/services/identity/authenticate_test.rb`; verify correct/incorrect inputs, normalization, row counts and unchanged account data.  
  Result: Passed — `bin/rails test test/models/session_test.rb test/services/identity/authenticate_test.rb`: 11 tests/62 assertions, zero failures/errors. Correct normalized credentials issue independent sessions; invalid inputs return nil without creating users/sessions or changing account data.
- **AC2:** Active guests can receive sessions without credentials, and confirmed registered users can receive sessions after authentication. Expired guests and deleted users are rejected by local model validation; PostgreSQL rejects missing/nonexistent user foreign keys independently of validations.  
  Check: `bin/rails test test/models/session_test.rb`; test owner validation and direct writes in isolated transactions, plus valid guest/registered ownership. Verify guest issuance does not change its creation time or create credentials.  
  Result: Passed — same focused command: credential-free active guest issuance and registered ownership succeed; expired guests, deleted/missing/unsaved owners fail validation. Validation-bypassing null and nonexistent foreign-key writes raise PostgreSQL errors inside savepoints. Guest attributes remain unchanged.
- **AC3:** Registered sessions remain active regardless of age until revoked or their owner becomes inactive; guest sessions become inactive exactly at the guest account’s 24-hour deadline. A fresh lookup after the owner becomes DeletedUser is inactive while retaining enough identity to report account deletion.  
  Check: Time-travel tests demonstrating activity beyond 30 days, plus guest deadline boundary checks, revocation and between-operation owner changes in focused model tests.  
  Result: Passed — same focused command: guest activity is true immediately before its original deadline and false at/after it, including sessions issued late in the guest lifetime. Registered sessions remain active after 365 days. Cached registered-owner instances do not conceal a later DeletedUser transition; fresh session lookup retains deleted identity.
- **AC4:** Separate guest issuances and successful registered authentications produce independent sessions. Revocation invalidates one and leaves the other active; repeated revocation succeeds without restoring records.  
  Check: Focused operation/model tests assert counts, lookup and idempotent revocation. No cookie or browser test harness in this provider task.  
  Result: Passed — same focused command: guest and registered issuance create independent session IDs. Revocation is idempotent, removes only the selected row and invalidates already-loaded session objects; sibling sessions remain active.
- **AC5:** Authentication/database failures issue no partial session and preserve existing account/guest records.  
  Check: Inject persistence failure at the operation boundary, assert the error propagates and verify row counts/account state. Keep failure injection local and restored.  
  Result: Passed — same focused command: injected Session creation connection failure propagates, creates no partial session and leaves user counts and attributes unchanged. Test-local method override is removed in ensure.
- **AC6:** Migration and existing checks succeed without changing guest/controller behaviour.  
  Check: `bin/rails db:prepare`, `RAILS_ENV=test bin/rails db:prepare`, `bin/ci`, `bin/rails zeitwerk:check`, scoped `git diff --check` and diff inspection. Record exact commands and actual results after implementation.  
  Result: Passed — `bin/rails db:prepare` and `RAILS_ENV=test bin/rails db:prepare` applied CreateSessions. `bin/rails zeitwerk:check` passed. `CI=true bin/ci` passed: 39 Ruby files linted, gem/importmap audits clear, Brakeman zero warnings/errors, 45 tests/268 assertions with no failures/errors. `git diff --check -- app config db docs test` passed; diff contains no controller/cookie changes.

## Implementation notes

Implemented `Session` in its model-family folder, required user association/foreign key, direct owner validation based only on the freshly loaded owner’s `active?`, fresh-state session `active?` and idempotent per-session revocation. Added `Identity::Authenticate` using Rails `authenticate_by` and issuing a session only for active confirmed registered credentials. Extended the explicit Zeitwerk collapse for the session folder. No expiry columns or registered-session TTL were introduced.

Removed the redundant subtype/confirmation predicate at the owner’s request; credential invariants remain in user models and database constraints. Focused tests passed again (11 tests/62 assertions). The first CI after this simplification flagged an extra blank line; fixed it and reran `CI=true bin/ci` successfully (45 tests/268 assertions, lint/audits clear).

The initial focused run found a nested time-helper block in a test; removed the unnecessary nesting. The final focused tests and eager-loaded full CI passed as recorded above. No scope deviations, dependency changes or controller wiring. The owner subsequently authorized PR publication and merge after hosted CI succeeds; record that result before merging.

Scope refinement: task 005 supplies shared guest/registered session lifecycle and registered authentication; task 005a will adapt task 003’s guest creation/current-user concern to the shared server-side Session model and implement HTTP sign-in/out, protected cookie binding, session rotation, request limits and explicit deleted-account failures. Both identity modes must resolve through Session records rather than trusting a bare user-ID cookie. Guest cookies retain browser-session lifetime; registered cookies follow Rails’ persistent signed-cookie convention. Before implementing 005a, specify cookie contents following Rails’ persistent signed-cookie convention, behavior for revoked sessions whose account was deleted, fresh credential entry from an old deleted session, and sign-out semantics. Password reset session invalidation remains task 006c.

Owner acceptance / merge: Accepted by owner and merged via [PR #6](https://github.com/adambelton/glutton/pull/6) on 19 October 2026. Squash commit: `04700f151b4a1b46df7da61f0c94d6bc522a3ddd`. The owner explicitly authorized merging without waiting after hosted CI remained queued. Hosted checks were not confirmed passing; local CI evidence above remains valid.
