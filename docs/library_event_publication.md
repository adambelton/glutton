# Library event publication

Task 012a publishes facts from the five supported Library operations. The source change and events commit together; a publication failure rolls back the operation. Task 016 adds Library consumption of completed Ratings facts; task 017 adds Ratings consumption of watched, not-interested and watchlist facts. Raw SQL, fixture creation and direct Active Record writes are not supported Library action APIs.

## Version 1 contract

Publisher: `Library::EVENTS_PUBLISHING_DOMAIN` (`library`). Stream key: `film:<internal film ID>`, scoped to the internal user ID. A stream survives entry removal/recreation. Its envelope sequence is the ordering authority, not the LibraryFilm ID or timestamp.

Each payload contains exactly `user_id` and `film_id`. Identifiers are internal IDs and the user matches the stream owner. The envelope supplies event ID, schema version (`1`), sequence, occurrence time, correlation and causation. Direct actions each start their own correlation and have no causation ID.

| Event | Meaning |
| --- | --- |
| FilmMarkedWatched | Establishes viewing evidence |
| FilmAddedToWatchlist | Establishes intent, without asserting seen or unseen |
| FilmMarkedNotInterested | Establishes unseen and unwanted evidence |
| FilmRemovedFromWatchlist | Clears watchlist classification; retains prior viewing evidence |
| FilmDismissalRemoved | Clears dismissal classification; does not assert seen |

Event names are frozen string constants in `Library::Events`, shared by publishers and tests. Each operation supplies its event name; payloads identify the user and film without exposing Library classification.

A transition emits one resulting action fact, without synthetic removal facts. Failed/duplicate actions emit no events. This project has no existing entries to backfill: supported operations publish events from entry creation onward.

Owner correction, 22 October 2026: removed redundant classification from v1 in place because this project has no historical data requiring compatibility. No version bump or retained-payload migration is needed. Subsequent published contract changes must respect versioning. An incompatible payload change requires a new schema version. Each future subscriber must explicitly define its historical and unsupported-version handling. Do not silently interpret unknown versions as v1. Retention and delivery remain governed by [Foundation operations](domain_event_operations.md).

Guest claim preserves stream ownership; physical owner cleanup cascades events without emitting a Library removal action.

## Completed-rating consumption

`library.completed_ratings` consumes RatingSubmitted v1 through normal durable delivery. A missing, ToWatch or NotInterested entry becomes watched; already watched is ignored without publication. Derived FilmMarkedWatched facts have the same v1 payload, retain the source correlation ID and identify the source event as causation. The transition, derived event and successful delivery receipt commit together. Public RecordWatched permissions and duplicate failures are unchanged. See [operations](domain_event_operations.md) for retained-event catch-up and failure recovery.

Ratings task 017 consumes these facts into its own RatingFilm held/dismissed states. FilmDismissalRemoved has no Ratings subscriber. Ratings does not copy Library classification or query Library records; it consumes only event identity and user/film identifiers. Hold release preserves indefinite dismissal and original queue position. See [operations](domain_event_operations.md).
