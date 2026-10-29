# Film qualities, sources and reassessment

Status: Current direction and open design questions, 29 October 2026  
Owner: Film knowledge

This replaces the former film-analysis dossier requirements. Owner decision: remove FilmAnalysis and AnalysisQuality. The model roles are Quality, QualityCategory, Film and FilmQuality (the film–quality link). Task 054 implements direct current film qualities/source context and retires the generated-analysis path; task 043 supplies persisted categories. Tasks 055/056 simplify local migration history and rebuild development/test from scratch under owner authorisation. These changes remain unmerged and undeployed.

## Purpose and vocabulary

Glutton owns useful descriptions of a viewer's relationship with horror. Vocabulary membership should have a plausible relationship to enjoyment or avoidance; that editorial hypothesis must not become a film-level centrality or importance gate. Detectability, trope occurrence or reuse across films alone is insufficient. “Humans are the real monsters” expresses a consequential moral outlook; a possessed prop or a broken telephone may simply describe plot mechanics.

The [working vocabulary](film_qualities/MASTER_LIST.md) has 235 provisional candidates after reviewing the original approximately 250. It is a starting point, not a final taxonomy or a set of validated preference predictors. The retained baseline supplies explicit definitions and exclusions. Preference relevance remains an editorial hypothesis, not guidance sent to JEV. Selection uses **a maximum stored against each category**, rather than one global maximum of 20. Category limits can differ; they are ceilings, never quotas. Exact initial limits remain to be chosen. Avoid padding and redundant associations; a cap alone does not validate additive scoring or prevent correlated evidence from being counted repeatedly.

Qualities and **quality categories** are editable product data. Categories organise qualities; they are not hard-coded dimensions, behavioural subclasses or mutually exclusive options. Their names do not imply built-in scoring priority. New categories must not require deployment. Keep a quality's identity when its meaning is unchanged, including category moves. Quality names are immutable after creation; definitions/exclusions may be tuned within the same concept. Category names remain editable. A new meaning requires an explicit new concept rather than repurposing an existing name. Changed meaning, splits and merges need explicit interpretation/reassessment rather than silently reusing an identifier. Retire referenced qualities instead of destroying the meaning of historical score records.

**Owner direction, 29 October:** use individually configurable category maximums and a separate admin category weight. Subgenres at 2 and tropes at 4–5 are starting candidates, not settled defaults; the proposed support minimum is 60%. All category weights start at 1. The [task-053 experiment](research/quality_selection_policy_053.md) used uniform ceilings only to compare effects, not to prescribe identical limits. These controls are planned product data, not implemented settings. No category minimum, automatic association changes or user-facing weighting controls are implied. Category spread alone does not resolve unequal totals or validate recommendation fairness.

[Task 043](specs/043_editable_quality_categories.md) implements persisted category configuration, ready for review. Task 054 removes its temporary analysis compatibility and renames the shared vocabulary to Quality. Neither implements selection/scoring. Baseline maxima are subgenres 2; tropes/situations 5; narrative devices 3; themes 4; ironies/reversals 2; character/social dynamics 3; presentation/intensity 4; emotional tone/experience 3; resolution/aftermath 2, with every weight 1. [Seed data](../config/quality_categories.yml) supplies defaults without resetting later tuning. The 60% support gate remains a baseline for the next selection slice.

## Equal starting weights and personal preference

Owner decision, 28 October 2026: all admitted qualities begin with equal base treatment, and every quality category has the same baseline multiplier (conceptually 1). Do not add a global multiplier based on a quality's theme, category, narrative centrality, JEV importance answer or model confidence. This is a baseline design decision, not a new weight column or implemented scoring formula.

Film-wide centrality is different from influence on an individual's enjoyment. The test favoured greed because its question explicitly rewarded central conflict and moral outlook. Minimal dialogue is a viewing-form characteristic that can matter more to a particular viewer. It remains eligible on the same basis as a theme when its definition and source support are satisfied. A meaningful quality need not be the central plot concern or occupy many screen minutes.

The initial workflow should identify source-supported qualities without an additional defining-importance gate. Retain supported candidates for inspection; do not discard them merely because JEV considers them secondary. Selection within each category ceiling still needs an explicit policy: support probability alone is confidence in evidence, not preference value, and equal weights do not resolve which candidates should occupy each category's slots. Review redundancy and preference usefulness without imposing category quotas or a theme-over-presentation hierarchy. Future weights cannot recover a useful quality that was excluded from the film beforehand.

Equal base treatment does not make every user's derived contribution identical. Actual rating strength, explicit appreciation/dislike/indifference and the agreed evidence classifications can still produce different contributions under Ratings rules. Keep those user-derived distinctions separate from an additional intrinsic quality/category weight.

Admin tuning should expose two independent controls: a category maximum governing film-quality selection, and a category weight governing its contribution to scoring. Category maxima may differ without changing the initial equal-weight baseline. Changing a maximum affects future assignment/suggestion policy; it must not silently alter accepted film associations. A weight change affects scoring policy, not JEV presence judgments or film membership; specify its recalculation/versioning behaviour in separately owned scoring tasks, preserving historical explanations. These controls have different ownership effects and must not be bundled into a cross-domain mutation. Admins control them initially; user controls and automated learning remain later possibilities.

## Source material and film updates

Wikipedia supplies maintained narrative/context material. Retain the relevant page identity, source revision and attribution/licence with imported material. BFI may supplement useful gaps; screenplay processing and model-led research are not prerequisites for a useful seed. Initial-release improvements to quality meanings, evidence and film associations are admin-only; community editing is deferred. Plot corrections belong on Wikipedia, rather than in a second Glutton plot editor.

A Wikipedia page update is a **source refresh**, not an accepted change to a film's qualities. It may be punctuation, credits, a corrected scene or a substantial reinterpretation. Do not publish changed associations or rescore users merely because a revision was fetched. Admin manual sync from TMDB, Wikipedia or both should run a follow-up quality check, even if source content is unchanged, and compare the proposed category-limited set with current accepted qualities. Show additions/removals and preserve manual corrections until an explicit admin apply action. A successful source sync and a failed/stale check are separate visible outcomes; no-change checks do not trigger rescoring. Use the initial assignment selection policy and record source/meaning/model/question/policy versions so changes can be investigated. Scheduled sync quality-check policy remains open. Periodic syncing is the preferred initial approach for both TMDB metadata and Wikipedia context; provider-specific cadence, change detection, retries and operating limits remain open. No callback mechanism is assumed.

A source record/version or a minimal current assignment revision used for freshness does not require a permanent archive of every former film-quality set. Source provenance, editorial audit and historical scoring are different needs; retain each only for an identified purpose.

Source descriptions must distinguish depicted events, attributed responses, supported interpretation and production intentions. A script does not prove finished-film sound or imagery; an unmade plan does not establish an achieved effect. Lack of evidence is unknown, not absence. A critic's response is not a universal viewer response or evidence that a future user will enjoy the film. Copies of one account are not independent corroboration.

## JEV: questions and request packing remain to be agreed

JEV is the chosen engine. It evaluates supplied context and explicit quality meanings; it should not do heavy research or invent the vocabulary. Film matching, expression interpretation and preference direction/strength are separate judgments. A Noul probability of film presence is not a preference weight or a score contribution.

### Neutral matching baseline

Owner clarification, 28 October 2026: the initial JEV evaluation asks whether each defined quality is supported in the supplied film context. Do not ask it to favour qualities that are important, influential, defining, desirable, useful for recommendations or likely to affect enjoyment. Do not supply category priorities or instructions to prefer themes over presentation. Such guidance requires a deliberate, separately evaluated experiment with evidence before adoption.

The [retained matching contract](film_qualities/matching.json) asks: **“Do the supplied source_paragraphs support [quality] in this film?”** It supplies each quality's definition and exclusion, together with the shared source-evidence policy. The 235 current [definitions](film_qualities/vocabulary.json) are the ones used in the latest six-film test. They retain concept-specific meaning (for example, duration in “sustained dread”) without a blanket importance hurdle. They remain provisional and can evolve; known semantic ambiguity is not a reason to block the seed or endlessly fit these six films.

Keep all per-quality support probabilities available for inspection before category-limit selection. The cap remains a product constraint, not a model instruction to invent a quota or a reason to suppress contextually supported matches. No new production threshold or selection rule is established here.

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

### Initial-release scope: enrichment and admin improvement

Owner clarification, 29 October 2026: import films from TMDB, enrich them with Wikipedia plot/context and assign qualities within each category's configured maximum. Bulk seed and ordinary users' missing-film imports via TMDB search use the same canonical pipeline, without requiring manual review of every imported film. Deduplicate by TMDB identity; distinguish pending/failed source enrichment and assignment from completion. Import retries and source sync must not overwrite later admin quality corrections. Importing a canonical film does not itself create a personal Library entry.

The automated initial within-category selection policy remains to be agreed: equal base treatment and contextual probabilities do not by themselves choose the useful candidates within each category ceiling. This needs a bounded practical decision, not another open-ended tuning project. Keep the retained uncapped results inspectable. No automatic importance ranking, category quota or production threshold is established by this scope clarification.

Three admin-only interfaces support continuous improvement:

- **Quality library:** inspect definitions/exclusions, categories and associated films; tune definitions within a concept. Quality names are immutable. New concepts require explicit creation rather than renaming or repurposing existing qualities.
- **Canonical film library:** inspect metadata, source context/provenance, sync/check status and current quality associations; manually sync either provider or both, inspect the resulting quality comparison, and add/remove existing qualities with evidence and category-limit/freshness validation. Plot corrections happen on Wikipedia.
- **Expression investigation/testing:** examine a user's expression in film context against existing definitions and associations. Distinguish missing vocabulary, missing film links, weak definition/matching, category-level preferences and uncertain evidence. Compare proposed adjustments against positive/negative/untouched cases before separate explicit application. Tests and suggestions do not mutate production data or establish category weights.

These admin screens are distinct from user TMDB search/import and personal Library management. Community submissions, publishing permissions, moderation and reputation are deferred. Authorised read-only inspection of Ratings evidence does not transfer ownership of expressions/profiles; admin access and minimal context must be specified before implementing that interface. JEV evaluates defined candidates; automatic invention of new vocabulary is not required. The [revised task-052 proposal](film_quality_review_workflow.md) details the scope and optional worked example; it does not authorise implementation or new provider calls.

### Prompt ownership and Langfuse

No JEV prompt migration is required to proceed. The question template and quality meanings are retained locally in the [working baseline](film_qualities/README.md); completed requests/responses were already recorded in Langfuse. Community-maintained quality definitions are product data. Future management of the shared question template in Langfuse may be useful, but is optional and does not transfer ownership of quality definitions or establish a runtime remote-prompt dependency.

## Accepted film-quality changes and downstream effects

Proposed boundary from the owner discussion: a deliberate, accepted change to a film's associated qualities—initially through system assignment or deliberate admin correction—makes affected scoring eligible for reassessment. Fetching source text, editing a draft, requesting a JEV assessment and receiving candidate matches do not by themselves change accepted qualities.

No actual association change means no downstream scoring change. A category-only rename or move does not alter quality meaning and should not rescore by itself. A definition/meaning revision can require reassessing affected film and expression links, separately from an article refresh. Initial association assignment and deliberate admin changes need explicit apply/freshness semantics; public community editing is outside the initial release.

Film knowledge owns the vocabulary and accepted film associations. Ratings owns interpretation and replacement of derived rating-quality contributions. Recommendations owns recomputed recommendations and their saved contributions. Use the agreed durable asynchronous domain-event mechanism where other domains must react; agree event meaning, payload, ordering, delivery, duplicates, failure handling and retention before implementing publishers/subscribers in separate tasks. No event contract is invented by this document. Shared reads remain permitted.

Keep original ratings and expression text unchanged. Replace affected current derived contributions without double counting. Reject late work for superseded inputs and distinguish pending/stale results from completed current results. Profile-only changes still leave directly expressed evidence unaffected; semantic changes to that quality or its expression link are a separate reassessment reason. The [Ratings scoring design](ratings_scoring_design.md) remains authoritative for Ratings rules.

## Historical score records and the open model decision

Rating qualities preserve which qualities, evidence/classifications and scores contributed to their historical rating assessments. Recommendation qualities preserve the actual contributions, totals and scoring-rule identity used when a recommendation was computed. Historical explanations read those saved results rather than rebuilding them from the film's current qualities or the user's current profile. A later calculation produces a new result; do not overwrite an earlier result or backdate its availability.

Ensure historical records still convey the quality meaning actually assessed. A mutable reference alone is insufficient if its meaning can be changed in place: choose stable concept identities, referenced meaning revisions or the necessary saved explanatory content when specifying scoring. This does not imply archiving every historical film-quality association set.

**Owner decision, 29 October:** use Quality for a shared vocabulary concept, QualityCategory for grouping/configuration, Film for canonical metadata/current source context and FilmQuality for its current accepted association to a Quality. No FilmAnalysis/AnalysisQuality lifecycle or independent archive of every former association set is required.

[Task 054](specs/054_direct_film_qualities.md) supplies direct film links and removes the analysis runtime. Owner subsequently confirmed all development data is disposable and authorised a complete reset. [Task 055](specs/055_simplify_catalogue_migrations.md) replaces the original analysis migration and intermediate conversions with direct catalogue creation; no legacy analysis import, archive or draft-migration guard remains necessary. Task 056 folds other correction migrations into table creation without changing the final schema contracts. Development/test have been rebuilt; historical task-054 verification records describe the superseded intermediate conversion only.

Source syncing, source/evidence retention, admin changes and suggestion application still require their bounded operations. No storage migration or source refresh itself publishes scoring-change events or rewrites another domain's historical results. Historical delivery specs/migrations remain records of the former implementation.

## Presentation

Expose useful source-backed film information and accepted qualities with appropriate spoiler labelling, evidence/context and a way to report inaccuracies. Source narrative, film traits and personal recommendation explanations have different responsibilities even if no independent analysis model remains. Do not invent predicted scene reactions beyond actual engine outputs. Direct access need not require Library watched status; normal watched-library navigation can carry a spoiler warning. Admin editors and expression investigation/testing, Wikipedia refresh status and any podcast comparison presentation remain separately scoped. Community editing is deferred.
