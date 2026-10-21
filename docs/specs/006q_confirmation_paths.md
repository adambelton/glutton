# 006q — Make confirmation paths explicit

Status: Merged  
Owner: Identity / registration

## Goal

Make CompleteRegistration readable as two explicit paths: a browser with a current identity, and an anonymous browser.

## Scope

- Put the current-user condition at the start of the transaction, with user lookup, access checks and attachment visibly belonging to the appropriate branch.
- Keep token revalidation/locking and the final account transition shared within the same coordinator.
- Update the existing review PR under the owner's continuing review authorization.

## Scope restrictions

- Identity only; no contract, failure, expiry, cookie, schema or other-domain changes.
- Preserve user-before-pending lock order, fresh token/ownership checks and atomic rollback. No new coordinator, policy abstraction or nested workflow.
- No merge or self-acceptance.

## Acceptance criteria

- **AC1:** The two paths are explicit, and all existing confirmation outcomes and concurrency protections remain intact.  
  Check: inspect the branch structure; run existing confirmation/browser/retention tests and full CI.  
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 232 tests / 2,633 assertions, zero failures/errors/skips (seed 5319). Includes existing browser confirmation, direct/guest completion, concurrent claims, attachment rollback and Library retention compatibility. RuboCop: 127 files clean; gem/importmap audits clean; Brakeman: zero errors/warnings.
- **AC2:** Scope, evidence and review status are recorded.  
  Check: inspect the diff and run git diff --check; update the plan and PR branch.  
  Result: Passed — inspected the Identity-only implementation diff and ran `git diff --check` successfully. Plan updated; publication to the existing open PR #22 is authorized. Acceptance and merge remain pending.

## Implementation notes

The transaction now starts with an explicit current_user_id branch. That path resolves current_user, verifies confirmation access and attaches an owned request; the anonymous path resolves only the guest already linked to the request. A private lock_registration helper preserves fresh locked token/ownership validation in both paths. The common account transition remains below the conditional. No new classes or behaviour changes; existing outcome/concurrency tests cover the refactor without tests of private method structure.

Owner acceptance / merge: Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge.
