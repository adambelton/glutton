# 001 — Initial Rails scaffold

Status: Ready for review  
Owner: Foundation

## Goal

A minimal Glutton Rails application that can be set up and booted against local PostgreSQL, with reproducible verification. Implementation is authorised for this task.

Before generating files, inspect available tools and select compatible supported Ruby/Rails versions. Record exact versions and generator options in the implementation notes before generation.

## Scope

- Rails monolith, local PostgreSQL, server-rendered views and Hotwire.
- Distinct Glutton development/test databases.
- A simple Glutton home page and the conventional Rails health endpoint.
- Ruby version pin, dependency lockfile and conventional Rails defaults.
- README prerequisites and exact setup, check, start and stop instructions.
- Focused smoke tests and applicable generated checks.

## Scope restrictions

- Remain within Foundation; do not establish product-domain schemas, interfaces or empty namespaces.

- No product models, migrations, authentication or Resend implementation; retain only necessary generated framework defaults.
- No external integrations, provider calls or API keys, including TMDB, JEV and Claude.
- Do not configure background-job infrastructure, deployment, containers or production services.
- Use the generated test framework and minimal CSS. Do not add a UI framework, polished product UI, speculative domain abstractions, stress tests or browser automation suite.
- Move working briefs, plan and specs into `docs/` and update references; retain `AGENTS.md` at the root for agent discovery. Preserve document content and `.obsidian/`. Keep secrets out of tracked files.
- Do not reset existing non-empty databases. Resolve unavailable toolchain prerequisites separately rather than upgrading system tools or installing infrastructure system-wide without agreement.
- No commits, PRs or merges. Git initialization is allowed if needed for a reviewable diff; record it without assuming a remote exists.

## Acceptance criteria

- **AC1:** Version pins and dependency lockfile match the working Ruby/Rails setup; exact versions and generator options are recorded.  
  Check: Run toolchain version commands and inspect the version pin and lockfile.  
  Result: Passed — `ruby -v`: 3.4.11; `rails -v` and `bundle exec rails -v`: 8.1.4; `bundle -v`: 2.6.9. `.ruby-version` and `Gemfile.lock` match. `bundle lock --local` resolved installed gems and `bundle check` passed.

- **AC2:** Documented setup prepares separate development/test PostgreSQL databases and can be repeated without deleting existing data.  
  Check: Follow README setup, confirm database names, then repeat setup without a reset.  
  Result: Passed — `bin/setup --skip-server` created `glutton_development` and `glutton_test`; repeated standalone setup and setup inside `bin/ci` passed without a reset. Setup invokes `db:prepare` for both environments; the generated `--reset` branch was removed.

- **AC3:** The app connects to PostgreSQL; `/` renders a Glutton page with HTTP 200, and the health endpoint succeeds.  
  Check: Explicitly verify database connectivity; run request smoke tests, boot a local server and request both routes. Stop the server afterward.  
  Result: Passed — `bin/rails test`: 3 tests, 12 assertions, no failures/errors/skips. Test SQL returned PostgreSQL, `glutton_test` and `SELECT 1 = 1`; development runner returned `PostgreSQL: glutton_development`. Booted `bin/rails server -b 127.0.0.1 -p 3107`; Python urllib requests returned HTTP 200 for `/`, `/up` and all eight referenced CSS/JS assets. Sent Ctrl-C and observed clean Puma exit.

- **AC4:** Focused route tests and applicable generated test/lint/security checks pass.  
  Check: Run relevant generated checks; record exact commands and distinguish environmental/advisory-fetch failures from application failures. Required checks that cannot run leave the task incomplete.  
  Result: Passed — `bin/ci` completed setup, RuboCop (24 files, no offenses), gem audit (no vulnerabilities), importmap audit (no vulnerable packages), Brakeman 8.0.6 (zero warnings/errors), and Rails tests (3 tests/12 assertions). `bin/rails zeitwerk:check` passed. `bin/bundler-audit check --update` fetched advisory commit `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485` and found no vulnerabilities. Initial sandbox cache/network failures were resolved by rerunning with local-service/cache access. The generated Brakeman latest-version requirement failed because 8.1.0 exists; the wrapper now runs the locked scanner, with `--ensure-latest` opt-in. No scanner or global toolchain upgrade was performed.

- **AC5:** README allows the owner to reproduce setup, verification and local boot/shutdown without external API keys.  
  Check: Follow the documented commands and record any missing prerequisite or correction. This may reuse evidence from AC2–AC4 rather than repeat those runs.  
  Result: Passed — README records exact prerequisites, repeatable setup, check commands, foreground start/stop, connection overrides and document links. Setup/check commands were executed as above. `bin/dev` directly executes the Rails server used in the HTTP check. No external API keys were needed.

- **AC6:** File/diff review confirms the scope restrictions are respected, with no secrets or overwritten pre-existing project documents.  
  Check: Inspect resulting files/diff and tracked configuration.  
  Result: Passed — inspected generated files and review diff; only framework base model, home controller/view and scaffold tests were added. No product migrations, integrations, job backend, deployment or containers. Working documents moved to `docs/`; root instructions and relative links updated. `.obsidian/` preserved and ignored; `config/master.key` is ignored, encrypted Rails credentials remain conventional generated defaults. Git initialized without remote, commits or merge.

Verification performed on 18 October 2026. Owner acceptance remains pending.

## Implementation notes

Selected installed Ruby 3.4.11, Rails 8.1.4, Bundler 2.6.9 and PostgreSQL 17.9. No global toolchain upgrades. Generator command (recorded before execution):

```sh
rails _8.1.4_ new . --name=glutton --database=postgresql --no-rc --skip-bundle --skip-docker --skip-kamal --skip-thruster --skip-solid --skip-active-job --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-jbuilder --skip-system-test --skip-ci
```

Use default Minitest, Propshaft/importmap/Hotwire, and generated lint/security tools. Rails automatically activates `--skip-action-mailer` with `--skip-active-job`; enable both in a later scoped task when mail delivery is introduced. Unused frameworks and deployment/job setup were skipped. Working documents are in `docs/`; root `AGENTS.md` remains discoverable.

Implemented the Rails home/health scaffold and default Hotwire install tasks. PostgreSQL defaults to localhost, with separate named development/test databases. `bin/setup` prepares both databases without a reset option. Local CI omits the generated destructive seed-replant step because this task has no seed data. Brakeman uses the locked scanner by default for reproducible checks; online dependency audits remain enabled.

Version-family support checked against [Rails support announcement](https://rubyonrails.org/2025/10/29/new-rails-releases-and-end-of-support-announcement) and [Ruby maintenance branches](https://www.ruby-lang.org/en/downloads/branches/). No application domain structures were introduced. Authentication will need to enable Action Mailer/Active Job in its own scoped task.

Final review: `git diff --check` passed; Markdown hard-break whitespace is explicitly allowed in `.gitattributes`. Local document links resolve. Changes are unstaged (intent-to-add only), with no commits or remote.

Owner acceptance / merge: Pending; no merge performed.
