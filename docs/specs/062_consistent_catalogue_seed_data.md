# 062 — Use YAML seed data and remove category keys

Status: Accepted  
Owner: Film knowledge

## Goal

Use consistent YAML configuration for the one-time catalogue seed and identify quality categories by name/ID rather than a separate key, as requested on 3 November 2026.

## Scope

- Convert config/quality_vocabulary.json to YAML, preserving all 235 names, definitions, exclusions and category membership. Reference category names in the seed data and resolve those names during initial insertion.
- Remove category keys from the model, original catalogue creation migration, config, fixtures, locale entries and tests. Keep category names editable and case-insensitively unique; associations continue to use database IDs.
- Reconcile local development/test schema without resetting or reseeding; preserve category/quality IDs, settings, definitions and film-quality evidence. Use the existing original-migration approach, with no follow-up migration.
- Update current seed documentation and plan; retain historical specs and research JSON as records of earlier work.

## Scope restrictions

- No derived/replacement key, global quality-name uniqueness, category-name immutability, idempotency, upsert, reconciliation logic in db:seed or generic importer.
- No provider calls, research-baseline edits, taxonomy/definition changes, new UI, film enrichment/assignment, scoring, events, other-domain mutations or unrelated cleanup.
- Preserve category caps/weights, optimistic locking, removal/recategorisation permissions and failure behaviour. Keep the one-time seed transaction.

## Acceptance criteria

- **AC1:** One-time YAML seed inserts exactly the retained 235 quality meanings in the correct nine categories.  
  Check: fresh-seed test compares every baseline name, definition, exclusion and category name, checks defaults and transaction rollback. Runtime JSON file removed; no code references remain.  
  Result: Passed — `PARALLEL_WORKERS=1 bin/rails test test/models/quality_category_test.rb test/services/film_knowledge/load_quality_vocabulary_test.rb test/migrations/film_quality_catalogue_migration_test.rb`: 9 tests / 792 assertions, zero failures/errors. The one-time seed is loaded from YAML and all 235 names, definitions, exclusions and category names match the retained JSON research baseline. Nine category defaults and weights match. The forced last-quality storage failure still rolls back the entire load, with no film/viewer/event mutations. Runtime config/quality_vocabulary.json was removed and source-reference search found no remaining runtime references.
- **AC2:** Categories use name/ID only; names/settings remain editable and associations survive renaming.  
  Check: category model/storage tests, original migration schema test, rejection of key assignment, rename preserving quality association and optimistic-lock failures.  
  Result: Passed — focused tests reject category key assignment, allow category renaming/zero caps/weight changes, preserve associated quality IDs through renaming, reject duplicate names case-insensitively and preserve stale-update/removal and recategorisation failures. Original migration test verifies neither categories nor qualities have a key column. Category model validation and key-specific locale entries are removed.
- **AC3:** Original migrations and local databases match the new storage contract without losing data.  
  Check: snapshot comparison across development/test category-key removal; fresh original-migration replay; table inventories; full CI, eager loading, whitespace and retained baseline checks.  
  Result: Passed — `bin/rails runner /private/tmp/glutton-062-reconcile.rb` and `RAILS_ENV=test bin/rails runner /private/tmp/glutton-062-reconcile.rb` removed the category-key constraint/column (including its index); ordered catalogue snapshots were identical before/after excluding only the removed key. Development retains nine categories/235 qualities; no reset or reseed. `bin/rails runner /private/tmp/glutton-062-table-audit.rb` and its test equivalent found exactly 20 expected application tables per database, no obsolete tables. All 11 original migrations replayed into a temporary isolated schema with both key columns absent, and the schema was dropped afterwards. `PARALLEL_WORKERS=1 bin/ci` passed 487 tests / 6,109 assertions, zero failures/errors/skips; 235 Ruby files clean, gem/importmap audits clean, Brakeman zero warnings. `bin/rails zeitwerk:check` passed, with the standard excluded-mailer-preview notice. `git diff --check` and `git diff --exit-code -- docs/film_qualities .obsidian` passed.

## Implementation notes

Both runtime seed files are YAML: `config/quality_categories.yml` and `config/quality_vocabulary.yml`. Each vocabulary entry supplies `quality_category_name`, resolved by the loader when it creates the initial catalogue. Names, definitions/exclusions, category membership and baseline caps/weights were preserved exactly. Historical research JSON remains unchanged.

Removed the category key, index and check constraint from the original `CreateFilmQualityCatalogue` migration, and removed key validation/immutability, locale entries and fixture attributes. No new migration or identifier was introduced. Existing local databases were reconciled without modifying retained values. README and active requirements now describe the current format and name/ID contract; task 061 points here for the superseding change.

To reproduce the seed/rename/storage checks, run the focused command above or full CI. To reproduce preservation verification around local reconciliation, capture these ordered values before/after and compare: `QualityCategory.order(:id).pluck(:id, :name, :maximum_qualities, :weight, :lock_version, :created_at, :updated_at)`, `Quality.order(:id).pluck(:id, :name, :quality_category_id, :match_rule, :not_sufficient, :lock_version, :created_at, :updated_at)` and `FilmQuality.order(:id).pluck(:id, :film_id, :quality_id, :evidence_references, :created_at, :updated_at)`. The temporary reconciliation script performed those comparisons and must not be rerun once the old column is gone. No persistent reconciliation path was added.

For fresh-build verification, create a temporary PostgreSQL schema, set its search path, run each of the 11 original migration proxies from `ActiveRecord::MigrationContext.new([Rails.root.join("db/migrate").to_s]).migrations` with `migrate(:up)`, compare the table inventory to db/schema.rb excluding Rails metadata tables, and assert both key columns are absent. Restore the original search path and drop only the temporary schema. This was completed by the temporary audit script above. No obsolete tables were found; active tables were retained.

No provider calls or changes outside Film knowledge ownership were made. Result is Ready for review, without owner acceptance or merge.

Owner acceptance / merge: Implementation requested on 3 November 2026; result pending review, not merged.

Owner delivery approval, 3 November 2026: final implementation accepted, including the subsequent simplifications; PR and merge after passing CI authorised. Actual merge pending under task 064.
