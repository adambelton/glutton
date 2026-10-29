# 054 — Replace FilmAnalysis with direct current film qualities

Status: Ready for review  
Owner: Film knowledge

## Goal

Remove the independent FilmAnalysis lifecycle and generated-analysis path. Films own current source context and direct accepted quality associations, preserving current accepted evidence through migration. Owner explicitly confirmed FilmAnalysis removal and requested code changes on 29 October 2026. Prerequisites: implementation plan, current film-quality requirements, category task 043 and existing migrations/domain-event rules.

## Scope

- Add Film source_context JSON object and FilmQuality as the join (film, Quality identity, nonempty evidence references). Rename the existing shared FilmQuality vocabulary to Quality, preserving IDs. The four domain models are Quality, QualityCategory, Film and FilmQuality; no FilmQualityAssignment model. Unique film/quality links and foreign keys prevent duplicate/dangling associations. Preserve current accepted associations, evidence references and the current legacy source document as an explicitly labelled source-context import, not a new analysis lifecycle. No old-set reconstruction API.
- Migrate only current published analyses, never superseded or unpublished candidates. Preserve film/quality identities across the vocabulary and join table renames and existing TMDB metadata. Do not trim existing accepted data to new category ceilings during migration. Drop legacy analysis/link tables after conversion; rollback is explicitly irreversible.
- Refuse migration if unpublished drafts exist, before any destructive change. They are not accepted film qualities and must not be silently published or discarded. Resolve/export drafts through an explicit operational decision before applying this migration to such an environment. This task migrates only the test database.
- Remove FilmAnalysis/AnalysisQuality models, generation/candidate/content/prompt classes, paid generation rake task, prompt-check CLI, generation-only fixtures/helpers/tests and obsolete locale copy. Preserve ordinary TMDB import/sample loading and shared AI configuration/tracing used elsewhere.
- Remove dimension compatibility and candidate-based Quality creation; persisted categories are the only grouping identity. Adapt category/reference tests to direct film links; preserve category configuration, immutable names and safe recategorisation/removal.
- Update current plan/requirements/proposal/brief to record the decision. Historical delivered specs/migrations remain historical; do not rewrite earlier verification as though it tested the new schema.

## Scope restrictions

- No JEV/provider calls, remote prompt deletion, Wikipedia/TMDB sync, bulk seed, admin interface, scoring/selection application, refresh-suggestion storage or new publication/event workflow. Storage/model retirement only; agreed events and separate publisher/subscriber specs are prerequisites for later scoring-aware mutation operations.
- No Ratings/Recommendations/Library mutation or changes to original ratings, expressions or saved scoring contributions. No new independent archive of every past film-quality set.
- Preserve unrelated local documentation/research/category work and ignored files. No development/production migration, automatic merge or deployment.

## Acceptance criteria

- **AC1:** Direct film qualities and source context work without FilmAnalysis.  
  Check: read film qualities and associated films, preserve independent context/metadata, reject invalid evidence/duplicates/dangling references; deletion restrictions protect accepted associations. Category moves retain quality/link identity and evidence.  
  Result: Passed — direct Film.qualities / Quality.films through FilmQuality verified, alongside retained references, source-context/metadata independence, invalid evidence, duplicate/FK protection and deletion restrictions. Category tests now use Quality and direct FilmQuality links; stale/collision/name-immutability checks remain. Focused suite: 52 tests / 1,054 assertions, no failures/errors/skips.
- **AC2:** Migration preserves current accepted data and handles drafts safely.  
  Check: isolated old-schema test with current/superseded analyses, source content, links and unchanged metadata/IDs; only current accepted links copied, old tables removed. Unpublished-draft case fails before new schema writes. Explicit irreversible rollback.  
  Result: Passed — both new migrations applied only to glutton_test. Isolated migration tests preserve shared Quality IDs, current film links/references/timestamps/source content and TMDB metadata across table/column renames; superseded links excluded, old tables absent, FK points to qualities. Draft case raises before new table/column creation and retains original draft content. Down migration explicitly irreversible. The earlier category migration remains separately tested on its former schema.
- **AC3:** Retired analysis code is no longer executable or referenced by runtime.  
  Check: search app/lib/config for removed model/generator/candidate APIs and dimension compatibility; check task list and eager loading. Historical migrations/tests may refer to old table names solely to verify transitions. TMDB tests remain green.  
  Result: Passed — rg search of app/lib/config/locales found no FilmAnalysis, AnalysisQuality, FilmQualityAssignment, retired generator/prompt/candidate/content APIs or dimension accessor. Historical migration names appear only in migrations/transition tests and historical docs. Eager loading passed; ordinary TMDB/sample tasks retained, paid generation task removed. Shared AI configuration and remote prompt/trace data untouched.
- **AC4:** Required checks pass with evidence and scope limits recorded.  
  Check: focused/full single-worker Rails tests, Ruby style, security checks, eager loading, links/whitespace and baseline/unrelated-file preservation. Update implementation plan and mark Ready for review, not accepted/merged.  
  Result: Passed — PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test: 485 tests / 5,374 assertions, no failures/errors/skips. RAILS_ENV=test bin/rails zeitwerk:check passed (standard mailer-preview notice). Ruby style: 243 files clean; Gem audit, Importmap audit and Brakeman clean (0 warnings). python3 /tmp/glutton-043-document-check.py: 212 local links/anchors across 18 changed Markdown files and whitespace passed, five retained baseline files and seven unrelated local status diffs unchanged. git diff --check passed. No new paid calls, external messages, hosted CI, development/production migration or merge.

## Implementation notes

Authorised replacement of runtime analysis models, not a new film publication workflow. Existing accepted evidence becomes current Film-owned data. An environment containing unpublished analysis drafts requires explicit draft disposition before migration; no real records will be discarded by this task.

Delivered: Quality/QualityCategory/Film/FilmQuality model roles, Film-owned current source context, preservation migration and naming migration; removed analysis lifecycle/generation/candidate/content code and their obsolete tests/fixtures/task/CLI/locales. Category configuration and ordinary TMDB behaviour remain. Updated active requirements/brief/proposal/event placeholder and retired-generator documentation; earlier delivery records remain historical.

Reproduce focused checks with PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/models/film_quality_test.rb test/models/film_test.rb test/models/quality_category_test.rb test/migrations test/services/film_knowledge. The migration tests create/drop isolated schemas within glutton_test. Full verification commands are recorded above; style uses RUBOCOP_CACHE_ROOT=/private/tmp/glutton-rubocop-054 bin/rubocop --no-server. Security commands: bin/bundler-audit check; bin/importmap audit; bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error. The temporary document checker reuses pre-task baseline hashes and resolves links/heading anchors in changed/new Markdown. Removed analysis-only tests explain the smaller total; retained application/domain tests pass.

Limitations: no admin editing/publication, JEV suggestion/selection, Wikipedia enrichment or scoring reassessment operation is added. Source-context versioning/sync must be specified before implementing refresh; a migration alone does not implement that behaviour. Migration deliberately blocks any environment with unpublished analysis drafts until explicit disposition/export. Only test data was migrated. The owner confirmed retaining Quality naming.

Owner acceptance / merge: Pending.

Follow-up supersession: owner confirmed development is the only application environment, existing development data may be discarded, and all local correction migrations should be cleaned up. Tasks 055/056 replace the intermediate preservation/rename migrations and transition tests with direct creation and fresh-schema checks. The prior draft guard, test-only migration limit and preservation results above are historical intermediate evidence, not the final installation procedure. Model roles/behaviour remain Quality, QualityCategory, Film and FilmQuality.
