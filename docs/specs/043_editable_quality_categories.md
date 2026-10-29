# 043 — Replace hard-coded dimensions with editable quality categories

Status: Ready for review  
Owner: Film knowledge

## Goal

Allow quality categories to be added, renamed and used without a deployment, while preserving existing quality identities and current association behaviour. Prerequisites: task 042, current product/quality requirements, task 028 implementation and current model/schema/candidate usages. Independent of the unresolved decision to retain or replace FilmAnalysis.

## Scope

Owner authorised baseline assumptions and implementation on 29 October 2026. This task delivers persisted category configuration and compatibility, not the full enrichment/admin/scoring pipeline.

- Persist a nonnegative integer maximum_qualities and nonnegative decimal weight per category, with optimistic locking. Initial nine-category configuration: subgenres 2; tropes/situations 5; narrative devices 3; themes 4; ironies/reversals 2; character/social dynamics 3; presentation/intensity 4; emotional tone/experience 3; resolution/aftermath 2. All weights 1. Support threshold 0.60 is the baseline for later selection work, not implemented matching in this task.
- Category seed data is idempotent and never resets later tuning. Preserve all seven legacy dimension identities as data categories (default maximum 3, except shared resolution category 2), without speculative semantic remapping into the new vocabulary. New category names are content. Do not seed the 235 qualities.
- Keep quality names immutable while allowing recategorisation; use optimistic locking for concurrent quality changes. Category keys are immutable stable identifiers. Existing Rails update!/destroy! actions retain validation, stale and missing-record failures; no user-action silent-success wrapper.

- Add persisted quality categories and associate each FilmQuality with a category. Use ordinary Rails models/foreign keys; no fixed category enum, STI, hierarchy or generic taxonomy engine.
- Migrate the existing seven dimension values into category records, preserving FilmQuality IDs, names and all existing associations. Replace the model inclusion list and database fixed-value check with category existence/referential integrity. Do not seed the research vocabulary as accepted product data.
- Support category creation, cosmetic rename and recategorising a quality while keeping its identity/meaning. Define model-owned actions/permissions, freshness/concurrency handling and explicit failures. Restrict removal of a category still in use; an empty category may be removed. Moving qualities first makes category removal possible without destructive cascades.
- Preserve the existing normalized-name collision rule within a category. A conflicting move fails explicitly and leaves both identities/associations unchanged; do not silently merge concepts. Review the exact identity lookup and transaction boundaries before implementation.
- Adapt existing Film knowledge candidate validation/publication and vocabulary serialization to category identity. Keep publication atomicity and explicit selected-quality validation. Replace any active static generator schema/category validation with current category data rather than preserving hidden dimension enums. This is compatibility work for the currently implemented path, not an endorsement of further generative analysis.
- Inspect existing drafts containing dimension strings and specify a bounded conversion/compatibility path before changing their reader. Existing accepted qualities/associations must retain identity; do not silently strand saved drafts or misclassify unknown categories.
- Localise new application-authored labels/errors. Category names are editable content, not locale keys encoding a closed vocabulary.

## Scope restrictions

- No FilmAnalysis/AnalysisQuality removal, direct-film association redesign, source refresh/subscription, history-retention implementation or new editorial publication workflow.
- No JEV integration, batching/threshold selection, model/provider calls, remote prompt edits, automated matching or production vocabulary seeding. Resolve any incompatible currently managed prompt contract explicitly before implementation; do not pay for a run or maintain a second closed category list to avoid that decision.
- No Ratings/Recommendations mutations, event publisher/subscriber, reassessment engine or scoring change. A grouping-only change does not change quality meaning and emits no semantic scoring-change event.
- No category-management browser UI, multi-category membership, applying weights to scores, enforcing these caps on legacy analysis publication or subclass hierarchy. Revisit only when concrete behaviour requires it.
- Preserve .obsidian/, unrelated work, current lifecycle invariants and user evidence. No deployment/merge automatically.

## Acceptance criteria

- **AC1:** An arbitrary new category can be created and used without code/schema/configuration changes.  
  Check: meaningful model/publication test creates a category absent from the original seven, creates/assigns a quality and reads it back; missing category fails at model and database boundaries.  
  Result: Passed — an arbitrary persisted new category publishes through the existing candidate format and is included dynamically in generation input/schema; missing category fails model validation and the NOT NULL/foreign-key boundary. Focused suite: 65 tests / 425 assertions, no failures/errors/skips (PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/models/quality_category_test.rb test/models/film_analysis_test.rb test/models/film_analysis_concurrency_test.rb test/models/film_knowledge test/services/film_knowledge/generate_analysis_test.rb).
- **AC2:** Migration preserves existing identities, associations and usable saved drafts.  
  Check: migration verification with representative old dimensions/drafts; compare quality IDs/names and association targets before/after. Exercise rollback or document its explicit data limits once new categories exist.  
  Result: Passed — RAILS_ENV=test bin/rails db:migrate completed. Isolated migration test creates the former schema and representative qualities, published links and saved draft JSON, then verifies preserved IDs/names/category mapping/links and identical draft documents after migration: 1 test / 5 assertions passed. Down migration explicitly raises IrreversibleMigration; no speculative mapping of the seven legacy meanings into the new categories. Development/production databases not migrated.
- **AC3:** Grouping edits are safe and independent of scoring.  
  Check: category rename, quality move, same-category name collision, stale/missing target and removal-while-in-use tests assert observable persistence outcomes. No duplicate/merged quality and no cross-domain writes/events.  
  Result: Passed — category rename/configuration, zero/invalid caps and weights, stable category keys, immutable quality names, category moves/collisions, stale/missing edits, referenced-category removal and seed reruns covered in QualityCategoryTest and compatibility tests. Moves use model-owned recategorise! with freshness/no-change handling; remove! refreshes references under lock. Grouping/configuration changes produce no scoring events or cross-domain writes. No admin HTTP/API entry point added.
- **AC4:** Existing Film knowledge entry points use categories consistently.  
  Check: focused candidate/publication/serialization/schema tests, locale checks, migration checks, full required CI and eager loading. No active fixed dimension enum or hidden seven-category fallback. Record managed-prompt compatibility decision before implementation. Verify category max/weight bounds in model/database, stale config/quality moves, name immutability, seed defaults and idempotency.  
  Result: Passed — full suite: PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test, 543 tests / 5,721 assertions, no failures/errors/skips. RUBOCOP_CACHE_ROOT=/private/tmp/glutton-rubocop-043 bin/rubocop --no-server inspected 258 files, clean. bin/bundler-audit check, bin/importmap audit and bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error passed. Locale checks included symbolic custom errors without missing translations. Exact bounds are model/database validated; new-category schema round trip and idempotent seed defaults tested. No managed prompt or provider call made.

## Implementation notes

Implementation authorised. Compatibility decision: retain the existing generator entry point and its dimension wire field, whose values now refer to persisted category keys, supplied dynamically in the generation input/schema. No managed prompt or provider call changes; no fixed seven-category enum remains. Saved draft JSON dimension strings remain readable through those preserved category keys, without rewriting published/historical documents. New candidate forms may use quality_category_id; existing selected IDs remain valid. Removing a category referenced only by a saved legacy draft must fail, as must removing a category with qualities. Existing generators remain legacy compatibility, not the new JEV pipeline.

Rollback is intentionally irreversible after category creation/moves: new category keys cannot safely become the former closed enum. Verification will migrate representative pre-change rows in an isolated test schema, preserving IDs and draft/published links. Only the test database may be migrated during this task. No public/admin HTTP entry points added; access policy remains the later admin-interface task.

Owner acceptance / merge: Pending.


### Delivered and verification limitations — 29 October 2026

Implemented QualityCategory configuration, seeded baseline data, migration of FilmQuality category identity, model-owned category removal/quality recategorisation, optimistic locking and legacy candidate/generator compatibility. Names remain immutable and saved dimension strings resolve persisted category keys. No quality definitions or researched vocabulary records were seeded; no associations were selected or changed by seed configuration.

The normal parallel test invocation crashed in the local Ruby 3.4.11 / pg native extension during forked database connections. Stopped that parent and reran with PARALLEL_WORKERS=1; focused and complete suites passed. The test-only migration and all database checks required local PostgreSQL access outside sandbox restrictions. CI setup was not run because bin/setup would prepare the development database; required style/security/test checks were run separately. Hosted CI has not run for this uncommitted implementation.

Baseline support threshold 0.60 and category caps are not yet applied by a JEV selection operation. Stored category weights are not yet used in scoring. Admin interfaces, seed/import orchestration and source syncing remain separately scoped. This task completes the first category-configuration slice, not the complete release pipeline.

Final checks: RAILS_ENV=test bin/rails zeitwerk:check passed (standard mailer-preview-directory notice only). python3 /tmp/glutton-043-document-check.py checked all changed/new Markdown local destinations and whitespace while preserving the five retained baseline data/docs files and seven unrelated local status diffs. It intentionally permits this task's application/spec changes. git diff --check passed. No further paid calls, external communication, commit, PR, merge or deployment performed.

Follow-up: owner confirmed removal of FilmAnalysis and corrected model roles to Quality, QualityCategory, Film and FilmQuality. Task 054 supersedes this task's temporary generator/dimension compatibility and draft-reference handling. The category configuration and its historical verification remain useful; task-054 results verify the new runtime separately.

Final installation follow-up: tasks 055/056 replace the temporary category-conversion migration with direct catalogue creation and owner-authorised local database rebuilds. Earlier transition-test evidence is historical; no old dimensions or analysis tables are installed by the final migrations.
