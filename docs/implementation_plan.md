# Glutton — Implementation progress

Updated: 8 November 2026. This document describes current progress, agreed order and next work. GitHub holds PR, commit, CI and delivery history; completed task records are not retained here.

## Current progress

- Foundation: Rails/PostgreSQL/Hotwire, English locale conventions, hosted/local CI with refreshed security advisories, durable asynchronous domain-event delivery and explicit observability integration are implemented. Ratings and Registry share a TypeSafe client with domain-specific limits and trace settings. Production deployment and scheduling remain decisions to make.
- Identity: guest/registered identities, revocable sessions, browser sign-in/out, registration/confirmation, password recovery and bounded expiry cleanup are implemented. Minimal superuser permission and explicit grant/revoke operations restricted to existing superusers are implemented.
- Registry: canonical film storage, TMDB search and complete metadata/Wikipedia import, editable quality categories and direct film-quality associations are implemented. The one-time plain-YAML seed loads 235 quality definitions and nine category defaults; names/IDs are used without separate keys. Initial per-film quality assignment, create-only loading orchestration and bounded warning-isolated batch entry points are implemented; superuser-only read-only catalogue inspection is implemented; import/edit/refresh web entry points and bulk catalogue execution remain to build.
- Library: Watchlist, Watched and Not interested browsing/details/actions are implemented, with authoritative shared reads for current rating status and the agreed event reactions. The Watched list preloads rated records by viewer and film so Library film subtypes can determine the available rating actions.
- Ratings: candidate queue, dismissal/holds, first submission with original expressions, rating replacement/history, browser editing and targeted Library entry are implemented.
- Ratings saves original expressions on submission. Applying an evaluation writes a complete set of rating qualities linked to that evaluation, with explicit scores or baseline scores as applicable. Explicit scores follow the overall rating’s direction. Ratings can run a bundled explicit assessment, then record and apply its scores. Ratings without expressions use a deterministic baseline. Submission and revision now durably schedule assessment of the saved rating version on a dedicated Ratings queue. This is ready for review with stubbed-provider verification. Queue activation, profile scoring, recommendation selection, ranking and explanations remain open.

## Current work

- **Application and test audit handoff.** The [8 November audit](audits/2026-11-08_application_and_test_audit.md) records the original findings. Scoped remediation covers the targeted Ratings form, Library and Identity model actions, shared provider transport and tracing, and regression coverage for browser interactions. Chrome also exposed a shared hidden-field parameter defect that affected Ratings dismissal. Repository CI now includes the browser suite and a Rails autoload check.

- **Development event worker.** bin/dev runs the event-only worker with Rails and manages shared shutdown. Existing 12 queued rating submissions have converged to Library watched entries through normal delivery.

- **Transient success notifications.** success toasts overlay the top right of the shared content below the header and dismiss after five seconds, pause during hover/focus and support manual dismissal. Persistent errors and reminders retained.

- **Ratings film source links.** shared TMDB/Wikipedia links between title and synopsis replace the separate release-year line; the year now follows the title in parentheses. Both open new tabs, including in the landing preview; rating controls remain read-only.

- **Header account controls.** shared Log in/Register/Try it out controls in the anonymous header and landing CTA, with Try it out omitted for guests; registered viewers get Log out. Account disclosure removed; account page deferred. Theme control uses borderless sun/moon icons; interactive cursors are shared globally with disabled-state defaults.

- Read-only Ratings interface is implemented. Reuse the actual film/rating/expression presentation for curated landing examples without personal records or interactive rating/trailer controls. The shared desktop layout has three columns: poster spanning the full card height; title/links and scrolling full synopsis above bottom-aligned rating choices; expression composer above a scrolling italicised removable list. Save/Dismiss sit at the bottom of the expressions column, aligned with the rating choices. Tablet groups poster/title/links and a fixed-height scrolling description on the left, with ratings/expressions/actions on the right. Phones use a single naturally growing column with page scrolling and no fixed card, description or list height. The shared card reserves fixed responsive film-detail/control regions and a scrolling expression list so synopsis length and expression count do not shift controls. Expressions are added with Enter (Shift+Enter keeps a newline); there is no Add button or example-caption heading. Pending input must be explicitly added or cleared before saving. Recommendations/Library examples remain deferred.

- Registry preview data is implemented. Registry supplies read-only films for landing examples and retains complete TMDB movie responses, with typed read adapters for consumed fields; full manual source refresh remains deferred.

Regular initial quality assignment makes one bundled support request per film without automatic paragraph-evidence requests. Source/definition snapshots, probabilities, decisions and application provenance remain recorded; historical paragraph evidence remains readable. On-demand manual review remains deferred; prefer one request unless measured limits/cost justify splitting.

Browser views use Phlex pages under `app/views/<domain>` and application-owned components under their domain or `app/components/shared`, with shared brand typography/colour themes. Registry inspection is superuser-only. Anonymous root now displays curated read-only Ratings examples with film posters/synopses; explicit account/guest entry gates product pages and preserves safe return URLs. Without a target, guests enter Ratings and registered users enter Library. Email templates remain ERB. All manual local work uses `glutton_development`; automated tests use `glutton_test`.

Development now contains 500 source-backed TMDB horror films, all with posters and initial qualities, following an owner-authorized clean Registry reload. The horror catalogue replacement is complete; cumulative TypeSafe usage remained below the approved $5 cap, including timeout reserves. Existing accounts and product activity were preserved. Core Ratings, Library and Recommendations functionality takes priority over Registry editing.

- Explicit identity entry and return routing is implemented. Anonymous landing preview creates no identity; account forms/explicit guest entry gate product pages and retain safe requested resources. Without a target, guests go to Ratings and registered users to Library.

- Rating choice naming/presentation is implemented. Native radio glyphs are hidden with selected/focus styling retained; “Pretty Good” now uses the saved pretty_good value and updated database constraint. No historical rating data required migration.

- Five landing examples are implemented. Rotation uses Alien, The Thing, Halloween, The Exorcist and An American Werewolf in London, with localized sample expressions and the existing readonly controls.

- Full TMDB metadata refresh is implemented. All 500 development films now have complete refreshed TMDB packets, vote counts, popularity and posters, with existing knowledge/personal state preserved. The Registry-owned operation retains full source responses and preserves Wikipedia, accepted qualities and evaluation history. This supplies stored vote-count/popularity inputs before Ratings admission.

- **Ratings catalogue discovery.** Automatic selection defaults to one film and fills only the requested shortfall under the per-user lock. The owner selected descending TMDB vote count for now, with missing values last and Registry ID as tie-break; this is a familiarity proxy, not a validated viewing probability. The owner selected a Registry metadata refresh prerequisite for the existing 500-film development catalogue; that refresh is complete. Replenish only requested queue shortfalls from Registry, preserving oldest-first order, ratings/dismissals/holds and existing Library-event behavior. Discovery requests vote-count ordering through a Registry-owned read query and keeps queue eligibility in Ratings. Library changes reach Ratings through the existing event subscription; depends on explicit Identity entry/gating. No anonymous candidate creation, providers or recommendation scoring.

- [Edit existing quality definitions](tasks/quality_definition_editing.md): Deferred draft; implementation not started. Superuser-only editing of matching definitions/exclusions, preserving immutable names, accepted film associations and historical evaluation snapshots, with explicit stale-form protection. Category settings and manual film-quality changes follow as separate Registry outcomes; source refresh and reassessment remain later.

- [Deterministic quality-change suggestions](tasks/deterministic_quality_suggestions.md): deferred draft for the later refresh/evaluation stage. Initial assignment may use the agreed selection arithmetic without implementing this suggestion product first.

A deferred alternative Ratings entry point is a seen-film selection grid for new users: selecting a film queues it for rating and replaces that tile with the next film, with no fixed number of selections required. This is documented in the product brief; it is excluded from current implementation.

## Delivery order

The immediate priority is a usable development seed followed by core public Ratings, Library and Recommendations functionality. Registry editing/refresh improvements below are deferred. The canonical-content dependency order remains:

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
- Ratings selects the next film from its own queue/presentation state. Library publishes watched facts; Ratings consumes them as known-seen evidence and admits unrated films into the same oldest-first queue without another seen question. Explicit rating dismissal remains in place even after new viewing evidence; already-rated films remain rated.
- Product domains communicate through durable asynchronous events with independent transactions and eventual consistency. See [domain events](domain_events.md). Agree publisher/subscriber contracts and implement them in separate owned tasks. Shared-data reads and internal domain operations may remain synchronous; AI processing retains separate rules.
- Source-backed film information/qualities are directly accessible with spoiler-labelled navigation normally from watched Library; access does not require watched status. Film owns current source context and direct quality associations; the former analysis models are retired.

## Agreed navigation

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. The agreed next design has a public anonymous landing preview and gated product pages. With no requested resource, identified guests default to Ratings and registered users default to Library; an explicit authorized resource target takes priority. This supersedes the earlier universal Ratings-root/no-homepage direction.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library is one page. A labelled dropdown at the top selects Watchlist (the default), Watched or Not interested. Use the platform-native select on mobile; preserve the same control on desktop. Selection is reflected in the URL, so refresh, sharing and back/forward restore the selected view. A bare Library URL opens Watchlist; changing the view resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with roomier film rows; keep the Library dropdown above the list. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

This is the agreed navigation design, not a claim that every destination is implemented. Login/registration/confirmation/recovery entry pages remain publicly reachable, and guest entry requires explicit interaction. Header controls show Log in/Register for anonymous visitors and guests, and Log out for registered viewers; there is no Account disclosure or account page. Login also offers Continue as guest with the same return rules. Active guests see a thin registration reminder below the header to save progress; it disappears on completed registration. The theme toggle is icon-only with localized accessible labeling and preserved keyboard/persistence behavior. Landing examples are curated Ratings demonstrations that cycle every 10 seconds with clickable position dots and pause/resume reusing the shared readonly form; film posters are intended UI content; no decorative hero is planned. Ratings admission uses descending TMDB vote count (missing last, Registry ID tie-break), while preserving the existing oldest-first unfinished queue. The root now provides the anonymous preview and identity-dependent redirects, and the authenticated header includes implemented Ratings/Library destinations, a superuser-only Registry link and account controls; Recommendations content still needs its own implementation; bounded first-visit Ratings discovery is ready for review. Do not add dead links or invent placeholder product flows merely to complete the navigation. Library browsing and its management actions are implemented; Recommendations and the complete mobile primary-navigation design remain separately scoped work.

## Future Recommendations scoring work

When implementing Recommendations, evaluate how variable film-quality counts and source coverage affect ranking, including raw-sum/normalization bias, overlapping qualities and positive/negative preference signals. Category caps do not establish fair scoring. The [recommendation construction requirements](architecture_brief.md#8-recommendation-construction) record the comparison cases; no scoring formula is selected yet.

## Future Ratings evaluation work

Apply the [evaluation consistency check](ratings_scoring_design.md#consistency-check-before-profile-work) when scoping expression profiles and implicit scoring. Record intentional differences before implementation.

Within the later Ratings scoring implementation, add support for profile-based evaluations and link their results to the originating evaluation. Distinguish profile-based interpretation from direct expression evidence; capture exact input/profile/definition versions, ordered calls/questions/responses, probabilities, deterministic processing and application outcomes. Retain historical results, reject stale work and replace contributions without double counting. Profile-only changes do not replace directly expressed evidence. Preserve Ratings ownership and the existing [scoring design](ratings_scoring_design.md); this is a future scoped outcome, not a new working task or implemented schema.

Operators can run `Ratings::RefreshExpressionProfiles.call` in Rails console to process durable pending requests. Rating submissions and revisions that change expressions record pending work in the same transaction. The same batch is available for hourly scheduling after the remaining Ratings scoring work. The first successful refresh creates a Ratings-owned profile parent and its first immutable revision. Each revision stores its applied text and links to an immutable synthesis evaluation. The workflow uses current original expressions, checks freshness before committing, and skips synthesis for empty or unchanged evidence. The OpenAI synthesis adapter returns an annotated narrative. GPT-6.1 Terra at low reasoning effort is the initial rollout choice. Initial scoring can use the latest completed profile. Each completed profile change triggers deferred reevaluation of all current ratings for that user. The planned hourly trigger will invoke the pending batch. The downstream rating-quality storage contract remains open.

Expression-profile updates require an LLM call; no JEV gate is assumed. JEV evaluates rating qualities against profiles or explicit expressions. Application evidence belongs in the database, with optional Langfuse diagnostic links. Do not introduce a generic cross-domain evaluation table/framework.

## Release follow-up

Complete the seed-first sequence above before later admin improvements. Admin viewing requires authorisation before exposure; manual source refresh changes no accepted qualities. Source/association changes do not themselves authorise downstream score mutations. Community editing, scheduled syncing, streaming integrations and speculative extra event consumers are not prerequisites.

Final production hosting, scheduler installation and account/activity-retention decisions remain explicit follow-up work. Shared reads of authoritative records are allowed; cross-domain writes require the owning workflow and agreed durable events. Product/architecture briefs and domain contracts retain the detailed requirements.
