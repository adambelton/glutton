# AI model services design

AI workflows turn versioned domain evidence into a validated assessment, an immutable evaluation and a durable product result. The owning domain defines the rules for applying that result.

Before implementing or changing an AI pipeline, map its entry point, assessment, provider adapter, evaluation and result models to the roles below in the working task. Compare the mapping with the nearest existing workflow. Record intentional differences in input, evidence, application, failure retention, retry policy and traces. Resolve unclear ownership before writing code.

## Roles

| Role | Owns |
| --- | --- |
| Orchestration service | The domain entry point. Loads the subject and current evidence, checks access and eligibility, and coordinates assessment, freshness checks, locking, transactions, recording and application. Names the workflow by its outcome, such as `AssessRatingQualities`. |
| Assessment object | Builds the provider-facing input from captured evidence, owns domain questions or synthesis instructions, and produces a completed, validated result. Interprets answers through domain rules. Handles deterministic paths such as baseline scoring or clearing a profile with no notes. Receives a provider collaborator so tests can supply stubbed responses. |
| Configured client | Owns provider authentication and transport, including timeout and retry defaults. Shared adapters can also handle reusable protocol parsing and provider-wide limits. The assessment owns workflow-specific request settings, the expected result shape, and domain failures. |
| Evaluation model | Uses `record!` with the domain subject and `assessment:` named explicitly, such as `record!(rating:, assessment:)`. Saves ordered provider requests in immutable `input` and `assessment.result` in immutable `output`. Validates the evidence and exposes assessed results to the owning aggregate. |
| Aggregate | Owns applicability and the named application action. `Film` applies film qualities, `Rating` applies rating scores, and `TasteProfile` publishes profile revisions. The orchestration service coordinates recording and application in one transaction when required. |
| Result model | Owns the durable product outcome and its invariants. Links to the exact evaluation that produced it. Retains prior results when the domain needs history. Stores the applied values and the source versions needed to use the result. The orchestration service uses those versions to decide when to refresh. Product reads use the result model. |

Reuse the configured client directly when its SDK or shared transport already supports the call. The assessment supplies the workflow-specific request settings, schema and interpretation. The configured client owns authentication, transport, timeout and retry defaults. Add an adapter only for a concrete provider capability the configured client lacks, and record the approved difference from the closest workflow before implementing it.

## Lifecycle and failure handling

The service captures the minimum inputs the assessment needs, including authoritative versions and access scope. Call the provider outside write locks. Before applying the result, acquire the owning lock and re-read the inputs and any current result that could have changed. Reject stale work. When the workflow records completed evaluations only, save the evaluation and its application atomically. When a workflow retains failed or unapplied assessments, keep the evaluation focused on the assessment. The result records what applied. Define how application failures surface and how recovery affects the existing result. Job retries, duplicate delivery, unchanged input, and a provider timeout with uncertain billing need explicit outcomes in the task.

## Evidence and configuration

Keep the structured requests actually sent in `input`, including their phase and non-secret provider settings. Keep received responses and validated decisions in `output`. Deterministic results have no provider requests. Reused evidence retains its source evaluation link. Store source versions so the evidence explains the applied result. The evidence must explain the saved result after the inputs or policy change. Keep scoring values and other product rules in the owning domain's models or model modules. Load non-secret model settings and request limits from configuration files such as `config/typesafe.json` and `config/taste_profile_synthesis.json`. Reuse the lifecycle pattern across domains while each domain retains its own evaluation model and result semantics.

## Tracing and privacy

Define fixed workflow trace names and tags as `TRACE_NAME` and `TRACE_TAGS` on the orchestration service. Use them for the root span and propagate the relevant tags and environment to generation observations. Link spans to the persisted evaluation, and include model and usage on generation spans. Keep credentials, private notes and private model payloads out of trace attributes and exception details. Any payload capture must follow the domain's explicit privacy policy.

## Verification

Use stubbed provider responses to verify input and output boundaries, result linkage, invalid responses, stale inputs, duplicate application, and rollback or failure retention. Use in-memory spans to verify hierarchy, metadata and privacy. Exercise the workflow's actual service entry point and its model application rules. Live provider calls and hosted trace export require their own authorization and verification.

## Reference implementations

- **Ratings quality assessment.** [AssessRatingQualities](../app/services/ratings/assess_rating_qualities.rb) delegates to [RatingQualityAssessment](../app/services/ratings/rating_quality_assessment.rb), which combines the explicit and implicit judgments. [RatingQualityEval](../app/models/ratings/rating_quality_eval.rb) records the assessment and [Rating](../app/models/ratings/rating.rb) applies the scores in the same transaction. Duplicate or older candidates leave no new evaluation or scores.
- **Registry initial assignment.** [AssignInitialFilmQualities](../app/services/registry/assign_initial_film_qualities.rb) delegates to [InitialQualityAssessment](../app/services/registry/initial_quality_assessment.rb). [FilmQualityEval](../app/models/registry/film_quality_eval.rb) retains failed assessments. Film applies the completed assessment to create authoritative [FilmQuality](../app/models/registry/film_quality.rb) associations.
- **Ratings taste-profile refresh.** [RefreshTasteProfile](../app/services/ratings/refresh_taste_profile.rb) delegates to [TasteProfileAssessment](../app/services/ratings/taste_profile_assessment.rb), which calls the OpenAI client configured by the [AI initializer](../config/initializers/ai.rb). [TasteProfileRevisionEval](../app/models/ratings/taste_profile_revision_eval.rb) records the completed assessment. The [TasteProfile](../app/models/ratings/taste_profile.rb) parent publishes the revision. Each immutable [TasteProfileRevision](../app/models/ratings/taste_profile_revision.rb) owns the applied profile text and retains its evaluation link. The refresh service compares saved notes per film.
