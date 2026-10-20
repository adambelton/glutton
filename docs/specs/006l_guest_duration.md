# 006l — Guest lifetime policy constant

Status: Ready for review  
Owner: Identity / guest lifecycle

## Goal

The guest lifetime can change in one model constant without rewriting guest-boundary tests. Owner explicitly requested the constant and test reuse during PR #21 review.

## Scope

- Define UserGuest::EXPIRY_DURATION (currently 24.hours), used by active?, active/expired scopes and Identity lifecycle tests. Replace guest-relative fixture ages/travel with the constant or relative offsets. Keep registration/token lifetimes separate and create near-deadline requests near that deadline so longer guest durations do not accidentally expire registration first.
- Record actual verification here; preserve exact-boundary and daylight-saving elapsed-time coverage.

## Scope restrictions

- No change to the configured lifetime, registration deadline, token lifetime, user-facing copy, schema or non-test data. No instance expiry-time accessor or generic configuration framework. Runtime consumers still ask active?.
- No other domain runtime changes, deployment or merge. Updating PR #21 for review remains authorized.

## Acceptance criteria

- **AC1:** Guest policy and tests use one duration without confusing independent registration/token deadlines.
  Check: focused lifecycle/consumer tests and search remaining numeric durations; vary the guest constant temporarily to verify shorter/longer lifetimes, then restore the configured value.
  Result: Passed — UserGuest::EXPIRY_DURATION is the sole guest lifetime literal in runtime code, used by active? and both query scopes. Guest boundary/age fixtures use that policy; remaining 24-hour values concern independent registration expiry. Temporarily changed the constant to 12.hours and 48.hours, ran `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` for each, and restored 24.hours in a finally block. Both full suites passed: 225 tests/2,579 assertions, zero failures/errors/skips. To reproduce, change only the constant, run the command, then restore it; no token or registration duration changes.
- **AC2:** Existing security, concurrency and repository checks pass.
  Check: full CI and git diff --check; record actual commands/results.
  Result: Passed — default restored-policy full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 225 tests/2,579 assertions, zero failures/errors/skips; RuboCop 125 files clean; dependency audits clean; Brakeman zero warnings/errors. Focused Identity/lifecycle/browser/task run passed 141 tests/1,252 assertions before the final independent-deadline fixture simplification; final Library suite passed 15 tests/79 assertions. `git diff --check` passed.

## Implementation notes

Added the frozen model-owned duration constant and updated expiry-sensitive tests. Near-deadline registration setup now creates fresh pending requests near guest expiry so tests work for shorter and longer guest lifetimes; independent pending/token deadlines retain their own values. Library changes are tests only. Daylight-saving verification uses elapsed seconds and the configured duration rather than a fixed local-hour expectation. Default lifetime is unchanged, no expiry timestamp accessor or runtime consumer coupling was added, and no non-test data changed. The separate discussion about User#resume_session ownership remains unresolved by this duration-only change.

Owner acceptance / merge: Pending.
