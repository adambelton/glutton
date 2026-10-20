# 006n — Explicit anonymous registration access

Status: Ready for review  
Owner: Identity / registration

## Goal

Make anonymous pending-registration access explicit while available_to? trusts an actual user role.

## Scope

- Add registration-owned unattached?; caller selects anonymous or user availability after checking activity.
- Remove nullable-user handling and the duplicate-email availability query. Creation, delivery and completion retain their existing duplicate-email enforcement.
- Verify anonymous access, ownership, eligibility and expired-request rejection.

## Scope restrictions

- Identity only; no schema, expiry policy, delivery, transition or uniqueness enforcement changes. Update existing PR for review; no merge.

## Acceptance criteria

- **AC1:** Anonymous browsers see only active unattached requests; users need registration permission and compatible ownership.
  Check: focused model/controller/integration tests.
  Result: Passed in full CI, including new model permission/ownership/expiry checks and controller anonymous-unattached versus anonymous-linked access checks. Initial focused run exposed fractional-second test setup; freezing time before creation fixed the fixture.
- **AC2:** Repository checks pass.
  Check: full CI and git diff --check.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 227 tests, 2,596 assertions, zero failures/errors/skips; style and security checks passed. `git diff --check` passed.

## Implementation notes

The caller checks activity and explicitly chooses user availability or anonymous unattached access. available_to? trusts the user role. Existing duplicate-email validation, delivery check and completion/database enforcement are unchanged.

Owner acceptance / merge: Pending.
