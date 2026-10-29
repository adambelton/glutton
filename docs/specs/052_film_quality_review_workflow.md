# 052 — Clarify initial catalogue enrichment and admin quality improvement

Status: Ready for review  
Owner: Film knowledge

## Goal

Revise the release-scope proposal after the owner's 29 October clarification: import TMDB films, enrich with maintained Wikipedia context, assign at most 20 qualities, and improve the system through admin tools. Community editing is deferred. One documentation outcome; no runtime implementation.

Prerequisites: [implementation plan](../implementation_plan.md), [product brief](../product_brief.md), [current requirements](../film_quality_requirements.md), retained [baseline](../film_qualities/README.md) and [category task 043](043_editable_quality_categories.md).

## Scope

- Replace the contributor/publisher proposal with initial bulk seed and user-requested TMDB import using the same enrichment/assignment path. Support admin manual TMDB/Wikipedia syncing followed by a quality comparison; keep applying associations separate. Periodic syncing remains the preferred background direction, with cadence/check policy undecided.
- Define three admin-only surfaces: quality library with immutable quality names and definition tuning; canonical film library with manual quality additions/removals; expression-led investigation of missing vocabulary or associations and definition/matching failures.
- Distinguish new concepts from tuning an existing meaning, category preference from category weights, and exploratory tests from production changes. Preserve equal base treatment, max 20 and historical scoring requirements.
- Update current requirements, relevant product-brief sections and implementation plan consistently. Keep the retained Tumbbad example as optional evidence of manual diagnosis, not a required publication process or automated selection policy.
- Identify the bounded next implementation decisions, including initial automated selection, source gaps, sync cadence, storage/legacy models and admin access. Read-only inspection of Ratings evidence does not transfer ownership.

## Scope restrictions

- Documentation only: no models, migrations, UI, imports, syncing, new JEV requests, prompt changes, experiments, live dataset writes, paid services or deployment.
- No public editing, contributor submission, moderator approval, reputation or mandatory per-film human publishing workflow in the initial release.
- Do not change the retained vocabulary/definitions/probabilities/source packets, expand task 043, implement scoring or invent event contracts. Separate owned publisher/subscriber tasks require agreed contracts first.
- Preserve original user expressions and historical contribution records. No automatic new vocabulary, film-association edits or user-profile mutation from a discovery suggestion/test. No bulk expression export or new admin entitlement is implemented here.
- Preserve unrelated local post-merge work and ignored workspace state. Owner product direction is recorded; detailed proposals and implementation remain reviewable separately.

## Acceptance criteria

- **AC1:** Release scope reflects seed and on-demand enrichment, with periodic source syncing and manual sync followed by quality comparison.  
  Check: follow seed import, user-selected missing film, duplicate import, missing source and metadata/plot refresh, manual sync with unchanged/changed candidate sets, failed checks and stale comparison results; neither a check nor a retry silently overwrites admin associations or triggers rescoring. Automatic initial max-20 selection remains an explicit implementation decision, not mandatory manual review.  
  Result: Passed — manually walked the revised catalogue lifecycle for bulk seed, user-selected TMDB import, reuse of an existing identity, missing/ambiguous Wikipedia context and subsequent source refresh. Same pipeline is required for seed/on-demand work; incomplete enrichment is visible. Initial selection is a system operation with policy still undecided, not mandatory per-film admin approval. Retry/refresh preservation of admin corrections is explicit. Additional manual walkthrough after the owner's sync clarification: manual TMDB/Wikipedia/both sync runs a quality comparison even with unchanged source content; same-set, changed-set, successful-sync/failed-check and stale-input outcomes remain separate. Differences require explicit admin application and unchanged checks do not rescore.
- **AC2:** Admin interfaces and quality evolution are explicit.  
  Check: inspect all three surfaces, immutable quality names, bounded definition tuning, associated-film visibility and manual add/remove; distinguish new meaning, category grouping and preference weighting. Ordinary users can request imports but cannot use admin editors.  
  Result: Passed — the proposal and current requirements specify the quality library, canonical film editor and expression investigation/testing as admin-only, while ordinary users may search/request missing-film imports. Names are immutable; same-concept tuning and category regrouping are distinct from new concept creation or scoring weights. The superseded contributor/publisher workflow has been removed. The retained 17-quality example is optional admin diagnosis, not an import gate.
- **AC3:** Expression-led discovery supports investigation without automatic product mutations.  
  Check: walk missing vocabulary, missing film association, weak definition/matching, category-level preference and insufficient evidence; retain quoted expression/film context and before/after tests, with separately explicit admin actions and domain ownership.  
  Result: Passed — manually walked all five investigation findings: existing quality with missing film association; weak definition/matching; missing concept; category-level preference; uncertain/contextual evidence. Each leads to inspection/test or explicit admin action, not automatic mutation. Before/after comparisons include negative and untouched examples. Ratings evidence remains read-only for Film knowledge, with access/minimal-context policy required before implementation. No live dataset or provider work performed.
- **AC4:** Documentation is consistent, bounded and verified.  
  Check: current requirements/brief/plan no longer put imports after release or prescribe community publishing; validate local links/whitespace and confirm no production/data-baseline changes. Preserve the worked example without accepting its assignments.  
  Result: Passed — product brief, requirements and plan now place user imports/admin improvement in initial-release scope and defer community editing. `python3 /tmp/glutton-052-check.py` passed: 194 local links/anchors across 12 changed Markdown files, whitespace including untracked documents, 17 unique canonical example IDs with unchanged probabilities/paragraph references, all 6 protected baseline/category files and 7 unrelated local diffs unchanged. `git diff --check` passed; production diff empty. No runtime tests, new CI, database writes or paid/model calls for this documentation-only revision.

## Implementation notes

Owner clarified scope on 29 October 2026 after reviewing the previous proposal. The previous Ready-for-review result covered a contributor/publisher design that is now superseded; its verification record is not evidence for this revised scope. Revised the proposal, current requirements, relevant product-brief sections and plan. No application implementation authorised by this task. The retained example was reframed for admin diagnosis without changing its IDs, source references or probabilities. No changes to task 043 or the retained baseline data. Follow-up owner clarification adds manual syncing with a follow-up quality comparison; applying differences remains explicit. Scheduled quality-check policy is still open. Re-ran the recorded document/preservation checker and whitespace checks after this change; both passed with the same 194 local links.

Verification: run `python3 /tmp/glutton-052-check.py` and `git diff --check`. The temporary checker uses `/tmp/glutton-052-before.json` for baseline hashes and prior local-diff preservation. Reproduce manually by resolving local Markdown links/heading anchors in changed files, comparing the example table to Tumbbad in `examples.json` and `vocabulary.json`, and walking the cases recorded under AC1–AC3. Temporary scripts/snapshots are session aids, not project dependencies.

Remaining decisions: initial automated selection and insufficient-context outcomes, storage/legacy-model role, provider-specific sync policy, admin access to expression evidence and bounded test execution. These are implementation-spec decisions, not an approved community publishing process. No user-testing, selection-accuracy or bulk-cost claim is made.

Owner acceptance / merge: Pending for revised proposal details; release direction supplied by owner.
