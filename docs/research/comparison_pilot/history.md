# Historical selection walkthrough

This is a constructed lifecycle exercise using The Babadook's two research association sets. Dates are illustrative UTC instants, not actual validation/activation dates. No curator approved these dossiers and none is active in an application. [Inspectable inputs and expected selections](timeline.json).

| Point | Change | Applicable analysis |
| --- | --- | --- |
| 1 January, 09:00 | Baseline created | None: creation is not activation |
| 2 January, 09:00 | Baseline hypothetically validated and activated | a2 |
| 3 January, 09:00 | Another draft created, later rejected | a2 remains active |
| 4 January, 09:00 | Replacement a3 created, pending validation | a2 |
| 5 January, 09:00 | a3 hypothetically validated and activated; a2 superseded at exactly that instant | a3 |
| 6 January, 09:00 | Punctuation-only a4 draft created | a3 |
| 7 January, 09:00 | a4 hypothetically activated; a3 superseded | a4, with the same qualities as a3 |

The baseline set is an explicit transcription of the previous dossier's candidate shorthand, not previously persisted production associations. The replacement set is the actual association list prepared in this run. Both are research candidates. a4 and the rejected draft are hypothetical lifecycle records, not additional researched analyses.

## What changes and what stays available

The baseline's broad living-with-unresolved-danger association is absent from a3. It does not disappear from a2. The replacement distinguishes continued containment from restored care. Old references still lead to the old source-based account; new references lead to the more precise moments. A query for 4 January must still return a2 even after the entire timeline has been loaded.

The selector uses activation-inclusive and supersession-exclusive intervals. It never infers that a draft is current because it has the latest creation time. One version's end equals its successor's start; the snapshots represent an atomic replacement. This exercise checks the resulting temporal invariant, not a database transaction, lock or concurrency implementation.

The punctuation-only replacement retains the same quality set. Its new analysis identity does not itself establish a reason to recalculate preference scores. Conversely, splitting a broad association does not justify copying an old rating-quality contribution into both new qualities.

## What this cannot reproduce

Historical film associations alone cannot reproduce a recommendation. That also requires the completed rating-quality scores which applied to the viewer at the time and the scoring rules actually used. No such input exists in this pilot. There are no synthetic scores, host profiles or predictions here. Pending score processing and stale-result policy remain future Ratings/Recommendations concerns; this example does not decide them.

Run `python3 docs/research/comparison_pilot/verify.py` to check the thirteen timestamp cases, unchanged baseline hashes, evidence links, supersession continuity and association retention. This is a research-artifact check, not a production temporal model.
