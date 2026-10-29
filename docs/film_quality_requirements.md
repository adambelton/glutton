# Film qualities, sources and reassessment

Status: Current direction and open design questions, 29 October 2026  
Owner: Film knowledge

This replaces the former film-analysis dossier requirements. It defines the intended direction, not the current schema. FilmAnalysis, AnalysisQuality, the generative analysis path and fixed dimensions still exist until separately scoped work replaces or removes them.

## Purpose and vocabulary

Glutton owns useful descriptions of a viewer's relationship with horror. Vocabulary membership should have a plausible relationship to enjoyment or avoidance; that editorial hypothesis must not become a film-level centrality or importance gate. Detectability, trope occurrence or reuse across films alone is insufficient. “Humans are the real monsters” expresses a consequential moral outlook; a possessed prop or a broken telephone may simply describe plot mechanics.

The [working vocabulary](film_qualities/MASTER_LIST.md) has 235 provisional candidates after reviewing the original approximately 250. It is a starting point, not a final taxonomy or a set of validated preference predictors. The retained baseline supplies explicit definitions and exclusions. Preference relevance remains an editorial hypothesis, not guidance sent to JEV. A film has **at most 20 accepted qualities**, never a quota. Avoid padding and redundant associations; a cap alone does not validate additive scoring or prevent correlated evidence from being counted repeatedly.

Qualities and **quality categories** are editable product data. Categories organise qualities; they are not hard-coded dimensions, behavioural subclasses or mutually exclusive options. Their names do not imply built-in scoring priority. New categories must not require deployment. Keep a quality's identity when its meaning is unchanged, including category moves and cosmetic renames. Changed meaning, splits and merges need explicit interpretation/reassessment rather than silently reusing an identifier. Retire referenced qualities instead of destroying the meaning of historical score records.

[Task 043](specs/043_editable_quality_categories.md) plans the bounded replacement of code-managed dimensions. It does not decide the fate of FilmAnalysis or implement scoring.

## Equal starting weights and personal preference

Owner decision, 28 October 2026: all admitted qualities begin with equal base treatment, and every quality category has the same baseline multiplier (conceptually 1). Do not add a global multiplier based on a quality's theme, category, narrative centrality, JEV importance answer or model confidence. This is a baseline design decision, not a new weight column or implemented scoring formula.

Film-wide centrality is different from influence on an individual's enjoyment. The test favoured greed because its question explicitly rewarded central conflict and moral outlook. Minimal dialogue is a viewing-form characteristic that can matter more to a particular viewer. It remains eligible on the same basis as a theme when its definition and source support are satisfied. A meaningful quality need not be the central plot concern or occupy many screen minutes.

The initial workflow should identify source-supported qualities without an additional defining-importance gate. Retain supported candidates for inspection; do not discard them merely because JEV considers them secondary. The max-20 accepted set still needs a selection policy: support probability alone is confidence in evidence, not preference value, and equal weights do not resolve which 20 should be selected. Review redundancy and preference usefulness without imposing category quotas or a theme-over-presentation hierarchy. Future weights cannot recover a useful quality that was excluded from the film beforehand.

Equal base treatment does not make every user's derived contribution identical. Actual rating strength, explicit appreciation/dislike/indifference and the agreed evidence classifications can still produce different contributions under Ratings rules. Keep those user-derived distinctions separate from an additional intrinsic quality/category weight.

Later, category weights might be system-controlled or user-controlled—for example, greater emphasis on subgenres than narrative devices. Controller, learning method, semantics, UI, persistence and recalculation policy remain open. Do not implement controls or a presumed system preference now; preserve the equal baseline and editable categories so the idea can be evaluated later.

## Source material and film updates

Wikipedia supplies maintained narrative/context material. Retain the relevant page identity, source revision and attribution/licence with imported material. BFI may supplement useful gaps; screenplay processing and model-led research are not prerequisites for a useful seed. Glutton should focus community effort on quality meanings, evidence and accepted film-quality associations rather than duplicating Wikipedia's encyclopaedic editing operation.

A Wikipedia page update is a **source refresh**, not an accepted change to a film's qualities. It may be punctuation, credits, a corrected scene or a substantial reinterpretation. Do not automatically evaluate every quality, publish changed associations or rescore users merely because a revision was fetched. Refresh may make review useful; exact detection, notification, refresh cadence and UI remain open.

A source record/version or a minimal current assignment revision used for freshness does not require a permanent archive of every former film-quality set. Source provenance, editorial audit and historical scoring are different needs; retain each only for an identified purpose.

Source descriptions must distinguish depicted events, attributed responses, supported interpretation and production intentions. A script does not prove finished-film sound or imagery; an unmade plan does not establish an achieved effect. Lack of evidence is unknown, not absence. A critic's response is not a universal viewer response or evidence that a future user will enjoy the film. Copies of one account are not independent corroboration.

## JEV: questions and request packing remain to be agreed

JEV is the chosen engine. It evaluates supplied context and explicit quality meanings; it should not do heavy research or invent the vocabulary. Film matching, expression interpretation and preference direction/strength are separate judgments. A Noul probability of film presence is not a preference weight or a score contribution.

### Neutral matching baseline

Owner clarification, 28 October 2026: the initial JEV evaluation asks whether each defined quality is supported in the supplied film context. Do not ask it to favour qualities that are important, influential, defining, desirable, useful for recommendations or likely to affect enjoyment. Do not supply category priorities or instructions to prefer themes over presentation. Such guidance requires a deliberate, separately evaluated experiment with evidence before adoption.

The [retained matching contract](film_qualities/matching.json) asks: **“Do the supplied source_paragraphs support [quality] in this film?”** It supplies each quality's definition and exclusion, together with the shared source-evidence policy. The 235 current [definitions](film_qualities/vocabulary.json) are the ones used in the latest six-film test. They retain concept-specific meaning (for example, duration in “sustained dread”) without a blanket importance hurdle. They remain provisional and can evolve; known semantic ambiguity is not a reason to block the seed or endlessly fit these six films.

Keep all per-quality support probabilities available for inspection before any top-20 truncation. The cap remains a product constraint, not a model instruction to invent a quota or a reason to suppress contextually supported matches. No new production threshold or selection rule is established here.

Quantify contextual correctness using source-linked reference judgments prepared independently of the model output: supported, contradicted or not established, and uncertain. Review false matches and missed supported qualities separately. Report the number judged and uncertain, supported-assignment rate among adjudicated assignments, and missed-supported rate within a fully adjudicated reference set. A selected-output review alone cannot measure recall; a small reference subset cannot establish full-vocabulary recall. Do not count missing source evidence as proof the quality is absent from the film. Keep source coverage and definition ambiguity visible. Cost is a separate measurement. This requires human semantic review to produce meaningful numbers; no enjoyment, narrative-importance or preference-quality score is part of this baseline.

Two decisions must not be conflated:

1. **Logical judgment:** evaluate a defined quality independently when several qualities can coexist. Supply a self-contained definition, useful exclusions and relevant film or expression context. Do not make qualities compete for one winner just because they share a category.
2. **Request packing:** independent questions can share a request. “One question per quality” does not mean “one HTTP request per quality”.

| Packing option | Useful property | Tradeoff / question to resolve |
| --- | --- | --- |
| One quality per request | Easy isolation and targeted reassessment | Repeats shared source context; extra round trips and failure handling |
| Several qualities per request | Shares context, with a bounded retry/failure unit | Batch size and grouping need justification; categories alone are not a semantic dependency |
| All relevant qualities in one request | Avoids repeated state and assembles one matching result | Must fit context, remain inspectable and define incomplete/failure handling |

TypeSafe recommends bundling questions that share state. Current official documentation describes state ingestion once, questions evaluated in parallel, and limits of 64k tokens per request and 32k for state plus each question, with no separate question-count cap. These capabilities support discussion; they do not establish an optimal Glutton batch size. [Fan-out guidance](https://docs.typesafe.ai/patterns/fan-out), [model limits](https://docs.typesafe.ai/models), [Noul criteria](https://docs.typesafe.ai/primitives/noul). Checked 28 October 2026.

Open: which evidence each judgment receives; whether to send the entire relevant vocabulary or a justified subset; question/criteria wording; neutral support wording (salience and preference-strength guidance are outside the initial matching baseline); grouping/size; thresholds; evidence-link collection; timeouts, failure handling and cost limits. The earlier research batch of 50 is an experiment setting, not a production decision. No additional calls or integration is authorised here.

The [retained findings](research/film_quality_findings.md) summarise feasibility, cost and limits. The [six uncapped examples](film_qualities/examples.json) preserve original source paragraphs/provenance, all 1,410 probabilities and the 318 matched-candidate review records. These are inspection examples, not accepted associations, validated preferences or a production threshold policy. Superseded tuning artifacts were removed at the owner's request.

### Next design step: selection and community review

Owner decision, 29 October 2026: further tuning of individual film-quality probabilities is not a prerequisite. Focus on how source-backed candidates become a useful reviewed set of at most 20, and how community contributors can inspect evidence, add/remove qualities and publish accepted changes. Keep ambiguity visible for review; do not silently turn model confidence into importance or impose category priorities.

Selection criteria, handling of overlapping qualities and uncertain evidence, contributor permissions, review/publishing mechanics and downstream contracts remain open. This direction does not implement or pre-authorise those workflows. A broader sample can inform the design without requiring perfect matches on the current examples.

### Prompt ownership and Langfuse

No JEV prompt migration is required to proceed. The question template and quality meanings are retained locally in the [working baseline](film_qualities/README.md); completed requests/responses were already recorded in Langfuse. Community-maintained quality definitions are product data. Future management of the shared question template in Langfuse may be useful, but is optional and does not transfer ownership of quality definitions or establish a runtime remote-prompt dependency.

## Accepted film-quality changes and downstream effects

Proposed boundary from the owner discussion: a deliberate, accepted change to a film's associated qualities—likely community-reviewed/manual—makes affected scoring eligible for reassessment. Fetching source text, editing a draft, requesting a JEV assessment and receiving candidate matches do not by themselves change accepted qualities.

No actual association change means no downstream scoring change. A category-only rename or move does not alter quality meaning and should not rescore by itself. A definition/meaning revision can require reassessing affected film and expression links, separately from an article refresh. The exact acceptance/editing workflow remains to be designed.

Film knowledge owns the vocabulary and accepted film associations. Ratings owns interpretation and replacement of derived rating-quality contributions. Recommendations owns recomputed recommendations and their saved contributions. Use the agreed durable asynchronous domain-event mechanism where other domains must react; agree event meaning, payload, ordering, delivery, duplicates, failure handling and retention before implementing publishers/subscribers in separate tasks. No event contract is invented by this document. Shared reads remain permitted.

Keep original ratings and expression text unchanged. Replace affected current derived contributions without double counting. Reject late work for superseded inputs and distinguish pending/stale results from completed current results. Profile-only changes still leave directly expressed evidence unaffected; semantic changes to that quality or its expression link are a separate reassessment reason. The [Ratings scoring design](ratings_scoring_design.md) remains authoritative for Ratings rules.

## Historical score records and the open model decision

Rating qualities preserve which qualities, evidence/classifications and scores contributed to their historical rating assessments. Recommendation qualities preserve the actual contributions, totals and scoring-rule identity used when a recommendation was computed. Historical explanations read those saved results rather than rebuilding them from the film's current qualities or the user's current profile. A later calculation produces a new result; do not overwrite an earlier result or backdate its availability.

Ensure historical records still convey the quality meaning actually assessed. A mutable reference alone is insufficient if its meaning can be changed in place: choose stable concept identities, referenced meaning revisions or the necessary saved explanatory content when specifying scoring. This does not imply archiving every historical film-quality association set.

**Open proposal:** replace standalone generated analyses with sourced film information and directly managed current film-quality associations. FilmAnalysis/AnalysisQuality should not be retained solely because historical scores need to be explained; those records already belong to Ratings and Recommendations. There is presently no agreed requirement to reconstruct every former film-quality set independently.

Before deleting or replacing models, decide whether they serve a separate concrete purpose: community edit review, rollback, source evidence, film-detail presentation, concurrency or audit. Identify the minimum retained data for that purpose. A reviewable pending edit and a current-assignment revision do not automatically require a permanent film-analysis lifecycle. Conversely, community correction/rollback should not be assumed solved merely by having recommendation history.

No decision to drop FilmAnalysis, migrate/delete existing analyses or alter publication invariants is made here. That work needs a separately scoped Film knowledge task after these questions are resolved. The category task must remain useful under either outcome.

## Presentation

Expose useful source-backed film information and accepted qualities with appropriate spoiler labelling, evidence/context and a way to report inaccuracies. Source narrative, film traits and personal recommendation explanations have different responsibilities even if no independent analysis model remains. Do not invent predicted scene reactions beyond actual engine outputs. Direct access need not require Library watched status; normal watched-library navigation can carry a spoiler warning. Community acceptance/review UI, Wikipedia refresh UI and any podcast comparison presentation remain separately scoped.
