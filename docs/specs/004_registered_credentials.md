# 004 — Registered account credentials

Status: Ready for review  
Owner: Identity / credentials

## Goal

Persist a confirmed registered identity with Rails password authentication while preserving email-free guests and inactive deleted identities in the same users table. Depends on task 002's STI model; task 003's established session interface remains unchanged.

Read [the implementation plan](../implementation_plan.md), [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Email confirmation is mandatory to complete registration. This task provides credential invariants, not registration or proof of mailbox ownership.

## Scope

- Clarify the architecture brief’s separation of substantial product rules from persistence; keep this straightforward Identity implementation in Active Record. No domain-layer refactor is included.
- Add `RegisteredUser < User`, inheriting `active? == true`. Add nullable `email_address`, `password_digest` and `email_confirmed_at` columns in a new migration. Do not rewrite the merged initial migration.
- Use Rails `has_secure_password` and bcrypt on RegisteredUser only. Disable automatic password-reset token generation for this task; recovery is separately scoped. Never store plaintext passwords or confirmations.
- Registered users require canonical email, a password digest and a confirmation timestamp. Creation requires a password of at least 15 characters and at most 72 bytes, with matching password confirmation. Allow password-manager paste and spaces; do not impose character-class rules. Existing persisted users can save unchanged credentials without re-entering their password. Enforce password length again when replacing it; no password-change UI is included.
- Normalize email by stripping surrounding whitespace and lowercasing the whole address before validation/persistence and lookup. Require a syntactically plausible address using existing Ruby/Rails facilities. Do not rewrite plus suffixes, dots or provider-specific aliases. Unknown/invalid email lookup returns no match and creates no record. Keep lookup internal to Identity, preferably on RegisteredUser.
- Enforce canonical nonblank email uniqueness in PostgreSQL and model validation. PostgreSQL must require email, nonblank digest and confirmation timestamp for RegisteredUser, and require all three fields to be null for GuestUser/DeletedUser. Add corresponding local model validation without putting password authentication on the base User. Do not attempt to validate password strength from a hash in PostgreSQL.
- Use synthetic confirmed accounts in model tests to exercise persistence and `authenticate`/Rails credential lookup. A confirmation timestamp is trusted internal state, not proof established by this task; no public path accepts it.
- Retain existing parameter filtering for email/password. Inspect it and add a focused assertion that the chosen field names are redacted if existing coverage does not already demonstrate this.

## Scope restrictions

- Identity only. No product domain associations, capability modules, library operations or UI wiring. Introduce no abstract repository/service or external identity store.
- No guest-to-registered or registered-to-deleted transition, pending-registration storage, token issuance/redemption, mail, controllers/routes, sign-in/session changes, password-reset implementation, email changes or account merging.
- Guest claiming moves to task 006b's confirmed-registration completion. Before that implementation, specify pending credentials, email uniqueness conflicts, token expiry/replay, guest deadline, atomic transition/retry behaviour and session rotation. Do not expose a credential-only claim operation that completes registration without confirmation.
- No email/password on guests or deleted users; retain guest expiry and deleted-account failure behaviour. Registering cannot create a second user ID for an existing guest; its later transition preserves identity.
- Do not infer authentication from email lookup or use an entered address to attach activity to an existing account. Mailbox verification remains task 006b's responsibility.
- No dependency upgrades beyond adding the required bcrypt dependency and its lockfile resolution for existing macOS/Linux platforms. No deployment, real user data, paid services or external communication are authorized by this spec. The owner subsequently authorized committing, pushing this task branch and opening a GitHub PR for review; no merge is authorized.

## Acceptance criteria

- **AC1:** A valid synthetic confirmed RegisteredUser persists, reloads via User as the correct subtype, remains active beyond 24 hours and authenticates only with the correct password. Plaintext password/confirmation are absent from stored attributes.  
  Check: Run `bin/rails test test/models/registered_user_test.rb`; assert persistence/subtype, activity, correct/incorrect credentials and hashed storage.  
  Result: Passed — `bin/rails test test/models/registered_user_test.rb`: 8 tests/100 assertions, zero failures/errors. Persistence through base lookup, password authentication, hashed-only attributes, disabled reset tokens, unchanged save and activity beyond 24 hours verified.
- **AC2:** Missing/malformed emails, missing confirmation timestamp, absent/short/over-72-byte passwords and mismatched password confirmation fail validation. Valid passwords with spaces work; saving an unchanged persisted account needs no new password.  
  Check: Focused model tests include character and multibyte byte-length boundaries, confirmation mismatch and unchanged save. Run the model test file.  
  Result: Passed — same focused command: required email/confirmation state, missing/short/over-limit passwords, character and multibyte byte boundaries, missing/mismatched password confirmation, spaces and replacement validation verified.
- **AC3:** Email normalization/lookup resolves case and surrounding-whitespace variants to one registered account without creating records. Plus-address variants remain distinct; guest/deleted rows never appear as registered lookup results. Unknown/invalid inputs yield no match.  
  Check: Focused model tests assert canonical persistence, lookup results, unchanged counts and duplicate validation.  
  Result: Passed — same focused command: canonical stored email, case/whitespace lookup, invalid/unknown lookup without inserts, duplicate validation and distinct plus addresses verified. Guest/deleted accounts remain credential-free.
- **AC4:** PostgreSQL independently rejects duplicate canonical email, incomplete registered credentials, blank/noncanonical email, blank digest and credential-bearing guest/deleted records. Existing guests migrate without changing IDs or timestamps.  
  Check: Apply the new migration with `bin/rails db:prepare` and `RAILS_ENV=test bin/rails db:prepare`; inspect schema and test validation-bypassing writes in isolated transactions. Record a representative before/after guest preservation check and exact reproduction steps.  
  Result: Passed — `bin/rails db:prepare` and `RAILS_ENV=test bin/rails db:prepare` applied the new migration. Focused tests bypass validations with `insert_all!` inside savepoints and assert named conditional check failures and `RecordNotUnique`. A representative existing test guest retained its ID, subtype and creation time, with all new credential fields null. Reproduction below.
- **AC5:** Email/password parameters are filtered, existing guest/deleted/session behaviour passes unchanged, and full checks succeed.  
  Check: ParameterFilter assertions; `bin/ci`; `git diff --check` for scoped files; review diff for excluded flows and domain changes. Record actual commands/results.  
  Result: Passed — ParameterFilter assertions passed in the focused tests. `bin/ci` passed: 34 Ruby files linted, gem/importmap audits clear, Brakeman zero warnings/errors, 34 tests/206 assertions with no failures/errors. `git diff --check -- app db test docs Gemfile Gemfile.lock` passed; unrelated local `.gitignore` edit excluded. Existing session and guest/deleted tests passed.

## Implementation notes

Implemented `RegisteredUser` with Rails `has_secure_password reset_token: false`, email normalization/internal lookup, credential and password validation. Added bcrypt 3.1.22; lockfile diff adds only bcrypt and its dependency declaration, preserving macOS/Linux platforms and existing versions. GuestUser and DeletedUser include the shared Identity-owned `WithoutCredentials` validation concern. Their activity behaviour is unchanged.

The new migration adds nullable credential columns, a unique email index and named conditional checks: registered rows must have canonical nonblank email, nonblank digest and confirmation timestamp; all other types must have null credentials. Email syntax is validated in the model; the database enforces canonical representation/presence, not full mailbox syntax. No public operation can set confirmation state in this task.

Migration preservation reproduction (test database before applying `20261019150000`): insert a GuestUser row with creation/update timestamps `2026-10-18 12:00:00` using `RAILS_ENV=test bin/rails console`, retaining its ID. Run `RAILS_ENV=test bin/rails db:prepare`; reopen the console and check `u = User.find(id); u.instance_of?(GuestUser) && u.created_at == Time.utc(2026, 10, 18, 12) && [u.email_address, u.password_digest, u.email_confirmed_at].all?(&:nil?)`, then remove the temporary row with `u.destroy!`. Actual verification used Rails runner scripts to perform these same insert/check/delete steps; both database preparations and the preservation assertion succeeded.

Updated the original guest test to assert null credential fields instead of absent columns. Documentation clarification agreed with the owner: substantial product rules should be independently testable without Rails/database setup; capability modules do not themselves provide persistence isolation. Current Identity persistence/credential code remains appropriate and unchanged. Scoped documentation whitespace checks passed.

No scope deviations. No claim operation, unconfirmed registered account, session change or registration UI is delivered. Confirmation and the in-place transition remain later work. The owner subsequently requested a GitHub PR; commit and branch publication are authorized for review. Owner acceptance and merge remain pending.

Owner acceptance / merge: Pending.
