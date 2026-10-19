# 005b — Simplify model file layout

Status: Ready for review  
Owner: Identity / model organisation

## Goal

Keep standalone/root models in Rails' default model location and group only subclasses beneath their superclass name. Depends on tasks 004a and 005. No domain contracts change.

Relevant architecture: [system shape](../architecture_brief.md), section 3. This supersedes task 004a's root-inside-family-folder layout at the owner's request.

## Scope

- Move User to `app/models/user.rb` and Session to `app/models/session.rb`; retain user subclasses in `app/models/user/`.
- Keep only the user-directory Zeitwerk collapse, preserving all constants and STI values. Remove the empty session directory.
- Update the architecture convention and implementation plan.

## Scope restrictions

- Identity file organisation and its autoload configuration only; no changes to model behaviour, schema, namespaces, dependencies or other domains.
- No blanket directory collapse, future empty directories or task 005a implementation. Preserve the pending sign-in spec and merge-record documentation.
- The owner authorized committing, publishing a PR and merging this layout change before starting task 005a. No deployment is authorized.

## Acceptance criteria

- **AC1:** Root/standalone models use default paths; user subclasses remain grouped with unchanged names and STI values.  
  Check: Inspect moved files and run `bin/rails zeitwerk:check`.  
  Result: Passed — User and Session moved unchanged to default root paths; user subclasses remain grouped. `bin/rails zeitwerk:check` reported “All is good!”. Only the user-directory collapse remains.
- **AC2:** Eager-loaded CI and scoped whitespace checks pass without behaviour/schema changes.  
  Check: `CI=true bin/ci`, `git diff --check -- app config docs` and diff inspection.  
  Result: Passed — `CI=true bin/ci`: 39 files linted, audits clear, Brakeman zero warnings/errors, 45 tests/268 assertions with no failures/errors. `git diff --check -- app config docs` passed; no model contents or schema changed.

## Implementation notes

Moved User and Session to `app/models/`, removed the empty session directory and its collapse rule, and updated the architecture convention. Existing model/session behaviour is unchanged. No scope deviations; task 005a remains draft. The owner subsequently authorized PR publication and merge; task 005a remains unimplemented.

Owner acceptance / merge: Pending.
