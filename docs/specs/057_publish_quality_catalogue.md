# 057 — Publish the direct quality catalogue and cleaned migrations

Status: In progress  
Owner: Foundation (supporting delivery)

## Goal

Publish the authorised category/catalogue, analysis retirement, migration consolidation, documentation and retained selection experiment changes in a PR. Merge only after CI passes for the exact current PR head, then prepare the next bounded task. Owner explicitly requested PR, merge after CI and next-task preparation on 29 October 2026.

## Scope

- Review and commit the current authorised work from tasks 043 and 052–056, including earlier post-merge documentation status updates. Preserve source baseline, ignored environment/Obsidian/raw-run files and unrelated workspace state.
- Include persisted Quality/QualityCategory/Film/FilmQuality roles, initial caps/weights, retired analysis runtime, clean creation migrations, final-contract tests, current scope documentation and public experiment evidence. Retain historical spec limitations/supersession notes rather than rewriting earlier test results.
- Open and attach the PR with concrete scope and verification. Inspect CI and head identity, merge only on successful required Repository checks for that same head. Record actual merge evidence afterwards and fast-forward local main.
- Prepare a Draft spec for deterministic source-support selection using the 60% threshold and per-category maxima. Preparation is not implementation or authority for further provider calls.

## Scope restrictions

- No new product features, paid calls, deployments, live prompt changes or arbitrary cleanup. Necessary concrete CI failures may be fixed under a documented scope amendment; do not bypass checks.
- Do not commit .env, ignored database/scratch artifacts, private local logs or credentials. No self-approval review. User's explicit conditional merge instruction overrides the default no-automatic-merge rule for this delivery only.

## Acceptance criteria

- **AC1:** The staged bundle contains only reviewed authorised changes.  
  Check: staged diff/filenames, no ignored secrets, canonical baseline preservation, offline experiment replay and document/whitespace checks; retain the existing full local test/security evidence without pretending it is hosted CI.  
  Result: Passed — reviewed staged allowlist of 75 code/config/migration/docs/script/test paths; no ignored environment, Obsidian, cache or raw-run files staged, no matching credential literals. Canonical five-file baseline and seven prior status diffs preserved; 216 local Markdown destinations/anchors and whitespace passed. Non-catalogue schema comparison preserved 17 table contracts and 11 foreign keys. Offline experiment replay reproduced the retained 12-call evidence (US$0.012344052 historical spend); no new calls made. Existing full local verification is 483 tests / 5,353 assertions with clean style/security/eager loading.
- **AC2:** The current PR head passes required CI before merging.  
  Check: CI run/check URL, conclusion, exact head SHA re-read, merge with matching-head guard.  
  Result: Not run.
- **AC3:** Actual merge and next-task handoff are verifiable.  
  Check: merged PR state/commit, fetched origin/main matching local main, updated local evidence and bounded next Draft spec. No next-task implementation.  
  Result: Not run.

## Implementation notes

Existing local verification: 483 tests / 5,353 assertions, Ruby style/security/eager loading clean. Both disposable databases rebuilt from all 11 creation migrations; development seeded with nine category defaults. Prior migration errors were corrected and recorded in tasks 055/056. All result statuses below must reflect checks actually run for this delivery.

Owner acceptance / merge: CI-conditional merge authorised; actual merge pending.
