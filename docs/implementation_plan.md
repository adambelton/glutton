# Glutton — Initial implementation plan

Status: Tasks 001, 001a and 002 ready for review; later tasks planned  
Date: 19 October 2026

## Task rules

Each task has **one owning domain, one small outcome, and independent verification**. Before implementation, write its spec from [the template](task_template.md), with scope restrictions and acceptance criteria including verification methods/results. Specs exist for tasks 001, 001a and 002; task 002 uses STI and derived expiry and is ready for review; owner acceptance and merge remain pending.

If work appears to require changes in multiple domains, **review the boundary first**. Ask whether ownership is wrong, an invariant needs one owner, or responsibilities are too tightly coupled. Do not mechanically split a poor boundary into provider/consumer tasks. Agree cross-domain contracts before implementation, including inputs, results and failure behaviour. Implement and test each side in its own task: the provider first, then the consumer against the established contract. Calling another domain is allowed; changing its implementation is not. Review ownership when a contract exposes misplaced rules or unnecessary coupling.

Use statuses `Draft`, `In progress`, `Ready for review`, `Accepted`, `Merged`; note blockers explicitly. Record actual changes and evidence in the spec. Owner acceptance and merge are separate from checks passing. Spec creation alone does not start implementation, and this plan does not authorise the whole list.

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

CI follow-up: **001b — Ready for review**, Foundation; [spec](specs/001b_github_ci.md). Run the existing repository checks on GitHub pull requests and main pushes.

## First rating and library slice

Candidate task boundaries; write each detailed spec just before starting, splitting further if needed. IDs 002 onward replace the earlier unimplemented sequence.

| Task | Owner / capability | Independently verifiable outcome | Depends on | Status |
| --- | --- | --- | --- | --- |
| 002 | Identity / accounts | Email-free guest identity with fixed 24-hour expiry | 001 | Ready for review — [spec](specs/002_identity_accounts.md) |
| 003 | Identity / guest sessions | Browser-session guest access with server-enforced expiry and identity isolation | 002 | Planned |
| 004 | Identity / credentials | Registered-account credential invariants and atomic in-place claim of an active guest; preserve ID and reject expired/duplicate claims | 002 | Planned |
| 005 | Identity / registered sessions | Password sign-in, session rotation, current guest/registered identity and sign-out; no automatic guest merge | 003, 004 | Planned |
| 006 | Identity / delivery | Resend configuration and local verification/reset mail previews; no real mail by default | 004 | Planned |
| 006a | Identity / registration | Registration form starts guest claim with email/password; preserves ID/activity, handles errors and limits requests; completion requires 006b | 005 | Planned |
| 006b | Identity / verification | Required email confirmation completes registration; expiring tokens, resend limits and pending/expired claim handling; entered email alone never grants access | 006, 006a | Planned |
| 006c | Identity / recovery | Expiring password-reset flow with request limits and agreed session invalidation | 005, 006 | Planned |
| 006d | Identity / guest retention | Scheduled cleanup of expired guest identities; recheck claim state and specify retry behaviour | 003, 004 | Planned — activity deletion ownership must be resolved before implementation |
| 007 | Film knowledge / catalogue | Minimal film identity/metadata persistence and local sample | 001 | Planned |
| 008 | Film knowledge / import | Import one selected TMDB identity with deduplication | 007 | Planned |
| 009 | Film knowledge / search | TMDB search returns disambiguated selection data | 008 | Planned |
| 010 | Library / viewing | Canonical user–film entry and mark-watched operation/read result | 005, 007 | Planned |
| 011 | Library / intent | Watchlist addition/removal, retaining independent watched facts | 010 | Planned |
| 012 | Library / dismissal | Not-interested/reconsideration operations and classification reads | 011 | Planned |
| 013 | Ratings / presentations | Own next-film selection, presentation/seen/unseen history and suppression; expose an idempotent make-available-for-rating operation that overrides earlier unseen suppression | 005, 007 | Planned |
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

The revised Identity sequence replaces magic-link tasks. Guest expiry is fixed at creation plus 24 hours; browser closure is not a reliable expiry signal. Registered-session duration remains undecided. Task 002 provides STI `User`/`GuestUser` persistence, an inactive `DeletedUser` subtype and polymorphic `active?`, deriving the deadline from `created_at` without a stored expiry. Registered subclass, deletion transitions and domain capability modules arrive with their own behaviour; admin permissions remain separate. Task 003 establishes session-bound guest access; task 004 introduces credentials and the claim transition; task 005 exposes both identity modes. The ratings-first entry and first-save guest creation belong in the later Ratings UI task using the established Identity contract. No product UI is added by task 002.

Guest cleanup must eventually remove associated activity as well as the identity. Task 006d is not authorization to modify other domains or invent deletion contracts mechanically: review ownership and define domain-owned deletion work as those records are introduced. Cleanup must not delete a concurrently registered account. Treat complete guest retention behaviour as a release requirement; do not claim it is implemented by the expiry predicate.

Task 010 provides Library's idempotent record-watched contract without calling Ratings. Task 013 provides Ratings' make-available contract, and task 014 provides its current-rating read contract. Agree each contract's inputs, results and failures before implementing it. Tasks 016 and 017 implement the separate consuming sides; they do not modify their providers. Neither task introduces events, background delivery or a generic integration layer.

Tasks 011 and 012 define intent/dismissal transitions without recommendation logic. Task 013 owns selection and presentation history independently of Library. Task 014 owns current-submission invariants before revision UI arrives. A seen response without a saved rating creates no Library classification and therefore does not exclude recommendations. Task 017 checks Ratings' current-rating result so marking an already-rated film watched does not requeue it.

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
