# 014 — First rating submission and publication

Status: Ready for review — implemented 21 October 2026  
Owner: Ratings / ratings

## Goal

Save a user's first four-level rating for an existing RatingFilm, remove it from pending candidate selection, and durably publish the completed rating in the same transaction. One independently verifiable outcome: a submitted rating is stored and available for future consumers without synchronous Library changes.

Read docs/implementation_plan.md, task 013, product brief section 3.1 and its later candidate clarifications, architecture brief section 6 and its later clarifications, and docs/domain_events.md. Consume the delivered Foundation publication contract; no consumer changes. The approved rating-or-dismiss flow supersedes earlier requirements for a separate seen confirmation.

## Scope

### Rating persistence and action

- Add `Rating` belonging to `RatingFilm`; add `RatingFilm.has_many :ratings`. Ownership and film identity come through that relationship, without duplicate user/film columns or a separate submission/history model.
- Store required `value` and standard Rails timestamps. Named frozen constants in the nested `Rating::Values` module define each choice; callers and tests reference those constants, with `Rating::Values::ALL` for validation/enumeration. The migration retains literal storage values independently of runtime code. Values are stable strings `brilliant`, `enjoyed`, `not_for_me`, `garbage`, representing the existing four product choices. English labels live in Rails locales. They are choices, not finalized scoring weights. Do not introduce numeric taste scores or an inference model.
- This task accepts the first rating only. Enforce one rating per RatingFilm in the database for now, plus required reference/value and allowed-value constraints. The collection association leaves the API suitable for future rating history; task 023 must explicitly extend storage and define current-rating/revision semantics before allowing multiple submissions. Do not prebuild version counters or a generic history framework.
- `Ratings::SubmitRating.call(user_id:, rating_film_id:, value:)` returns the persisted Rating. Resolve and lock the fresh active owner, then its RatingFilm, delegate submission permission/action to the model, and commit the rating and event together in a savepoint. No catalogue admission or arbitrary film lookup/create path.
- Missing/expired/deleted owners raise existing `Ratings::IdentityUnavailable`; missing/foreign candidates raise existing `Ratings::FilmUnavailable`. A candidate with an existing rating raises `Ratings::AlreadyRated`, including a repeated identical value. Invalid values raise `ActiveRecord::RecordInvalid` with localized symbolic errors. Invalid input must not be silently coerced into a valid choice. Caller rollback, validation failure or publication failure leaves no rating or event.
- Submitting a rating is explicit viewing evidence; no separate seen question, seen timestamp, prior presentation or Library watched record is required. A dismissed candidate may be rated by an explicit submission: dismissal only controls automatic rotation. Preserve its dismissal flag and created_at. The later targeted-entry task supplies the Library UI entry point, not a new persistence permission.
- Ratings remain private to their owner. Physical owner cleanup cascades RatingFilm and its ratings; guest claim preserves IDs and saved values. Film references remain restrictive. Verify using existing Identity operations without changing Identity.

### Candidate scopes

- `rated` means a RatingFilm has at least one associated rating; `unrated` means none. Implement as composable database scopes without duplicating candidate rows.
- `pending` means unrated and not dismissed. Keep `dismissed` independent: a candidate can be both rated and dismissed. No `undismissed` scope or independent rated flag.
- NextCandidates retains oldest-first created_at/ID ordering, limit behavior and owner checks, and now excludes rated films through `pending`. Tests cover all four combinations of rating existence and dismissal.
- Candidate creation/selection/dismissal alone publishes no rating event. Do not create ratings from Library facts or fabricate a rating to satisfy a scope.

### Published contract (v1)

- Define `Ratings::EVENTS_PUBLISHING_DOMAIN = "ratings"` and `Ratings::Events::RATING_SUBMITTED = "RatingSubmitted"` together in `app/services/ratings.rb`, following the agreed Library convention. Freeze string constants; no centralized publisher registry.
- Publish using `DomainEvents::Publish` inside the source transaction. Stream owner is the user; stream key is `film:<internal film ID>`. It does not depend on a deletable rating ID. Schema version is 1.
- Payload contains exactly `user_id`, `film_id`, `rating_id`, `value`. The event means the owner explicitly submitted this rating and therefore supplies completed-viewing evidence. Values use the stable strings above. No email, credentials, expressions, serialized models or speculative preference data.
- The Foundation envelope supplies ID, sequence, occurred_at, correlation and causation. A direct action starts a correlation with no causation ID. Source failure publishes nothing; notification failure after commit relies on Foundation recovery rather than rolling back committed input.
- Record the v1 contract in a Ratings publication document. Future Library/Recommendations consumers must define their own retained-event bootstrap, supported versions, ordering and duplicate handling. No subscriptions, synchronous fallback or manual replay mechanism is added here. Version 1 becomes an immutable published contract once implemented; incompatible changes require another schema version.
- Owner cleanup cascades events under the existing Foundation contract. Guest claim retains owner/stream identity. Do not add age-based event purging.

## Scope restrictions

- Ratings only. No Library/Identity/Film/Foundation implementation changes; no subscriber, route, UI, catalogue replenishment, watched-event admission, recommendation query, expressions, AI, preference scoring or deployment.
- Rating revisions/editing and `RatingRevised` publication remain task 023. This deliberately narrows the earlier broad 014 plan; initial submission is independently verifiable. No update/delete API for ratings in this task.
- Do not revive presentation history, extra queue timestamps, unseen responses or synchronous Library mutation. Do not infer interest from dismissal.
- Only test-database migrations during verification. All new application-authored labels, validation and domain errors belong in Rails locales. Existing locking, active-owner and durable-publication contracts remain unchanged.
- Owner approved this spec on 21 October 2026, including first-submission-only storage, the four value identifiers and event payload. Implementation is authorized; acceptance and merge remain separate.

## Acceptance criteria

- **AC1:** Each valid choice produces one owned rating; invalid and duplicate attempts have explicit failures without side effects.
  Check: four choices, missing/foreign/inactive owners, invalid values including blank/out-of-set/coercible inputs, repeat identical/different submissions, dismissed-candidate submission, unchanged candidate creation/dismissal and absence of Library changes. Verify model-owned action rules and locale rendering.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/rating_test.rb test/models/rating_persistence_test.rb test/services/ratings`: 37 tests / 319 assertions across AC1–AC3. Covers all four values, nil/blank/unknown/coercible input, duplicate same/different values, missing/foreign/inactive owners, dismissed submission with preserved candidate timestamps, no Library writes, model-owned action and strict English translations.
- **AC2:** Rated/unrated/pending/dismissed scopes express the agreed states and candidate ordering remains oldest-first.
  Check: all four rating/dismissal combinations across owners; bounded queue excludes rated/dismissed entries without duplicate rows or changes to timestamps; rating existence is the source of truth.
  Result: Passed — focused model/queue tests cover all four rating/dismissal combinations, owner isolation, composable scopes and bounded oldest-first selection. The existing queue tests retain creation-time/ID tie coverage. Selection and dismissal publish no rating events; explicit submission does not alter candidate creation/dismissal state.
- **AC3:** Rating and v1 event commit atomically and survive supported lifecycle changes.
  Check: exact payload/envelope ownership/name/version/stream, one event per first submission, no event from rejection/dismissal/selection; injected publication failure and caller rollback; separate-connection competing submissions yield one success and one AlreadyRated; expiry/cleanup and claim races; database constraints with validation bypass; cleanup removes owned ratings/events and preserves Film, claim retains activity.
  Result: Passed — focused tests verify exact v1 payload/envelope, source and event rollback on caller rollback and injected database publication failure, and usable enclosing transactions after rejection. Six additional separate-connection/lifecycle tests cover duplicate submissions, expiry while waiting, cleanup before submission, saved-activity cleanup, claim before submission and claim racing cleanup. Validation-bypass inserts verify required reference/value, foreign key, allowed values and first-rating uniqueness. Existing candidate tests verify restrictive Film references.
- **AC4:** Repository checks pass without crossing task boundaries.
  Check: record focused Ratings test paths/results, run `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, and `git diff --check`. Verify strict English locale resolution and document publication contract and limitations.
  Result: Passed — applied `RAILS_ENV=test bin/rails db:migrate` to the test database only. Final `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 338 tests / 3,494 assertions, zero failures/errors/skips; RuboCop 185 files clean, dependency audits clean, Brakeman zero warnings/errors. Initial CI found one extra blank line in the concurrency test; fixed it and reran full CI successfully. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing test-mail-preview exclusion notice. `git diff --check` passed. Published the [v1 contract](../ratings_event_publication.md). No development/production migration, UI or consumer verification was performed.

## Implementation notes

Implemented `Rating`, the `RatingFilm.ratings` association and model-owned first-submission permission/action, `Ratings::SubmitRating`, `Ratings::AlreadyRated`, four localized choices and domain-owned publication constants. The service locks the owner and candidate, coordinates model creation and publication, and returns the Rating. Validation checks `value_before_type_cast` so Rails string casting cannot silently accept symbols or string-coercible inputs. Database constraints enforce required valid values, references and one first submission.

`rated` and `unrated` use rating-ID subqueries so they compose without duplicate candidate rows; `pending` adds the existing dismissal filter. Ratings cascade through the candidate during owner cleanup. No other domain implementation changed and no extra history object was introduced. The first-rating uniqueness constraint is intentionally limited to this task; revisions and any schema change remain subject to task 023 approval. No scope deviations.

Spec approval: Owner approved implementation on 21 October 2026.

Review follow-up: replaced the flat value array with `Rating::Values::{BRILLIANT, ENJOYED, NOT_FOR_ME, GARBAGE}` and `ALL`. Validation and Ratings tests use these constants; historical migration literals and locale keys remain stable. Re-ran `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/rating_test.rb test/models/rating_persistence_test.rb test/services/ratings`: 37 tests / 319 assertions passed. Targeted RuboCop on the four changed Ruby files and `git diff --check` passed. Subsequent combined full CI after the Foundation 001k status-constant follow-up passed: 338 tests / 3,494 assertions, style/security checks clean. This includes the rating constant changes.

Implementation acceptance / merge: Pending.
