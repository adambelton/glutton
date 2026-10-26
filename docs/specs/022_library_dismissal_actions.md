# 022 — Dismiss and reconsider Library films

Status: Merged  
Owner: Library / dismissal actions

## Goal

Complete the existing Library film detail actions for changing viewing intent: a ToWatch film can become NotInterested, and a NotInterested film can return to Watchlist or be removed from Not interested. One shared detail composition renders action/information partials according to model-owned permissions and information. The presentation does not select a LibraryFilm subtype.

Depends on tasks 011/012 (existing operations), 012a (Library publication), and 021 (owner-scoped detail/action boundaries; its subtype partial selection is superseded below). Read the implementation plan, product/architecture Library sections and these specs before implementation.

## Scope

- Replace `render @library_film` and the three subtype-named partial directories with a shared Library detail composition. Name extracted partials after their action or information, for example `_mark_watched`, `_remove_from_watchlist`, `_mark_not_interested`, `_add_to_watchlist`, `_remove_from_not_interested` and `_rating_status`, under Library's views. Do not override `to_partial_path` to preserve hidden subtype dispatch.
- Guard the relevant UI with model-owned action permissions: `can_watch?` for Mark watched, `can_mark_not_interested?` for Mark not interested, and `can_add_to_watchlist?` for Add to watchlist. These are direct action checks, not proxies used to select a subtype or unrelated content.
- Add narrowly scoped model permissions for removal actions where none currently exist, with appropriate subclass overrides. Keep the rules in the models; do not infer removal permission from another action's predicate or duplicate the rules in views. These declarations describe existing supported actions, not new transitions.
- Retain title/year and authoritative rating information/entry from task 021 using content-named partials. Express applicability and rating-entry permission through model behaviour where needed, rather than class/type tests, `respond_to?`, or flags whose only purpose is identifying a subtype. Rating existence still comes from same-user Ratings records and is not stored in Library. Preserve existing watched rating behaviour and avoid querying/reconstructing Library classifications in the view.
- Add Mark not interested alongside the existing permitted detail actions. Add Add to watchlist and Remove from not interested where supported. Removing a film from Not interested removes the Library relationship; it does not imply watchlist intent or undo a user's independent Ratings dismissal.
- Do not build a controller/view type switch, predicate-to-subtype mapping, generic capability matrix, action registry or transition dispatcher. Simple action-specific conditionals calling model permissions are the intended composition. Services still enforce rules against freshly loaded state when a request is submitted; a hidden button is not authorization.
- Add explicit member action routes handled by the existing LibraryController: POST `/library/films/:id/mark_not_interested`, POST `/library/films/:id/add_to_watchlist`, and DELETE `/library/films/:id/remove_from_not_interested`. Use CSRF-protected Rails forms, never mutation through GET.
- Accept the existing LibraryFilm relationship ID. The controller validates input shape/format and takes the user from current_user. Request-supplied user_id, film_id or subtype must not redirect ownership or select a replacement relationship.
- Follow task 021's existing-entry action boundary: freshly lock the owner, require active identity, then resolve/lock the exact owned relationship and retain that protection through the operation. Use the consolidated MarkNotInterested, AddToWatchlist and RemoveNotInterested services directly with library_film_id; each owns its permission check, transition/removal and atomic publication. See owner-approved follow-up 022a.
- Owner-approved follow-up 022a removes film-based user-action creation and duplicate wrapper services. Detail actions never create a missing relationship or target a replacement row for the same Film. Missing, foreign, removed and old replacement IDs return 404; existing but unsupported/duplicate actions return 409 using the established domain error. Translate expected failures at the controller boundary; do not display developer service messages or turn failures into successful no-ops.
- Successful ToWatch → NotInterested and NotInterested → ToWatch transitions preserve relationship ID and creation time. Redirect with 303 to the returned updated object's detail URL and show a translated notice. The shared detail composition re-evaluates the returned/reloaded object's permissions and information to display the current controls. Transition services still return the updated concrete submodel; the controller and view do not select its type.
- Successful removal redirects with 303 to the first page of the Not interested collection with a translated notice. The old detail URL becomes unavailable. Do not accept an arbitrary return URL.
- Retain shared identity guard, 401 signed-out/inactive response, established 410 deleted-account handling, no-store, escaped user/film content, and untranslated user data. All authored copy belongs in Rails locale files, including action-specific accessible labels using named film-title interpolation.
- Keep existing atomic Library state/event publication. Successful actions emit their established facts; failures emit none. Ratings and other subscribers react independently as already implemented. No direct mutation of another domain or synchronous event-delivery waits.
- Maintain mobile-first detail controls with visible focus, comfortable touch targets, and readable desktop layout.

## Scope restrictions

- Library-only UI/action wiring and the model permission/information methods needed by that UI. Do not modify Identity, Ratings, Recommendations, Film, event infrastructure or subscriber behaviour.
- No new transitions, subtype, columns, event schemas or subscriptions. No subclass-driven STI persistence. Do not refactor unrelated Identity polymorphic views or other domains as part of this presentation change.
- No discovery/search/import, creation from absent Library relationships, dismissal reasons, bulk actions, undo, watched removal, rating revision, or NotInterested-to-Watched operation.
- No shared navigation/default route work, client-side optimistic state, generic integration layer or action dispatcher.
- Implementation was owner-approved; external communication and deployment are not part of this task.

## Acceptance criteria

- **AC1:** One shared detail composition exposes only the actions/information supported by model behaviour, using content-named partials.
  Check: ToWatch → NotInterested → ToWatch for active guests and registered users; same ID/creation time, correct 303 detail redirects, notices and changed controls. Watched exposes none of these intent-changing actions and retains rated/unrated information and rating entry. Existing Mark watched/Remove from watchlist behaviour remains correct. Inspect that partial names describe contents, subtype-named partials and implicit subtype rendering are removed, and action guards delegate to model permissions without type tests or unrelated-predicate inference. Test observable controls and operation outcomes rather than freezing the partial decomposition. No collection-row mutation controls.
  Result: Passed — LibraryDismissalActionsTest exercises guest/registered round trips, preserved identity/timestamps, redirects/notices and visible action changes. Existing detail tests pass with the shared composition, including rated/unrated and old watch/remove controls. Inspection confirms content-named partials and direct model permission guards; subtype partial directories and implicit rendering were removed.
- **AC2:** Removing a film from Not interested deletes only the owner's existing NotInterested relationship.
  Check: redirect to Not interested page one, translated notice, old detail URL unavailable, repeat removal explicit failure and no automatic watchlist creation. Independent Ratings state stays unchanged until normal event processing.
  Result: Passed — request test verifies removal, first-page Not interested redirect, notice, unavailable old ID, unchanged independent Ratings held/dismissed flags and no effect on replacement rows.
- **AC3:** Ownership, permissions, freshness and concurrency are preserved.
  Check: malformed/missing/foreign/removed IDs, supplied owner/film/type tampering, duplicate requests and unsupported source states. Old IDs cannot target replacement rows. Test concurrent removal versus reconsideration using real PostgreSQL connections: a removal-first stale action cannot recreate the row; a transition-first removal cannot delete the updated ToWatch entry. Include rollback/publication failure checks and retain existing operation concurrency tests.
  Result: Passed — request/service tests cover malformed/foreign/removed IDs, tampering, duplicate/unsupported operations, missing/expired owners and publication rollback. Two new real PostgreSQL connection tests verify removal-first cannot recreate the old entry and reconsideration-first prevents removal of the updated ToWatch row. Existing concurrency/rollback tests pass.
- **AC4:** HTTP security, localization and event boundaries hold.
  Check: CSRF on all writes, no GET mutations, signed-out/expired/revoked/deleted identity handling, no-store, strict translations and escaped titles. Verify the expected single Library event per successful action, none for rejection, and no direct RatingFilm/Rating mutations. Unexpected persistence failures propagate.
  Result: Passed — requests verify CSRF, expired/revoked/deleted sessions, explicit status codes, expected event names/counts and no direct Ratings writes. Existing escaping, no-store, strict translations and detail privacy checks pass. New action routes use POST/DELETE only.
- **AC5:** Browser usability and implementation evidence are recorded.
  Check: browser walkthrough through ToWatch → NotInterested → ToWatch, then mark another entry not interested and then remove it from that collection and verify its old URL. Check keyboard controls and mobile/desktop layouts. Run relevant Library request/operation regressions, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, and `git diff --check`; record exact results and limitations beneath these criteria.
  Result: Passed — full CI: 442 tests / 4,843 assertions, zero failures/errors/skips; style/security checks passed. Eager loading and whitespace passed. Mobile/desktop browser walkthrough passed; details below.

## Implementation notes

Implemented shared detail composition, content-named action/rating-status partials, model removal/rating permissions and three explicit existing-entry services with corresponding controller actions/routes/localized responses. Owner revision: task 022 also replaces task 021's subtype-based rendering with content-named partials and direct model-permission guards. This supersedes the earlier rendering decision without changing STI storage or transition ownership. Reuses the existing dismissal/reconsideration semantics and task 021's strict existing-entry action boundary. Creation is separate from user actions: the current Ratings-event handler can create a missing Library relationship; future explicit watchlist creation requires its own entry-point scope.

Owner acceptance / merge: Accepted and merged via PR #36; see merge evidence below.


### Verification — 26 October 2026

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/library_details_test.rb` — 6 tests / 100 assertions passed after the presentation change.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — 442 tests / 4,843 assertions, zero failures/errors/skips. Includes dismissal request coverage, existing Library/Ratings regressions, publication rollback and multi-connection concurrency tests. Style, dependency/importmap audit and Brakeman checks passed.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed, with the existing mailer-preview exclusion notice.
- `git diff --check` — passed. Reference inspection found no implicit LibraryFilm rendering, subtype names or type access in Library views.
- Browser: seed a disposable registered user with two ToWatch films in the test database and start `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3022 -P /tmp/glutton022-server.pid`. Sign in and open the first film detail at 375×812. Keyboard-activate Mark not interested: the same URL now offers Add to watchlist and Remove from not interested. Choose Add to watchlist: the original three supported actions return with a notice. At 1280×900, dismiss the second film and remove it from Not interested: confirm the Not interested collection notice and unavailable old detail URL. Screenshot: `/tmp/glutton022-detail.png`.
- Verified four Library events and the remaining ToWatch relationship, removed disposable fixtures, stopped the temporary server and reset the viewport. Browser used test-environment CSRF settings; request tests explicitly enable CSRF. No physical-device, zoom or screen-reader testing performed.
- Initial new-test run caught a Ruby block syntax error before execution; corrected before full CI. No production failures or domain-contract changes were needed.

Rating status is model-provided information (nil when not applicable; constants for rated/awaiting rating on watched entries), and can_rate? controls the rating entry action. Removal permissions describe the existing supported operations. No information is duplicated in storage, and service state validation remains independent of which buttons were rendered.

Owner naming refinement: use “Remove from not interested” for the action throughout UI/accessibility text, controller action, route/helper, partial, model permission and tests. After follow-up 022a, `RemoveNotInterested` is the single existing-entry operation; the wrapper has been removed. Existing published event identifiers remain unchanged. The earlier browser screenshot records the pre-refinement label; subsequent request/CI verification covers the renamed action.

Naming-refinement verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed (442 tests / 4,843 assertions; zero failures/errors/skips). `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check` passed. No old remove-dismissal action identifiers remain in app/config/test.

Action-boundary refinement: [022a](022a_library_action_boundary.md) consolidates all five user operations on `(user_id:, library_film_id:)`, removes wrappers and implicit creation, and updates dependent tests. Final full CI after consolidation passed: 436 tests / 4,752 assertions. Earlier verification above records the prior implementation stages.

## Merge evidence

Owner authorized merge after CI. [PR #36](https://github.com/adambelton/glutton/pull/36) merged on 26 October 2026 at 13:13:30 UTC; squash commit `79e2a4cc30e9c1a5f35d56d37c3619022bac333d`. Hosted Repository checks passed on exact head `6468b2baa2475d937762e69f775a25668c7caa21` at 13:10:57 UTC. Final local CI passed 436 tests / 4,752 assertions with clean style/security checks.
