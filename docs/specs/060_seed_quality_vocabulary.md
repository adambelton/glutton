# 060 — Load the initial quality vocabulary

Status: Accepted  
Owner: Film knowledge

## Goal

Owner follow-up, 3 November 2026: [task 061](061_simplify_initial_quality_seed.md) supersedes this task’s quality-key and idempotent-seed design. The details/results below record the original implementation; current code uses names/IDs and one-time insertion.

Persist the existing 235-quality baseline and definitions as usable catalogue data, with a safe repeatable seed command. This is the first bounded implementation of the approved seed-first stage, consuming the existing Quality/QualityCategory roles and category defaults.

## Scope

- Add an immutable, optional stable quality key and persisted matching definition/exclusion. Existing unkeyed records remain valid and unchanged; keyed qualities require nonblank definitions/exclusions. Preserve internal IDs, names, category moves and optimistic locking.
- Package the retained vocabulary as runtime seed data under config, preserving all original IDs, names and meanings exactly. Resolve original category labels to stable category keys when packaging, never from mutable category display names at runtime.
- Seed missing categories and keyed qualities in one transaction through FilmKnowledge::LoadQualityVocabulary, invoked by db:seed. Existing keyed qualities and category settings are never updated, including later definition edits or recategorisation. No name-based adoption of unkeyed qualities: a conflicting category/name raises the normal storage/model failure and rolls back the whole seed.
- Return the ordered seeded quality records; safe repeated system seeding is an explicit idempotency boundary. Unique database keys prevent duplicate identities; concurrent failures may be retried by the operator, with no partial commit.
- Run the migration and vocabulary seed in local development without dropping existing data; record counts and rerun preservation evidence. Document the seed command and recovery behaviour.

## Scope restrictions

- No film imports, Wikipedia fetching, initial assignment, TypeSafe integration or paid calls. These remain the subsequent seed-path capabilities; this task does not claim a usable film seed is complete.
- No new taxonomy research, matching wording changes, category-policy changes, refresh suggestions (058), admin screens/forms, source sync, scoring, publication/events or other-domain mutations.
- No adoption/renaming/reclassification of existing qualities, destructive reset, changes to historical examples or baseline files, generic importer, permanent vocabulary-version lifecycle or automatic overwriting of edited data. Model fields may be edited through normal validated persistence; admin editing workflows remain separate.

## Acceptance criteria

- **AC1:** Fresh seeding persists all 235 baseline identities, names, categories and definition/exclusion pairs exactly, with nine default categories.  
  Check: service tests compare runtime seed against the retained baseline and persisted values; execute db:seed locally and inspect counts.  
  Result: Passed — focused command `PARALLEL_WORKERS=1 bin/rails test test/models/quality_test.rb test/models/quality_category_test.rb test/services/film_knowledge/load_quality_vocabulary_test.rb test/migrations/film_quality_catalogue_migration_test.rb`: 13 tests / 1,094 assertions, zero failures/errors. Exact comparison of all 235 baseline IDs/names/definitions/exclusions and category mappings passed. `bin/rails db:seed` loaded development; runner confirmed 235 keyed qualities, nine categories, zero films and zero associations.
- **AC2:** Reruns preserve IDs, edits, recategorisation, category tuning and existing film-quality evidence; failure rolls back the complete seed.  
  Check: observable preservation tests, late name collision with an unkeyed record, local seed rerun. No film or viewer activity creation.  
  Result: Passed — same focused tests verify changed definitions/exclusions, recategorisation, renamed category/zero cap/weight tuning, stable record IDs/timestamps and unchanged accepted evidence/source context. An unkeyed collision at the final baseline entry rolls back all prior new qualities/categories; removing the collision permits retry. A local runner snapshot of ordered IDs/keys/definitions/category settings/lock versions/timestamps before and after loading db/seeds.rb was identical (`rerun_preserved: true`). No provider calls or cross-domain mutations.
- **AC3:** Quality keys are immutable and unique; keyed definitions/exclusions are required. Legacy unkeyed records survive migration.  
  Check: model/schema failure tests and isolated migration up/down against an existing quality/link, localized validation messages.  
  Result: Passed — `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:migrate` completed the additive migration. Focused tests passed model/storage invalid-key, duplicate-key and blank-definition/exclusion rejection, immutable key and stale-definition-edit failures, translated validation messages and legacy unkeyed persistence. Isolated schema migration up/down preserved an existing quality, film link and evidence. Development/test already enable strict missing-translation errors.
- **AC4:** Required verification and bounded delivery are documented.  
  Check: focused tests, full CI, eager loading, whitespace and baseline preservation. Mark Ready for review, without self-acceptance or merge.  
  Result: Passed — `PARALLEL_WORKERS=1 bin/ci`: setup, 236 Ruby files with no offences, gem/importmap audits with no vulnerabilities, Brakeman with zero warnings, 489 tests / 6,387 assertions with zero failures/errors/skips. `bin/rails zeitwerk:check` passed. `git diff --check` passed and `git diff --exit-code -- docs/film_qualities` confirmed retained baseline files unchanged. Initial sandbox-only database and RuboCop attempts could not access local PostgreSQL/cache; the authorised full-access checks above passed. Initial focused checks exposed a missing test category and Rails find-or-create collision masking; setup was corrected and the loader now reports the actual unique-name failure, with the final focused/full checks passing.

## Implementation notes

Added nullable `key`, `match_rule` and `not_sufficient` columns to Quality. Optional keys support legacy records; keyed records enforce complete definitions in both model and storage. Keys/names are immutable through the model, definitions remain editable with existing optimistic locking. Runtime JSON is an exact copy of retained meanings with stable category keys rather than mutable display labels. FilmKnowledge::LoadQualityVocabulary and db:seed create missing records within one transaction and never update existing records. README documents commands, rollback and retry limits. No API calls, film imports, assignment, UI or events were implemented.

Development seeding and its preservation check ran on 3 November 2026. The verification runner captures `Quality.order(:id).pluck(:id, :key, :name, :quality_category_id, :match_rule, :not_sufficient, :lock_version, :updated_at)` and `QualityCategory.order(:id).pluck(:id, :key, :name, :maximum_qualities, :weight, :lock_version, :updated_at)`, loads `db/seeds.rb` and compares the same queries; both comparisons passed. Reproduce after `bin/rails db:seed` using `bin/rails runner` or the Rails console. No destructive reset occurred. Unrelated PostgreSQL cast-format changes in the generated schema dump were normalised back to their previous text; only the new quality storage contract/version remains in the schema diff.

Remaining seed work is canonical TMDB import/Wikipedia enrichment and initial 60%/category-cap assignment using the shared bulk/on-demand path. This vocabulary slice does not claim the complete seed pipeline is delivered. Concurrent seed errors propagate and roll back; an operator can retry, with no automatic retry loop.

Owner acceptance / merge: Implementation authorised on 3 November 2026; completed result pending review, not merged.

Owner delivery approval, 3 November 2026: final implementation accepted, including the subsequent simplifications; PR and merge after passing CI authorised. Actual merge pending under task 064.
