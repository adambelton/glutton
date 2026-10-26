# 018 — Rate and dismiss existing candidates in the browser

Status: Merged — PR #32 on 26 October 2026  
Owner: Ratings / browser flow

## Goal

Let an active guest or registered user rate or dismiss films from their existing Ratings queue through a localized, accessible browser interface. One verifiable outcome: the user can open a candidate, save a rating with optional original expressions or dismiss it, then continue through pending candidates.

Read the implementation plan's superseding queue and hold decisions, architecture/product brief Ratings sections, specs 013–017, docs/ratings_event_publication.md and the existing Identity::UserSessions concern. Use established NextCandidates, SubmitRating and Dismiss contracts. Identity owns session resolution; Film supplies existing catalogue display data. No new synchronous domain contract is required.

## Scope

### Entry and presentation

- Add Ratings-owned routes/controller/views for the existing automatic queue, with a discoverable link from the current home page. Use a bounded oldest-first batch from Ratings::NextCandidates and present one candidate at a time. Do not create presentation history or session-persisted candidate lists.
- Offer the four existing Rating::Values choices with translated labels, optional separate expression inputs, Save rating and Dismiss. Film title and existing release-year data may identify the film; no new metadata import or external requests.
- Keep the initial UI simple and keyboard accessible: labelled rating choices and expression controls, associated errors, clear submit/dismiss actions and status messages. Prefer normal Rails forms/redirects; add no frontend framework.
- Show a localized empty state when no pending candidates remain. Do not query Library or fill shortfalls from the entire catalogue.
- Resolve current_user through existing Identity helpers and derive owner IDs exclusively from that authenticated session. Existing active guests and registered users are supported. Signed-out visitors get a localized sign-in/registration path; merely viewing the page must not create empty guests/candidates. An expired or missing identity must not gain access to another owner's form or be silently replaced on a stale submission.

### Explicitly limited first slice

This task wires the queue that already exists. Catalogue admission/recognition policy has not yet been approved or implemented, so an anonymous visitor cannot yet browse new candidates and save their first rating. That later discovery slice must specify candidate admission and use the established guest-creation contract at the appropriate write boundary. Do not invent catalogue selection or create guest sessions just to conceal an empty queue. The owner approved this limitation; the complete onboarding/discovery flow remains later work.

### Submission and dismissal

- Accept only rating choice and original expression strings for the session-owned candidate; never accept user IDs, nested record IDs or client-supplied held/dismissed state. Controller code delegates to the existing services and does not create ratings or publish events itself.
- Choose a bounded expression UI consistent with Rating::MAX_EXPRESSIONS and RatingExpression::MAX_TEXT_LENGTH, using model constants rather than duplicated limits. Unused blank UI fields are omitted explicitly at the HTTP boundary; preserve nonblank input exactly, including surrounding whitespace, and never split or rewrite an expression. The service continues rejecting blank expressions supplied directly.
- Successful submission or dismissal redirects to the queue using post/redirect/get. A validation failure retains the candidate, selected choice and entered text for correction with localized errors. Errors must not be logged with private expression contents.
- Missing/foreign candidate IDs produce the same non-disclosing unavailable outcome. Fresh owner validation remains in the service. Duplicate rating/dismissal attempts report the existing explicit failure rather than an invented successful transition.
- Automatic GET selection excludes held, dismissed and rated candidates through the existing pending scope. If the user opened a form before a hold/dismissal arrived, their deliberate rating submission remains allowed by the established SubmitRating contract; do not tighten it into a new Library-state authorization rule. Saved ratings never disappear due to a delayed event.
- No explicit hold/snooze/undismiss controls. Targeted entry from Library and bypassing rotation through a new route remain task 019. No watchlist/not-interested buttons or Library writes from this UI.

### Browser and domain boundaries

- Preserve Rails CSRF protection, signed-session behaviour, no-store handling, HTML escaping and existing identity failure behaviour. Any new authored visible/a11y text belongs in English locale files and is tested with strict missing-translation behaviour.
- Minimal home navigation is Ratings entry wiring only. Do not modify Identity services/session issuance, Library UI, event payloads/transport or catalogue behaviour. Use current shared Film display fields without exposing domain internals in cross-domain calls.
- Test the real Ratings services and resulting event rather than duplicating persistence in controller tests. Synchronous success means the rating is saved; do not wait for Library delivery or claim that downstream processing has completed.

## Scope restrictions

- Ratings only, including its routes and minimal entry link. No other domain runtime changes.
- No candidate refill, popularity policy, search/import, first-time guest discovery, recommendation flow, rating replacement/supersession, expression edits, quality/profile processing, snooze scheduling or deployment.
- No extra persistence, public feed, rate-history objects, ratings-specific session tracking, general design-system rewrite or unsolicited analytics.
- Owner approved implementation on 26 October 2026, including the existing-queue limitation and anonymous entry behaviour.

## Acceptance criteria

- **AC1:** Active guests and registered users can complete the existing queue flow.
  Check: request/browser tests for oldest-first eligible candidates, held/dismissed/rated exclusion before limit, all four choices, zero/multiple expressions, dismissal, redirect to next candidate and empty state. Reload persisted text and verify exactly one RatingSubmitted event on save and none on dismissal. Show a manual/browser walkthrough from pre-seeded test candidates; do not imply catalogue refill exists.
  Result: Passed — browser request tests cover guests and registered users, all four choices, oldest-first eligibility, exact expressions, save/dismiss/empty transitions and event counts. A real browser walkthrough verified keyboard rating, optional expressions, next candidate and dismissal; steps below.
- **AC2:** Boundary and stale-form failures are explicit and preserve user input safely.
  Check: nil/malformed/oversized choice and expression inputs, unused blank UI fields, exact nonblank whitespace, validation rerender, duplicate posts, foreign/missing candidates, signed-out/expired/deleted sessions and ownership tampering. Test a hold/dismissal arriving after form display: explicit rating still succeeds without clearing dismissal synchronously. No empty identity created by GET.
  Result: Passed — request tests cover malformed/missing/oversized input, whitespace, correction with preserved valid-shaped text and choice, duplicate conflicts, foreign/missing/malformed IDs, expired/revoked/deleted identity and stale held/dismissed forms. Malformed expression structures or excessive field counts are rejected rather than reflected; ordinary validation errors preserve all submitted fields.
- **AC3:** Browser security, privacy and accessibility hold.
  Check: CSRF enforcement, no-store response, escaped film titles/expressions, no user ID mass assignment, properly associated labels/errors, keyboard operation and strict translations. Confirm service-level atomicity remains covered and no synchronous Library writes or new event loops arise from UI wiring.
  Result: Passed — real CSRF enforcement on both POST routes, session-only ownership, no-store, escaped titles/text, labels/fieldset error associations and parameter filtering are covered. Strict translations enabled in test. Keyboard controls verified in the browser. Existing service atomicity tests passed; no synchronous Library writes added.
- **AC4:** Verification is recorded against the final implementation.
  Check: focused Ratings request/system/service tests; `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, `RAILS_ENV=test bin/rails zeitwerk:check`, `git diff --check`. Record exact browser/manual steps and observed results, plus any browser tooling limitation. No schema migration or deployment is expected.
  Result: Passed — focused request/service checks: 59 tests / 793 assertions. Full CI: 392 tests / 4,190 assertions, zero failures/errors/skips; RuboCop 206 files clean, gem/importmap audits clean and Brakeman zero warnings/errors. Application eager loading and whitespace checks passed. Browser walkthrough completed; no schema changes or deployment.

## Implementation notes

Implemented Ratings::CandidatesController with queue GET and rating/dismissal POST routes, localized forms/errors/status/empty/signed-out views, and a home entry link. Queue selection requests one candidate from NextCandidates. Writes use SubmitRating and Dismiss; model/service contracts are unchanged. Optional expressions use a native keyboard-accessible details disclosure containing up to MAX_EXPRESSIONS labelled textareas. Blank fields are omitted at the HTTP boundary; nonblank strings remain exact. Expression request parameters are filtered from logs.

Two existing Identity integration test route sets now include the home page’s Ratings link destination; no Identity runtime behaviour changed. The new integration test signs a disposable session cookie using a copy of Rails env_config. An initial shared-hash setup polluted other test cookies; fixed before final passing CI. An initial assertion incorrectly expected trimmed display text; corrected to assert preserved whitespace. Initial sandboxed PostgreSQL/style access failed; checks rerun with permitted local access.

Commands run:
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/ratings_browser_test.rb test/services/ratings` — 59 tests / 793 assertions, passed.
- `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` — final 392 tests / 4,190 assertions and all style/security checks passed. Single-worker suite retains explicit service concurrency tests.
- `RAILS_ENV=test bin/rails zeitwerk:check` — passed, existing test/mailers/previews exclusion notice only.
- `git diff --check` — passed.

Browser walkthrough (26 October 2026):
1. In the test database only, create a disposable registered user and two RatingFilms with display titles/release dates. Start `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3018 -P /tmp/glutton018-server.pid`.
2. Open `/ratings/candidates` signed out: sign-in/registration choices appear. Sign in using the disposable account, then follow the home Rate films link: oldest candidate and four labelled choices appear, with optional expressions collapsed.
3. Use Space/Right on the radio group to choose I enjoyed that; Enter expands expressions. Enter `  The atmosphere  ` and `The ending`, collapse with Enter, Tab to Save rating and Enter. Observe saved notice and second film.
4. Use Enter on Dismiss: observe dismissal notice and empty queue. Screenshot saved to `/tmp/glutton018-browser-result.png`.
5. Reload database records: selected value, both exact expression strings, dismissal and exactly one published event verified. Remove only walkthrough sessions/user/films and stop server. Initial cleanup hit the session foreign key; deleting the disposable session first completed cleanup.

Browser server used normal test configuration; CSRF was explicitly enabled and verified in request tests. No development data, migration, external requests or deployment. Existing queue admission remains Library activity or pre-existing candidates; catalogue replenishment/new-visitor discovery and targeted entry are still deferred.

Owner acceptance / merge: Authorized and merged; see evidence below.

## Merge evidence

Owner authorized merge after CI. [PR #32](https://github.com/adambelton/glutton/pull/32) merged on 26 October 2026 at 08:57:13 UTC (GMT), squash commit `f2d8abbfbd2d3f2a335ba49c432904c804310b5a`. Hosted Repository checks passed on exact head `5340552cc874248a58bb84a5a0e2c97b678753bb` at 08:56:55 UTC. Local main was fast-forwarded. Final local CI passed 392 tests / 4,190 assertions with clean style/security checks after refreshing advisory data and patching crass.
