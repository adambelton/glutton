# Glutton — Implementation progress

Updated: 4 November 2026. This document describes current progress, agreed order and next work. GitHub holds PR, commit, CI and delivery history; completed task records are not retained here.

## Current progress

- Foundation: Rails/PostgreSQL/Hotwire, English locale conventions, hosted/local CI with refreshed security advisories, durable asynchronous domain-event delivery and explicit observability integration are implemented. Production deployment and scheduling remain decisions to make.
- Identity: guest/registered identities, revocable sessions, browser sign-in/out, registration/confirmation, password recovery and bounded expiry cleanup are implemented. Minimal superuser permission and explicit grant/revoke operations restricted to existing superusers are implemented.
- Registry: canonical film storage, TMDB search and complete metadata/Wikipedia import, editable quality categories and direct film-quality associations are implemented. The one-time plain-YAML seed loads 235 quality definitions and nine category defaults; names/IDs are used without separate keys. Initial per-film quality assignment, create-only loading orchestration and bounded warning-isolated batch entry points are implemented; actual catalogue execution and web entry-point wiring remain to build.
- Library: Watchlist, Watched and Not interested browsing/details/actions are implemented, with authoritative shared reads for current rating status and the agreed event reactions.
- Ratings: candidate queue, dismissal/holds, first submission with original expressions, rating replacement/history, browser editing and targeted Library entry are implemented.
- Personal preference processing/scoring and recommendation selection/ranking/explanations remain to build. Historical research is not evidence of validated prediction accuracy.

## Current work

- Registry, Identity, Library and Ratings namespaces are implemented. The final Foundation delivery namespace task is implemented and in review. Catalogue inspection stays deferred until this final namespace change is merged.
- [Catalogue inspection](tasks/catalogue_inspection.md): prepared draft, deferred until the remaining domain model namespaces are complete. Registry will own superuser-only, read-only film/category/quality lists and details, related-record navigation and stored source/evidence display. Identity's superuser prerequisite is implemented. Editing, imports, source refresh and provider execution remain excluded; bulk catalogue execution still requires an explicit film list and provider budget.
- [Deterministic quality-change suggestions](tasks/deterministic_quality_suggestions.md): deferred draft for the later refresh/evaluation stage. Initial assignment may use the agreed selection arithmetic without implementing this suggestion product first.

## Model namespace migration order

Registry, Identity, Library and Ratings are complete. Foundation delivery is the final namespace outcome; its models share the existing DomainEvents namespace with their services. All retain existing tables/IDs and behaviour. The undeployed Identity migration intentionally invalidates old confirmation/reset links; newly issued links and existing signed-in sessions retain their agreed rules. Catalogue inspection follows the final namespace migration.

## Delivery order

The agreed order is seed first:

1. **Load the initial seed:** persist/load the quality vocabulary and definitions, retain category defaults, import canonical films from TMDB, enrich with Wikipedia context and assign initial qualities under the chosen 60%/category-cap baseline. Initial assignment is part of making seed data usable; it does not depend on a refresh-suggestion product or per-film human approval.
2. **View canonical content:** admin-only film, quality-category and quality lists/detail pages, including source context, associations and navigation between related records. Admin authorisation must protect these screens. Viewing comes before editing.
3. **Manual editing:** add admin operations/forms for quality definitions (names immutable), category settings and film-quality additions/removals. Reuse the accepted-record operations later; no change-evaluation workflow is a prerequisite for an explicit manual edit.
4. **Manual source refresh:** refresh TMDB/Wikipedia data from the canonical film screen and show outcomes/provenance. Source refresh alone changes no accepted film qualities.
5. **Evaluate potential changes:** wire JEV quality checks into the manual-refresh flow, show suggested differences and allow explicit application using the manual-editing operations. Retain immutable FilmQualityEval evidence; proposed differences need no separate suggestion queue/history model.
6. **After initial release:** inspect user expressions to discover missing qualities/category preferences and test vocabulary improvements. This admin discovery tool is deferred; ordinary expression interpretation/scoring for viewer preferences remains in release scope.

Bulk seed and ordinary missing-film imports will share canonical enrichment/initial-assignment behaviour. Scheduled sync is later work, not a prerequisite. Core expression interpretation/scoring stays in release scope; expression-led vocabulary discovery is post-release.

## Working-record lifecycle

Use the [task template](task_template.md) to constrain scope and verify an independently testable outcome before/during implementation. Amend the same record for review corrections and implementation refinements. Preserve each domain's mutation ownership and original experiment limits.

When preparing a PR, use the record to write the PR description: final behaviour/scope, checks actually run, outcomes and material limitations. Update maintained documentation to reflect current progress/decisions and remove the task record as part of the PR. Continue review, CI, approval and merge evidence on GitHub. Do not create a completed-task archive, retired-ID map, PR ledger or duplicated CI history.

Routine progress needs no task or PR citation. Only cite a PR when a specific piece of evidence or decision actually needs its origin explained. Prefer a current domain/design document when explaining current behaviour. A new record needs a distinct owned outcome, not another review round or publication step.

## Domain ownership

| Owner | Responsibilities | Boundary |
| --- | --- | --- |
| Registry | Film identity, TMDB search/import, metadata/media references, source context, editable quality categories/vocabulary and accepted film associations | Shared film knowledge independent of viewers |
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
- Source-backed film information/qualities are directly accessible with spoiler-labelled navigation normally from watched Library; access does not require watched status. Film owns current source context and direct quality associations; the former analysis models are retired.

## Agreed navigation

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. Ratings is the default landing destination; there is no separate product homepage.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library is one page. A labelled dropdown at the top selects Watchlist (the default), Watched or Not interested. Use the platform-native select on mobile; preserve the same control on desktop. Selection is reflected in the URL, so refresh, sharing and back/forward restore the selected view. A bare Library URL opens Watchlist; changing the view resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with roomier film rows; keep the Library dropdown above the list. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

This is the agreed navigation design, not a claim that every destination is implemented. Shared navigation/default-route wiring belongs to a narrowly scoped supporting UI task; Recommendations content and first-visit Ratings discovery still need their own implementations. Do not add dead links or invent placeholder product flows merely to complete the navigation. Library browsing and its management actions are implemented; Recommendations and shared primary navigation remain separately scoped work.

## Future Ratings evaluation work

Within the later Ratings scoring implementation, add RatingQualityEval records and link generated RatingQuality results to their originating evaluation. Distinguish profile-based interpretation from direct expression evidence; capture exact input/profile/definition versions, ordered calls/questions/responses, probabilities, deterministic processing and application outcomes. Retain historical results, reject stale work and replace contributions without double counting. Profile-only changes do not replace directly expressed evidence. Preserve Ratings ownership and the existing [scoring design](ratings_scoring_design.md); this is a future scoped outcome, not a new working task or implemented schema.

Expression-profile updates require an LLM call; no JEV gate is assumed. JEV evaluates rating qualities against profiles or explicit expressions. Application evidence belongs in the database, with optional Langfuse diagnostic links. Do not introduce a generic cross-domain evaluation table/framework.

## Release follow-up

Complete the seed-first sequence above before later admin improvements. Admin viewing requires authorisation before exposure; manual source refresh changes no accepted qualities. Source/association changes do not themselves authorise downstream score mutations. Community editing, scheduled syncing, streaming integrations and speculative extra event consumers are not prerequisites.

Final production hosting, scheduler installation and account/activity-retention decisions remain explicit follow-up work. Shared reads of authoritative records are allowed; cross-domain writes require the owning workflow and agreed durable events. Product/architecture briefs and domain contracts retain the detailed requirements.
