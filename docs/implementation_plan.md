# Glutton — Initial implementation plan

Status: See current implementation status below for merged work, changes awaiting review and planned capabilities.  
Date: 20 October 2026

## Current implementation status

This section summarizes current delivery status; task tables and linked specs retain detailed outcomes and historical verification.

| Area | Current status |
| --- | --- |
| Foundation | Tasks 001b–001e merged; original scaffold tasks 001/001a retain their recorded Ready for review status. Audit 001f and documentation follow-up 001g merged via PR #22. Async design 001h and durable delivery 001i merged via PR #25. Publisher ownership follow-up 001j merged via PR #26; delivery status follow-up 001k merged via PR #28. |
| Identity | Tasks 002–006 and their delivered follow-ups through 006n merged. Authentication serialization 006o, confirmation simplification 006p, explicit confirmation paths 006q and current-guest confirmation 006r merged via PR #22. Explicit guest-expiry errors 006s merged via PR #23. |
| Film knowledge | Catalogue 007, TMDB import 008, search 009 and outcome-test follow-up 009a merged. Boundary consistency 009b merged via PR #22. Analysis requirements 025, evidence pilot 026, comparison/history documentation 026a and repeat pilot 027 merged via PR #40. Task 028 draft/activation lifecycle is Draft. No quality/scoring pipeline is implemented. |
| Library | Watched operation 010 and guest-duration tests 010a merged. Watchlist task 011 merged via PR #23; dismissal task 012 merged via PR #24. Event publication task 012a merged via PR #26; Library browsing task 020 merged via PR #34; Library film details/watchlist actions task 021 merged via PR #35; dismissal actions task 022 and existing-entry action consolidation 022a merged via PR #36. |
| Ratings and Recommendations | Ratings candidate task 013 merged via PR #27; task 014 first rating submission merged via PR #28; task 015 expressions merged via PR #29; task 016 Library rating-event consumer merged via PR #30; task 017 Ratings Library-event consumer and follow-ups 016a/012b merged via PR #31; task 018 browser flow merged via PR #32; task 019 targeted entry merged via PR #33; task 020 Library browsing and supporting follow-ups 020b/020c merged via PR #34; duplicated rating-status proposal 020a is withdrawn. |

## Task rules

Each task has **one owning domain, one small outcome, and independent verification**. Before implementation, write its spec from [the template](task_template.md), with scope restrictions and acceptance criteria including verification methods/results. Specs exist for tasks 001, 001a, 001b, 002, 003, 004, 004a, 005, 005a, 005b and 006. Tasks 001b, 002 and 003 were accepted by the owner and merged via PRs #3, #1 and #2 respectively. Task 004 was accepted by the owner and merged via PR #4. Task 004a was accepted by the owner and merged via PR #5. Task 005 was accepted by the owner and merged via PR #6 without waiting for queued hosted CI, as explicitly authorized. Tasks 005a and 005b were accepted by the owner and merged via PRs #8 and #7. Task 006 and Foundation follow-up 001c were accepted and merged via PR #9 after hosted CI passed; both live mail templates were received.

If work appears to require changes in multiple domains, **review the boundary first**. Ask whether ownership is wrong, an invariant needs one owner, or responsibilities are too tightly coupled. Do not mechanically split a poor boundary into provider/consumer tasks. Agree cross-domain contracts before implementation, including inputs, results and failure behaviour. Implement and test each side in its own task: the provider first, then the consumer against the established contract. Reading another domain’s shared data is allowed and does not require a separate contract or provider task. Changing its implementation or mutating its data remains subject to its ownership. Review ownership when a contract exposes misplaced rules or unnecessary coupling.

Use statuses `Draft`, `In progress`, `Ready for review`, `Accepted`, `Merged`; note blockers explicitly. Record actual changes and evidence in the spec. Owner acceptance and merge are separate from checks passing. Spec creation alone does not start implementation, and this plan does not authorise the whole list.

Tasks 001d/006e were accepted and merged via PR #10 after hosted CI passed. Task 006a was accepted and merged via PR #11 after hosted CI passed; task 006b was accepted and merged via PR #12 after hosted CI passed: registration now proceeds through pending persistence, confirmation/claim capability (006b), then HTTP wiring (006f). Task 006f was accepted and merged via PR #13 after hosted CI passed. Task 006c password recovery was accepted and merged via PR #14 after hosted CI passed; owner confirmed browser completion. Task 006d bounded Identity retention cleanup was merged via [PR #15](https://github.com/adambelton/glutton/pull/15) on 19 October 2026; merge commit `74d0cfbc859d7cf6d7b05c5cf61ef776df32d7d6` was verified against GitHub on 20 October 2026. Local verification evidence remains in its spec.

## Domain ownership

Owner clarification, 26 October 2026: domain boundaries are ownership boundaries, not read-access barriers. All domains may read the shared database, including another domain’s models/scopes, while respecting session/user access controls. Each domain owns its mutations, invariants and lifecycle. Read-only presentation queries do not require event-derived copies or new provider/consumer tasks. Durable events remain the agreed mechanism for existing cross-domain state-changing reactions; this clarification does not replace those workflows. For example, Library derives rated/awaiting-rating display from Ratings-owned records without storing its own rated flag.

| Owner | Responsibilities | Boundary |
| --- | --- | --- |
| Film knowledge | Film identity, TMDB search/import, metadata/media references; later analyses, quality vocabulary and film associations | Shared film knowledge independent of viewers |
| Library | Canonical user–film relationship: watchlist, watched, not interested; library management and views | Does not own rating/recommendation presentation histories, ratings, expressions or inferred taste |
| Ratings | Rating presentations and all responses, ratings, original expressions; scoring, profiles and reassessment as distinct capabilities | Owns next-film selection from its own presentation state; reports completed ratings through Library operations |
| Recommendations | Candidate selection, ranking, explanations, recommendation presentations and all responses | Owns recommendation eligibility; consults Library and Ratings, requests Library-owned actions |
| Identity (supporting) | Guest/registered users, credentials, sessions, registration and delivery | Supplies session-bound internal identity; owns fixed guest expiry |
| Foundation (supporting) | Rails/database boot; later shared operational infrastructure | No product rules |

A domain is not a table or screen. Rating/recommendation records describe their purpose-specific activity; Library records canonical state. They need not share persistence. Capability boundaries keep tasks small inside Ratings without inventing a separate Taste domain. Do not generate empty engines, namespaces or speculative interfaces.

**Key rules:**

- Ratings records “haven’t seen it” and avoids repeating that rating prompt. This response alone creates no Library classification and does not exclude recommendations.
- Recommendation candidates are assumed unwatched unless evidence says otherwise. Recommendations excludes Library's To watch, Watched and Not interested entries; existence of a Ratings/Recommendations history record alone does not imply exclusion.
- Library owns watched-but-unrated films. “Awaiting rating” means watched without a current rating owned by Ratings; derive the display from that result initially. Library links to the targeted Ratings flow.
- Ratings owns current rating/history; Library's rated presentation reflects it rather than maintaining an independent rating value.
- Ratings does not require a Library watched record to accept a rating. Confirming seen alone stays in Ratings; a completed rating publishes viewing evidence for Library to consume asynchronously.
- Ratings selects the next film from its own queue/presentation state. Library publishes watched facts; Ratings consumes them as known-seen evidence and prioritizes unrated films without another seen question. Explicit rating dismissal remains in place even after new viewing evidence; already-rated films remain rated.
- Product domains communicate through durable asynchronous events with independent transactions and eventual consistency. See [domain events](domain_events.md). Agree publisher/subscriber contracts and implement them in separate owned tasks. Shared-data reads and internal domain operations may remain synchronous; AI processing retains separate rules.
- Analysis pages are directly accessible, with spoiler-labelled navigation normally from the watched Library view; Library watched status is not an analysis authorization gate.

## Initial scaffold

| Task | Owner | Outcome | Depends on | Status |
| --- | --- | --- | --- | --- |
| 001 | Foundation | Minimal Rails app boots against local PostgreSQL, with setup and smoke checks | None | Ready for review — [spec](specs/001_initial_scaffold.md) |

Cleanup/repository follow-up: **001a — Ready for review**, Foundation; [spec](specs/001a_scaffold_cleanup.md). Remove unused scaffold examples and publish the initial public GitHub repository, as authorised by the owner.

CI follow-up: **001b — Merged**, Foundation; [spec](specs/001b_github_ci.md). Run the existing repository checks on GitHub pull requests and main pushes.

Foundation follow-up: **001c — Merged**, [parallel database smoke test spec](specs/001c_parallel_database_smoke_test.md); correct the serial-only database-name assertion exposed by hosted CI for task 006.

i18n follow-ups: **001d — Merged**, Foundation [spec](specs/001d_i18n_foundation.md), provides Rails locale conventions; **006e — Merged**, Identity [spec](specs/006e_identity_i18n.md), migrates its existing UI/mail/validation copy using that contract.

Foundation follow-up: **001e — Merged**, [object-role conventions spec](specs/001e_object_role_conventions.md); record agreed role trust, behaviour ownership/naming and independent freshness rules and outcome/contract-focused testing in repository instructions. Documentation only.

## First rating and library slice

Candidate task boundaries; write each detailed spec just before starting, splitting further if needed. IDs 002 onward replace the earlier unimplemented sequence.

| Task | Owner / capability | Independently verifiable outcome | Depends on | Status |
| --- | --- | --- | --- | --- |
| 002 | Identity / accounts | Email-free guest identity with fixed 24-hour expiry | 001 | Merged — [spec](specs/002_identity_accounts.md), [PR #1](https://github.com/adambelton/glutton/pull/1) |
| 003 | Identity / guest sessions | Browser-session guest access with server-enforced expiry and identity isolation | 002 | Merged — [spec](specs/003_guest_sessions.md), [PR #2](https://github.com/adambelton/glutton/pull/2) |
| 004 | Identity / credentials | Confirmed registered-account credential persistence, normalization and password authentication invariants | 002 | Merged — [spec](specs/004_registered_credentials.md), [PR #4](https://github.com/adambelton/glutton/pull/4) |
| 004a | Identity / model organisation | Group the User model family without changing STI identity | 004 | Merged — [spec](specs/004a_user_model_layout.md), [PR #5](https://github.com/adambelton/glutton/pull/5) |
| 005 | Identity / sessions | Shared guest/registered session lifecycle and password-authenticated registered issuance, without HTTP wiring | 004, 004a | Merged — [spec](specs/005_registered_sessions.md), [PR #6](https://github.com/adambelton/glutton/pull/6) |
| 005b | Identity / model organisation | Keep root models at default paths and group only subclasses | 004a, 005 | Merged — [spec](specs/005b_simplify_model_layout.md), [PR #7](https://github.com/adambelton/glutton/pull/7) |
| 005a | Identity / sign-in flow | Move guest access to shared Session records; sign-in/out UI, protected cookies, rotation, request limits and current identity; no automatic guest merge | 003, 005 | Merged — [spec](specs/005a_sign_in_flow.md), [PR #8](https://github.com/adambelton/glutton/pull/8) |
| 006 | Identity / delivery | Resend configuration and local verification/reset mail previews; no real mail by default | 004 | Merged — [spec](specs/006_identity_mail_delivery.md), [PR #9](https://github.com/adambelton/glutton/pull/9) |
| 006a | Identity / registration | Validated pending credentials for direct signup or an active guest, without user creation, account transition or UI | 004, 005 | Merged — [spec](specs/006a_pending_registration.md), [PR #11](https://github.com/adambelton/glutton/pull/11) |
| 006b | Identity / verification | Confirmation tokens and atomic registered creation or in-place guest claim with fresh session; expiry, replay/conflict rejection and rollback | 004, 005, 006a | Merged — [spec](specs/006b_registration_confirmation.md), [PR #12](https://github.com/adambelton/glutton/pull/12) |
| 006f | Identity / registration UI | Wire registration/confirmation HTTP flow, mail delivery/resend, pending-to-guest continuity, visible verification/expiry, session binding, CSRF, limits, duplicate-email rejection and localized responses | 005a, 006, 006a, 006b | Merged — [spec](specs/006f_registration_browser_flow.md), [PR #13](https://github.com/adambelton/glutton/pull/13) |
| 006c | Identity / recovery | Expiring password-reset browser flow; request limits, atomic credential change/all-session revocation and fresh sign-in | 004, 005a, 006, 006f | Merged — [spec](specs/006c_password_recovery.md), [PR #14](https://github.com/adambelton/glutton/pull/14) |
| 006d | Identity / retention | Bounded expired guest/session/pending cleanup command, claim-race protection and documented cadence; scheduler deployment and future domain activity excluded | 002, 005, 006a, 006b, 006f | Merged — [spec](specs/006d_guest_retention.md), [PR #15](https://github.com/adambelton/glutton/pull/15); future activity deletion policy must be agreed before guest activity persistence |
| 006g | Identity / model organisation | Top-level UserRegistered/UserGuest/UserDeleted lifecycle classes and matching STI values; reversible existing-row migration | 006d | Merged — [spec](specs/006g_user_type_names.md), [PR #16](https://github.com/adambelton/glutton/pull/16) |
| 007 | Film knowledge / catalogue | Minimal film identity/metadata persistence and local sample | 001 | Merged — [spec](specs/007_film_catalogue.md), [PR #17](https://github.com/adambelton/glutton/pull/17) |
| 008 | Film knowledge / import | Import one selected TMDB identity with deduplication | 007 | Merged — [spec](specs/008_tmdb_film_import.md), [PR #18](https://github.com/adambelton/glutton/pull/18) |
| 009 | Film knowledge / search | TMDB search returns disambiguated selection data | 008 | Merged — [spec](specs/009_tmdb_film_search.md), [PR #19](https://github.com/adambelton/glutton/pull/19) |
| 010 | Library / viewing | LibraryFilm watched creation and permitted ToWatch-to-Watched transition returning the entry | 005a, 007 | Merged — [spec](specs/010_library_watched.md), [PR #20](https://github.com/adambelton/glutton/pull/20); commit 82d9b83, hosted CI passed |
| 011 | Library / intent | Watchlist creation, NotInterested-to-ToWatch transition and removal without changing watched entries | 010 | Merged — [spec](specs/011_library_watchlist.md), [PR #23](https://github.com/adambelton/glutton/pull/23); commit 4817bbe, hosted CI passed |
| 012 | Library / dismissal | NotInterested creation, ToWatch-to-NotInterested transition and dismissal removal | 011 | Merged — [spec](specs/012_library_dismissal.md), [PR #24](https://github.com/adambelton/glutton/pull/24); commit 78aba75, hosted CI passed; classification reads deferred to a consumer-driven spec |
| 001i | Foundation / event delivery | Durable outbox and jobs, independent subscriber receipts, ordering, retries, retention and operational visibility | 001h | Merged via PR #25 — [spec](specs/001i_durable_event_delivery.md) |
| 012a | Library / event publication | Publish versioned Library facts; retain stream versions through row deletion/recreation | 001i, 012 | Merged via PR #26 — [spec](specs/012a_library_event_publication.md) |
| 013 | Ratings / presentations | Own oldest-first candidate batches and boolean dismissal; catalogue admission and event consumption remain separate | 005a, 007 | Merged via PR #27 — [spec](specs/013_rating_presentations.md) |
| 014 | Ratings / ratings | First rating submission, rated/unrated/pending scopes and atomic RatingSubmitted publication | 013, 001i | Merged via PR #28 — [spec](specs/014_first_rating_submission.md) |
| 015 | Ratings / expressions | Save multiple optional original expressions atomically with a rating submission | 014 | Merged via PR #29 — [spec](specs/015_rating_expressions.md) |
| 016 | Library / rating-event consumer | Consume completed-rating events; reconcile watched evidence including NotInterested, explicitly handle duplicate deliveries and publish actual Library changes | 012a, 015 | Merged via PR #30 — [spec](specs/016_library_rating_consumer.md) |
| 017 | Ratings / Library-event consumer | Admit watched films, hold/release watchlist films and dismiss not-interested films; preserve evidence and oldest-first ordering | 012a, 013, 014, 016 | Merged via PR #31 — [spec](specs/017_ratings_library_consumer.md) |
| 017a | Ratings / action publication | Record explicit Library choices from the rating flow and publish requests | 013, 001i | Deferred — Ratings flow has no Library-action choices |
| 017b | Library / action consumption | Apply Ratings action requests and publish applied/rejected outcomes; preserve public transition failures | 012a, 017a | Deferred — Ratings flow has no Library-action choices |
| 017c | Ratings / action outcomes | Consume Library outcomes into recorded request status | 017a, 017b | Deferred — Ratings flow has no Library-action choices |
| 018 | Ratings / rating flow | Rating/dismissal UI over the single-record queue | 016, 017 | Merged via PR #32 — [spec](specs/018_ratings_browser_flow.md) |
| 019 | Ratings / targeted entry | Explicitly open a film for rating from Library, bypassing automatic-rotation dismissal; no Library watched-record prerequisite | 017, 018 | Merged via PR #33 — [spec](specs/019_ratings_targeted_entry.md) |
| 020a | Library / rating-event consumption | Withdrawn: duplicate rated flag is unnecessary with shared reads | — | Withdrawn — [decision](specs/020a_library_rating_status.md) |
| 020 | Library / browsing | One Library page with Watchlist/Watched/Not interested dropdown; watched rating status and entry | 010, 011, 012, 019 | Merged via PR #34 — [spec](specs/020_library_watched_view.md) |
| 020b | Supporting UI / controller organisation | Top-level domain controllers and singular Library/rating workflow routes | 019, 020 | Merged via PR #34 — [spec](specs/020b_controller_organisation.md) |
| 020c | Supporting UI / request access | Shared opt-in controller identity requirement with unchanged public access and domain responses | 020b | Merged via PR #34 — [spec](specs/020c_shared_identity_guard.md) |
| 021 | Library / film details and watchlist actions | Polymorphic Library film detail pages; remove ToWatch entries or transition to Watched and use existing rating entry | 010, 011, 012a, 019, 020, 020b, 020c | Merged via PR #35 — [spec](specs/021_library_watchlist_actions.md) |
| 022 | Library / dismissal actions | Compose details from content-named partials guarded by model permissions; add dismissal/reconsideration actions | 011, 012, 012a, 021 | Merged via PR #36 — [spec](specs/022_library_dismissal_actions.md) |
| 022a | Library / action boundary | Consolidate user actions on existing LibraryFilm IDs; retain event-owned creation and remove wrappers | 022 | Merged via PR #36 — [spec](specs/022a_library_action_boundary.md) |
| 023 | Ratings / revisions | Replace a rating and expressions, preserve superseded history without revision events; qualities remain deferred | 014, 015, 019 | Merged via PR #37 — [spec](specs/023_rating_revisions.md) |
| 023a | Ratings / revision browser flow | Edit the current rating through the existing Ratings interface using the established replacement operation | 023 | Merged via PR #38 — [spec](specs/023a_rating_revision_browser.md) |
| 023b | Library / rating navigation | Open current rating editing from rated watched films in collection/detail pages | 020–022a, 023a | Merged via PR #39 — [spec](specs/023b_library_rating_edit_links.md) |
| 024 | Ratings / expression revisions | Edit/remove expressions with clear retention and revision semantics | 023, 023a | Covered by 023/023a; no separate implementation |
| 025 | Film knowledge / analysis design | Define experiential analysis, evidence standards, quality usefulness and evolution requirements before pipeline implementation | 008 | Ready for review — [spec](specs/025_film_analysis_requirements.md) |

The revised Identity sequence replaces magic-link tasks. Guest expiry is fixed at creation plus 24 hours; browser closure is not a reliable expiry signal. Registered sessions follow Rails authentication conventions with no application-imposed TTL. Task 002 provides STI `User`/`GuestUser` persistence, an inactive `DeletedUser` subtype and polymorphic `active?`, deriving the deadline from `created_at` without a stored expiry. Registered subclass, deletion transitions and domain capability modules arrive with their own behaviour; admin permissions remain separate. Task 003 establishes session-bound guest access; task 004 introduces registered credential invariants; task 006b owns the confirmed claim transition; task 005 supplies shared guest/registered session lifecycle and registered authentication and task 005a exposes both identity modes through HTTP. Registered sessions end through sign-out/revocation or inactive-account rejection, not a custom age deadline. The ratings-first entry and first-save guest creation belong in the later Ratings UI task using the established Identity contract. No product UI is added by task 002.

Guest cleanup must remove associated activity as well as the identity. Task 010 covers Library activity through its approved scoped user foreign-key cascade, with existing Identity cleanup/claim compatibility verified; other domains require their own retention decisions before persistence. Task 006d is not authorization to modify other domains or invent deletion contracts mechanically: review ownership and define domain-owned deletion work as those records are introduced. Cleanup must not delete a concurrently registered account. Treat complete guest retention behaviour as a release requirement; do not claim it is implemented by the expiry predicate.

Tasks 010–012 retain their merged local operation contracts. Their old synchronous integration proposals are superseded by the owner-approved [event design](domain_events.md), not by retroactively changing historical verification. Task 001i supplies durable delivery; 012a publishes Library facts from creation onward. Task 014 owns rating-event publication. Task 016 is now Library-owned consumption of completed ratings, including the explicitly scoped system reconciliation of NotInterested to watched that current RecordWatched does not support. Task 017 is now Ratings-owned consumption of Library facts. Task 013 owns local queue/current selection and persistent rating dismissal; it no longer supplies MakeAvailableForRating across domains.

Task 017a publishes Ratings UI Library-action requests, 017b applies them in Library and emits outcomes, and 017c consumes those outcomes in Ratings. Recommendations follows the same separate publication, Library consumption and outcome-consumption steps in its later milestone tasks. No originating screen may claim a Library transition completed solely because its response was recorded. Consumer retries do not turn distinct duplicate user actions into silent successes.

Watched-but-unrated films take priority and skip the seen question. NotInterested means unseen/unwanted and suppresses rating and recommendation presentation. Removal retains unseen evidence. TMDB recognition inputs and the initial unknown-film selection policy remain to be specified; add a Film knowledge provider task before Ratings consumes new metadata. No live TMDB requests belong in presentation selection.

All private operations include checks against accessing another user's records, including other guests, and reject expired guest access. Early domain operations can be verified with representative records and existing contracts; they need not wait for every user interface.

## Later milestones — not implementation tasks

Break down only when approaching each milestone. Domain/capability ownership below replaces the former Taste/Discovery split.

- **Film knowledge:** media enrichment, reviewed trailer data, versioned sourced analyses, quality vocabulary and film associations. Analysis pages are directly accessible with clear spoiler labelling; normal navigation is from the watched Library view. No watched authorization contract is needed.
- **Ratings / analysis:** benchmark JEV scoring contracts and cost against labelled expressions and ratings.
- **Foundation:** task 001i configures durable jobs and outbox delivery now required by product-domain events; domain-specific processing rules remain with their domain.
- **Ratings / scoring:** implement the [agreed scoring design](ratings_scoring_design.md): unexpressed, implicitly expressed and explicitly expressed rating qualities; current-profile interpretation only for qualities without direct expressions; handle stale/duplicate assessments.
- **Ratings / profile building:** explicit-only synthesis and assessment of meaningful changes; evaluate JEV gate and Claude usage.
- **Ratings / preferences:** aggregate completed evidence and expose a preference result for recommendation consumption.
- **Ratings / reassessment:** historical reinterpretation, scheduling and freshness, divided into small tasks. Original input and inference remain distinct inside the domain.
- **Recommendations / eligibility:** consume Library classification and completed-rating events into owned eligibility projections; do not infer exclusion merely from presentation history. Bootstrap and stale/duplicate handling require a dedicated consumer spec.
- **Recommendations / ranking:** consume published completed Ratings preference versions and rank eligible films; define bootstrap, refresh and version handling in its own task.
- **Recommendations / presentation:** record each presented suggestion and explanation, with film media from Film knowledge.
- **Recommendations / responses:** retain response history and publish user choices; a separate Library-owned task consumes requests and publishes applied/rejected outcomes. A Recommendations-owned task consumes outcomes. Define version/conflict and pending UI behaviour before implementation.
- **Recommendations / evaluation:** compare rating-only and expression-informed results from fixed inputs; required Ratings changes become separate work after boundary review.

The first complete loop still requires rating-only usefulness, explicit evidence, historical reinterpretation, media, spoiler-safe explanations and feedback. Boundary changes do not reduce product scope. User-requested imports, conversations and custom artwork production remain later features.

## Before public release

Plan deletion/retention, security/accessibility, seed/media validation, operating-cost controls, deployment/backups and attribution. Review ownership for account deletion before slicing it; do not mechanically invent distributed coordination. Paid data/media licences remain excluded. Provider follow-up adds no gate beyond the agreed TMDB direction.

Film knowledge sequencing clarification, 20 October 2026: task 007 starts with minimal catalogue persistence and a small local sample. JEV work remains deferred. The initial quality vocabulary is provisional and expected to evolve; validating that starting set is not a prerequisite for catalogue implementation. This does not make draft film analyses fact-checked or authorize publishing unverified claims.

Post-merge Identity role/transition fixes in tasks 006h–006k were subsequently accepted and merged with the other convention fixes recorded below. They are separate from task 010.


## Conventions fixes authorized after task 010

| Task | Owner | Independently verifiable outcome | Status |
| --- | --- | --- | --- |
| 006h | Identity / registration | User-owned registration permission and lifetime; transition service retains destination/persistence ownership | Merged — [spec](specs/006h_registration_roles.md) |
| 006i | Identity / browser sessions | Session binding and presentation delegate real user behaviour without subtype dispatch | Merged — [spec](specs/006i_session_roles.md) |
| 006j | Identity / credentials | User-owned credential actions and recovery permission with unchanged security outcomes | Merged — [spec](specs/006j_credential_roles.md) |
| 006k | Identity / model construction | Prevent direct User construction without subtype enumeration; preserve legacy-row loading | Merged — [spec](specs/006k_user_construction.md) |
| 009a | Film knowledge / verification | Test import/sample outcomes rather than incidental whole-row snapshots | Merged — [spec](specs/009a_film_outcome_tests.md) |

For the earlier convention-fix work, the owner requested fixes rather than an audit deliverable; that work has no separate results document. Each task keeps its own verification evidence; the owner subsequently authorized a PR for online review. Owner accepted and authorized merge; PR #21 merged on 20 October 2026 at `0fa54269df0140451ab19ac5b665fb64d6cc3c50` after GitHub Repository checks passed.

Guest-duration follow-ups authorized during PR #21 review: **006l — Merged**, Identity [spec](specs/006l_guest_duration.md), owns the policy constant and lifecycle tests; **010a — Merged**, Library [spec](specs/010a_guest_duration_tests.md), updates only Library tests against that established policy.

Pending-registration duration follow-up: **006m — Merged**, Identity [spec](specs/006m_pending_duration.md); one-hour model-owned registration and confirmation-link deadline with expiry tests, authorized during PR #21 review.

Explicit anonymous registration access: **006n — Merged**, Identity [spec](specs/006n_registration_availability.md).

## Repository audit — 20 October 2026

**001f — Merged**, Foundation / repository review; [spec](specs/001f_codebase_audit.md), [audit report](audits/2026-10-20_codebase_audit.md). Audited freshly pulled main at `3cd3034e0e48fe04648c8a36c4e1d0028a622270`. The audit recorded one reproduced Identity sign-in/password-reset race and three maintainability/documentation observations; task 001f itself made no application changes. Existing tests, style, application eager loading and Brakeman passed. The separately scoped remediation tasks below were accepted and merged via PR #22.

## Audit remediation and confirmation simplification — 20 October 2026

The owner authorized implementation after reviewing audit 001f and discussing Identity complexity. Each task has one owner; no cross-domain contract changes are needed.

| Task | Owner | Outcome | Status |
| --- | --- | --- | --- |
| [006o](specs/006o_authentication_reset_serialization.md) | Identity / sessions | Serialize sign-in with password recovery (A1) | Merged via PR #22 |
| [006p](specs/006p_confirmation_orchestration.md) | Identity / registration | One confirmation coordinator and shared access rule (A2) | Merged via PR #22 |
| [009b](specs/009b_tmdb_boundary_consistency.md) | Film knowledge / provider boundary | Shared date parsing and search parameter rules (A3) | Merged via PR #22 |
| [001g](specs/001g_current_documentation.md) | Foundation / documentation | Consistent current summaries and open decisions (A4) | Merged via PR #22 |

Submission/delivery orchestration, broad Identity rewrites and release infrastructure remain outside this change. Owner accepted and merged this work via PR #22; see merge evidence below.

Verification for 006o/006p/009b/001g: full local CI passed 232 tests / 2,633 assertions, zero failures/errors/skips; RuboCop 127 files clean; dependency audits clean; Brakeman zero warnings/errors. Application eager loading and whitespace checks passed. Individual specs record commands, initial regression failure and limitations. No hosted CI or merge performed.

Confirmation readability follow-up: **006q — Merged**, Identity / registration; [spec](specs/006q_confirmation_paths.md). The owner requested an explicit top-level current-user versus anonymous branch while reviewing PR #22. Full local CI passed 232 tests / 2,633 assertions, style and security checks. Existing contracts and lock order are preserved; accepted and merged via PR #22.

Current-guest confirmation: **006r — Merged**, Identity / registration; [spec](specs/006r_confirmation_guest_attachment.md). A valid token for an unattached registration can upgrade the current active guest without a browser-held pending ID, supporting signup and confirmation in different browser sessions. Conflicting linked guests/requests remain rejected. Full local CI passed 235 tests / 2,662 assertions, style and security checks; the new cross-browser regression failed before the fix and passed after. Accepted and merged via PR #22; see merge evidence below.

## PR #22 merge and next task

Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge. Local main was fast-forwarded to that commit. No additional application changes were made while preparing the next spec.

**011 — Merged via PR #23**, Library / intent; [watchlist spec](specs/011_library_watchlist.md). Implements watchlist creation, permitted NotInterested-to-ToWatch transitions and explicit removal outcomes, preserves watched entries, and retains existing identity, lock and retention contracts. Rewatch, UI, Ratings and Recommendations changes are excluded. Focused verification: 39 tests/207 assertions; full CI: 253 tests/2,772 assertions, style and security checks passed. Owner approved merge; merged 21 October 2026, commit 4817bbe, after hosted CI passed.

**006s — Merged via PR #23**, Identity / guest lifecycle; [spec](specs/006s_expired_guest_error.md). UserGuest supplies GuestExpired after expiry; browser session resolution handles it while preserving cookie clearing and guest restart behaviour. Focused checks: 27 tests/139 assertions; full CI: 252 tests/2,769 assertions, style and security checks passed. Owner approved merge; merged 21 October 2026, commit 4817bbe, after hosted CI passed.

**012 — Merged via PR #24**, Library / dismissal; [spec](specs/012_library_dismissal.md). Implements creation/transition into NotInterested and explicit dismissal removal. Task 011 already supplies reconsideration into ToWatch. Watched entries remain protected; classification read contracts await a concrete consumer. Focused Library checks passed: 58 tests/330 assertions. Full CI passed: 272 tests/2,895 assertions, style and security checks clean. Owner approved merge; merged 21 October 2026, commit 78aba75, after hosted CI passed.

**013 — Merged via PR #27**, Ratings / presentations; [spec](specs/013_rating_presentations.md). Owns one RatingFilm per user/film, oldest-first batches and viewing-neutral dismissal. Library event consumption is task 017. Local ordering and retention approved; catalogue recognition/admission remains separate.

**001h — Merged via PR #25**, Foundation / architecture documentation; [spec](specs/001h_async_domain_design.md). Replaces synchronous-only coordination with asynchronous events across Library, Ratings and Recommendations. Delivery infrastructure is implemented in 001i; domain publishers/subscribers remain unimplemented.


**001i — Merged via PR #25**, Foundation / event delivery; [spec](specs/001i_durable_event_delivery.md). Implements durable outbox events and ordered subscriber receipts with GoodJob 4.22, after-commit notification wakeups and a recurring recovery sweep. Full local CI passed 292 tests / 3,020 assertions, style and security checks; process-kill recovery and concurrent delivery are covered. [Operations](domain_event_operations.md) documents connections, retry/status and retention. No domain subscriptions or deployment. Merge evidence below.

PR #25 review follow-up puts publishing-domain constants and inclusion validation on DomainEventStream and uses them in delivery tests. Full CI passed 294 tests / 3,027 assertions, style and security checks; 001i was subsequently merged via PR #25.

The subsequent database safeguard adds a publisher check constraint and validation-bypass coverage. Full CI passed 295 tests / 3,030 assertions, style and security checks. Publisher/subscriber specs must settle stream granularity, historical schema handling and bootstrap; compaction remains deferred pending usage evidence.

Dispatch discovery now fetches event/owner IDs together and checks event existence after locking the user. Concurrent cleanup coverage and full CI passed: 296 tests / 3,036 assertions, style and security checks. Task 001i was subsequently merged via PR #25.


## PR #25 merge and next task

Approved by the owner and merged via [PR #25](https://github.com/adambelton/glutton/pull/25) on 21 October 2026 at 16:16:38 UTC; squash commit `4a0943bcbc94573d6048c534a857388fdc416ff2`. Hosted Repository checks passed on head `cbb297642c092ec712d99574eadd3324e7955791` before merge. Local main was fast-forwarded to the merge commit. Final local CI passed 296 tests / 3,036 assertions, style and security checks.

**012a — Scope revised by owner**, Library / event publication; [spec](specs/012a_library_event_publication.md). The project has no existing entries, so baseline/bootstrap work was removed. Operations publish one v1 fact using shared event-name constants and explicit classifications.

Task **012a — Merged via PR #26**: Library operations publish versioned facts atomically; each operation supplies its resulting classification and uses shared event-name constants. [Spec and verification](specs/012a_library_event_publication.md); [publication contract](library_event_publication.md). Owner acceptance and merge are recorded below.

Foundation **001j — Merged via PR #26**: remove the product-domain allowlist from event streams, retain structural constraints and accept domain-owned publisher names. [Spec](specs/001j_domain_owned_publisher_names.md). Library task 012a adopts its own identifier after independent provider verification.

## PR #26 merge and next task

Accepted by the owner and merged via [PR #26](https://github.com/adambelton/glutton/pull/26) on 21 October 2026 at 16:49:30 UTC; squash commit `f4d911344a830b413fba9ea85aa2b44ce5b07a3e`. Hosted Repository checks passed on head `a703a329ec21302e2e57f8741f1e55e512715f73` before merge. Local main was fast-forwarded. Final local CI passed 301 tests / 3,175 assertions, style and security checks.

**013 — Merged via PR #27**, Ratings / presentations; [spec](specs/013_rating_presentations.md). Implements minimal candidate storage, oldest-first batch selection, boolean dismissal, concurrency and guest retention. Catalogue admission/recognition policy remains a separate prerequisite for the complete discovery feed; no global popularity ordering is assumed. Spec approved by the owner on 21 October 2026; implemented on `codex/ratings-presentations`. Owner review simplified this to one record and no seen/unseen question or presentation history. Revised verification is recorded in the spec. Owner accepted and merged via PR #27; see merge evidence below.

## Ratings simplification — 21 October 2026

Owner decision: offer rating or dismissal, without a separate seen/unseen question, dismissal reasons or presentation history. Dismissal only excludes automatic rating rotation and says nothing about viewing or recommendation interest. Library events must preserve it. Explicit rating initiated from Library is handled by targeted-entry task 019. Task 013 now uses one RatingFilm per user/film. This supersedes earlier unseen-response and presentation-history descriptions in this plan and the briefs.

Ratings-flow watchlist/not-interested actions (017a–017c) are deferred; they are not required for task 018. Those choices remain in Recommendations and Library. Task 018 owns rating/dismissal UI after rating persistence and Library-event projection; task 019 supplies explicit entry, including for dismissed films. No implementation of those later tasks is authorized here.

### Candidate batches — superseding queue policy

Owner approved one oldest-first queue for all persisted candidates, including future Library watched-event admissions and unfinished candidates from earlier sessions. Order by created_at then ID, excluding dismissal and (once task 014 exists) rows with ratings. Newly watched films do not jump ahead of older candidates. Task 013 stores only user, film, dismissed and standard timestamps; NextCandidates returns a read-only bounded batch. Task 014 owns has_many ratings, rated/unrated scopes and extending the existing pending scope to exclude rated rows. Catalogue replenishment will fill batch shortfalls under its separately agreed selection policy; existing user/film records are not recreated or reordered. Task 017 preserves existing dismissal and creation time on repeated admissions. Earlier watched-first/current-selection descriptions are superseded by this decision.

## PR #27 merge and next task

Owner accepted and merged [PR #27](https://github.com/adambelton/glutton/pull/27) on 21 October 2026 at 18:04:00 UTC (19:04 BST). Squash commit `69bfe2e5862bcd5cca65c77bb2e465e153a6c4e1`; hosted Repository checks passed on head `98598fb808229e10bf46ac98ac5f2ba1f9a8b371` before merge. Final local CI passed 320 tests / 3,270 assertions with clean style/security checks. Local main was fast-forwarded.

**014 — Merged via PR #28**, Ratings / ratings; [spec](specs/014_first_rating_submission.md). Implements first rating persistence, the has_many ratings relationship, rated/unrated/pending scopes and atomic v1 RatingSubmitted publication. Revision history/RatingRevised belongs to task 023; expressions remain 015. Spec approved on 21 October 2026; implemented on `codex/first-rating-submission`. Focused checks passed 37 tests / 319 assertions; full local CI passed 338 tests / 3,494 assertions with clean style/security checks. Application eager loading and whitespace checks passed. [Publication contract](ratings_event_publication.md). Owner accepted and merged via PR #28; see merge evidence below.

**001k — Merged via PR #28**, Foundation / event delivery; [spec](specs/001k_delivery_status_constants.md). Owner authorized named delivery-status constants and status-selection scopes alongside task 014, preserving storage and delivery contracts. Implemented and verified: focused delivery checks 25 tests / 158 assertions; combined full CI 339 tests / 3,497 assertions with clean style/security checks. Owner accepted and merged via PR #28; see merge evidence below.

## PR #28 merge and next task

Owner approved and merged [PR #28](https://github.com/adambelton/glutton/pull/28) on 21 October 2026 at 19:18:59 UTC (20:18:59 BST), squash commit `18454ac916f3f208eb2a113a674b0664fee1b278`. GitHub Repository checks passed on exact head `01201d1f10704bcfe2b5800938ea68fb36fbfea2` before merge. Local main was fast-forwarded.

**015 — Draft**, Ratings / expressions; [spec](specs/015_rating_expressions.md). Proposes optional original expressions saved atomically with the first rating and its unchanged v1 event. Review the proposed input bounds and blank/malformed-input handling. UI, editing and AI processing remain separate. Prepared on `codex/rating-expressions`; implementation has not started.

22 October 2026: recorded the [scoring design](ratings_scoring_design.md). Task 015 names the association `Rating#rating_expressions` and preserves original evidence for future scoring. RatingQuality and expression-profile processing remain later work; this documentation update does not start implementation.

**015 — Ready for review**, 22 October 2026. Owner approved the spec; implemented original RatingExpression persistence and atomic submission with unchanged v1 publication. Focused checks passed 46 tests / 429 assertions; full CI passed 348 tests / 3,607 assertions with clean style/security checks. Application eager loading and whitespace checks passed. Only the test database was migrated. [Spec and evidence](specs/015_rating_expressions.md). Owner acceptance and merge remain pending.

## PR #29 merge and next task

Owner approved and merged [PR #29](https://github.com/adambelton/glutton/pull/29) on 22 October 2026 at 10:25:39 UTC (11:25:39 BST), squash commit `a85db3d4f39f92dddfcadb34bda088fd496862ba`. Hosted Repository checks passed on exact head `94c426f4e1e3fe474aa7d1758b3947291bddafef` before merge. Local main was fast-forwarded.

**016 — Draft**, Library / rating-event consumer; [spec](specs/016_library_rating_consumer.md). Consume retained and new completed-rating facts, reconcile to watched, and publish actual changes atomically with delivery. No implementation started.

Task 023 owner clarification: replacement creates a new Rating with its own expressions and derived qualities, and atomically makes it current; currentness is derived from the highest Rating ID per RatingFilm without a stored flag. Preserve original evidence; enforce one current rating per RatingFilm and exclude superseded contributions from current preferences, including stale asynchronous work. Task 023 defines storage; revision events are deferred until a demonstrated consumer need.

**016 — Ready for review**, 22 October 2026. Owner-approved Library consumer establishes watched from completed-rating v1 facts, reconciles NotInterested, preserves public action failures and emits causal watched events only for actual changes. Existing delivery handles catch-up, retries and inactive-owner skips. Focused checks passed 96 tests / 714 assertions; full CI passed 364 tests / 3,740 assertions with clean style/security checks. Application eager loading and whitespace checks passed. No schema changes or deployment. [Spec and verification](specs/016_library_rating_consumer.md). Owner acceptance and merge remain pending.

## PR #30 merge and next task

Owner authorized merge after CI. [PR #30](https://github.com/adambelton/glutton/pull/30) merged on 22 October 2026 at 10:46:23 UTC (11:46:23 BST), squash commit `8aa83001b91187ce6af892246f65be5754f24624`. Hosted Repository checks passed on exact head `9e52547dc2e0597e248d135e145982ae1673fc9b` before merge. Local main was fast-forwarded.

**017 — Draft**, Ratings / Library-event consumer; [spec](specs/017_ratings_library_consumer.md). Revised after owner discussion: watched events find/create RatingFilm; not-interested events find/create and dismiss it using the existing dismissed attribute. No separate suppression storage, copied Library state or sequence watermark. Only these two events are subscribed to; later Library activity never clears dismissal. Explicit rating remains available through targeted entry. No implementation started.

Task 017 hold clarification: add a Ratings-owned held boolean for temporary exclusion, independent of indefinite dismissed. Subscribe to watched, not-interested, watchlist addition and watchlist removal. Watched/removal release holds; not-interested dismisses and releases any hold; no event clears dismissal. Pending becomes unrated, not dismissed and not held. Source-stream ordering is supplied by Foundation; no separate projection or sequence column. Explicit snooze UI, expiry and hold provenance remain deferred. This supersedes the earlier two-event/no-schema-change draft; see the revised spec. Implementation has not started.

**017 — Ready for review**, 22 October 2026. Owner-approved held state and four-event Ratings consumer implemented; watched/watchlist removal release holds, watchlist addition holds, and not-interested dismisses and releases. Original ratings, expressions, dismissal and queue position are preserved. Focused checks passed 151 tests / 1,345 assertions; full CI passed 384 tests / 4,010 assertions with clean style/security checks. Application eager loading and whitespace checks passed; existing-row migration verification passed. Only the test database migrated. [Spec and evidence](specs/017_ratings_library_consumer.md). Owner acceptance and merge remain pending.

**016a — Ready for review**, Library / event consumption; [spec](specs/016a_library_event_handler_namespace.md). Owner requested consistent handler organization. Moved the existing Library reaction to Library::EventHandlers::Ratings::RatingSubmitted; unchanged behaviour/subscriber identity. Existing delivery regressions passed 148 tests / 1,329 assertions; application eager loading, targeted style and whitespace checks passed. Repository instructions now require receiving domain / EventHandlers / publishing domain / event name.

**012b — Ready for review**, Library / event publication; [spec](specs/012b_library_event_payload.md). Removed classification from publish_event! and every Library event payload. Owner confirmed no historical data, so schema v1 is corrected in place without version compatibility or rewrites. Focused Library/Ratings/Foundation/job checks passed 148 tests / 1,329 assertions; targeted style and whitespace passed. No schema migration or deployment.

## PR #31 merge and next task

Owner authorized merge after CI. [PR #31](https://github.com/adambelton/glutton/pull/31) merged on 22 October 2026 at 12:06:57 UTC (13:06:57 BST), squash commit `4da49c223e974938f0a24bff10c89e6d65778b5f`. Hosted Repository checks passed on exact head `c0e7a0882d4ac1b90cf41e8505a7be66cbca678b` before merge. Final local CI passed 384 tests / 4,010 assertions with clean style/security checks. Local main was fast-forwarded.

**018 — Ready for review**, 26 October 2026, Ratings / browser flow; [spec](specs/018_ratings_browser_flow.md). Owner approved the existing-queue scope. Implemented localized rating/expression/dismissal forms with session ownership, explicit failures, protected writes and a home link. Focused checks passed 59 tests / 793 assertions; full CI passed 392 tests / 4,190 assertions with clean style/security checks. Application eager loading, whitespace and real browser keyboard walkthrough passed. Catalogue replenishment, first-time anonymous discovery and targeted Library entry remain deferred. Owner acceptance and merge pending.

**001l — Ready for review**, Foundation / dependency maintenance; [spec](specs/001l_crass_security_patch.md). PR #32 hosted CI detected GHSA-pq4g-8rxf-4g29 in crass 1.0.7. Updated only crass to 1.0.8. Refreshed advisory data and full local CI passed (392 tests / 4,190 assertions; style/security clean). Hosted verification and merge pending.

## PR #32 merge and next task

Owner authorized merge after CI. [PR #32](https://github.com/adambelton/glutton/pull/32) merged on 26 October 2026 at 08:57:13 UTC (GMT), squash commit `f2d8abbfbd2d3f2a335ba49c432904c804310b5a`. Hosted Repository checks passed on exact head `5340552cc874248a58bb84a5a0e2c97b678753bb` at 08:56:55 UTC. Local main was fast-forwarded. Final local CI passed 392 tests / 4,190 assertions with clean style/security checks after refreshing advisory data and patching crass.

**001l — Merged via PR #32**, Foundation / dependency maintenance. The isolated crass update to 1.0.8 resolves the hosted dependency-audit failure; no CI checks were bypassed.

**018 — Merged via PR #32**, Ratings / browser flow. Owner accepted the existing-queue UI and authorized merge after CI.

**019 — Ready for review**, Ratings / targeted entry; [spec](specs/019_ratings_targeted_entry.md). Supplies the Ratings destination for a user choosing “Rate this film” from Library. Entry uses the shared Film ID, bypasses automatic queue holds/dismissal, and admits a missing Ratings candidate only when a first rating is successfully saved. No Library watched prerequisite or model access; Library UI links remain task 020. Owner approved implementation on 26 October 2026. Implemented read-only targeted entry and atomic first submission with shared form/input handling. Focused checks passed 78 tests / 1,050 assertions; full CI passed 411 tests / 4,447 assertions with clean style/security checks. Eager loading, whitespace and browser/keyboard walkthrough passed. [Destination contract](ratings_targeted_entry.md). Owner acceptance and merge pending.

Task 019 owner review: consolidated rating entry into Ratings::RatingsController#new with optional film_id and one create action. Automatic selection retains queue eligibility; explicit selection bypasses holds/dismissal. Candidate dismissal remains separate. Updated provider destination documentation. Full local CI passed 412 tests / 4,451 assertions with clean style/security checks; application eager loading and whitespace checks passed. The earlier browser walkthrough predates the route consolidation; both modes were reverified through request tests. Ready for review.

Task 019 final controller simplification: new, create and dismiss now share Ratings::RatingsController. Removed CandidatesController and the Ratings base controller; moved status/error views with the workflow. Full CI passed 412 tests / 4,451 assertions, style/security clean; eager loading and whitespace passed. Ready for review.

Task 019 final admission decision: owner explicitly requested GET new(film_id:) to find/create RatingFilm before rendering. Unfinished candidates persist for the automatic queue. Create requires an existing owned rating_film_id and uses SubmitRating; removed SubmitFilmRating. Existing flags/timestamps and explicit duplicate failures remain. Focused tests passed 79 tests / 1,017 assertions; full CI passed 412 tests / 4,414 assertions, all style/security checks clean. Eager loading and whitespace passed. This supersedes prior read-only entry/submission-time admission descriptions. Ready for review.

Task 019 controller/service boundary follow-up: controller validates HTTP params, services load/validate entities, models retain domain permissions. Added FindCandidate for safe validation-error rendering; PrepareCandidate owns already-rated rejection. No controller entity queries remain. Full CI passed 416 tests / 4,438 assertions with clean style/security checks; eager loading and whitespace passed. Ready for review.

## PR #33 merge and next task

Owner authorized merge after CI. [PR #33](https://github.com/adambelton/glutton/pull/33) merged on 26 October 2026 at 10:15:01 UTC (GMT), squash commit `ec279e23ed17312900fac7ea32d6ed1a9c08f8d5`. Hosted Repository checks passed on exact head `8f2197dca066b36584e35813707593cabc92ca50` at 10:14:26 UTC. Local main was fast-forwarded. Final local CI passed 416 tests / 4,438 assertions with clean style/security checks, including the owner’s final controller edit.

**020a — Withdrawn after owner review**, Library / rating-event consumption; [spec](specs/020a_library_rating_status.md). Current Library consumption establishes watched but does not retain completed-rating status. The withdrawn draft proposed a Library-owned rated boolean maintained by the existing RatingSubmitted consumer. Owner rejected the premise that shared reads violate domain ownership. The proposal is withdrawn; task 020 reads authoritative Ratings data directly. No implementation was started.

**020 — Draft**, Library / watched view; [spec](specs/020_library_watched_view.md). Build the Watched films page, its home link and pagination. Each row shows title/year, Rated or Awaiting rating, and a Rate this film link for unrated films. Read rating status from Ratings-owned data; reuse the existing rating form. No duplicate rated flag, new subscriber or event replay. Documentation/specification only; implementation awaits approval.

## Mobile-first navigation — 26 October 2026

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. Ratings is the default landing destination; there is no separate product homepage.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library is one page. A labelled dropdown at the top selects Watchlist (the default), Watched or Not interested. Use the platform-native select on mobile; preserve the same control on desktop. Selection is reflected in the URL, so refresh, sharing and back/forward restore the selected view. A bare Library URL opens Watchlist; changing the view resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with roomier film rows; keep the Library dropdown above the list. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

This is the agreed navigation design, not a claim that every destination is implemented. Shared navigation/default-route wiring belongs to a narrowly scoped supporting UI task; Recommendations content and first-visit Ratings discovery still need their own implementations. Do not add dead links or invent placeholder product flows merely to complete the navigation. Task 020 supplies the Library page and its three read-only views; task 021/022 can add their respective management actions.

Task 020 draft revised to one Library page with three read-only dropdown selections. The previous separate watched page and homepage-link description is superseded. Shared responsive navigation/default-route wiring must be scoped as supporting UI work before implementation, without expanding Library ownership. No implementation started.

## PR #36 merge and next task

Owner authorized merge after CI. [PR #36](https://github.com/adambelton/glutton/pull/36) merged on 26 October 2026 at 13:13:30 UTC; squash commit `79e2a4cc30e9c1a5f35d56d37c3619022bac333d`. Hosted Repository checks passed on exact head `6468b2baa2475d937762e69f775a25668c7caa21` at 13:10:57 UTC. Final local CI passed 436 tests / 4,752 assertions with clean style/security checks. Local main was fast-forwarded.

**023 — Merged via PR #37**, Ratings / revisions; [spec](specs/023_rating_revisions.md). Implements full rating/expression replacement with preserved history, one current rating, stale-submission protection and no revision event publication. Revision events are deferred until a demonstrated consumer need. Owner approved the spec on 26 October 2026. Full local CI passed 452 tests / 4,930 assertions with clean style/security checks; migration, concurrency, retention and eager-loading checks passed. Browser editing is separately scoped as 023a; qualities and profile processing remain deferred. Implemented on `codex/rating-revisions`; accepted and merged via PR #37.

## PR #37 merge and next task

Owner authorized merge after CI. [PR #37](https://github.com/adambelton/glutton/pull/37) merged on 26 October 2026 at 14:26:22 UTC; squash commit `cbee7a2001a75fcbbc3bd4814d16b55529ab2cf5`. Hosted Repository checks passed at 14:25:37 UTC on exact head `a1bfa9ed6ccf41154e4e1f344287fb56edc83e33`. Final local CI passed 452 tests / 4,930 assertions with clean style/security checks. Local main was fast-forwarded.

**023a — Merged via PR #38**, Ratings / revision browser flow; [spec](specs/023a_rating_revision_browser.md). Owner approved 26 October 2026. Implements edit/update in the existing RatingsController, prefilled current expressions, stale-form protection and an edit link after first submission. Library links remain separately owned. Implemented on `codex/rating-revision-browser`. Full CI passed 460 tests / 5,081 assertions with clean style/security checks; eager loading, whitespace and mobile/desktop browser walkthrough passed. Full replacement also edits expressions; task 024 is covered by 023/023a. Owner accepted and merged via PR #38.


## PR #38 merge and next task

Owner authorized merge after CI. [PR #38](https://github.com/adambelton/glutton/pull/38) merged on 26 October 2026 at 15:14:48 UTC; squash commit `c3b1ebf114d50eff1422dde4e5c36cce3ffc5b6a`. Hosted Repository checks passed at 15:14:32 UTC on exact head `3b08f8b2a1da635accc261bb79d5b53d1e9d192c`. Full local CI passed 460 tests / 5,081 assertions with clean style/security checks. Local main was fast-forwarded.

**023b — Merged via PR #39**, Library / rating navigation; [spec](specs/023b_library_rating_edit_links.md). Add Edit rating links for rated watched films in the existing collection and detail pages using the established Ratings destination. Preserve unrated first-rating links, shared authoritative reads and model-owned action permissions. No Ratings changes or copied state. Implemented on `codex/library-rating-edit-links` after owner approval on 27 October 2026. Full CI passed 463 tests / 5,173 assertions with clean style/security checks; focused tests, eager loading, whitespace and mobile/desktop keyboard walkthrough passed. Owner accepted and merged via PR #39.

Task 024's original edit/remove-expression outcome is covered by the full replacement flow in 023/023a: unchanged expressions copy to the new rating, edits produce new evidence and cleared fields omit expressions, while original evidence is retained. No additional in-place expression editor is planned.


## PR #39 merge and next task

Owner authorized merge after CI. [PR #39](https://github.com/adambelton/glutton/pull/39) merged on 27 October 2026 at 08:09:56 UTC; squash commit `ead137008218a0baf988b98d799e4f9b46d9003a`. Hosted Repository checks passed at 08:09:37 UTC on exact head `95413ddb21966a19ef11e26ae4dfedd0a83f5434`. Local main was fast-forwarded. No further runtime changes were made after the verified implementation.

**025 — Ready for review**, Film knowledge / analysis design; [spec](specs/025_film_analysis_requirements.md). Owner requested documentation and approved task execution on 27 October 2026; the documentation deliverable is finalised. The previous vocabulary-persistence draft is superseded without implementation. [Requirements](film_analysis_requirements.md) define experiential analysis, completeness, claim-level corroboration and complementary evidence, reported individual experiences, source independence/conflicts, source-use evaluation and future independently reviewed community revisions. Qualities require preference relevance, transferability, discrimination and reliable identification; artistic execution alone does not justify them. Format-evolution requirements preserve raw user evidence and identify downstream reassessment needs without prescribing processing contracts. The future feedback cycle uses eligible original user expressions to propose independently reviewed analysis improvements; derived scores are not new evidence. Feedback implementation and contribution policies remain deferred. Constructed examples exercise the rubric; task 026 now supplies a separately scoped real-film pilot and provisional refinements. Production provider coverage remains unverified.

Sequence: define requirements → separately scope source evaluation and a small analysis pilot → implement/validate the pipeline → expand to the intended 500-film catalogue → derive/review shared qualities and dimensions. Metadata starts with TMDB identity import. The original 50-film research dataset remains exploratory. No pipeline, quality model, film imports, AI calls or community workflow implementation is included in task 025. Owner acceptance and merge pending.


**026 — Ready for review — evidence-depth revision 2**, Film knowledge / analysis evaluation; [spec](specs/026_film_analysis_pilot.md). Owner selected Bone Tomahawk, Terrifier, The Babadook, Alien and Scream and authorised the research pilot on 27 October 2026. [Report and drafts](research/analysis_pilot/README.md) evaluate experiential requirements against real sources. Five source-based drafts, an eight-candidate comparison and rubric identify refinements to claim scope and evidence status. Local links/anchors, draft structure/source references and whitespace checks passed. Task 025 remains provisional pending pilot review; no independent curator acceptance or predictive validation is claimed. No runtime implementation or database imports.

Owner review of 026 found the initial drafts too minimal and conclusion-focused. The approved revision is delivered: five dossiers with chronological narratives and contextual key moments before synthesis, 32 sources across 33 URLs, source corrections and retained evidence gaps. Local reference/structure and whitespace checks passed; evidence-depth acceptance remains with the owner. No runtime scope is added.

**026a — Ready for review**, Supporting architecture / design documentation; [spec](specs/026a_comparison_and_history_design.md). Records the podcast flow, three comparison layers, viewer-independent analysis, timestamped historical validity, retained film/rating qualities, analysis-only activation and self-explanatory quality names. Ratings remain immediately submitted; future persistence changes do not rewrite the historical implementation evidence in task 023. Documentation checks are recorded in the spec.

**027 — Ready for review**, Film knowledge / analysis evaluation; [spec](specs/027_comparison_ready_analysis_pilot.md). Repeat the same five-film pilot against the comparison and history decisions, preserving task 026 as baseline. Test addressable evidence, versioned film-quality associations and an illustrative activation/supersession timeline. Clearly labelled expression probes test evidence usability, not real host reactions or recommendation accuracy. Owner approved the run on 27 October 2026. Delivered five revision-3 dossiers, twenty associations, fifteen manual probes and thirteen checked illustrative historical selections; all six baseline files remain byte-identical. Evidence links and whitespace checks passed. [Report](research/comparison_pilot/README.md). Actual engine/profile/review comparison requires later domain-owned work and real inputs; no scores or independent film acceptance are claimed.

## V1 analysis closeout — 27 October 2026

Tasks 025, 026, 026a and 027 are complete documentation/research deliverables, ready for review. The owner authorised a PR and merge after CI. The final V1 workflow is an author-neutral draft, editable quality candidates and atomic activation resolving/creating qualities and retaining historical associations. Activation supplies V1 approval; community multi-person verification and expression feedback remain future work. Recommendations will own persisted recommendation-quality score contributions and totals rather than relying on reconstruction across domains. Ratings remains immediate on submission. These decisions add no runtime implementation or new domain communication.

Next: a bounded Film knowledge draft/activation persistence spec after merge. It will not include AI/provider integration, downstream scoring, browser UI or the 500-film import. No further pilot is a prerequisite.

## PR #40 merge and next task

Owner authorised merge after CI. [PR #40](https://github.com/adambelton/glutton/pull/40) merged on 27 October 2026 at 11:58:21 UTC, squash commit `254a87d723244235a7c6894742b1939041761247`. Hosted Repository checks passed on exact head `46873e53c51a1aed48551f63d65dc09e384bbfce` at 11:57:44 UTC. Local main was fast-forwarded. Tasks 025, 026, 026a and 027 are merged documentation/research deliverables; no production analysis or scoring implementation is implied.

**028 — Draft**, Film knowledge / analysis lifecycle; [spec](specs/028_film_analysis_lifecycle.md). Persist editable analysis drafts and quality candidates, resolve/create shared qualities and activate associations atomically, preserving history and rejecting stale competing activation. Domain operations/storage only; AI generation, UI, downstream scoring, new domain communication and catalogue expansion are excluded. Prepared on `codex/film-analysis-lifecycle`; implementation awaits owner approval.

**027a — Ready for review**, Film knowledge / analysis design; [spec](specs/027a_versioned_analysis_prompt.md). Added the first [saved analysis prompt and API run protocol](prompts/film_analysis/README.md). Future AI analyses use the OpenAI Responses API with recorded inputs and outputs. Narrative and moment counts follow the film rather than a fixed outline. No API generation or task 028 implementation performed; the earlier pilot provenance gap remains explicit.

**001m — Ready for review**, Foundation / observability; [spec](specs/001m_langfuse_tracing.md). Configured official OpenAI Ruby client and isolated Langfuse OTLP export. A real bounded diagnostic request and CLI trace audit passed; full single-worker CI passed 469 tests / 5,225 assertions with clean style/security checks. [Setup and trace evidence](ai_configuration.md). No film analysis runner or task 028 implementation.

**027b — Ready for review**, Film knowledge / prompt management; [spec](specs/027b_langfuse_analysis_prompt.md). Published film-analysis v1 to Langfuse with development label, verified exact retrieval and a real generation linked to the prompt version. Initial publication and linkage checks completed. Owner follow-up removes the local prompt and publisher: Langfuse owns editable versions; the check script and immutable per-run provenance remain. No analysis pipeline or task 028 implementation.
