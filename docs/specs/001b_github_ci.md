# 001b — GitHub continuous integration

Status: In progress  
Owner: Foundation

## Goal

Run the existing repository checks on GitHub pull requests and pushes to main, using the checked-in Ruby version and an isolated PostgreSQL 17 service. Depends on task 001; no product-domain changes or contracts.

Relevant architecture: [Rails and PostgreSQL setup](../architecture_brief.md), sections 3 and 11.

## Scope

- Add one GitHub Actions workflow invoking `bin/ci` on pull requests and main pushes, with read-only repository permission and a bounded runtime.
- Install Ruby from `.ruby-version` and cache Bundler dependencies. Supply PostgreSQL 17 on localhost with health checks and disposable service-only credentials, compatible with existing database configuration.
- Document local/hosted entry points. Publish a separate review PR and inspect its actual hosted check result.

## Scope restrictions

- Foundation only: no changes to product domains, application behaviour, dependency versions, schema or existing check semantics.
- No deployments, production credentials, paid services, branch-protection changes or automatic merge. No pull_request_target trigger.
- Reuse `bin/ci`; do not duplicate its commands or add a version matrix, artifact uploads or unrelated tooling.
- Preserve unrelated local IDE/ignore changes. The user request authorizes CI implementation and its review PR, not merging it.

## Acceptance criteria

- **AC1:** Workflow runs on pull requests and main pushes with Ruby from the repository, PostgreSQL 17 and `bin/ci`.  
  Check: Parse YAML and review triggers, service, runtime, permissions and command against official action/service documentation.  
  Result: Not run.
- **AC2:** Existing checks pass with no changes to their semantics.  
  Check: Run `bin/ci` locally and `git diff --check` for scoped files.  
  Result: Not run.
- **AC3:** The CI PR has a successful hosted check.  
  Check: Push the branch, create a PR and inspect `gh run view` plus logs for failures; record the run URL and actual result.  
  Result: Not run.

## Implementation notes

Not implemented.

Owner acceptance / merge: Pending.
