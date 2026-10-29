# Ratings scoring design

Status: Agreed conceptual design; scoring implementation deferred.  
Owner: Ratings  
Decision dates: 22, 27 and 28 October 2026

This records the owner discussion preceding task 015. It supersedes earlier brief terminology about separate implicit/explicit scores and mandatory pre-submission profile capture. It does not authorize scoring implementation or prescribe processing infrastructure.

## Recorded evidence and relationships

- RatingFilm has many ratings. Tasks 023/023a implemented replacement reviews while preserving previous submissions and expressions.
- Rating has many rating_expressions: original user-authored text about what they liked or disliked. Preserve the text independently of its interpretation.
- Rating has many rating_qualities: derived scores for the qualities associated with the film.
- RatingQuality belongs to Rating and references a quality. Expressions and rating qualities can have a many-to-many evidence relationship: several expressions can support one rating quality, and one expression can address several rating qualities. Supporting expressions must belong to the same rating. Settle join storage when implementing rating qualities.

Explicit expression links identify direct evidence. Their absence does not distinguish unexpressed from implicitly expressed. Classification is an attribute on RatingQuality, with named constants, not STI: these are changing evidence states with the same behaviour and a straightforward score computation. Do not add these fields or evidence joins in task 015.

## Evidence classifications

Classification applies to a rating quality, not to the shared quality globally.

| Classification | Evidence | Association |
| --- | --- | --- |
| Unexpressed | The overall rating supplies the evidence; no applicable expression or profile interpretation. | Rating and quality; no rating expression. |
| Implicitly expressed | The user's current expression profile provides applicable evidence, without a direct expression for this rating quality. | Rating and quality; interpreted using the current expression profile, with no rating expression. |
| Explicitly expressed | An expression attached to this rating directly addresses the quality. | Rating, quality and supporting rating expressions. |

Use these names rather than strong/weak reinforcement, boosts or adjustments relative to another score. Values are determined by evidence classification × actual rating strength, with the expressed preference informing direction or indifference. Classification identifies the evidence source; it does not itself identify positive or negative sentiment.

An overall rating supplies an implied score for every associated film quality unless applicable expression evidence says otherwise. Explicit evidence takes precedence over profile interpretation. Indifference can yield zero; dislike is distinct from indifference. Missing expression evidence does not imply either. Expressions may contradict the overall rating; do not mechanically multiply two negative values into positive preference evidence.

The initial numeric examples are +1 for unexpressed I Enjoyed That and +2 for unexpressed Brilliant, and +3/+5 respectively with matching explicit praise. These are starting examples, not a complete approved weight table. Exact negative values, profile-informed values and contradictory-sentiment values remain for the scoring spec and evaluation.

## Expression profile and recomputation

The expression profile derives exclusively from explicit expressions. Rating values, derived quality scores and profile-informed inferences must never feed back into it as user statements.

Profile changes trigger recomputation of eligible rating qualities: only unexpressed and implicitly expressed qualities. They may move between those classifications as applicability changes. Explicitly expressed qualities retain their expression provenance and are unaffected by profile-only changes. Changes to their own rating or expressions are a separate reassessment concern.

Implicitly expressed qualities are interpreted against the user's current expression profile, rather than belonging to an individual expression. This conceptual association does not require a per-quality profile foreign key or a captured pre-submission profile in task 015. Later processing must prevent stale work from replacing newer results and distinguish pending recomputation from completed current results; the minimal freshness mechanism belongs in that task's spec.

## Recommendation scoring

Aggregate the user's rating-quality points by quality. Score each eligible recommendation candidate by summing the user's points for its associated qualities. Repeated positive evidence across films raises the matching contribution; negative evidence reduces it. This is the proposed initial additive ranking model.

Owner clarification, 28 October 2026: qualities and categories have equal **base** treatment initially (category multiplier conceptually 1). There is no additional multiplier for global importance, narrative centrality, category prestige or JEV confidence. This does not replace the rating-strength, expressed direction/indifference and evidence-classification rules above; those describe a user's evidence and can produce different contributions. Film-source support probabilities are not preference scores.

System- or user-controlled category weighting is a possible later capability, not an implemented rule or approved control scheme. It must not introduce an assumed subgenre/theme priority now. Film-quality admission and the max-20 selection remain Film knowledge decisions; category weights cannot restore a relevant quality excluded upstream. See [current requirements](film_quality_requirements.md#equal-starting-weights-and-personal-preference).

Reprocessing must replace derived contributions, never accumulate duplicates. Repeated mentions within a rating must not automatically multiply its contribution. Only current applicable scores contribute to current preferences; late processing of superseded inputs must not restore their contributions. The timestamped lifecycle below replaces the earlier conceptual decision to rely solely on highest-ID currentness; task 023 remains an accurate record of what was implemented, not evidence that these new fields exist.

Evaluate common-quality frequency and unequal numbers of film qualities before deciding on normalization. Normalization, complete weights and ranking evaluation remain future scoring work, not requirements for original-expression persistence.

## Historical ratings and quality scores

Owner decision, 27 October 2026:

- Preserve each submitted rating/review and its expressions. Replacements take effect immediately on successful submission; record `superseded_at` on the previous version and optionally `superseded_by_id`. No rating `activated_at`, draft review or user commitment step for now. Consider those later only if frequent incremental replacement demonstrates a need.
- For ratings created by submission, the version's start is its persisted submission time (currently creation time); the previous version ends at the same replacement boundary. A historical version applies when its start is at or before `t` and supersession is absent or after `t`. Do not infer currentness merely from the largest ID once explicit validity is implemented.
- Preserve generated rating-quality scores and their association with the rating version that produced them. Expression-profile changes use the replacement/history pattern to produce new derived results without overwriting historical scores or representing unchanged expressions as fresh user evidence. A system-generated replacement is not a new user endorsement. Exact persistence for these reassessment versions belongs to future Ratings work.
- Submission time and score availability are different when processing is deferred. Recommendation computation must identify which completed score set actually applies; do not pretend newly calculated scores were available at the review's creation. Validity/provenance for completed reassessments and the policy while replacement processing is pending must be settled in that implementation spec. This does not introduce user-facing activation for reviews.
- Recommendations owns persisted recommendation qualities and their calculated score contributions, the recommendation total and scoring-rule version. Computation reads applicable rating qualities and accepted current film-quality associations; historical display uses the saved recommendation result instead of rebuilding it from those domains. Retain source-version references for provenance. New calculations must not overwrite earlier results. Film knowledge owns acceptance of film-quality changes. An independent archive of previous film-quality sets is not required merely to explain these saved scoring results; the FilmAnalysis model decision remains open.
- Qualities have explicit meanings/boundaries for JEV assessment. Preserve the meaning actually assessed in historical explanations through stable concept identities or the minimal required meaning revision/saved content. A mutable name/category reference alone must not silently reinterpret old scores. This does not require storing every former film-quality set.

The podcast/profile/review comparison is a consumer of these histories, not part of standalone film analysis. Use actual engine scores and explain their calculated positive/negative contributions. Comparing new expressions with the earlier expectation must not recompute that earlier expectation against the updated profile.

Current implementation still uses highest Rating ID and immediate submission; supersession timestamps, rating qualities, expression profiles and the scoring engine are not yet implemented. Preserve the existing runtime behaviour until separately scoped work changes it.

## Source refresh and accepted quality changes

Owner direction, 28 October 2026: a Wikipedia/source refresh alone does not trigger new rating-quality scoring. The proposed trigger is a deliberate accepted change to the qualities associated with a film, likely manually reviewed by the community. Definition/meaning changes can also require affected expression-link reassessment; category-only grouping edits do not.

Ratings owns replacing its affected current derived contributions and retains prior historical score sets; Recommendations owns its saved contributions and subsequent recalculation. Preserve original rating values/expressions, avoid duplicate contributions and stale result replacement, and distinguish pending from completed outputs. Exact affected-input selection, acceptance and domain-event contracts remain for separately scoped tasks. No publisher/subscriber or scoring implementation is added by this documentation update.

Historical rating/recommendation quality records capture which qualities contributed and how. They should remain intelligible without independently reconstructing a historical film analysis or association set. Whether Film knowledge needs edit review, rollback or audit history is a separate open decision in [film-quality requirements](film_quality_requirements.md#historical-score-records-and-the-open-model-decision).

## Effect on task 015

Task 015 adds RatingExpression and Rating#rating_expressions, saving raw expressions atomically with the first rating and its existing event. Stable expression identities provide the eventual explicit-evidence references. It adds no RatingQuality, score/classification columns, profile association, interpretation, processing jobs or new event payload fields. Those require separately scoped work. Original expressions can be saved before any film qualities or scoring process exist.

Documentation verification: reviewed against the owner discussion and task 015 scope; no runtime behaviour or numeric scoring implementation is claimed.
