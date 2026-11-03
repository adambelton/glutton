# 061 — Simplify the initial quality seed

Status: Accepted  
Owner: Film knowledge

## Goal

Follow-up: [task 062](062_consistent_catalogue_seed_data.md) supersedes the retained category keys and mixed seed-file formats. The evidence below records task 061 before that change.

Remove the redundant quality key and make the vocabulary seed a one-time initial load, following the owner's clarification on 3 November 2026. Names remain immutable; database IDs identify associations.

## Scope

- Remove Quality's key column, validation, immutable_key method and locale entries. Remove quality keys from runtime seed data; retain category keys, whose mutable display names have different requirements.
- Preserve existing names, IDs, definitions, categories and film-quality evidence by updating the original catalogue creation migration and removing the unmerged definition migration, as explicitly requested by the owner; reconcile already-migrated local databases without resetting data. Replace key-dependent definition validation with an optional complete pair: legacy name-only qualities remain valid; supplied definitions/exclusions must both be nonblank.
- Create categories and all 235 qualities directly in one transaction through db:seed. No matching/reuse/upsert, idempotency or edit-preservation logic. This is an initial-load command for an empty catalogue, not a reconciliation or editing tool.
- Audit development/test tables against the current original migrations and schema; remove any retired film-analysis tables if found, while preserving active Rails/GoodJob and other-domain tables. Prove all original migrations build the current table set in an isolated schema.
- Update affected tests, README and plan. Keep task 060's verification as historical evidence, with this follow-up explicitly superseding its key/rerun design.

## Scope restrictions

- No follow-up key-removal migration, database reset, reseeding existing development records, renaming or recategorising qualities, change to category keys, global name-uniqueness changes, derived key or replacement identifier.
- No provider calls, film imports, enrichment, assignment, UI, scoring, events, other-domain changes or research-baseline edits.
- No custom duplicate handling/retry machinery, generic importer or extra lifecycle states. Ordinary model/storage failures propagate and roll back the transaction.

## Acceptance criteria

- **AC1:** Quality has no key field/API and retains immutable names, editable definitions and stale-write protection.  
  Check: model/storage tests for optional complete definition pairs, name immutability and stale edits; isolated original migration up/down preserving IDs, links and evidence.  
  Result: Passed — `PARALLEL_WORKERS=1 bin/ci` includes model tests proving a key assignment is unknown, names remain immutable, definitions can be edited, stale writes fail, supplied definition/exclusion pairs must be complete and nonblank, and legacy name-only records remain valid. Original catalogue migration test verifies no quality key, both text fields, the pair constraint, foreign keys and migration reversal. Earlier focused check before folding definitions into the creation migration passed 12 tests / 824 assertions; final original-migration form is covered by the full suite below.
- **AC2:** A fresh one-time seed creates all 235 original names/definitions/exclusions and nine configured categories, without film/viewer mutations.  
  Check: invoke db:seed on isolated empty test catalogue and compare every baseline entry and category default. Force a persistence failure to verify rollback. No rerun-success or existing-edit-preservation contract.  
  Result: Passed — the service test invokes `load Rails.root.join("db/seeds.rb")` after clearing only its isolated test catalogue. All 235 original names/definitions/exclusions and nine category defaults match the retained baseline; Film, FilmQuality, LibraryFilm, Rating and DomainEvent counts remain unchanged. A temporary database check rejecting the last quality forces a late insert failure and verifies that all initial category/quality inserts roll back. No rerun/preservation lookup remains in the loader.
- **AC3:** Local existing catalogue survives key removal and all required checks pass.  
  Check: reconcile development/test to the edited original migration without reset; compare names/IDs/definitions/category/evidence snapshots before/after. Run focused tests, full CI, eager loading, whitespace and retained baseline checks.  
  Result: Passed — `bin/rails runner /private/tmp/glutton-061-reconcile.rb` and its `RAILS_ENV=test` equivalent removed only the redundant column/old constraints and installed the complete-pair constraint. Ordered snapshots of quality IDs/names/categories/definitions/lock versions/timestamps, category settings and film-quality evidence were identical before/after. Development retained 235 qualities/nine categories; test retained its existing fixture state. The temporary audit removed the obsolete unmerged migration-version receipt after folding the fields into the original migration, and `bin/rails db:schema:dump` now reflects the original latest version. `PARALLEL_WORKERS=1 bin/ci` passed: 487 tests / 6,110 assertions, zero failures/errors/skips, 235 Ruby files clean, gem/importmap audits clean, Brakeman zero warnings. `bin/rails zeitwerk:check` passed (standard excluded mailer-preview notice). `git diff --check` and `git diff --exit-code -- docs/film_qualities .obsidian` passed.

- **AC4:** No obsolete tables remain in development/test or fresh installation.  
  Check: compare live table inventories to the current migration/schema contract and inspect retired analysis table names. Replay original migrations in an isolated schema, compare tables, then remove only the temporary schema.  
  Result: Passed — `bin/rails runner /private/tmp/glutton-061-table-audit.rb` and its test-environment equivalent found 20 application tables each, exactly matching db/schema.rb after excluding Rails metadata tables. No unexpected or retired analysis tables were present, so no existing table needed deletion. The development audit replayed all 11 original migrations into a temporary isolated schema: exactly the expected 20 tables, no quality key and both definition columns. It then dropped that temporary schema. Active Rails/GoodJob and product-domain tables were retained.

## Implementation notes

Removed the quality key from the model, schema, locale entries and runtime vocabulary. No derived key or replacement identifier was added. The loader now directly creates categories and qualities in one transaction, with no lookup/reuse/update behaviour; README documents the one-time empty-catalogue requirement.

Per owner instruction, definition fields and their pair constraint now live in `20261029130000_create_film_quality_catalogue.rb`. The unmerged add-definition migration and proposed remove-key migration were removed; no production upgrade path was introduced. Existing local data was preserved while reconciling the already-run original migration. Task 060 remains a historical verification record, explicitly superseded here for key/idempotency decisions.

Reproduce catalogue preservation without reseeding: snapshot `Quality.order(:id).pluck(:id, :name, :quality_category_id, :match_rule, :not_sufficient, :lock_version, :created_at, :updated_at)`, category settings and `FilmQuality.order(:id).pluck(:id, :film_id, :quality_id, :evidence_references, :created_at, :updated_at)` before any local schema reconciliation, and compare afterwards. The temporary reconciliation script ran exactly this comparison; it is a one-time development operation and must not be rerun after key removal.

Reproduce the table audit in the Rails console: compare `(ActiveRecord::Base.connection.tables - %w[ar_internal_metadata schema_migrations]).sort` with `Rails.root.join("db/schema.rb").read.scan(/create_table "([^"]+)"/).flatten.sort`. In a fresh isolated PostgreSQL schema, run each migration from `ActiveRecord::MigrationContext.new([Rails.root.join("db/migrate").to_s]).migrations` with `migrate(:up)`, compare the table set, then restore the original search path and drop only the temporary schema. Do not reset or reseed the populated development catalogue. Full CI includes isolated original catalogue migration and one-time seed checks.

No outdated tables were found. Film import/enrichment/assignment remain subsequent tasks; no provider calls, UI or domain-event changes were made.

Owner acceptance / merge: Implementation requested on 3 November 2026; result pending review, not merged.

Owner delivery approval, 3 November 2026: final implementation accepted, including the subsequent simplifications; PR and merge after passing CI authorised. Actual merge pending under task 064.
