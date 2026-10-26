# 019 — Explicitly rate a selected film

Status: Merged — PR #33 on 26 October 2026  
Owner: Ratings / targeted entry

## Goal

Allow an active guest or registered user to rate a film selected from their Library, including films excluded from automatic rating rotation. This task supplies the Ratings destination; the subsequent Library task adds the link.

Library links to Ratings using the shared Film ID. Ratings finds or creates its own RatingFilm when the explicit form is opened, even if the Library event has not yet admitted it. Neither domain needs the other’s internal record ID. This does not introduce a separate catalogue-browsing screen.

Read the implementation plan’s superseding queue/hold decisions, task 018, tasks 014–017, the product/architecture brief Ratings sections and docs/ratings_event_publication.md. Use established Identity session resolution, shared Film reads and Ratings submission/publication. No synchronous Library calls or new cross-domain service contract.

## Scope

### Targeted browser entry

- The intended entry is a “Rate this film” link from Library. Implement the receiving Ratings destination here; add the Library link in task 020.
- Add a Ratings-owned GET destination identified by the shared internal Film ID, with a corresponding CSRF-protected submission. Document its route/helper, required input and browser outcomes for future Library links. Do not require a RatingFilm ID or Library model/reference from callers.
- Resolve the owner exclusively from the existing signed session. Support active guests and registered users; signed-out/expired/revoked sessions show the existing sign-in/registration path, and deleted accounts retain established behaviour. Do not create guest identities in this slice.
- Read the existing Film for title/release-year display. Missing or malformed Film IDs produce a localized unavailable response. No catalogue import, search or external lookup.
- Explicit GET finds or creates the owner’s RatingFilm under a fresh active-owner lock. Repeated entry preserves its identity, timestamps, held and dismissed flags. Leaving the form unfinished retains an eligible candidate in the queue. No Rating, expressions or event are created until submission. Automatic entry still selects an existing pending candidate.
- If the owner has already rated the film, show an explicit localized already-rated outcome with navigation back to the queue. Do not imply that editing or replacement is supported.
- Reuse the task 018 rating/expression form and validation behaviour where practical. Keep one set of choice labels and expression limits, preserve original nonblank text and filter expression parameters from logs. Provide a clear cancel/back-to-queue link; do not add dismissal/hold/watchlist controls to targeted entry.

### Submit against an existing rating film

- The rendered form submits rating_film_id, scoped exclusively to the session owner. Reuse SubmitRating; never find-or-create a candidate during submission. A missing, deleted or foreign candidate is unavailable.
- Rating, expressions and event commit or roll back together. Invalid input or publication failure preserves the candidate previously admitted on entry. No empty-candidate rollback is desired: unfinished candidates are persistent queue entries.
- Existing candidate identity, created_at, held and dismissed remain unchanged. Do not release a hold or clear dismissal synchronously. Normal asynchronous Library/Ratings reactions continue through the existing subscriptions.
- No Library watched prerequisite, Library query or synchronous Library mutation. This must work before the watched-event consumer has admitted a candidate.
- Keep first-rating duplicates as explicit AlreadyRated failures. Concurrent targeted submissions or a targeted submission racing queue submission must produce one rating/event; the loser reports the existing failure. Serialize candidate admission against existing Library-event consumption through the existing owner lock and uniqueness constraint.
- Validation errors retain the selected film, choice and valid-shaped expression input for correction, including when no candidate existed. Foreign candidate IDs, user IDs and client-supplied held/dismissed/nested record attributes cannot select another owner or mutate state.
- Success uses post/redirect/get with the existing saved notice and queue destination. It confirms Ratings persistence only, without waiting for downstream processing. A stale second submission returns an explicit conflict.

## Scope restrictions

- Ratings owns the route, controller/form changes and any needed internal operation. No Library UI/wiring, Library model access, Identity runtime changes or catalogue changes. Task 020 will consume the documented destination independently after provider verification.
- No new tables/columns, event names/payload changes, new subscriptions or delivery framework. No rating revisions/supersession, saved-rating history screen, expression edits, scoring/profile processing or snooze controls.
- No automatic queue replenishment, popularity policy, first-time anonymous discovery or guest creation. The explicit selection of one existing Film is not a catalogue-admission policy for the automatic feed.
- Use one Ratings::RatingsController with new accepting optional film_id and create submitting against an existing rating_film_id for both paths. Automatic selection respects queue eligibility; explicit entry bypasses it. Dismissal is an action on the same controller. Do not refactor unrelated controllers/services.
- Owner approved implementation on 26 October 2026. No deployment or external communication is included.

## Acceptance criteria

- **AC1:** Explicit entry admits or reuses the owner’s RatingFilm before rendering.
  Check: request tests for absent/pending/held/dismissed candidates and all combinations of held/dismissed, repeated GETs preserving candidate identity/timestamps and unfinished candidates remaining queued, title/year display, already-rated outcome, invalid/missing Film and signed-out/expired/revoked/deleted identity. No Library record is required; another user’s candidate/rating does not affect access.
  Result: Passed — request tests cover repeated GETs preserving candidate identity/timestamps and unfinished candidates remaining queued, absent/existing candidates, all held/dismissed combinations, foreign-owner ratings, missing/malformed IDs and inactive session outcomes. The same shared form displays title/year without Library reads or persistence.
- **AC2:** Targeted first submission preserves the established rating contract and is atomic.
  Check: all four values, zero/multiple expressions, exact whitespace, malformed/over-limit input, validation rerender and one unchanged RatingSubmitted event. New candidate appears on explicit entry; submission never creates one, and invalid input preserves it. Missing/deleted/foreign candidates cannot be submitted. Existing flags/created_at/evidence remain unchanged. Duplicate submission fails explicitly. No synchronous Library writes.
  Result: Passed — service/request tests verify all four values, optional exact expressions, preservation of admitted candidates on invalid input and missing/foreign/deleted candidate rejection, unchanged existing flags/created_at, duplicate failures and one unchanged v1 event. Existing queue tests pass after form extraction.
- **AC3:** Concurrent activity cannot duplicate candidates or ratings or erase user state.
  Check: separate-connection tests for two targeted first submissions, targeted versus queue submission, and targeted admission versus real Library-event delivery. Assert one owner/film candidate, one first rating/event, preserved expression evidence, explicit duplicate failure and the established held/dismissed reactions. Reuse existing delivery/lifecycle tests rather than duplicating the entire transport suite.
  Result: Passed — separate-connection tests cover competing targeted admission, queue versus targeted submission in both orders, expiry while admission waits, and real Library delivery racing targeted admission in both orders. One candidate/rating is retained, original evidence survives and the event-applied hold is preserved.
- **AC4:** The browser boundary and future Library destination are independently verifiable.
  Check: CSRF on POST, no-store, escaping, strict translations, session-derived ownership, ignored ownership/state tampering, accessible labels/errors, keyboard form flow and validation preservation. Document the exact route and inputs/outcomes using only shared Film identity. Verify task 018 queue flow remains unchanged.
  Result: Passed — CSRF, no-store, session ownership/tampering, escaping, strict translations, labels/error associations and validation preservation tested. Browser keyboard walkthrough passed. The shared-Film-ID route and outcomes are documented in docs/ratings_targeted_entry.md; no Library implementation was added.
- **AC5:** Final evidence is recorded before review.
  Check: focused Ratings request/service/concurrency tests; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record a browser walkthrough for a film without a candidate and an existing held/dismissed candidate, using disposable test fixtures and verifying persistence. Record any tooling limitations and actual results. No migration/deployment expected.
  Result: Passed — focused request/service/concurrency command: 78 tests / 1,050 assertions. Full CI: 411 tests / 4,447 assertions, zero failures/errors/skips; style/security checks clean. Rails eager loading and whitespace checks passed. Real browser walkthrough and database persistence verification passed; reproducible steps below.

## Implementation notes

The final GET-admission decision below supersedes earlier verification notes about read-only GETs and submission-time admission. Final verification is recorded at the end.

Implemented `new_rating_path(film_id: film_id)` for explicit explicit entry, or `new_rating_path` for the next pending candidate. Both forms submit to `ratings_path` through Ratings::RatingsController#create. One new template/form handles both. Ratings::RatingsController also handles dismissal and owns the browser identity/error handling directly; the separate candidate and Ratings base controllers are removed. Ratings::PrepareCandidate locks the fresh owner and finds/creates RatingFilm on explicit GET. Submission requires an existing owned RatingFilm and calls SubmitRating directly. Model rules and event publication stay unchanged. No new schema, Library reads/writes, Identity changes or candidate refill.

Provider destination and outcomes: [targeted entry contract](../ratings_targeted_entry.md). Library linking and rated/awaiting-rating display remain task 020. Owner acceptance and merge are separate from spec approval.

Verification commands:
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/ratings_targeted_entry_test.rb test/integration/ratings_browser_test.rb test/services/ratings` — passed: 78 tests / 1,050 assertions.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — passed: 411 tests / 4,447 assertions; 211 Ruby files clean, dependency/importmap audits clean, Brakeman zero warnings/errors. Explicit connection/thread concurrency checks still run with one test worker.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed for application code, with existing mailer-preview exclusion notice.
- `git diff --check` — passed.

Initial test run exposed an incorrect test assumption that UUID event ordering identifies the latest submitted rating; the assertion now selects the event for the actual rating ID. Targeted style checks caught five test formatting offenses, corrected before full CI. No production failures or scope deviations were found.

Browser walkthrough (26 October 2026):
1. In the test database only, create a disposable registered account and two existing Film rows. Leave the first without a RatingFilm; give the second a RatingFilm with held=true and dismissed=true. Start `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3019 -P /tmp/glutton019-server.pid`.
2. Open `/ratings/films/<first-film-id>` signed out: sign-in/registration links appear. Sign in with the disposable account and reopen that destination: correct title/year, four choices, optional expressions and queue return link; no dismissal button.
3. Select Brilliant using Space, expand expressions using Enter, enter `  Atmosphere  `, collapse, Tab to Save rating and Enter. Observe saved notice and empty automatic queue.
4. Open `/ratings/films/<second-film-id>`: form remains available despite both exclusion flags. Select I enjoyed that and submit using the keyboard. Observe saved notice. Reopen: explicit already-rated response with queue return link. Screenshot: `/tmp/glutton019-browser-result.png`.
5. Reload database records: two first ratings, exact original expression whitespace, unchanged second-row held/dismissed flags and two events verified. Delete only disposable test sessions/user/films and stop server.

Browser server used normal test configuration; request tests explicitly enabled and exercised CSRF enforcement. Test fixtures were removed. No migration, development-data changes, external service calls or deployment.

Owner acceptance / merge: Authorized and merged; see evidence below.

## Owner review refinement — unified rating entry

Owner requested one Ratings::RatingsController: new accepts optional film_id, selecting the next pending candidate when omitted, and create submits by shared Film ID for both paths. Replace the separate candidate/film rating routes and forms; candidate dismissal remains a separate action. This supersedes the earlier two-controller implementation and candidate-ID submission endpoint. Keep the same ownership, read-only GET, atomic submission and eligibility rules. Verify both modes through the unified controller, malformed optional IDs, empty queue, form film identity and explicit dismissal ownership.

Unified-entry verification: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/ratings_browser_test.rb test/integration/ratings_targeted_entry_test.rb` passed (17 tests / 308 assertions). `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed (412 tests / 4,451 assertions; 211 Ruby files clean; all security checks passed). `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check` passed. Request tests exercise both new modes, the shared POST, hidden Film ID, malformed supplied IDs, missing submission ID, preserved validation input, owner-scoped dismissal and CSRF on both writes. The browser walkthrough above predates this route/controller consolidation; it was not rerun, and its old URLs are historical. Use `/ratings/new?film_id=<id>` to reproduce explicit entry, `/ratings/new` for queue entry and POST `/ratings` for both saves. No old rating entry helpers/controllers remain in app/test.

Owner review: consolidate dismissal into Ratings::RatingsController as well, and remove CandidatesController and the Ratings base controller. All browser workflow actions share identity/error handling directly in that one controller. Preserve owner-scoped dismissal, explicit duplicate failure and CSRF protection.

Dismissal-consolidation verification: focused browser request tests passed (17 tests / 308 assertions). Full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed (412 tests / 4,451 assertions; style/security clean). Rails eager loading and `git diff --check` passed. Existing request cases now exercise POST `/ratings/dismiss` on Ratings::RatingsController for successful dismissal, foreign/malformed/missing candidates, duplicate failure and CSRF rejection. The controller delegates directly to Dismiss after validating the external ID; ownership and fresh identity checks remain in that service. No additional browser walkthrough was run for this consolidation.

## Superseding owner decision — persist candidates on explicit GET

Explicit new(film_id:) must find or create the session owner’s RatingFilm before rendering. Unfinished candidates remain in the automatic queue if eligible. Repeated GETs preserve identity, timestamps, held and dismissed. Owner explicitly prefers this GET behaviour over POST/redirect admission. Create accepts only an existing owned rating_film_id and uses SubmitRating; it must never create candidates. Remove SubmitFilmRating. Verify repeated/concurrent admission, abandoned forms, existing state, inactive/missing inputs and missing/foreign submission rejection. This supersedes earlier read-only GET and submission-time admission requirements and evidence.

Final GET-admission verification: focused request/service tests passed (79 tests / 1,017 assertions). Full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed (412 tests / 4,414 assertions; style/security clean). Application eager loading and `git diff --check` passed. Added concurrent entry coverage demonstrating one unfinished candidate, repeated GET identity/state preservation, abandonment followed by queue selection, and POST rejection of missing/foreign/deleted candidates even when a valid Film ID is supplied. Submission uses existing SubmitRating tests for rating/expression/event atomicity. Removed submission-time candidate creation service and its obsolete tests. No additional manual browser walkthrough was run for this change.

Owner readability follow-up: new now calls explicit load_film, which validates the external film_id and loads the Film before candidate preparation. PrepareCandidate retains its transactional freshness check. Focused browser tests passed (18 tests / 333 assertions), targeted controller RuboCop passed, and git diff --check passed. Full CI was not repeated for this extraction.

Owner boundary refinement: controllers validate HTTP parameter shape/format and translate outcomes; services load entities, validate existence/ownership/freshness and coordinate locks/transactions; models retain action permissions. Remove controller entity queries. Explicit preparation rejects already-rated candidates in the service. Validation rerender obtains the existing owned candidate through a Ratings read service, without admitting or changing it. Verify invalid input retention and missing/foreign/inactive read failures. Limit runtime changes to Ratings.

Controller/service boundary verification: existing focused Ratings request/service tests passed (79 tests / 1,017 assertions). Added four service regression tests for read-only owned lookup, missing/foreign/deleted candidates, inactive identity and already-rated preparation. Final full CI passed (416 tests / 4,438 assertions; style/security clean). Rails eager loading and git diff --check passed. Controller contains no entity queries or model-permission checks; ID helpers validate HTTP shape/format, services enforce entity rules, and FindCandidate reloads an owned candidate for validation rerender without admission. AGENTS.md records the agreed boundary. No browser walkthrough was repeated for this internal refactor.

Final owner edit retained: create passes rating_film_id_param directly to SubmitRating instead of storing a temporary local. Full CI rerun on the final tree passed (416 tests / 4,438 assertions; style/security clean); git diff --check passed. Owner approved PR and merge after hosted CI.

## Merge evidence

Owner authorized merge after CI. [PR #33](https://github.com/adambelton/glutton/pull/33) merged on 26 October 2026 at 10:15:01 UTC (GMT), squash commit `ec279e23ed17312900fac7ea32d6ed1a9c08f8d5`. Hosted Repository checks passed on exact head `8f2197dca066b36584e35813707593cabc92ca50` at 10:14:26 UTC. Local main was fast-forwarded. Final local CI passed 416 tests / 4,438 assertions with clean style/security checks, including the owner’s final controller edit.
