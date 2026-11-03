# 064 — Publish the initial quality vocabulary seed

Status: In progress  
Owner: Foundation (supporting delivery)

## Goal

Publish the reviewed seed-first documentation and initial quality vocabulary seed, merge after CI passes for the exact PR head, and prepare the next bounded Film knowledge task. Owner explicitly requested PR, merge after CI and next-task preparation on 3 November 2026.

## Scope

- Review and commit the authorised tasks 059–063 and existing post-merge handoff documentation from 043/052–057; retain deferred task 058 as a draft. Preserve unrelated and ignored files.
- Publish the final implementation: one-time transactional seed from plain YAML lists, 235 definitions/exclusions, category defaults, names/IDs without separate quality/category keys, original catalogue migration updates and relevant tests/documentation. Historical task evidence remains labelled as superseded where necessary.
- Create and attach a PR with final scope and actual verification. Confirm required hosted Repository checks succeed for the exact current head before a matching-head squash merge; fast-forward local main afterwards.
- Record actual merge evidence and prepare a Draft next Film knowledge spec in the approved seed-first order. Preparation only; no next-task implementation.

## Scope restrictions

CI repair amendment, 3 November: hosted run 41610156940 passed all 487 tests but failed the fresh gem audit on Loofah 2.25.2, Nokogiri 1.19.4, Rack 3.2.7 and rails-html-sanitizer 1.7.1. Scope permits only conservative patch updates of these four gems in Gemfile.lock and changing the gem-audit CI command to refresh advisories before checking, so local checks do not reuse stale security data. No advisory ignores or check bypasses. Re-run full CI and require successful hosted checks on the new exact head. Foundation owns this supporting delivery repair.

- No provider calls, paid experiments, deployment, production upgrades, new film enrichment/assignment runtime, unrelated fixes or changes to research baseline/ignored environment/Obsidian files.
- No self-approval review or CI bypass. User explicitly authorised conditional merge for this delivery; no further confirmation required once CI passes.
- Scope any concrete CI repair before implementation; do not bundle speculative cleanup. Do not stage secrets, temporary reconciliation scripts, logs or scratch data.

## Acceptance criteria

- **AC1:** The PR bundle contains only reviewed authorised changes and preserves baseline data.  
  Check: staged allowlist/diff, YAML-to-baseline comparison, local links/whitespace, no ignored or secret artifacts. Latest local CI evidence is recorded separately from hosted checks.  
  Result: Passed — `python3 /private/tmp/glutton-064-check.py` reviewed the explicit 33-path allowlist, 217 local Markdown destinations/anchors, whitespace and credential-pattern scan. Retained research/Obsidian diffs are empty. Latest code/data checks: exact ordered YAML comparison preserves all 235 names/definitions/exclusions/category assignments; both files are plain lists. Local full CI passed 487 tests / 6,109 assertions with clean style/security/eager loading. That is local evidence, not hosted CI.
- **AC2:** Hosted Repository checks pass for the unchanged PR head before merge.  
  Check: PR head readback, required check conclusion/run URL, matching-head merge guard; no bypass.  
  Result: Not run.
- **AC3:** Actual merge and next-task handoff are verifiable.  
  Check: merged state/commit, local main matches fetched origin/main, updated evidence and bounded Draft spec. No next-task implementation/provider calls.  
  Result: Not run.

## Implementation notes

Latest local product checks passed: 487 tests / 6,109 assertions, clean style/security/eager loading. Original migration replay and table audits passed; development retains 235 qualities/nine categories. Owner authorised original migration edits because no production data exists. Final seed is a one-time empty-catalogue operation, not idempotent.

Owner acceptance / merge: Current implementation accepted and PR/merge after CI authorised on 3 November 2026; actual merge pending.

Failure evidence: [initial hosted CI](https://github.com/adambelton/glutton/actions/runs/41610156940) passed tests/style/Importmap/Brakeman, but gem audit failed. Upstream patch advisories: [Loofah](https://github.com/flavorjones/loofah/security/advisories/GHSA-h6v6-rg66-fqj4), [Nokogiri](https://github.com/sparklemotion/nokogiri/security/advisories/GHSA-3w22-6jfg-527w), [Rack](https://github.com/rack/rack/security/advisories/GHSA-5v64-555j-wjxm), [rails-html-sanitizer](https://github.com/rails/rails-html-sanitizer/security/advisories/GHSA-h7wh-q2qr-458c). The original local clean-audit evidence used an older advisory checkout and is retained as historical evidence, not proof against the new advisories.

CI repair verification: `bundle update --patch --conservative loofah nokogiri rack rails-html-sanitizer` changed only those four gems: Loofah 2.25.3, Nokogiri 1.19.7 (Darwin/Linux), Rack 3.2.8 and rails-html-sanitizer 1.7.2. `PARALLEL_WORKERS=1 bin/ci` then passed 487 tests / 6,109 assertions with no style/security issues; gem audit refreshed ruby-advisory-db to `a58f1d0a3343e85cef597970f2c5458dcfbaf909` and found no vulnerabilities. Eager loading and whitespace passed. Hosted retry is still required before merge.
