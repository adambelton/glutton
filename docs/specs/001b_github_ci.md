# 001b — GitHub continuous integration

Status: Merged  
Owner: Foundation

## Goal

Run the existing repository checks on GitHub pull requests and pushes to main, using the checked-in Ruby version and an isolated PostgreSQL 17 service. Depends on task 001; no product-domain changes or contracts.

Relevant architecture: [Rails and PostgreSQL setup](../architecture_brief.md), sections 3 and 11.

## Scope

- Add one GitHub Actions workflow invoking `bin/ci` on pull requests and main pushes, with read-only repository permission and a bounded runtime.
- Install Ruby from `.ruby-version` and cache Bundler dependencies. Supply PostgreSQL 17 on localhost with health checks and disposable service-only credentials, compatible with existing database configuration.
- Add Linux platform resolution to the lockfile without upgrading existing dependency versions, as required by the hosted runner.
- Document local/hosted entry points. Publish a separate review PR and inspect its actual hosted check result.

## Scope restrictions

- Foundation only: no changes to product domains, application behaviour, dependency versions, schema or existing check semantics.
- No deployments, production credentials, paid services, branch-protection changes or automatic merge. No pull_request_target trigger.
- Reuse `bin/ci`; do not duplicate its commands or add a version matrix, artifact uploads or unrelated tooling.
- Preserve unrelated local IDE/ignore changes. The user request authorizes CI implementation and its review PR, not merging it.

## Acceptance criteria

- **AC1:** Workflow runs on pull requests and main pushes with Ruby from the repository, PostgreSQL 17 and `bin/ci`.  
  Check: Parse YAML and review triggers, service, runtime, permissions and command against official action/service documentation.  
  Result: Passed — `ruby -r yaml -e 'w = YAML.load_file(".github/workflows/ci.yml"); abort unless w.fetch("jobs").fetch("checks").fetch("steps").last.fetch("run") == "bin/ci"'` parses the workflow and verifies its entry point. Reviewed triggers, health checks, `.ruby-version` lookup, read-only permissions and timeout against official ruby/setup-ruby and GitHub service documentation.
- **AC2:** Existing checks pass with no changes to their semantics.  
  Check: Run `bin/ci` locally and `git diff --check` for scoped files.  
  Result: Passed — local `bin/ci`: 27 Ruby files linted, audits clear, Brakeman zero warnings/errors, 11 tests/37 assertions with no failures/errors. `git diff --check -- .github docs README.md` passed; unrelated local `.gitignore` edit excluded.
- **AC3:** The CI PR has a successful hosted check.  
  Check: Push the branch, create a PR and inspect `gh run view` plus logs for failures; record the run URL and actual result.  
  Result: Passed — [hosted run 39268328567](https://github.com/adambelton/glutton/actions/runs/39268328567) succeeded on commit `92de5e2` in 1m12s, including dependency installation and `bin/ci`. Verified with `gh run watch 39268328567 --repo adambelton/glutton --exit-status --interval 10`.

## Implementation notes

Implemented `.github/workflows/ci.yml` with one Ubuntu 24.04 job, Ruby from `.ruby-version`, Bundler cache, PostgreSQL 17 health checks, read-only repository permissions and a 15-minute timeout. Uses existing `bin/ci` unchanged. README documents the hosted/local entry point.

The first hosted run failed because the lockfile supported only arm64-darwin. Ran `bundle lock --add-platform x86_64-linux`; the diff adds Linux variants of the existing nokogiri/pg versions and the Linux platform, without version upgrades. Re-ran local CI successfully and verified the successful hosted run above. Scope was updated before the lockfile change. No domain code, deployment or branch protection changed.

Review PR: [#3](https://github.com/adambelton/glutton/pull/3). Hosted evidence is for the implementation commit; subsequent documentation-only evidence updates may trigger another run.

Owner acceptance / merge: Accepted by owner and merged via [PR #3](https://github.com/adambelton/glutton/pull/3) on 19 October 2026. Squash commit: `093e6954a5a99c19bdcedd4d13c0074fe06a59df`.
