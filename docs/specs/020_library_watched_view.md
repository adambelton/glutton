# 020 — Browse the Library and start a rating

Status: Merged  
Owner: Library / browsing

## Goal

Build one mobile-first **Library page**, with a dropdown at the top that defaults to **Watchlist** and also offers **Watched** and **Not interested**.

The user journey delivered by this task is:

1. Open Library: see Watchlist selected and the user’s to-watch films.
2. Select Watched: see watched films with title, release year when available, and Rated or Awaiting rating.
3. Select Rate this film beside an unrated watched film to open the existing Ratings form.
4. Revisit the Watched view after saving: its rating status reflects the saved rating.
5. Select Not interested to browse that part of the Library.

Each selection has its own URL state and empty message. Lists are read-only in this task; watchlist and not-interested management actions remain later work. Ratings supplies the existing form and remains the default product landing destination.

Global navigation is Ratings, Recommendations and Library along the bottom on mobile, moving to the header on desktop. There is no separate homepage-to-watched-page flow. The shared navigation shell is supporting UI work; this Library-owned task defines the Library destination and its contents. See the mobile-first navigation decision in the product and architecture briefs.

## Scope

### Concrete changes

- Add one Library controller action and GET route with a view selection parameter. Default to Watchlist; allow Watched and Not interested.
- Add a Library query/service that loads the signed-in user’s entries for the selected view and reads whether their films have Ratings-owned ratings.
- Add the page template, translated labels/empty state/navigation, and the top-of-page view dropdown.
- Link unrated rows to the existing Ratings entry using the shared Film ID.
- Add request/query tests and verify the complete list-to-rating journey in a browser.

No new stored information is needed. Library supplies which films are watched; Ratings supplies whether they have been rated. Read both existing sources when building the page. Do not store a copy of rating status in Library.

Read the implementation plan, task 010, task 019 and docs/ratings_targeted_entry.md before implementation. The ownership clarification in docs/architecture_brief.md and docs/domain_events.md applies: shared reads are allowed; mutations and invariants remain owned by their respective domains. Withdrawn proposal 020a is not a prerequisite.

### List behaviour

- Show only the session owner’s entries matching the dropdown: Watchlist uses ToWatch, Watched uses Watched, and Not interested uses NotInterested. Show existing film title and optional release year.
- Use a labelled native select that automatically submits on change, without a Show films button, above a single-column mobile list, with comfortable touch targets and a centred, wider list on desktop. Preserve selection in the URL and pagination links, and reset the page when changing views. Validate the allowed view names; do not accept arbitrary model/class names.
- Apply rating status and Rate this film links only in the Watched view.
- Propose a bounded page of 25 entries ordered by Library entry created_at descending, then ID descending, with simple previous/next navigation. This orders entry creation, not viewing date; do not add or imply a watched_at timestamp. Validate page input at the HTTP boundary, and keep loading bounded without a new pagination dependency.
- Derive Rated versus Awaiting rating from an actual Rating associated with the same user and Film through RatingFilm. A candidate alone, including a held or dismissed one, is not a completed rating. Another user’s rating must never affect the display.
- Use an efficient scoped query or bounded batch lookup, avoiding one Ratings query per displayed row. Shared model/scopes/subqueries are permitted. Put entity selection in Library’s query/service layer, consistent with the controller/service boundary; do not add ownership rules or mutations to the controller/view.
- Use the current first-rating contract: rating existence establishes completion. Do not implement speculative current/superseded logic before task 023; that later task must update dependent reads when its lifecycle changes.
- Show a localized empty state and accessible status text. No rating values, expressions or rating-history details are needed in this slice.

### Rating entry

- For each Awaiting rating row, provide a localized “Rate this film” link using `new_rating_path(film_id: film.id)`. Pass only the shared Film ID; Ratings resolves the session owner and creates/reuses its own candidate on GET under task 019’s established behaviour.
- Library page rendering does not create RatingFilm, Rating or events. Following the link delegates the candidate operation to Ratings. The link works even before the Library watched event has admitted a Ratings candidate, and even when an existing candidate is held/dismissed.
- Rated rows display their status without a rating-replacement action. Replacement belongs to task 023.
- Shared reads reflect committed rating evidence on the next page request without waiting for Library’s Ratings-event consumer. Library membership still depends on Library’s own state: a rating for a film not yet watched in Library does not insert that film into this list. Existing asynchronous watched reconciliation remains unchanged.
- A rating may be submitted after the list is rendered; task 019 already handles stale links with an explicit AlreadyRated response. Do not add locking across page display or synchronous reconciliation.

### Identity, boundaries and presentation

- Resolve identity through existing session helpers, never a user ID from request parameters. Signed-out/expired/revoked sessions receive localized sign-in/registration navigation; deleted accounts retain established behaviour. No guest creation on browsing.
- Preserve no-store responses, escaped Film titles, strict translations, labelled links/status/navigation and keyboard access. Put all authored UI text in locale files. Reuse existing home/session conventions without changing Identity runtime code.
- Shared reads are authorized; writes remain owned. No direct mutation of Ratings records, no duplicated domain information, no changes to rating invariants or lifecycle, and no new projection/read API merely to conceal an ordinary join.

## Scope restrictions

- Library owns the route, query/service, list views and dropdown. Shared application navigation and the default Ratings route belong to a separate supporting UI scope; do not modify the application shell as incidental Library wiring. Do not modify Ratings/Identity/Film runtime behaviour or event infrastructure. Reuse the verified Ratings destination.
- No database migrations, new columns/tables, subscriptions, event changes, replay/backfill or worker deployment.
- No watchlist/not-interested management actions, mark-watched form, search/TMDB import, filtering/sorting controls beyond the fixed list, rating editing/replacement, expressions display, recommendations or scoring.
- No Recommendations screen, shared navigation-shell implementation, generic query framework or new frontend/pagination dependency.
- Owner approved this scope before implementation.

## Acceptance criteria

- **AC1:** Library defaults to Watchlist and each selection shows only the correct owner’s matching films; Watched shows authoritative rating status.
  Check: absent candidate, unrated candidate, held/dismissed combinations and completed rating; another user’s rating of the same film must not count. Verify all three list memberships; exclude nonmatching states and other owners’ entries. A saved rating updates status on a fresh GET without delivery; a rated film with no Library watched entry stays absent. Rendering creates no records/events.
  Result: Passed — LibraryBrowserTest verifies all three owner-scoped views, all held/dismissed combinations, absent candidates, other-user rating isolation, immediate committed rating visibility and no rendering writes.
- **AC2:** The list is bounded, stable and usable.
  Check: dropdown default/selection, URL refresh and back/forward behaviour, resetting pagination on selection change, invalid view parameters, proposed 25-row limit, deterministic ordering/ties, previous/next and empty pages, malformed page input, bounded Ratings lookup rather than per-row queries, localized empty/status/title/year rendering and missing release dates. Verify observable results rather than exact SQL text.
  Result: Passed — request tests verify 25-row pages, deterministic timestamp ties, previous/next links, empty pages, invalid page/view shapes and page reset. BrowseTest verifies query count stays constant from one to thirty entries, including film reads. Browser checks verified selection, refresh and history; Turbo snapshot caching is disabled to keep restored selection and rating evidence fresh.
- **AC3:** Unrated films link to the established Ratings workflow without crossing write ownership.
  Check: link contains the shared Film ID and no owner/internal candidate ID. Follow it with no candidate and with held/dismissed candidates: Ratings admits/reuses the correct row and presents the form. Rated rows have no replacement action. Concurrently completed ratings receive the existing explicit stale-link response. No Library-side Ratings writes.
  Result: Passed — request tests follow actual links, admit missing candidates, reuse held/dismissed candidates, submit ratings and reject stale already-rated links. Real browser walkthrough saved a rating and immediately displayed Rated in Library without event delivery.
- **AC4:** Identity, privacy and accessibility hold.
  Check: active guest/registered access, signed-out/expired/revoked/deleted sessions, ignored ownership tampering, no-store, escaped film titles, strict translations and keyboard navigation. Verify single-column layout at narrow mobile widths and the wider desktop list. Use real established operations/session behaviour in request tests.
  Result: Passed — tests cover guest/registered, signed-out/revoked/expired/deleted sessions, owner tampering, no-store, escaping and strict translations. Browser verified keyboard selection and single-column layouts at 320px and 375px, plus centred desktop layout at 1280px.
- **AC5:** Final implementation evidence is recorded.
  Check: focused Library query/request tests and existing Ratings browser regressions; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record a browser walkthrough from watched list to rating form and back after save using disposable fixtures, plus any limitations. No schema changes/deployment expected.
  Result: Passed — final full CI: 425 tests / 4,556 assertions, zero failures/errors/skips; style and security checks passed. Eager loading and diff checks passed. Browser walkthrough details and limitations below.

## Implementation notes

Implemented GET `/library` through `LibraryController#show`, `Library::Browse`, localized templates and scoped responsive CSS. The controller validates URL inputs and resolves session identity; Browse loads owned entries and batches authoritative Ratings evidence. Pages contain at most 25 entries, with one extra row to detect the next page. Positive page numbers accept at most nine digits to bound offset arithmetic. The native dropdown automatically submits through a small Stimulus controller, as requested during review; there is no Show films button. Existing event consumers are unchanged. Shared navigation/root wiring remains the separately scoped supporting UI work.

Owner accepted and authorized merge; merged via PR #34.

Documentation verification: reviewed AGENTS.md, architecture/event guidance, task template and implementation plan for the ownership/read distinction; marked 020a withdrawn and removed it as a dependency. `git diff --check` passed. No application code changed and no runtime tests were run for this documentation update.

Scope revision: the owner selected three mobile bottom destinations and one Library dropdown, defaulting to Watchlist. Task 020 now covers all three read-only Library views so the dropdown has working destinations; tasks 021/022 retain management actions rather than separate screens. This supersedes the standalone watched page/home-link proposal. No application code changed.


### Final verification — 26 October 2026

- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — 425 tests / 4,556 assertions, no failures/errors/skips; style, dependency/importmap audit and Brakeman checks passed. Includes Library query/request tests and existing Ratings regressions.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed; existing mailer-preview exclusion notice remains.
- `git diff --check` — passed.
- Browser: seed a disposable registered account with one entry in each Library view in the test database; start `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3020 -P /tmp/glutton020-server.pid`. Open `/library`, sign in, verify Watchlist default, select Watched, follow Rate this film, submit I enjoyed that, then reopen `/library?view=watched`: Rated appears without a worker delivering events. Select Not interested; refresh and navigate Back/Forward. Repeat layout checks at 320×640, 375×812 and 1280×900. After the automatic-dropdown change, keyboard-select Watched and confirm URL/list update without a button; Back restores the previous selection. Snapshot: `/tmp/glutton020-mobile.png`.
- Browser persistence was verified before removing the disposable account/films. Temporary server stopped and viewport override reset. The browser used test-environment CSRF settings; existing Ratings regression tests exercise CSRF separately. Real-device/screen-reader testing and zoom were not performed.
- Initial checks found test-clock boundary fixtures and accidentally replaced model locale labels; both corrected. Browser history exposed stale Turbo snapshot selection, fixed with page-local no-cache metadata. One later CI run was contaminated by disposable browser fixtures; removing those fixtures restored the empty baseline and the full suite passed. No migrations, domain-state duplication or new event contracts.

Owner-requested refinements during implementation: automatic collection update on dropdown change; `LibraryController` instead of `Library::FilmsController`. Supporting follow-up 020b applies the agreed top-level controller convention to both Library and Ratings. These remain within the approved Library browsing scope. Owner accepted and authorized merge; merged via PR #34.

Merge evidence: owner approved on 26 October 2026. [PR #34](https://github.com/adambelton/glutton/pull/34) merged at 11:26:07 UTC as `3ed26aed38ca404329efbfa06df144a663abc819`. Hosted Repository checks passed at 11:25:36 UTC for head `42468ab9d5ae88bf0e580b97a04c5ab4d92ffe12`.
