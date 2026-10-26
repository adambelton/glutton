# 020c — Shared controller identity requirement

Status: Merged  
Owner: Supporting UI / request access

## Goal

Centralize the session identity requirement in ApplicationController while keeping access opt-in and domain-specific responses unchanged.

## Scope

- Add private `ApplicationController#require_identity`, using existing `current_user` and raising `Identity::Required` if absent.
- Library and Ratings explicitly opt in with `before_action :require_identity`; each handles the shared error alongside its existing service identity error.
- The owner approved this narrow shared-controller and Identity error wiring; no domain operation changes.

## Scope restrictions

- No global callback, authentication redirects, automatic guest creation, session changes, new copy, or service/model rule changes.
- Keep existing service freshness checks and domain failures. Public registration, sign-in and password recovery remain accessible. Deleted-account handling remains unchanged.

## Acceptance criteria

- **AC1:** Library and Ratings preserve active-user access, unauthorized signed-out/expired/revoked responses and deleted-account handling; public Identity flows remain accessible.
  Check: existing integration coverage through full CI.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 425 tests / 4,556 assertions, zero failures/errors/skips. Existing Library/Ratings identity outcomes, public registration/sign-in/recovery and CSRF coverage pass; style and security checks pass.
- **AC2:** Both controllers inherit the shared guard, opt in explicitly and retain handling for service identity failures.
  Check: inspect callbacks/rescues, Rails eager loading and diff check.
  Result: Passed — `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check`. Inspection confirms one private shared guard, explicit callbacks in Library/Ratings only, and both shared and domain-service errors handled. Existing mailer-preview eager-load exclusion notice remains.

## Implementation notes

Implemented the private shared guard and Identity::Required error; Library/Ratings opt in and retain their translated signed-out templates and service identity rescues. No service freshness checks or session behaviour changed. Existing tests cover the observable outcomes; no implementation-only tests added. Owner accepted and authorized merge; merged via PR #34.

Merge evidence: owner approved on 26 October 2026. [PR #34](https://github.com/adambelton/glutton/pull/34) merged at 11:26:07 UTC as `3ed26aed38ca404329efbfa06df144a663abc819`. Hosted Repository checks passed at 11:25:36 UTC for head `42468ab9d5ae88bf0e580b97a04c5ab4d92ffe12`.
