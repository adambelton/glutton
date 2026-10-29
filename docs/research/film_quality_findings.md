# Film-quality research: retained findings

Consolidated 29 October 2026 after the owner chose to stop fine tuning as a prerequisite and move toward selection/community review. Superseded tuning reports, matrices, duplicated inputs, local raw dumps and replay scripts have been removed. The [working baseline](../film_qualities/README.md) retains the vocabulary, question contract and reusable examples.

## Decisions carried forward

- Wikipedia's maintained articles provide a useful initial source; BFI may supplement gaps. JEV judges supplied context rather than doing heavy research.
- Start with 235 provisional qualities, aiming for roughly 250 without padding. Quality/category meanings remain editable product data; categories replace hard-coded dimensions through separately planned task 043.
- Qualities and categories begin with equal base treatment. Do not ask JEV to favour important, central, defining or personally influential qualities. Confidence/support probability is not a scoring weight.
- Assess coexisting qualities independently. Shared-state requests were inexpensive in these tests; one question per quality need not mean one HTTP request per quality.
- Keep matching separate from the eventual maximum of 20 accepted qualities and from each user's preference contributions. Source updates, candidate assessments and accepted film-quality changes are different actions.
- Imperfect matches are expected in a community-improved seed. Known semantic issues are diagnostics, not blockers or justification for endlessly fitting six films.

## Latest six-film evidence

On 28 October 2026, six `jev-1.14.0` calls evaluated all 235 revised questions against the same frozen Wikipedia packets: The Thing, The Babadook, Tumbbad, Get Out, The Witch and REC. All 1,410 probabilities survive in the [uncapped examples](../film_qualities/examples.json), together with original source paragraphs/revisions/licences and 318 matched-candidate review records.

| Film | Provisional matches >=0.7 | Uncertain 0.3–<0.7 |
| --- | ---: | ---: |
| The Thing | 53 | 51 |
| The Babadook | 46 | 53 |
| Tumbbad | 50 | 71 |
| Get Out | 59 | 64 |
| The Witch | 75 | 55 |
| REC | 35 | 46 |
| Total | 318 | 340 |

The run used 146,953 input tokens, with **calculated cost $0.006172026 total**, approximately $0.001029 per film, under its $0.02 ceiling. This is historical model-input cost, not a catalogue-wide cost guarantee or invoice reconciliation. All six calls succeeded without retries; trace checks matched exact requests, responses, model, hierarchy, usage and calculated cost. No film/domain records were changed.

The agent reviewed all matches and uncertain results plus four low-support diagnostic cases: 662 pairs. Among the 318 matches, 224 were directly supported, 61 attributed or reviewer interpretations, 25 ambiguous, six not established and two contrary to the tested definition. These are non-blind agent judgments, not independent accuracy measurements. Most low-support pairs were not adjudicated, so full recall is unknown. Seven unestablished pre-run probes yielded no matches; 22 of 24 supported/attributed probes matched. That small diagnostic set was neither held out nor owner-reviewed ground truth.

Examples of remaining limitations: Babadook's protector reversal stayed below the inspection threshold; REC's pacing was uncertain; possession versus replacement and known persistence versus an unknown threat outcome remain semantic boundaries. Tumbbad's minimal dialogue and greed were both strongly supported. No further tuning or selection rule follows automatically from these examples.

Earlier experiments established feasibility and explored presence, importance, prominence and relative choice. Importance did not demonstrate a clear gain, and relative choice forced coexisting qualities to compete. Those superseded comparisons are no longer a work queue. The tested neutral definitions, rather than the earlier importance-guided variants, form the retained baseline.

## Receipt and next step

The former experiment-only specs 044, 045, 048 and 049 and their detailed research trees were retired in [cleanup task 050](../specs/050_jev_research_cleanup.md). Removing artifacts is not retrospective owner acceptance or merge of those tasks. Existing remote Langfuse traces remain untouched; no remote dataset or prompt migration was performed.

The next design work is candidate selection and source-backed community review/publishing, with at most 20 accepted qualities and unchanged historical rating/recommendation contributions. Controller permissions, selection criteria, publishing mechanics and downstream event contracts still need agreement. [Current requirements](../film_quality_requirements.md) hold the authoritative lifecycle decisions.
