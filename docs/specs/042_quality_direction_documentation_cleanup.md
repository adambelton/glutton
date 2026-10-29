# 042 — Consolidate quality direction and remove obsolete LLM research

Status: Merged  
Owner: Film knowledge

Artifact disposition, 29 October 2026: this is a historical task record. Research filenames, commands and check results below describe work completed then; superseded tuning artifacts and replay scripts were intentionally removed in [task 050](050_jev_research_cleanup.md). Current inputs and reusable examples are in the [working baseline](../film_qualities/README.md); historical commands are not current reproduction instructions.

## Goal

Make the maintained documentation describe editable qualities/categories and the separation between source refresh, accepted film-quality changes and historical score records. Remove obsolete LLM testing documentation and plan one bounded category implementation task. Prerequisites: implementation plan, task template, product/architecture briefs, analysis requirements, scoring design, task 041 and current dimension usages inspected.

## Scope

- Delete obsolete generative-film-analysis experiment reports, generated pilot drafts, testing scripts and test-only task specs. Remove their links/results from maintained docs. Keep historical implementation specs as records of delivered code, and keep current vocabulary/JEV materials; JEV is the chosen engine, not the rejected generative research approach.
- Consolidate current requirements in film-quality documentation, preserving preference relevance, cap 20, evidence boundaries and domain ownership. Replace the obsolete analysis-dossier requirements as the current reference.
- Document editable categories and create a separate Draft implementation task to replace hard-coded dimensions, with migration/identity checks and explicit exclusions. Do not implement it.
- Record JEV question granularity separately from request packing; discuss one-by-one, batched and whole-list options without deciding a production batch size or making calls.
- Record Wikipedia/source refresh as independent from accepted film-quality changes. The latter is the proposed downstream reassessment trigger; no automatic scoring from article edits. Preserve historical rating/recommendation quality contributions. Independent FilmAnalysis/association history remains a design question, not a requirement or an authorised deletion of models/data.

## Scope restrictions

- Documentation and obsolete research cleanup only. No production source/schema/tests, live provider runs, remote prompt/trace changes, credentials, database writes, ignored raw artifacts, deployment or merge. Preserve .agents/ and .obsidian/.
- Do not invent downstream event contracts or implement Ratings/Recommendations changes. Historical score records belong to those domains. Category work must not absorb unsettled model removal or JEV integration.
- Remove research documentation explicitly requested by the owner, without erasing delivered implementation history or unrelated requirements.

## Acceptance criteria

- **AC1:** Obsolete LLM research is removed and maintained links resolve.  
  Check: explicit deletion manifest, repository reference search, Markdown local-link validation, whitespace and diff review.  
  Result: Passed. Removed 71 obsolete files: six former research directories (analysis_pilot, comparison_pilot, generated_analysis_verification, source_seed_experiment, quality_only_experiment, and obsolete candidate-review jev_quality_feasibility); nine test-only specs (026, 027, 030, 032, 033, 036, 037, 038, 039); and the superseded analysis-requirements document. Preserved three attributed Wikipedia exports under current JEV sources/, current master-vocabulary/JEV artifacts, installed skill and historical implementation specs. Condensed the legacy prompt/configuration docs and task 034 to existing implementation facts. Full README/docs local-link and heading-anchor check passed: 371 targets, zero failures. git diff --check passed.
- **AC2:** Current requirements distinguish source refresh, quality acceptance and historical scoring.  
  Check: inspect product/architecture/scoring/quality docs for consistent triggers, editable categories, open model-retention decision and domain ownership. No unapproved model removal or historical score reconstruction requirement.  
  Result: Passed. Replaced the former dossier document with film_quality_requirements.md; updated product, architecture, scoring, evolution and plan docs. Manually reviewed source-refresh versus accepted-change triggers, preserved historical score contributions, editable categories, open JEV request packing and open independent analysis/history retention. Current dimensions and analysis models explicitly remain implemented. Tracked diff contains only documentation and the pre-existing AGENTS.md change; no production/schema/test files changed. Offline current-JEV inspector passed (including frozen inputs, complete results, source references, cap, relevance audit and 70 unchanged prior raw JSON artifacts). No live provider requests or remote changes.
- **AC3:** One independently verifiable category implementation task is planned.  
  Check: Draft task specifies category records, migration preserving identities/associations, integration constraints and meaningful tests; excludes model-removal/scoring/JEV-request decisions. Plan links it without claiming implementation.  
  Result: Passed. Task 043 is Draft/planned only: category persistence, migration preserving IDs/associations/drafts, collision/removal/freshness failures, candidate/publication/schema integration and meaningful verification are specified. It excludes model removal, source refresh, JEV integration, scoring, cross-domain events and browser UI. The legacy managed-generator compatibility decision is explicit before implementation. The plan links 043 without treating planning as implementation authorisation.

## Implementation notes

Completed documentation cleanup and planning. Retained implementation specs are labelled historical, including prior fixed-dimension decisions; they do not override current requirements. No schema or model removal is implied by the discussion of historical scores.

Verification actually run:
- `python3 docs/research/master_quality_vocabulary/inspect.py` — passed offline after updating source-export links.
- Python local-link checker across README.md and docs/**/*.md — resolves relative paths, explicit IDs and heading anchors; 371 passed, zero failures.
- Explicit deletion-manifest check — all 71 removed paths absent; all three relocated current source exports present. Manifest of this run is in ignored tmp/documentation-cleanup-042.json.
- `git diff --name-only`/status review — no production source, schema or tests changed; pre-existing skill/AGENTS work preserved.
- `git diff --check` — passed. Runtime test suite not run for this documentation-only task.

Scope interpretation: obsolete LLM-generated-film research and obsolete candidate-review experiments were removed; current JEV definition/matching research remains useful and was retained. Existing remote traces, managed prompts, ignored raw artifacts, credentials and database records were untouched. Task 043 remains unimplemented and its tests are Not run.

Owner acceptance / merge: Current retained deliverables authorised and merged via [PR #45](https://github.com/adambelton/glutton/pull/45) on 29 October 2026 after CI. Historical research judgments retain their stated review/accuracy limits.
