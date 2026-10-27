# 023b — Open rating editing from Library

Status: Accepted  
Owner: Library / rating navigation

## Goal

An active guest or registered user can revisit their rating from a watched film in Library. Rated films offer “Edit rating”; unrated films retain “Rate this film”. Consume the established Ratings destination without changing Ratings or storing copied rating information.

Prerequisites: Library collection/detail pages (020–022a), rating replacement (023) and the editing destination (023a). Read the Library sections of the product and architecture briefs, the implementation plan and `docs/ratings_targeted_entry.md` before implementation.

## Scope

- Add a localized Edit rating link to rated watched films in the Watched collection and on their Library film detail pages. Link to `edit_rating_path(film_id: library_film.film_id)` using the shared Film ID. No owner ID or RatingFilm ID is passed.
- Preserve existing rating status text and first-rating links for unrated watched films. ToWatch and NotInterested pages do not gain rating-edit links.
- Keep action availability with the Library film model. Add the action-specific `can_edit_rating?` behaviour for detail rendering, with a false superclass default and watched behaviour based on authoritative Ratings evidence. Do not select partials or reconstruct permissions from STI class names. Partial names describe information/actions.
- Preserve the collection's existing bounded/batched rating-status read. Use its authoritative rated-film results to present the corresponding navigation link; do not introduce per-row queries, mirrored state or a generic permission framework just to share rendering with the detail page.
- Navigation reads existing state only. Opening Library must not create candidates, ratings or events. The Ratings destination continues to validate its own ownership and current evidence; stale Library pages do not bypass it.
- Localize link labels and film-specific accessible names, escape film titles, preserve keyboard access, mobile layout, pagination, no-store and existing session failures.

## Scope restrictions

- Library owns this task. No changes to Ratings controllers, services, models, views, routes or replacement semantics. The established GET destination is sufficient; no new synchronous mutation contract or asynchronous communication is needed.
- Do not copy rating values, current rating IDs, expressions or rated flags into Library storage. Shared read access is allowed and already used here.
- No schema changes, new events, background jobs, type-based rendering, shared navigation shell, automatic redirects or new Library transitions.
- No rating history display, deletion, scoring, expression editing mechanism, search/import UI or recommendations work. Task 024's original expression-editing outcome is already covered by 023/023a.
- Scope is limited to navigation from the existing collection/detail pages. Do not redesign those pages or generalize their query/presentation architecture.

## Acceptance criteria

- **AC1:** Rated watched films offer an Edit rating link on both Library surfaces; unrated watched films offer the existing first-rating link. Other Library states do not offer rating editing.
  Check: model permission and request tests for all existing Library states, including ratings with replacement history. Assert destination uses the shared Film ID and accessible name includes the escaped film title. Verify guest and registered access.
  Result: Passed: model permissions and Library request tests cover same-owner evidence, guest and registered users, replacement history, held/dismissed candidates, both surfaces, first-rating links and exclusion from other states. Film-specific accessible names and escaped script-like titles verified.
- **AC2:** Library reads preserve ownership and do not write or duplicate Ratings state. Existing session, pagination and collection behaviour remain intact.
  Check: request regressions for foreign/missing Library entries and signed-out/expired/deleted sessions; assert no changes to RatingFilm, Rating, expressions, LibraryFilm or events while loading the pages. Preserve the existing batched collection read in review without asserting incidental SQL text.
  Result: Passed: page reads leave LibraryFilm, RatingFilm, Rating, RatingExpression and DomainEvent counts unchanged. Existing ownership, missing-entry, session and pagination regressions passed. Reviewed Browse: its existing batched rated-film lookup is unchanged; no per-row collection queries added.
- **AC3:** Following the Library link opens the owner's existing current rating and expressions, and a replacement is visible on a subsequent visit through the same Library link.
  Check: integration/browser walkthrough from Watched collection → edit → save → Library detail → edit again; verify latest evidence. Check 375px and desktop widths, keyboard activation and translations. Run focused Library/Ratings request regressions, full local CI, eager loading and `git diff --check`; record commands/results here.
  Result: Passed on 27 October 2026: focused command below passed 32 tests / 488 assertions. Full CI passed 463 tests / 5,173 assertions with clean style and security checks; eager loading and whitespace checks passed. Initial CI found two test formatting offenses; corrected and reran full CI successfully. Browser walkthrough with disposable test data: Watched → keyboard-activate Edit rating → edit expression → keyboard-save → Library detail → keyboard-activate Edit rating shows updated expression. Collection screenshots at 375px and 1280px show no horizontal overflow (scroll width equals viewport); mobile detail link also verified. Temporary server stopped and fixture removed.

## Implementation notes

Owner approved implementation on 27 October 2026. Added model-owned detail permission and localized editing links to the existing detail partial and batched collection display. No Ratings implementation, schema or communication changes.

Reproducible automated checks:
```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/library_film_test.rb test/integration/library_browser_test.rb test/integration/library_details_test.rb test/integration/rating_revision_browser_test.rb
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
RAILS_ENV=test bin/rails zeitwerk:check
git diff --check
```

Manual check: sign in with a rated watched film, open Library → Watched, activate Edit rating with Enter, change an expression and save. Return to its Library detail page and activate Edit rating again; verify the new expression. Repeat collection layout checks at 375px and 1280px. Eager loading retains the existing excluded test/mailers/previews notice. No scope deviations.

Owner accepted on 27 October 2026 and authorized PR creation and merge after hosted CI passes. Merge pending.
