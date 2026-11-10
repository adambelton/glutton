# Public interface audit handoff

Date: 9 November 2026  
Reviewing supporting area: Foundation / repository review  
Baseline: local `08e81085e225f13d7329934587b9c96b3cd770eb`, with unrelated Ratings selection UI work in progress.

This review examines application-defined public methods and their production and test callers. Four findings concern a parallel lifecycle used only by tests, delivery lifecycle rules implemented outside their model, and internal helpers exposed publicly. Prior audit findings are not assumed to remain open.

## Recheck — 10 November 2026

All four original findings are resolved in the current tree. The original evidence below is retained as the historical review, including its former class names and paths.

| Finding | Current evidence | Status |
| --- | --- | --- |
| P1 Ratings evaluation lifecycle | `RatingQualityEval.record!` is shared by production and model tests. `ScoreRatingQualities#record_and_apply` records and calls `Rating#apply_quality_evaluation!` in one transaction, rolling back an unapplied duplicate. The former `build_from_assessment` / `record_and_apply!` evaluation lifecycle is absent; score-row construction is private to Rating. The AI design document describes this same lifecycle. Service tests cover stale ratings, competing/profile applications and atomic storage rollback. | Resolved |
| P2 EventDelivery lifecycle | `EventDelivery` owns `due_for_attempt?`, `start_attempt!`, `skip!`, valid `complete!` outcomes and `record_failure!` returning retrying/failed. `DomainEvents::Delivery::Deliver` delegates those decisions while retaining loading, locks, dispatch and rollback coordination. Delivery tests cover ordering, rollback/retry, terminal/manual retry, invalid outcomes and inactive owners. | Resolved |
| P3 Watched-film lookup | `LibraryFilmWatched#rated?` is private; status/action methods and the preloaded-association optimization remain. | Resolved |
| P4 Assessment helpers | `GenerateTasteProfile#synthesis_input` is private. `EvaluateExplicitQualities` loads its JSON contract during initialization; the former public configuration class method is absent. Provider evidence remains available. | Resolved |

This recheck does not authorize additional domain changes. The deferred applied-score read contract is separate from these findings and will be revisited at Recommendations integration. Verification: `PARALLEL_WORKERS=1 bin/rails test` passed with 714 tests and 8,622 assertions, including the existing Ratings, Library and delivery regression tests. Autoload and RuboCop checks passed. Browser tests and live providers were not run for this recheck. This is a recheck of the four reported findings, not a new exhaustive public-interface audit.

## Instructions for the receiving agent

Recheck the evidence against the current tree. Read AGENTS.md, the implementation plan, relevant domain contracts and current working records before changing code. Create a scoped working record for each independently verifiable owned outcome. This report is review evidence, not implementation approval across all domains. Preserve ongoing work and keep each fix with its relevant tests.

Do not mechanically hide Active Record associations, legitimate shared reads, meaningful action-permission predicates, framework callbacks or provider injection points. Small interfaces should keep behaviour with its owner, rather than replace raw getters with new getters that still make callers perform the operation. No new generic workflow or result framework is needed.

## P1 Medium Consolidate the Ratings evaluation lifecycle used by tests and production

Owner: Ratings.

Evidence: `app/models/ratings/rating_quality_eval.rb:9-24,40-48`; `app/services/ratings/assess_rating_qualities.rb:40`; `test/models/ratings/rating_quality_eval_test.rb:73-153`; `test/services/ratings/assess_rating_qualities_test.rb:112-114`.

Production constructs an evaluation through `build_from_assessment` and invokes `record_and_apply!`. Only tests call the separate `record!` and `apply_quality_scores!` path. This exposes two lifecycles: production atomically saves and applies a completed result, while tests can persist an unapplied attempt and apply it later. The paths also differ in duplicate handling: one returns without application, while the other raises. Tests of the second path therefore do not establish the first path's contract, and the application carries a second operation with no current production caller.

Choose one supported Ratings lifecycle and have behavioural tests exercise it. Reconcile the public entry point with `docs/ai_model_services_design.md`, which explicitly specifies `record!(subject:, assessment:)` and a named application action while requiring completed-only workflows to record and apply atomically. Do not simply delete `record!` without resolving that documented convention. If recording unapplied attempts is intended product behaviour, document its use and failure/recovery contract; otherwise remove that alternative public lifecycle. Keep explicit storage-contract tests separate from behaviour setup.

Verification: the supported production entry point covers persisted score rows, atomic rollback, stale ratings, old profile revisions, competing applications and the agreed duplicate outcome. Tests must not need a second production API solely to construct these scenarios. Preserve Registry's separately documented failed-attempt retention semantics.

## P2 Medium Move delivery lifecycle decisions and mutation into EventDelivery

Owner: Foundation domain-event delivery.

Evidence: `app/services/domain_events/deliver.rb:12,20,31-32`; `app/models/domain_events/event_delivery.rb:19-34`.

`Deliver` decides whether a receipt is due by combining its raw status and timestamp, increments `attempts` through a generic writer, and interprets status again after `record_failure!` to decide between `:failed` and `:retrying`. Thus the model's public operations do not encapsulate the lifecycle: callers must know which fields to inspect and mutate, and in which order. `complete!` also relies on the caller to constrain the outcome.

Give the delivery model ownership of attempt eligibility, attempt recording and valid completion/failure transitions. Let the operation communicate its outcome rather than requiring a caller to rediscover it from persisted status. Keep entity loading, locks, transactions and subscriber dispatch in the coordinator. Preserve the narrow Foundation contract; do not introduce a generic workflow engine.

Verification: exercise dispatch outcomes and persisted receipts for not-due work, ordered predecessors, inactive owners, successful or ignored handling, handler rollback, retry delay, terminal failure and manual retry. Preserve the attempt counter and rollback boundaries, including failure recording after subscriber rollback. `retry!` is a legitimate public operation used by the maintenance rake task.

## P3 Low Keep watched-film rating lookup private

Owner: Library.

Evidence: `app/models/library/library_film_watched.rb:6-22`.

`rated?` is public but is only called by this object's `rating_status`, `can_rate?` and `can_edit_rating?` methods. It exposes the lookup used to implement those public decisions, giving future callers another route to reconstruct permissions externally.

Make this helper private and retain the existing public status and action-permission methods. Keep the read-only association and its loaded-association optimization: cross-domain reading and preloading are permitted and are not themselves interface defects.

Verification: existing rendered status and action tests still distinguish rated and awaiting-rating films. Do not introduce tests of the private helper or a new public accessor to replace it.

## P4 Low Hide assessment input and configuration construction helpers

Owner: Ratings.

Evidence: `app/services/ratings/expression_profile_assessment.rb:36-42,64`; `app/services/ratings/explicit_quality_assessment.rb:3-5,13`.

`ExpressionProfileAssessment#synthesis_input` is public even though only its own provider-request method uses it. `ExplicitQualityAssessment.configuration` is public even though only its own initializer loads it. Neither needs external access in the current production or test call sites. These methods expose provider input assembly and local configuration loading alongside the intended assessment interface.

Keep those helpers internal, retaining construction, `call` and the completed `result` contract. Adjust the internal configuration call when making a class method private. Do not hide provider metadata needed to build immutable evaluation evidence or change configured question policy as part of this cleanup.

Verification: assessment tests observe the request supplied to the injected provider and the completed result, including validation failures. Avoid direct assertions on the newly private helper methods.

## Boundaries retained

Action-specific predicates such as `can_apply_quality_evaluation?` are legitimate model rules. Evaluation outputs are explicit immutable audit contracts; their existence is not automatically an implementation leak. Provider configuration and model metadata have production uses in that evidence. Shared associations and revision reads are allowed by the domain and AI workflow contracts. Lack of an HTTP caller alone does not make console-facing domain actions such as Registry recategorisation test-only APIs.

## Verification and limits

Static review of method visibility, call sites, relevant tests and documented ownership contracts. No application code or tests were changed, and no suites or paid provider calls were run. Unrelated Ratings UI changes and working records were preserved. Findings describe the checked local tree; dynamic invocation and external console consumers cannot be exhaustively established from repository searches.
