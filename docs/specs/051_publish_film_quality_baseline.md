# 051 — Publish the retained film-quality baseline through CI

Status: Merged  
Owner: Film knowledge

## Goal

Publish the current documentation, working vocabulary/examples and installed TypeSafe skill in a reviewable pull request, merging only after the PR's current commit passes CI. Owner explicitly requested PR and merge after CI on 29 October 2026. Prerequisites: implementation plan, current requirements/baseline, task template, cleanup task 050 and repository CI workflow read.

## Scope

- Review and commit the existing authorised documentation/skill/data changes on a `codex/` branch, retaining intentional obsolete-document deletions.
- Verify retained JSON identities/coverage, document links, whitespace and that no production code/schema or credentials are included. Preserve ignored Obsidian/environment state.
- Open and attach a PR with concrete scope, local validation and limitations. Inspect hosted CI for the exact PR head; merge only once required repository checks pass and the head is unchanged.
- Record the merge evidence in the local plan/handoff after actual merge. Preparation of the next task follows separately; no next-task implementation is included here.

## Scope restrictions

- No new model calls, prompt migration, quality/category implementation, workflow/scoring changes, deployment or unrelated cleanup. Task 043 remains Draft.
- Do not stage ignored files, raw scratch artifacts or credentials. Do not revert external workspace state. A failing CI does not authorise unrelated repairs or bypassing checks; investigate concrete failures and scope necessary fixes before changing them.
- User's explicit CI-conditional merge instruction supersedes the default prohibition on automatic merge for this task only. Do not submit a self-approval review or claim model accuracy/owner adjudication from CI.

## Acceptance criteria

- **AC1:** PR contains only the intended retained baseline, documentation cleanup and skill installation.  
  Check: staged diff review, JSON identity/coverage and document-link checks, no production diff, no ignored credentials/artifacts.  
  Result: Passed local review. Checkout matched fetched origin/main before branching. `python3 /tmp/glutton-050-check.py` verified exact 235-record meanings, reconstructed questions/policy, six source packets, all 1,410 probabilities and 318 matched reviews; 254 Markdown links/anchors, removal allowlist and whitespace passed. New retained JSON and skill lock parsed. `git diff --name-only -- app db test config lib` empty. Explicit staging excludes ignored secrets, Obsidian state and raw scratch.
- **AC2:** The exact PR head passes hosted repository CI before merge.  
  Check: inspect run/check status for the head SHA; retain run URL, final conclusion and merge response.  
  Result: Passed. [Hosted CI](https://github.com/adambelton/glutton/actions/runs/40834619291) completed successfully for exact PR head `7445d23078162c85a2209108e57965d25912f0c9`. Repository checks passed setup, Ruby style, Gem/importmap/Brakeman security checks and Rails tests: 534 runs, 5,665 assertions, zero failures/errors/skips. The head was re-read unchanged before `gh pr merge --squash --match-head-commit`; no bypass or self-approval review.
- **AC3:** Actual merge is verified and the working checkout is ready for a separately scoped handoff.  
  Check: fetch merged main, verify merge SHA/PR state; preserve unrelated local state; update plan with actual evidence after merge.  
  Result: Passed. [PR #45](https://github.com/adambelton/glutton/pull/45) reports merged on 29 October 2026 at `a03be7d43cb7c8f3755765c42af76bb2a8cdee4a`. Fetched origin/main, switched to main and fast-forwarded; local HEAD and remote main match the verified merge. Local post-merge plan/status updates and next-task draft are deliberately outside the merged PR. Ignored credentials/Obsidian state were not staged or reverted.

## Implementation notes

Published the reviewed 66-file documentation/skill/data bundle. The GitHub connector could read the repository but returned a 403 for PR creation, so creation and merge used the existing authenticated GitHub CLI. PR was attached to this chat. Hosted CI and exact-head merge were verified through the read connector; no model requests, runtime changes or deployment. Task 052 is the separate prepared design handoff, not started work.

Owner acceptance: PR and merge after passing CI explicitly authorised on 29 October 2026. Actual merge: [PR #45](https://github.com/adambelton/glutton/pull/45), `a03be7d43cb7c8f3755765c42af76bb2a8cdee4a`, 29 October 2026 after passing CI.
