# 041 — Draft a master quality vocabulary and test JEV matching

Status: Ready for review  
Owner: Film knowledge

Artifact disposition, 29 October 2026: this is a historical task record. Research filenames, commands and check results below describe work completed then; superseded tuning artifacts and replay scripts were intentionally removed in [task 050](050_jev_research_cleanup.md). Current inputs and reusable examples are in the [working baseline](../film_qualities/README.md); historical commands are not current reproduction instructions.

## Goal

Create a useful, provisional master vocabulary for describing viewers' relationships with horror, independently of qualities generated from the three sample films; then test source-grounded JEV matching against that frozen vocabulary. Owner requested this change of approach on 28 October 2026. Prerequisites read: task template, implementation plan, product/analysis requirements, TypeSafe skill and prior source/JEV experiments.

## Scope

- Author about 250 v0 qualities spanning subgenres, tropes, narrative devices, themes, ironies, dynamics, presentation/intensity, emotional tone and resolution. Owner explicitly requested these facets and approximately 250 entries. Give each quality an explicit matching rule, boundary and illustrative taste question. Qualities describe films; liking/disliking them remains separate viewer evidence. Keep it revisable, without claiming exhaustive coverage or a production taxonomy.
- Freeze the vocabulary and a small source-based reference set before querying JEV. Reuse the same three retained Wikipedia packets; do not let the model generate quality names, rewrite plots or perform research. Record all remaining matches for inspection, without calling unreviewed cells correct.
- At most fifteen official TypeSafe requests: up to five batches of fifty qualities for each film, pinned JEV 1.14, one independent Noul per quality, no retries and US $0.10 ceiling with conservative reservation. Use the configured TYPESAFE_API_KEY; transmit only retained public Wikipedia text and authored questions. Preserve raw payloads, model/status/usage/cost, trace and unchanged catalogue/prior artifacts.
- Inspect predicted matches against actual supplied paragraphs and compare against the frozen reference subset. Low support means not established from this source, never absent from the film. Record ambiguous claims, missed distinctions and limitations. No threshold tuning or further paid attempt.
- Update the project direction to vocabulary-first matching and record reviewable artifacts/results. Owner clarified that JEV is the chosen engine: evaluate and improve definitions, state and questions, rather than reopening tool selection. After the frozen baseline, perform an explicit preference-relevance audit of all 250 entries; remove weak descriptive mechanics, propose stronger concepts and record a separately versioned working list. About 250 is a target, not permission to pad. Owner also superseded code-managed dimensions with editable qualities/categories and reassessment of affected derived results; record requirements and current constraints, without implementing taxonomy or cross-domain recalculation. This revision authorises no additional paid requests.
- Owner chose a maximum of 20 assigned qualities per film (not a quota). Retain uncapped matching results for inspection; propose only a reviewed selection within that maximum. Avoid padding and redundant assignments. This task does not implement or validate downstream score normalisation; a cap alone does not resolve all raw-sum bias.
- Owner confirmed following Wikipedia's maintained articles while Glutton focuses on qualities. Record this responsibility split without implementing subscriptions, upstream editing or another encyclopaedic community workflow.

## Scope restrictions

- Film knowledge research only. No production quality records, vocabulary IDs, generator/validator/schema changes, Ratings/expression implementation, user profile inference, publication, Wikipedia subscription implementation, deployment or merge.
- Do not turn genre/type labels, artistic praise, popularity, a creator's identity or production circumstances into experiential evidence by assumption. Do not turn source silence into absence or a quality's presence into enjoyment. Correlated qualities are not independent preference evidence.
- No source-ground-truth claim: reference judgments are agent readings of supplied packets, not independent viewing or human acceptance. No claim that results generalise to sparse articles or calibrate JEV probabilities.
- Master list and reference subset are frozen before spending; do not revise them to improve results or rerun failures. Preserve prior work, including .agents/ and .obsidian/.

## Acceptance criteria

- **AC1:** The vocabulary is interpretable and useful for preference distinctions.  
  Check: each entry has stable experimental ID, name, category, matching boundary and taste question; cover contrasting experiences and avoid forced viewer reactions. Provide a readable master list, audit every original entry for a plausible seek/avoid mechanism, and distinguish editorial hypotheses from empirically demonstrated preference influence.  
  Result: Passed for the research deliverable. Baseline vocabulary has 250 unique entries with all required fields across nine facets. Subsequent owner-directed relevance audit covers all 250; 41 weak descriptors retired and 26 new hypotheses added, leaving 235 working candidates. `inspect.py` checks identity/count reconciliation, definitions, boundaries and hypotheses. MASTER_LIST.md is the current readable list; BASELINE_LIST.md preserves the tested list. Preference influence is editorial and not user-validated; several retained entries require refinement before production.
- **AC2:** Matching uses the frozen list and source-grounded independent questions.  
  Check: hash vocabulary/references/packets before execution, no generated naming or leaked reference labels, no tools/retries; at most fifteen requests under ceiling with actual usage/cost and trace evidence.  
  Result: Passed. `prepare.py` froze vocabulary, 36 references, cases, exact requests and source hashes before calls (freeze.json). Fifteen pinned jev-1.14.0 requests each ask 50 independent Nouls; all 750 judgments completed, no retries/reference labels in state. 158,935 input tokens; calculated US $0.00667527 against reservation $0.06071982 and ceiling $0.10. All 15 remote traces reconcile request/response/model/parent/usage/cost through audit_traces.rb. No second run after vocabulary revision.
- **AC3:** Accuracy is assessed against inspectable evidence.  
  Check: frozen reference-subset outcomes, review high-support predictions with paragraph links, list disagreements/misses and uncertainty; no full-grid accuracy claim without reviewing that grid.  
  Result: Passed with stated limits. All 18 source-positive and 18 not-established reference judgments agree at frozen bands. REVIEW.md/review.json provide paragraph-linked source readings for 58 baseline selections and 12 diagnostic cases, including unsupported high matches and low matches to supported reversals. No full-grid precision/recall or viewer-preference claim. Baseline selections are explicitly not accepted current preference profiles; later relevance audit retires some selected labels. PIPELINE.md quotes exact supplied criteria and proposes unexecuted refinements.
- **AC4:** Work is reviewable and domain state preserved.  
  Check: prior/domain hash equality; syntax, JSON/reference checks, local links/anchors and whitespace. Update requirements and plan; mark Ready for review without owner acceptance or merge.  
  Result: Passed. Before/after domain counts 2/0/0 and analysis hashes identical; 70 prior JSON artifacts unchanged. Offline inspector passed complete coverage, hash/answer/cap/source/audit integrity and cost checks. Ruby syntax passed for evaluate.rb and audit_traces.rb. Python syntax passed via py_compile with cfile paths in /tmp (initial default cache destination was sandbox-denied; corrected check passed). 149 local research/spec links and anchors passed before closeout; git diff --check passed. Requirements/brief/plan updated for JEV, preference relevance, Wikipedia responsibility and editable taxonomy. EVOLUTION.md identifies current model/database/identity constraints and future reassessment outcomes, without inventing cross-domain event contracts. No runtime tests rerun because production code/schema are unchanged; no owner acceptance or merge.

## Implementation notes

Authored and froze exactly 250 qualities across nine facets and 36 reference judgments before provider calls. Five batches of 50 independent Nouls per film. Fixed candidate threshold ≥0.7, not-established band ≤0.3, middle uncertain; no tuning. Conservative reservation $0.06071982 under $0.10. Source silence never means film absence.

Owner acceptance / merge: Pending.

## Changes and reproducible verification

- Research assets under `docs/research/master_quality_vocabulary/`: frozen baseline, reference set, exact questions, all probabilities, source review, preference audit and revised working list.
- Used installed TypeSafe skill for independent Noul judgments, meaningful criteria, shared-state batching, source-only evidence, no retries and inspectable raw results. Official documentation verified before the calls; JEV input pricing was $0.042/million, output free.
- Reproduction commands are listed in the research README. Offline result check: `python3 docs/research/master_quality_vocabulary/inspect.py`. The evaluator's existing ledger refuses paid reruns; do not delete it or replay automatically.
- Syntax: `ruby -c docs/research/master_quality_vocabulary/evaluate.rb` and the same for `audit_traces.rb`; Python `py_compile.compile(path, cfile="/tmp/<name>.pyc", doraise=True)` for prepare.py and inspect.py. Local link verification resolves relative Markdown paths and explicit/heading anchors from research/spec files; whitespace check is `git diff --check` plus direct research/spec line checks.
- Deviation: the owner raised preference relevance and vocabulary evolution during the run. The frozen baseline is unchanged; a separate 235-entry working revision and requirements were produced. New or refined questions were not tested again. “About 250” was not treated as a quota.
- Production fixed dimensions remain implemented until a separately scoped Film knowledge change. No migration, taxonomy UI, downstream recalculation, event publisher/subscriber or application user-facing text changed.

Documentation maintenance, task 042: obsolete earlier LLM experiment documentation was removed at the owner's request. Current vocabulary/JEV inputs/results remain; the three source exports now live under master_quality_vocabulary/sources/. Current lifecycle requirements are in film_quality_requirements.md; whether to retain independent FilmAnalysis history is open. The original recorded experiment outcomes above remain historical, not production acceptance.
