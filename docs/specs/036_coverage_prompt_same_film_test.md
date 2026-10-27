# 036 — Test coverage prompt on the same film

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Evaluate prompt v7 on The Thing using the previous request's exact input and settings, then compare narrative coverage and evidence support with v6. Owner authorized testing the same movie and boundaries on 27 October 2026. Prerequisites: tasks 034/035, current generation protocol and Film knowledge evidence requirements.

## Scope

- One paid synchronous evaluation request with `gpt-5.5-2026-04-23`, max output 16,000 tokens, max tool calls 12, timeout 180 seconds and zero retries. Use the exact request/input/schema from task 034 and change only instructions to the verified managed v7 text/hash `79a51106e540703d003b4f482c2289738e35ec7675701b285ee4f9376bb0fd19`.
- The Thing already has analysis 2. Run a one-off evaluation through the configured client without calling Film generation/save or bypassing its initial-only rule. Preserve the raw UUID artifact, prompt snapshot, settings, original response/status/usage, tool history and trace. Validate the returned document with current generated-document validation, but do not apply it.
- Trace root/generation/validation and reconcile actual remote observations using the Langfuse CLI. Compare original narrative flow, omitted causal links, screenplay/finished-film corroboration, candidate derivation, resource use and cost against task 034. Treat it as one observational comparison, not proof of a prompt effect.
- Record reproducible commands and results in a report and update the plan/spec. Verify existing analyses/counts and artifact hashes remain unchanged.

## Scope restrictions

- Film knowledge evaluation only. No application code, schema, prompt change/tuning, model/budget change, extra validator, source integration, corpus download, publication, regeneration, Batch/bulk execution or downstream mutations.
- At most one billable request. Failure is retained without retry. Source standards and OpenSubtitles exclusion remain unchanged; no manual evidence packet is prepared.
- Do not hold a database transaction across provider work. No temporary deletion, replacement or reclassification of the existing analysis to force eligibility.

## Acceptance criteria

- **AC1:** One request tests v7 with identical input/settings and no saved-draft mutation.
  Check: exact request equality except instructions; record before/after content hashes/counts and original artifact hash. Preserve raw response and actual validation outcome.
  Result: Passed. One evaluation completed and passed document validation. Exact request equality excluding instructions passed; v7 hash verified before spending. Saved-analysis document/publication/supersession hashes and counts remain unchanged (2/0/0), and the prior v6 artifact hash is unchanged. New response exists only in UUID evaluation artifact `6325be66-097b-4561-a55f-0d657e664be6.json`, SHA-256 `226f0ff5f979b0037f96ff3c0f48553a8e5b63ea0461d9a06ab6e2ee61f9cbcf`.
- **AC2:** Actual trace and provenance reconcile.
  Check: remote observations match prompt/model/input/output/settings/usage/research actions and evaluation outcome; record cost with billing limits.
  Result: Passed. CLI retrieved root/generation/validation observations. Thirteen assertions reconcile hierarchy, prompt v7, exact inputs/output, normalized settings, research actions, actual model/usage and persisted-false evaluation outcome. Usage 93,193 input (4,608 cached) / 7,302 output (2,983 reasoning). Langfuse aggregate model cost $0.685025 plus four-search estimate $0.04 gives provisional $0.725025; cached-input breakdown is absent from the trace and billed cost may be lower. Export and remote ingestion verified.
- **AC3:** The comparison answers whether coverage improved in this sample.
  Check: read original v6/v7 outputs and compare causal narrative gaps, per-claim corroboration, script use and quality derivation. Identify remaining limits without quotas or assuming resource count measures quality.
  Result: Passed (sample comparison completed). v7 connects the Norwegian investigation, global containment stakes, Bennings/Blair, failed blood testing/authority, MacReady/Norris/Palmer and station destruction to the ending. It is a more continuous account than v6, though entries still bundle details, per-clause support is uneven and the final companions wording blurs a death with an unresolved disappearance. Nine sources and five candidates are descriptive counts, not quality criteria. One nondeterministic sample does not establish a causal prompt effect.
- **AC4:** Evidence is reviewable and bounded.
  Check: report/spec/plan links and `git diff --check`. No runtime suite required for a one-off evaluation/documentation task; no production code changed. Mark Ready for review after evidence collection, without acceptance/merge.
  Result: Passed. [Comparison report](../research/generated_analysis_verification/the_thing_coverage_comparison.md) records original artifacts/hashes, exact-runner snapshot, request equality, state checks, remote reconciliation, coverage comparison and cost/accuracy limitations. Local Markdown targets and `git diff --check` passed. No runtime suite was rerun; no production code, saved analysis or prompt changed.

## Implementation notes

Completed exactly once on 27 October 2026 with outcome `validated_evaluation`. No result was applied to the saved draft. One-off evaluation is necessary because initial-only generation correctly refuses the already saved The Thing draft. It exercises the same provider request and document validator without adding regeneration behaviour or overwriting editorial work. Evaluation is an experiment, not a new product lifecycle.

Owner acceptance / merge: Pending. One evaluation request authorized; no publication or saved revision.


## Reproducible evidence

The exact paid runner was executed using `bin/rails runner /tmp/glutton_task036_evaluate.rb` and retained locally as `tmp/film_analysis_runs/task036-evaluation-runner.rb` (SHA-256 `2ea2c8257b6d829637a7f28d10ff7108beacf45ab09f24c9b65f4a08063eae37`). It reuses the previous request verbatim except for instructions and calls the configured provider once, then the existing document validator without a save call. Local `task036-verification.json` records unchanged state and prior artifact hash. `task036-observations.json` preserves the actual CLI result. The [report](../research/generated_analysis_verification/the_thing_coverage_comparison.md) provides commands and manual comparison findings. No further paid evaluation is authorized by these reproduction instructions.

Ready for review. Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
