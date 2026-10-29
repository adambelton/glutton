# 056 — Fold local schema corrections into creation migrations

Status: Ready for review  
Owner: Foundation (supporting database migration history)

## Goal

Simplify disposable local migration history without changing the final domain schema. Owner explicitly requested cleaning up other correction migrations after authorising development/test rebuilds. Prerequisites: implementation plan, task 055, current migrations/schema and domain ownership rules.

## Scope

- Fold Identity credential columns/final UserRegistered constraints and confirmation-delivery fields into table creation. Remove obsolete STI-value conversion migration because new databases start with current type names.
- Remove the event-publisher allowlist addition/removal pair; preserve the final open publisher contract.
- Fold Ratings held state and nonunique rating-history index into table creation. Move Film source_context into Film creation, keeping catalogue table creation separately scoped.
- Compare the final non-catalogue schema to the pre-cleanup schema, excluding migration-version/header changes. Rebuild local databases and run existing domain tests. No domain behaviour, constraints, ownership or event meaning changes.

## Scope restrictions

- Supporting history cleanup only, not cross-domain feature implementation. No production environment, shared-schema compatibility layer, provider calls, new model/API behaviour, paid work, deployment or merge. Existing dev data is explicitly disposable under owner instruction.
- Preserve GoodJob's generated migration, independent table-creation migrations, unrelated workspace/research files and all final constraints/indexes/foreign keys.

## Acceptance criteria

- **AC1:** Correction migrations are consolidated with unchanged final contracts.  
  Check: schema comparison outside task-055 catalogue tables, inspect current STI checks, event-publisher constraints, rating-history index and held defaults.  
  Result: Passed — removed seven correction files and folded final values into creation migrations. Compared the final schema against /tmp/glutton-056-before-schema.rb with /private/tmp/glutton-056-schema-check.py: 17 non-catalogue table definitions and 11 foreign keys match after sorting column/index/constraint lines and normalising equivalent PostgreSQL text-cast rendering. User credential constraints use UserRegistered directly; no publisher allowlist remains; rating history uses the nonunique composite index; held defaults false. GoodJob generated migration unchanged.
- **AC2:** Fresh builds and application checks pass.  
  Check: complete development/test migration replay and seeding, full single-worker Rails suite, style/security/eager loading, migration status and docs/link/whitespace checks.  
  Result: Passed — task-055 logs independently confirm all 11 migrations replayed in each database from empty state. Development seeded/verified with nine categories, weights 1 and empty catalogue. Full Rails suite: 483 tests / 5,353 assertions, no failures/errors/skips. Current-user persistence and rating-history storage tests replace removed transformation/rollback tests. Style 232 files clean; Gem/Importmap audits and Brakeman clean; eager loading and git diff --check pass. Local document checker validates 215 destinations/anchors and retained baseline/unrelated work. No runtime domain behaviour or event contract change.

## Implementation notes

Authorised local history rewrite. A development reset attempt found one active database connection; the authorised reset may disconnect sessions only on glutton_development to complete the drop. No unrelated database/session will be targeted.

Owner acceptance / merge: Pending.


### Verification notes

The first full-suite attempt referenced two deleted correction migrations. Updated those tests to assert final credential/session protections and direct rating-history persistence, rather than obsolete up/down transformations. Re-ran the complete suite and style checks successfully. Fresh catalogue migration up/down tests remain in test/migrations/film_quality_catalogue_migration_test.rb.

Reproducible checks: PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test; RAILS_ENV=development bin/rails zeitwerk:check; RUBOCOP_CACHE_ROOT=/private/tmp/glutton-rubocop-056 bin/rubocop --no-server; standard Gem/Importmap/Brakeman audit commands. Temporary schema checker compares parsed table/foreign-key definitions against the captured pre-cleanup dump, excluding only task-055 catalogue tables and equivalent ordering/text casts. Rebuild commands and initial reset failures are recorded in task 055, not hidden as successful attempts.

Final migration history contains independent creation migrations only, including unchanged generated GoodJob schema. Historic specs remain evidence of earlier delivery, not instructions to replay removed corrections. No PR/merge or deployment performed.
