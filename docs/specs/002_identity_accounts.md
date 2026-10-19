# 002 — Temporary guest identity

Status: Ready for review  
Owner: Identity / accounts

## Goal

Persist an email-free guest identity with a fixed 24-hour lifetime, ready for subsequent session and registration tasks. Depends on task 001's Rails/PostgreSQL scaffold. No cross-domain contracts are consumed or introduced.

Relevant decisions: [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Guests can discover usefulness through personal activity before registering. Product records reference an internal user ID; later registration preserves that ID.

## Scope

- Add a minimal Rails `User` model and PostgreSQL `users` table with an internal primary key, timestamps and a required guest expiry timestamp. All users created in this task are guests; credentials and registered state arrive in a separate task.
- Explicit guest creation sets expiry to 24 hours after creation, using application time. Reads and activity never extend this deadline. Do not accept a caller-supplied user ID or expiry through a public interface.
- Expose a small Identity-local predicate for guest expiry: active before the deadline, expired at or after it. Use Rails time helpers for deterministic tests.
- Require the expiry in model validation and PostgreSQL. Keep a stable internal ID across reloads; never synthesize an email address or password.
- Record the later registration requirement: successful registration requires email confirmation and upgrades the same guest identity, preserving its activity; expired guests cannot be claimed. This task does not implement that operation.

## Scope restrictions

- Change only Identity-owned guest persistence, time rules and tests, plus task documentation. Do not add Library, Ratings, Recommendations or Film knowledge code, associations, foreign keys or placeholder interfaces.
- No cookies, sessions, current-user helpers, controllers, routes, forms, registration, passwords, email fields, verification tokens, mailers or external calls. Do not generate the complete authentication scaffold in this task.
- No cleanup job or deletion of user/activity records. Expiry marks an identity as unusable; deletion is separate. Later session handling must enforce expiry server-side even before cleanup runs.
- Do not add speculative registered-account columns or a generic identity service. Introduce credentials and conditional account invariants in their own task.
- No anonymous-account recovery by entered email, account merging, cross-browser guest recovery or lifetime refresh on activity.
- No production deployment, real user data, external communication or paid services are authorized by this spec. The owner subsequently authorized committing this task, pushing its branch and opening a GitHub PR for review; no merge is authorized.

## Acceptance criteria

- **AC1:** Explicit guest creation persists an internal ID, timestamps and expiry, with no email or password. Reloading retains the same identity and expiry.  
  Check: Inspect migration/schema and run `bin/rails test test/models/user_test.rb` with creation/reload assertions.  
  Result: Passed — `bin/rails test test/models/user_test.rb`: 5 tests, 18 assertions, zero failures/errors. Creation/reload assertions verify ID, timestamps, 24-hour expiry and absence of credentials; migration/schema inspected.
- **AC2:** Expiry is fixed at creation plus 24 hours. The guest is active just before the deadline and expired exactly at and after it; reading or updating unrelated timestamps does not renew it.  
  Check: Run `bin/rails test test/models/user_test.rb` with frozen/travelled time and explicit boundary and non-renewal assertions.  
  Result: Passed — `bin/rails test test/models/user_test.rb`: 5 tests, 18 assertions, zero failures/errors. Frozen-time boundary checks cover immediately before, exactly at and after expiry; reload/touch checks preserve the deadline.
- **AC3:** Model validation and PostgreSQL reject missing guest expiry independently. Separate guest creations produce separate IDs.  
  Check: Run `bin/rails test test/models/user_test.rb`, including a write bypassing validations in an isolated transaction and distinct-identity assertions.  
  Result: Passed — `bin/rails test test/models/user_test.rb`: missing expiry fails model validation and a validation-bypassing insert raises `ActiveRecord::NotNullViolation` inside a savepoint. A subsequent valid insert succeeds; distinct creations have different IDs.
- **AC4:** The change works with the scaffold and stays within Identity persistence scope.  
  Check: Run `bin/rails db:prepare`, `RAILS_ENV=test bin/rails db:prepare`, `bin/ci` and `git diff --check`; inspect the diff for excluded features and unrelated edits. Record actual commands and outcomes here after implementation.  
  Result: Passed — `bin/rails db:prepare` and `RAILS_ENV=test bin/rails db:prepare` applied the migration successfully. `bin/ci` passed: 25 Ruby files linted, gem/importmap audits clear, Brakeman zero warnings/errors, 8 tests/30 assertions with zero failures/errors. `git diff --check` passed; implementation diff contains only Identity model, migration, generated schema and tests. Existing document edits and untracked `.idea/` were preserved.

## Implementation notes

Implemented `User.create_guest!` with one captured creation time and expiry exactly 24 hours later, plus `guest_expired?`, presence validation and a PostgreSQL NOT NULL constraint. No automatic renewal or credential fields.

The initial focused run and CI failed the deadline test because the time helper rounded fractional seconds; corrected the test to create its guest under frozen time. The focused tests and full CI then passed as recorded above. Initial sandboxed database setup could not connect to local PostgreSQL; database checks succeeded with approved execution outside the sandbox.

No scope deviations. Session ownership, server-side rejection of expired identities, registration/claiming and eventual deletion remain required follow-up work; this task supplies persistence and the expiry predicate only. The owner subsequently requested a GitHub PR for review. Commit and branch publication are authorized for that purpose; owner acceptance and merge remain pending.

Owner acceptance / merge: Pending.
