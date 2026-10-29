# Horror Film Discovery — Product Brief

**Status:** Project kickoff / product definition  
**Date:** 18 October 2026 (updated after product and architecture discussion)  
**Working title:** Glutton (provisional; naming and domain purchase deferred until after MVP)  
**Audience:** Product owner and implementation/architecture collaborators (including Codex)

## 1. Vision

Build a personalised horror-film discovery experience that understands **what people appreciate about the films they have watched**, rather than relying chiefly on genres, popularity, ratings or conventional “similar films” metadata.

A viewer rates films and may optionally describe, in their own words, why they enjoyed or disliked them. Ratings alone reveal recurring positive and negative patterns across film **qualities**; explicit **expressions** supply more specific information. The system maintains an expressions profile built only from what the viewer has actually expressed, and uses it to reinterpret rating history. Together these inform recommendations, explanations and an evolving understanding of personal taste.

The product should be enjoyable even before its recommendations become useful: reflecting on horror should be interesting in its own right. Horror means more than fear: people might enjoy performers, decade-specific aesthetics, folklore, extreme violence, imaginative effects, quiet atmosphere, narrative structure, humour, themes or any other distinctive characteristic.

**Core proposition:** Discover horror through the things you love about horror, not simply the films you have already watched.

**Project ambition:** Build an independent enthusiast product with real users in production, a distinctive experience and a committed community. It is first a personal engineering and product-learning project, not a venture pursuing rapid scaling or commercial growth. Ideally, it becomes self-sustaining. A future acquisition by a film-discovery company (for example, JustWatch) is a possible upside, **not** a product requirement, exit plan or justification for changing priorities.

**Learning goals:** Use the project to reinforce domain-driven design, PostgreSQL performance, and managing domain complexity with Ruby on Rails. These goals should inform deliberate design and measurement without requiring unnecessary infrastructure or abstractions.

## 2. Users and principles

**Initial audience:** Individual horror enthusiasts who enjoy discovering films and thinking about why particular films resonate with them. The initial catalogue and vocabulary focus deliberately on horror; expansion beyond horror is optional, not an assumed goal.

Principles:

- **Personal enjoyment, not objective merit.** The rating records a viewer's own reaction, not whether they consider a film artistically good. A separate artistic-quality assessment is deferred.
- **Expressions are optional, and the user's words come first.** Ratings must yield useful recommendations on their own. No forced checklist of observations; film-specific prompts may inspire writing, but are not classification options the user must choose.
- **Infer from patterns; learn from expressions.** Ratings accumulate positive and negative evidence when qualities recur across films. Expressions provide explicit context that can change how earlier ratings are interpreted. Never turn inferred patterns into supposed user expressions.
- **Compounding understanding, cost-conscious refresh.** New understanding can improve interpretations of older ratings, but full recalculation need not follow each expression. Separate changed input, meaningful changes to the expressions profile, and eventual recomputation.
- **Reflection should feel worthwhile.** Rating is quick and lightweight, with optional individual expressions that make reflection worthwhile. A separate conversational interface is a possible future experiment, not a core product requirement.
- **Useful before clever.** Start with a coarse, comprehensible quality vocabulary and simple matching; increase granularity only when results justify it.
- **Interpretations are provisional.** Viewers' tastes may evolve, and film interpretations may differ. Retain original expressions and analyses so classification can be revisited.
- **Traceability and visibility.** Sourced film information and qualities are available to users and can be reported as inaccurate. Classification can stay internal, but the product should be able to explain recommendations meaningfully.
- **Reusability and cost discipline.** Source context and accepted film qualities should be reusable; user interactions should not require unnecessary expensive model calls.
- **Independent and enthusiast-led.** Prioritise excellent discovery, meaningful reflection and sustainable maintenance over growth funnels, advertising inventory or maximising revenue.
- **Recommendation integrity.** Sponsorships, commissions and commercial relationships must not influence the underlying taste match or recommendation ranking.

### Accounts and privacy

Start visitors in the ratings experience and let them use ratings, recommendations and their library as email-free guests before registering. Create the temporary identity when personal activity needs saving. Guests and registered users share a revocable server-side session model. Guest sessions are issued without credentials; registered sessions follow successful password authentication. A normal browser-session cookie identifies the guest session across tabs; closing a tab does not end it, and browser restoration may preserve it. Enforce a fixed expiry 24 hours after guest creation, without extending it on activity. Explain that guest progress is temporary and registration keeps it. Expired guests lose access and cannot register to recover their old activity; the retention policy deletes abandoned guest identities and their associated activity. Deletion is eventual, not triggered by browser closure.

Registered accounts use email and password. For an existing guest, registration upgrades their internal user ID so activity is retained. Direct signup requires no guest or user record before confirmation. Store unverified email and password information in a separate pending registration, optionally linked to the existing guest; only verified registration stores an email on a user. Confirmation creates a registered account for direct signup or upgrades its linked active guest. Email confirmation is required to complete registration, rather than an optional step after registration. If someone starts signup and then uses the app as a guest in the same browser, preserve that continuity so confirmation retains their activity. Keep a verification reminder, the registration deadline and the temporary nature of guest activity visible until completion; unconfirmed signup does not make progress permanent. New registrations for an already registered email are rejected with sign-in guidance, without sending another confirmation. Entering an address alone never grants access to existing data. Signing into an existing account requires authentication and does not automatically merge guest activity. Collect no names, demographic details or public profiles. Registered sessions follow Rails authentication conventions without an application-imposed TTL; sign-out, revocation and account deletion end access. Verification uses an explicit confirmation action; merely viewing an email link does not complete registration. Identity cleanup is available as a bounded command for expired guests, sessions and pending registrations. The proposed cadence is every 15 minutes, but no scheduler is installed; Library watched activity uses an agreed scoped user foreign-key cascade so eventual expired-guest deletion removes its Library relationships and preserves shared films. Other product-activity deletion policies must be agreed before those domains persist guest activity.

Use one users table with stable internal IDs for guests and registered accounts; film and preference records reference only those IDs. Guests have no fabricated email or password. Use Rails authentication primitives as the starting point, with application-owned guest and registration behaviour. Resend is the delivery provider for verification and password-reset mail, with local previews and no real sending by default; development can explicitly use Resend for end-to-end verification, while automated tests remain local. This replaces the original magic-link decision.

Password recovery uses an emailed link valid for 15 minutes and an explicit new-password submission. Resetting revokes every existing session and requires fresh sign-in; viewing the link alone changes nothing. Ordinary request responses do not reveal whether the email is registered. Recovery does not merge guest activity or switch another signed-in account.

Ratings, expressions and taste profiles are private by default. Keep email out of AI inputs and analytics; filter email, passwords and authentication tokens from routine logs. This setup does not anonymise registered activity after a complete database leak. Separate identity infrastructure and custom email encryption are not initial requirements. Registered-account deletion anonymises and locks the retained identity and revokes access. The exact activity anonymisation/deletion policy needs specification before launch; abandoned guests and their activity are deleted rather than retained as deleted accounts.

## 3. Two engagement modes and a personal library

### 3.1 Rate films

The viewer cycles through horror films in an explicit rating interface. First they indicate whether they have seen the film. Selecting **Haven’t seen it** records the film as **confirmed unseen**, so it is not offered for rating again while that status remains. At this point, offer **Add to watchlist** or continue to the next film. Confirmed unseen alone leaves the film eligible for recommendations; adding it to the watchlist classifies it as To watch and excludes it from recommendations.

If they have seen it, they are presented with four ratings and optional expression inputs:

1. **Brilliant** — strong positive evidence.
2. **I Enjoyed That** — light positive evidence.
3. **Not For Me** — light negative evidence.
4. **Garbage** — strong negative evidence.

Encourage several simple, individual expressions of ideas rather than one large block of text. Each expression remains natural language, can concern multiple qualities, and may include context essential to its meaning. No tags or expressions are compulsory. The viewer saves the film's rating and expressions together, then continues.

Extreme reactions carry greater weight than mild reactions; numeric weights remain experimental. For MVP, prompts follow the overall rating's sentiment rather than deliberately soliciting mixed positive and negative observations. Preserve what viewers actually write.

Shared expressions may later provide inspiration in placeholders, with consent and moderation. Prefer changes on page load or manual request rather than during composition. Clearly labelled curated examples may precede real shared contributions. Seen confirmation precedes spoiler-bearing rating material. Film-information links are clearly labelled for spoilers.

### 3.2 Process recommendations

Present eligible films with an understandable, specific, spoiler-safe recommendation reason. Support useful spoiler-free film information and, where integrations permit, a trailer and external ratings. Reasons should reflect actual expressed preferences or inferred rating patterns rather than superficial similarity; ratings-only users must also receive explanations.

A viewer can:

- **Add to watchlist:** Classify the film as To watch. This is intent, not positive enjoyment evidence.
- **Mark watched:** Classify the film as Watched and queue it for a subsequent rating session if unrated. An immediate-rating link may be useful; a limited overall-rating interface is an option to evaluate.
- **Not interested:** Record that the viewer has not seen the film and does not want to watch it; classify it as Not interested and exclude it from future recommendation results and rating prompts. This is not negative quality evidence. Capturing a reason is deferred beyond MVP.

**Recommendations only contain films that the viewer has not classified.** To watch, Watched and Not interested all exclude films from results. Removing an unwatched film's classification makes it eligible again.

### 3.3 Personal library

Viewing status (**unknown**, **confirmed unseen**, or **watched**) is distinct from library classification. A confirmed-unseen film need not appear in any of the three classified library views. Marking it watched through the library or recommendation interface makes it available for rating. Removing a watchlist or Not interested classification does not erase confirmed-unseen status or return the film to rating prompts.

The library is the durable home for classified films, with **To watch**, **Watched**, and **Not interested** views. Watched films can be rated or awaiting a rating. Viewers can mark watchlist films watched, revisit ratings and expressions, and reconsider dismissed films. Exact transition wording and editing/history behaviour remain to be specified.

The library provides access to spoiler-labelled film information/qualities and inaccuracy reporting. It is also a potential future entry point for streaming/purchase options and community quality editing; those features are not MVP requirements.

### 3.4 Possible future reflection experience

A separate ThoughtForm-like conversation after a first watch or rewatch remains a plausible experiment, not a required milestone or architectural dependency. The core rating-and-expression interface should meet the product's reflection needs. A future conversation could acknowledge previous opinions and explore how they changed.

### Ownership of viewer activity

Library owns the canonical user–film relationship. Ratings owns its presentations, responses, ratings, expressions and taste interpretation. Recommendations owns its suggestions, responses, eligibility and ranking. Their histories remain separate; product-domain coordination uses durable asynchronous domain events. A completed rating publishes viewing evidence that Library consumes to establish watched state. Library publishes classification changes that Ratings and Recommendations consume independently. Watched-but-unrated films become ready for rating without another seen question; an already-rated film is not requeued. Not interested means not seen and not wanted: exclude it from rating prompts and recommendations. Removal does not assert that the film has since been watched or erase unseen history. A Ratings unseen answer alone creates no Library classification and does not exclude discovery. Choices made in recommendation or rating screens are recorded in their owning domain and delivered to Library asynchronously; successful Library changes and rejected requests have explicit outcomes. Brief propagation delays across screens are acceptable; lost or duplicate effects are not. Each domain's own action commits independently, with durable publication in its transaction. See the architecture decision in [domain events](domain_events.md).

## 4. Domain vocabulary (product concepts, not prescribed code objects)

- **Film:** A distinct cinematic work, with a stable external identity, credits and metadata; differentiate remakes and releases.
- **Film source information:** Maintained narrative/context material, principally Wikipedia, with source identity and revision. Whether Glutton needs an independent FilmAnalysis model remains open.
- **Quality:** A reusable characteristic potentially relevant to enjoyment or dislike: e.g. slow-burn storytelling, isolated environments, practical effects, demonic possession, oppressive atmosphere, folk ritual. Qualities are grouped into broad categories for classification, but need not appear as user-facing tags.
- **Expression:** A viewer's original natural-language account of what they appreciated or disliked. Expressions may correspond to several qualities and can carry context that those qualities do not capture.
- **Viewing status:** Unknown, confirmed unseen, or watched. Confirmed-unseen films are excluded from rating prompts until marked watched, but remain recommendation-eligible unless classified in the library. This status supplies no enjoyment evidence.
- **Library classification:** A viewer’s durable To watch, Watched or Not interested choice. All exclude a film from recommendations; only watched-film ratings and expressions supply enjoyment evidence.
- **Rating:** The viewer's overall four-level personal reaction to a watched film, carrying directional and strength information.
- **Film–quality association:** An accepted assessment that a film substantially exhibits a quality, grounded in source evidence; changes can make downstream scoring eligible for reassessment.
- **Expression–quality association:** An assessment that a viewer's expression indicates appreciation or dislike of a quality; can be re-evaluated with newer models/vocabularies.
- **Expressions profile:** An interpretation based **exclusively on the viewer's actual expressions**, retaining their context and associated qualities. Inferences from rating patterns must not be added to this profile as though explicitly stated.
- **Inferred preference profile:** The system's current positive and negative interpretation of the viewer's *entire rating history*, informed by the expressions profile. It is derived, provisional and can be recalculated as explicit context evolves.
- **Recommendation / response:** A proposal to watch a film and the viewer's response to that proposal; distinct from a watched-film rating.

**People as qualities:** Do not populate an enormous static list of actors, directors, writers and other contributors. Supply film-specific candidate people dynamically from verified credits when classifying an expression. Distinguish liking a performer's involvement from liking the film's themes or story.

Categories and exact granularity are provisional. Capture distinctions that matter to matching (e.g. film set in the 1970s versus a modern film with 1970s visual style) without making every individual technique a new quality. Rich source material need not imply a hyper-specific vocabulary. Quality categories are editable data, not hard-coded dimensions.

## 5. Catalogue, sources and film qualities

### 5.1 Initial catalogue and expansion

Target a diverse initial catalogue of 500 horror films, with useful source-backed quality associations at sustainable cost. Start from the provisional master vocabulary rather than generating qualities from a handful of film analyses. Initial coverage need not be exhaustive; the vocabulary and associations should be easy to improve.

After launch, users should be able to find/import a film through the external metadata catalogue. Deduplicate by stable film identity. Metadata/source enrichment and reviewed quality assignment are separate steps; importing a film does not imply it has accepted qualities or require generated analysis prose.

### 5.1.1 Initial catalogue and media source: TMDB

**Decision, 18 October 2026:** Use TMDB for now as the initial film search and metadata provider, including credits, external identifiers, posters/backdrops and trailer references. External data and media access must be free; paid plans and licensing are outside the current budget. Media is an important part of helping viewers assess recommendations and belongs in the core discovery experience. Play trailers through their supported host embeds rather than downloading/rehosting them.

Film analyses remain independently researched. Glutton retains its own film identities and source provenance so integrations can be changed. TMDB is selected as a practical working dependency; AI-connected use, donations and underlying media rights remain unresolved provider/licensing questions. The owner has chosen to proceed with that uncertainty; written confirmation is not an agreed prerequisite for this decision. No provider enquiry or signup has been performed in this discussion. This decision does not assert permission or create a paid commitment.

A preliminary website check found Alucarda, A Page of Madness, Tumbbad, Saloum, Skinamarink and separate 1977/2018 Suspiria records. Full seed coverage, metadata accuracy, trailer playback and UK availability still need validation. Distinguish original film year from regional release dates and re-releases. Do not treat provider overviews, trailers or artwork as automatically spoiler-safe.

Film pages should eventually provide country-specific viewing options. MVP may omit availability or use the supplied external TMDB watch-page link, with applicable attribution. Embedded offers and direct provider links remain later options; availability and affiliate relationships must remain separate from taste ranking.

TheTVDB, OMDb, Fanart.tv and KinoCheck are alternatives or supplements, not required initial integrations. Custom Glutton artwork remains an optional creative direction. The architecture brief retains research findings and the limits of the KinoCheck coverage trial.

### 5.2 Qualities and editable categories

A quality must plausibly influence whether a viewer enjoys or avoids a film through its substantial portrayal. “Humans are the real monsters” describes a moral outlook; an incidental prop or plot convenience may not be a useful taste distinction. Definitions, exclusions, prominence/context and a preference hypothesis matter. These hypotheses remain revisable; perfect initial coverage is unnecessary.

The [working vocabulary](film_qualities/MASTER_LIST.md) has 235 candidates, aiming for roughly 250 without padding. Assign at most **20 qualities per film**, not a quota. Reduce redundant signals; the cap alone does not establish fair comparison scores.

Qualities and quality categories are editable product data. Adding a category must not require deployment. A category move or cosmetic rename preserves quality identity and does not itself rescore. Adding/removing concepts, changing meaning, splits and merges require appropriate reassessment without losing original ratings/expressions or historical score explanations. [Task 043](specs/043_editable_quality_categories.md) plans replacing the current code-managed dimensions; implementation has not started.

Owner clarification, 28 October 2026: **start with equal base quality weights and equal category multipliers**. Greed being central to a film's story does not make it more important to a viewer than minimal dialogue. JEV should establish supported characteristics, without a default film-centrality gate or importance/confidence scoring multiplier. Meaningful presentation and content qualities receive the same base treatment as themes/subgenres. Which supported qualities earn the max-20 slots remains a separate editorial/selection question; no category quotas or automatic confidence top-20 policy is settled.

User-derived contributions still reflect rating strength and explicit likes/dislikes/indifference under the scoring design. Future category weighting may be system-controlled or user-controlled, but controller and mechanics are undecided. All categories start equally; no weight fields or controls are required now. See [equal-baseline requirements](film_quality_requirements.md#equal-starting-weights-and-personal-preference).

### 5.3 Sources, accepted changes and historical scores

Follow Wikipedia's maintained film pages for useful narrative/context, with retained revision, attribution and licence. BFI can supplement gaps. Glutton's community should focus on quality definitions, source-backed associations and corrections rather than duplicating Wikipedia's encyclopaedic maintenance.

A Wikipedia refresh updates source material; it does not automatically trigger JEV evaluation, replace accepted qualities or rescore users. A deliberate accepted change to the qualities associated with a film—likely through a manually reviewed community action—is the proposed boundary for downstream reassessment. Source refresh, candidate assessment and accepted association changes are separate actions. Exact editing/acceptance, refresh and event contracts still require discussion.

Preserve rating-quality and recommendation-quality records as the record of the qualities and contributions used in historical scoring. Historical explanations read those saved results. They should not reconstruct earlier recommendations from a film's current qualities or the user's current profile.

Whether FilmAnalysis/AnalysisQuality still serve a useful independent purpose remains open. They are not required solely to explain historical scores, and there is no settled requirement to archive every former film-quality set. Consider current source information plus directly managed current associations; identify any separate review, rollback or audit need before retaining additional history. No existing model or data is removed by this documentation decision.

### 5.4 Film information, reporting and comparison

Present useful sourced film information, accepted qualities and their context with spoiler labelling and a way to report inaccuracies. Keep film facts/traits separate from personal predictions. Normal navigation from watched Library may warn about spoilers; direct access need not enforce watched status. Discovery cards remain spoiler-safe. Community moderation UI remains separately scoped.

The proposed podcast can compare original expectations with the hosts' submitted reactions using actual historical score contributions. It does not require Glutton to own a second encyclopaedic narrative or invent predicted scene reactions. Film information, personal recommendation explanation and review comparison remain distinct presentation responsibilities, not a commitment to an analysis persistence model.

See [film-quality requirements](film_quality_requirements.md) for evidence, JEV question/request-packing discussion, reassessment boundaries and open model decisions.

## 6. From expressions to recommendations

### 6.1 JEV assessment and context

JEV is the chosen engine for quality assessment and expression interpretation. Give it explicit concept definitions, exclusions and useful film/source context; preserve original viewer text. An expression can match multiple qualities and may describe a particular portrayal rather than an unrestricted liking for a topic. Presence probabilities are not preference weights.

Discuss logical judgments separately from request packing. One independent question per quality can be sent in one request, several batches or separate calls. No production batch size, category partition, threshold or preference-strength primitive is settled. Compare the actual context/failure/cost tradeoffs before selecting packing; the earlier batch-of-50 setting is not a product requirement. See [JEV questions and packing](film_quality_requirements.md#jev-questions-and-request-packing-remain-to-be-agreed).

### 6.2 Preference evidence and contextual reinterpretation — core MVP behaviour

Glutton uses **one recommendation process with two complementary sources of evidence**:

1. **Rating-pattern evidence:** Each of the four ratings contributes positive or negative evidence for the qualities associated with the rated film. Brilliant/Garbage contribute more strongly than I Enjoyed That/Not For Me. A quality recurring across positively rated films accumulates positive evidence; recurring across negatively rated films accumulates negative evidence. Do not infer positive appreciation from mere exposure or frequency of watched films. Rating-only users must still receive useful recommendations.
2. **Explicit-expression evidence:** The user's actual words, classified against qualities with relevant sourced film context, identify more particular reasons for enjoyment or dislike. An expression may concern *how* a quality is presented, not simply the presence of a topic (e.g. liking **monstrous, non-romanticised vampires** does not establish an unrestricted liking for vampires). Preserve original wording and contextual meaning. Support matching multiple qualities without prematurely requiring compound or conditional-quality infrastructure.

The **expressions profile is derived only from explicit expressions**, never from rating patterns or earlier inferred preference scores. It can become more precise as users express more. The **inferred preference profile** aggregates rating evidence and may use that expressions profile as an interpretive lens to attribute greater relevance to some of the qualities present in previously rated films. For example, an explicit appreciation of grotesque practical effects may make those qualities more plausible explanations for older positive ratings that had no expressions. New expressions should not be retroactively fabricated for those ratings.

**Contextual reinterpretation of historical ratings is an MVP requirement.** The product must be capable of updating its inferred view of *all* rated films in light of a meaningfully changed expressions profile; it is not enough merely to append new expression weights to future recommendations. This compounding behaviour is central to Glutton's engagement promise.

Maintain the distinction between direct evidence and inferred attribution. Reinterpretation must not recursively feed its conclusions into the expressions profile or count reinterpreted evidence as independent additional user statements. The initial numeric formula, balance between implicit and explicit evidence, degree of redistribution and approach to conflicting/conditional preferences are **open experimental and architectural decisions**.

### 6.3 Save-time assessment, profile building and periodic improvements

Saving a film triggers two distinct assessments:

1. **Quality scoring through JEV:** Assess implicit evidence from the rating and explicit evidence from the submitted expressions. Implicit scoring uses the expressions profile that existed before this submission; it must not include updates derived from this film's newly submitted expressions. JEV handles both kinds of quality scoring; Claude is not required for this scoring round. Preserve the distinction between implicit and explicit evidence.
2. **Expressions profile building:** Independently assess whether the submitted expressions meaningfully change the viewer's explicit preference understanding. The proposed cost optimisation is to ask JEV first, then ask Claude to update the profile only when warranted. Benchmark this gate, including additions, refinements and contradictions; it is a hypothesis rather than a proven cheapest or most accurate approach. The profile remains exclusively grounded in original expressions.

New expressions benefit recommendations through their own explicit scoring once processing completes. Updated profiles inform subsequently assessed films once available. Earlier ratings are reinterpreted through periodic scoring improvements, including the implicit scoring of the submission that changed the profile. A viewer who first rates many films without expressions and later adds some receives that retrospective benefit when reassessment runs.

Saving viewer input and completing assessment are distinct. Users should be able to continue rating while processing completes. Do not claim that recommendations already reflect changes still awaiting processing.

The exact periodic cadence, meaningful-change criteria and any manual/on-demand refresh control remain open. A profile assessment that finds no material change should not force full historical recalculation. New ratings need not reprocess all previous ratings. Retain sufficient input/version provenance to recover from failures and revise assessments after edits or processing improvements.

Refresh must replace or supersede previous interpretations rather than count them again. It must not feed inferred conclusions into the expressions profile. The detailed reassessment method, reuse opportunities and cost limits belong to implementation experiments; constant live reprocessing is not required.

### 6.4 Matching baseline

Using the current inferred preference profile and the film–quality associations, begin with a straightforward recommender that:

- Handles positive **and** negative preference evidence, including repeated quality patterns and direct expressions.
- Can rank plausible candidate films even for a viewer who supplies no expressions.
- Lets a single explicitly expressed quality influence interpretation of older ratings where relevant, without automatically dominating every other quality.
- Does not treat a liked vampire film as proof of a general liking for all vampire films; competing qualities and established rating patterns affect ranking.
- Excludes every film classified as To watch, Watched or Not interested; confirmed-unseen status alone does not exclude it from recommendations, although it does exclude it from rating prompts.
- Produces traceable, spoiler-safe reasons for recommending a film.
- Captures watchlist, watched and not-interested decisions without treating intent or dismissal as enjoyment evidence.

Do not prescribe weights, thresholds, refresh schedules or scoring mathematics in this brief. Film-level similarity is a useful baseline, not synonymous with predicted enjoyment. More specialised conditional-quality matching remains a testable later refinement, not an MVP prerequisite.

### 6.5 Evaluation

Test coverage (important characteristics captured), overlap (meaningful similarities across films), discrimination (different films remain distinguishable) and usefulness to users. Evaluate the agreed JEV question design on expressions that are short, elaborate, ambiguous, multi-quality and paraphrased, including cases with no appropriate quality. Measure precision/recall against hand-labelled examples, cost and latency. Measure recommendation usefulness separately from quality-tag overlap. Compare **rating-only** recommendations against **expression-informed, historically reinterpreted** recommendations. Test positive and negative recurring signals; an isolated liked film with an otherwise unfamiliar quality; expressions that identify a particular portrayal rather than a whole genre; changes that materially affect and do not affect the expressions profile; and before/after recommendation rankings on a refresh. Verify that repeated recalculation without new inputs does not amplify preference strength. Re-evaluate previously stored data after vocabulary or prompt changes where justified.

## 7. MVP scope and staged delivery

**Foundational MVP / first working loop**

- Small seed catalogue with film metadata, sourced context and provisional film–quality associations.
- A cycling rating interface with persistent confirmed-unseen status, exclusion of confirmed-unseen films from rating prompts, direct watchlist addition for unseen films, four-level personal ratings and **optional multiple individual expressions**, saved together.
- A library with To watch, Watched and Not interested views, pending-rating access and the ability to revisit ratings and expressions.
- Source-backed film information and qualities accessible with spoiler-labelled navigation and manual inaccuracy reporting; independent analysis-model retention remains open.
- JEV implicit and explicit quality scoring using the pre-submission expressions profile, plus separate expressions-profile assessment/building based **only on explicitly submitted expressions**; retain original text.
- Positive and negative preference inference from recurring qualities across rated films, including for users who never submit expressions.
- **Contextual reinterpretation of existing ratings** when the expressions profile changes meaningfully, through periodic reassessment rather than compulsory recalculation after each expression; exact cadence and optional manual refresh remain open.
- Baseline recommendations using the current inferred profile, spoiler-safe explanations, and watchlist/watched/not-interested actions. All three library classifications exclude films from recommendations.
- A usable bulk-rating flow that does not require selecting tags.

**Subsequent milestones**

- External catalogue lookup and user-requested film import with source/quality enrichment (may be implemented earlier if useful, but should not block the first loop).
- A separate conversational reflection or rewatch experience is an optional future experiment, not a committed milestone.
- More expressive recommendations and richer feedback, including reasons for Not interested, where evidence justifies it.
- Shared viewer expressions as rotating inspiration on watched-film pages, once consent/moderation mechanisms are adequate. A prototype may use clearly labelled curated examples before real shared contributions exist.

**Explicitly out of scope initially**

- User-edited analyses and community moderation/reputation systems.
- Separate objective film-quality ratings.
- Forced positive-and-negative characteristic capture for every film.
- Social following, shared viewing and broad film coverage beyond horror.
- Exhaustive fine-grained quality hierarchies, elaborate conditional-quality modelling, and constant live generative processing. (Basic retrospective reinterpretation **is** in scope.)
- Subscriptions, mandatory paid tiers, advertisements, paid ranking or acquisition-driven growth features.

## 8. Working vocabulary and design limits

The [working master list](film_qualities/MASTER_LIST.md) is provisional editorial material, not accepted production assignments or validated preference prediction. Retained [matching inputs and six review examples](film_qualities/README.md) support the next selection/community-review design work. Further individual-quality tuning is not a prerequisite. Superseded generative-analysis and JEV tuning artifacts were removed at the owner's request; [concise findings](research/film_quality_findings.md) preserve the useful evidence and limitations.

Editable categories are planned, while JEV request packing and the need for independent analysis/history models remain open. Historical score contributions must remain inspectable as vocabulary and film assignments evolve.

## 9. Sustainability, monetisation and long-term possibilities

**Operating goal:** Glutton can succeed as a small personal project that real horror enthusiasts use and return to. Revenue is welcome insofar as it offsets infrastructure, metadata, hosting and AI costs as usage grows; profitability, recurring revenue and business scale are **not** success conditions. Keep costs observable and predictable, particularly for source assessment, quality scoring, profile synthesis and periodic reassessment; future conversations would add another variable cost. Reuse sourced context and classifications wherever practical, set sensible limits on variable-cost operations, and revisit those limits using actual usage data.

**Initial monetisation stance:** No subscription requirement and no paywall in the MVP. Basic rating, free-text expressions, core recommendations and accessible film analyses should remain free. Consider an unobtrusive mechanism for **voluntary one-off donations** once there are users; it should not interrupt the product experience. If the future interactive/ThoughtForm-like reflection experience has substantial marginal AI costs, optional pay-per-use or one-off credits could be explored later, rather than assuming a subscription. Do not paywall it until usefulness, demand and cost are understood.

**Where to watch:** A useful product feature irrespective of revenue. Let viewers see legitimate streaming, rental or purchase options for recommended films, ideally country-specific, with clear provider attribution. The availability-data integration and any affiliate-tracking mechanism should remain conceptually separate from recommendation selection and ranking. Investigate whether reliable UK streaming availability, title-level links and affiliate payments can realistically be obtained; these are **unverified commercial/integration dependencies**, not assumed capabilities. A low-friction prototype might use TMDB's watch-provider information, while direct JustWatch/other partnerships are potential later options subject to terms and eligibility. Optional physical-media affiliate links may suit enthusiasts. Clearly disclose affiliate relationships.

**Licensing and contributor rights:** Public accessibility does not automatically mean source material, imagery, metadata or reviews can be republished or commercially reused. Check provider terms, attribution and permitted use before enabling donations/affiliates or scaling. If viewer expressions, analyses or future community contributions become valuable collective data, establish clear, respectful permissions and privacy practices; avoid treating user-submitted text as freely transferable merely because it is stored by the application.

**Long-term opportunity, not roadmap obligation:** A distinctive recommendation experience, useful source-backed film qualities, an evolving quality vocabulary, and an engaged horror community may become independently valuable. A discovery platform might someday wish to partner with or acquire Glutton. That is an optional outcome of building something people value, **not** a reason to adopt startup-style growth targets, premature commercial architecture or engagement tricks. The product remains successful if it stays small, loved and economically sustainable.

## 10. Non-binding technical considerations for architectural design

The next phase should decide architecture, persistence and integration boundaries. Candidate direction, **not requirements**:

- Ruby on Rails and PostgreSQL in a cohesive monolith; no initial distributed-service requirement.
- Explicit separation of catalogue/enrichment, personal taste and discovery responsibilities, without assuming Rails engines or specific module boundaries.
- Database-backed editable quality categories, stable quality identities and current film associations. Independent analysis/history models remain an open decision.
- Background jobs where justified for source refresh, accepted quality-change reassessment and external enrichment; an additional on-demand refresh control remains an option.
- Adapter boundaries for metadata provider, source retrieval, JEV quality scoring/profile-change assessment, Claude expressions-profile synthesis and recommendation evaluation.
- Persistence of source provenance, relevant source/accepted-input identity, quality-vocabulary revision and classification run metadata to support reproducibility.
- Usage limits, deduplication, retry/idempotency and sensible costs for external model/provider calls.

Avoid choosing framework patterns or building abstractions solely for potential future community features. Implement only the boundaries that current behaviours require, then evolve them.

## 11. Open product questions / acceptance tests

**Open:** Where-to-watch data availability, provider licensing and actual affiliate eligibility; when to expose a voluntary donation link; how AI usage costs change with real users; how to display rating strength without implying artistic merit; spoiler labelling and presentation details; consent/review for shared expression prompts; whether the first recommendation version needs any minimum taste profile; source coverage sufficient for useful initial qualities; whether independent analysis models/history are needed; JEV request packing; whether user film import belongs in the first release or immediate follow-on; exact Jev primitives and thresholds; the initial evidence weighting and contextual attribution strategy; criteria for meaningful expressions-profile changes; periodic reassessment cadence and optional manual refresh; expressions-profile structure and validation of the JEV novelty/change gate; library transitions and re-rating/expression edit and deletion behaviour; how detailed recommendation explanations should be.

**First-success tests:**

1. Can someone rate a dozen familiar films quickly, **without writing any expressions**, and still receive plausible recommendations?
2. Can it accumulate distinct positive and negative evidence from qualities repeatedly appearing in films the viewer rates? Can it identify meaningful shared qualities from the expressions users do choose to write?
3. Can it suggest an unclassified film with a believable, spoiler-safe explanation, and exclude it after a To watch, Watched or Not interested decision without adding false enjoyment evidence?
4. Can users inspect sourced film information and quality context, and report an inaccurate association?
5. Can classifications be regenerated after a quality change without losing the viewer's original expressions?
6. After a viewer supplies an informative expression, can Glutton **reinterpret older ratings** and produce sensibly changed recommendations at a periodic refresh (or optional on-demand refresh), without manufacturing new explicit expressions or self-reinforcing scores?
7. Can save-time JEV scoring use the pre-submission profile while separately assessing profile changes, with explicit evidence taking effect after scoring and historical evidence improving after refresh?
8. Can viewers manage their three library views, find watched films awaiting ratings, revise ratings/expressions, and reconsider dismissals?
9. Does Haven’t seen it prevent repeated rating prompts while preserving recommendation eligibility, and can the viewer add it directly to To watch? Does marking it watched subsequently make it available to rate?
10. Can source information be refreshed independently of accepted quality changes, with scoring updated only for relevant accepted changes?

**Product hypothesis:** Ratings identify recurring patterns in what horror enthusiasts like and dislike. Optional expressions provide the context to reinterpret those ratings more intelligently, yielding increasingly relevant and understandable recommendations as users engage—while making reflection on films rewarding in its own right. **Rate films to narrow; express yourself to supercharge discovery.**

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

Library film details: selecting a film in a Library collection opens its existing Library relationship detail page. Information and available actions are defined by model behaviour. Task 021 supplies detail access and watchlist removal/mark-watched actions; task 022 replaces its subtype-based presentation with a shared composition of content-named partials guarded by model permissions, and adds dismissal-management actions. Existing watched rating entry remains. A removed relationship is unavailable rather than recreated by visiting its old URL.

Library entry creation is distinct from actions on an existing entry. Ratings activity currently establishes watched entries through asynchronous Library event handling; recommendations acceptance is a future creation source. A future TMDB search may offer rating or explicit Add to watchlist, with watchlist creation followed by a redirect to that Library film detail page. Browsing details never creates entries and requires the LibraryFilm ID, not a shared Film ID.
