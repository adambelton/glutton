# Comparison-ready analysis pilot — run 027

Status: Ready for review; research drafts, not activated analyses  
Date: 27 October 2026  
Owner: Film knowledge  
Authorship: Codex assistant; source-based research and manual evaluation, no direct viewing. Exact deployed model build unavailable. Task/prompt provenance: owner-approved [task 027](../../specs/027_comparison_ready_analysis_pilot.md), [analysis requirements](../../film_analysis_requirements.md), and preserved task 026 revision-2 dossiers.

**Spoilers:** full narrative outcomes and disturbing scenes appear in the dossiers.

## Result

The existing narratives can support considerably more precise comparisons when qualities link to specific versioned moments. The repeat also exposes limits: a scene can be identifiable without a supported quality match; one expression can concern several moments; and apparently similar endings need different descriptions. Historical association selection works in the bounded illustrative fixture. Actual recommendation correctness remains untested.

This run preserves the full chronological narratives and key-moment discussions in separate revision-3 dossiers, then adds evidence references, re-evaluation notes and explicit candidate association sets. It does not replace evidence with a matrix. No host information or constructed expression appears inside a standalone dossier.

## Dossiers and evaluation

| Film | Revised dossier | Causal/relational trace checked | Material change from revision 2 |
| --- | --- | --- | --- |
| Bone Tomahawk | [Analysis 3](bone_tomahawk.md) | Treatment visit → rescue → loss of mobility → captivity → partial rescue; M1 and M4 | Qualifies the tonal boundary with M7; humour may persist during danger. Companionship enjoyment is not assumed. |
| Terrifier | [Analysis 3](terrifier.md) | Pickup delay → building entry → failed resistance → sister's arrival; M1 and M3 | Separates the returning attacker from the survivor's later violence; neither explains the other. |
| The Babadook | [Analysis 3](the_babadook.md) | Loss → isolation → caregiver threat → protection → ongoing care; M2 and M5 | Separates continued containment from renewed affection in the ending. |
| Alien | [Analysis 3](alien.md) | Work obligation → quarantine breach → concealed threat → betrayal → escape; M1 and M5 | Separates interrupted refuge from successful adaptation. The two meals stay distinct. |
| Scream | [Analysis 3](scream.md) | Threat → suspicion → party → deception → resistance; M3 and M5 | Adds a source disagreement about the garage injury; no invented precise surveillance delay. |

All five retain seven narrative phases, their original six contextual moments and seven experiential dimensions. Added moments refine referents instead of making old links silently point elsewhere. See the [reference history](reference_history.md), including unchanged, corrected, split and prospective withdrawn references.

## Research performed

Re-examined the five revision-2 dossiers against the new comparison use case, with targeted web rechecks of Bone Tomahawk B6 (Bitel), Terrifier T4 (Williams), The Babadook D1/D5/D6 (Kenny, Culture Crypt, Eisenberg), Alien A3 (Graham-Dixon), and Scream S2 (Newman). Those are existing sources, not additional independent votes. Source registers and earlier access limitations are inherited, not presented as a fresh full audit of every URL.

Added Scream S8, [BBFC content advice](https://www.bbfc.co.uk/release/scream-q29sbgvjdglvbjpwwc0zmde0mtc), retrieved 27 October 2026. Its description differs from the earlier synopsis about the specific garage injury. Revision 3 keeps the agreed event but marks that detail disputed; an authoritative publisher does not resolve a scene discrepancy by itself. No alternate-cut explanation is asserted without evidence.

The inherited 32 sources across 33 URLs become 33 sources across 34 URLs. The search also returned other summaries; they are not treated as inspected corroboration or added to source registers. No scripts/subtitles, film copies, source archives, paid services or model API runs were used. No new evidence of a particular host's response was obtained.

## Association evaluation

[Twenty inspectable associations](associations.json) are also displayed beside their evidence in the dossiers. These are selected research candidates, not exhaustive film inventories or seed data. Nineteen are labelled supported interpretations; Bone Tomahawk's wry-humour association remains tentative in its scene-specific scope. None is independently accepted. Each records the analysis version, self-explanatory quality name, support status and evidence references. There is no separate quality-definition field.

Self-explanatory names help preserve useful distinctions: temporary refuge interrupted differs from a threat surviving the ending; perpetrator playfulness differs from conversational wit; the act of resisting differs from resistance succeeding. These are hypotheses about useful distinctions, not evidence that finer granularity necessarily improves ranking. Wider-film overlap and user preference relevance still require evaluation.

A quality's presence is independent of positive or negative sentiment toward it. Two viewers can react oppositely to one moment without changing the film association. Conversely, liking a scene does not establish liking every quality associated with it.

## Comparison probes

The [separate probe worksheet](probes.md) contains fifteen clearly labelled constructed expressions: praise, dislike and an ambiguous/uncovered case for each film. They test evidence navigation, not a classifier or the recommendation engine. They are excluded from corroboration and profile building.

Manual outcomes:

- Five praise cases locate material; one needs more precise scene identification and another exposes a gap between a broad quality and a specific viewing device.
- Five dislike cases locate events. Scream's boyfriend example still does not distinguish disliking betrayal from disliking the writing of a twist.
- All five ambiguous/uncovered cases remain without a supported quality match. Being able to locate a scene is insufficient to infer a preference about its music, effects or another undocumented feature.

The results support a comparison presentation that can say “located, interpretation uncertain” or “not covered”. A forced binary match would hide these distinctions. These are presentation/research findings; no new runtime states or APIs are prescribed.

## Historical selection

The [walkthrough](history.md) and [fixture](timeline.json) retain baseline and replacement association sets for The Babadook. Thirteen historical queries cover pre-activation, pending/rejected drafts, exact replacement boundaries, later retrospective queries and a prose-only replacement with unchanged qualities.

The checked invariant is one applicable version at an active time, with an inclusive start and exclusive end. Older association sets remain retrievable after replacement. Draft creation does not displace active material. The fixture is explicitly hypothetical: none of these timestamps asserts real validation or activation. Database concurrency and transaction behaviour were not tested.

## What the podcast still needs

The analysis layer is now inspectable independently of either host. The other layers still require actual engine output, real historical completed rating-quality sets, applicable scoring rules and submitted host reviews/expressions. There is no score or ranking in this report. An analytical explanation of a scene is not evidence that the engine predicted the host's response to it.

For the eventual episode, retain the expectation from before submitting new expressions. Reading the analysis before discussion is part of the agreed experience and should remain recorded context. It may shape responses, so those expressions are not blind validation of the analysis they have just read.

Still unresolved: complete scene/cut verification; independent acceptance; candidate overlap outside this selected English-language sample; real expression-matching quality; scoring accuracy; and the policy while updated assessments are pending. The run does not settle those by producing a larger document.

## Verification

Run from the repository root:

```sh
python3 docs/research/comparison_pilot/verify.py
git diff --check
```

The verifier checks baseline SHA-256 hashes, local links/anchors, twenty association references, thirteen historical selections, replacement continuity and unchanged qualities for the prose-only case. The narrative/source and probe evaluations above are manual author reviews, not automated factual verification. Exact execution results are recorded in task 027. No Rails tests are required or claimed for this documentation-only work.
