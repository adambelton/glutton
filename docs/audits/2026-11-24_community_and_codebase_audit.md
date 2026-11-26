# Community and codebase audit

24 November 2026 · Foundation / repository review · Audited commit `89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81`

The highest-impact finding is that account closure can delete other members’ replies on a surviving curation. The current preview also has a gap between checking Community access and committing an onboarding change. Foundation event delivery has a separate race with account cleanup.

The review traced Community requests, Turbo responses, model mutations and database constraints. Across Identity, Library, Registry, Ratings, Recommendations and Foundation it checked for drift identified in the [October codebase audit](2026-10-20_codebase_audit.md), [November application and test audit](2026-11-08_application_and_test_audit.md) and [public interface audit](2026-11-09_public_interface_audit.md). The findings below are from source and schema inspection. The suggested regression checks are follow-up work.

## Findings

### A1 · High · Account closure can erase other members’ replies

When an endorser closes their account on someone else’s curation, foreign keys cascade from the user to the endorsement, from the endorsement to the opening comment, and from that comment to its replies and their contents. The post survives, but another member’s reply can disappear. Restore replay invokes the same account destruction path. The existing test closes the **post author’s** account, where deletion of the entire unprotected post is expected. [Endorsement and post migration](../../db/migrate/20261123110000_create_community_posts_and_film_endorsements.rb) · [Comment migration](../../db/migrate/20261123120000_create_community_endorsement_comments.rb) · [Reply migration](../../db/migrate/20261124120000_add_community_comment_replies.rb) · [Deletion replay](../../app/services/identity/account_administration/replay_account_deletions.rb) · [Curation integration tests](../../test/integration/community_curation_test.rb)

Community owns discussion retention. Identity owns closure and replay. Their deletion ordering is an acknowledged launch dependency. Verify both paths with three distinct members: the post author, an endorser with an opening comment, and the author of a reply. After the endorser’s removal, check that their text and attribution are gone, their endorsement has ended, and the reply remains visible on the surviving post. [Agreed retention rules](../community_niche_requests_architecture.md#author-and-account-deletion)

### A2 · Medium · Onboarding can commit after preview access is revoked

Conduct acceptance and the username and avatar endpoints check preview access in the controller. The subsequent locked Identity workflow checks account access. Username and avatar changes also check current conduct acceptance. None rechecks preview eligibility against the freshly locked member. A revocation that commits between the controller check and the account lock can therefore be followed by a successful write. Curation publication already performs its posting check against the locked account. [Conduct controller](../../app/controllers/community/code_of_conduct_controller.rb) · [Profile controller](../../app/controllers/account_settings_controller.rb) · [Conduct workflow](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/services/community/accept_code_of_conduct.rb) · [Account workflow](../../app/services/identity/account_administration/manage_registered_account.rb) · [Curation publication](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/services/community/publish_curation.rb)

Keep preview policy in Community and receipt/profile mutations in Identity. Verify that revocation winning the lock prevents each write and that a write completed before revocation retains its ordinary outcome.

### A3 · Medium · Account cleanup can interrupt event dispatch

Foundation’s delivery entry point reads a receipt, then follows its event and stream in separate queries to obtain the owner ID. Account cleanup can delete those rows before the owner lock is taken, leaving a missing association and raising during dispatch. The existing race test blocks the worker at the owner lock, after it already has the ID. Resolve the owner ID in a single joined read, handle a missing result, and keep the locked receipt recheck. Cover cleanup during discovery and verify that dispatch can continue with another delivery. [Delivery entry point](../../app/services/domain_events/delivery/deliver.rb) · [Cleanup concurrency tests](../../test/services/domain_events/delivery/concurrency_test.rb)

### A4 · Medium · Collapsed discussions still load and render the full tree

Opening a curation loads all its comments, bodies and authors. The component recursively renders replies inside collapsed disclosures. Publishing an inline reply also rebuilds the full discussion to update one branch and its counts. The Community architecture calls for bounded reads. Verify the change by growing unrelated threads and measuring loaded records and response size for both opening the post and publishing a reply. Preserve selected-reply navigation and removal markers. [Discussion query](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/services/community/curation_discussion.rb) · [Thread renderer](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/components/community/curation_comment_thread.rb) · [Reply controller](../../app/controllers/community/curation_replies_controller.rb) · [Community architecture](../community_niche_requests_architecture.md)

### A5 · Medium · The caller enforces one authored opening comment

`FilmEndorsement#add_initial_comment!` can add a second authored root. The current editor avoids this by inspecting the endorsement and choosing whether to add or revise. No duplicate-producing HTTP path was identified. The model’s public action nevertheless permits a state its callers must know to prevent, a recurrence of the November public-interface finding. Give the endorsement ownership of that decision while retaining the curation lock and batch validation. Verify both editing the existing opening and starting a fresh root after deletion leaves an older removal marker with replies. [Endorsement actions](../../app/models/community/film_endorsement.rb) · [Curation editor decision](../../app/models/community/post_community_curation.rb)

## Recurring convention drift

- **T1 · Identity request helpers navigate implicitly.** The password-recovery CSRF helper opens the sign-in page, including when supplying the default token for a reset submission. Registration, sign-in and Identity entry use similar helpers. Make navigation visible in the example and extract the token from the form already opened. [Password recovery](../../test/integration/password_recovery_test.rb) · [Registration](../../test/integration/registration_flow_test.rb) · [Sign-in](../../test/integration/sign_in_test.rb) · [Identity entry](../../test/integration/identity_entry_test.rb)
- **T2 · A Ratings request test mutates a Registry film directly.** The escaping example changes the film title with `update!` after opening the rating form. Give the fixture its intended title at construction and retain the rendered escaping assertions. [Ratings browser request test](../../test/integration/ratings_browser_test.rb)
- **D1 · Registry import guidance describes obsolete retry behaviour.** The development guide says both source fetches must succeed before insertion and lists initial quality assignment as future work. The importer can persist verified TMDB metadata with empty Wikipedia context. Retrying such an import can return an existing-film conflict. Align the guide with the implemented fallback and the assignment job’s source-readiness requirement. [Development guide](../development.md) · [Import transaction](../../app/services/registry/catalogue_maintenance/import_film.rb) · [Wikipedia fallback](../../app/services/registry/sources/fetch_wikipedia_context.rb) · [Assignment enqueue decision](../../app/services/registry/catalogue_maintenance/import_discovered_film.rb)

## Boundary to preserve

Community reads the viewer’s Watched entries and Registry metadata to establish nomination eligibility. Its private Library shortcuts delegate mutations to Library commands. This follows the agreed shared-read and mutation-ownership conventions. Keep that arrangement when addressing the findings. [Eligibility query](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/services/community/eligible_curation_films.rb) · [Library shortcuts](https://github.com/adambelton/glutton/blob/89ade29d0a1122b9803ed6d45fbcf2ac4c1e5e81/app/services/community/manage_curation_film_in_library.rb)

## Verification at the audited commit

| Check | Result |
| --- | --- |
| Rails suite | 847 tests, 10,538 assertions, zero failures, errors or skips. |
| Browser suite | Chrome 157 with its matching driver passed 50 tests and 1,400 assertions, with zero failures, errors or skips. The initial Chrome 158 run produced 50 teardown errors when Capybara attempted to reset storage for origin `*`. |
| RuboCop and Brakeman | 647 Ruby files inspected with zero offences. Brakeman reported zero warnings and errors. |
| Zeitwerk | Application eager loading passed. The check excluded test mailer previews. |
| Runtime and CI | Local checks used Ruby 3.4.11 because the pinned 3.4.13 was absent. [Hosted CI passed for the audited commit](https://github.com/adambelton/glutton/actions/runs/45447401185). |

The audit made no application changes. Recheck the cited behaviour against the current tree before implementing a finding. For A1 in particular, agree the Community retention and Identity deletion ordering before changing the cascades.

## Remediation

- Account closure and restore replay end the departing member's endorsements on surviving curations and preserve other members' replies. The existing author-account cascade still applies before post protection is implemented.
- Conduct acceptance and profile writes recheck Community preview eligibility against the locked member. Foundation delivery resolves the stream owner in one read and rechecks the receipt under lock.
- Curation discussions load in pages on demand. Film endorsements own opening-comment creation, and edits to published comments happen in the discussion.
- Identity requests now obtain CSRF data from explicitly opened forms. The Ratings escaping test constructs its film with the intended title, and the development guide reflects the Registry import fallback.
