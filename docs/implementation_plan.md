# Glutton — Initial implementation plan

Status: See current implementation status below for merged work, changes awaiting review and planned capabilities.  
Date: 20 October 2026

## Current implementation status

This section summarizes current delivery status; task tables and linked specs retain detailed outcomes and historical verification.

| Area | Current status |
| --- | --- |
| Foundation | Tasks 001b–001e merged; original scaffold tasks 001/001a retain their recorded Ready for review status. Audit 001f is Ready for review. Documentation follow-up 001g is Ready for review. |
| Identity | Tasks 002–006 and their delivered follow-ups through 006n merged. Authentication serialization 006o and confirmation simplification 006p are Ready for review. |
| Film knowledge | Catalogue 007, TMDB import 008, search 009 and outcome-test follow-up 009a merged. Boundary consistency 009b is Ready for review. |
| Library | Watched operation 010 and guest-duration tests 010a merged. Watchlist/dismissal management and product UI remain planned. |
| Ratings and Recommendations | Planned; no implementation delivered. |

## Task rules

Each task has **one owning domain, one small outcome, and independent verification**. Before implementation, write its spec from [the template](task_template.md), with scope restrictions and acceptance criteria including verification methods/results. Specs exist for tasks 001, 001a, 001b, 002, 003, 004, 004a, 005, 005a, 005b and 006. Tasks 001b, 002 and 003 were accepted by the owner and merged via PRs #3, #1 and #2 respectively. Task 004 was accepted by the owner and merged via PR #4. Task 004a was accepted by the owner and merged via PR #5. Task 005 was accepted by the owner and merged via PR #6 without waiting for queued hosted CI, as explicitly authorized. Tasks 005a and 005b were accepted by the owner and merged via PRs #8 and #7. Task 006 and Foundation follow-up 001c were accepted and merged via PR #9 after hosted CI passed; both live mail templates were received.

If work appears to require changes in multiple domains, **review the boundary first**. Ask whether ownership is wrong, an invariant needs one owner, or responsibilities are too tightly coupled. Do not mechanically split a poor boundary into provider/consumer tasks. Agree cross-domain contracts before implementation, including inputs, results and failure behaviour. Implement and test each side in its own task: the provider first, then the consumer against the established contract. Calling another domain is allowed; changing its implementation is not. Review ownership when a contract exposes misplaced rules or unnecessary coupling.

Use statuses `Draft`, `In progress`, `Ready for review`, `Accepted`, `Merged`; note blockers explicitly. Record actual changes and evidence in the spec. Owner acceptance and merge are separate from checks passing. Spec creation alone does not start implementation, and this plan does not authorise the whole list.

Tasks 001d/006e were accepted and merged via PR #10 after hosted CI passed. Task 006a was accepted and merged via PR #11 after hosted CI passed; task 006b was accepted and merged via PR #12 after hosted CI passed: registration now proceeds through pending persistence, confirmation/claim capability (006b), then HTTP wiring (006f). Task 006f was accepted and merged via PR #13 after hosted CI passed. Task 006c password recovery was accepted and merged via PR #14 after hosted CI passed; owner confirmed browser completion. Task 006d bounded Identity retention cleanup was merged via [PR #15](https://github.com/adambelton/glutton/pull/15) on 19 October 2026; merge commit `74d0cfbc859d7cf6d7b05c5cf61ef776df32d7d6` was verified against GitHub on 20 October 2026. Local verification evidence remains in its spec.

## Domain ownership

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
- Ratings does not require a Library watched record to accept a rating. Confirming seen alone stays in Ratings; a completed rating synchronously records watched through Library.
- Ratings selects the next film from its own queue/presentation state. Library's user-facing mark-watched workflow synchronously requests rating eligibility; a previous unseen response must not prevent this. Recording watched after a completed rating must not trigger that request again.
- Cross-domain communication uses a few explicit synchronous contracts, not events or asynchronous jobs. Each provider and consumer has its own task and tests. Specify rollback/retry behaviour before implementing each consumer; do not assume separate domain writes are automatically atomic. This decision does not remove deferred AI assessment work.
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
| 011 | Library / intent | Watchlist addition/removal, retaining independent watched facts | 010 | Planned |
| 012 | Library / dismissal | Not-interested/reconsideration operations and classification reads | 011 | Planned |
| 013 | Ratings / presentations | Own next-film selection, presentation/seen/unseen history and suppression; expose an idempotent make-available-for-rating operation that overrides earlier unseen suppression | 005a, 007 | Planned |
| 014 | Ratings / ratings | Save a four-level rating based on Ratings' seen confirmation; expose current-rating result and establish submission/history invariants without requiring Library state | 013 | Planned |
| 015 | Ratings / expressions | Save multiple optional original expressions atomically with a rating submission | 014 | Planned |
| 016 | Ratings / Library contract consumer | On completed rating, synchronously invoke Library's existing record-watched operation; test agreed success, rollback and retry behaviour without requeueing | 010, 015 | Planned |
| 017 | Library / Ratings contract consumer | User mark-watched workflow synchronously invokes Ratings' make-available operation; test earlier unseen, already-rated and repeated requests | 010, 013, 014 | Planned |
| 018 | Ratings / rating flow | Cycling seen/unseen and rating UI, including direct watchlist action through the existing Library contract | 011, 016 | Planned |
| 019 | Ratings / targeted entry | Open a specified film for rating using Ratings' state, including films made available by Library; no Library watched-record prerequisite | 017, 018 | Planned |
| 020 | Library / watched view | Distinguish awaiting-rating/rated using Ratings' current-rating result; link to targeted rating | 014, 019 | Planned |
| 021 | Library / watchlist view | To watch list with existing mark-watched workflow and rating entry point | 011, 017, 019 | Planned |
| 022 | Library / dismissed view | Not interested list with reconsideration | 012 | Planned |
| 023 | Ratings / revisions | Re-rate while retaining agreed history and superseding the current submission | 016, 019 | Planned |
| 024 | Ratings / expression revisions | Edit/remove expressions with clear retention and revision semantics | 015, 019 | Planned |

The revised Identity sequence replaces magic-link tasks. Guest expiry is fixed at creation plus 24 hours; browser closure is not a reliable expiry signal. Registered sessions follow Rails authentication conventions with no application-imposed TTL. Task 002 provides STI `User`/`GuestUser` persistence, an inactive `DeletedUser` subtype and polymorphic `active?`, deriving the deadline from `created_at` without a stored expiry. Registered subclass, deletion transitions and domain capability modules arrive with their own behaviour; admin permissions remain separate. Task 003 establishes session-bound guest access; task 004 introduces registered credential invariants; task 006b owns the confirmed claim transition; task 005 supplies shared guest/registered session lifecycle and registered authentication and task 005a exposes both identity modes through HTTP. Registered sessions end through sign-out/revocation or inactive-account rejection, not a custom age deadline. The ratings-first entry and first-save guest creation belong in the later Ratings UI task using the established Identity contract. No product UI is added by task 002.

Guest cleanup must remove associated activity as well as the identity. Task 010 covers Library activity through its approved scoped user foreign-key cascade, with existing Identity cleanup/claim compatibility verified; other domains require their own retention decisions before persistence. Task 006d is not authorization to modify other domains or invent deletion contracts mechanically: review ownership and define domain-owned deletion work as those records are introduced. Cleanup must not delete a concurrently registered account. Treat complete guest retention behaviour as a release requirement; do not claim it is implemented by the expiry predicate.

Task 010 provides Library's record-watched contract (already-watched entries raise Library::AlreadyWatched) without calling Ratings. Task 013 provides Ratings' make-available contract, and task 014 provides its current-rating read contract. Agree each contract's inputs, results and failures before implementing it. Tasks 016 and 017 implement the separate consuming sides; they do not modify their providers. Neither task introduces events, background delivery or a generic integration layer. Their specs must define handling of AlreadyWatched explicitly; repeated transition calls are not successful no-ops.

Task 010 includes the minimal ToWatch subtype and watched transition; tasks 011 and 012 define the remaining intent/dismissal transitions without recommendation logic. Task 013 owns selection and presentation history independently of Library. Task 014 owns current-submission invariants before revision UI arrives. A seen response without a saved rating creates no Library classification and therefore does not exclude recommendations. Task 017 checks Ratings' current-rating result so marking an already-rated film watched does not requeue it.

Each consuming task verifies real provider compatibility as well as failure handling. A failed save must not appear rated, and a watched action must not imply a completed rating. Decide the concrete synchronous consistency mechanism in the relevant spec before implementation; retain ownership of writes in the providing domain.

All private operations include checks against accessing another user's records, including other guests, and reject expired guest access. Early domain operations can be verified with representative records and existing contracts; they need not wait for every user interface.

## Later milestones — not implementation tasks

Break down only when approaching each milestone. Domain/capability ownership below replaces the former Taste/Discovery split.

- **Film knowledge:** media enrichment, reviewed trailer data, versioned sourced analyses, quality vocabulary and film associations. Analysis pages are directly accessible with clear spoiler labelling; normal navigation is from the watched Library view. No watched authorization contract is needed.
- **Ratings / analysis:** benchmark JEV scoring contracts and cost against labelled expressions and ratings.
- **Foundation:** configure durable jobs when first needed; domain-specific processing rules remain with their domain.
- **Ratings / scoring:** capture pre-submission expressions profile, separate implicit/explicit evidence and handle stale/duplicate assessments.
- **Ratings / profile building:** explicit-only synthesis and assessment of meaningful changes; evaluate JEV gate and Claude usage.
- **Ratings / preferences:** aggregate completed evidence and expose a preference result for recommendation consumption.
- **Ratings / reassessment:** historical reinterpretation, scheduling and freshness, divided into small tasks. Original input and inference remain distinct inside the domain.
- **Recommendations / selection:** apply eligibility rules to Library classifications; do not infer exclusion merely from rating/recommendation history.
- **Recommendations / ranking:** rank eligible films against a defined Ratings preference result.
- **Recommendations / presentation:** record each presented suggestion and explanation, with film media from Film knowledge.
- **Recommendations / responses:** retain response history and invoke existing Library operations for watchlist, watched and dismissal. Implement/test Library providers and Recommendation consumers in separate tasks; define synchronous failure and retry behaviour before implementation.
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

**001f — Ready for review**, Foundation / repository review; [spec](specs/001f_codebase_audit.md), [audit report](audits/2026-10-20_codebase_audit.md). Audited freshly pulled main at `3cd3034e0e48fe04648c8a36c4e1d0028a622270`. The audit recorded one reproduced Identity sign-in/password-reset race and three maintainability/documentation observations; task 001f itself made no application changes. Existing tests, style, application eager loading and Brakeman passed. The separately scoped remediation tasks below are now Ready for review; owner acceptance and merge remain pending.

## Audit remediation and confirmation simplification — 20 October 2026

The owner authorized implementation after reviewing audit 001f and discussing Identity complexity. Each task has one owner; no cross-domain contract changes are needed.

| Task | Owner | Outcome | Status |
| --- | --- | --- | --- |
| [006o](specs/006o_authentication_reset_serialization.md) | Identity / sessions | Serialize sign-in with password recovery (A1) | Ready for review |
| [006p](specs/006p_confirmation_orchestration.md) | Identity / registration | One confirmation coordinator and shared access rule (A2) | Ready for review |
| [009b](specs/009b_tmdb_boundary_consistency.md) | Film knowledge / provider boundary | Shared date parsing and search parameter rules (A3) | Ready for review |
| [001g](specs/001g_current_documentation.md) | Foundation / documentation | Consistent current summaries and open decisions (A4) | Ready for review |

Submission/delivery orchestration, broad Identity rewrites and release infrastructure remain outside this change. Owner acceptance and merge are pending.

Verification for 006o/006p/009b/001g: full local CI passed 232 tests / 2,633 assertions, zero failures/errors/skips; RuboCop 127 files clean; dependency audits clean; Brakeman zero warnings/errors. Application eager loading and whitespace checks passed. Individual specs record commands, initial regression failure and limitations. No hosted CI or merge performed.
