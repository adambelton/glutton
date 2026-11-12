# Glutton — Implementation progress

Updated: 12 November 2026. This document describes current progress, agreed order and next work. GitHub holds PR, commit, CI and delivery history; completed task records are not retained here.

## Current progress

- Foundation: Rails/PostgreSQL/Hotwire, English locale conventions, hosted/local CI with refreshed security advisories, durable asynchronous domain-event delivery and explicit observability integration are implemented. Ratings and Registry share a TypeSafe client with domain-specific limits and trace settings. Production deployment and scheduling remain decisions to make.
- Identity: guest/registered identities, revocable sessions, browser sign-in/out, registration/confirmation, password recovery and bounded expiry cleanup are implemented. Minimal superuser permission and explicit grant/revoke operations restricted to existing superusers are implemented.
- Registry: canonical film storage, TMDB search and complete metadata/Wikipedia import, editable quality categories and direct film-quality associations are implemented. The one-time plain-YAML seed loads 235 quality definitions and nine category defaults; names/IDs are used without separate keys. Initial per-film quality assignment, create-only loading orchestration and bounded warning-isolated batch entry points are implemented; superuser-only read-only catalogue inspection is implemented; import/edit/refresh web entry points and bulk catalogue execution remain to build.
- Library: Watchlist and Watched browsing, details and actions are implemented, with authoritative shared reads for current rating status and the agreed event reactions. The Watched list preloads rated records by viewer and film so Library films can determine the available rating actions.
- Ratings: candidate queue, dismissal/holds, first submission with optional film notes, rating replacement/history, browser editing and targeted Library entry are implemented.
- Ratings saves optional film notes on submission and durably queues assessment of the saved rating version. The assessment gives direct evidence from notes precedence, uses the latest completed profile for eligible qualities, and assigns baseline scores where neither applies. One evaluation records the evidence for each complete score set. Only a newer profile revision can supersede applied scores for the same rating version. Queue activation, recommendation ranking and explanations remain open.

## Current work

- **Rating and recommendation actions and Library simplification — planning.** Library will keep Watchlist and Watched on one `LibraryFilm` with a required `watched` boolean defaulting to false. Retire STI and the Not interested section. Development Not interested entries can be discarded. Ratings owns `dismissed` and `suppressed` booleans. Recommendations owns a nullable `response` of `accepted` or `rejected` and a separate `suppressed` boolean. Add to Watchlist and Mark Watched belong to Library. Reviewing and restoring dismissed ratings candidates or rejected recommendations belongs to the domain that presented them. The [rating and recommendation event contracts](domain_events.md#rating-and-recommendation-events) describe independent publication and subscriber reactions.
- **Delivery sequence for the redesign.** Scope Library's two-state model, transition behaviour and section removal as a Library task. Ratings suppression and Recommendations ranking are implemented. Coordinate action recording, event publication and subscriber reactions in one working task. Add each review/restore flow in its owning domain. Use the existing Foundation delivery mechanism. Use the agreed event contracts for payloads, ordering, idempotency and retention.
- **Rating and recommendation events.** Library consumes only `RatingSubmitted` and `RecommendationAccepted`. Recommendations consumes Ratings and Library facts to manage its suppression. Browser controls and ranking are separate.
- **Development rebuild.** Edit the original migrations for changed tables and regenerate the schema from an empty database. Before replacing `glutton_development`, stop writers, keep a local rollback backup, and rehearse a selective restore of users and the Registry catalogue (films, quality categories, qualities, associations and evaluations) in a scratch database. Preserve IDs and reset sequences. Leave Library, Ratings, Recommendations, taste profiles, event streams and job history empty. Verify catalogue counts and references, account sign-in and empty activity before handing back for fresh manual ratings. Restore accounts and require fresh sign-in. Sessions and pending registrations start empty. The local rebuild is complete.
- **Redesign verification.** The Library simplification and Ratings suppression rename are implemented. A scratch rebuild produced the checked-in schema. The selective restore copied one user, 500 films, nine quality categories, 235 qualities, 501 evaluations and 12,025 associations, preserving IDs and resetting sequences. It used the rebuilt schema's column lists because development still has the retired `film_quality_evals.application` column. Keep that legacy data in the rollback backup. The replacement became the development database and the app restarted. The original database and a full backup were retained. The restored registered account requires a fresh sign-in.

- **Library actions from Ratings and Recommendations.** Add to Watchlist and Mark Watched post to Library. Successful actions show a notice and pass the acted-on film ID through flash to the immediate next selection. Recommendations also offers a link to rate the film just marked Watched. Normal event delivery still updates suppression.

- **Recommendations — ranking implemented.** The owner selected raw sum over actual latest applied scores, including implicit/explicit expression scores. Five current assessed films remain the unlock threshold. Select the next highest-scoring eligible film, defaulting to one, without a positive-score cutoff. Use only scored current revisions; omit old scores while a replacement awaits assessment. Any new Ratings read API remains separately owned. Investigation artefacts are removed. The Recommendations page shows unlock progress or the next eligible film. Explanation and response controls remain separate.

- **Capability-oriented service organisation — Implemented.** Services now use the agreed domain/capability namespaces, one errors namespace per domain and responsibility-based AI operation names. Service tests follow the capabilities; models, job identities, event contracts, provider requests and persistence semantics are preserved. [Organisation and naming](architecture_brief.md#service-organisation-and-naming) and the [AI composition guidance](ai_model_services_design.md) describe the conventions. Ratings assessment composition now uses consistent implicit/explicit result readers, and the unused refresh keyword is removed. The [public-interface audit recheck](audits/2026-11-09_public_interface_audit.md#recheck--10-november-2026) confirms that all four original findings are resolved. The applied-score read contract is deferred to Recommendations integration.

- **Application and test audit handoff.** The [8 November audit](audits/2026-11-08_application_and_test_audit.md) records the original findings. Scoped remediation covers the targeted Ratings form, Library and Identity model actions, shared provider transport and tracing, and regression coverage for browser interactions. Chrome also exposed a shared hidden-field parameter defect that affected Ratings dismissal. Repository CI now includes the browser suite and a Rails autoload check.

- **Development job worker.** bin/dev runs the domain event and Ratings queues alongside Rails and manages shared shutdown. Existing 12 queued rating submissions have converged to Library watched entries through normal delivery.

- **Transient success notifications.** success toasts, error alerts and registration banners share a viewport-right overlay without shifting page content. Success toasts dismiss after five seconds, pause during hover/focus and support manual dismissal; errors and reminders remain persistent. The post-save Ratings edit link is removed; existing ratings remain editable through Library.

- **Ratings film source links.** shared TMDB/Wikipedia links between title and synopsis replace the separate release-year line; the year now follows the title in parentheses. Both open new tabs, including in the landing preview; rating controls remain read-only.

- **Header account controls.** shared Log in/Register/Try it out controls in the anonymous header and landing CTA, with Try it out omitted for guests; registered viewers get Log out. Account disclosure removed; account page deferred. Theme control uses borderless sun/moon icons; interactive cursors are shared globally with disabled-state defaults.

- The Ratings form and read-only landing examples share a three-column desktop card with film information, rating controls, and one visible multiline notes field. On mobile, the layout stacks the same content. Notes are optional, saved with the rating, and editable through a rating revision.

- Registry preview data is implemented. Registry supplies read-only films for landing examples and retains complete TMDB movie responses, with typed read adapters for consumed fields; full manual source refresh remains deferred.

Regular initial quality assignment makes one bundled support request per film without automatic paragraph-evidence requests. Source/definition snapshots, probabilities, decisions and application provenance remain recorded; historical paragraph evidence remains readable. On-demand manual review remains deferred; prefer one request unless measured limits/cost justify splitting.

Browser views use Phlex pages under `app/views/<domain>` and application-owned components under their domain or `app/components/shared`, with shared brand typography/colour themes. Registry inspection is superuser-only and uses the shared application layout. Registry, Library and Account headings sit above their content cards. Anonymous root now displays curated read-only Ratings examples with film posters/synopses; explicit account/guest entry gates product pages and preserves safe return URLs. Without a target, guests enter Ratings and registered users enter Library. Email templates remain ERB. All manual local work uses `glutton_development`; automated tests use `glutton_test`.

Development now contains 500 source-backed TMDB horror films, all with posters and initial qualities, following an owner-authorized clean Registry reload. The horror catalogue replacement is complete; cumulative TypeSafe usage remained below the approved $5 cap, including timeout reserves. The latest local development rebuild imported the same 500 TMDB identities into a fresh database to verify the original migrations and persisted provider requests. That rebuild started with no accounts or product activity. Core Ratings, Library and Recommendations functionality takes priority over Registry editing.

- Explicit identity entry and return routing is implemented. Anonymous landing preview creates no identity; account forms/explicit guest entry gate product pages and retain safe requested resources. Without a target, guests go to Ratings and registered users to Library.

- Rating choice naming/presentation is implemented. Native radio glyphs are hidden with selected/focus styling retained; “Pretty Good” now uses the saved pretty_good value and updated database constraint. No historical rating data required migration.

- Five landing examples are implemented. Rotation uses Alien, The Thing, Halloween, The Exorcist and An American Werewolf in London, with localized sample notes and the existing readonly controls.

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
| Library | Canonical user–film relationship: Watchlist and Watched; library management and views | Does not own rating/recommendation presentation histories, ratings, expressions or inferred taste |
| Ratings | Rating presentations and all responses, ratings, original expressions; scoring, profiles and reassessment as distinct capabilities | Owns next-film selection from its own presentation state; reports completed ratings through Library operations |
| Recommendations | Candidate selection, ranking, explanations, recommendation presentations and all responses | Owns recommendation eligibility; consults Library and Ratings, requests Library-owned actions |
| Identity (supporting) | Guest/registered users, credentials, sessions, registration and delivery | Supplies session-bound internal identity; owns fixed guest expiry |
| Foundation (supporting) | Rails/database boot; later shared operational infrastructure | No product rules |

A domain is not a table or screen. Rating/recommendation records describe their purpose-specific activity; Library records canonical state. They need not share persistence. Capability boundaries keep tasks small inside Ratings without inventing a separate Taste domain. Do not generate empty engines, namespaces or speculative interfaces.

**Key rules:**

- Ratings records “haven’t seen it” and avoids repeating that rating film. This response alone creates no Library classification and does not exclude recommendations.
- Recommendations owns its suppression state. Watchlist and Watched activity can suppress a prompt through Library events.
- Library owns watched-but-unrated films. “Awaiting rating” means watched without a current rating owned by Ratings; derive the display from that result initially. Library links to the targeted Ratings flow.
- Ratings owns current rating/history; Library's rated presentation reflects it rather than maintaining an independent rating value.
- Ratings does not require a Library watched record to accept a rating. Confirming seen alone stays in Ratings; a completed rating publishes viewing evidence for Library to consume asynchronously.
- Ratings selects the next film from its own queue/presentation state. Library publishes watched facts; Ratings consumes them as known-seen evidence and admits unrated films into the same oldest-first queue without another seen question. Explicit rating dismissal remains in place even after new viewing evidence; already-rated films remain rated.
- Product domains communicate through durable asynchronous events with independent transactions and eventual consistency. See [domain events](domain_events.md). Agree publisher/subscriber contracts and implement them in separate owned tasks. Shared-data reads and internal domain operations may remain synchronous; AI processing retains separate rules.
- Source-backed film information/qualities are directly accessible with spoiler-labelled navigation normally from watched Library; access does not require watched status. Film owns current source context and direct quality associations; the former analysis models are retired.

## Agreed navigation

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. The agreed next design has a public anonymous landing preview and gated product pages. With no requested resource, identified guests default to Ratings and registered users default to Library; an explicit authorized resource target takes priority. This supersedes the earlier universal Ratings-root/no-homepage direction.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library is one page. A labelled dropdown at the top selects Watchlist (the default) or Watched. Use the platform-native select on mobile; preserve the same control on desktop. Selection is reflected in the URL, so refresh, sharing and back/forward restore the selected view. A bare Library URL opens Watchlist; changing the view resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with roomier film rows; keep the Library dropdown above the list. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

This is the agreed navigation design, not a claim that every destination is implemented. Login/registration/confirmation/recovery entry pages remain publicly reachable, and guest entry requires explicit interaction. Header controls show Log in/Register for anonymous visitors and guests, and Log out for registered viewers; superusers also have an Account link beside Registry, with a Glutton Profile tab for their own profile and refresh controls. Login also offers Continue as guest with the same return rules. Active guests see a registration reminder in the viewport-right notification overlay to save progress; it disappears on completed registration. The theme toggle is icon-only with localized accessible labeling and preserved keyboard/persistence behavior. Landing examples are curated Ratings demonstrations that cycle every 10 seconds with clickable position dots and pause/resume reusing the shared readonly form; film posters are intended UI content; no decorative hero is planned. Ratings admission uses descending TMDB vote count (missing last, Registry ID tie-break), while preserving the existing oldest-first unfinished queue. The root now provides the anonymous preview and identity-dependent redirects, and the authenticated header links to Ratings, Recommendations and Library and includes a superuser-only Registry link and account controls. Do not add dead links or invent placeholder product flows merely to complete the navigation. Library browsing and its management actions are implemented. The complete mobile primary navigation remains separately scoped.

## Future Recommendations scoring work

At Recommendations integration, revisit a narrowly scoped Ratings-owned model scope/query for each viewer’s current ratings and latest actually applied score set. Prefer the smallest existing-model API before adding a service. Agree inputs, result shape and missing/inactive-viewer behaviour then, and adopt it in the Recommendations consumer within its own scope. Verify viewer isolation, superseded ratings/score sets, newer recorded-but-unapplied evaluations and current unassessed revisions. Keep ranking, aggregation and eligibility in Recommendations; shared reads are already permitted. Do not build an unused read API ahead of that integration.

When implementing Recommendations, evaluate how variable film-quality counts and source coverage affect ranking, including raw-sum/normalization bias, overlapping qualities and positive/negative preference signals. Category caps do not establish fair scoring. The [recommendation construction requirements](architecture_brief.md#8-recommendation-construction) record the monitoring concerns. The owner selected raw sum over applied scores; no normalization or fixed quality count is planned without evidence of relevant films being overlooked.

## Future Ratings evaluation work

Apply the [evaluation consistency check](ratings_scoring_design.md#consistency-check-before-profile-work) when scoping taste profiles and implicit scoring. Record intentional differences before implementation.

The [Ratings scoring design](ratings_scoring_design.md) documents initial scoring and how newer profile revisions can supersede a complete score set while retaining history. Profile publication queues reassessment for current ratings and keeps only the newest pending revision per viewer. Reassessment carries forward explicit judgments when an applied set exists. Defer batching until production usage provides evidence about reassessment cost or latency.

Operators can run `Ratings::TasteProfiling::ProcessProfileRefreshes.call` in Rails console to process durable pending requests. Rating submissions and revisions that change notes record pending work in the same transaction. GoodJob runs the same batch every 15 minutes on the Ratings assessment queue in production. The first successful refresh creates a Ratings-owned profile parent and its first immutable revision. Each revision stores its applied text and links to an immutable synthesis evaluation. The workflow uses current original notes, checks freshness before committing, and skips synthesis for empty or unchanged evidence. The OpenAI synthesis adapter returns an annotated narrative. GPT-6.1 Terra at low reasoning effort is the initial rollout choice. Initial scoring uses the latest completed profile. Reevaluation is queued immediately after profile publication.

Taste-profile updates require an LLM call; no JEV gate is assumed. JEV evaluates rating qualities against profiles or direct film notes. Application evidence belongs in the database, with optional Langfuse diagnostic links. Do not introduce a generic cross-domain evaluation table/framework.

## Ratings writing guidance

The optional **Your notes** field gives viewers a place to keep a private film journal. A light prompt such as “What stayed with you? What made it work or fall flat?” could help viewers explain what shaped their reaction. A note like “I liked the slow pace” is useful on its own. Adding that the quiet made each return to the house feel less safe gives the profile a condition it can use when interpreting other films. Try the wording with viewers and see whether it helps them write more informative notes without adding friction to rating.

The weekly podcast is a natural place to try this. Discuss the film, use follow-up questions to surface what shaped each host’s reaction, then let each host write their own notes in Glutton. The discussion can reveal why the same quality worked for one person and fell flat for another.

## Release follow-up

Complete the seed-first sequence above before later admin improvements. Admin viewing requires authorisation before exposure; manual source refresh changes no accepted qualities. Source/association changes do not themselves authorise downstream score mutations. Community editing, scheduled syncing, streaming integrations and speculative extra event consumers are not prerequisites.

Final production hosting, scheduler installation and account/activity-retention decisions remain explicit follow-up work. Shared reads of authoritative records are allowed; cross-domain writes require the owning workflow and agreed durable events. Product/architecture briefs and domain contracts retain the detailed requirements.
