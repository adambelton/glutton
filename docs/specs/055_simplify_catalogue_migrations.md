# 055 — Simplify catalogue migrations and rebuild development

Status: Ready for review  
Owner: Film knowledge

## Goal

Remove the original analysis migration and collapse the category/direct-quality migration chain into one clean catalogue migration. Owner explicitly authorised rewriting local history and dropping/rebuilding all development tables on 29 October 2026; existing development data need not be preserved. Development is the only application environment.

## Scope

- Replace the original analysis migration and three local follow-ups with one migration directly creating quality_categories, qualities, film_qualities and Film source_context. Preserve model contracts and baseline seed configuration; no analysis tables on a fresh install.
- Drop/recreate glutton_development and rerun all migrations/seeds. Rebuild glutton_test for verification. These are local disposable databases; no backups/legacy-data conversion or migration guard is required under the owner's explicit reset instruction.
- Replace historical-transition tests with direct schema/migration contract verification. Update current plan/docs/task evidence to distinguish this final migration from earlier superseded local verification.

## Scope restrictions

- No production environment, paid/provider calls, live prompt changes, deployment or merge. No new selection, scoring, admin UI or event workflow. Preserve unrelated workspace/research files.

## Acceptance criteria

- **AC1:** Fresh migration creates the target catalogue directly.  
  Check: isolated migration/schema test, model/full suite and eager loading; no analysis migration/runtime path remains.  
  Result: Passed — direct catalogue creation test exercises a fresh isolated schema and rollback, checking the four catalogue/base tables, source-context object, foreign keys and unique film-quality pair. Removed the original analysis migration, three intermediate local conversions and their superseded transition tests. Runtime/model contracts remain covered; full suite passed as recorded below.
- **AC2:** Development is rebuilt successfully from all remaining migrations.  
  Check: explicit database identity, db:drop/create/migrate/seed, migration status and baseline category values. Films/qualities/links start empty; all nine configured categories are present.  
  Result: Passed — dropped/recreated glutton_development with owner-authorised data loss and reran all 11 remaining migrations plus db:seed. Development verification confirmed exactly those 11 version entries, nine configured categories with expected per-category caps and all weights 1; films/qualities/links empty, no analysis tables. One active development session required DROP DATABASE ... WITH (FORCE), targeting only the authorised local database.
- **AC3:** Code/docs and migration state are consistent.  
  Check: test database rebuild, style/security/links/whitespace checks; preserve unrelated files and record exact commands/results.  
  Result: Passed — rebuilt glutton_test from the same 11 migrations. Full suite 483 tests / 5,353 assertions, no failures/errors/skips; Ruby style 232 files clean, Gem/Importmap audits clean, Brakeman 0 warnings, development eager loading passed (standard mailer-preview notice only). Document checker: 215 local destinations/anchors and whitespace valid; five baseline files and seven unrelated status diffs preserved. git diff --check passed. No paid calls, hosted CI, merge or deployment.

## Implementation notes

Read-only inventory confirmed glutton_development had two films and two unpublished analyses, with no quality/analysis links. The owner then explicitly authorised discarding all development data and rebuilding, superseding earlier backup/export/preservation plans. No migration compatibility bridge or old analysis lifecycle is needed.

Owner acceptance / merge: Pending.


### Actual execution and reproducibility

The initial db:drop encountered an active local development session. After authorised force-drop, Rails automatically bootstrapped the prior schema dump, causing a duplicate-table migration error. No existing data needed recovery under the owner's reset instruction. Repeated the reset with fresh, initially absent SCHEMA paths so db:migrate replayed every migration rather than loading db/schema.rb:

- psql -h localhost -d postgres -v ON_ERROR_STOP=1 -c 'DROP DATABASE glutton_development WITH (FORCE)' (and the corresponding glutton_test command).
- SKIP_TEST_DATABASE=1 SCHEMA=/private/tmp/glutton-055-fresh-dev-schema.rb RAILS_ENV=development bin/rails db:create db:migrate db:seed.
- SCHEMA=/private/tmp/glutton-055-fresh-test-schema.rb RAILS_ENV=test bin/rails db:create db:migrate.
- RAILS_ENV=development bin/rails db:schema:dump.

Migration logs are /private/tmp/glutton-055-dev-rebuild.log and /private/tmp/glutton-055-test-rebuild.log; both contain all 11 completed versions. SCHEMA paths were absent before execution; use new absent paths to reproduce a true migration replay. Temporary local verification script tmp/catalogue-migration-055/verify.rb checks database identity, versions, category defaults, empty catalogue and absence of analysis tables. These temporary files are not application dependencies. Owner explicitly waived data preservation; no backup/export was created or needed.

Final application checks: PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test; RAILS_ENV=development bin/rails zeitwerk:check; RUBOCOP_CACHE_ROOT=/private/tmp/glutton-rubocop-056 bin/rubocop --no-server; bin/bundler-audit check; bin/importmap audit; bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error. Supporting correction consolidation is recorded in task 056. Source syncing/selection/scoring/admin UI remain unimplemented by these migration tasks.
