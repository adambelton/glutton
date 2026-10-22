# 015 — Original expressions with a rating

Status: Ready for review — implemented 22 October 2026  
Owner: Ratings / expressions

## Goal

Save zero or more original viewer-authored expressions together with a first rating and its existing RatingSubmitted event. One independently verifiable outcome: the complete submission commits, or none of it does.

Read the implementation plan, product brief section 3.1, architecture brief sections 5–6 and their later Ratings clarifications, task 014 and docs/ratings_event_publication.md. Consume existing Identity lifecycle and Foundation publication contracts without changing them. The earlier seen-confirmation, submission-revision and profile-capture proposals are not prerequisites for this persistence task.

## Scope

### Original expression storage

- Add RatingExpression belonging to Rating, with required original text and standard timestamps. Rating exposes `has_many :rating_expressions`. Derive user and film ownership through Rating → RatingFilm; do not duplicate their IDs or introduce a submission wrapper.
- Store each submitted expression independently. Preserve wording, capitalization, punctuation, line breaks and surrounding whitespace for nonblank text; no stripping, rewriting, translation, deduplication, tagging or sentiment inference. Repeated text is valid.
- Reject empty or whitespace-only expressions rather than silently dropping input. An empty collection represents a rating without expressions. Unused UI fields can be handled explicitly in the later UI task.
- Approved bounded input: at most 20 expressions per rating, at most 2,000 characters per expression. These are input limits, not semantic analysis rules. Define limits as named model constants and use them in validation/tests; keep persisted storage constraints independent of runtime constants.
- Store text in a non-null text column with a required foreign key to Rating, cascading on physical rating deletion. Enforce the text-length ceiling in the database as well as model validation. Do not invent unique-text constraints, position columns, extra timestamps or revision state. Return expressions in insertion/ID order when enumerating the saved collection.

### Submission contract

- Extend `Ratings::SubmitRating.call(user_id:, rating_film_id:, value:, expression_texts: [])`, retaining its returned Rating and existing callers. The new input is an array of original strings. Omission or an empty array preserves rating-only behaviour; nil, a scalar, a hash or non-string elements are invalid, without string coercion.
- Existing fresh-owner and candidate locks, permissions and failure precedence remain. Missing/inactive owner, missing/foreign candidate and already-rated outcomes keep the task 014 errors. Explicit submission of a dismissed candidate remains allowed and preserves its dismissal/creation time.
- Ratings models own collection/content validation and expression persistence; the service coordinates the established locked transaction and publication. Use Rails `accepts_nested_attributes_for :rating_expressions` for child construction and saving. The submission accepts only original strings and maps them to text-only nested attributes; expression IDs and deletion flags are not accepted. Do not add a separate public expression-save service, endpoint, callback-driven publication or custom nested-input framework.
- Malformed expression collections (wrong container/element type or too many entries) raise `Ratings::InvalidExpressions` with a localized message. Blank or overlong expression text raises `ActiveRecord::RecordInvalid` with localized symbolic validation errors. The boundary checks are justified by externally supplied collection/text values; internal user/rating collaborators remain trusted roles.
- Save the rating and all expressions before publishing the existing event, inside the same savepoint. Any invalid expression, persistence error, publication error or enclosing rollback leaves no rating, expression or event. A partial submission must never be reported as successful.
- Retain first-rating uniqueness. Repeating the submission, with identical or different expressions, raises AlreadyRated and leaves the original text intact. This task does not append expressions to an existing rating; task 024 owns later edits/removals and their revision semantics.

### Publication and lifecycle

- Keep RatingSubmitted version 1, stream identity and exact payload unchanged: user_id, film_id, rating_id, value. Emit one event per completed rating, after its expressions have been persisted in the same transaction. No raw expression text, expression IDs/counts or additional expression event are needed by current cross-domain consumers.
- No scoring, profile updates, jobs or AI/provider calls. Original input must be durable independently of future processing; do not prebuild pending-work state without the separately approved processing task.
- Expressions are private through their rating ownership. Physical guest cleanup cascades User → RatingFilm → Rating → RatingExpression and existing event storage, preserving shared Film rows. Guest claim preserves expression/rating IDs and exact text. Verify with existing Identity operations; no Identity implementation changes.
- Put all new application-authored errors and attribute labels in English Rails locales. User-entered expression text is never translated or placed in error messages, logs or event payloads by this change.

## Scope restrictions

- Follow the [agreed scoring design](../ratings_scoring_design.md) for terminology and future relationships. This task captures original evidence only; stable RatingExpression IDs enable future explicit RatingQuality references. Do not add `rating_qualities` associations before that model exists, classification/score fields, or expression-profile capture.
- Ratings only. No Library, Identity, Foundation, Film or Recommendations implementation changes; no subscribers, routes, forms, presentation changes or deployment.
- No rating revisions, expression editing/deletion API, additional submission/history object, inferred qualities, expression profiles, scoring weights, moderation, public sharing or synthetic expressions.
- No general model/scope cleanup. Add only associations, actions and validation needed for this atomic submission path.
- Only test-database migrations during verification. Owner approved implementation, input limits and blank/malformed-input failures on 22 October 2026.

## Acceptance criteria

- **AC1:** A first rating stores zero or multiple original expressions with ownership and exact text preserved.
  Check: omitted/empty inputs, multiple expressions in input order, Unicode, punctuation/newlines/surrounding whitespace, duplicates, dismissed candidates, rating-only compatibility and all four rating choices. Reload persisted values rather than inspecting only in-memory objects.
  Result: Passed — focused Ratings checks: 46 tests / 429 assertions. Reloaded expression text covers Unicode, whitespace, duplicates and input order; omitted/empty collections, all rating choices and dismissed candidates remain supported.
- **AC2:** Invalid input fails explicitly without partial persistence.
  Check: nil/scalar/hash collections, non-string or string-coercible elements, empty/whitespace-only text, count/length limits and one over each, invalid rating, missing/foreign/inactive owner/candidate, duplicate submission. Verify named constants and strict localized errors without echoing original text.
  Result: Passed — focused checks cover malformed collections without coercion, blank/overlong text, inclusive character/count bounds, existing permission failures and duplicate precedence. Model validation uses symbolic localized errors; boundary errors do not echo submitted text.
- **AC3:** Rating, expressions and publication are atomic, with lifecycle and privacy guarantees preserved.
  Check: invalid later expression and injected expression-persistence/publication failures; caller rollback; savepoint remains usable after a rescued failure; exact unchanged event payload and one event; separate-connection competing submissions save only the winner's complete expression set. Verify cleanup and claim, including races against submission, with real Identity operations. Validation-bypass storage tests cover required reference/text, FK and length. No other-domain writes or processing jobs are introduced.
  Result: Passed — focused checks inject expression and event database constraint failures and verify complete rollback plus usable enclosing transactions. Caller rollback, exact v1 payload, competing submissions, guest expiry/cleanup and registration claim pass. Expression identities/text survive claim; physical cleanup cascades them. Direct inserts verify NOT NULL, FK and character-length constraints.
- **AC4:** Repository checks pass and evidence describes the actual implementation.
  Check: focused Rating/RatingExpression and Ratings service tests; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record exact focused paths/results, test-only migration commands and any limitations; update the publication document's source-atomicity explanation without changing its v1 payload.
  Result: Passed — focused command: `RAILS_ENV=test bin/rails test test/models/rating_expression_test.rb test/models/rating_test.rb test/models/rating_persistence_test.rb test/services/ratings` (46 tests / 429 assertions). Full CI: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` (348 tests / 3,607 assertions; style and security checks clean). `RAILS_ENV=test bin/rails zeitwerk:check` passed for application code with the existing mailer-preview exclusion notice. `git diff --check` passed. Migration: `RAILS_ENV=test bin/rails db:migrate`; only the test database was migrated.

## Implementation notes

Added RatingExpression, the ordered Rating#rating_expressions association, model-owned collection validation and Rails nested-attribute construction, and atomic saving through the existing submission service. Rails saves newly built expressions with the rating; the service publishes afterward within its existing savepoint. Added required cascading foreign key, non-null text and database length constraint, with localized errors and labels. No other-domain runtime changes or scoring machinery. Updated scoring documentation to record classification as an attribute (not STI) and the future many-to-many evidence relationship.

Verification notes: initial sandboxed database commands could not connect to PostgreSQL; approved escalated test commands succeeded. The first full CI run passed all tests/security checks but caught one extra blank line; corrected before the final CI run. Development and production databases were not migrated. Owner review and merge remain pending.

Owner acceptance / merge: Pending.

Review follow-up: owner requested Rails nested attributes. Removed the custom capture_expressions method; RatingFilm validates the external collection after duplicate permission checks, then creates the rating with text-only nested attributes. Rating declares accepts_nested_attributes_for with the named count limit. Verification: repeated the focused command above (46 tests / 429 assertions) and full CI (348 tests / 3,607 assertions, style/security clean); both passed. `git diff --check` passed. Existing rollback, malformed-input, duplicate, cleanup and claim tests passed unchanged.
