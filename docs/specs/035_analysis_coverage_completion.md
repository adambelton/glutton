# 035 — Make narrative coverage drive research completion

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Improve the managed research prompt's coverage planning and stopping rule after task 034 produced a selective narrative despite substantial source material and unused output allowance. Owner authorized this recommended improvement on 27 October 2026. Read the current plan, task 034 report, analysis evidence requirements, Film knowledge brief and generation protocol.

## Scope

- Update only managed development instructions to build the chronological account first, identify missing causal links, research those gaps and derive experiential synthesis/qualities after the account. Remain one combined operation, with the model directing its research.
- Make incomplete coverage a result of attempted investigation or actual budget/source limits, rather than treating an early gap list as sufficient completion. Direct attention to existing detailed source passages and targeted corroboration instead of collecting more general reviews. Keep unsupported details out.
- Preserve current two-source factual admission, screenplay/released-film distinction, source independence, substantive search-content acceptance, attribution, quality guidance and OpenSubtitles exclusion. No scene/source/word quota or new validator.
- Publish/retrieve one immutable development version with the same JSON contract, compare preserved instructions and record exact version/hash and source limitations in spec/protocol/plan.

## Scope restrictions

- Film knowledge prompt/documentation only. No application code, schema, model/budget changes, new phases/services, corpus/provider integration, production promotion, automatic publication or bulk/Batch execution.
- Preserve saved Alien/The Thing drafts and raw artifacts. Initial-only generation remains unchanged; no regeneration or paid evaluation is included in this prompt edit. A future sample is needed to assess whether coverage actually improves.
- Do not claim stronger model necessity or measured improvement from one observational diagnosis or prompt review. No runtime test claims for checks not run.

## Acceptance criteria

- **AC1:** Instructions make whole-account coverage and targeted gap investigation the completion objective.
  Check: inspect the exact prompt diff against task 034 observations; confirm chronology → causal gaps → targeted research → synthesis/qualities, with no fixed quota, output-format change or new gate.
  Result: Passed. The exact diff adds one COVERAGE AND COMPLETION section: construct the chronological account, identify causal gaps, consult existing detailed sources/targeted corroboration, then finalize synthesis/qualities. Important omitted connections require a reasonable targeted attempt or an actual source/budget limitation; the prompt does not require exhausting calls. No quota, output-shape change or gate was added.
- **AC2:** Existing behaviour is preserved and the managed development snapshot is verified.
  Check: compare unchanged instruction sections byte-for-byte, publish through Langfuse CLI and retrieve by exact version/development. Verify text/config/hash and development/latest labels without production promotion; prior v6 remains unchanged.
  Result: Passed. Published `film-analysis` v7 with contract `researched-analysis-v1`, SHA-256 `79a51106e540703d003b4f482c2289738e35ec7675701b285ee4f9376bb0fd19`. Exact version and development retrieval match proposed text/config/hash; development/latest labels, no production label. Removing the one new section reproduces v6 byte-for-byte, preserving every existing instruction. Application retrieval of historical v6 still matches its original SHA-256.
- **AC3:** Documentation and limits are explicit.
  Check: update protocol/plan, resolve local links and run `git diff --check`. No runtime suite or paid evaluation is required for this prompt/documentation-only change; state that live effectiveness is not yet measured.
  Result: Passed. Updated current protocol/version/hash and plan. Local Markdown link targets resolved and `git diff --check` passed. No application/runtime tests or paid evaluation were run for this prompt/documentation-only change. Live coverage improvement remains unmeasured; existing saved analyses and run artifacts were not modified.

## Implementation notes

Implemented one new managed coverage/completion section; no application code changed. Task 034 completed at 6,262 output tokens including 2,890 reasoning tokens, below its 16,000-token cap; eleven tool actions were recorded against a cap of twelve. These observations support investigating research organization and stopping behaviour, not a proven model limitation. Model remains the agreed `gpt-5.5-2026-04-23` for a future controlled comparison. Langfuse prompt engineering/version-control guidance applies.

Owner acceptance / merge: Pending.


## Reproducible evidence

Retrieve with `FilmKnowledge::AnalysisPrompt.call(version: 7)` and `.call(label: "development")` in `bin/rails runner`; verify the hash above and compare with the published snapshot. Local diagnostic files are `tmp/film_analysis_runs/task035-prompt-source.json`, `task035-prompt-proposal.json`, `task035-prompt-published.json` and `task035-prompt.diff`. These are historical evidence, not runtime prompt fallbacks. The CLI publication used `npx --yes langfuse-cli api prompts create --body-file ... --json`; no provider generation occurred.

Preparation asserted that removing the inserted section yields the complete original v6 text, and separately compared all evidence/screenplay/experience/subtitle/schema/quality instruction sections unchanged. Post-publication Rails retrieval compared exact version/development text/config/hash and rechecked historical v6. Current [Langfuse version-control documentation](https://langfuse.com/docs/prompt-management/features/prompt-version-control) was fetched before editing. Whitespace checks used `git diff --check`; local-link checks resolved Markdown targets relative to each changed document.

Ready for review. Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
