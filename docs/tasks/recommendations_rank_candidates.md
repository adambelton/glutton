# Rank recommendation candidates

Status: Prepared — implementation not started  
Owner: Recommendations

## Goal

Provide independently testable recommendation ranking logic using the viewer's applied Ratings scores and accepted Registry qualities, before building any display or response workflow.

## Agreed decisions

- Implement logic before UI. No page, navigation, posters, explanations or action buttons in this task.
- Use raw sum. Include the actual applied unexpressed, implicitly expressed and explicitly expressed scores; do not substitute rating-only weights or apply another classification multiplier.
- For each quality, sum its signed scores across the viewer's contributing ratings. A candidate's score is the sum of these aggregates for its accepted qualities, counted once each. Unmatched and net-neutral qualities contribute zero.
- No diminishing returns, division by quality count, new weights or fixed quality quota. Investigate observed omission of relevant films before introducing count corrections.
- Five distinct films with current assessed ratings unlock personalized recommendations; notes are optional. No popularity fallback below that threshold.
- Exclude all Library classifications. Ratings dismissal alone does not exclude a candidate.
- Select the next highest-scoring eligible film, defaulting to one result like Ratings selection. Do not impose a positive-score cutoff: zero and negative totals remain rankable.
- Use only scored current rating revisions. When a revision awaits assessment, omit that film's old scores and do not count it toward the assessed-film threshold. Never fall back to a superseded revision.

## Scope

- A Recommendations-owned read operation that loads an active viewer and coordinates evidence reads, eligibility and ranking. Keep the calculation independently testable with explicit input data; use ordinary Ruby objects without a generic ranking framework.
- Read the viewer's current rating revisions and one latest actually applied score set per contributing rating. Retain positive and negative values as recorded by Ratings.
- Read authoritative Library classifications and current accepted Registry film-quality associations. No data projection is needed for these shared reads.
- Return structured data for a future consumer: assessed-film count, unlock state and the selected film identity/score with signed per-quality contributions. Default to selecting one candidate; the interface may accept an explicit bounded batch size consistent with Ratings selection. Do not return the full catalogue by default. Public copy and UI presentation are deferred. Below threshold or with no eligible candidates return no selection, with distinguishable result state.
- Select by descending score, with film ID ascending for exact ties. Selection itself does not consume, dismiss or persist a film; unchanged evidence and eligibility yield the same next candidate. Advancement through recorded responses belongs to the later response workflow. No UI pagination in this task.
- Verify isolation, current/applied score semantics, threshold, signed arithmetic and exclusions, using provider-free tests.

## Scope restrictions

- Task preparation only in this chat; no implementation started.
- No controllers, routes, navigation, UI, generated explanations, served-result history, response persistence, Library actions, event contracts or delivery changes.
- No Ratings/Registry mutations, model assessment or provider calls. Recommendations consumes applied score results, not raw evaluation output or profile text.
- Review the deferred applied-score read boundary before implementation. Prefer the smallest existing-model read. If a Ratings-owned scope/query must be added, agree its inputs/result shape and implement it in a separate Ratings-owned task; do not disguise a Ratings change inside this task or invent an API only to avoid shared reads.
- Preserve existing identity access controls and domain failures. Missing/inactive viewers must not receive personalized results or be silently treated as a new viewer.
- Quality-count bias, thin context and broad quality definitions remain monitoring concerns, not new Registry work here.

## Implementation boundary review

- The owner has resolved score selection and pending-revision semantics. Resolve exact read/result interfaces during implementation planning using those agreed rules. Any new Ratings-owned read behavior requires its own scoped workflow.
- Library exclusions are eventually consistent with completed-rating delivery. Before implementation, verify whether the existing exclusion contract is sufficient during that gap or needs an explicit owner decision; do not silently introduce another source of eligibility state.

## Acceptance criteria

- **AC1:** Evidence belongs only to the active viewer; each contributing film supplies one rating revision and one latest actually applied score set. Superseded revisions/sets and recorded-but-unapplied evaluations do not contribute. An unassessed current revision contributes no scores, even if its previous revision was assessed.  
  Check: tests for viewer isolation, missing/inactive viewers, historical revisions/sets, unapplied evaluations and the agreed pending-revision policy.  
  Result: Not run.
- **AC2:** Raw-sum arithmetic uses the stored score unchanged for all three classifications. Negative matches reduce scores; neutral/unmatched qualities add zero; distinct matches retain their full contribution.  
  Check: controlled mixed-sign and classification examples with expected per-quality totals and candidate scores, including a sparse strong match outranking a dense weak match.  
  Result: Not run.
- **AC3:** Every Library classification excludes its film; Ratings dismissal alone does not. Other viewers' classifications have no effect.  
  Check: eligibility cases and the explicitly agreed delivery-gap behavior.  
  Result: Not run.
- **AC4:** Five distinct assessed current films unlock results; fewer return no recommendations and accurate progress. Notes are not required. Duplicate history cannot inflate progress.  
  Check: below/at-threshold cases and the agreed pending-revision policy.  
  Result: Not run.
- **AC5:** Selection defaults to the highest-scoring eligible film without a score cutoff, breaks ties deterministically, and repeats unchanged for unchanged input without any data mutation or provider calls.  
  Check: default single-result selection, no eligible candidates, equal scores, all-zero/all-negative candidates and repeat-read cases; focused service tests and `bin/rails test`. Browser tests are unnecessary for this logic-only task.  
  Result: Not run.

## Implementation notes

Not implemented. This amends and renames the original page draft to reflect the owner's logic-first direction; it is not an additional outcome. Investigation artefacts were removed at the owner's request. No application or development-data changes in task preparation.

Review handoff: Task prepared with owner scoring decisions recorded. Implementation not started; review the read boundary and existing eventual-consistency contract before coding.
