# Load initial Wikipedia context for a canonical film

Status: Draft — prepared, not started  
Owner: Film knowledge

## Goal

Attach an inspectable, revision-specific Wikipedia source packet to an existing canonical Film, ready for later initial quality assignment. This is the next small seed-first capability after the vocabulary seed. Reuse existing TMDB import for canonical film identity and existing Film.source_context storage; do not rebuild either.

## Scope

- Provide one Film knowledge operation accepting a canonical film ID and an explicitly identified English Wikipedia page ID. The caller supplies the verified film/page pairing; this operation does not infer identity from title similarity. Load/recheck the film inside the service boundary. This packet-loading operation can later serve both bulk and on-demand orchestration; it introduces no per-film approval workflow.
- Fetch an identified article through a narrow HTTPS MediaWiki client with a descriptive User-Agent, explicit timeouts, bounded response size and zero automatic retries. Pin content and provenance to the same revision. Use the documented revision/parse APIs rather than scraping page chrome or asking a model to research the film.
- Extract ordered source paragraphs with section labels and revision-local paragraph references, preserving source wording apart from documented HTML/citation/whitespace normalisation. Include the lead and available plot/narrative, production and reception context; exclude navigation, reference lists, infobox tables and unrelated page furniture. Do not summarise, invent interpretations or strip attributed opinions/production intentions into factual assertions.
- Persist page ID/title, revision ID and revision URL, retrieval time, article/history attribution links, applicable licence information and the extracted paragraphs together under Film.source_context. Avoid a second source model/history archive or unused version metadata. Preserve unrelated source-context entries and all TMDB metadata.
- Film owns the initial-context action and its permission to apply it. Fetch outside the write transaction; reload/lock the film before applying the complete packet atomically. Reject an already-attached Wikipedia packet rather than overwriting it or silently returning an idempotent success. A film deleted during fetching must not be recreated. Later manual source refresh is outside this operation.
- Distinguish invalid input, missing film/page, redirect/disambiguation/identity mismatch, unavailable or inadequate narrative context, malformed/incomplete payload and transport/rate-limit failures. Missing context is not successful enrichment. Fail without persisting a partial packet; keep accepted FilmQuality links/evidence unchanged. Settle exact error names, packet shape and deterministic extraction/readiness rules in this spec before implementation, using representative fixture pages.

## Scope restrictions

- No JEV/TypeSafe/OpenAI calls, paid experiments, quality assignment, selection arithmetic, suggestion comparison (deferred change evaluation), vocabulary changes, scoring, events or other-domain mutations.
- No automatic article discovery/film-page matching, bulk film-list curation, job/scheduler installation, user/admin screens, editing/refresh UI or generic source workflow. Callers may supply page IDs from verified seed mappings initially; automatic matching and pipeline wiring remain separately bounded work within the seed stage.
- No permanent enrichment queue/history tables or parallel copies of canonical film/source state. Readiness/failure here is the explicit operation outcome, not a new lifecycle engine. The eventual initial-assignment operation must require usable context; it cannot infer completion from TMDB metadata alone.
- No database reset or overwrite of existing development source/quality data. Automated verification uses fake HTTP and isolated test records. Preparing this draft authorises no implementation, live source import or external communication.

## Acceptance criteria

- **AC1:** One explicit operation stores useful source context with correct revision identity and attribution.  
  Check: fake-HTTP fixtures with lead, narrative, production and reception sections; exact normalised paragraph order/text, page/revision identity and attribution/licence persisted together. No external page furniture or generated prose.  
  Result: Not run.
- **AC2:** Missing, mismatched or failed source acquisition cannot become completed enrichment.  
  Check: invalid IDs, missing film/page, redirect/disambiguation policy, empty/inadequate context, wrong/missing revision identity, invalid JSON/HTML, oversized response, 429/5xx/timeouts and malformed payloads produce explicit failures and no partial writes.  
  Result: Not run.
- **AC3:** Initial enrichment preserves accepted qualities and respects concurrent/deleted state.  
  Check: existing Wikipedia context rejected, concurrent initial attempts cannot overwrite each other, film deletion during request fails, and TMDB metadata/unrelated source entries/quality associations/evidence remain unchanged. No Library/ratings/event activity.  
  Result: Not run.
- **AC4:** Verification and extraction limits are recorded before review.  
  Check: focused client/extraction/service/model tests, full CI, eager loading, whitespace and locales for any application-facing errors. Document reproducible commands, tested fixture coverage and any remaining identity/source-coverage limitations.  
  Result: Not run.

## Implementation notes

Not implemented. Follow the approved order: finish seed content before admin viewing/editing and later refresh/change-evaluation. This source-packet slice does not deliver the complete film seed. Canonical import already exists; bulk/on-demand pipeline wiring, verified page discovery/mappings and initial >=60% category-capped assignment remain to be scoped without making standalone refresh suggestions a prerequisite.

Preparation read existing Film.source_context, TMDB import/client/metadata roles, current quality requirements and retained source-packet examples. Official documentation consulted on 3 November 2026: [MediaWiki revision identity](https://www.mediawiki.org/wiki/API:Revisions), [revision-specific parsing](https://www.mediawiki.org/wiki/API:Parsing_wikitext), [article information](https://www.mediawiki.org/wiki/API:Info) and [API etiquette](https://www.mediawiki.org/wiki/API:Etiquette). These support the draft integration direction, not evidence that Glutton's source extraction or identity matching is implemented or verified. Relevant exact request/response fields and site licence metadata must be checked when implementing.

Owner acceptance / implementation approval: Pending. Draft preparation requested as the post-merge handoff; implementation has not started.
