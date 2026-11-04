# Inspect the canonical catalogue as a superuser

Status: Draft — deferred until remaining domain model namespaces are complete  
Owner: Registry (following the pending Registry rename)

## Goal

Let an internal superuser inspect existing canonical films, quality categories and qualities, and navigate their current associations. This is one read-only catalogue inspection experience, distinct from the personal Library. Prerequisites: the completed Registry namespace and remaining separately owned model-namespace migrations, existing `Registry::Film`/`Registry::QualityCategory`/`Registry::Quality`/`Registry::FilmQuality` storage and Identity's persisted `superuser?` state. Follow the [implementation plan](../implementation_plan.md), [catalogue requirements](../film_quality_requirements.md) and [workflow direction](../film_quality_review_workflow.md).

## Scope

- Add Registry-owned list/detail routes, controllers and views for films, quality categories and qualities, using existing Rails/Hotwire conventions and simple shared layout/navigation. Provide a discoverable catalogue entry for superusers without adding an unfinished primary product destination.
- Authorize every catalogue route using the fresh session-bound identity and `superuser?`. Signed-out, ordinary registered, guest, expired guest and deleted identities must not see catalogue content, including direct detail URLs. Preserve existing Identity expiry/deleted-session handling. Revocation must deny the same signed-in browser on its next request. This is Registry's feature authorization; do not add Identity mutations or a generic permissions framework.
- Films: show stored title/release date and provider identifiers, relevant stored TMDB metadata, Wikipedia source context with page/revision/attribution links, and accepted qualities grouped by category. Show missing source context or an empty accepted set honestly without treating absence as a completed successful assignment. Plot/context is spoiler-bearing and labelled accordingly.
- Categories: show persisted name, maximum and weight, and their qualities. Qualities: show immutable name, category, matching definition/exclusions and currently associated films. Link film -> quality -> category and category/quality -> associated records. Use current associations as authoritative state; do not infer membership from evaluation candidates.
- Show available provenance for accepted associations (linked evaluation and its recorded support/source paragraph references where present) as read-only context. Distinguish absent provenance from a negative judgment. Reuse stored evaluation/source data; do not add evaluation execution, a separate evaluation browser or a raw provider/log export.
- Keep lists and associated-record browsing bounded with deterministic pagination/order. Handle empty catalogues, missing optional fields and missing records explicitly. Render stored text escaped and keep source attribution with source content. All application-authored UI copy belongs in English Rails locale files; preserve existing strict missing-translation configuration.

## Scope restrictions

- Registry only: read Identity's authoritative state without changing users, sessions or privilege lifecycle. Do not mutate Library, Ratings or Recommendations or expose viewer expressions. Shared reads do not require an event projection or new contract.
- No editing, import/search UI, film loading, source refresh, reassessment, suggested-change application, bulk execution, provider calls, seed execution or paid budget. No Registry model mutations, automatic repair, schema additions, event publishing or background work is required for viewing.
- Do not implement account deletion, public privileged roles, privilege-management screens, broad primary-navigation redesign, deployment or scheduling. No live superuser grant or database bootstrap is performed by this task.
- Reuse existing persisted data and associations. Do not invent a generic admin framework or speculative authorization service. If stored evidence cannot support a proposed display, narrow it and update this record before changing scope.

## Acceptance criteria

- **AC1:** All catalogue endpoints enforce superuser access without exposing records to other identities.  
  Check: integration coverage for signed-out, ordinary registered, active/expired guest and deleted identities, direct detail requests and next-request revocation in the same signed-in browser; authorized superusers can reach every list/detail. Verify existing inactive/deleted browser handling remains intact.  
  Result: Not run.
- **AC2:** Existing films, categories and qualities are inspectable with consistent association navigation and honest source/evidence states.  
  Check: representative persisted fixtures for sourced/unsourced films, films with/without accepted qualities, optional evidence, category settings, definitions/exclusions and related-record links. Verify source attribution, escaped stored content, spoiler labelling, empty lists and missing records. Do not assert speculative evaluation conclusions.  
  Result: Not run.
- **AC3:** Browsing is bounded, usable and read-only.  
  Check: deterministic pagination on lists and large associated-record sets; request/browser checks showing navigation makes no domain writes or provider requests. Verify responsive narrow/desktop layouts, accessible labels/focus and strict locale resolution. Exercise existing domain actions for fixtures when testing implemented mutations; constructor fixtures and explicit storage-contract tests retain their existing rules.  
  Result: Not run.
- **AC4:** Verification and maintained documentation match the final feature.  
  Check: focused integration/rendering tests, `PARALLEL_WORKERS=1 bin/ci`, `bin/rails zeitwerk:check`, `git diff --check` and proportionate visual checks. Record actual results and material limits. Mark Ready for review before PR preparation; update maintained progress and transfer this record into the PR description, removing it from the PR.  
  Result: Not run.

## Implementation notes

Not implemented. This record prepares the follow-on Registry inspection outcome only; implementation, provider expenditure, account changes, external communication and deployment are not authorized by preparing it.

Review handoff: Pending scope approval. Keep this record for implementation/review corrections; do not create separate review, CI or publication tasks for the same outcome.
