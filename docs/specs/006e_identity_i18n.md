# 006e — Identity user-facing translations

Status: Merged  
Owner: Identity

## Goal

Move existing Identity interface, mail subjects/bodies and custom validation copy into English locale entries using task 001d's standard Rails i18n contract.

## Scope

- Sign-in/out notices, errors, rate-limit response, form labels/actions, session status and deleted-account screen.
- Confirmation/reset subjects and HTML/text body copy; share identical message text across multipart templates.
- Use an error symbol for the custom Session owner validation and translate its message through Active Model.

## Scope restrictions

- No authentication, delivery, rate-limit, token or account-rule changes; no new messages, languages or translation abstraction. Developer ArgumentError/configuration diagnostics remain literal strings.
- Do not change Foundation configuration; consume its standard Rails i18n support. No live emails needed for copy extraction; SMTP configuration is unchanged.

## Acceptance criteria

- **AC1:** Existing English interface/mail behaviour remains intact, and user-facing Identity copy is stored in locale files.  
  Check: Existing controller/concern/mailer tests, strict missing translation configuration and diff review.  
  Result: Passed — existing controller, concern and mailer assertions pass with strict missing-key errors enabled. Development `/session/new` and both mail previews returned 200. Locale copy preserves the prior English wording; multipart templates share introduction/ignore text.
- **AC2:** Invalid session owner retains structured error metadata and translated English copy.  
  Check: Focused model assertion for `errors.details` and rendered message.  
  Result: Passed — added one meaningful model check for `errors.details[:user]` containing `{ error: :inactive }` and English `must be active`; passed in the full run.
- **AC3:** Existing tests/style/security checks pass without provider access.  
  Check: `PARALLEL_WORKERS=1 CI=true bin/ci`, `bin/rails zeitwerk:check`, `git diff --check`.  
  Result: Passed — `PARALLEL_WORKERS=1 CI=true bin/ci`: 60 tests / 503 assertions, 48 Ruby files linted cleanly, audits clear and Brakeman zero warnings. `bin/rails zeitwerk:check` and `git diff --check` passed. No live mail sent. Initial strict lookup revealed missing model attribute labels; added their locale entries and the final run passed.

## Implementation notes

Requested during review of task 006; this separate Identity task consumes Rails i18n rather than changing another domain's behaviour.

Owner acceptance / merge: Accepted by the owner and merged via [PR #10](https://github.com/adambelton/glutton/pull/10) on 19 October 2026 after hosted CI passed on the final agent-rule commit. Squash commit: `93e857bdd8aa220b2153ced1b38026e01c582ae9`.
