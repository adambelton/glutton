# 010 — Canonical Library watched state

Status: Ready for review  
Owner: Library / viewing

## Goal

Record one canonical watched relationship for an active user's existing film and expose a transition operation returning the relationship. Depends on task 005a's session-bound current identity and task 007's Film persistence. No Ratings or Recommendations contract is consumed. This is Library's provider capability; future consuming workflows remain tasks 016/017.

Read the implementation plan, product brief sections 2 (Accounts and privacy), 3.3 and Ownership of viewer activity, architecture brief sections 4/11, and task 006d's retention restrictions before implementation. The owner approved the retention boundary below with this spec before implementation.

## Scope

### Persistence and operation (owner-approved simplification)

- Keep LibraryFilm as the STI root and LibraryFilmWatched and the narrowly scoped LibraryFilmToWatch subtype, with unique user/film identity, required references and existing scoped deletion policy.
- Store id, type, user_id, film_id and standard Rails timestamps. Remove watched_at through a follow-up migration: no current feature needs a separate confirmation/viewing timestamp.
- Library::RecordWatched.call(user_id:, film_id:) accepts internal user/film IDs and resolves both records inside its transaction, returning the persisted LibraryFilm entry. An existing entry with can_watch? false raises Library::AlreadyWatched without changing its row. Concurrent requests serialize; after one succeeds, the next fails with AlreadyWatched. LibraryFilm#can_watch? returns false; LibraryFilmToWatch overrides it to true. RecordWatched owns the permitted ToWatch-to-Watched STI transition using becomes! and save!, preserving relationship identity and returning the destination object. Source subtypes know supported actions, not sibling classes. Models expose permission only; remove model record_watched methods and WatchUnavailable. The service owns success and rejection. No classification hash or library_state method.
- Remove FilmState: no application consumer establishes a read contract. Do not add a replacement read API for tests.
- Inline the transaction and user-before-library lock order in RecordWatched; remove FilmAccess. Refresh the locked user and check active? to coordinate with cleanup/claiming. Missing/inactive users raise IdentityUnavailable. Missing films raise FilmUnavailable. Use a normal Film lookup without a row lock: there is no film-deletion workflow; the foreign key protects integrity in a racing deletion. No model persisted? checks or separate Film.exists? query. The user ID must come from trusted Identity resolution when HTTP wiring is added. Persistence errors propagate and caller rollback remains effective.
- Prevent direct LibraryFilm construction in its initializer without enumerating subclasses. Remove model/database subtype allowlists; keep required type, references and uniqueness. User construction/validation changes remain outside this Library task.
- Trust declared roles without class guards. Keep storage invariants and concrete initial watched construction; no additional transitions, placeholder types, Ratings calls or changes to Identity/Film implementations.
- Tests verify operation outcomes, identity/isolation, failures, repeat rejection, transaction/retention contracts and database invariants. Do not assert classification projections, whole attribute snapshots, collaborator classes or incidental query structure. Targeted persistence constraints may be tested directly because they are explicit contracts.

### Guest retention: approved boundary decision

- Library entries have no independent reason to survive physical removal of their owning user. Approved policy: physically delete these dependent rows in the same transaction as that user's physical deletion, retain shared Film records, and retain entries when an active guest is claimed in place as a registered user. Guest expiry still revokes access immediately; physical removal remains eventual.
- Approved mechanism: Library declares a narrowly scoped `ON DELETE CASCADE` foreign key from library_films.user_id to users.id. Film references remain restrictive. This is a Library-owned dependent-data invariant, not a global cascade, asynchronous domain communication or generic deletion coordinator. It requires no new Identity operation/callback: existing cleanup already deletes a freshly locked/rechecked expired guest in one transaction, while claiming preserves the user's ID.
- The owner reviewed and approved this scoped invariant against task 006d's requirement to agree product-activity deletion before persistence. It does not authorize relaxing other foreign keys or bypassing cleanup failures. If boundary review instead establishes that deletion has independent Library rules requiring an operation, revise this spec and agree explicit provider/consumer work before implementation; do not add hidden Identity changes here.
- Verify real compatibility by calling established Identity cleanup/claim operations from Library-owned tests without changing their implementation. A rollback of user deletion must restore Library entries alongside Identity rows; cleanup that loses a claim race must preserve the new registered identity and its entries. Cleanup output/count contracts remain unchanged. Its bounded candidate count does not bound the number of dependent entries deleted for an individual guest; document that operational limit honestly.
- No registered-account deletion workflow or retention policy is implemented. Existing registered/deleted users are not selected by guest cleanup. This entry policy is not a blanket policy for future Ratings/Recommendations records.

## Scope restrictions

- Library only. No modifications to Identity, Film knowledge, Ratings or Recommendations implementations, their models, callbacks or UI. Calling existing identity/film persistence contracts and verifying compatibility is allowed; a required change in another domain needs separate ownership review/specification.
- No HTTP/controller/view/navigation work, watched list, watchlist, dismissal, unwatch, date editing, rewatch/history or public API endpoint. Task 011 adds watchlist addition/removal beyond the minimal ToWatch model and watched transition authorized here; task 012 introduces LibraryFilmNotInterested and its transitions; tasks 017/020 introduce workflow/view behaviour. Those later specs must define preservation of independent watched facts before implementing transitions; changing STI type must not silently erase viewing history.
- Only ToWatch-to-Watched is permitted in this task, explicitly authorized by the owner. Do not add generic caller-selected transition APIs. Transitions must be explicit and transactional, preserving the same relationship ID and uniqueness invariant. They must not be implemented through unrestricted caller-supplied type assignment or an automatic destroy/recreate convention.
- No Ratings selection, rating submission/current-rating lookup, make-available calls or queuing. Saving watched does not imply a completed rating. Library subtype behaviour must not be used as a new prerequisite imposed on Ratings: the agreed Ratings operation accepts a rating without a watched Library record and records watched only on completion. Future Library UI may expose actions appropriate to its type; that does not relocate rating persistence or change the Ratings contract. This primitive must not trigger Ratings; task 017 owns that consuming workflow and task 016 records watched after rating without requeueing.
- Review existing application class checks read-only for comparable internal argument guards; retain external HTTP/JSON/configuration validation, schema-shape checks and targeted exception recovery. Do not change other domains or replace Identity lifecycle-policy branches under this Library task. Record findings rather than broadening implementation scope.
- No TMDB calls/import, AI/JEV, jobs/events, generic integration/retention framework, scheduler, paid service, deployment or merge. Updating the existing PR is owner-authorized. No development/production data writes during verification; use isolated test records/databases.
- Use Rails locale entries and symbolic model validation errors for new application-authored validation text. Developer-only exceptions remain static diagnostics; there is no new application UI copy.

## Acceptance criteria

- **AC1:** Recording watched returns a durable relationship for the requested user/film; repeated calls fail with AlreadyWatched and preserve the existing row; concurrent calls produce one success and one AlreadyWatched without duplicates.
  Check: focused model/operation/concurrency tests; no watched_at, FilmState, FilmAccess or library_state remains in runtime code/schema.
  Result: Passed — focused Library/model suite: 21 tests, 102 assertions, zero failures/errors/skips. Runtime code and schema contain none of the removed field/services/projection.
- **AC2:** Fresh active-user and film-existence contracts reject unavailable collaborators without writes; user isolation and guest deadline remain enforced.
  Check: missing-ID, lifecycle-change, expiry and isolation tests.
  Result: Passed — focused tests cover exact guest expiry, registered longevity, stale/deleted/missing users, unavailable films, ID resolution and user isolation without classification reads.
- **AC3:** Existing cleanup/claim compatibility, restrictive film references, rollback and explicit retry work without changing other domains.
  Check: Library retention/concurrency tests with real Identity operations; full CI, eager loading and whitespace checks.
  Result: Passed — real cleanup/claim and separate-connection concurrency tests pass, including outer rollback, injected persistence failure and explicit retry. Full CI: 219 tests, 2,533 assertions, zero failures/errors/skips; RuboCop 123 files clean; gem/importmap audits clean; Brakeman zero errors/warnings. Zeitwerk application eager loading passes with the existing mail-preview exclusion. Whitespace checks pass.

## Implementation notes

LibraryFilm and LibraryFilmToWatch expose can_watch? (false by default, true for ToWatch). Models contain no sibling-class references or record_watched methods. RecordWatched resolves IDs inside the transaction, locks the user and existing entry, creates an initial watched entry or executes the permitted STI transition using becomes! and save!. False permission raises Library::AlreadyWatched. The returned object represents the resulting subtype; identity, ownership, film and creation time survive a transition.

Owner explicitly replaced the earlier idempotent-success contract: repeated and concurrent requests after success must raise AlreadyWatched without modifying the row. System consumers must specify their own justified duplicate handling; they must not mask unrelated failures. A retry following rolled-back persistence remains possible. No model-level fallback action or WatchUnavailable remains.

Removed FilmState, FilmAccess, library_state, subtype allowlists and redundant watched_at. Follow-up migrations preserve already-applied migration history and were applied only to the test database. Root construction is rejected without subclass enumeration. Destination-save failure and caller rollback preserve the original ToWatch row; retry succeeds. Separate-connection tests cover serialized transition rejection and existing Identity claim/cleanup compatibility. No Identity or Film implementation changes, network requests or non-test data writes.

User transition refactoring remains deferred to the Identity-owned follow-up. The minimal ToWatch subtype and its watched transition are explicitly owner-approved; watchlist management/UI, dismissal and reverse transitions remain deferred.

Reproduce verification:

```sh
RAILS_ENV=test bin/rails db:migrate
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/library_film_test.rb test/services/library
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
RAILS_ENV=test bin/rails zeitwerk:check
git diff --check
```

Final already-watched rejection verification: Passed — focused suite 21 tests/102 assertions; full CI 219 tests/2,533 assertions, zero failures/errors/skips; RuboCop 123 files clean; dependency audits clean; Brakeman zero warnings/errors; Zeitwerk application eager loading passed with the existing preview exclusion; git diff --check passed. No migration was needed for this revision.

Owner authorization: Spec, scoped cascade, minimal ToWatch transition, ID inputs and explicit AlreadyWatched failure approved on 20 October 2026. Updating PR #20 is authorized. PR #20 was originally opened without approval; the owner subsequently authorized updates for review. Acceptance and merge remain pending; no merge is authorized.
