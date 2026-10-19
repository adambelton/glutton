# 004a — Group user subclass models

Status: Merged  
Owner: Identity / model organisation

## Goal

Keep User and its subclasses together in the user model-family directory without changing existing identity or persistence behaviour. Depends on merged task 004. No domain contracts change.

Relevant architecture: [system shape and Identity](../architecture_brief.md), sections 3 and 11.

## Scope

- Place User, GuestUser, RegisteredUser and DeletedUser together in `app/models/user/`, including `user.rb` itself.
- Configure Zeitwerk to collapse that organisational directory, preserving the existing top-level class names and stored STI type strings.
- Document the layout convention: a domain model with no domain superclass gets its own named folder containing its model file; subclasses join the folder named for their root domain superclass. ApplicationRecord remains shared Rails infrastructure, not a domain model family. Create no empty folders.

## Scope restrictions

- Identity organisation and the necessary narrow autoload configuration only. No other domains, behaviour, public API, class namespace, table name, schema or STI data changes.
- Do not apply a blanket collapse to all model directories; genuine domain namespaces must keep their meaning.
- No refactoring validation, authentication, session behaviour or task 005 implementation. Preserve pending draft/merge-record documentation and unrelated local files.
- The owner authorized committing, pushing a branch and opening a GitHub PR for review. No deployment or merge is authorized.

## Acceptance criteria

- **AC1:** User and all its subclasses reside in `app/models/user/`, retaining their names, superclass and stored type values.  
  Check: Inspect moved files; run `bin/rails zeitwerk:check` and existing model/session tests via `bin/ci`.  
  Result: Passed — moved all four unchanged model files into `app/models/user/`. `bin/rails zeitwerk:check` reported “All is good!”; existing model/session tests passed through eager-loaded CI, retaining original STI names.
- **AC2:** Eager loading and normal repository checks pass without a schema change.  
  Check: `CI=true bin/ci`, scoped `git diff --check`, and diff inspection.  
  Result: Passed — `CI=true bin/ci`: 34 files linted, audits clear, Brakeman zero warnings/errors, 34 tests/206 assertions with no failures/errors. `git diff --check -- app config docs` passed. No schema or class-name changes.

## Implementation notes

Moved User, GuestUser, RegisteredUser and DeletedUser files beneath `app/models/user/`, including `app/models/user/user.rb`. Added a narrowly scoped Zeitwerk collapse in `config/initializers/autoloading.rb` and documented the layout convention in the architecture brief. No behaviour changes or scope deviations. Task 005 remains draft; the owner subsequently authorized a GitHub PR; owner acceptance and merge remain pending.

Owner acceptance / merge: Accepted by owner and merged via [PR #5](https://github.com/adambelton/glutton/pull/5) on 19 October 2026. Squash commit: `db7722b94fb9c2f31583b141492222e7cbe5f851`.
