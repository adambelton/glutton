# 001l — Patch the CSS tokenizer dependency

Status: Ready for review  
Owner: Foundation / dependency maintenance

## Goal

Resolve the dependency-audit failure blocking PR #32: crass 1.0.7 is affected by GHSA-pq4g-8rxf-4g29 (incorrect tokenization of bad URLs enables CSS sanitizer bypass). Hosted CI identifies 1.0.8 as the patched minimum. This is necessary remediation within the owner's instruction to merge after CI.

## Scope

- Conservatively update the transitive crass dependency to its patched release, without unrelated dependency updates.
- Refresh local advisory data and run the repository checks before requesting hosted verification.

## Scope restrictions

- Foundation dependency maintenance only. No product behaviour, domain contracts, sanitizer configuration, audit ignores, CI weakening or deployment.

## Acceptance criteria

- **AC1:** The lockfile uses patched crass and no unrelated dependency changes.
  Check: inspect lockfile diff and run the dependency audit with refreshed advisory data.
  Result: Passed — `bundle update crass --conservative` changed only crass 1.0.7 to 1.0.8. `bin/bundler-audit update` refreshed advisory data to 03da937a9e171e3fedebde6620e203559b7a60c0; the refreshed audit passed during full CI.
- **AC2:** Repository checks pass with the patch.
  Check: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `git diff --check`, then hosted CI on the final PR head.
  Result: Passed locally — `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 392 tests / 4,190 assertions, all style/security checks passed. `git diff --check` passed. Hosted verification passed on the updated head; see merge evidence below.

## Implementation notes

Initial hosted run for PR #32 passed 392 tests / 4,190 assertions and all other checks, but its fresh advisory database detected this dependency issue. Earlier local security checks used older advisory data.

Owner acceptance / merge: Authorized and merged; see evidence below.

## Merge evidence

Owner authorized merge after CI. [PR #32](https://github.com/adambelton/glutton/pull/32) merged on 26 October 2026 at 08:57:13 UTC (GMT), squash commit `f2d8abbfbd2d3f2a335ba49c432904c804310b5a`. Hosted Repository checks passed on exact head `5340552cc874248a58bb84a5a0e2c97b678753bb` at 08:56:55 UTC. Local main was fast-forwarded. Final local CI passed 392 tests / 4,190 assertions with clean style/security checks after refreshing advisory data and patching crass.
