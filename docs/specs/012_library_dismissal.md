# 012 — Library dismissal and removal

Status: Ready for review  
Owner: Library / dismissal

## Goal

Provide one small dismissal lifecycle: classify an unclassified or ToWatch film as NotInterested, and remove only an existing NotInterested classification without erasing watched information.

Depends on tasks 010/011 for persistence, explicit transitions, lock ordering and retention. NotInterested-to-ToWatch reconsideration is already implemented by task 011. Read the implementation plan, product brief sections 3.2/3.3 and Ownership of viewer activity, architecture brief sections 4/11, and specs 010/011 before implementation.

## Scope

### Approved synchronous contracts

- `Library::MarkNotInterested.call(user_id:, film_id:)` accepts trusted internal IDs and returns the persisted NotInterested entry. Create it when no entry exists; otherwise check the source's permission and perform the permitted transition in this service, retaining ID, owner, film and creation time.
- `Library::RemoveNotInterested.call(user_id:, film_id:)` resolves and locks the caller's NotInterested entry, calls `destroy!` and returns the destroyed entry. Removal means the classification was actually removed. It does not add the film to the watchlist.
- Both operations freshly resolve and lock User, require `active?`, resolve Film, then lock the scoped entry, matching existing Library ordering. Missing/inactive users raise `Library::IdentityUnavailable`; absent films raise `Library::FilmUnavailable`.

| Existing entry | MarkNotInterested | RemoveNotInterested |
| --- | --- | --- |
| None | Create NotInterested | Raise `Library::NotMarkedNotInterested` |
| ToWatch | Transition to NotInterested | Raise `Library::NotMarkedNotInterested` |
| NotInterested | Raise `Library::DismissalUnavailable` | Destroy and return entry |
| Watched | Raise `Library::DismissalUnavailable` | Raise `Library::NotMarkedNotInterested` |

- Models declare `can_mark_not_interested?`, false by default and true for ToWatch. LibraryFilm supplies `dismissal_error`, returning nil when permitted and `Library::DismissalUnavailable` otherwise, without subclass overrides. Services own concrete creation and `becomes!`/save transitions. No subclass references sibling classes or performs its own transition.
- Duplicate user actions fail explicitly. Expected failures leave persisted state unchanged; unexpected persistence failures propagate. Caller rollback must undo successful operations; explicit retry after rollback remains possible.
- Removal changes only Library classification. It does not erase Ratings' confirmed-unseen information, alter ratings, compute recommendation eligibility or add negative taste evidence.

### Concurrency and retention

- Reuse user-before-entry locking, unique user/film index and foreign keys. No schema changes.
- Duplicate concurrent dismissal has one success and one DismissalUnavailable; duplicate removal has one success and one NotMarkedNotInterested.
- Dismissal versus watchlist addition serializes through fresh state: add-first creates ToWatch then dismissal transitions it; dismissal-first creates NotInterested then addition transitions it. In both orders there is one relationship and transitions preserve its ID.
- Removal versus watchlist addition from NotInterested: removal-first permits new ToWatch creation; addition-first preserves the transitioned ToWatch and removal fails. Never delete based on a stale subtype.
- Preserve existing RecordWatched behaviour. From an initial ToWatch entry, watched-first makes dismissal fail; dismissal-first leaves NotInterested and RecordWatched rejects under its current contract. This task does not enable NotInterested-to-Watched. That transition and the existing broad AlreadyWatched rejection need a separate watched-operation decision before changing them.
- Verify existing Identity guest claim/cleanup compatibility through Library-owned tests: claim retains NotInterested entry identity; guest expiry rejects actions immediately; physical cleanup removes dependent entries while retaining shared films. No Identity changes.

## Scope restrictions

- Library application code/tests only; consume established Identity and Film contracts without changing those domains.
- No UI, controllers, routes, pagination, dismissal reasons, recommendation logic, ratings, unwatch, rewatch or viewing history. Watched-to-NotInterested is disallowed.
- No new subtype, schema migration, generic transition/lookup framework, background event/job, live provider request, paid service, deployment or merge.
- No classification read API in this task. The plan's original read work is deferred to a separately specified consumer need; tests must not invent a production classification projection.
- Preserve existing watchlist and watched APIs. Do not broaden RecordWatched or introduce silent idempotent successes.
- Trust model roles; use fresh locked records for correctness, not class/reflection switches. Any new user-facing text must use Rails locales; no UI copy is planned.
- Owner approved this spec and implementation on 21 October 2026. Publication and merge remain separate.

## Acceptance criteria

- **AC1:** Creation, transition and removal follow the table with explicit failures and owner isolation.
  Check: operation tests for guest/registered owners, returned persisted/destroyed entries, duplicate requests, missing/inactive/stale identities, absent films, and unchanged watched entries. Verify transition ID, owner, film and creation time; verify permission/error consistency.
  Result: Passed — focused Library/model suite: 58 tests, 330 assertions, zero failures/errors/skips. Tests cover all table outcomes, guest/registered owners, isolation, missing/inactive/stale identities, absent films, conditional permission errors and retained transition identity.
- **AC2:** Rollback and explicit retry preserve the original persisted outcome.
  Check: caller rollback and injected create/update/destroy failure; no partial changes or lost source entry; retry succeeds after removing the failure.
  Result: Passed — operation tests cover caller rollback for creation, transition and removal, injected create/update/destroy failures and successful explicit retry. Persisted source entries survive failed transitions.
- **AC3:** Concurrent operations serialize with the outcomes above.
  Check: deterministic separate-connection tests for duplicate dismissal/removal, both orderings against watchlist addition, and both dismissal/watched orderings from ToWatch. Coordinate through database blocking evidence, not sleeps alone.
  Result: Passed — eight separate-connection race tests use PostgreSQL blocking evidence: duplicate dismissal/removal, both dismissal/watchlist orderings, both removal/watchlist orderings and both dismissal/watched orderings. Watched survives dismissal attempts; RecordWatched retains its existing rejection for NotInterested.
- **AC4:** Guest ownership and retention remain compatible with established Identity operations.
  Check: real confirmation and cleanup calls from Library tests, verifying retained relationship identity on claim, rejection at expiry, scoped dependent deletion and retained shared films.
  Result: Passed — real Identity confirmation retains dismissal ownership and relationship identity. Exact guest expiry rejects both operations; cleanup removes expired dependent entries, preserves the claimed owner and retains shared Film rows.
- **AC5:** Repository checks pass and the implementation stays within this scope.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/library_film_test.rb test/services/library`; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`; `RAILS_ENV=test bin/rails zeitwerk:check`; `git diff --check`. Inspect changes for other-domain, schema and UI additions.
  Result: Passed — full CI: 272 tests, 2,895 assertions, zero failures/errors/skips; style and dependency/security checks passed. Zeitwerk application eager loading passed with the existing mail-preview exclusion. git diff --check passed. Runtime/test changes are Library-only; no schema, UI or other-domain implementation changes.

## Implementation notes

Implemented MarkNotInterested and RemoveNotInterested using established fresh user/film lookup and user-before-entry locks. Models declare permission and the conditional shared dismissal error; the service creates or transitions the concrete destination. Removal resolves NotInterested and calls destroy! directly. Existing watched/watchlist operations are unchanged.

Added ten operation/retention tests, eight separate-connection concurrency tests and one model permission/error test. Ran both test commands under AC5, Zeitwerk and whitespace checks on 21 October 2026. The first focused run exposed two test-only naming mistakes; corrected them before the passing focused/full runs. Prior PR #23 merge documentation was preserved.

No scope deviations. Classification reads, UI and NotInterested-to-Watched remain deferred as approved.

Owner acceptance / merge: Pending.
