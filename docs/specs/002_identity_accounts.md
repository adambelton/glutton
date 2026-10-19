# 002 — Temporary guest identity

Status: Ready for review  
Owner: Identity / accounts

## Goal

Persist an email-free guest identity with a fixed 24-hour lifetime, ready for subsequent session and registration tasks. Depends on task 001's Rails/PostgreSQL scaffold. No cross-domain contracts are consumed or introduced.

Relevant decisions: [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Guests can discover usefulness through personal activity before registering. Product records reference an internal user ID; later registration preserves that ID.

## Scope

- Use Rails single-table inheritance: concrete `User` base and `GuestUser` subclass sharing `users`, with internal ID, required `type` and timestamps. Only the guest subtype is implemented now.
- Create guests explicitly with `GuestUser.create!`. Derive expiry from `created_at + 24.hours`; do not store a separate expiry column. Reads and activity never renew the deadline. Policy changes therefore affect existing guests.
- `User#expired?` returns false; `GuestUser#expired?` overrides it and returns true at or after the deadline. Test through the base lookup to verify subtype dispatch.
- Use one initial migration to create the users table with its final STI shape. Require type in model validation and PostgreSQL; never synthesize credentials.
- Record the later registration requirement: successful registration requires email confirmation and upgrades the same guest identity, preserving its activity; expired guests cannot be claimed. This task does not implement that operation.

## Scope restrictions

- Change only Identity-owned guest persistence, time rules and tests, plus task documentation. Do not add Library, Ratings, Recommendations or Film knowledge code, associations, foreign keys or placeholder interfaces.
- No cookies, sessions, current-user helpers, controllers, routes, forms, registration, passwords, email fields, verification tokens, mailers or external calls. Do not generate the complete authentication scaffold in this task.
- No cleanup job or deletion of user/activity records. Expiry marks an identity as unusable; deletion is separate. Later session handling must enforce expiry server-side even before cleanup runs.
- Do not add speculative registered-account columns or a generic identity service. Introduce credentials and conditional account invariants in their own task. Registered/deleted subclasses, transition operations and domain capability modules arrive only with their owning tasks.
- No anonymous-account recovery by entered email, account merging, cross-browser guest recovery or lifetime refresh on activity.
- No production deployment, real user data, external communication or paid services are authorized by this spec. The owner subsequently authorized committing this task, pushing its branch and opening a GitHub PR for review; no merge is authorized.

## Acceptance criteria

- **AC1:** `GuestUser.create!` persists an email-free identity; `User.find` returns a `GuestUser` with the same ID and creation timestamp. Separate guests have separate IDs. No expiry column remains.  
  Check: Inspect schema and run `bin/rails test test/models/user_test.rb`.  
  Result: Passed — `bin/rails test test/models/user_test.rb`: 7 tests, 23 assertions, zero failures/errors. Base lookup instantiates `GuestUser`; schema has required `type`, timestamps and no expiry/credential fields.
- **AC2:** Base `User#expired?` returns false; guests expire exactly 24 hours after creation, including across a daylight-saving change. Reads and timestamp touches do not renew expiry.  
  Check: Run frozen-time boundary, base lookup, non-renewal and DST tests with `bin/rails test test/models/user_test.rb`.  
  Result: Passed — same focused command: base false, guest deadline boundaries, reload/touch non-renewal and Europe/London 2026-10-25 DST checks all passed.
- **AC3:** Model validation and PostgreSQL reject missing type. The single initial migration creates the final STI schema directly.  
  Check: Model tests bypass validations inside a savepoint; apply the migration from an unmigrated local database and inspect schema.  
  Result: Passed — the single `CreateUsers` migration applied successfully to development and test after rollback. Schema inspection confirms required STI type and no stored expiry; model/database constraint tests passed in `bin/ci`.
- **AC4:** Scaffold checks pass within Identity scope.  
  Check: Run `bin/rails db:prepare`, `RAILS_ENV=test bin/rails db:prepare`, `bin/ci` and `git diff --check`.  
  Result: Passed — both `db:prepare` commands succeeded; `bin/ci` passed with 26 Ruby files linted, clear gem/importmap audits, zero Brakeman warnings/errors and 10 tests/35 assertions with no failures/errors. `git diff --check` passed.

## Implementation notes

Implemented `GuestUser < User`, required STI type, base `expired?` returning false and a guest override deriving expiry from creation time. The initial migration creates the final users table directly; no compensating migration is retained. Local development/test users tables were rolled back with `bin/rails db:rollback STEP=2` and `RAILS_ENV=test bin/rails db:rollback STEP=2` before consolidation, then rebuilt using the checks above.

No domain capability modules or future subclasses were added. Session enforcement, registration/confirmation, domain capabilities and cleanup remain separate tasks. The owner authorized committing and pushing updates to PR #1; no merge is authorized.

Owner acceptance / merge: Pending.
