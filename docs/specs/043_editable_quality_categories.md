# 043 — Replace hard-coded dimensions with editable quality categories

Status: Draft — planned, not started  
Owner: Film knowledge

## Goal

Allow quality categories to be added, renamed and used without a deployment, while preserving existing quality identities and current association behaviour. Prerequisites: task 042, current product/quality requirements, task 028 implementation and current model/schema/candidate usages. Independent of the unresolved decision to retain or replace FilmAnalysis.

## Scope

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
- No category-management browser UI, multi-category membership, category-specific scoring or subclass hierarchy. Revisit only when concrete behaviour requires it.
- Preserve .obsidian/, unrelated work, current lifecycle invariants and user evidence. No deployment/merge automatically.

## Acceptance criteria

- **AC1:** An arbitrary new category can be created and used without code/schema/configuration changes.  
  Check: meaningful model/publication test creates a category absent from the original seven, creates/assigns a quality and reads it back; missing category fails at model and database boundaries.  
  Result: Not run.
- **AC2:** Migration preserves existing identities, associations and usable saved drafts.  
  Check: migration verification with representative old dimensions/drafts; compare quality IDs/names and association targets before/after. Exercise rollback or document its explicit data limits once new categories exist.  
  Result: Not run.
- **AC3:** Grouping edits are safe and independent of scoring.  
  Check: category rename, quality move, same-category name collision, stale/missing target and removal-while-in-use tests assert observable persistence outcomes. No duplicate/merged quality and no cross-domain writes/events.  
  Result: Not run.
- **AC4:** Existing Film knowledge entry points use categories consistently.  
  Check: focused candidate/publication/serialization/schema tests, locale checks, migration checks, full required CI and eager loading. No active fixed dimension enum or hidden seven-category fallback. Record managed-prompt compatibility decision before implementation.  
  Result: Not run.

## Implementation notes

Not implemented. Before starting, confirm whether the current legacy generator remains enabled or is retired in its own task; category integration must not expand into redesigning that pipeline. The task remains Draft until those bounded compatibility details are resolved.

Owner acceptance / merge: Pending.
