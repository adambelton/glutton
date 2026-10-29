# Quality selection: global cap versus category ceilings

Status: Ready for review, 29 October 2026. Film knowledge / [task 053](../specs/053_category_selection_policy_experiment.md).

**Finding:** category ceilings address the observed concentration of global top-20 selection, but do not by themselves establish fair recommendation scores or correct assignments. Store any chosen ceiling as editable category data, not a code constant or a requirement to fill every category. A 60% minimum is a useful candidate for the next policy, not evidence that every admitted match is reliable.

## What ran

Replayed the retained six films and ran two fresh full-vocabulary rounds: 12 successful calls, 2,820 fresh judgments, using `jev-1.14.0`, the same 235 definitions, source packets and neutral support question. No category/importance instructions were sent. Each film used one request with shared context and 235 independent Noul questions. The historical examples were not rewritten.

Compared >=0.60 and >=0.70 support gates. Within each policy, sort by descending support then stable quality ID for ties. Select global top 20, or independently take up to 2/3/4 per category; threshold-only is a diagnostic. Never pad a category. These caps are experimental settings, not adopted defaults or preference weights.

Actual calculated charge: **US$0.012344052**, from 293,906 input tokens at US$0.042/million; outputs free under the checked [TypeSafe pricing](https://docs.typesafe.ai/models). Budget was US$1. Successful requests reserved US$0.033030144 at the full default context bound. An earlier sandbox DNS failure never reached the service; network-enabled execution then completed without paid retries. Even counting that blocked attempt's reservation gives US$0.035782656, below budget. No user expressions/personal data were sent.

Reproduce with `python3 script/experiments/quality_selection_policy.py` to replay locally; this makes no provider calls. `--collect` is the explicit paid path, uses `.env.development` without printing it, and resumes completed cases without another call. Reusing this completed run is not authority to launch a new paid experiment. Exact public request/response JSON and the attempted-call ledger remain in ignored `tmp/quality-policy-053/`; [compact evidence](quality_selection_policy_053.json) retains probabilities, usage, request/input hashes, selections and repeat comparisons. Request bodies reconstruct from pinned model, unchanged baseline files and the [script](../../script/experiments/quality_selection_policy.py), without copying source packets into another research tree. This run did not create Langfuse datasets/evaluators/prompts.

## Category distribution

There are nine provisional categories, with vocabulary sizes 15–45. Values below cover **both fresh rounds across six films**; ranges describe actual results, not theoretical limits. Jaccard measures overlap of selected IDs between fresh rounds (intersection/union), averaged across the six films. It measures stability, not truth or recommendation usefulness.

| 60% policy | Selected per film | Categories represented | Mean repeat overlap | Largest observed category share |
| --- | ---: | ---: | ---: | ---: |
| Global 20 | 20 | 6–9 | 0.921 | 45% |
| Up to 2/category | 16–18 | 8–9 | 0.887 | 12.5% |
| Up to 3/category | 24–27 | 8–9 | 0.892 | 12.5% |
| Up to 4/category | 30–36 | 8–9 | 0.909 | 13.3% |
| Threshold only | 44–90 | 8–9 | 0.957 | 32.4% |

First fresh round, showing the category-3 option against global 20:

| Film | Global count / categories | Category-3 count / categories |
| --- | ---: | ---: |
| The Thing (1982) | 20 / 8 | 27 / 9 |
| The Babadook | 20 / 7 | 25 / 9 |
| Tumbbad | 20 / 9 | 27 / 9 |
| Get Out | 20 / 6 | 25 / 9 |
| The Witch (2015) | 20 / 7 | 27 / 9 |
| Rec | 20 / 8 | 26 / 9 |

The historical replay shows the same broad concentration issue: Get Out's global 20 contains 10 Themes labels. Fresh round 1 contains 9. A category-3 ceiling retains bodily autonomy, loss of self and racial othering, but excludes other strongly supported themes, including dehumanisation (0.96). It admits useful descriptions elsewhere, such as confining interiors (0.89). This is a deliberate selection tradeoff, not a probability correction.

Category-2 keeps totals closest to the former global cap, but removes more distinctions within a category. Category-4 permits more descriptions and larger totals. Category-3 is a reasonable **provisional comparison point** between them; these six films do not establish that 3 is optimal, or justify individually tuned limits for all nine categories.

## Correctness and threshold tradeoffs

The following are contextual diagnostics, not new owner-adjudicated reference labels or preference-accuracy estimates:

- **Useful broadening:** Tumbbad's category-3 set includes corrupting mentorship and breaking an inherited cycle, while global top 20 concentrates on subgenres/themes. Existing paragraphs P8 and definitions support these distinct descriptions. This is not evidence that every category needs representation.
- **Sparse-category weakness:** Get Out's first fresh category-3 set includes concealed infection (0.64). Paragraphs P7–P9 establish concealed brain transplantation, not infection; “assimilated” in the existing definition makes this an ambiguous fit rather than a confidently valid new tag. Graphic bodily injury (0.61) supplies its ninth category, but drops below 0.60 in round 2, leaving eight categories. A plot description of injury does not alone establish explicit screen presentation under this definition. Do not force the missing category back in.
- **A higher threshold does not remove all false matches:** Rec's category-3 selection includes unresolved threat at the ending (0.76), previously flagged as contradicted: P7 shows the attacker still active, rather than uncertainty about whether the threat ended. This survives 70%. Other retained flags include questionable competent-people and sanctuary claims. Category spread is not a correctness score.
- **Crowded-category omissions remain real:** a hard category ceiling can remove a legitimate fourth theme or subgenre even at high support. A cap of 2/3/4 is a policy choice about representation, not a claim that those excluded qualities are absent.

At 60%, category-3 yields 24–27 selected qualities; at 70%, 22–27. Mean same-input repeat overlap rises from 0.892 to 0.931. Global top 20 is unchanged by switching these thresholds in all fresh cases: its candidates already clear 70%. In contrast, category ceilings reach further down sparse-category lists, so the threshold matters more. A 60% gate admits additional uncertain candidates; that may be acceptable for reviewable suggestions, but is a deliberate risk for automatic initial assignment.

First fresh category-3 selections contain 3 historical `not_established`, 1 `contradicted`, 5 `ambiguous` and 11 `not_historically_reviewed` flags among 157 selected associations. Global 20 has 3 historical ambiguous flags and no historical contradicted/not-established flags among 120. **These are not measured error rates:** historical review is incomplete (especially below 70%), was agent-authored, is not independent owner ground truth, and did not review each fresh selection anew. The result is a warning worth inspecting, not a declaration that global selection is more accurate.

Repeated calls also changed the selected set despite unchanged sources/definitions/model: global top 20 swapped one quality in five of six films; category-3 changed in five of six films (one to three additions/removals). Small model variation and ranking ties can generate suggestions without a substantial Wikipedia update. This supports keeping refresh results as suggestions only, with explicit admin application.

## Recommended direction and open decision

Prefer **data-managed category ceilings** as the next policy direction to review, with no mandatory minimum and a provisional 60% eligibility gate. Use the category-3 output as the first concrete set to inspect, alongside category-2 where it discards a useful distinction. Do not adopt a global-20-plus-category-caps hybrid silently; that would introduce another allocation rule and could restore category competition.

A category setting should mean a configurable nonnegative integer maximum, validated explicitly; 0 disables automatic selection for that category, not evidence that its qualities are absent. It is not a per-film adaptive quota, a score multiplier or a number chosen by JEV. Different ceilings nevertheless change selection opportunities and can indirectly change category influence; putting them in data does not make the policy neutral. Initial equal settings provide a controlled baseline; differing category ceilings should be deliberate, evidence-based changes. No configuration was implemented or accepted by this experiment.

Two separate decisions remain:

1. **Selection:** whether to replace the global cap, which category ceilings to start with, and whether 60% is acceptable for automatic initial assignments as well as suggestions. Acceptance of a number does not settle source ambiguity or overlapping labels.
2. **Comparison/scoring:** how to prevent variable totals and correlated qualities from inflating similarity or recommendation scores. Category ceilings reduce concentration but still allow unequal totals (24 versus 27 here); a broad category with many near-synonyms can have more chances to match. This experiment has no user outcomes and does not validate a normalisation rule. Preserve equal base treatment; do not introduce category weights under the guise of a fairness fix.

If accepted, record ceiling/threshold policy revisions so results can be reproduced. Changing a cap or moving a quality between categories can change the *next proposed selection*, even where quality meaning is unchanged. Do not retroactively alter accepted sets or rescore merely because grouping/configuration changed; explicit association application remains the boundary. This qualifies the earlier category-only no-rescoring rule without changing it. Any future cap field should be separately scoped after task 043's bounded category replacement, not silently added to that task or hard-coded into fixed dimensions.

The six films are familiar and have relatively rich full Wikipedia packets, including reception/production context. They are neither a random seed sample nor plot-only evidence. These results support a concrete policy review, not confidence across obscure/sparse films or a claim of fair personalised recommendations. No production records, definitions or historical rating/recommendation contributions changed.

## Owner follow-up: category-specific controls

After reviewing the experiment, the owner clarified that each category should have its own editable maximum; uniform ceilings were experimental comparisons, not intended product defaults. Subgenres 2 and tropes 4–5 are illustrative starting candidates. The owner also agreed separate admin category-weight tuning, with all weights initially 1. This supersedes the uniform category-3 starting recommendation above as the product direction; no specific complete configuration or scoring formula is adopted. Cap changes affect selection proposals; weight changes affect scoring policy. Neither is permission to silently apply refreshed film associations or rewrite historical results. Implementation and recalculation semantics remain separately scoped.
