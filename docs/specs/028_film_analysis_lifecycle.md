# 028 — Persist film analysis drafts and activate quality associations

Status: Draft  
Owner: Film knowledge

## Goal

An existing catalogue film can have an editable analysis draft and quality candidates, then atomically activate them as its current knowledge while preserving previous analyses and associations. Human and AI authors use the same persistence lifecycle. This task supplies domain operations and storage, not an authoring interface or AI integration.

Prerequisites: existing Film catalogue persistence and the agreed [V1 workflow](../film_analysis_requirements.md#v1-draft-and-quality-workflow). The completed pilots inform content examples; production activation does not require another pilot. No new cross-domain behavioural contract is consumed.

## Scope

- Persist FilmAnalysis belonging to Film, with authored narrative/evidence content, explicit source references and gaps, and minimal authoring provenance distinguishing human/AI origin without STI. Use a simple structured document for analysis content; do not build a table per claim or a generic schema engine.
- Persist editable quality candidates belonging to a draft, including a self-explanatory proposed name or selected existing quality, dimension and evidence references into that analysis. Support manual add/edit/remove and replacing a draft's candidate set with supplied candidates. Actual AI generation is deferred; future generation follows the separately documented [OpenAI API prompt/run protocol](../prompts/film_analysis/README.md).
- Persist shared Quality and quality dimensions within Film knowledge, plus AnalysisQuality associations belonging to an activated FilmAnalysis. Qualities can occur in multiple analyses/films. Do not require a separate definition field or seed the pilot vocabulary as accepted facts.
- Resolve explicitly selected existing qualities by identity. For new proposals, trim names and reuse an exact case-insensitive name match within the same dimension; otherwise create the quality. Enforce that identity rule in the database, reject duplicate resolved qualities within one analysis, and do not infer semantic equivalence. Renaming/reclassifying shared qualities is out of scope.
- Expose domain operations to create/edit a draft for an existing Film and activate that draft. Model actions own lifecycle rules; orchestration loads fresh records and coordinates the transaction. No broad role guards or type switches.
- Store created_at, activated_at, superseded_at and superseded_by_id on analyses. Activation resolves/creates qualities, persists final evidence-linked associations, activates the draft and supersedes the previous active version at one timestamp in a transaction. A failure rolls back all new shared qualities and associations as well as lifecycle changes.
- Capture the active predecessor when preparing a replacement draft. Activation must fail explicitly if that predecessor has changed, rather than letting a stale competing draft supersede newer work. Serialize activation per film; enforce at most one active analysis through a database constraint. Repeated activation is an explicit failure, not a successful no-op.
- Retain activated analyses, their content, provenance and association sets unchanged. Supersession fields may change only through replacement activation. Start a fresh draft for content/candidate corrections; an unchanged quality set still belongs to the new analysis. Drafts never affect current knowledge.
- Provide current and as-of-time analysis selection using activation-inclusive/supersession-exclusive validity. Before first activation the result is absent. AnalysisQuality inherits validity from its analysis; shared qualities are never invalidated by one film's replacement.
- Validate required content, candidate identity/dimension and evidence references at activation; incomplete drafts may be saved. Activation requires at least one supported candidate and explicit recorded gaps, not proof that the entire film has been exhaustively analysed. This is structural validation and explicit approval, not automated truth verification.

## Scope restrictions

- Film knowledge owns all mutations. Do not change Ratings, Library, Recommendations or Identity implementations. No rating supersession migration, rating-quality computation, recommendation-quality snapshots or profile reassessment in this task.
- No events, new asynchronous domain communication, generic integration layer, AI/provider requests, prompts, jobs, source ingestion, TMDB changes, batch imports or 500-film expansion.
- No controllers, routes, browser UI, authorization/curator roles, multi-person verification, community contributions, expression feedback or podcast interface. Domain operations can be exercised in tests and Rails console; safe public access is a later task.
- No semantic quality matching, taxonomy management UI, global quality renaming/merging, separate quality-definition field or mandatory final taxonomy. Dimensions are simple reusable records, not a classification framework.
- No edits to activated content, historical deletion or individual association invalidation timestamps. Do not create a generic temporal persistence framework.
- New application validation/failure copy belongs in English locale entries. Never translate authored analysis or quality names.

## Acceptance criteria

- **AC1:** Editable drafts and candidate sets persist without changing active knowledge or creating shared qualities prematurely.
  Check: model/domain tests create, edit and replace candidate sets for an existing film; exercise both authoring origins. Verify active selection and shared vocabulary remain unchanged, and invalid Film references fail.
  Result: Not run.
- **AC2:** Activation reuses existing qualities and creates new ones with traceable analysis associations atomically.
  Check: tests cover selected existing identity, normalized same-dimension name reuse, new quality creation, different dimensions, duplicate candidates, missing evidence and forced failure after partial writes. Confirm rollback preserves the prior analysis and vocabulary.
  Result: Not run.
- **AC3:** Replacement preserves historical evidence and exact validity boundaries.
  Check: activate an initial draft and replacement at controlled times; verify before/at/after selection, old content and associations, a pending draft, prose-only replacement and inability to edit activated content or reactivate it.
  Result: Not run.
- **AC4:** Concurrent/stale activation cannot publish two active versions or silently replace unexpected work.
  Check: meaningful database-backed concurrency tests exercise two drafts based on the same predecessor (including first activation), one accepted outcome and one explicit stale failure; test shared-quality uniqueness across different films and schema constraints. Verify no orphaned partial associations or vocabulary writes.
  Result: Not run.
- **AC5:** Implementation remains bounded and verified.
  Check: run focused model/domain tests, migrations against the test database including rollback/reapply where supported, application eager loading, full bin/ci and git diff --check. Inspect the diff for domain ownership, absence of AI/network/UI changes and localized validation errors. Record actual commands/results here.
  Result: Not run.

## Implementation notes

Not implemented. Candidate generation means accepting/editing supplied candidates in this task; an automated generator can use the same draft lifecycle later. Exact model/service filenames and content document shape should follow the existing Rails conventions without a generic abstraction.

Owner acceptance / merge: Pending. Spec preparation does not authorize implementation.
