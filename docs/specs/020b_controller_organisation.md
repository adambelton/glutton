# 020b — Top-level domain controllers

Status: Merged  
Owner: Supporting UI / controller organisation

## Goal

Use one top-level controller named for each current product domain: RatingsController and LibraryController.

## Scope

- Move the two controllers and their conventional view directories; qualify domain services/errors explicitly.
- Remove route module scopes and update affected tests and current documentation.
- Use singular Library (`show`) and rating-workflow (`new`, `create`, `dismiss`) resources. Keep `/library` and `library_path`; change Ratings URLs to `/rating/new`, `/rating`, `/rating/dismiss`, with `rating_path` and `dismiss_rating_path`. Update forms, tests and the current entry contract.
- Record the convention: no controller namespace while one controller per domain suffices.

## Scope restrictions

- Preserve responses and domain behaviour; only the explicitly approved route/helper changes and Library index-to-show rename are in scope. No service/model, schema, navigation or locale changes.

## Acceptance criteria

- **AC1:** Existing Library and Ratings requests, including Identity route-test wiring, still work.
  Check: run full repository CI, which includes their request tests.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 425 tests / 4,556 assertions, zero failures/errors/skips; style and security checks passed.
- **AC2:** Rails loads the moved controllers and no runtime/test references use their old names.
  Check: generated routes, eager-load check, reference search and diff whitespace check.
  Result: Passed — `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`; no old controller names or nested view paths remain in app/config/test or the current Ratings entry contract. Existing mailer-preview eager-load exclusion notice remains.

## Implementation notes

Owner explicitly requested this simplification after reviewing task 020. This supporting-area follow-up owns the organisational changes to both controllers; task 020 still owns Library browsing behaviour. Owner accepted and authorized merge; merged via PR #34.

Implemented top-level controllers, conventional view paths, unscoped routes, explicit service/error constants, and updated CSRF test references and temporary Identity test routes. Existing request coverage exercises the moved endpoints.

Singular-resource refinement verified: `RAILS_ENV=test bin/rails routes -g "rating|library"` reports GET `/library` → library#show; GET `/rating/new` → ratings#new; POST `/rating` → ratings#create; POST `/rating/dismiss` → ratings#dismiss. Forms and tests use `rating_path`/`dismiss_rating_path`; `new_rating_path` and `library_path` remain. Full CI rerun passed: 425 tests / 4,556 assertions, no failures/errors/skips; eager loading and whitespace passed. No old plural Ratings URL/helper references remain in app/config/test or the current entry contract. No compatibility aliases were added.

Merge evidence: owner approved on 26 October 2026. [PR #34](https://github.com/adambelton/glutton/pull/34) merged at 11:26:07 UTC as `3ed26aed38ca404329efbfa06df144a663abc819`. Hosted Repository checks passed at 11:25:36 UTC for head `42468ab9d5ae88bf0e580b97a04c5ab4d92ffe12`.
