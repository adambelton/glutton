# Glutton — Architecture Brief

Status: Draft for discussion  
Date: 18 October 2026

## 1. Purpose and architectural goals

Glutton helps horror enthusiasts discover films through the qualities they enjoy and dislike. Personal ratings provide implicit evidence; optional notes provide explicit context that improves scoring of subsequently rated films and, through later reassessment, previously rated films.

The project should become a useful, sustainable product with real users. It also provides deliberate practice in domain-driven design, PostgreSQL performance, and managing domain complexity in Ruby on Rails. Architectural decisions should make domain rules and database behaviour understandable, while keeping implementation and operations manageable for an independent maintainer.

This document distinguishes agreed behaviour from proposed implementation. Framework patterns, numeric scoring rules, provider capabilities and deployment choices remain open unless explicitly settled below. It incorporates the product brief and subsequent discussion; where the discussion revises the original brief, this draft follows the discussion.

## 2. Agreed product scope

### Rate films

Ratings presents films for rating or dismissal and offers a direct Add to Watchlist shortcut. Dismissal belongs to Ratings. Library activity can suppress candidates through events.

For a seen film, the viewer chooses Brilliant, Pretty Good, Not For Me, or Garbage. They may record what they liked or disliked in one optional multiline field. They save the rating and notes together.

Expressions are optional. Users who only rate films must receive useful recommendations. Extreme ratings provide stronger directional evidence than mild ratings; exact weights remain experimental.

### Process recommendations

Recommendations contain spoiler-safe information, an understandable reason for the suggestion, and potentially trailers and external ratings where integrations permit. A viewer can mark a film watched, accept it, or reject it. Acceptance adds it to their Watchlist through a Library subscriber.

Recommendations uses its own response and suppression state for eligibility. Watchlist and Watched activity suppresses a film through Library events. Recommendation acceptance and rejection supply no enjoyment scores.

Marking a film watched makes it available for a later rating session, with a possible immediate-rating entry point. A reduced rating interface is an option, not a settled MVP requirement.

### Manage the library

The library provides Watchlist and Watched views. Watched films may be awaiting a rating or already rated. Users can revisit and change ratings and expressions, reconsider dismissed films, and inspect film information and qualities through spoiler-labelled links normally shown in the watched Library view.

Library stores Watchlist and Watched entries. Marking a film Watched makes it available for rating. Removing a Watchlist entry publishes an event that keeps the film suppressed in Ratings. Recommendations discards records created solely for suppression and preserves previously recommended or answered records.

A separate conversational reflection interface is a possible future feature, not required for the core product or initial architecture. Community editing, streaming availability, donations and affiliate integrations are also later concerns.

## 3. Proposed system shape

Use a cohesive Ruby on Rails application backed by PostgreSQL. Initial scaffolding uses server-rendered views and Hotwire; the scoped implementation plan records the delivery sequence. No current behaviour requires independently deployed services.

Organise code around domain responsibilities with explicit application operations for workflows. Keep substantial product decisions—such as rating transitions, recommendation eligibility, scoring and preference calculations—in ordinary Ruby objects with explicit inputs/results, independently testable without Rails boot or database records. Application operations load the required state, invoke those rules, persist results and publish domain events atomically with the source change. Other product domains react asynchronously in their own transactions. Keep database constraints for persisted invariants; independent rule tests do not replace persistence or workflow tests.

Registry models live under `app/models/registry/` with matching `Registry::` constants: Film, QualityCategory, Quality, FilmQuality and FilmQualityEval. They retain their existing unprefixed database tables and foreign keys; Library and Ratings canonical-film associations explicitly reference `Registry::Film`. Registry services/jobs use the same namespace. Library and Ratings event declarations live in their respective `app/models/<domain>/events.rb` files as `Library::Events` and `Ratings::Events`, including their publishing-domain identifier. The domain directories establish their parent namespaces implicitly. Identity models live under `app/models/identity/`; Library models live under `app/models/library/` with one `LibraryFilm` model and a required `watched` boolean in `library_films`. Ratings models live under `app/models/ratings/` and retain their original tables; Foundation delivery models live under `app/models/domain_events/`, using the existing DomainEvents service namespace and unchanged tables. ApplicationRecord and ApplicationJob remain shared Rails bases. `identity/user.rb` defines the Identity::User STI storage/query root (direct construction is prohibited); `identity/user_registered.rb`, `identity/user_guest.rb` and `identity/user_deleted.rb` define UserRegistered, UserGuest and UserDeleted. The Identity classes retain the users table and short stored STI labels through `store_full_sti_class = false`; class resolution stays within Identity without legacy aliases or data rewrites. User-owned registration/credential permissions and actions stay on the models; registration transition execution remains in its Identity service. Session UI uses Rails polymorphic partials. Session owns resumption and fresh binding checks, consulting user.active? and a model-owned inactive error when needed. The transport derives cookie expiry from user.session_duration; this does not impose a registered server-session TTL. Session and PendingRegistration are also namespaced under Identity, with unchanged tables. Reconsider model organisation only when concrete behaviour warrants it.

Confirmation has one transaction coordinator in Identity::Registration::CompleteRegistration, including attachment of an unattached registration to the current active guest. PendingRegistration owns token resolution and confirmation access rules shared by GET and completion; GET performs no attachment. The browser completion entry point delegates to that coordinator. Completion locks the source user before the pending request and revalidates the token after locking.

Active Record remains appropriate for persistence and straightforward local behaviour, including Identity credentials, password hashing and account validation. Declare built-in validations directly in their models; reserve extracted capability modules for meaningful domain behaviour rather than sharing validation declarations. Do not duplicate that model in a separate entity/repository layer without a concrete need. Extract stronger persistence boundaries where domain complexity or tests show the benefit. Use background jobs for deferred processing. Avoid introducing engines, generic repositories, event sourcing or a messaging platform without a concrete need.

Treat every object as a role and name collaborators for the role actually required, whether implemented through a concrete class, superclass or shared-behaviour module. Trust internal role contracts by default; class guards and their disguised predicate equivalents require a specific justification. Put rules about an object's permitted behaviour inside that object and delegate the operation rather than identifying its class to choose behaviour elsewhere. Meaningful domain-state and action-permission predicates remain appropriate. Models own ordinary actions and their rules; transition services coordinate changes between model types, while the source model declares supported actions without sibling-class knowledge. Validate untrusted input at its boundary. Refresh/re-read and lock when freshness/concurrency matters independently of role trust. Tests follow the same role rules and verify observable outcomes and contracts rather than incidental internal state; do not introduce production interfaces solely for test assertions. The maintained implementation/review conventions and examples are in [AGENTS.md — Object roles and behaviour](../AGENTS.md#object-roles-and-behaviour).

Keep external-provider calls behind narrow adapters. Initial boundaries cover JEV assessment, Claude profile synthesis, metadata lookup and source retrieval. These boundaries should expose the operations Glutton requires rather than reproduce every provider API.

Use local PostgreSQL for development. Railway plus Neon is the owner’s familiar deployment option, with production hosting still to be selected. Server-rendered Rails views and Hotwire are the initial frontend direction. Job backend and specific provider/model versions remain undecided; background processing is a separate task after the minimal scaffold. Modest model API development costs are acceptable; expensive data/media licences are not. The owner has a Claude API key and can create a JEV key; keep credentials out of source control.

## 4. Domain responsibilities

Boundaries follow distinct activities and their language, not a generic user–film table. They remain testable modelling decisions rather than prescriptions for Rails engines or independent services.

| Area | Owns | Boundary |
| --- | --- | --- |
| Registry | Film identity, metadata/media, sourced context, editable quality categories/vocabulary and accepted film–quality associations | Shared knowledge independent of viewers |
| Library | Canonical user–film relationship: Watchlist and Watched; library management | Does not own purpose-specific presentation histories, ratings or inferred preferences |
| Ratings | Rating presentations and responses, ratings, original expressions, scoring, taste profiles and inferred preferences | Rating submission, scoring and profile building are distinct capabilities; Ratings publishes completed-viewing facts and explicit Library action requests |
| Recommendations | Selection, eligibility, ranking, explanations, presentation and response history | Maintains projections from Library/Rating events; publishes response choices without owning Library state |

Owner clarification, 26 October 2026: domain boundaries are ownership boundaries, not read-access barriers. All domains may read the shared database, including another domain’s models/scopes, while respecting session/user access controls. Each domain owns its mutations, invariants and lifecycle. Read-only presentation queries do not require event-derived copies or new provider/consumer tasks. Durable events remain the agreed mechanism for existing cross-domain state-changing reactions; this clarification does not replace those workflows. For example, Library derives rated/awaiting-rating display from Ratings-owned records without storing its own rated flag.

Ratings contains separate capabilities for recording evidence, scoring, profile building and reassessment. They share domain language; the original evidence/inferred interpretation distinction remains an invariant inside this domain, not a separate Taste boundary. Library is the canonical collection, while Ratings/Recommendations records describe their specific activities. These records need not share a data model.

A Ratings “haven’t seen it” response suppresses later rating prompts without creating a Library entry or excluding recommendation eligibility. Recommendations assumes candidates are unwatched absent evidence otherwise; its exclusion rule uses Library's classifications, not the mere existence of any user–film record. Library owns watched-but-unrated films and links to Ratings. Its rated display reflects Ratings' authoritative current rating rather than owning a duplicate value.

Registry owns the shared quality vocabulary; Ratings interprets it as evidence about a viewer. Dynamically source people candidates from verified credits. Any apparent need to change multiple domains requires a boundary/invariant review before creating provider/consumer tasks; an occasional stable interaction is not inherently a modelling defect.

Qualities and quality categories are editable descriptive product data. Do not invent behavioural subclasses unless concrete rules require them; category membership is not a class selector.

## 5. Core concepts and invariants

- **Film:** A distinct work identified consistently across imports, including remakes and versions where relevant.
- **Film source information:** Current source material with provenance; FilmQualityEval retains immutable assessed inputs and results.
- **Film–quality assessment:** An accepted source-backed association for current scoring; permanent historical association sets are not yet required. Current assignment freshness is distinct from retention history.
- **Library entry:** The canonical user–film relationship, owned by Library. Viewing facts and watchlist/dismissal intent need consistent rules without prescribing a table structure. Ratings dismissal and recommendation rejection belong to their respective domains.
- **Rating presentation / response:** Ratings' record that a film was presented and the viewer's response, including haven’t seen it. Separate from canonical Library state.
- **Recommendation presentation / response:** Recommendations' record of a proposed film and response, independent of Library persistence. Library actions use Library-owned operations.
- **Rating:** The viewer's personal reaction to a watched film. Watched does not imply rated.
- **Expression:** One original viewer-authored idea associated with a film. Preserve wording and revisions required for traceability; define retention and deletion behaviour explicitly.
- **Expressions profile revision:** An interpretation derived exclusively from the viewer's actual expressions. Rating patterns and inferred scores must never enter it as user statements.
- **Film quality scoring assessment:** Separate implicit and expression-based evidence for one viewer's rating submission, recording its input versions and processing provenance.
- **Inferred preference result:** The current aggregation of completed scoring evidence used for recommendations. Its exact representation and aggregation formula remain open.
- **Recommendation response:** A discovery decision, separate from watched-film enjoyment evidence. Current library state determines eligibility; response history can support later evaluation.

Reprocessing replaces or supersedes an interpretation. It must not accumulate duplicate evidence. Running the same assessment or aggregation repeatedly with identical inputs must not amplify preference strength.

Group constants that represent a set of model values in named modules so references carry the context of the value. For example, use `Rating::Values::BRILLIANT` and `RatingQuality::Classifications::UNEXPRESSED`.

### Service organisation and naming

Application services live in `app/services/<owning_domain>/<capability>` where a meaningful capability exists. A capability names a stable responsibility or outcome: Ratings uses CandidateSelection, RatingRecording, QualityScoring and TasteProfiling; Library uses CollectionManagement. Registry separates CatalogueMaintenance, QualityManagement and CatalogueQueries. CatalogueQueries is a read grouping for administrative inspection, previews and ordered IDs; it does not imply UI-only browsing. Identity uses AccountAdministration, Authentication, Registration and PasswordRecovery, with shared MailOrigin and ReturnDestination at its root. Recommendations uses CandidateSelection for ranking and next-film selection.

Technical groupings are appropriate where the responsibility is technical: Registry Sources, receiving-domain EventHandlers, and DomainEvents Publication and Delivery. Publication and delivery preserve different transaction/failure boundaries. Not every domain needs subdivisions. Models, jobs, controllers and tests remain in their conventional Rails layers; capability folders do not rename persisted models or create new access barriers.

Keep closely collaborating commands, queries, calculations, AI operations, validators, value objects and assets together; group domain exceptions in the domain’s errors directory. Flat capability interiors make their collaborations traceable. Keep question JSON and prompt text adjacent to their consuming operations. Operation-specific JSON files share the consuming Ruby file stem, such as `evaluate_explicit_qualities.rb` and `evaluate_explicit_qualities.json`; shared provider configuration keeps its provider-oriented name. There is no global queries, values, policies or AI layer; a supporting object belongs beside its closest collaborators. TmdbMetadata and WikipediaContext therefore remain in Registry::Sources, while Subscription remains in DomainEvents::Delivery.

Choose a class name from its responsibility, complete interface, return value and lifecycle. A `.call` method alone does not establish whether it is an operation or information object. Avoid names that could reasonably describe both a command and its resulting artefact.

| Role | Examples and naming rationale |
| --- | --- |
| Commands/application coordinators | ScoreRatingQualities coordinates assessment and applied scores; RefreshTasteProfile coordinates one viewer's refresh/publication; AssignInitialFilmQualities records and applies initial assignments. Use actions describing outcomes. |
| Queries/calculations | FindCurrentRating and FilmIdsByTmdbVoteCount identify what is retrieved or derived. Preserve clear existing names rather than forcing grammatical uniformity. |
| Information/results | NoteComparison calculates once in its constructor and exposes changes, retained notes and current mappings. It represents a comparison rather than a command called NoteChanges. |
| Executable AI operations | EvaluateRatingQualities combines explicit and implicit judgments; EvaluateInitialFilmQualities executes support judgments and selection; GenerateTasteProfile produces validated proposed text and citations without publication. Retained input/result state does not make these passive result objects. |
| Persisted evaluation evidence | RatingQualityEval, FilmQualityEval and TasteProfileRevisionEval represent immutable assessment evidence/provenance. They are distinct from executable operations and applied domain results. |
| Exceptions | Name the specific failure under its owning domain’s Errors namespace, preserving reason and recovery contracts. |

Use one `app/services/<domain>/errors/` directory and `Domain::Errors::Name` namespace for all domain exceptions, including capability-specific failures. For example, Ratings::Errors::QualityAssessmentFailed and Identity::Errors::ConfirmationDeliveryLimited have the same predictable home as shared domain failures. Their raising and handling collaborators still express capability ownership. Do not add errors directories inside capabilities. Keep existing component-owned transport errors such as TypeSafeClient::Error and ProviderRequest::Error.

Add functionality to an existing capability when it shares that responsibility. Introduce a new capability when a distinct, stable responsibility emerges. Do not create a directory solely for one operation or split because file count grows. Reconsider boundaries when unrelated responsibilities or independently evolving workflows accumulate. Refactor demonstrated organisational friction rather than anticipated complexity. Preserve domain ownership, shared-read permissions and intentional asynchronous mutation contracts throughout.

Service tests generally follow capability directories. Cross-capability tests can remain at the domain root; model, job, integration and system tests retain their Rails locations. The [AI composition guidance](ai_model_services_design.md) explains how to compare capabilities without forcing identical implementation structures.

### Cross-domain service communication

Domains may read stable shared facts directly when the caller preserves access controls. For derived values or queries whose meaning depends on the source domain's rules or storage, use a named read operation owned by that domain. The owner defines the inputs, result, ordering where applicable, and freshness callers can rely on. The consuming domain decides how to use the result.

Each domain owns changes to its durable state. When a fact from one domain should trigger a change in another, publish a domain event and let the receiving domain apply its own rules asynchronously.

Ratings discovery uses Registry's named vote-count query for ordered film IDs. Registry owns how it derives that ordering. Ratings chooses the query and owns viewer eligibility and queue admission. Library changes that affect Ratings eligibility reach it through events.

When a task adds a workflow analogous to an existing one, compare the two entry points before implementation. Review service lifecycle, transaction ownership, provider adapters, failure handling, tracing and persisted evidence. Record intentional differences in the working task and exercise both paths when changing a shared contract.

TypeSafe request handling is shared across Ratings and Registry. The TypeSafe adapter loads model, pricing, timeouts and workflow defaults from config/typesafe.json. Evaluation records capture the resolved settings, including operator overrides. Each domain loads its matching configuration and saves the settings with the evaluation. Domain assessments own question construction, decisions and evidence. Trace payload capture is opt-in. Registry retains its film-source trace payloads, and Ratings traces carry request counts and usage without expression text.

Use an orchestration service whenever a workflow composes data from multiple services, within one domain or across domains. Place it alongside the services in the domain that owns the outcome and name it for that outcome. When several workflows share a capability, group them by that capability. Controllers and components call the orchestrator. Each collaborating service owns its queries, rules and transactions. When a service needs data from another domain during its operation, have it yield the required inputs and let the orchestrator supply the result in a block. For example, `Ratings::CandidateSelection::NextCandidates` coordinates Registry ordering and Ratings queue admission.

Place application components in the domain that owns what they present. Registry owns film links and posters. Shared holds the common document shell and general controls.

Views and components can orchestrate presentation and call domain services directly when they need data to render. Use the same cross-domain read rules and preserve viewer access controls. Controllers handle HTTP input and dispatch user actions to the owning domain. Rendering uses read operations, and the domain services retain their rules and transaction responsibilities.

AI workflows follow the [AI model services design](ai_model_services_design.md), which defines the responsibilities of orchestration services, assessments, provider adapters, evaluations and result models.

### Asynchronous domain events

Owner decision, 21 October 2026: Library, Ratings and Recommendations coordinate through durable asynchronous domain events. This supersedes the synchronous-only design. The source commits its state and outbox event together; subscribers commit their own state and delivery receipt independently. Brief eventual consistency is acceptable. Delivery must survive crashes and retries, preserve stream ordering and prevent duplicate effects. No broker or independently deployed service is required. Foundation implements the durable outbox and subscriber receipts using GoodJob 4.22 in the same PostgreSQL database, with after-commit notification wakeups and a 30-second recovery sweep. Library/Ratings publication and consumers use this transport; deployment remains separate. See [operations](domain_event_operations.md).

[Domain events](domain_events.md) specifies the publication/subscription map, event versus request semantics, versioning, conflicts, backfill, privacy, failure recovery and separate publisher/consumer tasks. Library publishes watched/watchlist/dismissal/removal facts. Ratings publishes completed rating/revision and later preference facts. Recommendations publishes recorded action choices for Library to apply or reject; receiving a choice is not proof that Library changed. Ratings UI actions follow the same boundary. Domain model behaviour and internal synchronous calls remain unchanged.

Ratings preserves its own history and distinguishes known watched awaiting rating from unknown films needing a seen/unseen prompt. Consumers retain provenance and never erase a saved rating due to a delayed contradictory Library event. Completed-rating handling is a system workflow with explicitly defined duplicate/reconciliation behaviour; it does not change public user-action failure semantics. No subscriber recreates a source action just because it received the resulting fact.

Source-backed film information is directly accessible; normal navigation is through spoiler-labelled links on the watched Library view, without a Library-based authorization gate.

## 6. Saving a rated film

Scoring clarification, 22 October 2026: [Ratings scoring design](ratings_scoring_design.md) records the agreed unexpressed, implicitly expressed and explicitly expressed classifications, current-profile recomputation rules and proposed Rating/RatingQuality relationships. Profile versions and evidence classifications follow that design. The current rating flow captures original expressions; scoring and profile processing remain deferred.

### Record the submission

A Ratings operation validates its own seen confirmation and the rating, without requiring a Library watched record, then atomically persists the rating and expressions and preserves the submitted rating and original expressions. The viewer can continue rating once their input is durably saved.

Saving and assessment completion are distinct states. Provider failure must not lose the submission. Deferred work must be durably discoverable and retryable; the exact database-backed job or pending-work mechanism is an implementation decision.

### Branch A: quality scoring through JEV

Use the rating, submitted expressions, relevant film knowledge and the applicable taste profile to produce:

1. Implicit quality evidence based on the rating, interpreted using that profile.
2. Explicit quality evidence based on the expressions submitted for this film.

Record the actual profile/input versions used and reject stale work. Both kinds of scoring are handled through JEV; Claude is not required for this round of scoring. This specifies responsibility, not whether the assessments require one provider request or several.

Store implicit and explicit outputs separately enough to inspect and evaluate them. How JEV represents relevance, direction and strength, and how these outputs combine, must be established through experiments.

### Branch B: taste profile assessment

Use an LLM call to synthesize and update the taste profile from original expressions, preserving their context. No JEV gate is assumed. Meaningful-change criteria, synthesis inputs, revision semantics and cadence remain for the Ratings implementation. Preserve original expressions and processing state so failures can be recovered without treating inferred quality scores as new user statements.

Submissions without expressions do not require profile synthesis. Edits and deletions require reassessing the affected explicit evidence; an additions-only novelty check is insufficient for removing an earlier claim.

### Completion and concurrency

The two branches may complete independently. Completed scoring can affect recommendations without waiting for profile synthesis. A new profile revision informs subsequent assessments once available, and makes historical assessments candidates for refresh.

Rapid submissions may be assessed against the same profile revision while processing is pending. Record this honestly and reconcile through reassessment. Profile updates must detect an outdated base revision and merge or retry against current explicit evidence, rather than overwrite another update. The serialization strategy remains open.

## 7. Immediate effects and periodic reassessment

An expression contributes explicit evidence for its own film as soon as scoring completes. After its profile update completes, it can inform implicit scoring of subsequent submissions. Existing assessments are updated later through periodic or explicitly triggered work.

Refresh considers all relevant rated films, including the implicit assessment of the submission that caused the profile change. It recomputes from authoritative inputs and selected current revisions, preserving the distinction between direct expression evidence and inferred attribution.

Track freshness through input revisions rather than a single ambiguous updated timestamp. Relevant changes include ratings, expressions, taste profile, accepted film qualities, vocabulary and scoring method. Different changes may require different processing stages; a profile change need not require reclassifying unchanged expression text.

The exact refresh cadence, material-change criteria and whether MVP offers a manual refresh control remain open. Coalesce superseded work, bound provider costs, and avoid claiming that recommendations incorporate a profile revision before the relevant processing completes.

## 8. Recommendation construction

Before Recommendations integration, review whether the existing Ratings models/scopes adequately expose the latest applied scores for each current rating. Shared reads are allowed; do not introduce a provider abstraction solely because the records belong to Ratings. If a Ratings-owned scope/query is needed, agree its viewer handling and result shape and implement it in a separate Ratings-owned task. Verify viewer isolation, superseded ratings/sets, recorded-but-unapplied evaluations and unassessed current revisions. Recommendations retains ranking and eligibility ownership.

Recommendations first excludes all films classified in the viewer's library. It then ranks eligible films using current completed preference evidence and film–quality associations, accounting for both positive and negative signals.

Owner decision, 11 November 2026: implement Recommendations logic before its display. Aggregate actual applied Ratings scores by quality, including unexpressed, implicitly expressed and explicitly expressed classifications, then sum the matching quality totals for each eligible film. Do not reweight classifications or apply diminishing returns. Admitting a recommendation requires five distinct films with current assessed ratings. Notes are optional and there is no popularity fallback. Neither quality overlap nor the resulting score establishes predicted enjoyment. Present the oldest eligible queued RecommendationFilm. When the queue has no eligible entry, admit the highest-scoring eligible film with no positive-score cutoff. Only scored current rating revisions contribute; while a revision awaits scoring, omit its superseded scores and exclude that film from the assessed-film count. Queue admission records the selected film. Subsequent ratings can change ranking for future admissions without replacing an already queued eligible film. Selection alone does not record a response.

When implementing recommendation scoring, explicitly evaluate the effect of different numbers of assigned qualities per film. Raw sums can favour films with more positive matching qualities or penalise those with more negative matches; dividing by total quality count can instead dilute useful matches or favour sparse descriptions. Counts reflect source coverage, actual film characteristics and category ceilings, and an unassigned quality is not proof of absence. Category caps alone do not resolve this bias. Monitor neutral-quality additions, overlapping/correlated qualities, sparse coverage and negative-preference influence. Distinguish matching scores from coverage/uncertainty. Raw sum is selected; no normalization or equal-quality-count requirement is chosen. Require evidence of relevant films being overlooked before introducing a correction. This is a deferred consideration for Recommendations implementation, not additional Registry assignment work.

Recommendation explanations must be supported by the evidence actually used and remain spoiler-safe. An explanation must distinguish an explicitly expressed preference from an inferred pattern. Prefer reusable spoiler-safe film material and inexpensive explanation construction where sufficient; per-card generative calls are not assumed.

Store enough information about served recommendations and scoring versions to compare outcomes and understand ranking changes. The required retention and detail should be proportionate to evaluation needs.

## 9. Registry sources and quality decisions

Current direction, 28 October 2026: use maintained Wikipedia narrative/context and a revisable master vocabulary. Glutton owns accepted source-backed quality associations; JEV is the chosen assessment engine. Source acquisition and candidate evaluation do not automatically accept new qualities. [Current requirements](film_quality_requirements.md) supersede the former generated-analysis dossier design.

Quality categories are persisted editable records with maximum-qualities and weight settings. Names and database IDs identify concepts without separate keys. Category ceilings govern film-quality selection; weights begin at 1 and do not affect JEV presence judgments. Category grouping alone does not rescore. See [current requirements](film_quality_requirements.md).

Qualities have equal initial base treatment. Do not use film centrality or model confidence as an intrinsic weight or quality-selection gate. Actual rating/expression evidence determines user-specific contributions. Category weights are stored configuration; their scoring use, recalculation behaviour and editing UI remain separately scoped. Ceilings are category-specific maxima, with no global 20 limit or category minimum.

A Wikipedia page refresh changes source material. A deliberate accepted film-quality change is the proposed trigger for affected downstream reassessment. Do not automatically regenerate matches or scores for every page revision. Registry publishes accepted changes only through a separately agreed event contract; Ratings and Recommendations own their resulting mutations.

Historical rating/recommendation contributions explain the scores actually produced using saved inputs/results. FilmQualityEval preserves complete call and decision evidence, while FilmQuality stores accepted current associations linked to their originating evaluation. No independent FilmAnalysis/AnalysisQuality lifecycle or archive of every former association set is retained. Langfuse is optional diagnostic tracing; application evaluation records remain readable independently.

Initial film assignment uses independent per-quality support questions in one request, without supporting-paragraph Choice requests. Paragraph-reference collection is reserved for explicit manual review and does not block normal assignment. Code selects support >=0.60 within configured category ceilings. Completed and failed/partial evaluations are retained; stale inputs prevent application and batch warnings isolate per-film failures. The [working baseline](film_qualities/README.md) retains vocabulary/question material and historical examples. No prompt migration or further tuning is required before seed loading.

Follow the seed-first [implementation plan](implementation_plan.md): admin inspection, manual editing, source refresh and explicit change comparison/application remain to build. Community editing is deferred. Source refresh alone changes no accepted associations or downstream scores.

### Current provider decision — 18 October 2026

Use **TMDB** for initial search, metadata, verified identity selection, external IDs, credits, poster/backdrop references and trailer references. Use free developer access; paid data/media plans are outside the budget. Media is a core discovery requirement. Retain Glutton-owned film IDs, provider identifiers and provenance behind a narrow TMDB adapter; do not implement multiple providers pre-emptively. Independently researched analyses and viewer expressions remain the basis of AI processing. Keep TMDB-derived content out of model inputs for now, including credits used as classification candidates unless independently verified; this separation does not itself resolve the broad AI-use clause.

Store the complete TMDB movie response under the metadata details envelope, alongside retrieval provenance. Validate film identity/title/release date when importing, and adapt optional provider fields through Registry-owned typed readers when consumed. Unknown or malformed optional fields remain in the source packet without leaking provider shapes into views. Legacy filtered packets remain readable; obtaining missing source fields requires a separately scoped full metadata refresh.

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
- Select rating-flow candidates while excluding dismissed, suppressed and already rated candidates; include watched films awaiting ratings.
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

Identity owns one users table with stable internal IDs, using Rails single-table inheritance with `Identity::User` as the shared role and lifecycle subclasses `Identity::UserGuest`, `Identity::UserRegistered` and `Identity::UserDeleted`. Direct construction of User is unsupported; concrete lifecycle roles own their behaviour. `Identity::User#active?` returns true; `Identity::UserGuest` overrides it to return true only before `created_at + Identity::UserGuest::EXPIRY_DURATION`, without a stored deadline; `Identity::UserDeleted#active?` always returns false. Changing the lifetime policy affects existing guests. Create an email-free guest when first saving personal activity; no fabricated credentials. Use one server-side Session model for guests and registered users. An active guest can receive a session without credentials; a registered session requires password authentication. Both support revocation and reject inactive owners. Guest cookies have browser-session lifetime; registered cookies follow Rails authentication conventions. The protected cookie references the Session record, not just the user ID. Browser identity resolves the shared Session record. The cookie is not a tab-lifetime guarantee, and browser session restoration may preserve it. Independently enforce a fixed 24-hour deadline from guest creation on every guest access; activity never renews it. Missing/invalid sessions and expired guests must not grant access to old activity. Cookie expiry does not delete database records.

Store unverified email and password digests in a separate PendingRegistration, with an optional guest reference; do not store unverified email on User or identify/access an existing user by it. Direct signup creates no User record by itself. If the person begins guest activity in the same browser before confirming, an Identity-owned operation must bind the new guest to that pending request using trusted browser/session state, never email matching; specify conflicting-link handling and test this journey in the UI task. Confirmation without a linked guest upgrades the current active guest when one is present; otherwise it creates a UserRegistered. Task confirm an unattached registration with the current guest removes the browser-held pending ID from confirmation: the token identifies the registration and the current session identifies the guest. A different linked guest, a registered current user or another pending request already linked to the current guest remains a conflict. Delete the pending row atomically when either confirmation path succeeds, retaining no duplicate completed credential record. For guest signup, confirmation upgrades the linked active guest in place, preserving its internal ID and domain-owned activity, and rotates the session. Confirmation must reject an expired linked guest rather than silently switching to direct signup. Require email, a securely hashed password and confirmed mailbox ownership to complete registration. Submitting the registration form alone does not complete the guest-to-registered transition. Specify pending-registration access, expiry and cleanup behaviour in the registration/confirmation specs before implementation. The Identity namespace migration intentionally invalidates previously issued confirmation/password-reset links because no production users exist; request replacement links after migration. New links retain the existing expiry/binding rules. Confirmation tokens are purpose-scoped and valid only while the pending registration remains active, with no independent token timer. Resending does not extend the registration deadline; credential changes/replacement also invalidate links. Pending requests own a one-hour deadline from creation, configured by PendingRegistration::EXPIRY_DURATION and additionally require their linked user to remain active. Guest expiry stays internal to UserGuest; registration does not read or expose its deadline. Completion atomically creates/upgrades the account, revokes all old guest sessions, issues a fresh Session and deletes the pending request; expected conflict/expiry/replay failures grant no access. The registration browser flow supplies registration/confirmation HTTP wiring, bounded synchronous mail delivery and browser session binding. Confirmation GET only renders a form; a CSRF-protected POST completes registration. Pending browser ownership is tracked by ID in the encrypted Rails session, with guest attachment and visible expiry. Confirmation links use explicit APP_ORIGIN configuration; SMTP runs after attempt reservation commits, with no database locks held across network calls. New pending registrations reject an already registered normalized email with sign-in guidance and send no confirmation; stale pending requests cannot resend after that email registers. The form intentionally reveals registered-email availability, but an entered email never grants identity or access. Final confirmation still enforces uniqueness for concurrent requests. An expired guest cannot be claimed. Signing into an existing account requires authentication and does not automatically transfer or merge guest records. Guest-aware account validations and database constraints must be specified before credentials are introduced. Permit guest-to-registered transition only before expiry and after email confirmation; registered-to-deleted transition anonymises the account, clears superuser privilege and revokes sessions atomically. The storage constraint rejects deleted identities retaining superuser privilege; this lifecycle transition does not require a separate actor-authorized privilege revocation. Deleted accounts cannot regain access. A browser still holding a deleted-account identity receives an explicit account-deleted failure on identity-dependent requests; it must not silently fall back to a guest. Retain the failure across requests until the session is explicitly reset. Implement transitions explicitly in their respective Identity tasks.

Domain-owned capability modules are included by the user subclasses that support them; shared guest/registered behaviour belongs in those modules, not type-switching branches in `Identity::User`. Operations require `active?` and enforce ownership. Deleted users receive no product capability modules; the inactive predicate does not replace session revocation during deletion. Internal operator privilege is separate from lifecycle subtypes. Identity persists a denied-by-default superuser boolean constrained to registered accounts. Rails supplies the `superuser?` boolean predicate; the non-null false default, lifecycle validations and storage constraint enforce denied-by-default privilege state. `Identity::AccountAdministration::GrantSuperuser` and `Identity::AccountAdministration::RevokeSuperuser` require an existing superuser actor, load/lock actor and target in ascending ID order and delegate actor-authorized model-owned actions, with explicit unsupported/missing and repeated-action failures. First-superuser provisioning is directly through the database, with no application bootstrap bypass. Operator console invocation is documented in the README; there is no public permission-management endpoint. Feature-specific authorization is deferred to future feature implementations; consumers read current authoritative identity state; browser sessions store no permission copy and observe revocation on their next request. Capability modules organise access to domain behaviour; inclusion in an Active Record class does not isolate that behaviour from persistence. Keep substantial rules independently testable as described in section 3, with modules delegating to domain-owned rules/operations where needed. Do not create empty capability modules in advance.

Library entries, ratings, expressions and preference data reference internal user IDs for both guests and registered accounts. Domain operations enforce the current identity's ownership. Identity owns guest expiry; each domain retains ownership of deleting its activity. Before implementing cleanup across domains, review ownership and agree a concrete deletion policy, including transactional cascades where appropriate and safe handling of queued events. Use the approved scoped retention and event-delivery contracts; do not introduce a generic integration layer. Scheduled cleanup must recheck guest state so registration cannot race with deletion; define the schedule and failure/retry behaviour in its spec. Expired access is rejected independently of eventual cleanup.

Identity supplies Identity::AccountAdministration::CleanupExpiredAccounts.call(batch_size: 100) and `bin/rails identity:cleanup_expired`. SQL selects bounded oldest-first expiry candidates; per-candidate transactions lock/recheck current state and delete expired guests with their Sessions/PendingRegistrations or independently expired pending rows. Guest-before-pending lock order matches registration. Registered/deleted accounts and active guests are retained. Failures roll back the current candidate and stop; earlier commits remain, and re-running is safe. Counts include pending rows removed with guests. The proposed cadence is every 15 minutes, but scheduler deployment is not implemented and backlog size affects physical deletion delay. Library includes Library-owned watched activity with an owner-approved scoped user foreign-key cascade: physical guest deletion removes its LibraryFilm rows in the same transaction and keeps shared Film rows, while in-place claim retains Library ownership. This requires no Identity implementation change. The schema also cascades expired-guest deletion through Ratings, Recommendations and domain event data. Cleanup limits guest candidates, not the number of Library rows belonging to each candidate. GoodJob runs event delivery in an external worker. Identity cleanup scheduling remains open.

Credential authentication and session issuance use the same transaction/user lock as password recovery. This makes credential verification and session issuance share the user lock held by password recovery: reset revokes an earlier sign-in, and an earlier reset prevents subsequent issuance using the old password. Identity provides password recovery using Rails-native UserRegistered reset tokens with a 15-minute expiry and password-salt binding. Identity::PasswordRecovery::RequestPasswordReset uses normalized registered-email lookup and synchronous mail outside transactions. Identity::PasswordRecovery::ResetPassword locks/revalidates the target, saves a policy-valid password and revokes all its Sessions atomically; concurrent redemption has one winner. GET only renders; CSRF-protected PATCH resets without automatic login. Same-account browser state is cleared, other registered identities conflict, and unrelated guest/pending state survives without merging. Request IP/email-fingerprint and update IP limits use per-worker memory stores; shared multi-worker controls remain a release prerequisite. APP_ORIGIN validation is shared with confirmation through the minimal Identity::MailOrigin helper.

Use secure sessions, HTTPS in production, restricted database access and filtering of email, passwords and authentication tokens from routine logs. Keep email out of model inputs and analytics. Resend is the provider for verification/password-reset delivery; use local mail previews and non-network delivery by default, with explicitly configured Resend delivery available in development for end-to-end verification. Rails Action Mailer owns multipart confirmation/reset templates and development-only previews; explicit SMTP mode uses required STARTTLS and certificate verification. Development loads ignored dotenv settings; production uses process environment. Mail logging is disabled to exclude recipients, credentials and token-bearing bodies. Callers supply authorized recipients and HTTPS links; composition performs no account transitions. Tests always remain non-network. Registered sessions follow Rails authentication conventions: persistent signed cookies backed by revocable server-side sessions, without a custom age deadline. Guest expiry remains separate. Registered-account deletion and scheduler deployment remain separate work. Do not require names, demographic fields or public profiles. Separate identity infrastructure, custom email encryption and email-lookup hashes are not initial requirements; a complete database exposure can still link registered email to preferences.

Viewer submissions and profiles are private by default; sharing expressions as inspiration requires separate consent and moderation. Source attribution and provider reuse terms must be checked before publishing catalogue material.

## 12. Evaluation and delivery

Develop complete working slices:

1. Validate a small catalogue subset and implement Ratings, Watchlist, Watched and optional film notes.
2. Establish JEV scoring contracts and a rating-only recommendation baseline.
3. Add explicit scoring and profile synthesis with recorded input/profile versions and the agreed evidence classifications.
4. Add historical reassessment, freshness tracking and before/after ranking evaluation.
5. Complete discovery presentation, library management, film-information visibility and quality reporting; expand the validated seed catalogue.

The first public loop requires all core behaviours above. External imports and conversational reflection do not block it.

Evaluate rating-only versus expression-informed recommendations, positive and negative recurring patterns, contextual expressions, conflicting evidence, and profile changes that do or do not warrant refresh. Verify that identical repeated processing does not amplify evidence.

Workflow tests cover retry and idempotency, concurrent profile updates, stale results, revision provenance and recommendation eligibility. Verify that Watchlist and Watched events update candidate eligibility and preserve explicit Ratings dismissal.

## 13. Decisions still to make

- Select production deployment and the job approach when deferred processing is introduced. Rails, PostgreSQL and server-rendered Hotwire are the implemented framework choices.
- Define Ratings JEV assessment inputs and outputs, and validate required provider capabilities.
- Define implicit/explicit aggregation and the initial recommendation ranking formula.
- Define taste profile structure, synthesis inputs and revision semantics.
- Choose refresh cadence, material-change criteria and user-visible processing states.
- Specify re-rating, expression editing/deletion and library-transition behaviour.
- Agree source/evidence coverage, accepted film-quality changes and spoiler-safe presentation; specify source/evaluation purge and manual-edit provenance rules.
- Decide what recommendation evidence and delivery history to retain for evaluation.

These decisions should be recorded with their reasoning, observed results and conditions for revisiting them. Domain boundaries and abstractions should evolve in response to those findings.

## 14. Implementation and review workflow

Follow [current progress](implementation_plan.md) and [repository instructions](../AGENTS.md). Before implementation, use a temporary working record based on [the template](task_template.md) to constrain scope and validate the outcome. When preparing the PR, use that record for its description, update maintained progress/decisions and remove the working record. GitHub then owns review, CI and delivery history. Avoid routine PR references; cite one only where specific evidence or a decision needs provenance. Owner acceptance and actual merge remain separate.

Implementation tasks belong to one domain/supporting area and one focused capability where practical. First review any apparent cross-domain work for an incorrect boundary or misplaced invariant. If ownership remains sound, consume established contracts without modifying the other domain; necessary changes require separately scoped work. UI wiring is no exception. Introduce concrete structures only when needed.

### User-facing copy

Use standard Rails i18n locale entries for application UI, flash/error text, mail subjects/bodies and custom validation messages. Start with English only; use semantic keys, interpolation and standard Active Model error symbols. Translate at rendering/action time, not in constants evaluated at boot. Keep locale values plain text and let views escape them. Missing translations raise in development/test. Developer diagnostics and static emergency error pages remain independent of translated application rendering.

## Ratings workflow clarification — 21 October 2026

Owner-approved simplification supersedes the earlier Ratings seen/unseen question and presentation-history proposals: present a film for rating or dismissal. A dismissal only removes it from automatic Ratings rotation; it does not assert that the user has not seen it or change recommendation eligibility or Library classification. Store current queue/selection/dismissal on one RatingFilm per user/film, without presentation history or dismissal reasons. Later Library viewing evidence preserves explicit rating dismissal. The user can explicitly initiate rating from Library through the later targeted-entry task. Ratings offers the Library-owned Add to Watchlist shortcut. Recommendations owns acceptance and rejection, and offers the Library-owned Mark Watched shortcut. 

Ratings candidate ordering clarification: the owner subsequently approved oldest-first batches from a single persistent RatingFilm queue. Candidate selection defaults to one film and supports explicitly requested batches. Candidates admitted by Library watched events and unfinished catalogue candidates use the same created_at/ID order; newly watched entries do not jump the queue. The row stores user, film, boolean dismissal, suppression and standard timestamps. Selection records no presentation/current state. The ratings relationship supplies rated/unrated scopes; selection excludes rated rows. Catalogue replenishment fills only requested batch shortfalls under the per-user lock, preserving all existing user/film records, ratings, dismissal and suppression. New films are admitted by descending typed TMDB vote count, missing/unusable counts last and Registry ID ascending on ties. Selection and admission use Ratings-owned queue state for viewer eligibility. Library Watchlist additions suppress Ratings candidates. Removal from either Library tab preserves or applies suppression. Marking Watched releases suppression. Both preserve explicit dismissal. For this discovery implementation, Registry exposes a named vote-count ordering of film IDs. Ratings passes excluded IDs and a shortfall while holding the per-user lock. Registry performs the ordering over stored metadata in Ruby. This supersedes earlier watched-first priority descriptions.

## Mobile-first navigation — 26 October 2026

Agreed product structure: Ratings, Recommendations and Library are the three primary destinations, in that order. Anonymous visitors see a curated, read-only Ratings demonstration using real horror-film posters/synopses, fictional sample ratings and two or three expressions per example; no identity or personal queue entry exists until meaningful explicit interaction. Product pages require login, completed registration or Continue as guest. A requested resource takes priority after entry; without one, guests go to Ratings and registered users to Library. Login/registration use dedicated pages, and login also offers guest continuation. This supersedes the earlier universal Ratings-root/no-homepage proposal.

- On mobile, use persistent bottom navigation with an icon and visible text label for each destination and a clear active state. Keep account/sign-in controls in the page header. Reserve content space for the navigation and device safe area so it never obscures forms, actions or the final list item. Use comfortable touch targets and verify keyboard/focus behaviour, zoom and narrow screens.
- Library has one collection page with Watchlist and Watched tabs and poster grids. The URL preserves the active tab and Watched rating filters across reload and navigation. A bare Library URL opens Watchlist. Switching tabs resets pagination.
- On desktop, move the same three primary destinations into the header, keeping their order, labels and active state. Use a centred, width-constrained content area with the collection tabs above the poster grid. Do not introduce a different information hierarchy or duplicate top and bottom navigation.
- Prefer a responsive web implementation with standard links and accessible controls. These destinations can carry into a future app without introducing an app framework now.

The authenticated header links to Ratings, Recommendations and Library. Superusers also have Registry and Account links. The mobile navigation design above remains planned.

### Controller organisation

Use one top-level controller named after each product domain for now: `RatingsController` and `LibraryController`, with conventional `app/views/ratings` and `app/views/library` templates and no route module scopes. Domain services and errors retain their namespaces and are explicitly qualified by controllers. Controller namespaces are unnecessary while each domain has a single controller; revisit only when a concrete organisational need arises. This does not change mutation ownership or permitted shared reads.

The Library is a singular resource (`LibraryController#show`); the current rating interaction is a singular resource exposing `new`, `create` and `dismiss` through `RatingsController`. Use `/library` and `/rating` routes rather than implying a collection of libraries or a ratings index.

Controllers that require a session opt in with `before_action :require_identity`. The private ApplicationController method uses existing Identity session resolution and raises `Identity::Errors::Required` for absence. Controllers own their signed-out responses and also retain handling of domain service identity failures. This is not a global callback: public Identity entry points remain accessible. Services still validate fresh user state independently.

Library card actions resolve the owner-scoped LibraryFilm ID. LibraryFilm owns permissions and transitions. Library services lock the viewer and existing entry for marking Watched, moving to Watchlist and removing a film. The shortcuts from Ratings and Recommendations pass the shared Film ID to Library, which owns creating the entry if needed and publishing the resulting change. A stale existing-entry ID cannot recreate a removed relationship.

Library creates entries through its direct collection actions and reactions to RatingSubmitted and RecommendationAccepted. A future TMDB search may offer rating or direct Watchlist addition. Detail GETs use the LibraryFilm ID and never create entries.
