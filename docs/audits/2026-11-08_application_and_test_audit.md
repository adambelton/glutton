# Application and test audit handoff

Date: 8 November 2026  
Reviewing supporting area: Foundation / repository review  
Baseline: local `12c54690f51076a53146382568dc798871b05817`; its tracked tree matched freshly fetched remote main `1332bcd3bb515894af28540e2fa5ad96ad83705f`.

This handoff records the application audit and the separate test-quality pass. The domain structure is broadly sound. The review confirmed one UI defect and identified convention, test-design and observability gaps. The backend suite provides substantial outcome and contract coverage; browser interaction coverage is missing.

## Instructions for the receiving agent

Read AGENTS.md, the current implementation plan, the task template and the relevant domain contracts before changing code. Recheck each finding against the current tree. This audit records findings, not approved implementation scope for every domain.

Create a tightly scoped working record for each independently verifiable owned outcome. Combine a fix and its relevant tests in the same record; do not create separate tasks for review corrections or publication. Shared test mechanics may belong to Foundation, but product assertions and mutations retain their domain ownership. A single agent can address multiple outcomes sequentially without combining their ownership.

Preserve authorized shared reads, durable asynchronous event reactions, explicit user-action failures, localization and existing experiment limits. Do not introduce a generic provider, permissions, workflow or testing framework. No paid experiments, live provider calls, deployments, messages, PRs or merges are authorized by this record alone.

The findings below are point-in-time evidence. Use future working records and PRs for remediation progress rather than turning this audit into a second delivery ledger.

## Application findings

### A1 Medium Confirmed targeted rating mode loss after validation

Owner: Ratings.

Evidence: [RatingsController#render_new](../../app/controllers/ratings_controller.rb), [Ratings::Form](../../app/components/ratings/form.rb), [Views::Ratings::New](../../app/views/ratings/new.rb).

`render_new` determines targeted mode from `params.key?(:film_id)`. The targeted GET carries that parameter, but the form POST carries `rating_film_id` without retaining the presentation mode. A validation failure therefore renders the automatic-queue presentation: Dismiss appears and the targeted return link disappears. This is a presentation-state defect, not an ownership bypass.

Preserve the intended presentation mode across failed submission while continuing to resolve ownership from the session and candidate ID. Do not infer authorization from a submitted presentation flag.

Verification: targeted entry has no Dismiss action; invalid choice, malformed expressions and unadded draft responses retain targeted controls and entered values. Automatic entry retains its own controls. Verify that forged presentation data cannot change ownership or candidate state.

A disposable integration probe loaded the existing `RatingsTargetedEntryTest`, captured CSRF through its `csrf` helper, asserted no dismiss form, posted an invalid value with the existing candidate ID, asserted 422, and asserted no dismiss form again. The final assertion failed: expected zero `form[action="/rating/dismiss"]`, found one. The probe lived outside the repository at `/tmp/glutton_audit_targeted_mode_test.rb`; preserve the regression in the owning task rather than depending on that temporary file.

### A2 Medium Behavioural tests bypass model actions

Owners: the domains whose tests establish the state; see T6 for remediation guidance.

Examples: [ratings_targeted_entry_test.rb](../../test/integration/ratings_targeted_entry_test.rb) updates held/dismissed flags in its repeated-entry and stale-form scenarios; [rating_hold_test.rb](../../test/models/ratings/rating_hold_test.rb) also sets both directly. Other behavioural tests mutate identity type or ownership.

Use implemented actions such as `hold!` and `dismiss!`, constructor fixtures for initial state, and time travel for expiry. Distinguish explicit storage-contract bypasses from ordinary behavioural setup. Do not mechanically remove legitimate constraint tests or add production APIs solely to arrange tests for unimplemented behaviour.

Verification: affected tests still establish the same observable scenarios through owned behaviour, and rejected actions preserve the intended records and events.

### A3 Medium Ordinary actions remain in services

Owners: Identity and Library, in separate tasks.

Evidence: [DeliverRegistrationConfirmation](../../app/services/identity/deliver_registration_confirmation.rb), [RemoveFromWatchlist](../../app/services/library/remove_from_watchlist.rb), [RemoveNotInterested](../../app/services/library/remove_not_interested.rb).

The confirmation delivery service owns attempt limits, cooldown rules and delivery-counter mutation. Library removal services own action-permission enforcement, destruction and publication. These are ordinary actions under the current model-behaviour convention; they are not transitions between model types.

Retain loading, fresh checks, locking, transactions and transport coordination in services. Delegate ordinary actions and their permission rules to the owning models. Keep existing errors and public outcomes; do not introduce idempotent success for repeated user actions. Preserve mail transmission outside the database transaction and publication atomicity for Library removal.

Verification: existing delivery limits, concurrent reservation, mail failure, removal rejection and source/event rollback contracts continue to pass. Model action tests should establish the same permissions rather than merely checking a delegated method was called.

### A4 Low Library list and detail duplicate rating action decisions

Owner: Library.

Evidence: [Views::Library::Browse](../../app/views/library/browse.rb), [Library::RatingStatus](../../app/components/library/rating_status.rb), [LibraryFilmWatched](../../app/models/library/library_film_watched.rb).

Browse chooses Rate/Edit using the selected collection and rated-ID list; detail delegates to model behaviour. They agree now, but permission or display changes can diverge.

Consolidate the behavioural decision and presentation where useful while retaining the efficient batch read. Shared Ratings reads are permitted; do not introduce an event-derived rated flag or a separate projection merely to avoid them.

Verification: list/detail agree for unrated, rated and foreign-user rating evidence; the list retains bounded query growth. Avoid replacing one duplication with an N+1 query pattern.

### A5 Low Shared transport remains Registry owned

Owner: Foundation for the shared transport outcome, with explicit Registry scope for relocation of its existing implementation/call sites.

Evidence: [TypeSafeClient](../../app/services/type_safe_client.rb) constructs and rescues [Registry::ProviderRequest](https://github.com/adambelton/glutton/blob/1332bcd3bb515894af28540e2fa5ad96ad83705f/app/services/registry/provider_request.rb), although both Ratings and Registry consume TypeSafeClient.

This is misplaced supporting infrastructure, not an illegal shared-data read. Establish one appropriate owner for the existing small HTTP transport. Review the boundary before scoping edits; do not create a generic provider framework or duplicate the transport.

Verification: timeout and size bounds, disabled retries, JSON validation, error translation, authentication handling and trace privacy remain intact for existing consumers. Use stubbed HTTP; no live requests are needed.

### A6 Low Presence checks and unused interfaces are inconsistent

Owners: affected domains; keep corrections inside appropriately scoped outcomes.

Examples of optional-object truthiness occur in [Library operations](../../app/services/library/add_to_watchlist.rb), [SessionsController](../../app/controllers/sessions_controller.rb), and [RegistrationConfirmationsController](../../app/controllers/registration_confirmations_controller.rb). Prefer explicit `present?` for optional objects while preserving boolean and nil/false/empty semantics.

[LibraryFilm](../../app/models/library/library_film.rb) exposes `watchlist_addition_error` and `dismissal_error`, whose only callers found were tests. Production services independently choose those errors. Remove redundant interfaces and their implementation-preserving tests unless current production use establishes a need. See T7.

Verification: no changed permission/error semantics; repository search confirms remaining callers before removal. Do not mechanically replace meaningful predicates or boolean flags.

### A7 Low Assessment trace metadata stops at root spans

Owner: Foundation shared tracing, with explicit scope for any domain instrumentation changes.

Evidence: [Ratings assessment](../../app/services/ratings/assess_rating_qualities.rb), [Registry assignment](../../app/services/registry/assign_initial_film_qualities.rb), [TypeSafeClient](../../app/services/type_safe_client.rb).

Assessment roots carry domain tags and environment; TypeSafe generation spans do not inherit these attributes. Usage-bearing observations can therefore be absent from observation-level filtered views or aggregations. This is inferred from emitted attributes and current [Langfuse propagation guidance](https://langfuse.com/integrations/native/opentelemetry), not verified against hosted trace ingestion.

Propagate the relevant non-sensitive context without exporting private expressions, credentials or unrelated request data. Use the TypeSafe and Langfuse skills when addressing this outcome.

Verification: in-memory exported generation spans retain parent linkage, domain/environment context, model and usage attributes; privacy assertions continue to exclude expression text and secrets. Hosted ingestion verification, if required, needs appropriately authorized execution and must be reported separately.

## Separate test quality findings

### T1 High value coverage gap JavaScript interactions are untested

Owners: Foundation for minimal browser-test infrastructure; domain interaction scenarios retain their owners.

The test inventory and CI contain HTTP integration tests but no JavaScript-executing browser suite. [IdentityEntryTest](../../test/integration/identity_entry_test.rb) checks carousel/theme markup; [RatingsBrowserTest](../../test/integration/ratings_browser_test.rb) posts expression fields directly. These cannot establish that the real controls work.

Add a small set of visible interaction tests for expression entry/removal, Enter versus Shift+Enter, draft blocking, theme persistence, carousel navigation/pause and toast dismissal/pause. Prioritize the core rating interaction. Test what a person can do and observe, not controller method names or exact DOM nesting. Keep HTTP coverage for authorization, escaping, response contracts and server validation. A1 requires an HTTP regression test independently of browser infrastructure.

Verification: tests execute actual JavaScript and fail when the relevant interaction is broken; include the chosen checks in CI. Avoid recreating every backend edge case in a browser.

### T2 Medium Expected outcomes depend on actual results

Owner: Library.

In [EntryOperationsTest](../../test/services/library/entry_operations_test.rb), the success test branches on `result.destroyed?` to decide whether deletion was expected. For transitions it largely checks that the original permission became false, which does not establish the intended destination. Other coverage exists, but this example is independently weaker than its name suggests.

State the expected outcome before exercising each operation. Separate deletion and transition examples if that is clearer than a table. Verify the intended observable state or permitted behaviour and exact duplicate failure; do not assert concrete collaborator classes merely to distinguish cases.

Verification: deleting when a transition was intended, or transitioning to the wrong state, must fail the relevant test without relying on another file's assertions.

### T3 Medium Tests reach into private controller state

Owner: Identity.

[Controller-concern UserSessionsTest](../../test/controllers/concerns/identity/user_sessions_test.rb) calls private methods with `send`, asserts object identity, and removes `@current_user` to manipulate memoization.

Retain the contracts being protected: session rotation, no accidental identity creation, rollback, pending-registration preservation and failure propagation. Prefer public request behaviour and persisted outcomes. A private helper rename or memoization refactor should not break those tests if behaviour is unchanged. Preserve narrowly justified fault injection where public requests alone cannot establish the failure case.

Verification: retain coverage of each distinct failure/security outcome before removing private-method tests; avoid merely dropping difficult cases.

### T4 Medium Helpers hide state changing requests

Owner: Ratings.

[RatingsBrowserTest#csrf](../../test/integration/ratings_browser_test.rb) performs `GET /rating/new`, and `rate` calls it implicitly. That GET can replenish the candidate queue. A helper that appears to retrieve a token changes product state before the action under test.

Open the page explicitly during arrangement, capture the token from that response, and submit it explicitly. Apply the same review to targeted/revision helpers. Make stale-form boundaries visible and avoid incidental navigation between observing and submitting a form.

Verification: tests clearly identify which request admits candidates; invalid submission and stale-form assertions cannot be accidentally satisfied or obscured by an extra GET.

### T5 Low Duplication and large examples obscure purpose

Owners: Library, Identity and Ratings for their scenarios; Foundation only for genuinely shared test mechanics.

[DetailActionsTest](../../test/services/library/detail_actions_test.rb) overlaps [EntryOperationsTest](../../test/services/library/entry_operations_test.rb) on ownership, expiry and rollback. The large curated-preview example in [IdentityEntryTest](../../test/integration/identity_entry_test.rb) combines account navigation, image safety, carousel structure, readonly controls and source links. [Ratings::ConcurrencyTest](../../test/services/ratings/concurrency_test.rb) mixes helpers and scenarios and uses a boolean loop plus manual deletion to reset competing-order cases.

Consolidate truly duplicate scenarios and split unrelated contracts into clearly named tests with independent setup. Keep tables when the cases share one contract; avoid branching tables that require mentally executing the test. Consider small shared helpers for repeated connection barriers or session binding only where they improve clarity. Do not build a test framework or hide product behaviour behind a large scenario DSL.

Verification: each retained failure identifies the violated contract and case. Preserve distinct race orderings and rollback stages; reducing line count is not the objective.

### T6 Model mutation ownership in tests

This is the same underlying finding as A2, not a separate remediation task. Use existing domain actions, constructors and time travel. Isolate and explain special storage fixtures for unimplemented lifecycle states rather than creating production APIs solely for setup.

### T7 Tests preserve unused production interfaces

Owner: Library; overlaps A6.

[LibraryFilmTest](../../test/models/library/library_film_test.rb) tests error-selection methods that production does not call. These assertions preserve redundant interfaces rather than the actual rejection contract. Remove them alongside the unused methods and retain tests of the real actions and agreed failures.

## Coverage and design worth preserving

- Real PostgreSQL race tests verify one winner, explicit stale/duplicate rejection, expiry/claim ordering and no activity resurrection. Their use of blocking detection is purposeful; do not replace deterministic barriers with arbitrary long sleeps.
- Transaction rollback, atomic source/event publication, ordered delivery and retry/receipt behaviour are valuable contracts.
- Foreign keys, uniqueness, immutable evidence and targeted persistence snapshots justify direct storage tests. Raw writes in explicitly labelled constraint tests are not ordinary mutation violations.
- Provider request shapes, bounded calls/costs, error handling, privacy and trace output deserve precise assertions. Stubbed probabilities test deterministic policy; they do not establish live semantic accuracy.
- [Library::BrowseTest](../../test/services/library/browse_test.rb) checks bounded query growth rather than exact SQL text. Keep this performance contract while allowing implementation changes.
- Shared reads, receiving-domain event handlers, explicit transition failures and localized application copy are broadly consistent. The previous authentication serialization fix remains present.

## Verification evidence and limits

| Check actually run during the application pass | Result |
| --- | --- |
| `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` | Passed: 670 tests, 8,376 assertions, zero failures/errors/skips; seed 13524. Initial sandbox attempt could not connect to PostgreSQL; approved rerun used the local test database. |
| `bin/rubocop --no-server --cache false` | Passed: 377 files, no offences. |
| `RAILS_ENV=test bin/rails zeitwerk:check` | Application eager loading passed; test mailer previews were explicitly excluded by the check. |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | Passed: zero warnings and errors. |
| Disposable targeted-mode integration probe | Failed as expected for A1: one test, three assertions, one failure; dismiss form unexpectedly appeared after 422. |
| Remote main comparison | Fetched main at `1332bcd`; tracked tree matched the local audited tree. |
| `git diff --check` and working-tree inspection at audit completion | Passed; no repository changes from either review pass. |

The separate test-quality pass was static inspection and did not rerun the unchanged suite. Review coverage included test inventory, representative domain/service/model/integration/job/support tests, anti-pattern searches and CI configuration; it is not exhaustive proof of every assertion or concurrency interleaving.

Live providers, hosted tracing, interactive browser behaviour, dependency-advisory refreshes and hosted CI were not verified. The passing suite is evidence of its current assertions, not evidence that the missing behaviours are correct. No application fixes were made by either audit.
