# 028 — Persist film analysis drafts and publish quality associations

Status: Accepted — merge pending  
Owner: Film knowledge

## Goal

An existing catalogue film can have an editable analysis draft and quality candidates, then atomically publish them as its current knowledge while preserving previous analyses and associations. Human and AI authors use the same persistence lifecycle. This task supplies domain operations and storage, not an authoring interface or AI integration.

Prerequisites: existing Film catalogue persistence and the agreed [V1 workflow](../film_analysis_requirements.md#v1-draft-and-quality-workflow). OpenAI/Langfuse configuration and managed prompt setup are merged via PR #41; Langfuse owns prompt revisions. This task accepts supplied analysis content and quality proposals without making API calls. The completed pilots inform content examples; production publication does not require another pilot. No new cross-domain behavioural contract is consumed.

## Approved Film editing and publishing boundary

Film is the client entry point: `film.edit_analysis!(content:, quality_candidates:)` creates or reuses the unpublished draft, copying the current published content and candidates when starting a revision. Omitted fields are preserved; explicitly empty values clear them. `film.publish_analysis!` publishes the pending changes through internal `FilmKnowledge::PublishAnalysis` coordination. Clients do not select version IDs or manage drafts/supersession. Publishing without unpublished changes fails explicitly with a localized domain error. Use `published_at` and publication terminology throughout. Shared FilmQuality vocabulary remains independently owned within Film knowledge.

Verification: exercise initial editing, repeated editing, copying current knowledge, omitted versus empty fields, publication and no-pending-change failure, historical immutability and concurrent edit/publication. An edit serialized after publication starts the next draft without changing the published version. Revise the unmerged migration in place after test-database rollback; no development data migration or UI changes. Verification passed; see the acceptance criteria below.

## Scope

- Persist FilmAnalysis belonging to Film, with authored narrative/evidence content, explicit source references and gaps, without an origin classification or authoring-provenance field. Use a simple structured document for analysis content; do not build a table per claim or a generic schema engine.
- Keep evidence sources within the analysis content. Defer separate authoring/run provenance until its retention requirements are agreed; no origin, prompt/model or trace metadata field in this task.
- Persist editable quality candidates as the `quality_candidates` JSON array on the draft analysis (no candidate table), including a self-explanatory proposed name or selected existing quality, dimension and evidence references into that analysis. Support manual add/edit/remove and replacing a draft's candidate set with supplied candidates. Actual AI generation is deferred; future generation follows the separately documented [OpenAI API prompt/run protocol](../prompts/film_analysis/README.md).
- Persist shared FilmQuality records within Film knowledge, plus AnalysisQuality associations belonging to a published FilmAnalysis. Define the seven agreed dimensions as FilmQuality::Dimensions constants with localized display labels; persist the validated dimension value on FilmQuality, not a dimension record. Qualities can occur in multiple analyses/films. Do not require a separate definition field or seed the pilot vocabulary as accepted facts.
- Resolve explicitly selected existing qualities by identity. For new proposals, trim names and reuse an exact case-insensitive name match within the same dimension; otherwise create the quality. Enforce that identity rule in the database, reject duplicate resolved qualities within one analysis, and do not infer semantic equivalence. Renaming/reclassifying shared qualities is out of scope.
- Expose domain operations to create/edit a draft for an existing Film and publish that draft. Model actions own lifecycle rules; orchestration loads fresh records and coordinates the transaction. No broad role guards or type switches.
- Store created_at, published_at, superseded_at and superseded_by_id on analyses. Publication resolves/creates qualities, persists final evidence-linked associations, publishes the draft and supersedes the previous active version at one timestamp in a transaction. A failure rolls back all new shared qualities and associations as well as lifecycle changes.
- Permit at most one editable draft and one active analysis per film, enforced by model validation and database constraints. Further authoring edits that draft rather than creating a competing revision. Film reuses its pending draft; when none exists it copies current published content and candidates before applying the supplied changes. Serialize preparation, edits and publication per film. Publication supersedes the current analysis; no stored predecessor or stale-baseline check is needed. Repeated publication is an explicit failure, not a successful no-op.
- Retain published analyses, their content, quality candidates and association sets unchanged. Supersession fields may change only through replacement publication. Start a fresh draft for content/candidate corrections; an unchanged quality set still belongs to the new analysis. Drafts never affect current knowledge.
- Provide current and as-of-time analysis selection using publication-inclusive/supersession-exclusive validity. Before first publication the result is absent. AnalysisQuality inherits validity from its analysis; shared qualities are never invalidated by one film's replacement.
- Validate required content, candidate identity/dimension and evidence references at publication; incomplete drafts may be saved. Publication requires at least one supported candidate and explicit recorded gaps, not proof that the entire film has been exhaustively analysed. This is structural validation and explicit approval, not automated truth verification.

## Scope restrictions

- Film knowledge owns all mutations. Do not change Ratings, Library, Recommendations or Identity implementations. No rating supersession migration, rating-quality computation, recommendation-quality snapshots or profile reassessment in this task.
- No events, new asynchronous domain communication, generic integration layer, AI/provider requests, prompts, jobs, source ingestion, TMDB changes, batch imports or 500-film expansion.
- No controllers, routes, browser UI, authorization/curator roles, multi-person verification, community contributions, expression feedback or podcast interface. Domain operations can be exercised in tests and Rails console; safe public access is a later task.
- No semantic quality matching, taxonomy management UI, global quality renaming/merging, separate quality-definition field or mandatory final taxonomy. Dimensions are managed in code, not editable content. No dimension or candidate tables.
- No edits to published content, historical deletion or individual association invalidation timestamps. Do not create a generic temporal persistence framework.
- New application validation/failure copy belongs in English locale entries. Never translate authored analysis or quality names.

## Acceptance criteria

- **AC1:** Editable drafts and candidate sets persist without changing active knowledge or creating shared qualities prematurely.
  Check: model/domain tests create, edit and replace candidate sets for an existing film; exercise incomplete content and candidate edits without requiring authorship classification or provider metadata. Verify active selection and shared vocabulary remain unchanged, and invalid Film references fail.
  Result: Passed. Draft tests cover incomplete content, JSON-array validation, candidate add/edit/remove/replacement, stale-object refresh and missing/deleted films. Film-owned editing tests verify copied published content/candidates, omitted-field preservation, explicit clearing and reuse of pending changes. No vocabulary or active knowledge is created before publication.
- **AC2:** Publication reuses existing qualities and creates new ones with traceable analysis associations atomically.
  Check: tests cover selected existing identity, normalized same-dimension name reuse, new quality creation, different dimensions, duplicate candidates, missing evidence and forced failure after partial writes. Confirm rollback preserves the prior analysis and vocabulary.
  Result: Passed. Tests cover explicit FilmQuality identities, case-insensitive same-dimension reuse, separate dimensions, invalid dimensions/references, duplicate resolution and rollback after both partial association writes and supersession. Plain value-object tests cover malformed content, candidate identities and evidence references. All seven dimension constants pass model/database validation and resolve localized labels.
- **AC3:** Replacement preserves historical evidence and exact validity boundaries.
  Check: publish an initial draft and replacement at controlled times; verify before/at/after selection, old content and associations, a pending draft, prose-only replacement and inability to edit published content or republish it.
  Result: Passed. Tests verify exact validity boundaries, pending and prose-only replacements, retained content/candidates/associations, immutable accepted versions and explicit repeat-publication/non-increasing-time failures. Local lifecycle actions reject publication without associations and invalid supersession targets.
- **AC4:** Each film has at most one editable draft and one active analysis, including under concurrency.
  Check: database-backed tests race two draft preparations, two publications of the same initial/replacement draft, shared-quality creation across different films, and candidate editing against publication. Verify explicit rejected outcomes, retained history and no partial associations or vocabulary writes. Check database uniqueness independently.
  Result: Passed. Six PostgreSQL concurrency tests verify one draft under concurrent preparation, exactly one successful initial/replacement publication, shared-quality identity resolution across films and candidate edits/direct association creation racing publication. An edit after publication starts a new draft; a direct association write to the published version is rejected. Independent schema tests verify one draft, one active analysis and vocabulary/association uniqueness.
- **AC5:** Implementation remains bounded and verified.
  Check: run focused model/domain tests, migrations against the test database including rollback/reapply where supported, application eager loading, full bin/ci and git diff --check. Inspect the diff for domain ownership, absence of AI/network/UI changes and localized validation errors. Record actual commands/results here.
  Result: Passed on 27 October 2026 after all owner-requested simplifications:
  - `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_analysis_test.rb test/models/film_analysis_concurrency_test.rb test/models/film_knowledge` — **32 tests / 207 assertions** (before adding two inheritance/clearing regression tests, subsequently covered by full CI), zero failures/errors/skips.
  - `RAILS_ENV=test bin/rails db:migrate:down VERSION=20261027130000` and `RAILS_ENV=test bin/rails db:migrate:up VERSION=20261027130000` — previous unmerged migration rolled back and the revised three-table migration with `published_at` applied successfully. Development migrations were not run.
  - `RAILS_ENV=test bin/rails zeitwerk:check` — passed, with the existing mailer-preview directory exclusion unchanged.
  - `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — **503 tests / 5,456 assertions**, zero failures/errors/skips; RuboCop, Bundler audit, Importmap audit and Brakeman passed.
  - `git diff --check` and local spec-link verification — passed. Diff inspection confirms Film knowledge ownership and no provider/UI/event/downstream implementation changes. Removed an unrelated PostgreSQL schema-rendering change to the existing Ratings constraint.

  Follow-up verification after extracting `FilmQuality.create_quality!`: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_analysis_test.rb test/models/film_analysis_concurrency_test.rb` passed **30 tests / 211 assertions**; `bin/rubocop app/models/film_quality.rb` passed. The same focused suite passed again after renaming the public method to `find_or_create!` and separating ID/name lookups (30 tests / 211 assertions); RuboCop passed for both the model and publication service. `find_or_create!` calls `create_quality!` only when `resolve_by_name` returns nil. Final full CI was rerun after all naming/refactoring changes: 503 tests / 5,456 assertions passed, with clean style and security checks.

  The earlier table-based implementation passed 492 tests / 5,373 assertions before owner review; the results above supersede that verification. No new server or paid API request was started.

## Approved responsibility separation

Film owns the client-facing editing and publishing operations. `FilmKnowledge::PublishAnalysis` coordinates publication internally using the film identity. `FilmKnowledge::AnalysisContent` and `FilmKnowledge::QualityCandidate` interpret the existing JSON. `FilmQuality.find_or_create!` is the explicit public lookup/creation entry point. Internal `resolve_by_id!` validates an existing selection, `resolve_by_name` only looks up a name/dimension match, and `create_quality!` creates when no match exists. Owner follow-up extracts `create_quality!` as an explicit internal creation method, keeping lookup separate and preserving recovery from concurrent creation of the same name/dimension. Verify existing creation, reuse, rollback and shared-quality race tests; no schema or API expansion. FilmAnalysis retains editing permissions, lifecycle actions, history and associations. Direct association writes still check current persisted state under the film lock.

## Owner review revision

The owner approved code-managed dimensions, the `FilmQuality` name and embedded `quality_candidates`, then removed origin and deferred authoring/run provenance. Each film has one editable draft; edits update it until publication. No predecessor reference or stale-baseline check is needed. Accepted history is retained through `superseded_by`. The unmerged migration is revised directly after rollback in the test database; no compatibility migration or historical-data backfill is needed.

## Implementation notes

Implemented on `codex/analysis-drafts-activation`. Models remain at Rails' top level: `FilmAnalysis`, `FilmQuality` and `AnalysisQuality`. All belong to Film knowledge. Existing `Film` gains the analysis association and editing and publishing actions. No other domain implementation changed.

### Domain operations

- `film.edit_analysis!(content:, quality_candidates:)` locks a freshly loaded film. It edits the pending draft, or creates one by copying current content and quality candidates and applying the supplied changes. With no existing analysis, omitted fields use empty defaults. Omitted fields on a revision are preserved; explicit empty values clear them. It returns the saved analysis. Clients do not select or create draft versions themselves. Missing/deleted films raise `ActiveRecord::RecordNotFound`.
- `film.publish_analysis!` delegates to internal `FilmKnowledge::PublishAnalysis.call(film_id:)`. Under the film lock, the coordinator selects pending changes, validates readiness, resolves shared qualities and creates evidence-linked associations. It supersedes current knowledge and publishes the pending analysis at one microsecond-precision timestamp in a single transaction. It returns the published analysis. Previously held instances must be reloaded to observe changes.
- FilmAnalysis internally owns `edit_draft!`, `publish!(at:)`, `supersede!(replacement:, at:)` and duplicate-association rejection in `add_quality!`. FilmQuality owns `find_or_create!(quality_candidate:)`. There is no separate candidate-replacement operation.
- Plain `FilmKnowledge::AnalysisContent` and `FilmKnowledge::QualityCandidate` objects own document/candidate validation without persistence. Candidate failures become localized analysis errors at the publication boundary.
- `film.film_analyses.current` selects current knowledge; `film.film_analyses.at(time)` selects historical knowledge. Both return an empty relation before first publication. Associations inherit their analysis's interval.

Invalid publication raises `ActiveRecord::RecordInvalid` with localized errors. Publishing with no pending changes raises `FilmKnowledge::NoUnpublishedAnalysis`; it does not silently succeed or create an empty draft. Editing/deleting/republishing accepted analyses or their candidates raises `FilmKnowledge::AnalysisNotEditable`. Accepted associations and shared vocabulary use Rails read-only records. A publication clock at or before the current analysis publication is rejected explicitly rather than backdated or allowed to produce an empty interval.

Draft actions, candidate edits and publication share a per-film database row lock. Separate partial unique indexes independently enforce one draft and one current analysis per film. The service transaction uses a savepoint to contain failures even when the caller already has a transaction. Association creation retains its own guard for direct writes: it locks the owning film and reads current analysis state without calling the draft-edit wrapper, reloading the caller's analysis or creating a per-association draft-edit savepoint. Shared-quality creation across films recovers only the known dimension/name unique-index conflict, returning the winning identity. It does not treat unrelated storage errors as success.

### Stored documents

`content` is a JSON object; `quality_candidates` is a JSON array of objects. Incomplete drafts can contain an empty object and array. The initial publication structure (`FilmKnowledge::AnalysisContent::FORMAT_VERSION`, currently 1) requires:

- `format_version`, nonblank `context` identifying the analysed cut/version and nonblank `synthesis`.
- Nonempty `narrative` and `moments` arrays. Each entry contains a unique `id`, nonblank `text` and nonempty `source_ids` referring to recorded sources. Narrative and moment IDs share one namespace within the analysis.
- Nonempty `sources`, each with a unique `id` and nonblank `reference`. Additional authorship, locator, independence, claim-status and revision metadata can remain in the document; no table-per-claim schema or automatic source verification is introduced.
- An explicit `gaps` array of nonblank strings; an empty array explicitly records no identified gaps. No narrative/moment count is prescribed.

Quality candidates provide either `film_quality_id` or a proposed `name` and `dimension`, plus nonempty `evidence_references` to narrative/moment IDs. An existing selection must not also propose a name or conflicting dimension. Publication rejects missing/dangling evidence and duplicates after resolution. Dimensions are the seven values defined by `FilmQuality::Dimensions`, validated in the model and database, with display labels in locales. Dimension changes are code changes and, when needed, explicit data migrations. No dimension content or pilot vocabulary is seeded. Proposed names are stripped and matched case-insensitively within their dimension.

Origin and separate authoring/run provenance are intentionally deferred. Source references remain in `content`; nothing here makes provider calls or verifies the truth of supplied evidence.

[The test content helper](../../test/support/film_analysis_helpers.rb) provides a small complete, constructed input; [lifecycle tests](../../test/models/film_analysis_test.rb) demonstrate domain calls and failures. Actual AI generation, curated content ingestion and UI remain deferred.

Owner approved implementation on 27 October 2026. Owner accepted the implementation and authorized PR creation and merge after CI on 27 October 2026. Merge pending.
