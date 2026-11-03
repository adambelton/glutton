# Build deterministic film-quality suggestions

Status: Draft — prepared, not started; lower priority  
Owner: Film knowledge

## Goal

Priority clarification, 29 October: the owner places initial seeding and admin inspection ahead of standalone quality-change suggestions. Do not start this as the next product feature. Selection arithmetic can be reused within the initial-assignment task when needed; revisit this spec's refresh-diff scope only after seed loading, read-only canonical content inspection, manual editing and manual TMDB/Wikipedia refresh are usable. Expression-led vocabulary discovery comes after this stage and is deferred until after initial release.

Turn one complete set of recorded per-quality support probabilities into an inspectable proposed film-quality set under the 60% baseline and persisted category ceilings. Return a comparison with current accepted qualities without changing them. Prerequisites: the implemented direct quality catalogue and category settings, current requirements and retained selection-policy findings.

## Scope

- Define one small Film knowledge operation consuming a film identity and a complete probability map for an explicitly captured vocabulary. Load authoritative qualities/categories/current film links in the owning service boundary; arithmetic/ranking belongs in code, not another model question.
- Baseline minimum support is >=0.60. Require finite numeric values in [0,1], known quality IDs and complete declared coverage. Reject missing/unknown IDs, incomplete results, empty vocabulary and malformed values explicitly; do not substitute zero, clamp values or silently accept a partial provider response. Settle the precise callable input/result contract in this spec before implementation.
- Select within each persisted category by descending support, then stable Quality ID for ties. Respect maximum_qualities including zero; no category minimum, padding, cross-category slot borrowing or global 20 ceiling. Do not multiply support by category weight or send qualitative importance guidance.
- Return proposed IDs with categories/support and inspectable exclusion reasons (below threshold or beyond category ceiling). Return added/retained/removed IDs versus the film's current accepted set and an explicit unchanged comparison when appropriate. A manual association below the gate may appear as a suggested removal; never remove it automatically.
- Capture the minimal existing input/configuration identities needed to explain the result and detect superseded inputs later: relevant Quality/QualityCategory versions, source context identity and observed accepted IDs. Do not claim missing provider/input provenance proves freshness. A future apply operation must validate freshness separately; this task implements no apply action.
- Cover more than 20 selections across categories, independent category maxima, threshold equality, small/empty supported categories, deterministic ties, zero caps, category-weight independence, manual-correction diff, stale/missing vocabulary and malformed/incomplete inputs. Keep tests observable and persist the accepted set unchanged.

## Scope restrictions

- No TypeSafe/OpenAI requests, prompt/definition changes, new paid experiments or provider adapter. Use fixed probabilities in tests. No research vocabulary seeding or inference that the six-film examples are accepted catalogue data.
- No accepted FilmQuality mutation, publication event, Ratings/Recommendations/Library writes, score calculation, category-weight application, source synchronisation, bulk imports or admin UI. No new permanent suggestion/history table or generic workflow engine.
- Do not introduce category quotas, a new global maximum, importance/centrality ranking, preferences inferred from model support or hidden tie randomness. Preserve the existing names and category-setting semantics.
- Keep changes within this one Film knowledge operation/result contract. A provider integration or production apply/publication workflow needs its own scoped task and agreed downstream contracts.

## Acceptance criteria

- **AC1:** The selection policy is deterministic and respects configured category limits.  
  Check: exact >=0.60 boundary, per-category 0/2/5 and different caps, total >20, no padding/borrowing, stable ties, same outputs when category weights change. Assert output and exclusions, not incidental query order.  
  Result: Not run.
- **AC2:** Incomplete or invalid input cannot become a valid empty/partial suggestion.  
  Check: missing film, unknown/missing assessed IDs, empty vocabulary, nil/string/bool/NaN/infinite/out-of-range probabilities and superseded vocabulary/config inputs produce explicit agreed failures; a complete valid run with no supported matches yields a genuine empty proposal.  
  Result: Not run.
- **AC3:** Suggestions are inspectable and cannot alter accepted data.  
  Check: added/retained/removed and unchanged comparisons, preserved manual corrections and source/evidence/accepted links; no events or cross-domain mutations. Verify observed input identities are returned without pretending the future apply workflow exists.  
  Result: Not run.
- **AC4:** Bounded implementation verification is recorded.  
  Check: focused selection tests, full required CI, locales for any surfaced application-authored text, eager loading and whitespace; no new schema/provider work. Update plan and mark Ready for review only after implementation.  
  Result: Not run.

## Implementation notes

Prepared after the catalogue PR at the owner's request. This spec does not start implementation or authorise provider calls. Before coding, settle the exact expected-vocabulary/version input and error/result contract using existing persisted roles; do not add a parallel vocabulary model solely to simplify this service.

This task proves policy mechanics, not the semantic accuracy of JEV matches or fair recommendation scoring. Persisted definitions, source enrichment/provider assessment, explicit admin application and scoring remain separate capabilities.

Owner acceptance / implementation approval: Pending.
