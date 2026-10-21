# 013 — Ratings presentations and seen/unseen evidence

Status: Draft — revised for asynchronous domain events  
Owner: Ratings / presentations

## Goal

Persist Ratings-owned presentation/response history and select the next rating interaction from local state. Distinguish films known seen and awaiting rating from films that still need a seen/unseen question. This task does not implement cross-domain event transport or Library subscribers.

Read the implementation plan, product brief sections 2/3.1 and Ownership of viewer activity, architecture brief sections 4/11, and docs/domain_events.md. The owner superseded synchronous MakeAvailableForRating on 21 October 2026. Foundation task 001i and Library publication task 012a precede event-consumer task 017; local Ratings persistence can be implemented independently once this revised spec's remaining decisions are agreed.

## Scope

### Local presentation behaviour

- `Ratings::PresentNext.call(user_id:)` returns a Ratings-owned presentation with the interaction it requires: a rating for a known-seen unrated film, or a seen/unseen question for an unknown film. Return nil when exhausted. Repeated retrieval of an outstanding eligible presentation returns the same record rather than duplicating history.
- Known-seen unrated films take priority, oldest ready time then film ID. They must not be asked whether they have seen the film again. Preserve an already-open eligible presentation rather than silently replacing a form when another film becomes ready.
- The general unknown-film pool follows after known-seen films. Its catalogue eligibility and recognition ordering are still a review decision: TMDB vote count was discussed as a candidate proxy but is not imported or approved as a final rule. Do not ship film-ID ordering as an unspoken product policy. Define a Film knowledge provider task before consuming new selection metadata; no live TMDB calls during selection.
- `Ratings::RecordSeen.call(user_id:, presentation_id:)` records seen evidence and the answer/time, then makes the film ready for rating. The same interaction may advance to its rating stage without another seen question. It does not save a numeric rating or create Library state.
- `Ratings::RecordUnseen.call(user_id:, presentation_id:)` records the answer/time and suppresses further automatic rating prompts while that evidence remains. It closes the seen/unseen presentation and does not create Library state or change recommendation eligibility.
- Missing/foreign presentations raise Ratings::PresentationUnavailable without disclosing another owner's state. Repeating an answered user response raises Ratings::PresentationAlreadyAnswered. User-response idempotency must not be inferred from retry-safe event delivery.
- Every action freshly resolves/locks its active owner. Missing/inactive owners raise Ratings::IdentityUnavailable. Film-targeted local work rejects absent films with Ratings::FilmUnavailable. Expected failures leave state unchanged; unexpected persistence failures propagate and caller rollback remains effective.

### Current state and history

- Keep one Ratings-owned user/film record and a history of presentations/responses. Store seen evidence, ready-for-rating status/time and suppression provenance without overwriting them with a single overloaded available/seen/unseen label. Exact schema and behavioural roles must be settled in this spec before implementation; avoid speculative subclasses or a general state-machine framework.
- Preserve historical answers when later evidence changes eligibility. Ordinary actions and their permissions belong on models; services coordinate selection, ownership, locking and transactions. Subclass transitions, if concrete behaviour justifies any, remain service-owned.
- At most one outstanding interaction per user, enforced with appropriate database uniqueness. Define seen-question completion versus rating-stage completion explicitly; record numeric-rating completion in task 014, not by pretending a seen answer is a rating. Task 014 extends this same Ratings domain to exclude current-rated entries.
- Use required ownership/film references, unique user/film state, and coherent answer/time constraints. If ownership is duplicated on presentation rows to enforce uniqueness, constrain consistency in the database. Lock order is user, per-film record, presentation.

### Event integration contract — consumed in task 017, not implemented here

- Library FilmMarkedWatched supplies known-seen evidence; create/update the local Ratings film record and ready an unrated film without a numeric rating. Earlier unseen evidence remains historical but no longer suppresses it. An existing current rating prevents requeueing.
- Library FilmMarkedNotInterested means unseen and unwanted, so Ratings suppresses automatic prompts. It is not “declined to rate.” Keep provenance and history; a delayed contradictory event cannot erase a saved rating or newer known-seen evidence.
- Watchlist addition does not by itself assert seen/unseen. It updates the Library projection and clears superseded dismissal intent; independent unseen evidence remains. Removal clears the matching current classification, not seen/unseen history, and does not imply the film was watched.
- Subscriber processing invalidates a now-ineligible outstanding presentation without inventing a user answer. The next retrieval can select another film. Submission against an invalidated presentation must have an explicit stale-presentation failure; task 017 adds this behaviour with its consumer tests.
- No public synchronous MakeAvailableForRating integration. Event handling invokes Ratings-owned behaviour and commits its delivery receipt with local updates. Version ordering, duplicates, replay and conflict rules follow docs/domain_events.md; transport implementation belongs to 001i and subscription implementation to 017.

### Proposed retention boundary

Ratings activity is deleted with physical deletion of its guest owner and retained on in-place guest claim. Propose scoped user-to-Ratings-film and Ratings-film-to-presentation foreign-key cascades; shared Film rows remain restrictive and survive. This policy requires owner approval with the final persistence spec. Use established Identity cleanup/claim operations in compatibility tests without editing Identity. Event receipts/payload retention is separately defined by Foundation/consumer specs; delayed events must never resurrect deleted or expired owners.

## Scope restrictions

- Ratings implementation/tests only. No Library, Identity or Film implementation changes. No cross-domain synchronous mutation or direct Library-table eligibility query.
- No numeric rating/expressions implementation, AI, recommendation ranking, UI/routes, targeted-entry screen, metadata imports, jobs/outbox or subscribers in this task.
- Do not flatten seen evidence, intent suppression, current rating and presentation history into a classification copied from Library. No shadow rating values in other domains.
- Any migration is limited to Ratings-owned state/history. New user-facing validation text must use Rails locales and symbolic errors.
- This is a revised draft, not authorization to implement the unsettled storage/selection decisions or publish changes.

## Acceptance criteria

- **AC1:** Known-seen unrated films precede eligible unknown films and are presented for rating without another seen question.
  Check: deterministic priority/ties, outstanding-presentation retry, both interaction types, exhaustion, and unknown-film ordering once agreed. Seen answers advance to ready-for-rating; unseen answers suppress future questions without Library writes.
  Result: Not run — revised draft only.
- **AC2:** History, ownership and explicit failure contracts hold.
  Check: duplicate responses, foreign/missing presentation, expired/deleted/missing owner, absent film, retained prior responses, unique current state and coherent timestamps; failed operations and caller rollback leave no partial state.
  Result: Not run — revised draft only.
- **AC3:** Concurrent local actions and guest retention preserve invariants.
  Check: deterministic separate-connection selection/response races, failure injection/retry, direct storage constraints, real Identity claim/cleanup and rollback, expired access and preserved shared films.
  Result: Not run — revised draft only.
- **AC4:** Scope and repository checks hold.
  Check: test-only migrations and final explicit Ratings model/service test paths; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`; `RAILS_ENV=test bin/rails zeitwerk:check`; `git diff --check`. Record actual commands and outputs after implementation. Cross-domain event tests belong to task 017.
  Result: Not run — revised draft only.

## Implementation notes

Not implemented. Replaces the prior synchronous make-available proposal. Before implementation, agree the current-state/presentation schema, unknown-film selection policy and scoped retention policy. Event design is recorded separately; no workers, publishers or consumers exist yet.

Owner acceptance / merge: Pending.
