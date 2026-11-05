# Edit existing quality definitions in Registry

Status: Draft — prepared for owner review; implementation not started  
Owner: Registry

## Goal

Let a superuser correct an existing quality’s matching definition and exclusion text through the Registry frontend, within the same concept. This is the first independently verifiable part of manual Registry editing after read-only inspection. Follow the implementation plan, film-quality requirements and review workflow; consume the existing Registry superuser policy, Phlex/RubyUI frontend and Quality optimistic-lock column.

## Scope

- Add edit/update entry points for an existing Registry quality, linked from its detail page. Display its immutable name and current category as context; only match_rule and not_sufficient are editable.
- Use a full-page Phlex view under app/views/registry and a domain-owned form component only where reuse warrants it. Use existing RubyUI controls, shared themes, English locales, accessible labels and field/error associations. Keep entered values on validation or stale-form failure.
- Preserve the existing Registry route authorization before loading content. Signed-out requests use the established sign-in flow; active guests and ordinary registered users cannot edit; expired/deleted/revoked identities retain Identity behavior. Re-read authoritative privilege at the mutation boundary; document transaction/locking order so concurrent privilege revocation cannot be bypassed by stale user state. No Identity mutations are permitted.
- Controllers own permitted parameter shape and submitted lock-version format, response status and redirects. Services own loading, existence/freshness checks and transaction coordination. Quality owns its explicit definition-edit operation and validation/invariants. Do not query the same record independently in controller and service or add generic permission/mutation frameworks.
- Require both definition and exclusion to be nonblank for an edit; do not expose a definition-purge operation. Keep names and category immutable through this form, even if additional parameters are submitted. Do not add a new maximum text length without an existing requirement.
- Carry the originally displayed lock_version through submission. Reject stale edits explicitly rather than reloading the latest version and overwriting it; explain how to review/reload current text and resubmit. A successful update redirects to the quality detail with a localized notice.
- Preserve accepted FilmQuality links, category settings, film source data and immutable FilmQualityEval output/application evidence. Editing criteria does not run evaluation, automatically change film membership, rescore preferences or rewrite historical evidence. A different concept requires a later explicit creation/revision decision rather than silently repurposing the existing name/ID.

## Scope restrictions

- Registry owns this mutation. Shared Identity reads are allowed; no Identity, Library, Ratings or Recommendations writes.
- No quality/category creation or deletion, name editing, recategorisation, category-cap/weight editing, manual film-quality edits, imports/source refresh, AI/provider calls, budgets, seed execution, asynchronous event contract or scoring changes. Category settings and film-quality management are later separate Registry tasks.
- No new schema/history framework, definition-version migration, deployment or live data changes during preparation. Reuse existing lock_version and retained evaluation snapshots. Tests use explicit model actions/constructor fixtures; manual local work uses development and automated tests use glutton_test.
- Preparing this record does not start implementation or authorize publication, live editorial changes or provider expenditure.

## Acceptance criteria

- **AC1:** Only a current superuser can reach edit/update routes; malformed, missing, forged-session and revoked requests cannot mutate a quality.  
  Check: integration/service coverage for direct URLs, guest/registered/signed-out/deleted/expired identities, same-browser revocation, missing IDs, CSRF and privilege freshness at mutation time. Confirm unauthorized requests do not expose quality data.  
  Result: Not run.
- **AC2:** Definition edits are explicit, validated and resistant to stale forms.  
  Check: successful persisted change, both missing/blank/whitespace fields, bad parameter shapes/lock versions, forged immutable fields, two competing submissions and removed-record handling. Assert observable persistence/failures through the model-owned operation rather than generic test updates. Verify user-entered text is escaped and all authored copy resolves through strict locales.  
  Result: Not run.
- **AC3:** Editing affects only the current quality criteria.  
  Check: accepted associations, category settings and saved evaluation output/application remain unchanged; no provider requests, jobs/events, viewer-data writes or scoring occur. Use an existing evaluation-backed association to verify its saved definition/evidence remains readable after the edit.  
  Result: Not run.
- **AC4:** The editor is usable and verification is recorded.  
  Check: desktop/narrow and keyboard/focus checks, validation/stale feedback and successful return navigation; focused tests, PARALLEL_WORKERS=1 bin/ci, Rails eager-load and whitespace checks. Update maintained progress; mark Ready for review before PR preparation and transfer this record into the PR when publication is requested.  
  Result: Not run.

## Implementation notes

Not implemented. Read-only Registry inspection and the shared Phlex/RubyUI frontend are prerequisites. Category settings, manual associations, refresh and reassessment stay outside this outcome.

Review handoff: Pending owner scope review.
