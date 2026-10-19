# 001d — Rails i18n foundation

Status: Ready for review  
Owner: Foundation

## Goal

Use Rails' existing I18n support for application copy, with English as the initial locale and missing translations failing in development/tests.

## Scope

- English locale configuration, translated layout metadata and scaffold heading/tagline.
- Established consumer contract: standard Rails `t` / `I18n.t`, named keys, interpolation, plain-text values escaped by views; Active Model error symbols use Rails' normal translation lookup. Missing keys raise in development/test.
- Document the convention for new user-facing text. Identity migrates its own copy separately in task 006e.

## Scope restrictions

- No custom translation abstraction or string constants wrapping locale keys, translation gems, new languages, locale selection/persistence, domain behaviour changes or authentication changes.
- Static Rails emergency error pages remain self-contained, available even when Rails cannot boot. Developer exceptions, logs and configuration diagnostics are not UI copy.

## Acceptance criteria

- **AC1:** English defaults, locale HTML metadata and scaffold text render; unknown translation keys fail in development/test.  
  Check: Existing request tests plus runner assertions on locale configuration and `I18n.t` missing keys.  
  Result: Passed — existing request tests passed in full CI. Development Rack::MockRequest checks returned 200 for `/`, `/session/new` and both mail previews. `RAILS_ENV=test bin/rails runner` asserted default/available locales are English and missing `I18n.t("missing.translation.probe")` raises `I18n::MissingTranslationData`.
- **AC2:** Foundation changes introduce no product rules or translation service layer.  
  Check: Review diff; `bin/rails zeitwerk:check`, full local CI and `git diff --check`.  
  Result: Passed — `PARALLEL_WORKERS=1 CI=true bin/ci`: 60 tests / 503 assertions, no failures/errors/skips, 48 Ruby files linted cleanly, dependency audits clear, Brakeman zero warnings. `bin/rails zeitwerk:check` passed (preview directory warning unchanged; previews exercised separately). `git diff --check` passed.

## Implementation notes

User requested i18n setup while reviewing PR #9. Implementation authorized; no merge authorized.

Owner acceptance / merge: Pending.
