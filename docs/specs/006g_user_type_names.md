# 006g — Explicit User lifecycle names

Status: Ready for review  
Owner: Identity / model organisation

## Goal

Use UserGuest, UserRegistered and UserDeleted with matching STI values, preserving existing account IDs and session associations. No other domain contract changes. Supersedes the class naming choice in 004a/005b; task 007 stays deferred during this task.

Read the implementation plan, architecture brief sections 3/11, existing User models, registration/recovery and retention operations before implementation.

## Scope

- Move lifecycle models directly under app/models/ as user_guest.rb, user_registered.rb and user_deleted.rb; remove the directory collapse and rename references.
- Keep Rails default STI naming: UserGuest, UserRegistered and UserDeleted. Keep the concrete base User supported; no custom table-name or STI overrides.
- Add a reversible transactional data migration translating the three old type values and replacing credential check constraints to match the new registered value. Preserve all IDs, credentials, timestamps and sessions; do not edit historical migrations.
- Update runtime references, association class names, tests and current architecture guidance. Historical completed specs remain historical.
- Existing sessions remain usable. Class-bound password reset tokens issued before the rename may be invalidated by the class rename; document this limitation rather than introducing token compatibility infrastructure. Pending registration tokens are not tied to the renamed user subclasses.

## Scope restrictions

- Identity only; no Film knowledge implementation, lifecycle policy changes, new UI/copy, aliases for old classes, generic STI framework or other domains.
- No data resets or production changes. Test migration preservation against isolated test records. Apply the final migration locally to keep the development app usable; preserve existing rows. Deployment requires a coordinated application/migration transition; old/new app versions must not serve concurrently against different STI formats.
- No automatic publication or merge. Owner acceptance remains separate.

## Acceptance criteria

- **AC1:** Normal autoloading resolves top-level User subclasses and stores matching class names.  
  Check: Zeitwerk check; model tests verify class names, stored values and base-User reload for all three subclasses.  
  Result: Passed — `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading; the existing development mail-preview directory remains outside eager-load paths. Tests verify default class/table/STI mapping and reload all lifecycle subclasses through User.
- **AC2:** Existing rows and constraints migrate forward/back without losing identity or sessions.  
  Check: Isolated migration test translates legacy rows, asserts IDs/credentials/timestamps/session associations unchanged, reloads new classes, rejects credentials on UserGuest/UserDeleted and missing credentials on UserRegistered, and reverses to legacy values/constraints.  
  Result: Passed — `test/migrations/rename_user_types_test.rb` runs in the full suite and verifies forward/back translation, unchanged row contents except type, preserved sessions, credential authentication and rejection of invalid credential/type combinations. The local development migration completed; aggregate verification found one UserRegistered and one Session associated with that registered owner. No users or sessions were recreated.
- **AC3:** Existing Identity workflows remain correct.  
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, including registration, sign-in, recovery and cleanup tests; `git diff --check`. Record actual results and migration/token limitations.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 164 tests, 1,551 assertions, zero failures/errors/skips; RuboCop 88 files clean; gem/importmap audits found no vulnerabilities; Brakeman zero warnings/errors. `git diff --check` passed. Registration, sessions, password recovery and concurrent cleanup tests use the final names.

## Implementation notes

Implemented the top-level lifecycle models and updated all runtime/test references, the pending-registration association, credential constraints and schema. Removed the custom Zeitwerk collapse without adding table-name or STI overrides. Historical migrations/specs retain their original names; the new migration translates existing rows reversibly.

Reproduce verification:

```sh
RAILS_ENV=test bin/rails db:migrate
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
git diff --check
```

Local development migration was also applied with `bin/rails db:migrate`; no production changes, publication or merge occurred. An earlier CI invocation used its default development setup and applied the intermediate namespace migration despite the initial test-only verification restriction. That uncommitted migration was reversed without deleting rows before replacing it with the final naming migration; subsequent CI explicitly used RAILS_ENV=test. Final development aggregate counts remain one registered user and one associated session. Password reset links generated with the old class name may require requesting a new link. Application code and migration must transition together; mixed-version deployment is unsupported. Task 007 remains unimplemented.

Owner acceptance / merge: Pending. Owner selected User as the base and UserRegistered, UserGuest and UserDeleted as top-level subclasses on 20 October 2026, superseding the intermediate namespace proposal.
