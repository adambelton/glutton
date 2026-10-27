# 029 — Generate an analysis from an imported TMDB film

Status: Merged via PR #43  
Owner: Film knowledge

## Goal

Import a film from TMDB, then generate and save its initial analysis and quality candidates using the imported film data. OpenAI is used only for the initial seed; all revisions are manual. The workflow requires no manually prepared evidence packet, additional source collection, enrichment stage or manual application of generated output. Generated changes remain unpublished until the existing `film.publish_analysis!` operation is invoked.

Prerequisites: task 008 TMDB import, task 028 Film-owned editing/publication, task 027b managed prompt retrieval/linkage, and task 001m configured OpenAI client/tracing. Read the [analysis requirements](../film_analysis_requirements.md), [generation protocol](../prompts/film_analysis/README.md), and [configuration guide](../ai_configuration.md). All application behaviour in this task belongs to Film knowledge; no new cross-domain contract.

## Scope

- Provide an explicit developer entry point that takes a TMDB film ID and runs import followed by analysis generation. A lower-level generation operation accepts an imported Film with no analysis. Existing drafts and published analyses are ineligible for generation. Model, output-token limit and output location are configuration, not an editorial preparation step. Do not trigger paid requests on every ordinary import or model callback.
- Retain the analysis-relevant metadata returned by the existing TMDB movie-details request: overview, tagline, genre names/IDs, runtime, original language, and available production/release context, alongside existing identity fields. Define and validate the retained field shapes using representative TMDB fixtures. Do not add a separate enrichment source or require additional endpoints. The current importer keeps only title/date/original title and fetch provenance; extending this projection is necessary for generation.
- Preserve import deduplication by TMDB ID. If an existing imported film lacks the retained metadata, the workflow obtains it through the same movie-details import path before generation. This is automatic, not a new user step. Missing optional TMDB fields remain explicit unknowns; do not require a complete plot or supplemental sources before generating.
- Assemble the request automatically from the persisted Film identity and TMDB metadata, its TMDB reference/fetch information, and current shared quality vocabulary. Use the imported snapshot as the supplied source. Film identity does not prove a particular cut/version; report unknowns accurately. Do not claim to have viewed a film or inspected reviews/scripts/subtitles that were not supplied.
- Retrieve `film-analysis` from Langfuse once per run, by explicit version or development label. Preserve the returned name, version, text and hash together. Adapt the managed prompt/output contract to TMDB-backed generation and the existing `content`/`quality_candidates` structure as part of implementation review; no local editable prompt fallback or automatic production-label promotion. Current v1 returns Markdown and assumes supplied source material, so it cannot be treated as an already compatible persistence contract.
- Make one bounded OpenAI Responses request using existing configured clients, an explicit model/output cap, existing timeout and no automatic retry loop. The analysis should reflect the available information and identify coverage gaps. Separate supplied facts from interpretation; do not fabricate detailed scenes, audience testimony or citations to satisfy a completeness requirement. Missing coverage is not a prerequisite for an additional workflow stage. Narrative/moment counts follow available information, not fixed quotas.
- Validate the generated draft's JSON shape, dimensions, quality identities and evidence-reference consistency, then save `content` and `quality_candidates` through `film.edit_analysis!`. Generation must not call publication, create shared FilmQuality records or write AnalysisQuality associations. Apply the whole result atomically; no partial candidate/content update. Draft completeness and publication readiness remain separate: thin TMDB data may yield an explicitly incomplete draft without invented detail or forced candidates.
- Do not hold a database transaction across provider calls. Film owns the initial-only eligibility rule and enforces it again when saving atomically; generation cannot replace an existing analysis. A failed request leaves imported metadata available for an explicit retry while no analysis exists. No generation-preparation state, freshness snapshot or optimistic locking is needed.
- Save a new diagnostic run artifact with the exact imported input, resolved prompt snapshot, request settings, original response, response status/model/usage when supplied, trace ID and application outcome. Artifacts are automatic output, not files the user must prepare or reimport. No new provenance table/FilmAnalysis columns, credentials or hidden chain-of-thought. Never overwrite a prior run or present edited content as raw model output.
- Trace the run and its generation with stable names, exact prompt-version linkage, meaningful input/output, actual model/usage and distinct failure outcomes. Reuse the existing tracer provider and flush before command exit. Export failure must not repeat a paid request or undo an otherwise saved draft; report that limitation.

## Scope restrictions

- Only Film knowledge import/generation/model operations, command, prompt contract, tests and documentation. No Ratings, Library, Recommendations or Identity changes, downstream scoring or domain messaging.
- No manual evidence packets, source-gathering tasks, planned enrichment prerequisites, web search, scripts/subtitles/review acquisition or curator preparation. The current workflow is TMDB import followed by generation.
- No HTTP interface, curator accounts, background jobs, scheduling, bulk generation, 500-film expansion or automatic publication. Existing editorial review/publication remains unchanged.
- No dimension/vocabulary-management redesign, semantic quality matching, general workflow/evaluation framework or new analysis provenance columns.
- Reuse locked integrations: `openai` 0.113.0, `opentelemetry-sdk` 1.13.1 and `opentelemetry-exporter-otlp` 0.37.0. Verify current provider documentation before implementation; supporting dependency upgrades need separate scope.
- Tests use fake external responses, without credentials or paid calls. Owner approved implementation on 27 October 2026. Owner subsequently authorized the development prompt compatibility update on 27 October 2026, preserving existing quality guidance. A real generation still requires separate authorization with the chosen film/model/token limit.
- Application-authored user-facing errors use Rails locales. Do not translate imported or generated content; developer-only diagnostics follow existing conventions.

## Acceptance criteria

- **AC1:** A TMDB ID is sufficient to import the source film and assemble generation input automatically.
  Check: fake TMDB fixtures cover first import, duplicate import, existing films with missing metadata, optional missing fields and upstream failures. Verify identity deduplication and that the actual overview/metadata enter the request without a packet file or additional source request.
  Result: Passed. Focused import/generation/prompt/concurrency suite: 26 tests / 271 assertions, no failures; full CI includes the additional locked-SDK response test. Fixtures cover retained overview, genres, runtime, language, production/release context, missing values, malformed metadata, deduplication and automatic legacy refresh. Existing importer failure/concurrency tests remain passing.
- **AC2:** Successful generation saves one unpublished analysis through Film.
  Check: fake OpenAI output produces saved content/candidates, retains omitted factual coverage as gaps, and does not publish or create shared qualities/associations. Cover initial analysis and rejection of existing drafts/published knowledge before provider work. Revisions use the manual editing operation. No console copy/import step is required.
  Result: Superseded by the initial-seed-only correction in AC12 below; generated revisions are no longer supported.
- **AC3:** Invalid generation cannot partially save an initial seed, and existing analyses cannot be regenerated.
  Check: cover missing/deleted films, prompt failures, refusal/truncation, malformed documents, invalid dimensions/quality IDs, dangling or invented references, provider errors and attempted generation when a draft or published analysis already exists. Verify existing analyses remain unchanged, imported metadata survives generation failure, and an explicit retry is possible without duplicating films.
  Result: Superseded by AC12 below; freshness/concurrent-generation tests were removed in favour of initial-only eligibility and manual revision checks.
- **AC4:** Run artifacts and tracing reflect the actual input, prompt and outcome.
  Check: inspect local artifacts and in-memory observations for prompt identity, generation type, hierarchy, model, usage, output, persistence outcome and safe diagnostics. Test export failure without repeating generation. After separate live-run approval, run import-to-draft end to end, retrieve its trace using the Langfuse CLI and audit it against current guidance.
  Result: Passed (local). Artifact and in-memory span assertions verify exact prompt text/hash, input, request settings, raw output, hierarchy, prompt linkage, actual model/token usage using the locked OpenAI response classes, sanitized failures and export failure without retry or lost persistence. Distinct UUID files preserve prior attempts. Development prompt publication/retrieval subsequently passed under AC6. Live generation and CLI trace-ingestion audit: Not run; separately authorized film/model/token cap still required.
- **AC5:** The workflow is documented and bounded.
  Check: provide reproducible initial import-and-generate command examples using a TMDB ID, with no preparatory source or manual result-application step. Run focused tests, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, eager loading and `git diff --check`; record actual results here. Distinguish draft structural validity from factual assessment and publication readiness.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 520 tests / 5,597 assertions, 0 failures/errors/skips; RuboCop (254 files), gem/importmap security audits and Brakeman (0 warnings) passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed (standard mailer-preview exclusion notice); `git diff --check` passed. Commands and structural-versus-editorial limits are documented in the generation protocol.

## Implementation notes

Implemented on `codex/film-analysis-generation`. `TmdbMetadata` validates and projects the existing movie-details response; `ImportTmdbFilm` optionally fills legacy missing metadata while retaining deduplication and ordinary duplicate-import behaviour. The explicit `film_knowledge:generate_analysis` command imports then calls `GenerateAnalysis`. `AnalysisPrompt` retrieves one managed version through the established CLI, checks the `tmdb-analysis-v1` contract marker and retains text/hash. `GeneratedAnalysis` supplies the Responses JSON schema and validates source/evidence/candidate references before Film atomically saves the initial draft under its eligibility rule. No migration, cross-domain mutation, publication or dependency upgrade was added.

The workflow records owner-only UUID diagnostic artifacts, stable nested trace names and actual response data. The command flushes export and reports export failure separately from successful persistence. Incomplete drafts are permitted without changing task 028 publication rules. All new text is developer-only command/error diagnostics; no application UI copy was introduced.

Reproduce focused verification:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/services/film_knowledge/analysis_prompt_test.rb \
  test/services/film_knowledge/generate_analysis_test.rb \
  test/services/film_knowledge/import_tmdb_film_test.rb \
  test/services/film_knowledge/import_tmdb_film_concurrency_test.rb
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
RAILS_ENV=test bin/rails zeitwerk:check
git diff --check
```

Verification history: sandboxed PostgreSQL access was unavailable; tests were rerun with approved local database access. The first full CI run exposed a new test cleanup using association nullification against a non-null foreign key. Cleanup now deletes only the test's analysis rows; its leftover test film was removed. The subsequent focused suite and final full CI passed. No production/development film was generated.

Remaining limitation: no live generation or remote trace-ingestion audit has been performed. The owner subsequently authorized development prompt publication; compatible v2 is now published and verified under AC6. Local tests establish persistence/trace contracts, not factual quality or production provider compatibility. Structural validation checks references, not whether each prose claim is true. No automatic retry, source acquisition or analysis publication is introduced.

Tracing references: [Langfuse best practices](https://langfuse.com/docs/observability/best-practices) and [prompt linkage](https://langfuse.com/docs/prompt-management/features/link-to-traces). Recheck current documentation and use the Langfuse skill when implementing.

Owner acceptance / merge: Pending. Implementation is ready for review. Development prompt publication was subsequently authorized and completed under AC6. No real generation API call, production deployment, PR creation or merge performed.

## Authorized development prompt follow-up — 27 October 2026

Scope: update the existing managed `film-analysis` development prompt to consume the automatic TMDB input and return the implemented JSON contract; preserve its quality naming, granularity and genuine-match guidance. No application-code changes, paid generation, production promotion, prompt deletion or vocabulary redesign. Langfuse only permits content changes through an automatically numbered immutable version; retain the existing prompt name and development label.

- **AC6:** Development retrieval returns compatible instructions and config without changing quality-selection principles.
  Check: compare old/new instructions, publish via Langfuse CLI, retrieve by development label and exact version, compare text/hash/config, and invoke `AnalysisPrompt.call` without OpenAI. Verify old version remains available and production is not assigned. Run `git diff --check`.
  Result: Passed. Langfuse CLI published the authorized compatibility update as automatic version 2 under the existing `film-analysis` name. Labels: `development`/`latest`; no production label. Application retrieval using `FilmKnowledge::AnalysisPrompt.call(label: "development")` and `.call(version: 2)` matched exact text/config/hash (`9e937b0eaab4ae7885789c9d66bec3a4aed21172c92248afd5e76c78410bb79f`). CLI retrieval by version 1 confirmed its text remains unchanged. Preparation compared the previous quality-guidance block byte-for-byte and retained it verbatim. `git diff --check` passed. No application code changed and no OpenAI request was made; full CI was not rerun for this remote-prompt/documentation-only follow-up.

## Superseded implementation review history

Earlier review iterations introduced block wrappers, preparation state and freshness comparisons, then moved input assembly into Film and the generated document into `app/models/film_knowledge`. Those iterations passed their recorded local checks (up to 524 tests / 5,615 assertions), but the owner clarified that regeneration was outside the actual workflow. The initial-only correction below removes the concurrency/preparation machinery while retaining model-owned eligibility/input/save operations and service-owned provider orchestration. No optimistic-locking migration was created or applied.

## Owner scope correction — initial seed only

The owner clarified that OpenAI generates only the initial seed after film import. All revisions are manual. This supersedes earlier regeneration/freshness requirements and the preparation/guard follow-ups above; optimistic locking was discussed but not implemented.

Scope: remove preparation state, snapshot comparison, stale-generation errors and generation concurrency machinery. Film owns a single eligibility rule: imported TMDB identity, retained metadata and no existing analysis. The service checks it before provider work; the save action enforces the same rule and atomically saves the initial unpublished draft. Failed attempts may be retried while no analysis exists. Existing task 028 manual editing/publication stays unchanged. No lock_version migration, prompt changes or new workflow states.

- **AC12:** OpenAI only seeds films with no analysis; later revisions remain manual.
  Check: verify initial generation, refusal of existing drafts/published analyses before prompt/provider calls, direct repeated-save rejection, manual editing after generation, atomic failure and explicit retries. Run focused tests, full CI, eager loading and whitespace checks. Confirm no generation preparation/snapshot/stale or optimistic-locking code remains.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_test.rb test/models/film_analysis_test.rb test/services/film_knowledge/generate_analysis_test.rb`: 45 tests / 348 assertions. Final `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 522 tests / 5,618 assertions, no failures/errors/skips; all style/security checks passed. `RAILS_ENV=test bin/rails zeitwerk:check` and `git diff --check` passed. Initial seeding, rejection of existing drafts/published analyses before prompt/provider work, manual revisions and failed-attempt retries are covered. Source inspection found no generation preparation/state-comparison methods, stale-analysis error or lock_version column. The obsolete generation-concurrency test was removed; existing manual-analysis lifecycle/concurrency coverage remains. Ready for review; acceptance and merge pending.

## Owner acceptance — 27 October 2026

The owner accepted the final implementation and authorized PR creation and merge after hosted CI, together with tasks 028a, 028b and 029. Latest combined local CI passed 522 tests / 5,618 assertions with clean style/security checks; eager loading and whitespace checks passed. This acceptance does not authorize a paid film-generation run. Hosted CI and merge evidence will be recorded after merge.

## PR #43 merge — 27 October 2026

Owner-authorized [PR #43](https://github.com/adambelton/glutton/pull/43) merged at 16:38:40 UTC as squash commit `94758745f8b9d1c9a8cb6f7c7fcaa2fdf2cd2fd5`. Hosted [Repository checks](https://github.com/adambelton/glutton/actions/runs/40542518272) passed on exact head `641f6de76daae15c13c82a1fc47dbd0b2c22f6e5` at 16:37:26 UTC. Local main was fast-forwarded. Earlier acceptance/pending statements describe pre-merge history. No real film-generation request was made.

Post-merge [main CI](https://github.com/adambelton/glutton/actions/runs/40542938308) also passed on the squash commit.
