# 027 — Re-run the analysis pilot for traceable comparison

Status: Ready for review  
Owner: Film knowledge / analysis evaluation

## Goal

Evaluate whether a standalone analysis can support precise comparison with viewer expectations and expressions, while preserving previous analysis/quality versions. Revisit Bone Tomahawk (2015), Terrifier (2016), The Babadook (2014), Alien (1979) and Scream (1996). This is a research/documentation pilot, not a recommendation-engine implementation or podcast episode.

Prerequisites: owner review of this spec; revised analysis requirements and task 026 dossiers. The recommendation engine, rating-quality persistence and real host review/profile inputs are not available for an actual prediction evaluation in this task.

## Scope

- Preserve task 026 revision 2 as the baseline; write the new run separately with source/revision provenance and a change log.
- Re-evaluate each dossier's chronological narrative and contextual key moments. Research additional evidence where needed; do not merely reformat conclusions.
- Give meaningful narrative/moment evidence stable references within an identified analysis version. Define how unchanged, corrected, split and removed moments are identified across the two pilot versions without designing storage.
- Produce per-analysis film-quality association sets with self-explanatory candidate names and links to the supporting moments/claims. Keep disputed or tentative associations distinct from accepted findings; these remain research candidates, not database seeds.
- Demonstrate that broad qualities alone are insufficient for some scene-specific expressions. Use clearly labelled constructed expression probes to test whether the evidence can locate a moment, preserve context, support contrasting reactions or honestly return no supported match. Probes are not host reviews or new experiential evidence.
- For one film, retain baseline and replacement association sets and walk through creation, pending validation, activation and supersession using an explicitly illustrative timeline. Demonstrate historical selection before, at and after the replacement boundary, including a rejected draft and a prose-only correction.
- Report which analysis requirements support later profile/review comparisons, which evidence is still missing and what actual engine/user inputs are required to evaluate recommendation correctness.

## Scope restrictions

- Film knowledge owns this task. Do not implement or mutate Ratings or Recommendations, or copy viewer profiles/expressions into film analysis. Shared-data reads are allowed but this task creates no runtime contract.
- No app/schema changes, actual scoring runs, numeric match predictions, generated host profiles, fabricated reviews, podcast publication or database imports.
- No claim of having used the app end to end for prediction comparison. Actual scores and explanations must eventually come from the real engine; illustrative arithmetic would not satisfy that requirement and is excluded here.
- No production taxonomy, quality-description field, automated source-ingestion pipeline, reviewer UI or generic temporal framework.
- No direct-viewing or independent-validation claim unless actually performed with identified provenance. A simulated activation is not curator acceptance.
- Preserve source-use limits and original synthesis. Do not store full source texts or infer absence from missing evidence. No paid access or external communication.

## Acceptance criteria

- **AC1:** All five revised dossiers provide evidence usable independently of a viewer.
  Check: trace major causal developments and at least one quiet/relational moment and one turning point per film through narrative, scene evidence and conclusions. Inspect source support and unresolved gaps, not just section counts.
  Result: Passed in author review on 27 October 2026 — five separate revision-3 dossiers retain the full chronological narratives and contextual moments. The report records the causal chain and relational/turning-point checks per film. Targeted source rechecks refined humour scope, ending distinctions and a garage-injury dispute. Direct viewing and independent acceptance remain outstanding.
- **AC2:** Candidate film qualities are traceable to versioned evidence without personal information.
  Check: inspect each association's evidence references, self-explanatory name and support status; follow references into the correct analysis version. Check that differing reactions can address the same evidence without changing the film account to fit a viewer.
  Result: Passed — twenty candidate associations reference specific revision-3 evidence anchors and are displayed in the dossiers plus associations.json. Nineteen supported interpretations and one tentative association remain unaccepted research candidates. The standalone dossiers contain no host profiles or constructed expressions. reference_history.md preserves old referents and records corrections/splits without changing the baseline.
- **AC3:** Comparison probes expose supported matches and honest limits.
  Check: per film, use labelled constructed praise, dislike and ambiguous/uncovered expressions; explain evidence location and contextual limits without assigning preference scores. Keep probes outside standalone analyses and exclude them from source corroboration.
  Result: Passed for manual evidence-navigation probes — fifteen labelled constructed expressions, three per film, are recorded separately in probes.md. Praise/dislike cases locate relevant material with contextual limits; all five ambiguous/uncovered cases remain unmatched at quality level. No classifier accuracy, user testimony, preference scores or real engine evaluation is claimed.
- **AC4:** Historical analysis/association selection survives replacement.
  Check: exercise the illustrative lifecycle at boundary timestamps; a draft does not displace active evidence, activation replaces atomically, older associations remain inspectable and the boundary selects exactly one version. Distinguish changed associations from prose-only changes. No score reproduction is claimed.
  Result: Passed — `python3 docs/research/comparison_pilot/verify.py` passed thirteen illustrative historical selections, supersession continuity and prose-only association equality. Baseline/replacement sets remain inspectable in timeline.json. The exercise includes no active first draft, a rejected draft, pending replacement and exact-boundary selection; it does not test database concurrency or actual activation.
- **AC5:** Report separates verified research outcomes from future engine evaluation.
  Check: list missing real inputs and unresolved processing policies; validate local links/anchors and whitespace. Record commands and actual results here. No runtime tests are required for docs-only work.
  Result: Passed — the same verifier checked six unchanged baseline hashes, 196 local links/anchors and twenty association references. `git diff --check` passed. The report lists missing engine/viewer inputs and unresolved processing policy. No application code, database changes, runtime tests or numeric recommendation scores were introduced.

## Implementation notes

Owner approved execution on 27 October 2026. Completed the [repeat report](../research/comparison_pilot/README.md), five revision-3 dossiers, association sets, reference history, probes and an illustrative lifecycle fixture. The six baseline Markdown files are preserved byte-for-byte and checked by hashes. The documentation tests readiness for comparison; actual recommendation/profile/review comparison requires separately scoped work in its owning domain after the engine and real inputs exist. That later evaluation must use the score and scoring rules actually used, not a narrative reconstruction presented as an engine explanation.

Owner acceptance / merge: Pending.

Reproduction: from the repository root run `python3 docs/research/comparison_pilot/verify.py` and `git diff --check`. Review the report’s per-film causal traces against linked N/M sections and the separately labelled probe worksheet. Source rechecks and added BBFC evidence are recorded in the report; previously consulted sources are not claimed as newly independent evidence.
