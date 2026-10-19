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

The library provides To watch, Watched and Not interested views. Watched films may be awaiting a rating or already rated. Users can revisit and change ratings and expressions, reconsider dismissed films, and inspect film analyses through spoiler-labelled links normally shown in the watched Library view.

Viewing status (unknown, confirmed unseen, watched) is distinct from library classification. Confirmed-unseen films need not belong to a classified library view. Marking one watched through the library or discovery makes it available for rating. Removing an unwatched film's classification makes it eligible for recommendations again, while preserving confirmed-unseen status and its exclusion from rating prompts. Exact transitions between existing library choices, and their UI wording, need specification before implementation.

A separate conversational reflection interface is a possible future feature, not required for the core product or initial architecture. Community editing, streaming availability, donations and affiliate integrations are also later concerns.

## 3. Proposed system shape

Use a cohesive Ruby on Rails application backed by PostgreSQL. Initial scaffolding uses server-rendered views and Hotwire; the scoped implementation plan records the delivery sequence. No current behaviour requires independently deployed services.

Organise code around domain responsibilities with explicit application operations for workflows. Keep substantial product decisions—such as rating transitions, recommendation eligibility, scoring and preference calculations—in ordinary Ruby objects with explicit inputs/results, independently testable without Rails boot or database records. Application operations load the required state, invoke those rules, persist results and coordinate established synchronous domain contracts within agreed transaction boundaries. Keep database constraints for persisted invariants; independent rule tests do not replace persistence or workflow tests.

Keep standalone models and root model classes directly under `app/models/`, following Rails' default file mapping. Group subclass files under a folder named for their superclass: `app/models/user.rb` defines User, while `app/models/user/` contains `guest_user.rb`, `registered_user.rb` and `deleted_user.rb`. Session lives in `app/models/session.rb` without a folder. Explicitly collapse only organisational subclass directories in Zeitwerk to preserve class names and STI values. Genuine namespace directories remain namespaces; do not create empty folders or add rules for standalone models.

Active Record remains appropriate for persistence and straightforward local behaviour, including Identity credentials, password hashing and account validation. Declare built-in validations directly in their models; reserve extracted capability modules for meaningful domain behaviour rather than sharing validation declarations. Do not duplicate that model in a separate entity/repository layer without a concrete need. Extract stronger persistence boundaries where domain complexity or tests show the benefit. Use background jobs for deferred processing. Avoid introducing engines, generic repositories, event sourcing or a messaging platform without a concrete need.

Keep external-provider calls behind narrow adapters. Initial boundaries cover JEV assessment, Claude profile synthesis, metadata lookup and film research/analysis. These boundaries should expose the operations Glutton requires rather than reproduce every provider API.

Use local PostgreSQL for development. Railway plus Neon is the owner’s familiar deployment option, with production hosting still to be selected. Server-rendered Rails views and Hotwire are the initial frontend direction. Job backend and specific provider/model versions remain undecided; background processing is a separate task after the minimal scaffold. Modest model API development costs are acceptable; expensive data/media licences are not. The owner has a Claude API key and can create a JEV key; keep credentials out of source control.

## 4. Domain responsibilities

Boundaries follow distinct activities and their language, not a generic user–film table. They remain testable modelling decisions rather than prescriptions for Rails engines or independent services.

| Area | Owns | Boundary |
| --- | --- | --- |
| Film knowledge | Film identity, metadata/media, sourced analyses, vocabulary and film–quality assessments | Shared knowledge independent of viewers |
| Library | Canonical user–film relationship: watchlist, watched and not interested; library management | Does not own purpose-specific presentation histories, ratings or inferred preferences |
| Ratings | Rating presentations and responses, ratings, original expressions, scoring, expressions profiles and inferred preferences | Rating submission, scoring and profile building are distinct capabilities; Ratings requests canonical state changes through Library operations |
| Recommendations | Selection, eligibility, ranking, explanations, presentation and response history | Reads Library classifications and Ratings preferences; requests Library actions without owning their state |

Ratings contains separate capabilities for recording evidence, scoring, profile building and reassessment. They share domain language; the original evidence/inferred interpretation distinction remains an invariant inside this domain, not a separate Taste boundary. Library is the canonical collection, while Ratings/Recommendations records describe their specific activities. These records need not share a data model.

A Ratings “haven’t seen it” response suppresses later rating prompts without creating a Library entry or excluding recommendation eligibility. Recommendations assumes candidates are unwatched absent evidence otherwise; its exclusion rule uses Library's classifications, not the mere existence of any user–film record. Library owns watched-but-unrated films and links to Ratings. Its rated display reflects Ratings' authoritative current rating rather than owning a duplicate value.

Film knowledge owns the shared quality vocabulary; Ratings interprets it as evidence about a viewer. Dynamically source people candidates from verified credits. Any apparent need to change multiple domains requires a boundary/invariant review before creating provider/consumer tasks; an occasional stable interaction is not inherently a modelling defect.

## 5. Core concepts and invariants

- **Film:** A distinct work identified consistently across imports, including remakes and versions where relevant.
- **Film analysis revision:** A reusable, sourced account containing description and supported interpretation. Analysis is richer than the current quality vocabulary.
- **Film–quality assessment:** A versioned interpretation that a film exhibits a quality, with sufficient provenance for reassessment.
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

### Synchronous domain contracts

Use explicit synchronous operations for communication among Ratings, Library and Recommendations. Agree inputs, results and failure behaviour before implementation; implement and test the provider and consumer sides in separate domain-owned tasks. Do not introduce events or asynchronous domain synchronization. Deferred AI assessments remain separate.

Ratings selects films using its own presentation/queue state. Seen confirmation alone creates no Library record. A completed rating invokes Library's record-watched operation. Separately, Library's user mark-watched workflow invokes Ratings' make-available operation, overriding prior unseen suppression while avoiding requeueing already-rated films. The record-watched operation used by Ratings does not call back into Ratings. Specify rollback/retry behaviour before implementing consumers; synchronous calls alone do not guarantee atomic persistence.

Film analyses are directly accessible; normal navigation is through spoiler-labelled links on the watched Library view, without a Library-based authorization gate.

## 6. Saving a rated film

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

## 9. Film knowledge pipeline

Begin with the diverse 50-film research catalogue, treating existing model-drafted material as experimental until validated. Film analyses should preserve sources, uncertainty, descriptive versus interpretive distinctions, and analysis/prompt revisions.

Keep research/analysis separate from quality association. Vocabulary changes should permit reassociation without regenerating the underlying analysis. Analyses may be incomplete where evidence is insufficient.

Expose directly accessible readable analyses with clear spoiler labelling and normal navigation from the watched Library view, with a manual inaccuracy-reporting workflow from the first release. Reports identify the film and preferably the disputed section; they do not directly alter published content. Community editing is deferred.

Later user-requested imports should deduplicate by stable external identity and use the same analysis contract. Metadata identity can become available before enrichment completes.

### Current provider decision — 18 October 2026

Use **TMDB** for initial search, metadata, verified identity selection, external IDs, credits, poster/backdrop references and trailer references. Use free developer access; paid data/media plans are outside the budget. Media is a core discovery requirement. Retain Glutton-owned film IDs, provider identifiers and provenance behind a narrow TMDB adapter; do not implement multiple providers pre-emptively. Independently researched analyses and viewer expressions remain the basis of AI processing. Keep TMDB-derived content out of model inputs for now, including credits used as classification candidates unless independently verified; this separation does not itself resolve the broad AI-use clause.

Use supported host embeds for trailers, validate language/identity/playback, and review media/overviews for spoiler suitability. Keep artwork replaceable with an accessible fallback. A TMDB country-specific watch-page link is an optional MVP addition; direct provider deep links are not supplied by that endpoint. Preserve attribution requirements for TMDB and, where watch-provider data is used, JustWatch.

The owner explicitly chose to proceed for now despite unresolved AI-use, donation and media-rights questions. Do not represent the integration as approved by TMDB or impose written confirmation as an agreed development/release gate. No API key, account signup or provider contact has yet been performed. Respect documented API/retention limits and preserve a straightforward replacement path. Earlier source evaluations below are background findings, superseded where they propose TheTVDB as the initial provider.

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

Prefer relational tables and constraints for stable identities, ownership, relationships, state and queryable scoring evidence. Consider JSONB for structured analysis content and evolving provider payloads; do not hide core relationships in opaque documents.

Candidate persistence groups include films and external identities; analysis revisions and sources; qualities and film associations; library entries, rating/expression revisions and submissions; profile revisions; assessment runs and quality evidence; recommendation deliveries/responses; and inaccuracy reports. This is a conceptual inventory, not a committed table list.

Database invariants should include one current library relationship per viewer/film, valid rating values, foreign-key integrity, and uniqueness for idempotent processing identities. Decide revision retention and current-record pointers explicitly before implementing constraints.

Design and measure the principal access paths:

- Find eligible recommendation candidates by excluding a viewer's classified films.
- Select rating-flow candidates without repeating confirmed-unseen films; include watched films awaiting ratings.
- Read the viewer's watched films awaiting ratings and paginate each library view.
- Retrieve current per-quality preference evidence and candidate film associations.
- Find assessments affected by a changed profile or film-knowledge revision.
- Aggregate scores without counting superseded assessments.

Use representative generated data and PostgreSQL execution plans to guide indexes and query changes. Measure query latency and rows processed before introducing cached aggregates, materialized views, partitioning or specialised infrastructure. These exercises should support real application access patterns.

## 11. Rails workflow and operational boundaries

Application operations coordinate save-rating, classify-library-entry, assess-film, update-profile, refresh-scores and obtain-recommendations workflows. Domain rules should remain explicit and testable without being scattered across callbacks. Callbacks, if used, should have narrow local responsibilities.

Do not hold database transactions open during external model calls. Assessments should have explicit pending, running, succeeded and failed states as needed, attempt metadata and retry policies. Use input-version checks before publishing results so delayed jobs cannot replace newer results.

Track model/provider identity, prompt or method version, relevant input revisions, latency and cost where available. Deduplicate work, set usage limits, and retain the minimum provider payload necessary for diagnosis and reproducibility. Logs should avoid unnecessary expression text or other private data.

**Authentication decision — revised 19 October 2026:** Use Rails-native email/password authentication for registered accounts, starting from Rails' authentication generator/primitives. Add application-owned registration and email verification. Claimable guests are an application design, not a built-in Rails convention. This supersedes passwordless magic links.

Identity owns one users table with stable internal IDs, using Rails single-table inheritance with a concrete `User` base and lifecycle subclasses `GuestUser`, `RegisteredUser` and `DeletedUser`. Introduce each subtype only when its behaviour is implemented. `User#active?` returns true; `GuestUser` overrides it to return true only before `created_at + 24.hours`, without a stored deadline; `DeletedUser#active?` always returns false. Changing the lifetime policy affects existing guests. Create an email-free guest when first saving personal activity; no fabricated credentials. Use one server-side Session model for guests and registered users. An active guest can receive a session without credentials; a registered session requires password authentication. Both support revocation and reject inactive owners. Guest cookies have browser-session lifetime; registered cookies follow Rails authentication conventions. The protected cookie references the Session record, not just the user ID. Task 005 supplies this shared lifecycle; task 005a replaces the earlier guest-only user-ID binding with shared-session resolution. The cookie is not a tab-lifetime guarantee, and browser session restoration may preserve it. Independently enforce a fixed 24-hour deadline from guest creation on every guest access; activity never renews it. Missing/invalid sessions and expired guests must not grant access to old activity. Cookie expiry does not delete database records.

Store unverified email and password digests in a separate PendingRegistration, with an optional guest reference; do not store unverified email on User or identify/access an existing user by it. Direct signup creates no User record by itself. If the person begins guest activity in the same browser before confirming, an Identity-owned operation must bind the new guest to that pending request using trusted browser/session state, never email matching; specify conflicting-link handling and test this journey in the UI task. Confirmation without a linked guest creates a RegisteredUser. Delete the pending row atomically when either confirmation path succeeds, retaining no duplicate completed credential record. For guest signup, confirmation upgrades the linked active guest in place, preserving its internal ID and domain-owned activity, and rotates the session. Confirmation must reject an expired linked guest rather than silently switching to direct signup. Require email, a securely hashed password and confirmed mailbox ownership to complete registration. Submitting the registration form alone does not complete the guest-to-registered transition. Specify pending-registration access, expiry and cleanup behaviour in the registration/confirmation specs before implementation. Task 006b provides one-hour purpose-scoped confirmation tokens, invalidated by pending credential changes/replacement. Pending requests expire 24 hours from creation, capped by the original linked guest deadline. Completion atomically creates/upgrades the account, revokes all old guest sessions, issues a fresh Session and deletes the pending request; expected conflict/expiry/replay failures grant no access. Task 006f supplies registration/confirmation HTTP wiring, bounded synchronous mail delivery and browser session binding. Confirmation GET only renders a form; a CSRF-protected POST completes registration. Pending browser ownership is tracked by ID in the encrypted Rails session, with guest attachment and visible expiry. Confirmation links use explicit APP_ORIGIN configuration; SMTP runs after attempt reservation commits, with no database locks held across network calls. New pending registrations reject an already registered normalized email with sign-in guidance and send no confirmation; stale pending requests cannot resend after that email registers. The form intentionally reveals registered-email availability, but an entered email never grants identity or access. Final confirmation still enforces uniqueness for concurrent requests. An expired guest cannot be claimed. Signing into an existing account requires authentication and does not automatically transfer or merge guest records. Guest-aware account validations and database constraints must be specified before credentials are introduced. Permit guest-to-registered transition only before expiry and after email confirmation; registered-to-deleted transition anonymises the account and revokes sessions. Deleted accounts cannot regain access. A browser still holding a deleted-account identity receives an explicit account-deleted failure on identity-dependent requests; it must not silently fall back to a guest. Retain the failure across requests until the session is explicitly reset. Implement transitions explicitly in their respective Identity tasks.

Domain-owned capability modules are included by the user subclasses that support them; shared guest/registered behaviour belongs in those modules, not type-switching branches in `User`. Operations require `active?` and enforce ownership. Deleted users receive no product capability modules; the inactive predicate does not replace session revocation during deletion. Admin permissions are separate from lifecycle subtypes. Capability modules organise access to domain behaviour; inclusion in an Active Record class does not isolate that behaviour from persistence. Keep substantial rules independently testable as described in section 3, with modules delegating to domain-owned rules/operations where needed. Do not create empty capability modules in advance.

Library entries, ratings, expressions and preference data reference internal user IDs for both guests and registered accounts. Domain operations enforce the current identity's ownership. Identity owns guest expiry; each domain retains ownership of deleting its activity. Before implementing cleanup across domains, review ownership and agree a concrete deletion policy and synchronous mechanism. Do not introduce events or a generic integration layer. Scheduled cleanup must recheck guest state so registration cannot race with deletion; define the schedule and failure/retry behaviour in its spec. Expired access is rejected independently of eventual cleanup.

Task 006c supplies password recovery using Rails-native RegisteredUser reset tokens with a 15-minute expiry and password-salt binding. Identity::RequestPasswordReset uses normalized registered-email lookup and synchronous mail outside transactions. Identity::ResetPassword locks/revalidates the target, saves a policy-valid password and revokes all its Sessions atomically; concurrent redemption has one winner. GET only renders; CSRF-protected PATCH resets without automatic login. Same-account browser state is cleared, other registered identities conflict, and unrelated guest/pending state survives without merging. Request IP/email-fingerprint and update IP limits use per-worker memory stores; shared multi-worker controls remain a release prerequisite. APP_ORIGIN validation is shared with confirmation through the minimal Identity::MailOrigin helper.

Use secure sessions, HTTPS in production, restricted database access and filtering of email, passwords and authentication tokens from routine logs. Keep email out of model inputs and analytics. Resend is the provider for verification/password-reset delivery; use local mail previews and non-network delivery by default, with explicitly configured Resend delivery available in development for end-to-end verification. Rails Action Mailer owns multipart confirmation/reset templates and development-only previews; explicit SMTP mode uses required STARTTLS and certificate verification. Development loads ignored dotenv settings; production uses process environment. Mail logging is disabled to exclude recipients, credentials and token-bearing bodies. Callers supply authorized recipients and HTTPS links; composition performs no account transitions. Tests always remain non-network. Registered sessions follow Rails authentication conventions: persistent signed cookies backed by revocable server-side sessions, without a custom age deadline. Guest expiry remains separate. Registered-account deletion and cleanup scheduling remain to be specified. Do not require names, demographic fields or public profiles. Separate identity infrastructure, custom email encryption and email-lookup hashes are not initial requirements; a complete database exposure can still link registered email to preferences.

Viewer submissions and profiles are private by default; sharing expressions as inspiration requires separate consent and moderation. Source attribution and provider reuse terms must be checked before publishing catalogue material.

## 12. Evaluation and delivery

Develop complete working slices:

1. Validate a small catalogue subset; implement independent viewing status and library classification, confirmed-unseen exclusion from rating prompts, direct watchlist addition, spoiler-labelled analysis navigation, ratings and multiple expressions.
2. Establish JEV scoring contracts and a rating-only recommendation baseline.
3. Add explicit scoring and profile synthesis using the prior-profile rule.
4. Add historical reassessment, freshness tracking and before/after ranking evaluation.
5. Complete discovery presentation, library management, analysis visibility and reporting; expand the validated seed catalogue.

The first public loop requires all core behaviours above. External imports and conversational reflection do not block it.

Evaluate rating-only versus expression-informed recommendations, positive and negative recurring patterns, contextual expressions, conflicting evidence, and profile changes that do or do not warrant refresh. Verify that identical repeated processing does not amplify evidence.

Workflow tests should cover retry/idempotency, concurrent profile updates, stale results, edits/deletions, prior-profile capture and recommendation exclusion for every library classification. Also verify persistence of confirmed-unseen status, its exclusion from rating prompts but not recommendations, direct watchlist addition, preservation of viewing status when classification is removed, and eligibility for rating after marking watched. Benchmark classification precision/recall, the novelty gate, recommendation usefulness, latency and cost separately.

## 13. Decisions still to make

- Confirm Rails/PostgreSQL and select the frontend, deployment and job approach.
- Define JEV assessment inputs and outputs, and validate required provider capabilities.
- Define implicit/explicit aggregation and the initial recommendation ranking formula.
- Define expressions profile structure, synthesis inputs and revision semantics.
- Choose refresh cadence, material-change criteria and user-visible processing states.
- Specify re-rating, expression editing/deletion and library-transition behaviour.
- Establish the analysis validation bar and spoiler-safe presentation contract.
- Decide what recommendation evidence and delivery history to retain for evaluation.

These decisions should be recorded with their reasoning, observed results and conditions for revisiting them. Domain boundaries and abstractions should evolve in response to those findings.

## 14. Implementation and review workflow

Follow [the implementation plan](implementation_plan.md) and [repository instructions](../AGENTS.md). Before implementing each small task, create a focused spec under `specs/` using [the template](task_template.md). Define scope, scope restrictions and acceptance criteria with verification methods in advance; record actual evidence under the criteria and summarise changes/deviations afterward. Ready for review is distinct from owner acceptance and merge. The [initial scaffold spec](specs/001_initial_scaffold.md) covers only local Rails/PostgreSQL boot and setup; it does not authorise implementing authentication or the product loop.

Implementation tasks belong to one domain/supporting area and one focused capability where practical. First review any apparent cross-domain work for an incorrect boundary or misplaced invariant. If ownership remains sound, consume established contracts without modifying the other domain; necessary changes require separately scoped work. UI wiring is no exception. Introduce concrete structures only when needed.

### User-facing copy

Use standard Rails i18n locale entries for application UI, flash/error text, mail subjects/bodies and custom validation messages. Start with English only; use semantic keys, interpolation and standard Active Model error symbols. Translate at rendering/action time, not in constants evaluated at boot. Keep locale values plain text and let views escape them. Missing translations raise in development/test. Developer diagnostics and static emergency error pages remain independent of translated application rendering.
