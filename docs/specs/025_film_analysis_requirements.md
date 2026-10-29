# 025 — Define film analysis requirements and evidence standards

Historical implementation/design record. Current direction is in [film-quality requirements](../film_quality_requirements.md); fixed dimensions are superseded by planned task 043, and independent analysis-model retention is under review. Removed experiment reports are not prerequisites or active product requirements.


Status: Merged via PR #40  
Owner: Film knowledge / analysis design

## Goal

Define the content and evidential standard for a maintained film analysis before selecting enrichment sources or implementing the analysis pipeline. Deliver docs/film_quality_requirements.md and align the briefs/plan. This supersedes the unimplemented quality-vocabulary persistence proposal.

Prerequisites: existing TMDB identity import (008), product/architecture film-analysis sections and the agreed Ratings scoring design. The intended 500-film catalogue will inform shared qualities after a future pipeline is validated on a smaller sample.

## Scope

- Define analysis coverage, completeness and gaps, with a provisional experiential structure and a usefulness rubric for derived qualities; shared terminology does not require one-to-one categories.
- Define observations, reported experiences, reported facts and interpretations; claim-level provenance, corroboration, complementary evidence, source independence, conflicts and provisional single-source information.
- Provide a source-use evaluation matrix for later source selection, including scripts/subtitles as research inputs; distinguish original synthesis from reuse of source material.
- Record future community/curator revisions and independent verification of the exact proposed change, leaving one-versus-two reviewers unresolved.
- Define future format/content/vocabulary evolution and downstream reassessment requirements while preserving raw user evidence; identify unresolved processing policies without designing cross-domain implementation.
- Record the future analysis → qualities → discovery → user expressions → reviewed analysis cycle, including provenance, feedback independence and deferred contribution policies.
- Provide a review rubric and constructed examples exercising evidence edge cases.
- Align the product brief, architecture brief and implementation plan with analysis-first sequencing and the intended 500-film catalogue. Preserve the exploratory status of existing research data.

## Scope restrictions

- Documentation only, owned by Film knowledge. No runtime code, migrations, models, schema, API calls to acquire film data, seeding, AI processing, jobs, UI or deployment.
- No quality persistence, fixed taxonomy, film-association implementation, scoring, profiles or changes to another domain implementation. Downstream impacts are requirements only, not new mutation or communication contracts.
- Do not select providers or claim their actual coverage, approve particular source licences, import scripts/subtitles or commit to paid services.
- No community moderation implementation or final reviewer-count policy. No table-per-claim or generic integration architecture is prescribed.
- No mechanism for user-expression feedback: no expression ingestion, domain communication contract, jobs, consent UI or automated analysis/preference updates. Eligibility, attribution and withdrawal/retention policies remain open.
- A real-film pilot and its acceptance evidence require a separately scoped task. Constructed examples must not be described as empirical validation.

## Acceptance criteria

- **AC1:** Requirements explain what a complete analysis tells us and organise it experientially while assessing qualities for recommendation usefulness.
  Check: review the coverage table, supporting identity/provenance information, significant sequences, unknown-versus-absent rule and film-derived quality sequencing against owner decisions.
  Result: Passed — documentation review on 27 October 2026; seven provisional experiential dimensions plus supporting information, concrete sequence evidence and explicit coverage gaps are defined. Technical execution is supporting evidence rather than an automatic quality. The quality rubric covers preference relevance, transferability, discrimination and reliable identification. The 500-film goal and small-pilot-first sequencing are recorded. Final review also records violence primarily under Intensity and explicitness while preserving its distinct emotional, tonal, relational and rhythmic aspects.
- **AC2:** Evidence standards distinguish support from source count and enable meaningful independent review.
  Check: walk through script/review corroboration, complementary detail, copied-source dependence, conflicting cuts, interpretations, missing evidence and cross-dimension scenes.
  Result: Passed — constructed examples in the requirements document exercise these cases. Claim-level provenance, provisional single-source claims and future independent revision review are defined. Reported fear/disgust and contrasting amusement are evidence of individual experiences, not audience prevalence. No real-film/source-coverage evaluation was performed within task 025; the separately authorised task 026 now supplies a bounded pilot and records its limits.
- **AC3:** Docs provide a source-use framework and consistent scope without implementing the pipeline.
  Check: inspect changed-file scope, internal Markdown links and references to the replaced task path; run git diff --check. Confirm application/database files are unchanged.
  Result: Passed — git diff --check passed on 27 October 2026. A Python check resolved every relative Markdown link in the requirements, spec, briefs and plan; no broken links or links to the superseded vocabulary spec remain. Final verification checked local heading anchors as well as file targets. git status --short confirms documentation-only changes. Existing task 023b merge documentation was preserved. No runtime tests were run because no application code changed.

- **AC4:** Format evolution preserves original user evidence and defines when downstream interpretation needs reassessment.
  Check: review rename-only, added-dimension, corrected-association, quality-split, stale-assessment and explicit-evidence reinterpretation scenarios against the existing scoring design.
  Result: Passed — documentation review on 27 October 2026. Requirements distinguish format/content/vocabulary/assessment versions, retain raw ratings/expressions, require compatible completed results and prevent obsolete or duplicate contributions. Profile-only changes remain distinct from evidence/definition changes. Six constructed scenarios are documented; no recomputation was implemented or tested. Processing contracts and stale-result presentation remain open.

- **AC5:** The future expression-feedback cycle is clear without implying its mechanism exists or treating derived conclusions as fresh evidence.
  Check: trace a contrasting scene response through proposal/review, repeat processing of one contribution, accepted association changes and withdrawn/replaced evidence.
  Result: Passed — documentation review on 27 October 2026. Four constructed scenarios describe the cycle and its boundaries. Original expressions remain Ratings-owned; Film knowledge owns analysis amendments. Independent review, source identity, selection/prompt bias, non-duplication and unresolved contribution/privacy/retention policies are explicit. No feedback mechanism or runtime validation was implemented.

## Pilot follow-up

Task 026 (obsolete research removed) tests these requirements on the five owner-selected films. Its findings add phase scope, separated content/response evidence, claim-level support and explicit gap-resolution requirements. Owner review of the initial pilot found inadequate depth; its approved revision now requires chronological narrative and contextual key moments before conclusions, reflected in the requirements and product brief. A completed documentation check does not validate the analysis standard empirically; the pilot and resulting revisions require owner review. No independent curator acceptance or predictive evaluation has occurred.

## Subsequent comparison and lifecycle decisions

Task [026a](026a_comparison_and_history_design.md) records the podcast's three layers, viewer-independent evidence references, preserved analysis/film-quality versions, analysis-only activation and immediate ratings with timestamped supersession. Quality names are self-explanatory; no definition field is required. Task 027 (obsolete research removed) scopes a new pilot against those requirements. These are later requirements, not retroactive claims that task 025 implemented them or task 026 tested them.

## Implementation notes

Documentation authored at the owner's request on 27 October 2026. Owner approved the spec and requested execution on the same date; the documentation deliverable has been finalised and checked. The previous Quality model/key proposal is superseded, not implemented. Experiential dimensions are proposed research organisation, not committed schema or quality values. The owner-requested evolution discussion records future downstream requirements without expanding this documentation task into other domains’ implementation. The real-film pilot is separately delivered in task 026. Production provider evaluation, pipeline implementation, community workflows and user-expression feedback mechanisms remain future tasks.

Spec approval: Owner approved on 27 October 2026.

Owner acceptance of final deliverable / merge: Pending. No pipeline implementation or real-film pilot is included in this task.

Merge record: owner authorised merge after CI; merged via [PR #40](https://github.com/adambelton/glutton/pull/40) on 27 October 2026 at 11:58:21 UTC after hosted checks passed on `46873e53c51a1aed48551f63d65dc09e384bbfce`. Earlier status/evidence above describes the pre-merge deliverable. Research acceptance does not assert production accuracy or independent curator verification.
