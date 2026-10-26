# 021 — Library film details and watchlist actions

Status: Ready for review  
Owner: Library / film details and watchlist actions

## Goal

Select a film in any Library collection to open its existing Library film detail page. The concrete Library film submodel determines its behaviour and presentation. From a ToWatch detail page, remove the film or mark it watched; after transition, the same detail destination presents the returned Watched submodel and its existing rating entry.

Depends on tasks 010/011 (Library operations), 012a (publication), 019 (targeted rating entry), 020 (Library browsing) and 020b/020c (controller routes and access). Read the implementation plan, product/architecture Library sections and these operation contracts before implementation.

## Scope

### Collection and detail destinations

- Preserve the singular `/library` collection page, its Watchlist/Watched/Not interested dropdown and pagination. Make each film title a link to its Library detail page. Watchlist mutation controls belong on the detail page, not each collection row. Existing watched-list rating status/shortcuts may remain; no unrelated list redesign.
- Add GET `/library/films/:id`, handled by the existing top-level LibraryController. The identifier is the LibraryFilm relationship ID, not the shared Film ID. Use the same controller for the detail and its explicit action endpoints; do not introduce a FilmsController or controller namespace.
- Resolve the current owner's existing LibraryFilm in a Library service. Missing, foreign or removed entries are unavailable; detail GET never creates a LibraryFilm, RatingFilm, Rating or event. Validate the URL ID's shape/format in the controller; services own entity existence, ownership and freshness checks.
- Show existing Film title and optional release year, the submodel's scoped information/actions, and a labelled return link to Library. No new film metadata fetches, catalogue detail page, posters or analysis features in this slice.

### Submodel-owned behaviour and polymorphic presentation

- Treat the loaded concrete submodel as the role. Use Rails polymorphic rendering (`render @library_film`) with concrete partials for LibraryFilmToWatch, LibraryFilmWatched and LibraryFilmNotInterested. Shared markup may be extracted when it is actually shared.
- Submodels define supported behaviour and relevant information; their partials present it. Do not build a generic controller/view that switches on class/type or reconstructs the submodel through a matrix of capability checks. Do not introduce an action registry, generic presenter framework or broad classification API.
- **ToWatch:** present title/year and Mark watched and Remove from watchlist actions.
- **Watched:** present title/year and authoritative Rated/Awaiting rating information. Offer the existing `new_rating_path(film_id:)` only when unrated. Read Ratings-owned evidence for the same user and shared Film as in task 020, without copying rating data into Library. Ordinary rated/unrated state checks remain appropriate within this presentation; they do not choose a Library subtype.
- **NotInterested:** present title/year and its not-interested information. Reconsideration/removal controls remain task 022. Do not add disabled placeholders for future actions.
- Action rules remain in models. Transition services coordinate source and destination and return the updated concrete submodel. Controllers do not choose the destination subtype; source subclasses do not implement their own STI transitions. Reuse the returned object when choosing the successful detail destination. A redirected GET reloads it through the same owner-scoped lookup and polymorphically renders its current subtype.

### Existing-entry actions and outcomes

- Use CSRF-protected POST `/library/films/:id/mark_watched` and DELETE `/library/films/:id/remove_from_watchlist`, both handled by LibraryController. Derive user_id exclusively from current_user. Do not accept a request-supplied film_id or subtype as authority for these actions.
- The action service boundary loads the existing owned relationship under the established fresh-owner-before-entry lock order and retains that protection through the operation. Derive the shared film_id from that relationship. Coordinate the established RecordWatched/RemoveFromWatchlist behaviour without duplicating transitions or event publication. This existing-entry boundary is deliberately stricter than RecordWatched's general create-if-absent contract, which remains unchanged for other callers.
- A removed relationship must never be recreated by a stale detail action. If it was removed and a new Library relationship for the same Film now exists, the old ID remains unavailable; do not silently target the replacement. Concurrent actions resolve against fresh state with explicit failures, not successful no-ops. Keep all existence/precondition checks in services, not controller queries.
- Successful mark-watched preserves relationship ID and creation time, and returns the updated Watched submodel. Redirect with 303 to that object's detail URL and a translated notice. The page now offers the existing rating entry without waiting for event delivery; do not automatically create a rating candidate or redirect into Ratings.
- Successful removal deletes only the current owner's ToWatch entry and redirects with 303 to Watchlist's first page with a translated notice. No caller-controlled return URL.
- Malformed, missing, foreign or removed LibraryFilm IDs return 404. Existing but unsupported actions return 409 with localized explanation and a fixed Library return link; preserve the established domain failure rather than silently treating a duplicate as success. Identity absence/inactivity retains 401 and deleted-account handling retains 410. Do not surface developer-oriented service error messages as UI copy. Unexpected persistence errors propagate.
- Retain atomic Library state/event publication and normal asynchronous subscribers. No direct Ratings mutations or event-delivery waits. The Ratings link passes the shared Film ID, unlike the Library detail/action URLs.
- Put all labels, notices, errors and accessibility copy in Rails locales. Escape film titles, use named interpolation, and preserve no-store, keyboard access and comfortable mobile controls. Share translated copy where appropriate.

## Scope restrictions

- Library owns the detail page, subtype partials and existing-entry action boundary. No changes to Identity, Ratings, Recommendations, Film or event infrastructure. Shared reads and established operation calls remain allowed.
- No new transitions or changes to general RecordWatched/RemoveFromWatchlist semantics. No subclass-driven STI transitions, duplicated permission rules, type-switch rendering or generic action dispatch.
- No add-to-watchlist discovery/search/import UI, Mark not interested action, reconsideration, bulk actions, undo, watched removal, rating replacement or automatic rating redirect. Dismissal-management actions remain task 022; discovery needs its own scope.
- No schema, duplicated domain information, event payload/subscription changes or client-side optimistic mutations.
- No shared bottom/header navigation or default landing-route wiring. Those remain separately scoped supporting UI work.
- This spec does not authorize implementation, deployment or external communication.

## Acceptance criteria

- **AC1:** Collection links open the owner's existing Library film, with presentation selected polymorphically by its concrete submodel.
  Check: all three collections/detail variants, title/year and missing release date; ToWatch actions, Watched rating status/link and NotInterested information. No irrelevant actions, type-switch/capability-matrix rendering or writes on detail GET. Test observable presentation, not incidental partial internals.
  Result: Passed — LibraryDetailsTest verifies collection links, all three subtype presentations, escaped title, optional release year, state-specific controls and read-only detail rendering. Rails partial-path inspection confirms native polymorphic dispatch.
- **AC2:** Watchlist actions operate on the existing relationship and render the transitioned result.
  Check: real service-backed guest/registered requests; mark-watched preserves ID/creation time, redirects to the same detail URL and presents Watched information/actions. Removal redirects to Watchlist and makes the old detail unavailable. Verify original entry scope despite supplied user_id, film_id or subtype tampering.
  Result: Passed — service-backed request tests verify same-ID watched redirect, creation-time preservation, updated presentation, registered-user removal, first-page redirect and ignored owner/film/type tampering.
- **AC3:** HTTP validation, permissions and races have explicit outcomes.
  Check: malformed/missing/array/hash IDs, foreign entries, repeat submissions, changed submodels, stale removed IDs and removal/recreation of the same user/Film under a different ID. A concurrency test must establish that removal cannot slip between detail-action lookup and transition to cause unintended recreation. Signed-out/expired/revoked/deleted sessions and CSRF reject writes without creating users/activity. No GET mutation.
  Result: Passed — request/service tests cover malformed/unavailable/foreign IDs, expired/missing owners, unsupported actions, stale removed IDs and replacement relationships. Two PostgreSQL connection tests verify removal-before-action rejects without recreation and removal blocks between detail lookup and transition. Existing CSRF/session tests pass. Action routes are POST/DELETE only; the path ID, rather than query/body overrides, identifies the relationship.
- **AC4:** Library events and Ratings ownership are preserved.
  Check: successful actions publish the expected single event; rejected actions publish none; failures roll back state/events. No RatingFilm/Rating writes during Library requests. Follow the watched-detail rating link before event delivery to confirm the correct form. Rated state uses same-user actual rating evidence; absent/held/dismissed candidates remain unrated, and another user's rating does not count. Existing operation rollback/concurrency tests continue to pass.
  Result: Passed — request tests verify single-event success, no-event rejection, no Library-side Ratings writes and real rating entry before delivery. Service tests verify caller rollback and injected publication failure rollback for both actions. Watched detail verifies same-owner actual rating evidence including held/dismissed candidates and foreign ratings.
- **AC5:** Detail navigation and controls are accessible, localized and verified.
  Check: keyboard operation, focus/touch targets, escaped titles, strict translations, notices/errors, no-store, mobile/desktop layout and collection return links. Browser walkthrough: Watchlist → detail → mark watched → updated detail → rating form; then remove another ToWatch entry and verify its old URL is unavailable. Also open NotInterested and already-rated Watched details.
  Result: Passed — browser walkthrough at 375×812 and 1280×900 verified ToWatch → Watched at the same URL, keyboard submission, rating form entry, removal → Watchlist, unavailable removed URL, and rated/NotInterested presentations. Request tests check escaping, translations, no-store, labels and notices. No physical-device or screen-reader testing performed.
- **AC6:** Implementation evidence is recorded before review.
  Check: relevant Library/Ratings request and Library operation regressions, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, and `git diff --check`. Record commands/results, browser steps and limitations beneath these criteria.
  Result: Passed — full CI: 435 tests / 4,691 assertions, no failures/errors/skips; style/security checks passed. Rails eager loading and diff whitespace checks passed. Reproducible commands and browser notes below.

## Implementation notes

Implemented LibraryController detail/actions, native subtype partials, FindFilm lookup, WatchFilm/RemoveWatchlistFilm existing-entry service boundaries, and LibraryFilmWatched#rated? using authoritative Ratings data. No schema/event-contract changes. This revision supersedes the list-row controls and direct film_id action proposal. The owner selected a Library relationship detail destination and submodel-owned behaviour/presentation, rendered through Rails polymorphism. Unlike the earlier draft, stale detail actions cannot recreate removed relationships. Transition services continue to return the updated submodel.

Owner acceptance / merge: Pending.


### Verification — 26 October 2026

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/library_details_test.rb test/services/library/detail_actions_test.rb` — 8 tests / 130 assertions passed.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — 435 tests / 4,691 assertions passed, including existing Ratings/Library regressions and the new concurrent removal cases; style/dependency/importmap/Brakeman checks passed. One test worker avoids the existing local PostgreSQL/fork issue; explicit multi-connection concurrency tests still run.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed, with the existing mailer-preview exclusion notice.
- `git diff --check` — passed.
- Browser: seed a disposable registered user, two ToWatch films, one rated Watched film and one NotInterested film in the test database. Start `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3021 -P /tmp/glutton021-server.pid`. Sign in; open Watchlist → film title → Mark watched using the keyboard; verify the same detail URL now shows Watched and Awaiting rating. Follow Rate this film and verify the correct existing Ratings form before event delivery. Remove the other ToWatch film, confirm Watchlist notice and unavailable old detail URL. Open rated Watched and NotInterested details to verify their distinct presentations. Check at 375×812 and 1280×900. Screenshot: `/tmp/glutton021-detail.png`.
- Verified database outcomes and exactly two Library events from browser actions, then removed the disposable fixtures, stopped the server and reset the viewport. Browser used test-environment CSRF settings; request tests explicitly enable Library CSRF protection.
- Initial concurrency-test instrumentation used a callback whose Rails execution context was the model; corrected it to reference the test helper explicitly. Final full CI passes. No production behaviour changes were required by testing.

Implementation uses small explicit action services rather than a generic dispatcher. Each takes the relationship ID, locks the fresh owner then the exact owned row, and invokes the established film-based operation inside that transaction. Thus removal/recreation cannot redirect a stale request to another row. General RecordWatched creation semantics remain unchanged for existing callers.
