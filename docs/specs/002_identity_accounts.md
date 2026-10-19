# 002 — Temporary guest identity

Status: Ready for review  
Owner: Identity / accounts

## Goal

Persist an email-free guest identity with a fixed 24-hour lifetime, ready for subsequent session and registration tasks. Depends on task 001's Rails/PostgreSQL scaffold. No cross-domain contracts are consumed or introduced.

Relevant decisions: [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Guests can discover usefulness through personal activity before registering. Product records reference an internal user ID; later registration preserves that ID.

## Scope

- Use Rails single-table inheritance: concrete `User` base and `GuestUser` subclass sharing `users`, with internal ID, required `type` and timestamps. Only the guest subtype is implemented now.
- Create guests explicitly with `GuestUser.create!`. Derive expiry from `created_at + 24.hours`; remove the stored guest expiry column. Reads and activity never renew the deadline. Policy changes therefore affect existing guests.
- `User#expired?` returns false; `GuestUser#expired?` overrides it and returns true at or after the deadline. Test through the base lookup to verify subtype dispatch.
- Preserve existing guest IDs and creation timestamps during migration; backfill their STI type. Require type in model validation and PostgreSQL; never synthesize credentials.
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
- **AC3:** Model validation and PostgreSQL reject missing type. Migration preserves an existing guest's ID and creation time while assigning `GuestUser`.  
  Check: Model tests bypass validations inside a savepoint; migrate a representative pre-STI guest in the test database and inspect it after migration. Record commands and outcomes.  
  Result: Passed — focused model/database checks reject missing type. Before migration, inserted a test guest with creation time `2026-10-18 12:00:00`; after migration, `User.find(id)` returned `GuestUser` with the same ID and creation time. Temporary test row removed. Reproduction steps below.
- **AC4:** Scaffold checks pass within Identity scope.  
  Check: Run `bin/rails db:prepare`, `RAILS_ENV=test bin/rails db:prepare`, `bin/ci` and `git diff --check`.  
  Result: Passed — `bin/rails db:prepare` and `RAILS_ENV=test bin/rails db:prepare` applied the STI migration. `bin/ci` passed: 27 files linted, gem/importmap audits clear, Brakeman zero warnings/errors, 10 tests/35 assertions with no failures/errors. `git diff --check` passed.

## Implementation notes

Implemented `GuestUser < User`, required STI type, base `expired?` returning false and a guest override deriving expiry from creation time. Added a follow-up migration so already-migrated databases retain their guest IDs and timestamps. No domain capability modules or future subclasses were added.

Migration preservation reproduction (test database only, before applying `20261019140000`): in `RAILS_ENV=test bin/rails console`, insert a row with `connection = ActiveRecord::Base.connection; id = connection.select_value("INSERT INTO users (created_at, updated_at, guest_expires_at) VALUES ('2026-10-18 12:00:00', '2026-10-18 12:00:00', '2026-10-19 12:00:00') RETURNING id")` and retain the ID. Run `RAILS_ENV=test bin/rails db:prepare`, reopen the console and check `user = User.find(id); user.class == GuestUser && user.created_at == Time.utc(2026, 10, 18, 12)`, then `user.destroy!`. Actual verification used Rails runner scripts for these same insert/check/delete steps.

Revision authorized by the owner: STI and polymorphic expiry replace the stored deadline. Previous verification (5 focused tests/18 assertions; full CI 8 tests/30 assertions) covered the earlier design and is superseded by the checks above. Session enforcement, registration/confirmation, domain capabilities and cleanup remain separate tasks. The owner authorized committing and pushing updates to PR #1; no merge is authorized.

Owner acceptance / merge: Pending.
