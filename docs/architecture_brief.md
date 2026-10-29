# Glutton — Architecture Brief

Status: Draft for discussion  
Date: 18 October 2026

## 1. Purpose and architectural goals

Glutton helps horror enthusiasts discover films through the qualities they enjoy and dislike. Personal ratings provide implicit evidence; optional expressions provide explicit context that improves scoring of subsequently rated films and, through later reassessment, previously rated films.

The project should become a useful, sustainable product with real users. It also provides deliberate practice in domain-driven design, PostgreSQL performance, and managing domain complexity in Ruby on Rails. Architectural decisions should make domain rules and database behaviour understandable, while keeping implementation and operations manageable for an independent maintainer.

This document distinguishes agreed behaviour from proposed implementation. Framework patterns, numeric scoring rules, provider capabilities and deployment choices remain open unless explicitly settled below. It incorporates the product brief and subsequent discussion; where the discussion revises the original brief, this draft follows the discussion.

## 2. Agreed product scope

### Rate films

The viewer cycles through films in an explicit rating interface. They first indicate whether they have seen the film. Selecting **Haven’t seen it** persists confirmed-unseen status and excludes the film from subsequent rating prompts while that status remains. Offer **Add to watchlist** directly at this point, or continue to the next film. Confirmed-unseen status alone does not exclude a film from discovery; watchlist addition classifies it as To watch and does exclude it.

For a seen film, the viewer chooses Brilliant, I Enjoyed That, Not For Me, or Garbage. They may add several individual, natural-language expressions. The interface encourages distinct ideas without forcing tags or stripping contextual meaning. They save the rating and expressions together.

Expressions are optional. Users who only rate films must receive useful recommendations. Extreme ratings provide stronger directional evidence than mild ratings; exact weights remain experimental.

### Process recommendations

Recommendations contain spoiler-safe information, an understandable reason for the suggestion, and potentially trailers and external ratings where integrations permit. A viewer can mark a film watched, add it to their watchlist, or mark it not interested.

Only films with no library classification are eligible. To watch, watched and not interested all exclude a film from recommendation results. Watchlist acceptance is not positive enjoyment evidence. Not interested is not negative quality evidence.

Marking a film watched makes it available for a later rating session, with a possible immediate-rating entry point. A reduced rating interface is an option, not a settled MVP requirement.

### Manage the library

The library provides To watch, Watched and Not interested views. Watched films may be awaiting a rating or already rated. Users can revisit and change ratings and expressions, reconsider dismissed films, and inspect film information and qualities through spoiler-labelled links normally shown in the watched Library view.

Viewing status (unknown, confirmed unseen, watched) is distinct from library classification. Confirmed-unseen films need not belong to a classified library view. Marking one watched through the library or discovery makes it available for rating. Removing an unwatched film's classification makes it eligible for recommendations again, while preserving confirmed-unseen status and its exclusion from rating prompts. Exact transitions between existing library choices, and their UI wording, need specification before implementation.

A separate conversational reflection interface is a possible future feature, not required for the core product or initial architecture. Community editing, streaming availability, donations and affiliate integrations are also later concerns.

## 3. Proposed system shape

Use a cohesive Ruby on Rails application backed by PostgreSQL. Initial scaffolding uses server-rendered views and Hotwire; the scoped implementation plan records the delivery sequence. No current behaviour requires independently deployed services.

Organise code around domain responsibilities with explicit application operations for workflows. Keep substantial product decisions—such as rating transitions, recommendation eligibility, scoring and preference calculations—in ordinary Ruby objects with explicit inputs/results, independently testable without Rails boot or database records. Application operations load the required state, invoke those rules, persist results and publish domain events atomically with the source change. Other product domains react asynchronously in their own transactions. Keep database constraints for persisted invariants; independent rule tests do not replace persistence or workflow tests.

Keep all current models directly under `app/models/`, following Rails' default file mapping. `user.rb` defines the User STI storage/query root (direct construction is prohibited); `user_registered.rb`, `user_guest.rb` and `user_deleted.rb` define UserRegistered, UserGuest and UserDeleted. All share the users table and use their full top-level class names as STI values. No namespace, table-name override or directory-collapse rule is needed. User-owned registration/credential permissions and actions stay on the models; registration transition execution remains in its Identity service. Session UI uses Rails polymorphic partials. Session owns resumption and fresh binding checks, consulting user.active? and a model-owned inactive error when needed. The transport derives cookie expiry from user.session_duration; this does not impose a registered server-session TTL. Session remains in `session.rb`. Reconsider model organisation only when concrete behaviour warrants it.

Task [006p](specs/006p_confirmation_orchestration.md) (Merged via PR #22) simplifies confirmation. Confirmation has one transaction coordinator in Identity::CompleteRegistration, including attachment of an unattached registration to the current active guest. PendingRegistration owns token resolution and confirmation access rules shared by GET and completion; GET performs no attachment. The browser completion entry point delegates to that coordinator. Completion locks the source user before the pending request and revalidates the token after locking.

Active Record remains appropriate for persistence and straightforward local behaviour, including Identity credentials, password hashing and account validation. Declare built-in validations directly in their models; reserve extracted capability modules for meaningful domain behaviour rather than sharing validation declarations. Do not duplicate that model in a separate entity/repository layer without a concrete need. Extract stronger persistence boundaries where domain complexity or tests show the benefit. Use background jobs for deferred processing. Avoid introducing engines, generic repositories, event sourcing or a messaging platform without a concrete need.

Treat every object as a role and name collaborators for the role actually required, whether implemented through a concrete class, superclass or shared-behaviour module. Trust internal role contracts by default; class guards and their disguised predicate equivalents require a specific justification. Put rules about an object's permitted behaviour inside that object and delegate the operation rather than identifying its class to choose behaviour elsewhere. Meaningful domain-state and action-permission predicates remain appropriate. Models own ordinary actions and their rules; transition services coordinate changes between model types, while the source model declares supported actions without sibling-class knowledge. Validate untrusted input at its boundary. Refresh/re-read and lock when freshness/concurrency matters independently of role trust. Tests follow the same role rules and verify observable outcomes and contracts rather than incidental internal state; do not introduce production interfaces solely for test assertions. The maintained implementation/review conventions and examples are in [AGENTS.md — Object roles and behaviour](../AGENTS.md#object-roles-and-behaviour).

Keep external-provider calls behind narrow adapters. Initial boundaries cover JEV assessment, Claude profile synthesis, metadata lookup and source retrieval. These boundaries should expose the operations Glutton requires rather than reproduce every provider API.

Use local PostgreSQL for development. Railway plus Neon is the owner’s familiar deployment option, with production hosting still to be selected. Server-rendered Rails views and Hotwire are the initial frontend direction. Job backend and specific provider/model versions remain undecided; background processing is a separate task after the minimal scaffold. Modest model API development costs are acceptable; expensive data/media licences are not. The owner has a Claude API key and can create a JEV key; keep credentials out of source control.

## 4. Domain responsibilities

Boundaries follow distinct activities and their language, not a generic user–film table. They remain testable modelling decisions rather than prescriptions for Rails engines or independent services.

| Area | Owns | Boundary |
| --- | --- | --- |
| Film knowledge | Film identity, metadata/media, sourced context, editable quality categories/vocabulary and accepted film–quality associations | Shared knowledge independent of viewers |
| Library | Canonical user–film relationship: watchlist, watched and not interested; library management | Does not own purpose-specific presentation histories, ratings or inferred preferences |
| Ratings | Rating presentations and responses, ratings, original expressions, scoring, expressions profiles and inferred preferences | Rating submission, scoring and profile building are distinct capabilities; Ratings publishes completed-viewing facts and explicit Library action requests |
| Recommendations | Selection, eligibility, ranking, explanations, presentation and response history | Maintains projections from Library/Rating events; publishes response choices without owning Library state |

Owner clarification, 26 October 2026: domain boundaries are ownership boundaries, not read-access barriers. All domains may read the shared database, including another domain’s models/scopes, while respecting session/user access controls. Each domain owns its mutations, invariants and lifecycle. Read-only presentation queries do not require event-derived copies or new provider/consumer tasks. Durable events remain the agreed mechanism for existing cross-domain state-changing reactions; this clarification does not replace those workflows. For example, Library derives rated/awaiting-rating display from Ratings-owned records without storing its own rated flag.

Ratings contains separate capabilities for recording evidence, scoring, profile building and reassessment. They share domain language; the original evidence/inferred interpretation distinction remains an invariant inside this domain, not a separate Taste boundary. Library is the canonical collection, while Ratings/Recommendations records describe their specific activities. These records need not share a data model.

A Ratings “haven’t seen it” response suppresses later rating prompts without creating a Library entry or excluding recommendation eligibility. Recommendations assumes candidates are unwatched absent evidence otherwise; its exclusion rule uses Library's classifications, not the mere existence of any user–film record. Library owns watched-but-unrated films and links to Ratings. Its rated display reflects Ratings' authoritative current rating rather than owning a duplicate value.

Film knowledge owns the shared quality vocabulary; Ratings interprets it as evidence about a viewer. Dynamically source people candidates from verified credits. Any apparent need to change multiple domains requires a boundary/invariant review before creating provider/consumer tasks; an occasional stable interaction is not inherently a modelling defect.

Quality modelling consideration (owner discussion, 20 October 2026): consider distinct quality types with potentially different rules and behaviour. Rails single-table inheritance may be appropriate, following the existing User hierarchy, if concrete differences justify it. Revisit this when specifying quality persistence; it is a candidate design, not a committed hierarchy. Distinguish behavioural types from descriptive categories, and avoid inventing subclasses before their rules are known. This is outside task 007 and does not block minimal film catalogue work.

## 5. Core concepts and invariants

- **Film:** A distinct work identified consistently across imports, including remakes and versions where relevant.
- **Film source information:** Maintained source material with provenance; an independent FilmAnalysis lifecycle is under review.
- **Film–quality assessment:** An accepted source-backed association for current scoring; permanent historical association sets are not yet required. Current assignment freshness is distinct from retention history.
- **Library entry:** The canonical user–film relationship, owned by Library. Viewing facts and watchlist/dismissal intent need consistent rules without prescribing a table structure. Confirmed-unseen rating responses belong to Ratings and need no Library entry.
- **Rating presentation / response:** Ratings' record that a film was presented and the viewer's response, including haven’t seen it. Separate from canonical Library state.
- **Recommendation presentation / response:** Recommendations' record of a proposed film and response, independent of Library persistence. Library actions use Library-owned operations.
- **Rating:** The viewer's personal reaction to a watched film. Watched does not imply rated.
- **Expression:** One original viewer-authored idea associated with a film. Preserve wording and revisions required for traceability; define retention and deletion behaviour explicitly.
- **Expressions profile revision:** An interpretation derived exclusively from the viewer's actual expressions. Rating patterns and inferred scores must never enter it as user statements.
- **Film quality scoring assessment:** Separate implicit and expression-based evidence for one viewer's rating submission, recording its input versions and processing provenance.
- **Inferred preference result:** The current aggregation of completed scoring evidence used for recommendations. Its exact representation and aggregation formula remain open.
- **Recommendation response:** A discovery decision, separate from watched-film enjoyment evidence. Current library state determines eligibility; response history can support later evaluation.

Reprocessing replaces or supersedes an interpretation. It must not accumulate duplicate evidence. Running the same assessment or aggregation repeatedly with identical inputs must not amplify preference strength.

### Asynchronous domain events

Owner decision, 21 October 2026: Library, Ratings and Recommendations coordinate through durable asynchronous domain events. This supersedes the synchronous-only design. The source commits its state and outbox event together; subscribers commit their own state and delivery receipt independently. Brief eventual consistency is acceptable. Delivery must survive crashes and retries, preserve stream ordering and prevent duplicate effects. No broker or independently deployed service is required. Foundation task 001i implements the durable outbox and subscriber receipts using GoodJob 4.22 in the same PostgreSQL database, with after-commit notification wakeups and a 30-second recovery sweep. It merged via PR #25; domain publishers/subscribers and deployment remain separate. See [operations](domain_event_operations.md).

[Domain events](domain_events.md) specifies the publication/subscription map, event versus request semantics, versioning, conflicts, backfill, privacy, failure recovery and separate publisher/consumer tasks. Library publishes watched/watchlist/dismissal/removal facts. Ratings publishes completed rating/revision and later preference facts. Recommendations publishes recorded action choices for Library to apply or reject; receiving a choice is not proof that Library changed. Ratings UI actions follow the same boundary. Domain model behaviour and internal synchronous calls remain unchanged.

Ratings preserves its own history and distinguishes known watched awaiting rating from unknown films needing a seen/unseen prompt. NotInterested means unseen and unwanted, excluding rating and recommendation presentation; removing it does not assert seen. Consumers retain provenance and never erase a saved rating due to a delayed contradictory Library event. Completed-rating handling is a system workflow with explicitly defined duplicate/reconciliation behaviour; it does not change public user-action failure semantics. No subscriber recreates a source action just because it received the resulting fact.

Source-backed film information is directly accessible; normal navigation is through spoiler-labelled links on the watched Library view, without a Library-based authorization gate.

## 6. Saving a rated film

Scoring clarification, 22 October 2026: [Ratings scoring design](ratings_scoring_design.md) records the agreed unexpressed, implicitly expressed and explicitly expressed classifications, current-profile recomputation rules and proposed Rating/RatingExpression/RatingQuality relationships. It supersedes the earlier separate-score terminology and mandatory prior-profile capture described below. Task 015 captures original expressions only; scoring and profile processing remain deferred.

### Record the submission

A Ratings operation validates its own seen confirmation and the rating, without requiring a Library watched record, then atomically persists the rating and expressions, records a submission revision, and identifies the expressions profile revision that existed before this submission. The viewer can continue rating once their input is durably saved.

Saving and assessment completion are distinct states. Provider failure must not lose the submission. Deferred work must be durably discoverable and retryable; the exact database-backed job or pending-work mechanism is an implementation decision.

### Branch A: quality scoring through JEV

Use the rating, submitted expressions, relevant film knowledge and the captured prior expressions profile to produce:

1. Implicit quality evidence based on the rating, interpreted using that prior profile.
2. Explicit quality evidence based on the expressions submitted for this film.

The captured profile **must not include changes derived from this submission**. Both kinds of scoring are handled through JEV; Claude is not required for this round of scoring. This specifies responsibility, not whether the assessments require one provider request or several.

Store implicit and explicit outputs separately enough to inspect and evaluate them. How JEV represents relevance, direction and strength, and how these outputs combine, must be established through experiments.

### Branch B: expressions profile assessment

Independently assess whether the new expressions add, narrow, contradict or otherwise meaningfully change the existing understanding of explicit preferences. The proposed cost-saving sequence is:

1. Ask JEV whether the expressions warrant a profile update.
2. If so, ask Claude to synthesize a revised expressions profile from explicit evidence.

Benchmark the JEV gate against always attempting synthesis. A false negative can suppress useful context, so original expressions and processing status must remain available for recovery. The gate's exact question, inputs and threshold remain open.

Submissions without expressions do not require profile synthesis. Edits and deletions require reassessing the affected explicit evidence; an additions-only novelty check is insufficient for removing an earlier claim.

### Completion and concurrency

The two branches may complete independently. Completed scoring can affect recommendations without waiting for profile synthesis. A new profile revision informs subsequent assessments once available, and makes historical assessments candidates for refresh.

Rapid submissions can capture the same prior profile while processing is pending. Record this honestly and reconcile through reassessment. Profile updates must detect an outdated base revision and merge or retry against current explicit evidence, rather than overwrite another update. The serialization strategy remains open.

## 7. Immediate effects and periodic reassessment

An expression contributes explicit evidence for its own film as soon as scoring completes. After its profile update completes, it can inform implicit scoring of subsequent submissions. Existing assessments are updated later through periodic or explicitly triggered work.

Refresh considers all relevant rated films, including the implicit assessment of the submission that caused the profile change. It recomputes from authoritative inputs and selected current revisions, preserving the distinction between direct expression evidence and inferred attribution.

Track freshness through input revisions rather than a single ambiguous updated timestamp. Relevant changes include ratings, expressions, expressions profile, film analysis/associations, vocabulary and scoring method. Different changes may require different processing stages; a profile change need not require reclassifying unchanged expression text.

The exact refresh cadence, material-change criteria and whether MVP offers a manual refresh control remain open. Coalesce superseded work, bound provider costs, and avoid claiming that recommendations incorporate a profile revision before the relevant processing completes.

## 8. Recommendation construction

Recommendations first excludes all films classified in the viewer's library. It then ranks eligible films using current completed preference evidence and film–quality associations, accounting for both positive and negative signals.

Start with a comprehensible aggregation and matching method. Neither film similarity nor quality overlap alone establishes predicted enjoyment. Exact scoring mathematics, normalization, conflict handling, minimum-history behaviour and balancing implicit versus explicit evidence require evaluation.

Recommendation explanations must be supported by the evidence actually used and remain spoiler-safe. An explanation must distinguish an explicitly expressed preference from an inferred pattern. Prefer reusable spoiler-safe film material and inexpensive explanation construction where sufficient; per-card generative calls are not assumed.

Store enough information about served recommendations and scoring versions to compare outcomes and understand ranking changes. The required retention and detail should be proportionate to evaluation needs.

## 9. Film knowledge sources and quality decisions

Current direction, 28 October 2026: use maintained Wikipedia narrative/context and a revisable master vocabulary. Glutton owns accepted source-backed quality associations; JEV is the chosen assessment engine. Source acquisition and candidate evaluation do not automatically accept new qualities. [Current requirements](film_quality_requirements.md) supersede the former generated-analysis dossier design.

Quality categories are editable records, not the seven `FilmQuality::Dimensions` constants. Task [043](specs/043_editable_quality_categories.md) plans their replacement while preserving quality identities and existing associations. Categories organise concepts without defining scoring behaviour; a grouping-only edit does not rescore.

Initial quality/category base weights are equal, following the owner's 28 October clarification. Do not use film centrality or model confidence as an intrinsic weight or default quality-selection gate. A presentation characteristic such as minimal dialogue may matter more to a viewer than a central theme. Actual rating/expression evidence still determines user-specific contributions. Future system- or user-controlled category weighting is optional and unspecified; no weight fields, category quotas or weighting UI are required now. The max-20 selection policy remains separate from score weighting.

A Wikipedia page refresh changes source material. A deliberate accepted film-quality change is the proposed trigger for affected downstream reassessment. Do not automatically regenerate matches or scores for every page revision. Film knowledge publishes accepted changes only through a separately agreed event contract; Ratings and Recommendations own their resulting mutations.

Historical rating/recommendation contributions explain the scores actually produced. They must not depend on reconstructing an old film association set. Whether FilmAnalysis/AnalysisQuality are needed for a separate review/rollback/audit purpose remains open; current source information plus direct current associations may suffice. No model removal is implemented or authorised by this requirement.

Owner clarification, 29 October 2026: further fine tuning is not a prerequisite to a useful community-improved seed. The [working baseline](film_qualities/README.md) retains the current vocabulary, neutral question contract and six uncapped examples. The next design work is selection and source-backed community review/publishing. No Langfuse prompt migration is required for that step; quality meanings remain product data.

JEV's logical judgments and HTTP request packing are separate. Independent per-quality questions may share state in one request or several batches; production grouping, context, thresholds and failure handling remain to be discussed. Do not hard-code category partitions or interpret support probability as a preference score.

The existing generated-analysis implementation remains legacy code until separately scoped replacement/removal. Its old research trials are not the current product contract. Keep source evidence, original expressions and actual historical score outputs, without assuming that every intermediate film analysis or former association set needs permanent retention.

### Current provider decision — 18 October 2026

Use **TMDB** for initial search, metadata, verified identity selection, external IDs, credits, poster/backdrop references and trailer references. Use free developer access; paid data/media plans are outside the budget. Media is a core discovery requirement. Retain Glutton-owned film IDs, provider identifiers and provenance behind a narrow TMDB adapter; do not implement multiple providers pre-emptively. Independently researched analyses and viewer expressions remain the basis of AI processing. Keep TMDB-derived content out of model inputs for now, including credits used as classification candidates unless independently verified; this separation does not itself resolve the broad AI-use clause.

Use supported host embeds for trailers, validate language/identity/playback, and review media/overviews for spoiler suitability. Keep artwork replaceable with an accessible fallback. A TMDB country-specific watch-page link is an optional MVP addition; direct provider deep links are not supplied by that endpoint. Preserve attribution requirements for TMDB and, where watch-provider data is used, JustWatch.

The owner explicitly chose to proceed for now despite unresolved AI-use, donation and media-rights questions. Do not represent the integration as approved by TMDB or impose written confirmation as an agreed development/release gate. On 20 October 2026 the owner completed TMDB API-key signup and reported receiving an API key and application read-access token. The read-access token is configured in ignored local environment settings; it has not been inspected or live-tested by the implementation agent. No provider enquiry has been sent. Respect documented API/retention limits and preserve a straightforward replacement path. Earlier source evaluations below are background findings, superseded where they propose TheTVDB as the initial provider.

Commercial pricing note — 20 October 2026 (owner-reported during signup, not independently verified): TMDB commercial access was quoted as **US$149 per month** for an application with **less than US$500,000 in annual revenue or fewer than 500,000 monthly active users**, preserving the eligibility wording reported by the owner. This is a planning reference, not a purchase or subscription commitment; paid access remains outside the currently authorized implementation scope.


### Initial metadata-source investigation — 18 October 2026

At the time of this investigation TMDB was a candidate; it is now selected under the current provider decision above, without a claim of provider approval. Its [FAQ](https://developer.themoviedb.org/docs/faq) describes free attributed non-commercial use and defines commercial purpose in terms of owner revenue. However, the [current API terms](https://www.themoviedb.org/api-terms-of-use), inspected directly on 18 October 2026 and marked last updated 20 October 2023, define revenue-related use more broadly, restrict AI-connected use in section 1.C, and limit caching to six months. No current explicit donation exemption was found. Older permissive staff forum replies predate these terms and do not settle the proposed use.

Possible follow-up: seek written clarification of a free horror-discovery site accepting optional operating-cost donations, and of metadata/poster display alongside AI scoring of independently researched analyses and viewer expressions. Distinguish display-only use from sending TMDB content to models; do not assume either is permitted. Also clarify metadata refresh/retention and stable identifier storage. No enquiry has been sent and no API account or key was used in this investigation.

A preliminary public-website spot check found records for seven deliberately varied films: [Alucarda](https://www.themoviedb.org/movie/40074), [A Page of Madness](https://www.themoviedb.org/movie/94525), [Tumbbad](https://www.themoviedb.org/movie/538858), [Saloum](https://www.themoviedb.org/movie/858096), [Skinamarink](https://www.themoviedb.org/movie/994143), and separate [1977](https://www.themoviedb.org/movie/11906) and [2018](https://www.themoviedb.org/movie/361292) Suspiria records. All were found through live website search; detailed records were inspected for Alucarda and A Page of Madness. Both detailed records expose posters, credited people and video links. Presence does not establish metadata accuracy, trailer suitability, API completeness or UK offer accuracy.

A Page of Madness has a 1926 identity heading but a 1973 GB release date in the search presentation; Tumbbad's search presentation similarly shows a 2024 date. Import must distinguish original identity year from regional/re-release dates. Search also returns unrelated and similarly named works, so require explicit selection and identity confirmation rather than accepting the first match blindly.

This small sample supports further evaluation, not a catalogue-wide coverage claim. The referenced 50-film seed assets were not present in the project or Desktop file search, so the complete seed has not been audited. Once the seed and authorised API access are available, assess correct identity, external IDs, credits, original/alternative titles, release dates, images, trailer availability and UK watch links across the seed and an additional obscure/international sample. Do not use TMDB's horror genre label as the sole admission rule for Glutton.

For MVP, a supplied TMDB watch-page link is a candidate alternative to omitting availability. The [watch-provider endpoint](https://developer.themoviedb.org/reference/movie-watch-providers) documents country-specific provider data and a TMDB onward-link URL, not full provider deep links; JustWatch attribution is required. A dedicated availability provider can be selected later independently of metadata import and recommendation ranking.

### TheTVDB alternative investigation — 18 October 2026

TheTVDB is a viable metadata candidate, not yet selected. Its [API pricing page](https://thetvdb.com/api-information) lists free attributed access below $50,000 annual company revenue, with annual tier review and consideration of parent-company revenue. If this alternative is adopted, use project-licensed access rather than requiring Glutton viewers to buy TheTVDB subscriptions. Older support material describes negotiated licensing and user-supported keys; confirm the applicable current signup terms.

The [public terms](https://thetvdb.com/tos) contain no explicit AI/ML prohibition found in this review. API permission is project-specific, based on the use disclosed when applying. Absence of a prohibition is not an affirmative provider decision about Glutton. Crucially, the terms explicitly exclude image/trailer display rights from the API licence; media permissions require separate investigation.

The [official v4 specification](https://github.com/thetvdb/v4-api/blob/main/docs/swagger.yml) supports movie search, aliases/translations, external identifiers, extended movie records, artwork/trailers and update workflows. Its score field is a popularity hint, not a viewer rating. Schema support does not establish field completeness or media rights.

Catalogue verification remains limited: a fetched [Tumbbad record](https://thetvdb.com/movies/tumbbad) includes identity, release date, external links and trailer metadata, but the retrieved snapshot is old and has sparse credits (two cast entries, one director). Other sample pages could not be retrieved, and live browser search stalled; these failures are not evidence that the films are absent. No authenticated API calls or account signup were performed. Full seed and obscure/international coverage, credits accuracy, current API payloads and a separate UK availability source remain to be evaluated before provider selection.

### Further media-provider investigation — 18 October 2026

[Fabric Origin Nexus](https://www.fabricdata.com/origin-nexus), formerly IVA, explicitly advertises licensed and warranted imagery and promotional video, alongside metadata and availability. This is the strongest public rights statement found so far. Its [AWS Marketplace listing](https://aws.amazon.com/marketplace/pp/prodview-p27uigdqu2blu) lists a one-month production package at $6,000/month; this is a published package, not proof of its cheapest available direct arrangement. A small-catalogue quote, territorial/media scope, AI-assisted-app permission and horror coverage would require provider confirmation.

[Watchmode's current terms](https://api.watchmode.com/tc), dated 1 September 2026, explicitly exclude third-party-image rights from its licence and prohibit hotlinking to its own CDN. It does not meet the preferred artwork-rights requirement despite returning media URLs.

Movie of the Night documents hosted images and subscription-dependent image use in its [published terms](https://github.com/movieofthenight/streaming-availability-api/blob/main/TERMS.md), but a clear chain-of-rights warranty for film artwork was not established. Treat it as a candidate for clarification, not confirmed rights-cleared artwork. Gracenote and Getty offer imagery products, but suitable film-page rights, pricing and AI terms have not been established for Glutton.

Trailers need not be licensed for local hosting: official studio/distributor uploads can be candidates for the standard [YouTube embedded player](https://developers.google.com/youtube/player_parameters), subject to platform requirements, uploader permission and actual embed availability. Embedding is distinct from downloading or rehosting a trailer and does not solve poster rights. For the small seed catalogue, manually curated trailer IDs and separately permissioned distributor artwork are a possible alternative to an enterprise media bundle. No provider was contacted or selected.

### TheTVDB + KinoCheck live feasibility check — 18 October 2026

Zero-cost access is a firm constraint. Media is an important part of the core recommendation experience, not merely optional decoration. TheTVDB was the proposed metadata/search provider during this trial and is now an alternative; no authenticated API trial or account registration has yet been completed.

Five live TheTVDB page reads confirmed IMDb links for The Thing (tt0084787), Alien (tt0078748), Get Out (tt5052448), Hereditary (tt7784604) and Tumbbad (tt8239946). These IDs join directly to KinoCheck's documented IMDb lookup; no TMDB API dependency is required. This verifies website identifiers, not authenticated TheTVDB payloads or search behaviour.

Twelve live KinoCheck movie lookups with language=en returned:

| Result | Films |
| --- | --- |
| English trailer and thumbnails returned (4) | Suspiria (2018), Get Out, Hereditary, Nosferatu (2024) |
| Movie record, no English videos (3) | The Thing, Alien, Skinamarink |
| Movie not found for tested IMDb lookup (5) | Suspiria (1977), Alucarda, A Page of Madness, Tumbbad, Saloum |

This is a deliberately mixed convenience sample, not a statistically representative coverage estimate. Every lookup returned HTTP 200, including application-level movie-not-found errors: adapters must inspect response bodies. All four successful trailer results supplied KinoCheck and YouTube thumbnails that returned HTTP 200 with image/jpeg, and YouTube oEmbed returned matching KinoCheck.com video metadata. Actual browser playback, UK territorial restrictions, age gates, visual/spoiler suitability and long-term availability were not verified.

[KinoCheck documentation](https://api.kinocheck.com/) advertises free official film materials, 1,000 daily requests, and thumbnail mirroring. It returns video thumbnails rather than a comprehensive poster catalogue. The [API terms](https://kinocheck.com/api-terms-of-use) reviewed contain no explicit AI restriction, but no comprehensive rights warranty was established. Use supplied thumbnails to represent their associated playable videos; standalone artwork reuse needs clarification.

Conclusion: technically feasible as a supplementary media source, insufficient as the sole media source for Glutton's diverse horror catalogue in this test. Plan editorially selected official YouTube trailers as fallback, retain source/identity/language and review status, and keep media independently replaceable. A film metadata record must not be mistaken for media readiness. Before committing the complete discovery experience, audit the actual seed and validate playback and presentation. No paid option, provider contact or signup was used.

## 10. Persistence and PostgreSQL learning plan

Prefer relational tables and constraints for stable identities, ownership, relationships, state and queryable scoring evidence. Consider JSONB for sourced context and evolving provider payloads where justified; do not hide core relationships in opaque documents.

Candidate persistence groups include films and external identities; sources and current source revisions; quality categories, qualities and accepted film associations; library entries, rating/expression revisions and submissions; profile revisions; assessment runs and quality evidence; recommendation deliveries/responses; and inaccuracy reports. This is a conceptual inventory, not a committed table list.

Database invariants should include one current library relationship per viewer/film, valid rating values, foreign-key integrity, and uniqueness for idempotent processing identities. Decide revision retention and current-record pointers explicitly before implementing constraints.

Design and measure the principal access paths:

- Find eligible recommendation candidates by excluding a viewer's classified films.
- Select rating-flow candidates without repeating confirmed-unseen films; include watched films awaiting ratings.
- Read the viewer's watched films awaiting ratings and paginate each library view.
- Retrieve current per-quality preference evidence and candidate film associations.
- Find assessments affected by a changed profile, accepted film-quality change or semantic quality revision; a source refresh alone does not qualify.
- Aggregate scores without counting superseded assessments.

Use representative generated data and PostgreSQL execution plans to guide indexes and query changes. Measure query latency and rows processed before introducing cached aggregates, materialized views, partitioning or specialised infrastructure. These exercises should support real application access patterns.

## 11. Rails workflow and operational boundaries

Application operations coordinate save-rating, classify-library-entry, assess-film, update-profile, refresh-scores and obtain-recommendations workflows. Domain rules should remain explicit and testable without being scattered across callbacks. Callbacks, if used, should have narrow local responsibilities.

Do not hold database transactions open during external model calls. Assessments should have explicit pending, running, succeeded and failed states as needed, attempt metadata and retry policies. Use input-version checks before publishing results so delayed jobs cannot replace newer results.

Track model/provider identity, prompt or method version, relevant input revisions, latency and cost where available. Deduplicate work, set usage limits, and retain the minimum provider payload necessary for diagnosis and reproducibility. Logs should avoid unnecessary expression text or other private data.

**Authentication decision — revised 19 October 2026:** Use Rails-native email/password authentication for registered accounts, starting from Rails' authentication generator/primitives. Add application-owned registration and email verification. Claimable guests are an application design, not a built-in Rails convention. This supersedes passwordless magic links.

Identity owns one users table with stable internal IDs, using Rails single-table inheritance with a concrete `User` base and lifecycle subclasses `UserGuest`, `UserRegistered` and `UserDeleted`. Introduce each subtype only when its behaviour is implemented. `User#active?` returns true; `UserGuest` overrides it to return true only before `created_at + UserGuest::EXPIRY_DURATION`, without a stored deadline; `UserDeleted#active?` always returns false. Changing the lifetime policy affects existing guests. Create an email-free guest when first saving personal activity; no fabricated credentials. Use one server-side Session model for guests and registered users. An active guest can receive a session without credentials; a registered session requires password authentication. Both support revocation and reject inactive owners. Guest cookies have browser-session lifetime; registered cookies follow Rails authentication conventions. The protected cookie references the Session record, not just the user ID. Task 005 supplies this shared lifecycle; task 005a replaces the earlier guest-only user-ID binding with shared-session resolution. The cookie is not a tab-lifetime guarantee, and browser session restoration may preserve it. Independently enforce a fixed 24-hour deadline from guest creation on every guest access; activity never renews it. Missing/invalid sessions and expired guests must not grant access to old activity. Cookie expiry does not delete database records.

Store unverified email and password digests in a separate PendingRegistration, with an optional guest reference; do not store unverified email on User or identify/access an existing user by it. Direct signup creates no User record by itself. If the person begins guest activity in the same browser before confirming, an Identity-owned operation must bind the new guest to that pending request using trusted browser/session state, never email matching; specify conflicting-link handling and test this journey in the UI task. Confirmation without a linked guest upgrades the current active guest when one is present; otherwise it creates a UserRegistered. Task [006r](specs/006r_confirmation_guest_attachment.md) removes the browser-held pending ID from confirmation: the token identifies the registration and the current session identifies the guest. A different linked guest, a registered current user or another pending request already linked to the current guest remains a conflict. Delete the pending row atomically when either confirmation path succeeds, retaining no duplicate completed credential record. For guest signup, confirmation upgrades the linked active guest in place, preserving its internal ID and domain-owned activity, and rotates the session. Confirmation must reject an expired linked guest rather than silently switching to direct signup. Require email, a securely hashed password and confirmed mailbox ownership to complete registration. Submitting the registration form alone does not complete the guest-to-registered transition. Specify pending-registration access, expiry and cleanup behaviour in the registration/confirmation specs before implementation. Confirmation tokens are purpose-scoped and valid only while the pending registration remains active, with no independent token timer. Resending does not extend the registration deadline; credential changes/replacement also invalidate links. Pending requests own a one-hour deadline from creation, configured by PendingRegistration::EXPIRY_DURATION and additionally require their linked user to remain active. Guest expiry stays internal to UserGuest; registration does not read or expose its deadline. Completion atomically creates/upgrades the account, revokes all old guest sessions, issues a fresh Session and deletes the pending request; expected conflict/expiry/replay failures grant no access. Task 006f supplies registration/confirmation HTTP wiring, bounded synchronous mail delivery and browser session binding. Confirmation GET only renders a form; a CSRF-protected POST completes registration. Pending browser ownership is tracked by ID in the encrypted Rails session, with guest attachment and visible expiry. Confirmation links use explicit APP_ORIGIN configuration; SMTP runs after attempt reservation commits, with no database locks held across network calls. New pending registrations reject an already registered normalized email with sign-in guidance and send no confirmation; stale pending requests cannot resend after that email registers. The form intentionally reveals registered-email availability, but an entered email never grants identity or access. Final confirmation still enforces uniqueness for concurrent requests. An expired guest cannot be claimed. Signing into an existing account requires authentication and does not automatically transfer or merge guest records. Guest-aware account validations and database constraints must be specified before credentials are introduced. Permit guest-to-registered transition only before expiry and after email confirmation; registered-to-deleted transition anonymises the account and revokes sessions. Deleted accounts cannot regain access. A browser still holding a deleted-account identity receives an explicit account-deleted failure on identity-dependent requests; it must not silently fall back to a guest. Retain the failure across requests until the session is explicitly reset. Implement transitions explicitly in their respective Identity tasks.

Domain-owned capability modules are included by the user subclasses that support them; shared guest/registered behaviour belongs in those modules, not type-switching branches in `User`. Operations require `active?` and enforce ownership. Deleted users receive no product capability modules; the inactive predicate does not replace session revocation during deletion. Admin permissions are separate from lifecycle subtypes. Capability modules organise access to domain behaviour; inclusion in an Active Record class does not isolate that behaviour from persistence. Keep substantial rules independently testable as described in section 3, with modules delegating to domain-owned rules/operations where needed. Do not create empty capability modules in advance.

Library entries, ratings, expressions and preference data reference internal user IDs for both guests and registered accounts. Domain operations enforce the current identity's ownership. Identity owns guest expiry; each domain retains ownership of deleting its activity. Before implementing cleanup across domains, review ownership and agree a concrete deletion policy, including transactional cascades where appropriate and safe handling of queued events. Use the approved scoped retention and event-delivery contracts; do not introduce a generic integration layer. Scheduled cleanup must recheck guest state so registration cannot race with deletion; define the schedule and failure/retry behaviour in its spec. Expired access is rejected independently of eventual cleanup.

Task 006d supplies Identity::CleanupExpiredAccounts.call(batch_size: 100) and `bin/rails identity:cleanup_expired`. SQL selects bounded oldest-first expiry candidates; per-candidate transactions lock/recheck current state and delete expired guests with their Sessions/PendingRegistrations or independently expired pending rows. Guest-before-pending lock order matches registration. Registered/deleted accounts and active guests are retained. Failures roll back the current candidate and stop; earlier commits remain, and re-running is safe. Counts include pending rows removed with guests. The proposed cadence is every 15 minutes, but scheduler deployment is not implemented and backlog size affects physical deletion delay. Task 010 adds Library-owned watched activity with an owner-approved scoped user foreign-key cascade: physical guest deletion removes its LibraryFilm rows in the same transaction and keeps shared Film rows, while in-place claim retains Library ownership. This requires no Identity implementation change. Before other product domains persist guest activity, agree their domain-owned deletion without bypassing foreign keys. Cleanup limits guest candidates, not the number of Library rows belonging to each candidate. Task 001i enables Active Job with an external GoodJob worker; domain event consumers and scheduler deployment remain separate tasks.

Task [006o](specs/006o_authentication_reset_serialization.md) (Merged via PR #22) makes credential verification and session issuance share the user lock held by password recovery: reset revokes an earlier sign-in, and an earlier reset prevents subsequent issuance using the old password. Task 006c supplies password recovery using Rails-native UserRegistered reset tokens with a 15-minute expiry and password-salt binding. Identity::RequestPasswordReset uses normalized registered-email lookup and synchronous mail outside transactions. Identity::ResetPassword locks/revalidates the target, saves a policy-valid password and revokes all its Sessions atomically; concurrent redemption has one winner. GET only renders; CSRF-protected PATCH resets without automatic login. Same-account browser state is cleared, other registered identities conflict, and unrelated guest/pending state survives without merging. Request IP/email-fingerprint and update IP limits use per-worker memory stores; shared multi-worker controls remain a release prerequisite. APP_ORIGIN validation is shared with confirmation through the minimal Identity::MailOrigin helper.

Use secure sessions, HTTPS in production, restricted database access and filtering of email, passwords and authentication tokens from routine logs. Keep email out of model inputs and analytics. Resend is the provider for verification/password-reset delivery; use local mail previews and non-network delivery by default, with explicitly configured Resend delivery available in development for end-to-end verification. Rails Action Mailer owns multipart confirmation/reset templates and development-only previews; explicit SMTP mode uses required STARTTLS and certificate verification. Development loads ignored dotenv settings; production uses process environment. Mail logging is disabled to exclude recipients, credentials and token-bearing bodies. Callers supply authorized recipients and HTTPS links; composition performs no account transitions. Tests always remain non-network. Registered sessions follow Rails authentication conventions: persistent signed cookies backed by revocable server-side sessions, without a custom age deadline. Guest expiry remains separate. Registered-account deletion and scheduler deployment remain separate work. Do not require names, demographic fields or public profiles. Separate identity infrastructure, custom email encryption and email-lookup hashes are not initial requirements; a complete database exposure can still link registered email to preferences.

Viewer submissions and profiles are private by default; sharing expressions as inspiration requires separate consent and moderation. Source attribution and provider reuse terms must be checked before publishing catalogue material.

## 12. Evaluation and delivery

Develop complete working slices:

1. Validate a small catalogue subset; implement independent viewing status and library classification, confirmed-unseen exclusion from rating prompts, direct watchlist addition, spoiler-labelled film-information navigation, ratings and multiple expressions.
2. Establish JEV scoring contracts and a rating-only recommendation baseline.
3. Add explicit scoring and profile synthesis using the prior-profile rule.
4. Add historical reassessment, freshness tracking and before/after ranking evaluation.
5. Complete discovery presentation, library management, film-information visibility and quality reporting; expand the validated seed catalogue.

The first public loop requires all core behaviours above. External imports and conversational reflection do not block it.

Evaluate rating-only versus expression-informed recommendations, positive and negative recurring patterns, contextual expressions, conflicting evidence, and profile changes that do or do not warrant refresh. Verify that identical repeated processing does not amplify evidence.

Workflow tests should cover retry/idempotency, concurrent profile updates, stale results, edits/deletions, prior-profile capture and recommendation exclusion for every library classification. Also verify persistence of confirmed-unseen status, its exclusion from rating prompts but not recommendations, direct watchlist addition, preservation of viewing status when classification is removed, and eligibility for rating after marking watched. Benchmark classification precision/recall, the novelty gate, recommendation usefulness, latency and cost separately.

## 13. Decisions still to make

- Select production deployment and the job approach when deferred processing is introduced. Rails, PostgreSQL and server-rendered Hotwire are the implemented framework choices.
- Define JEV assessment inputs and outputs, and validate required provider capabilities.
- Define implicit/explicit aggregation and the initial recommendation ranking formula.
- Define expressions profile structure, synthesis inputs and revision semantics.
- Choose refresh cadence, material-change criteria and user-visible processing states.
- Specify re-rating, expression editing/deletion and library-transition behaviour.
- Agree source/evidence coverage, accepted film-quality changes and spoiler-safe presentation; resolve independent analysis-model retention.
- Decide what recommendation evidence and delivery history to retain for evaluation.

These decisions should be recorded with their reasoning, observed results and conditions for revisiting them. Domain boundaries and abstractions should evolve in response to those findings.

## 14. Implementation and review workflow

Follow [the implementation plan](implementation_plan.md) and [repository instructions](../AGENTS.md). Before implementing each small task, create a focused spec under `specs/` using [the template](task_template.md). Define scope, scope restrictions and acceptance criteria with verification methods in advance; record actual evidence under the criteria and summarise changes/deviations afterward. Ready for review is distinct from owner acceptance and merge. The [initial scaffold spec](specs/001_initial_scaffold.md) covers only local Rails/PostgreSQL boot and setup; it does not authorise implementing authentication or the product loop.

Implementation tasks belong to one domain/supporting area and one focused capability where practical. First review any apparent cross-domain work for an incorrect boundary or misplaced invariant. If ownership remains sound, consume established contracts without modifying the other domain; necessary changes require separately scoped work. UI wiring is no exception. Introduce concrete structures only when needed.

### User-facing copy

Use standard Rails i18n locale entries for application UI, flash/error text, mail subjects/bodies and custom validation messages. Start with English only; use semantic keys, interpolation and standard Active Model error symbols. Translate at rendering/action time, not in constants evaluated at boot. Keep locale values plain text and let views escape them. Missing translations raise in development/test. Developer diagnostics and static emergency error pages remain independent of translated application rendering.

## Ratings workflow clarification — 21 October 2026

Owner-approved simplification supersedes the earlier Ratings seen/unseen question and presentation-history proposals: present a film for rating or dismissal. A dismissal only removes it from automatic Ratings rotation; it does not assert that the user has not seen it or change recommendation eligibility or Library classification. Store current queue/selection/dismissal on one RatingFilm per user/film, without presentation history or dismissal reasons. Later Library viewing evidence preserves explicit rating dismissal. The user can explicitly initiate rating from Library through the later targeted-entry task. Watchlist and not-interested-in-watching choices remain in Library and Recommendations; Ratings-flow action requests are deferred. See task 013 for current implementation scope.

Ratings candidate ordering clarification: the owner subsequently approved oldest-first batches from a single persistent RatingFilm queue. Candidates admitted by future Library watched events and unfinished catalogue candidates use the same created_at/ID order; newly watched entries do not jump the queue. The row stores user, film, boolean dismissal and standard timestamps only. Selection records no presentation/current state. Task 014 adds the real ratings relationship and rated/unrated scopes; selection then excludes rated rows. Catalogue replenishment fills only batch shortfalls under a separately approved policy, preserving all existing user/film records and dismissal. This supersedes earlier watched-first priority descriptions.

## Mobile-first navigation — 26 October 2026

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. Ratings is the default landing destination; there is no separate product homepage.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library has one collection page. A labelled dropdown at the top selects Watchlist (the default), Watched or Not interested. Use the platform-native select on mobile; preserve the same control on desktop. Selection is reflected in the URL, so refresh, sharing and back/forward restore the selected view. A bare Library URL opens Watchlist; changing the view resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with roomier film rows; keep the Library dropdown above the list. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

This is the agreed navigation design, not a claim that every destination is implemented. Shared navigation/default-route wiring belongs to a narrowly scoped supporting UI task; Recommendations content and first-visit Ratings discovery still need their own implementations. Do not add dead links or invent placeholder product flows merely to complete the navigation. Task 020 supplies the Library page and its three read-only views; task 021/022 can add their respective management actions.

### Controller organisation

Use one top-level controller named after each product domain for now: `RatingsController` and `LibraryController`, with conventional `app/views/ratings` and `app/views/library` templates and no route module scopes. Domain services and errors retain their namespaces and are explicitly qualified by controllers. Controller namespaces are unnecessary while each domain has a single controller; revisit only when a concrete organisational need arises. This does not change mutation ownership or permitted shared reads.

The Library is a singular resource (`LibraryController#show`); the current rating interaction is a singular resource exposing `new`, `create` and `dismiss` through `RatingsController`. Use `/library` and `/rating` routes rather than implying a collection of libraries or a ratings index.

Controllers that require a session opt in with `before_action :require_identity`. The private ApplicationController method uses existing Identity session resolution and raises `Identity::Required` for absence. Controllers own their signed-out responses and also retain handling of domain service identity failures. This is not a global callback: public Identity entry points remain accessible. Services still validate fresh user state independently.

Library film details use the owner-scoped LibraryFilm ID and remain in LibraryController. Owner revision for task 022: use a shared detail composition with partials named for actions/information, such as mark_watched and rating_status. Guard actions directly through model-owned permissions (for example, can_watch?), with narrowly scoped removal permissions or information behaviour where needed. Do not select partials using LibraryFilm types, implicit subtype rendering, type switches or unrelated capability inference. Models retain the rules, subclasses supply their supported behaviour, and services enforce fresh state; transition services still return the updated concrete submodel. This supersedes task 021's subtype-partial decision, not its relationship or action boundaries. Existing-entry action resolution and transition must share the appropriate owner/entry lock protection so stale IDs cannot recreate a removed relationship. User actions have one contract each: user_id plus the existing library_film_id. RecordWatched, AddToWatchlist, MarkNotInterested, RemoveFromWatchlist and RemoveNotInterested resolve the exact owned row, use model permissions, and transition/remove with atomic publication; there are no film-ID creation branches or duplicate entry wrappers. Ratings entry continues to use the shared Film ID.

Library creation boundary (owner decision, task 022a): current creation is in the Library Ratings-event handler. Accepted recommendations may establish entries through a future Library event handler once specified. A future TMDB search can offer Rate this film (the existing Ratings admission boundary) or explicit Add to watchlist (a separately scoped creation operation followed by a redirect to the created LibraryFilm ID). Do not create Library entries during detail GET or accept a shared Film ID as an alternate detail lookup. No recommendation/search implementation is implied by this design.
