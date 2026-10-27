# 023a — Edit the current rating in the browser

Status: Merged  
Owner: Ratings / revision browser flow

## Goal

An active guest or registered user can open a Ratings-owned editing destination for an already-rated film, see their current rating and expressions, and save a replacement using task 023. Earlier ratings remain intact. This task supplies the destination and a post-submission link; adding Library entry links remains separately owned work.

Prerequisites: existing Ratings browser conventions (018/019) and the replacement operation (023). Follow the mobile-first layout and localized-content conventions in the product and architecture briefs.

## Scope

- Extend the existing singular rating resource and top-level RatingsController with edit/update. Proposed destination: `GET /rating/edit?film_id=<shared Film ID>`; update: `PATCH /rating`, submitting rating_film_id, previous_rating_id, value and expression_texts. Keep the shared Film ID at the cross-domain navigation boundary; only existing owned candidates can be edited.
- Load the existing owned candidate and current rating through Ratings-owned service behaviour. Edit is read-only: no candidate admission, first submission, Library prerequisite or writes. Missing/foreign films or candidates return 404; an existing unrated candidate returns an explicit 409 revision-unavailable response.
- Prefill the selected value and all current expressions. Reuse the existing rating/expression form where practical, with explicit form action/method and localized editing copy. The hidden previous_rating_id captures the displayed rating. Parse IDs at the HTTP boundary to the integer required by the revision contract; services load and validate entities, models own replacement rules.
- Update calls `Ratings::ReviseRating` and replaces the full expression set. Blank fields are omitted as in first submission; clearing all expressions saves a new rating with none. Preserve old rating/expressions. No revision event is published.
- Invalid values/expressions return 422 with safe submitted values retained. Keep the originally submitted previous_rating_id through error redisplay; do not silently retarget a newer rating. Stale/replayed updates return 409 with a localized reload-edit link. Reload obtains the latest rating and expressions; it does not automatically retry or overwrite intervening work.
- Successful update redirects with 303 to the same edit destination and a localized confirmation. Include a return-to-rating-queue link. Following first submission, keep the existing queue redirect and offer a localized edit-just-saved-rating link identifying that film; this makes the editing flow reachable within Ratings without changing Library.
- Preserve active-owner/session checks, deleted-account handling, CSRF protection, no-store responses and safe escaped expression rendering. No owner ID comes from submitted input. Validate before redirecting; no arbitrary return URL.
- Document the editing destination for a later Library-owned link task. This is a stable navigation destination, not a new cross-domain mutation contract.

## Scope restrictions

- Ratings owns all changed behaviour. No Library controller/model/view changes, recommendation work, shared navigation shell or other domains' mutations. Existing Library rated display continues unchanged.
- No schema changes, new event, superseded flag, history page, rating deletion, undo, scoring, profile work or expression processing. Existing first-rating and dismissal semantics stay intact.
- Edit/update require an existing rated candidate; do not admit one or route first submissions through replacement. Keep one RatingsController and the singular rating resource; no extra controller or generic form/service framework.
- Expression changes use full replacement, not in-place changes to historical records. Review whether anything remains for planned task 024 after this flow; do not invent a second editing mechanism here.
- No deployment, paid services or external communication. Spec approval does not approve the future Library link task.

## Acceptance criteria

- **AC1:** Edit displays the latest rating and exact original expressions for the signed-in owner without writing anything, including for held/dismissed candidates.
  Check: request tests for guest/registered owners, latest revision selection, no writes on GET, unrated/missing/foreign records, signed-out/expired/deleted sessions and malformed film IDs.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/rating_revision_browser_test.rb test/integration/ratings_browser_test.rb test/integration/ratings_targeted_entry_test.rb`: 26 tests / 484 assertions, no failures/errors/skips. Edit tests cover latest evidence, held/dismissed candidates, escaping, no writes, identity and unavailable outcomes.
- **AC2:** Save creates a replacement with the submitted expressions, preserves history and candidate state, and redirects to the same editing destination with confirmation. Clearing all expression fields is supported. No revision event is emitted.
  Check: request tests through the real service, including same-value/expression-only edits, no-expression replacement and first-submission edit-link destination. Verify persisted current/history records and unchanged events.
  Result: Passed in the same focused suite and final full CI. Request tests verify historical expressions remain intact, same-value/empty-expression replacement, unchanged candidate flags and event counts, 303 confirmation and the first-submission edit link. Real browser walkthrough confirmed first submit → edit → replace → clear expressions.
- **AC3:** Invalid or stale submissions do not overwrite current evidence. Validation redisplay preserves input and the original previous-rating ID; a newer revision cannot be silently adopted by an old form.
  Check: invalid/malformed inputs, ownership tampering, missing/invalid/stale previous IDs, double submission and a newer revision between display/error redisplay/save. Assert 422/409 outcomes and unchanged records. CSRF-enabled requests reject untrusted writes.
  Result: Passed. Request tests exercise malformed values/expressions/IDs, owner tampering, replay, original expected-ID preservation through validation errors after an intervening revision, and CSRF rejection. A real two-tab browser check confirmed an old form shows the stale message and reload link, and reload shows the winning rating.
- **AC4:** The edit flow is usable on narrow mobile and desktop layouts, by keyboard, and with strict translation checks; first rating and dismissal flows remain usable.
  Check: browser walkthrough at 375px and desktop widths: first submit → edit link → change value/expressions → save → reload → clear expressions; verify labels, focus, escaping, notices and stale reload behaviour. Run request regressions and `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, eager loading and `git diff --check`.
  Result: Passed. Final `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 460 tests / 5,081 assertions, no failures/errors/skips; style and all security checks clean (log: `/tmp/glutton023a-ci.log`). `RAILS_ENV=test bin/rails zeitwerk:check` passed with the existing excluded mailer-preview notice; `git diff --check` passed. In-app browser walkthrough on localhost test server at 375px and 1280px confirmed no horizontal overflow, labels, escaped original expression, prefilled radio choice, save notices, expression clearing and explicit stale reload. Keyboard activated edit/reload links and save, and changed rating with arrow navigation. Strict translation checks were enabled in the test environment; request tests explicitly enabled CSRF. Temporary test server stopped and fixture removed. Screenshot: `/tmp/glutton023a-mobile.png`.

## Implementation notes

Owner approved implementation on 26 October 2026. Added edit/update to the existing controller and singular resource, a read-only FindCurrentRating service, shared form method/action locals, localized edit/stale pages and first-submission edit link. The existing ReviseRating service owns replacement and stale checks. Controller parses HTTP IDs and shares expression shape validation with first submission; it does not query entities directly. Validation redisplay preserves the submitted expected ID.

No schema changes or revision events. Library links and shared navigation remain outside this task. Full replacement includes expression editing; review whether planned task 024 has any remaining independent outcome before drafting it. The existing plain HTML rating form is reused; no visual redesign was introduced.

Verification on 26 October 2026: initial full CI found four test string-quoting style offenses while all tests passed. Corrected them and reran full CI successfully; only the final successful evidence above is the completion gate. Browser reproduction: create an active test account and unrated candidate, sign in, open `/rating/new`, submit with an expression, follow the edit link, change/save, clear/save, then open two edit tabs and submit one before submitting the other. Confirm conflict and reload the latest. Development data was not changed.

Owner accepted and authorized merge after CI. PR #38 merged on 26 October 2026 at 15:14:48 UTC; squash commit `c3b1ebf114d50eff1422dde4e5c36cce3ffc5b6a`. Hosted Repository checks passed at 15:14:32 UTC on exact head `3b08f8b2a1da635accc261bb79d5b53d1e9d192c`. Local main fast-forwarded.
