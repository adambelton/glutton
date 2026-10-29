# Film-quality working baseline

This is the retained starting material for selecting and reviewing film qualities. It replaces the superseded tuning research folders. Requirements and lifecycle decisions remain in [film qualities, sources and reassessment](../film_quality_requirements.md).

- [MASTER_LIST.md](MASTER_LIST.md): readable list of 235 provisional qualities, meanings and exclusions.
- [vocabulary.json](vocabulary.json): the same data for future implementation. IDs, names, categories and definitions are unchanged from the latest test. No viewer-preference validation or accepted film associations are implied.
- [matching.json](matching.json): the current shared JEV question template and evidence policy. It preserves the tested independent contextual-support judgment without importance or category priorities.
- [examples.json](examples.json): six source-provenanced uncapped examples, all 1,410 support probabilities and the 318 matched-candidate review records. These are historical examples for selection/review work, not production data or a new scoring rule.
- [Findings and limitations](../research/film_quality_findings.md): compact experiment receipt and the decision to stop fine tuning as a prerequisite.

## Using the matching contract

For each quality, substitute its `name` into `question_template`; use its `match_rule` as `criteria.true` and substitute its `not_sufficient` into `false_criterion_template` as `criteria.false`. All questions have the recorded `question_type`. They can share state containing the film title, unmodified source paragraphs and the recorded evidence policy. The reconstructed question set is identical to the latest tested one.

Quality categories organise the vocabulary but are not sent as ranking instructions. Editorial hypotheses about what a viewer should prefer are not matching evidence. A support probability is neither a recommendation weight nor an importance score. Preserve uncertain evidence as uncertain, rather than calling it film absence.

The example match/uncertain bands were inspection settings only. No top-20 truncation has been applied to these examples. Each review refers to paragraph IDs in that same example's `source_paragraphs`, with source revision and attribution/licence retained alongside them. Interpretive reviewer judgments are not independent ground truth.

## Next work

Design how candidates become a reviewed set of at most 20 accepted qualities, and how community contributors inspect evidence, add/remove qualities and publish accepted changes. Known ambiguity is review work; perfecting these six films is not a prerequisite. Definitions can evolve later with explicit reassessment of affected associations and derived scores, while preserving original user input and historical contribution records.

[Task 043](../specs/043_editable_quality_categories.md) remains the separately scoped replacement of fixed dimensions with editable categories. Selection policy, publishing permissions and other workflow details remain open; these files do not implement or pre-authorise them.

## Langfuse

Exact requests/responses from the completed experiments were already traced in Langfuse. No migration of the JEV questions is needed to proceed. Keep community-owned quality meanings as product data; future management of the shared question template in Langfuse is an optional implementation choice. These local files are the current baseline, with no runtime dependency on a remote prompt. Existing traces are retained; local raw dumps and replay scripts were deliberately removed.
