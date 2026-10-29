# 053 — Compare global and category quality-selection caps

Status: Ready for review  
Owner: Film knowledge

## Goal

Produce one reproducible comparison of film-quality selection policies, using the retained six films and fresh JEV results, to inform whether configurable category ceilings should replace the overall 20-quality cap. Prerequisites: current implementation plan, product brief sections 5–6, requirements, task 052 and retained vocabulary/matching/examples.

## Scope

Owner follow-up, 29 October: record individually configurable category ceilings and separate admin category-weight tuning as the intended direction. Equal weights remain the initial baseline. Subgenres 2 / tropes 4–5 are illustrative starting candidates, not final values. This documentation follow-up does not expand the completed call experiment or authorise implementation.

- Use unchanged source packets, definitions and neutral per-quality support questions. User authorises paid calls with the project's TYPESAFE_API_KEY, public Wikipedia context/quality definitions only, maximum US$1 (29 October 2026).
- Evaluate >=0.60 as the main proposed support gate, >=0.70 as sensitivity, and deterministic probability-descending/ID-tie selection: global top 20, category ceilings 2/3/4, threshold-only diagnostic. Category ceilings do not fill empty categories. Uniform experimental ceilings are not tuned category defaults.
- Replay the historical six-film results and collect two fresh full-vocabulary rounds on the same six frozen packets/model. Keep exact requests/results, usage, provenance and arithmetic separate from interpretation. Stop on errors rather than silently fabricating answers or retrying paid calls.
- Report selected counts/category coverage/concentration, cap-driven exclusions, retained review flags and repeat stability. Inspect concrete additions/omissions against source/definitions. Existing review labels are historical agent judgments, not owner-adjudicated truth; the 0.60–0.69 band is not fully reviewed.
- Explain variable-total/count bias, vocabulary/category-size effects and limits of inferring recommendation fairness without user outcomes. Propose data-managed category ceilings and consequences for regrouping; no production policy adoption by experiment.

## Scope restrictions

- No application/schema/UI/scoring implementation, production vocabulary/association changes, source subscription, user-expression processing or event contract changes. No category weights, minimum category quotas, importance guidance or prompt/definition tuning.
- Do not modify retained baseline data, task 043 or unrelated local work. Do not declare historical review flags accuracy ground truth, repeatability correctness, or category spread fair recommendation quality.
- Do not create live Langfuse datasets/evaluators, annotations or prompt changes. Keep this a bounded selection experiment, not a new testing framework or broad JEV tuning exercise.
- No automatic acceptance of model output or replacement of manually accepted film qualities. No budget escalation or open-ended provider retries. Each request reserves its full default context cost before execution; total reservation must remain below US$1.

## Acceptance criteria

- **AC1:** Comparable policy outputs exist for the same frozen inputs.  
  Check: exact IDs/thresholds/caps and stable tie ordering; no padding; all probabilities valid and all 235 answers present per completed film; retained baseline hashes unchanged.  
  Result: Passed — retained baseline/category hashes unchanged. Replay produced 18 film-round cases (6 historical, 12 fresh), 180 policy outputs and 60 fresh repeat comparisons. All successful fresh responses contained exactly 235 valid probabilities; exact request/input hashes matched. Synthetic boundary check confirmed >=0.60 inclusion, exclusion below threshold, stable ID ties, per-category ceiling and no category padding.
- **AC2:** Fresh calls stay within the authorised data/spend boundary.  
  Check: request/response/usage ledger, pinned model and unchanged definitions/question/state; two six-film rounds if successful; calculated usage charge and conservative request reservation below US$1; errors reported explicitly.  
  Result: Passed — 12 successful pinned-model calls, 293,906 input tokens, calculated US$0.012344052 at checked pricing. Full-context reservation US$0.033030144; including the initial sandbox-DNS-blocked attempt US$0.035782656, below US$1. Exact public requests/results and ledger saved under ignored tmp/quality-policy-053. No personal data, prompt changes or paid automatic retries. One network escalation resolved sandbox DNS restrictions; no provider rejection or secret output.
- **AC3:** Findings address category balance without overstating fairness or accuracy.  
  Check: compare category occupancy/counts, exclusions, historical flags, same-input repeat stability and concrete context examples; distinguish ceilings from quotas and selection opportunity from scoring weights; identify decision/implementation implications and limits.  
  Result: Passed — findings compare 60%/70%, category ceilings 2/3/4 and global20, with actual category count/concentration, historical review flags and fresh set-overlap. Source-linked examples inspect useful Tumbbad additions, sparse Get Out candidates and a surviving questionable Rec ending label. Labels explicitly remain historical agent judgments, not owner ground truth; no recommendation fairness/accuracy claim. Data-managed caps and configuration/grouping effects are proposed, not implemented.
- **AC4:** One concise findings record and reproducible evidence are ready for review.  
  Check: report links to scoped experiment script/data, checks actually run, local link/whitespace checks and no production/baseline/unrelated changes. Update plan/status; no automatic policy implementation, merge or catalogue publication.  
  Result: Passed — one findings document, compact JSON evidence and scoped replay/collection script. Ran python3 script/experiments/quality_selection_policy.py (offline replay), inline request/hash/charge/selection-boundary checks, python3 /tmp/glutton-052-check.py and git diff --check. 201 local links/anchors across 14 changed Markdown files valid; 6 protected baseline/category files and 7 unrelated diffs unchanged; production diff empty. Temporarily removed the raw-cache directory, replayed offline and verified the complete compact evidence remained byte-for-byte identical, then restored the cache. Owner follow-up recorded individually configurable ceilings and separate admin category-weight controls with equal initial weights; updated current requirements/brief/workflow/plan and appended the decision without changing experimental results. Re-ran preservation/link/whitespace checks: 201 local destinations valid, protected inputs unchanged. No application runtime tests or CI required/run for this isolated experiment.

## Implementation notes

Owner approved paid experiment calls and US$1 ceiling. Research scope only; category caps and 60% threshold are proposals under evaluation. No implemented or accepted replacement for the current overall cap yet.

Deliverables: findings at docs/research/quality_selection_policy_053.md, compact reproducible probabilities/selections at docs/research/quality_selection_policy_053.json and script/experiments/quality_selection_policy.py. Brief/requirements/plan note category ceilings as a proposal under review. The old task-052 evidence remains separate.

Reproduce without paid calls: run python3 script/experiments/quality_selection_policy.py; inspect counts/category_counts and fresh_repeat_comparisons in the generated JSON. With raw cache absent, the retained compact fresh cases supply offline replay. Compare the recorded file hashes to the baseline, and inspect source/definition references for the concrete examples. The session checker at /tmp/glutton-052-check.py additionally verifies local document links, whitespace and preservation against its pre-task snapshot. Exact paid requests remain reconstructible from the canonical inputs and request_for function. No new paid run is authorised merely by this spec becoming Ready for review.

Limitations: six familiar, relatively rich full-context articles; no sparse-film holdout or user-outcome test, no owner-adjudicated accuracy labels, no proof that 3 or 60% is optimal. Follow-up should decide the selection policy and fair-comparison rule explicitly rather than adding automatic category weights or re-entering general prompt tuning.

Owner acceptance / merge: Pending.
