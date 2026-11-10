# Asynchronous domain communication

Library and Ratings publish/consume the contracts below through durable Foundation delivery. Recommendations activity, preference events and accepted-quality reassessment remain future work, requiring concrete contracts before implementation.

## Decision and boundaries

Owner clarification, 26 October 2026: domain boundaries are ownership boundaries, not read-access barriers. All domains may read the shared database, including another domain’s models/scopes, while respecting session/user access controls. Each domain owns its mutations, invariants and lifecycle. Read-only presentation queries do not require event-derived copies or new provider/consumer tasks. Durable events remain the agreed mechanism for existing cross-domain state-changing reactions; this clarification does not replace those workflows. For example, Library derives rated/awaiting-rating display from Ratings-owned records without storing its own rated flag.

Library, Ratings and Recommendations own their data and publish domain facts through durable asynchronous delivery. The source action commits without waiting for other domains. Briefly stale screens are acceptable; lost updates, duplicate effects and stale events reversing newer state are not. A single deployed Rails application with PostgreSQL and durable background jobs is sufficient; no external message broker or separately deployed service is required.

Publish the source change and its outbox event in one database transaction. Each consumer later commits only its own domain updates and delivery receipt. The outbox is delivery infrastructure, not the authoritative domain history or an event-sourced replacement for models. Domain rules belong in their existing models/operations. Internal calls within a domain remain ordinary synchronous Ruby calls. This decision concerns asynchronous state-changing reactions, not a ban on synchronous shared-data reads, Identity resolution or external request/response APIs.

NotInterested means the person has not seen the film and does not want to watch it. Ratings excludes it from rating prompts; Recommendations excludes it from discovery. It is not a refusal to rate a watched film. Watched entries cannot become ToWatch or NotInterested. Completed ratings are evidence of viewing; a seen answer alone does not create Library state.

## Implemented publication and reactions

Events name domain facts, with minimum internal user/film identity in the payload and identity/schema/source sequence in the envelope. They do not expose Library STI classification or serialized models.

| Publisher / fact | Current reaction |
| --- | --- |
| Library: FilmMarkedWatched | Ratings admits a missing candidate or releases its hold, preserving current ratings and explicit dismissal. |
| Library: FilmAddedToWatchlist | Ratings admits/holds its candidate; watchlist intent does not establish a rating or enjoyment. |
| Library: FilmRemovedFromWatchlist | Ratings releases an existing hold without creating a missing candidate or clearing dismissal. |
| Library: FilmMarkedNotInterested | Ratings admits/dismisses its candidate and releases any hold, preserving ratings and expressions. |
| Library: FilmDismissalRemoved | Published for the Library action; Ratings has no subscription and does not automatically restore rotation. |
| Ratings: RatingSubmitted | Library creates/reconciles watched state, including NotInterested. Already watched is ignored; an actual transition publishes a causal FilmMarkedWatched in the same receipt transaction. |

Rating replacement preserves history and emits no revision event. A later consumer need must establish its actual meaning/payload before adding one. Recommendations consumers and cross-domain action requests are not implemented by these subscriptions.

The Ratings queue is oldest-first by created_at/ID, unrated, not dismissed and not held. Library watched facts do not jump the queue or clear dismissal. Explicit rating entry may bypass a hold/dismissal. There is no separate presentation/current-selection or seen/unseen-answer history.

A Library transition publishes its resulting action once. ToWatch-to-NotInterested publishes FilmMarkedNotInterested, not a fabricated removal plus addition. Stream identity is per user/film and survives Library row removal/recreation. See the [Library publication contract](library_event_publication.md), [Ratings publication contract](ratings_event_publication.md) and [operations](domain_event_operations.md) for exact payloads, stream identity and recovery.

## Future action requests and conflict rules

The following rules constrain future explicit recommendation/rating-flow Library choices; they are not an implemented request workflow or a requirement to add unused event plumbing.

A recorded recommendation choice is a fact about that interaction and carries a request for Library to act. It cannot truthfully claim that the requested Library action succeeded. The UI may acknowledge the recorded choice immediately; pending/applied/rejected status remains available without blocking for a subscriber.

Library revalidates the request against fresh state and reports the outcome. Include the observed Library version when the originating screen has one; reject a known stale version. A missing observed version does not prove freshness: evaluate the fresh permitted action, reject conflicting watched-state changes, and define deterministic processing order for multiple pending requests. Do not use wall-clock timestamps as a global ordering guarantee. Concurrent independent source requests have no inherent total order; Library is the authority that serializes accepted classification changes.

Duplicates of the same delivery return the recorded outcome. A different user request for a transition that did not occur remains an explicit rejection, including an already-satisfied user action. A completed-rating subscriber is a system workflow: it may explicitly accept existing watched state without generating another watched event. The public RecordWatched duplicate failure remains unchanged.

Rating completion establishes viewing even if Library currently says NotInterested. The Library completed-rating handler owns this system reconciliation; it does not reuse the public duplicate-action contract. A stale dismissal event must not erase a newer rating/seen fact. Ratings retains provenance/version of independent evidence and never retracts a saved rating from a Library projection update. Library's later watched event converges the classification. Resolve genuine contradictions explicitly rather than destroying history.

Library watched events update Ratings eligibility, not rating submissions. Ratings emits RatingSubmitted only for an actual committed submission; receiving a Library event cannot synthesize one. Preference-refresh events do not create Library actions. Outcome acknowledgements do not generate fresh requests. Propagate correlation and causation IDs through real derived changes so these paths can be inspected without endless republishing.

## Delivery contract and failure handling

- Envelope: unique event ID, event name/schema version, owning domain, durable stream identity, monotonic stream sequence, occurred_at, correlation/causation IDs, and minimum necessary payload. No credentials, email, raw expression text or serialized Active Record objects.
- Publisher identifiers are stable constants owned by each publishing domain (for example, `Library::Events::PUBLISHING_DOMAIN`). Foundation validates presence and storage identity constraints, without a product-domain allowlist or registration step.
- Each publisher contract defines its stream granularity and ordering needs. Library uses user/film streams; user-wide preferences may require a user-level stream. Each subscriber contract defines supported historical schema versions and explicit handling of unsupported versions before implementation.
- A Library stream is per user/film, not per deletable LibraryFilm row. Sequence continuity must survive removal/recreation. Allocate versions atomically with the user-locked source write; specify persistent stream/version storage in the publisher contract.
- At-least-once delivery with independent receipts per subscriber. Domain update and unique subscriber/event receipt commit together; retry after a worker crash cannot duplicate domain effects. Source rollback leaves no deliverable event. Enqueue failure after source commit is recovered by polling the durable outbox.
- Process each subscriber's stream in order. Retry/backoff a failed predecessor without silently advancing dependent events; unrelated users/films and subscribers continue. Monitor backlog age, retries and terminal failures, and provide an explicit retry/replay procedure. Workers running in the same app do not eliminate this requirement.
- `EventDelivery` owns when a receipt is due, counts attempts, and records completion or failure. The delivery coordinator owns the locks and handler transaction. A handler failure rolls back subscriber writes before the receipt records the retry or terminal failure. Skipping an inactive owner does not count as an attempt.
- Cross-domain streams have no total order. Use source-specific versions, causal links and the conflict rules above; do not compare unrelated sequence numbers or trust timestamps to resolve races.
- Persist events even when a planned subscriber does not yet exist. Each new subscriber needs a defined bootstrap: retained events from a recorded cursor, or an owner-provided snapshot plus subsequent versions with no gap. Future subscribers must define how they consume retained events.
- Event retention/compaction must account for registered and future consumers, replay needs and privacy. Do not purge unacknowledged events simply because the initial subscriber finished. Avoid promising indefinite history retention; agree concrete policy before runtime implementation.
- Handlers lock/recheck the user before activity writes. Expired/deleted/missing owners must not be recreated by delayed events. Record a terminal skipped outcome where safe, and clean up user-owned payloads/receipts under the approved retention policy. Guest claim preserves the user ID. Infrastructure retention ownership must be decided without introducing Identity callbacks mechanically.
- No direct publisher-to-consumer synchronous fallback during outages. Show locally committed results and allow other views to converge. Failed asynchronous requests expose a rejected outcome rather than falsely reporting a completed Library action.

## Handler organisation

Production reactions use `ReceivingDomain::EventHandlers::PublishingDomain::EventName`. Keep a single ordered subscription for related reactions whose order matters. Library uses `Library::EventHandlers::ConsumeRatingsEvent` and Ratings uses `Ratings::EventHandlers::ConsumeLibraryEvent` for shared validation/loading and explicit dispatch. Handlers mutate only the receiving domain through its model actions/permissions. Use explicit top-level publisher constants where nested namespaces would shadow them.

## Future contracts

Define event meaning/payload, ordering, bootstrap/delivery, duplicate/failure handling and retention before adding preference updates, recommendation responses, action outcomes or accepted film-quality reassessment. Source refresh alone changes no accepted associations or user scores. Publish only when a concrete receiving-domain reaction exists; no generic workflow engine or synchronous fallback is implied.
