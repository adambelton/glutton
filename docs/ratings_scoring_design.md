# Ratings scoring design

Status: Agreed conceptual design; scoring implementation deferred.  
Owner: Ratings  
Decision dates: 22 and 27 October 2026

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

Reprocessing must replace derived contributions, never accumulate duplicates. Repeated mentions within a rating must not automatically multiply its contribution. Only current applicable scores contribute to current preferences; late processing of superseded inputs must not restore their contributions. The timestamped lifecycle below replaces the earlier conceptual decision to rely solely on highest-ID currentness; task 023 remains an accurate record of what was implemented, not evidence that these new fields exist.

Evaluate common-quality frequency and unequal numbers of film qualities before deciding on normalization. Normalization, complete weights and ranking evaluation remain future scoring work, not requirements for original-expression persistence.

## Historical ratings and quality scores

Owner decision, 27 October 2026:

- Preserve each submitted rating/review and its expressions. Replacements take effect immediately on successful submission; record `superseded_at` on the previous version and optionally `superseded_by_id`. No rating `activated_at`, draft review or user commitment step for now. Consider those later only if frequent incremental replacement demonstrates a need.
- For ratings created by submission, the version's start is its persisted submission time (currently creation time); the previous version ends at the same replacement boundary. A historical version applies when its start is at or before `t` and supersession is absent or after `t`. Do not infer currentness merely from the largest ID once explicit validity is implemented.
- Preserve generated rating-quality scores and their association with the rating version that produced them. Expression-profile changes use the replacement/history pattern to produce new derived results without overwriting historical scores or representing unchanged expressions as fresh user evidence. A system-generated replacement is not a new user endorsement. Exact persistence for these reassessment versions belongs to future Ratings work.
- Submission time and score availability are different when processing is deferred. Recommendation computation must identify which completed score set actually applies; do not pretend newly calculated scores were available at the review's creation. Validity/provenance for completed reassessments and the policy while replacement processing is pending must be settled in that implementation spec. This does not introduce user-facing activation for reviews.
- Recommendations owns persisted recommendation qualities and their calculated score contributions, the recommendation total and scoring-rule version. Computation reads applicable rating qualities and analysis qualities; historical display uses the saved recommendation result instead of rebuilding it from those domains. Retain source-version references for provenance. New calculations must not overwrite earlier results. Analysis activation and supersession belong to Film knowledge; Ratings does not duplicate those association histories.
- Quality names should convey their meaning without an additional definition field. A materially different concept gets a distinct identity; cosmetic wording changes must not silently change historical interpretation.

The podcast/profile/review comparison is a consumer of these histories, not part of standalone film analysis. Use actual engine scores and explain their calculated positive/negative contributions. Comparing new expressions with the earlier expectation must not recompute that earlier expectation against the updated profile.

Current implementation still uses highest Rating ID and immediate submission; supersession timestamps, rating qualities, expression profiles and the scoring engine are not yet implemented. Preserve the existing runtime behaviour until separately scoped work changes it.

## Effect on task 015

Task 015 adds RatingExpression and Rating#rating_expressions, saving raw expressions atomically with the first rating and its existing event. Stable expression identities provide the eventual explicit-evidence references. It adds no RatingQuality, score/classification columns, profile association, interpretation, processing jobs or new event payload fields. Those require separately scoped work. Original expressions can be saved before any film qualities or scoring process exist.

Documentation verification: reviewed against the owner discussion and task 015 scope; no runtime behaviour or numeric scoring implementation is claimed.
