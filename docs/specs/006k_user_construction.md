# 006k — User root construction

Status: Merged  
Owner: Identity / model construction

## Goal

Direct User construction fails, while subtype creation and loading existing STI rows remain supported. Depends on merged 010/001e and the agreed conventions in AGENTS.md. Owner explicitly authorized fixing the remaining convention issues.

## Scope

- Use an explicit root initialization guard without subclass enumeration, remove redundant model type-presence validation and retain database NOT NULL/credential invariants. Adjust explicit legacy base-row fixtures through direct storage setup, retaining historical migration coverage. Test root construction, subtype behaviour and loading a legacy base row.
- Record changes and reproducible verification here; no separate audit report.

## Scope restrictions

- No data migration, non-test data access, lifecycle policy rewrite or other domain changes. Existing persisted base rows are not deleted or rewritten.
- No generic role framework, speculative module, sibling-model transition logic, asynchronous domain integration, deployment or merge. The owner subsequently authorized publishing these fixes in a PR for online review.

## Acceptance criteria

- **AC1:** The scoped behaviour obeys role trust, model-owned actions/permissions and service-owned transitions without changing established outcomes.
  Check: inspect scoped diff and run relevant model/service/HTTP/concurrency tests, including meaningful failure cases.
  Result: Passed — Final combined Identity/Library checks passed 183 tests/1,571 assertions, including root new/create rejection, actual subtype persistence, legacy base-row loading, historical two-way STI migration and NOT NULL/credential constraints.
- **AC2:** Verification is outcome-focused and required repository checks pass.
  Check: focused tests, full CI after executable changes, eager loading and git diff --check. Record commands/results; do not imply unrun checks passed.
  Result: Passed — Full repository verification: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 219 tests/2,552 assertions, zero failures/errors/skips; RuboCop 122 files clean; gem/importmap audits clean; Brakeman zero warnings/errors. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

Direct User construction raises NotImplementedError; no permitted-subtype list or Rails abstract_class flag is introduced. Removed redundant model type-presence validation; database type NOT NULL and credential checks remain. Legacy-row test setup inserts historical base rows directly to verify loading and migration compatibility. Existing base rows are neither queried outside tests nor rewritten. No schema migration or non-test data change.

All verification used isolated test data. Owner authorized creating a PR for online review after local verification; acceptance and merge remain pending. The owner requested fixes directly; there is no separate audit-results document.

Owner acceptance / merge: Accepted by owner and merged in [PR #21](https://github.com/adambelton/glutton/pull/21) on 20 October 2026; verified merge commit `0fa54269df0140451ab19ac5b665fb64d6cc3c50`.
