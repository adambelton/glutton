# 017 — Ratings admission, holds and dismissal from Library events

Status: Ready for review — implemented 22 October 2026  
Owner: Ratings / Library-event consumer

## Goal

React to Library activity using the existing RatingFilm: watched events admit a film for rating, watchlist activity temporarily holds/releases it, and not-interested events dismiss it indefinitely from automatic rotation. Preserve saved ratings, original expressions and candidate identity. Ratings owns only its own eligibility decisions, not a copy of Library state.

Read the implementation plan's superseding candidate-batch policy, architecture brief, docs/domain_events.md, docs/library_event_publication.md, docs/domain_event_operations.md and specs 013–016. Use established Library v1 facts, Foundation delivery and Identity/catalogue roles. This task adds no Library provider behaviour.

## Scope

### Event contract and reactions

Register one stable Ratings-owned subscription for FilmMarkedWatched, FilmMarkedNotInterested, FilmAddedToWatchlist and FilmRemovedFromWatchlist using Library's publisher/name constants. Consume schema v1 and validate only the envelope and user/film identifiers needed to apply it, including agreement with stream owner/key. The event name supplies the reaction; do not duplicate the publisher's whole payload validation or interpret unused fields. Unsupported versions, malformed required identifiers and missing Film fail through existing retries/terminal-failure handling.

| Library event | RatingFilm absent | RatingFilm exists |
| --- | --- | --- |
| FilmMarkedWatched | Create an undismissed, unheld RatingFilm using normal timestamps. | Release any hold; preserve dismissal, ratings, expressions and created_at. |
| FilmAddedToWatchlist | Create a held, undismissed RatingFilm. | Hold it; preserve dismissal, ratings, expressions and created_at. |
| FilmRemovedFromWatchlist | No action; do not create a candidate solely for a removal. | Release any hold; preserve dismissal, ratings, expressions and created_at. |
| FilmMarkedNotInterested | Create a dismissed, unheld RatingFilm. | Dismiss it and release any hold; preserve ratings, expressions and created_at. |

Do not subscribe to FilmDismissalRemoved. Removing not-interested from Library does not automatically clear indefinite Ratings dismissal. A watched event also preserves dismissal. Dismissal has one meaning inside Ratings regardless of which interaction caused it; do not store its origin or a dismissal reason.

### Ratings-owned states

- `dismissed` means remove from automatic rotation indefinitely. `held` means temporarily remove from rotation with the intention of reintroducing it later. These are independent booleans, not Library classifications or STI types.
- Add only `RatingFilm.held`, non-null with default false and explicit boolean validation. Existing rows start unheld. Releasing a hold never clears dismissal; both states may coexist, for example when an already-dismissed film is added to a watchlist.
- Model actions own holding and releasing, alongside the existing dismissal action. Define action-specific permissions and explicit failure for a requested hold/release that cannot occur; localize new application errors. The consumer checks those permissions to handle already-satisfied outcomes idempotently. Do not add silent-success behaviour to public model actions solely for delivery retries.
- A possible future explicit “hold”/“snooze” UI would use Ratings-owned behaviour. Its hold precedence, release rules and any expiry require a later spec. No UI, timer, deadline, hold reason or origin tracking now.

### Model behaviour and atomic delivery

- Keep one ordered subscription with an explicit event-name-to-handler mapping. Use a separate Ratings-owned handler for each reaction; shared envelope validation and fresh record loading remain in the subscription entry point. Model actions retain permission rules. Adding an event requires its handler and mapping entry, not another branch in a central reaction method. Do not split event types into separate subscriptions or change Foundation ordering.
- Reuse RatingFilm's existing user/film uniqueness, dismissed boolean, permissions and dismissal action; extend these with the held behaviour above. Models own actions; the consumer coordinates fresh loading, locks and persistence under Deliver's locked active user. No subtype checks or Library model queries.
- An actual admission, hold, release or dismissal returns `:processed`. An already-satisfied reaction, including removal without a row, returns `:ignored` without writes or timestamp changes. For not-interested, dismissal and release together constitute one atomic reaction. Public repeated dismissal keeps its existing failure.
- Commit RatingFilm changes and the receipt together in Deliver's transaction. A persistence failure leaves neither a partial change nor a successful receipt. Receiving Library events never creates a Rating, an expression or a RatingSubmitted event.
- No separate suppression record, library_suppressed flag, copied classification, watched flag, origin marker or last-applied Library sequence. Unlike indefinite dismissal, hold/release order matters: rely on Foundation's ordered delivery and completed receipts, not a claim that these reactions commute. An earlier failed matching fact blocks later matching facts in that Library stream; completed-receipt redelivery cannot reapply an old hold. Do not bypass Deliver for replay or compare unrelated streams' sequences/timestamps. Verify add/remove/add and add/watched histories through real dispatch.
- A delayed not-interested event may dismiss an already-rated RatingFilm, but must never erase or replace its ratings or expressions. Rated rows remain excluded by rating existence. Completed-rating delivery still establishes watched in Library through task 016; the derived watched event does not clear Ratings dismissal.

### Selection and explicit actions

- Extend the pending rule to unrated, not dismissed and not held, owner-scoped bounded selection and created_at/ID order. Newly watched films do not jump ahead of older unfinished candidates. Apply eligibility in the database before the batch limit. No backdated admission, separate priority or catalogue refill.
- Creation of a dismissed or held row does not make it eligible for selection. Later catalogue admission must preserve existing rows rather than recreating them; implementing catalogue refill remains separate.
- Explicit rating of an existing owned held or dismissed candidate remains allowed through the existing submission service. Targeted entry from Library belongs to task 019. Explicit entry bypasses automatic rotation; this task does not introduce an undismiss action or reset dismissed or held as a synchronous side effect of submission. A later FilmMarkedWatched event releases the hold; the saved rating already excludes the row from automatic selection.
- Serialize event application with existing local submission/dismissal/selection through the user lock. Preserve existing public duplicate-action failures and rating/expressions ownership.

### Catch-up and lifecycle

- Discover all retained matching watched/not-interested/watchlist facts using existing bounded dispatch and receipts. No source reads, source backfill, synthetic baseline, snapshot or cursor infrastructure. Historical watchlist/removal facts establish and release holds in source-stream order; none of the subscribed facts clears dismissal.
- Verify rollback/retry, duplicate facts, ordered retained delivery and catch-up reruns. A batch with no processed work does not prove the backlog is drained; use status and existing recovery sweeps.
- Expired/deleted owners are skipped through Foundation. Existing cleanup removes RatingFilm and related activity; registration claim preserves owner/row identities. Verify using real Identity operations, including races; no Identity changes or new retention policy.
- All new application-facing text uses Rails locales. No external calls, raw expression data in logs or network effects in handlers.

## Scope restrictions

- Ratings owns this task. The only outside-domain edit allowed is its explicit entry in the subscription registry. No Library/Foundation transport/Identity/Film runtime changes or generic integration layer.
- Storage change is limited to the held boolean and its validation/default/non-null constraint; migrate only the test database during verification. No new tables or other columns. No storage of Library knowledge, separate suppression state, dismissal provenance, sequence watermark or general reconciliation framework.
- No Recommendations consumer, UI/routes, catalogue selection/popularity policy, rating revisions/supersession, expression/quality scoring, profile processing or deployment.
- No changes to public submission/dismissal semantics, automatic undismissal, broad scope refactor or event pruning. Owner approved implementation on 22 October 2026.

## Acceptance criteria

- **AC1:** Library facts admit, hold, release and dismiss RatingFilm according to the reaction table without changing original evidence or queue ordering.
  Check: absent/existing rows, all held/dismissed combinations, rated rows and real pending/NextCandidates results. New watched rows appear after older unfinished rows; held/dismissed rows do not appear. Released rows retain original created_at and return at that queue position only when unrated and not dismissed. Removing watchlist with no row creates nothing; FilmDismissalRemoved has no consumer. Explicit rating accepts held/dismissed candidates without resetting either state synchronously.
  Result: Passed — all four event reactions cover absent/existing rows and every held/dismissed combination, including saved ratings/expressions. Queue checks verify filtering before limit, original order after release, independent dismissal and foreign-owner isolation. Missing-row removal and unsubscribed FilmDismissalRemoved do not admit candidates. Explicit submission preserves held/dismissed synchronously.
- **AC2:** Changes and receipts are atomic, ordered and repeat-safe.
  Check: persistence failure rolls back admission/state changes and successful receipt, including the combined dismiss/release reaction; retry completes once. Repeated facts and completed-receipt redelivery preserve IDs, text and no-op timestamps. Failed predecessor blocks later matching hold/release events; add/remove/add and add/watched histories reach the correct state. Retained facts catch up in bounded batches. Unsupported versions, missing Film and invalid required identifiers fail without writes. Verify model hold/release failure semantics and existing duplicate dismissal failure.
  Result: Passed — injected database failures verify admission rollback, blocked successor and retry, and atomic rollback of combined dismissal/release. Bounded retained add/remove/add/watched history and completed-receipt replay preserve source order and no-op timestamps. Invalid versions/identifiers and missing Film retry without writes. Hold/release/duplicate-dismissal failures and localized errors pass.
- **AC3:** Concurrent and cross-domain activity preserves user evidence without loops or resurrection.
  Check: separate connections for duplicate delivery, event application against rating submission and dismissal, expiry/cleanup/claim. Deliver real Library and Ratings facts in both cross-domain orders: ratings/expressions survive, Library becomes watched, the resulting watched fact releases holds while preserving dismissal, and no consumer synthesizes ratings or repeated events. Verify ownership isolation and existing cascade behaviour.
  Result: Passed — separate-connection tests cover duplicate delivery, submission before a waiting hold, dismissal before/after a hold, expiry, cleanup and claim. Real Library/Ratings dispatch in both cross-domain orders preserves original text and ratings, establishes watched, releases holds and retains dismissal without event loops. Cleanup removes held rows/receipts and preserves shared Film.
- **AC4:** Storage, checks and documentation match implementation.
  Check: existing rows migrate to held=false; model validation and bypass-model tests enforce non-null boolean storage. Record test-only migration commands and focused Ratings/Library/Foundation test results; run `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`. Update subscription/catch-up docs, distinguishing release of temporary holds from indefinite dismissal. No deployment.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/rating_hold_test.rb test/services/ratings test/services/library test/services/domain_events test/jobs`: 151 tests / 1,345 assertions. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 384 tests / 4,010 assertions; style/security clean. `RAILS_ENV=test bin/rails zeitwerk:check` passed for application code with the existing mailer-preview exclusion notice. `git diff --check` passed. `RAILS_ENV=test bin/rails db:migrate` added only held. An additional rolled-back migration check verified pre-existing rows default to false; details below. No development/production migration or deployment.

## Implementation notes

Implemented RatingFilm.held with false default/non-null storage and boolean validation; model-owned hold/release permissions and actions with localized failures; pending excludes held rows. Ratings::ConsumeLibraryFilm applies the four approved Library events through normal ordered delivery. It uses existing RatingFilm ownership/uniqueness and actions, preserves dismissal/evidence, and emits no domain events. Only the explicit subscription registration changes outside Ratings runtime code. Library subscriber tests now isolate their registered subscription when asserting per-subscriber counts; new integration tests exercise both production subscriptions together.

Spec approved on 22 October 2026. No scope deviations. Earlier test runs caught a test syntax error, cached cross-thread assertion and old single-subscriber count assumptions; corrected before the passing checks above. No Foundation transport or Library runtime changes.

Existing-row migration verification ran with `RAILS_ENV=test bin/rails runner /tmp/glutton017-migration-check.rb`. Reproduce by loading `db/migrate/20261022120000_add_held_to_rating_films.rb`, opening an ActiveRecord transaction, running that migration down, inserting one user/film/candidate with the pre-held schema, running it up, and asserting SELECT held for that candidate is false; raise ActiveRecord::Rollback to restore schema and remove verification fixtures. This passed; the surrounding transaction rolled back the check. Normal test migration remains applied. Validation-bypass tests also confirm held cannot be null. No extra schema constraints or source-state columns were added.

Owner acceptance / merge: Pending.

Owner review follow-up: extracted FilmMarkedWatched, FilmAddedToWatchlist, FilmRemovedFromWatchlist and FilmMarkedNotInterested into individual handlers under Ratings::LibraryEvents. ConsumeLibraryFilm keeps shared validation/loading and an explicit HANDLERS mapping; EVENT_NAMES derives from the mapping. The existing single subscription and per-stream ordering remain unchanged. No Foundation or model permission changes.

Follow-up verification: repeated the focused command in AC4 (151 tests / 1,345 assertions, all passed), `bin/rubocop app/services/ratings/consume_library_film.rb app/services/ratings/library_events` (5 files, no offenses), `RAILS_ENV=test bin/rails zeitwerk:check` (application passed with the existing mailer-preview exclusion notice), and `git diff --check` (passed). Full CI results above predate this extraction; full CI was not repeated.

Owner naming follow-up: renamed Ratings::LibraryEvents to Ratings::LibraryEventHandlers and its directory to app/services/ratings/library_event_handlers; updated the dispatch mapping. Behaviour is unchanged.

Rename verification: `RAILS_ENV=test bin/rails zeitwerk:check` passed with the existing mailer-preview exclusion notice. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/ratings/library_consumer_test.rb test/services/ratings/library_consumer_concurrency_test.rb` passed (16 tests / 252 assertions). `git diff --check` passed; no old namespace/path references remain in app or test.

Final namespace refinement: handlers now use nested Ratings::EventHandlers::LibraryFilms modules under app/services/ratings/event_handlers/library_films. Dispatch references updated; behaviour unchanged. Application eager loading and the same consumer test command passed again (16 tests / 252 assertions). Targeted RuboCop initially caught whitespace introduced during indentation; removed it and reran the check.

Domain naming correction: the final namespace is Ratings::EventHandlers::Library, under app/services/ratings/event_handlers/library. Library names the publishing domain, not its internal models. Dispatch references updated. `RAILS_ENV=test bin/rails zeitwerk:check` passed with the existing mailer-preview exclusion notice; the consumer test command above passed (16 tests / 252 assertions); targeted RuboCop passed (5 files, no offenses); `git diff --check` passed.

Owner boundary follow-up: renamed the shared entry point to Ratings::ConsumeLibraryEvent and its as-yet-unreleased subscriber identity to ratings.library_events. RatingFilm remains internal to Ratings; no LibraryFilm references are used by the Ratings consumer. Model-specific reaction work remains inside the receiving domain.

Entry-point/boundary verification: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/ratings test/services/domain_events test/jobs` passed (148 tests / 1,329 assertions). Application eager loading and targeted entry-point/handler/registry RuboCop passed. `git diff --check` passed. Production search found no LibraryFilm references under Ratings services or RatingFilm references under Library services.

Final combined verification before PR: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed on the final implementation (384 tests / 4,010 assertions; style and security checks clean). This includes all handler/entry-point renames and removal of classification. `git diff --check` passed.
