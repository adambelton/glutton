# Clarify Ratings evidence contracts

Status: Draft — deferred; not implemented  
Owner: Ratings

## Goal

Make existing Ratings evidence semantics explicit for readers and assessment collaborators without changing which evidence applies. This is the separate non-structural follow-up requested during capability organisation. Each item below is independently actionable; the owner should agree its detailed API before implementation.

## Scope

### 1. Domain boundary: current applied quality scores

Problem: Recommendations::CompareBaselineRankings reconstructs the latest applied score set with grouped evaluation IDs over RatingQuality rows. Rating independently knows which evaluations actually applied. A consumer should not have to reconstruct this Ratings invariant.

Proposed change: expose a narrowly scoped Ratings-owned query or scope, located with QualityScoring if a service is appropriate, for current ratings' latest actually applied quality-score rows with explicit viewer scoping. Return the existing evidence needed for the ranking comparison without moving ranking, aggregation or recommendation eligibility into Ratings. Choose the smallest API after reviewing the existing model query. Do not introduce a repository or generic evidence abstraction.

Benefit: one owning definition of current/applied evidence, independent of consumer ranking arithmetic.

Risks: accidentally selecting the newest merely recorded evaluation, mixing score sets, including superseded ratings, leaking another viewer's evidence, or changing treatment of current unassessed revisions.

### 2. Optional local composition: assessment return contracts

Problem: EvaluateExplicitQualities returns itself with result/provider_calls; EvaluateImplicitQualities returns a hash while exposing provider_calls separately. EvaluateRatingQualities must remember both forms.

Proposed change: give the implicit operation a result reader and return itself, matching the explicit collaborator. Update only the composite's corresponding use. Keep distinct questions, explicit precedence, reuse and provider-call capture. No superclass, shared runner or generic result type.

Benefit: the two collaborators have a predictable local interface without merging their responsibilities.

Risks: changing the combined result shape, losing provider evidence, breaking no-question paths or repeating implicit work during explicit-evidence race recovery.

### 3. Optional local cleanup: unused refresh argument

Problem: RefreshTasteProfile#record_and_apply accepts notes: but does not read it. The caller's notes variable is still required for the unchanged-evidence check.

Proposed change: remove only the unused method keyword and corresponding call argument. Retain the notes comparison, synthesis-evidence freshness check, owner lock and all publication behaviour.

Benefit: the signature accurately describes the inputs needed for recording/publication.

Risks: confusing the unused argument with the required earlier unchanged-input check or weakening freshness validation.

## Scope restrictions

- Exclude completed directory, namespace, class-name, test-location and asset-path restructuring.
- Preserve model mutation ownership, current/applied evidence semantics, immutable evaluation history, provider requests, scoring arithmetic, transactions, locking, events and job identities.
- No live providers, paid services, query optimisation, generic assessment framework or profile-component extraction.
- This task owns the Ratings provider contract. A future Recommendations caller adaptation needs its owning scope and API agreement; do not change Recommendations' implementation implicitly under this record.
- The three accepted items need no new persistence or compatibility aliases. Do not rename persisted models or diagnostic history.

## Acceptance criteria

- **AC1:** The Ratings read operation returns only the specified viewer's current ratings and latest actually applied score set for each; an unassessed current revision contributes none.  
  Check: domain tests for two viewers, a superseded rating, multiple applied sets, a newer recorded-but-unapplied evaluation and a current unassessed revision. Compare results with the current consumer query on controlled fixtures without changing ranking.  
  Result: Not run.
- **AC2:** The read contract's inputs/result and treatment of missing/inactive viewers are agreed before implementation; it performs no writes and leaves recommendation eligibility/aggregation with Recommendations.  
  Check: owner API review and focused read-contract tests; preserve the shared-read/access rules.  
  Result: Not run.
- **AC3:** Explicit and implicit operations compose through the agreed local return contract without changing requests, evidence or applied scores.  
  Check: `bin/rails test test/services/ratings/quality_scoring test/jobs/ratings`; cover explicit precedence, empty/no-profile paths, inherited evidence, overlap recovery and last-good results at configured-client stubs.  
  Result: Not run.
- **AC4:** Removing the unused notes: argument leaves no-change detection, stale-input rejection and revision publication unchanged.  
  Check: `bin/rails test test/services/ratings/taste_profiling test/jobs/ratings/refresh_taste_profiles_job_test.rb`; exercise unchanged notes, notes changed during generation, cleared evidence and competing publication.  
  Result: Not run.
- **AC5:** Required regression, autoload and lint checks pass without live provider calls.  
  Check: `bin/rails zeitwerk:check RAILS_ENV=test`, `bin/rails test`, `bin/rails test:system`, `bin/rubocop`.  
  Result: Not run.

## Implementation notes

Not implemented. Structural work deliberately retained the inconsistent assessment return values and unused keyword. No production API has been selected for the proposed read operation.

Review handoff: Pending. Use this record for the eventual PR description and remove it when preparing that PR, following the repository task lifecycle.
