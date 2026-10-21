# Asynchronous domain communication

Status: Design direction authorized by the owner on 21 October 2026; event names and detailed contracts below are proposed for the scoped implementation specs. No event transport, publishers or consumers are implemented yet.

## Decision and boundaries

Library, Ratings and Recommendations own their data and publish domain facts through durable asynchronous delivery. The source action commits without waiting for other domains. Briefly stale screens are acceptable; lost updates, duplicate effects and stale events reversing newer state are not. A single deployed Rails application with PostgreSQL and durable background jobs is sufficient; no external message broker or separately deployed service is required.

Publish the source change and its outbox event in one database transaction. Each consumer later commits only its own domain updates and delivery receipt. The outbox is delivery infrastructure, not the authoritative domain history or an event-sourced replacement for models. Domain rules belong in their existing models/operations. Internal calls within a domain remain ordinary synchronous Ruby calls. This decision concerns product-domain coordination, not a ban on synchronous Identity resolution, catalogue reads or external request/response APIs.

NotInterested means the person has not seen the film and does not want to watch it. Ratings excludes it from rating prompts; Recommendations excludes it from discovery. It is not a refusal to rate a watched film. Watched entries cannot become ToWatch or NotInterested. Completed ratings are evidence of viewing; a seen answer alone does not create Library state.

## Publication and subscription map

Names are domain facts, not generic model-update notifications. Every film-specific event carries trusted internal user/film IDs, event identity and source version. The payload must be sufficient to apply its meaning without a synchronous callback into the publisher.

| Publisher / fact | Consumer / reaction |
| --- | --- |
| Library: FilmMarkedWatched | Ratings establishes seen evidence and a ready-to-rate entry if there is no current rating; it supersedes earlier unseen suppression. Already-rated films remain rated and are not queued. Recommendations excludes the film. |
| Library: FilmAddedToWatchlist | Recommendations excludes the film. Ratings records current Library intent but does not infer seen/unseen from watchlist intent alone. It clears an earlier Library dismissal suppression if this is the newer classification; independent Ratings unseen responses still apply. |
| Library: FilmMarkedNotInterested | Ratings records the not-seen/no-intent fact and suppresses prompts. Recommendations excludes the film. Do not overwrite prior presentation history or delete saved ratings when processing a delayed contradictory event. |
| Library: FilmRemovedFromWatchlist / FilmDismissalRemoved | Consumers remove the applicable Library classification/suppression. Recommendations re-evaluates eligibility against its other owned facts. Ratings retains recorded seen/unseen evidence; removing a dismissal does not assert the person has now watched it. |
| Ratings: RatingSubmitted / RatingRevised | Library consumes the completed-viewing fact and ensures watched state. Recommendations records that the film is rated and excludes it immediately on receipt, even if the Library event has not arrived. Revisions update the local rating revision without producing repeated watched transitions. |
| Ratings: PreferencesUpdated (later scoring/profile milestone) | Recommendations updates its preference projection and schedules ranking refresh. Only completed published preference versions cross this boundary; raw expressions and intermediate model output stay in Ratings. |
| Recommendations: RecommendationResponseRecorded | Library consumes explicit watchlist, watched or not-interested choices. The event says the response was recorded, not that Library already changed. Recommendations retains its response and pending application status. No-op navigation/exposure has no Library reaction. |
| Ratings: RatingFlowLibraryActionRequested (future UI) | Library consumes explicit add-to-watchlist or other supported Library actions made from the rating flow. Seen/unseen answers themselves do not request Library changes. Ratings retains request status separately from its answers. |
| Library: LibraryActionApplied / LibraryActionRejected | The requesting domain updates its pending response/action status using the request event ID. These outcomes are emitted for asynchronous action requests, not for ordinary direct Library calls. Other domains react to the resulting Library fact, not to these acknowledgements. |
| Film knowledge: catalogue/analysis revision publication (later) | Ratings may update stored selection inputs and invalidate affected assessments; Recommendations may refresh film evidence. Define actual payload and consumers in the metadata/analysis tasks, not a blanket event for every Film update. |

A Library transition publishes the resulting fact once. ToWatch-to-NotInterested publishes FilmMarkedNotInterested, not a fabricated user removal followed by a new action. Explicit removal publishes its own fact. Facts retain the resulting classification plus source sequence where needed for projection consistency, without exposing STI names.

Recommendations and Ratings presentation histories remain independent. Recommendations does not subscribe to every Ratings page view or unseen answer: unseen alone does not exclude discovery. Ratings need not subscribe to recommendation exposure. Publish only when another domain has a concrete reaction.

## Requests, conflicts and loops

A recorded recommendation choice is a fact about that interaction and carries a request for Library to act. It cannot truthfully claim that the requested Library action succeeded. The UI may acknowledge the recorded choice immediately; pending/applied/rejected status remains available without blocking for a subscriber.

Library revalidates the request against fresh state and reports the outcome. Include the observed Library version when the originating screen has one; reject a known stale version. A missing observed version does not prove freshness: evaluate the fresh permitted action, reject conflicting watched-state changes, and define deterministic processing order for multiple pending requests. Do not use wall-clock timestamps as a global ordering guarantee. Concurrent independent source requests have no inherent total order; Library is the authority that serializes accepted classification changes.

Duplicates of the same delivery return the recorded outcome. A different user request for a transition that did not occur remains an explicit rejection, including an already-satisfied user action. A completed-rating subscriber is a system workflow: it may explicitly accept existing watched state without generating another watched event. The public RecordWatched duplicate failure remains unchanged.

Rating completion establishes viewing even if Library currently says NotInterested. Task 016 must specify the Library-owned system transition that reconciles this evidence; current RecordWatched cannot perform it. A stale dismissal event must not erase a newer rating/seen fact. Ratings retains provenance/version of independent evidence and never retracts a saved rating from a Library projection update. Library's later watched event converges the classification. Resolve genuine contradictions explicitly rather than destroying history.

Library watched events update Ratings eligibility, not rating submissions. Ratings emits RatingSubmitted only for an actual committed submission; receiving a Library event cannot synthesize one. Preference-refresh events do not create Library actions. Outcome acknowledgements do not generate fresh requests. Propagate correlation and causation IDs through real derived changes so these paths can be inspected without endless republishing.

## Delivery contract and failure handling

- Envelope: unique event ID, event name/schema version, owning domain, durable stream identity, monotonic stream sequence, occurred_at, correlation/causation IDs, and minimum necessary payload. No credentials, email, raw expression text or serialized Active Record objects.
- A Library stream is per user/film, not per deletable LibraryFilm row. Sequence continuity must survive removal/recreation. Allocate versions atomically with the user-locked source write; specify persistent stream/version storage in the publisher task.
- At-least-once delivery with independent receipts per subscriber. Domain update and unique subscriber/event receipt commit together; retry after a worker crash cannot duplicate domain effects. Source rollback leaves no deliverable event. Enqueue failure after source commit is recovered by polling the durable outbox.
- Process each subscriber's stream in order. Retry/backoff a failed predecessor without silently advancing dependent events; unrelated users/films and subscribers continue. Monitor backlog age, retries and terminal failures, and provide an explicit retry/replay procedure. Workers running in the same app do not eliminate this requirement.
- Cross-domain streams have no total order. Use source-specific versions, causal links and the conflict rules above; do not compare unrelated sequence numbers or trust timestamps to resolve races.
- Persist events even when a planned subscriber does not yet exist. Each new subscriber needs a defined bootstrap: retained events from a recorded cursor, or an owner-provided snapshot plus subsequent versions with no gap. Library has existing rows before events are introduced; task 012a must publish/version a consistent bootstrap. Backfill must not masquerade as fresh user activity or overwrite newer events.
- Event retention/compaction must account for registered and future consumers, replay needs and privacy. Do not purge unacknowledged events simply because the initial subscriber finished. Avoid promising indefinite history retention; agree concrete policy before runtime implementation.
- Handlers lock/recheck the user before activity writes. Expired/deleted/missing owners must not be recreated by delayed events. Record a terminal skipped outcome where safe, and clean up user-owned payloads/receipts under the approved retention policy. Guest claim preserves the user ID. Infrastructure retention ownership must be decided without introducing Identity callbacks mechanically.
- No direct publisher-to-consumer synchronous fallback during outages. Show locally committed results and allow other views to converge. Failed asynchronous requests expose a rejected outcome rather than falsely reporting a completed Library action.

## Delivery sequence

1. Foundation task 001i: narrowly scoped durable outbox, job execution and delivery receipts, with ordering, crash recovery, privacy and operational checks. Implemented with GoodJob and PostgreSQL storage in the [001i spec](specs/001i_durable_event_delivery.md), Ready for review; see [operations](domain_event_operations.md).
2. Library task 012a: versioned Library publication and bootstrap for existing rows, using the Foundation contract. No consumer implementation.
3. Ratings task 013: own presentation state and local seen/unseen workflows. Store known-seen unrated separately from unknown/unseen eligibility; no MakeAvailableForRating cross-domain API.
4. Ratings tasks 014/015: rating/submission/expression persistence; task 014 defines committed submission/revision publication, and 015 preserves atomic rating-plus-expression save. Later preference work owns PreferencesUpdated publication.
5. Library task 016: consume completed-rating events, define system reconciliation and duplicate outcomes, and publish actual Library changes.
6. Ratings task 017: consume Library facts into its owned eligibility state; known watched but unrated films are presented for a rating first, without asking seen again. Preserve current ratings and historical answers.
7. Separate domain-owned tasks for Ratings/Recommendations action publication, Library action consumption/outcomes, and requesting-domain outcome consumption before the associated UI is complete. Recommendations also consumes Library exclusions and completed rating/preference facts in separately scoped tasks.

Selection metadata remains a separate Film knowledge concern. TMDB vote count is a candidate recognition proxy discussed with the owner, not yet an approved/imported field or final ranking policy. Asynchronous coordination does not settle catalogue eligibility or ranking.
