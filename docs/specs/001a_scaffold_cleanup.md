# 001a — Scaffold cleanup and repository setup

Status: In progress  
Owner: Foundation

## Goal

Remove unused generated examples and publish the verified initial scaffold to the owner's public GitHub repository on `main`.

## Scope

- Remove inactive PWA templates/wiring, demo Stimulus controller, empty helper and commented inflections initializer.
- Remove unused system-test/signoff examples from local CI configuration.
- Preserve the current document layout and repair stale links.
- Verify the scaffold, inspect tracked files for secrets, create `adambelton/glutton` as public, commit and push `main`.

## Scope restrictions

- No domain features, dependency changes or removal of active framework/security/test infrastructure.
- Retain existing documents, local notes, error pages and icons currently referenced by the layout.
- Never publish master keys, environment files, logs or local notes. No force push or overwrite of an existing remote.
- The user's current request authorizes the initial commit and push, superseding task 001's earlier no-commit restriction for this repository-setup task. No PR or merge is needed.

## Acceptance criteria

- **AC1:** Unused examples and wiring are removed; active routes and Hotwire remain functional.  
  Check: Inspect references and run `bin/ci`.  
  Result: Passed — `bin/ci` passed: 22 Ruby files linted, gem/importmap audits clear, Brakeman zero warnings/errors, and 3 tests/12 assertions with no failures. Inactive PWA/demo/helper/inflections files and example wiring removed.
- **AC2:** Local document links resolve and private local files are excluded from Git.  
  Check: Validate relative Markdown links, inspect staged files and run `git diff --cached --check`.  
  Result: Passed — all relative Markdown links resolve; obsolete document paths and removed-code references are absent. `git diff --cached --check` passed. `git check-ignore` confirms the master key and local notes are excluded; staged-file credential-pattern checks passed.
- **AC3:** The public owner repository has `main` matching the local commit.  
  Check: Verify repository visibility, upstream and remote commit hash after push.  
  Result: Not run.

## Implementation notes

Cleanup implemented and verified. GitHub account verified as `adambelton`; no existing `adambelton/glutton` repository was found. User explicitly selected public visibility.

Owner acceptance / merge: Pending; repository creation/push explicitly authorised.
