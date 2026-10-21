# 011 — Library watchlist addition and removal

Status: Ready for review  
Owner: Library / intent

## Goal

Provide a small, independently verifiable watchlist lifecycle for an active user's existing film: add an unclassified or NotInterested film to To watch, remove an unwatched To watch entry, and preserve the existing watched relationship when marking it watched.

Depends on task 010's LibraryFilm persistence, uniqueness, RecordWatched operation and retention policy. Consumes established Identity active-user resolution and Film persistence only. This is a Library provider task; HTTP and future Ratings/Recommendations consumers remain separate tasks.

Read the implementation plan, product brief sections 3.3 and Ownership of viewer activity, architecture brief sections 4/11, and task 010 before implementation.

## Scope

### Synchronous operation contracts

Implementation authorized by the owner on 21 October 2026 against the following scoped contracts.

- `Library::AddToWatchlist.call(user_id:, film_id:)` accepts trusted internal IDs and returns the persisted LibraryFilmToWatch entry when no relationship exists, or transitions a permitted existing entry into ToWatch while retaining its ID and creation time. Reuse the existing table/subtype and unique user/film index.
- `Library::RemoveFromWatchlist.call(user_id:, film_id:)` accepts the same IDs, removes only the caller's ToWatch entry and returns the destroyed entry. Successful return means the row was actually removed; repeat removal is a failure.
- Resolve and lock the current User first, require `active?`, then resolve the existing Film and lock the caller's LibraryFilm where present. Use task 010's ordering and errors: missing/inactive identity raises `Library::IdentityUnavailable`; missing film raises `Library::FilmUnavailable`. All user-dependent work is scoped to that freshly resolved user.
- State-specific outcomes:

| Existing relationship | Add to watchlist | Remove from watchlist |
| --- | --- | --- |
| None | Create and return ToWatch | Raise `Library::NotOnWatchlist` |
| ToWatch | Raise `Library::WatchlistUnavailable` | Destroy and return the entry |
| NotInterested | Transition and return ToWatch | Raise `Library::NotOnWatchlist` |
| Watched | Raise `Library::WatchlistUnavailable` | Raise `Library::NotOnWatchlist` |

- Expected failures leave state unchanged. Unexpected persistence failures propagate; do not convert them into successful no-ops. Removing a reconsidered entry does not restore its former NotInterested classification; retry after a rolled-back failure remains possible.
- Preserve `Library::RecordWatched.call(user_id:, film_id:)`: a ToWatch entry becomes Watched with the same relationship ID and creation time; repeating watched still raises AlreadyWatched. Do not broaden that operation's responsibilities.

### Behaviour ownership and watched-state preservation

- Models declare `can_add_to_watchlist?`: false by default, true for the minimal LibraryFilmNotInterested subtype. The service owns concrete creation and the permitted `becomes!`/save transition. Models do not reference sibling classes. LibraryFilm supplies the shared watchlist_addition_error: nil when can_add_to_watchlist? is true, otherwise Library::WatchlistUnavailable, without subclass overrides. Repeated additions remain explicit failures.
- Removal resolves and locks LibraryFilmToWatch directly, then calls its existing `destroy!`; no additional model action wrapper is required. Missing eligible entries raise NotOnWatchlist.
- Introduce only the minimal LibraryFilmNotInterested subtype needed for transition into ToWatch. Creation of dismissals and transitions into NotInterested remain task 012. Do not add a generic transition or lookup framework.
- Preserve watched information by excluding Watched-to-ToWatch and deletion of Watched entries from these operations. A watched relationship stays watched, including when watchlist requests are stale. Rewatch intent and historical viewing storage are not needed for this outcome and must not be introduced here.
- Removing a ToWatch entry means removing only that unwatched Library classification. It does not assert that the film has never been seen, change Ratings' confirmed-unseen history, erase a rating or calculate recommendation eligibility. Those domains are not implemented/changed by this task.

### Transactions, races and retention

- Use a transaction per operation with the user-before-library lock ordering already used by RecordWatched. Retain unique-index and foreign-key protection; no schema changes are expected. Caller transaction rollback must undo a successful add/remove.
- Concurrent duplicate additions produce one success and one WatchlistUnavailable. Concurrent duplicate removals produce one success and one NotOnWatchlist.
- Removal racing RecordWatched must serialize: if watched wins, removal fails and the watched entry survives; if removal wins, RecordWatched may create a new watched relationship. Never delete a watched entry based on a stale ToWatch object.
- Addition racing RecordWatched must serialize: add-first permits the existing watched transition; watched-first rejects the add and preserves the watched entry.
- Retain task 010's approved user foreign-key cascade and restrictive film reference. Verify that ToWatch entries survive in-place guest claim and disappear with physical expired-guest cleanup, while shared Film rows remain. Do not change Identity implementation or add cleanup coordination.
- No changes to existing domain contracts are required. If implementation reveals otherwise, review ownership and revise this spec before changing scope.

## Scope restrictions

- Library implementation and Library-owned tests only. Do not edit Identity, Film knowledge, Ratings or Recommendations implementations; compatibility tests may call their established operations.
- No UI/controllers/routes, pagination or classification read API, recommendation filtering, rating eligibility calls, dismissal, unwatch, rewatch, history, watched timestamps or generic transition endpoints.
- No schema migration, further subtype, duplicated watchlist boolean, background job/event, paid service, deployment or live provider request. If storage changes become necessary, stop and revise the scope first.
- Do not infer lifecycle from concrete-class checks. Trust declared roles; re-read/lock for freshness. Tests assert observable outcomes, failures and persisted invariants rather than whole-row snapshots or private call structure.
- Any new application-authored user-facing validation text must use English locale entries and symbolic errors; static developer-only exception diagnostics may remain untranslated. No UI copy is planned.
- Implementation is authorized; publication, acceptance and merge remain separate.

## Acceptance criteria

- **AC1:** Adding/removing an unwatched film follows the table above, with explicit repeat failures and no unintended changes to another user's entry.
  Check: Library model/operation tests for guest and registered users, duplicate add/remove, missing relationship, identity isolation, missing/inactive/stale user and missing film. Verify the returned persisted/destroyed entry and resulting database row existence. Verify NotInterested-to-ToWatch preserves ID, owner, film and creation time, rejects removal before transition and allows removal afterward.
  Result: Passed — focused Library suite: 39 tests, 207 assertions, zero failures/errors/skips. Watchlist operation tests cover returned entries, repeat failures, owner isolation, registered longevity, exact guest expiry, stale/deleted/missing users and absent films.
- **AC2:** Watchlist operations cannot erase watched state; the existing ToWatch-to-Watched transition preserves relationship identity.
  Check: create a watched entry through RecordWatched; attempt add/remove and verify unchanged ownership, ID and watched behaviour. Add ToWatch through the new operation, mark watched, verify same ID, then reject removal and repeat watched.
  Result: Passed — operation and race tests preserve watched ownership, relationship ID and creation time; add/remove reject watched entries and repeated watched raises AlreadyWatched.
- **AC3:** Failure and concurrency preserve the contract.
  Check: separate-connection tests for duplicate adds/removes and both orderings of watchlist operations versus RecordWatched. Cover duplicate concurrent reconsideration and inject create/update/destroy failure and caller rollback; verify unchanged persisted outcomes and a successful explicit retry. Coordinate threads deterministically rather than relying on sleeps alone.
  Result: Passed — seven separate-connection race tests coordinate through PostgreSQL blocking evidence: duplicate add/remove and both orderings against RecordWatched. Concurrent reconsideration has one winner and one WatchlistUnavailable failure. Operation tests verify create/update/destroy failure propagation, caller rollback and explicit retry.
- **AC4:** Guest retention/claim compatibility holds without another domain's implementation changing.
  Check: use the existing real Identity confirmation and cleanup operations from Library tests; verify ToWatch identity survives claim, expired owners cannot mutate, cleanup removes only dependent entries and retains films. Reuse established retention coverage where it already proves the invariant.
  Result: Passed — real Identity confirmation retains the same watchlist entry and owner ID; expired-guest cleanup removes dependent entries, retains the shared film and leaves the claimed owner accessible. Existing Library retention tests also pass.
- **AC5:** Implementation stays scoped and passes repository verification.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/library_film_test.rb test/services/library`; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`; `RAILS_ENV=test bin/rails zeitwerk:check`; `git diff --check`. Inspect the diff for schema/other-domain/UI additions and record actual output here.
  Result: Passed — full CI: 253 tests, 2,772 assertions, zero failures/errors/skips; RuboCop 135 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. Zeitwerk application eager loading passed with the existing mail-preview exclusion. Whitespace checks passed. Application/test changes are confined to Library; no schema or UI changes. Commands are listed above. Initial CI found one extra blank line in a new test; corrected and full CI rerun successfully.

Owner scope revision: transition into ToWatch from NotInterested explicitly authorized; revision verified by the commands under AC5.

## Implementation notes

Implemented AddToWatchlist and RemoveFromWatchlist with fresh user/film resolution and the existing user-before-library lock ordering. Models declare transition permission; LibraryFilm supplies the shared rejection error without subclass overrides. AddToWatchlist creates ToWatch when absent or performs the permitted NotInterested-to-ToWatch transition with becomes! and save!. Removal resolves a fresh locked ToWatch entry and calls destroy!. Removed the misleading add_to_watchlist! and redundant remove_from_watchlist! model methods. RecordWatched is unchanged. No generic framework, new schema or other-domain implementation changes were needed.

Added ten operation/retention tests and seven deterministic concurrency tests. Reconsideration tests verify retained identity, ownership and creation time, permission, removal eligibility, failure rollback and explicit retry. All verification commands under AC5 were run on 21 October 2026 against the test environment. Existing pending documentation updates recording PR #22's merge were preserved.

Implementation was authorized on 21 October 2026. The owner explicitly expanded scope to include the minimal NotInterested subtype and transitions from it into ToWatch; transitions into NotInterested remain task 012. Watched rewatch intent, UI and other-domain consumers remain excluded.

Shared-error revision: owner requested LibraryFilm to supply WatchlistUnavailable without subclass overrides. Removed the ToWatch override and unused AlreadyOnWatchlist exception; updated operation and concurrency expectations. Re-ran `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: Passed — 252 tests/2,764 assertions, 134 Ruby files clean and security checks passed. `git diff --check` passed.

Conditional-error revision: watchlist_addition_error now returns nil when can_add_to_watchlist? is true. Model tests cover allowed and denied outcomes. Focused Library command under AC5 passed 39 tests/207 assertions; full CI passed 253 tests/2,772 assertions, style and security checks clean. Targeted RuboCop and git diff --check passed.

Owner acceptance / merge: Pending.
