# AI model services design

AI workflows turn versioned domain evidence into a validated assessment, an immutable evaluation and a durable product result. The owning domain defines the rules for applying that result.

Before implementing or changing an AI pipeline, map its entry point, assessment, provider adapter, evaluation and result models to the roles below in the working task. Compare the mapping with the nearest existing workflow. Record intentional differences in input, evidence, application, failure retention, retry policy and traces. Resolve unclear ownership before writing code.

## Roles

| Role | Owns |
| --- | --- |
| Orchestration service | The domain entry point. Loads the subject and current evidence, checks access and eligibility, and coordinates assessment, freshness checks, locking, transactions, recording and application. Names the workflow by its outcome, such as `AssessRatingQualities`. |
| Assessment object | Builds the provider-facing input from captured evidence, owns domain questions or synthesis instructions, and produces a completed, validated result. Interprets answers through domain rules. Handles deterministic paths such as baseline scoring or clearing a profile with no expressions. Receives a provider collaborator so tests can supply stubbed responses. |
| Provider adapter | Owns protocol details, authentication, model settings, response parsing and validation of the external response shape. Enforces the approved request, timeout and cost limits. Supplies the actual non-secret settings and usage to the assessment. Reuse shared transport and adapters for the protocols they already support. |
| Evaluation model | Uses `record!` with the domain subject and `assessment:` named explicitly, such as `record!(rating:, assessment:)`. Saves `assessment.result` as the immutable `output` snapshot, validates its shape and references, and owns the named application action. For completed-only workflows, `record!` can own the atomic operation and keep the named application step private. Expose separate recording and application only when the workflow needs to retain unapplied attempts or apply them later. |
| Result model | Owns the durable product outcome and its invariants. Links to the exact evaluation that produced it. Retains prior results when the domain needs history. Stores the applied values and the source versions needed to use the result. The orchestration service uses those versions to decide when to refresh. Product reads use the result model. The evaluation is the audit record for inputs, provider output and the decisions behind the result. |

## Lifecycle and failure handling

The service captures the minimum inputs the assessment needs, including authoritative versions and access scope. Call the provider outside write locks. Before applying the result, acquire the owning lock and re-read the inputs and any current result that could have changed. Reject stale work. When the workflow records completed evaluations only, save the evaluation and its application atomically. When a workflow retains failed or unapplied attempts, record application status separately and define how failures and recovery affect the existing product result. Job retries, duplicate delivery, unchanged input, and a provider timeout with uncertain billing need explicit outcomes in the task.

## Evidence and configuration

Store the source versions and input snapshot, the questions or instructions used, validated responses, deterministic decisions and actual non-secret provider settings where applicable. The evidence must explain the saved result after the inputs or policy change. Keep scoring values and other product rules in the owning domain's models or model modules. Keep provider configuration with the adapter. Load non-secret model settings and request limits from configuration files such as `config/typesafe.json` and `config/expression_profile_synthesis.json`. Reuse the lifecycle pattern across domains while each domain retains its own evaluation model and result semantics.

## Tracing and privacy

Define fixed workflow trace names and tags as `TRACE_NAME` and `TRACE_TAGS` on the orchestration service. Use them for the root span and propagate the relevant tags and environment to generation observations. Link spans to the persisted evaluation, and include model and usage on generation spans. Keep credentials, private expressions and private model payloads out of trace attributes and exception details. Any payload capture must follow the domain's explicit privacy policy.

## Verification

Use stubbed provider responses to verify input and output boundaries, result linkage, invalid responses, stale inputs, duplicate application, and rollback or failure retention. Use in-memory spans to verify hierarchy, metadata and privacy. Exercise the workflow's actual service entry point and its model application rules. Live provider calls and hosted trace export require their own authorization and verification.

## Reference implementations

- **Ratings quality assessment.** [AssessRatingQualities](../app/services/ratings/assess_rating_qualities.rb) delegates to [RatingQualityAssessment](../app/services/ratings/rating_quality_assessment.rb), which combines the explicit and implicit judgments. [RatingQualityEval](../app/models/ratings/rating_quality_eval.rb) uses `record!(rating:, assessment:)` to check applicability with `Rating`, record the completed assessment, and apply [RatingQuality](../app/models/ratings/rating_quality.rb) rows in one transaction. Duplicate or older candidates return without recording or applying.
- **Registry initial assignment.** [AssignInitialFilmQualities](../app/services/registry/assign_initial_film_qualities.rb) delegates to [InitialQualityAssessment](../app/services/registry/initial_quality_assessment.rb). [FilmQualityEval](../app/models/registry/film_quality_eval.rb) retains failed attempts and tracks application to [FilmQuality](../app/models/registry/film_quality.rb) separately.
- **Ratings expression-profile refresh.** [RefreshExpressionProfile](../app/services/ratings/refresh_expression_profile.rb) delegates to [ExpressionProfileAssessment](../app/services/ratings/expression_profile_assessment.rb). [ExpressionProfileEval](../app/models/ratings/expression_profile_eval.rb) records the completed result and applies it through the [ExpressionProfile](../app/models/ratings/expression_profile.rb) parent. Each immutable [ExpressionProfileRevision](../app/models/ratings/expression_profile_revision.rb) owns the applied profile text and retains its evaluation link. The refresh service compares saved expression texts per film.
