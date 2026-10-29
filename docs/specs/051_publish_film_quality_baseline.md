# 051 — Publish the retained film-quality baseline through CI

Status: In progress  
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
  Result: Not run.
- **AC3:** Actual merge is verified and the working checkout is ready for a separately scoped handoff.  
  Check: fetch merged main, verify merge SHA/PR state; preserve unrelated local state; update plan with actual evidence after merge.  
  Result: Not run.

## Implementation notes

Not implemented.

Owner acceptance: PR and merge after passing CI explicitly authorised on 29 October 2026. Actual merge: Pending.
