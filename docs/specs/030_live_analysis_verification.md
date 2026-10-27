# 030 — Verify one real initial film analysis

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Verify the merged import-to-draft workflow with one real film and inspect the generated analysis, saved draft and actual Langfuse observations. Produce a small evidence report describing what worked and what the supplied TMDB metadata could support. Prerequisites: merged tasks 028a, 028b and 029, configured OpenAI/Langfuse integration from tasks 001m/027b, and the [generation protocol](../prompts/film_analysis/README.md).

## Scope

- Use approved Alien (1979), TMDB ID 348, for one development run using the existing `film_knowledge:generate_analysis` command. Confirm it has no existing analysis before execution; preserve any existing manual work. Film/model/output-token allowance must be explicitly agreed before the billable request. Preparing this spec does not authorize execution.
- Pin the verified `film-analysis` prompt to version 2, contract `tmdb-analysis-v1`, expected SHA-256 `9e937b0eaab4ae7885789c9d66bec3a4aed21172c92248afd5e76c78410bb79f`. Retrieve and compare before spending; stop if the agreed instructions differ. Keep the model explicit rather than treating the earlier connectivity diagnostic's model as an analysis choice.
- Run the existing TMDB import and initial generation once, with the agreed model and positive output-token cap. Retain the automatically produced UUID artifact as the original request/response record. Use the existing locked integrations: `openai` 0.113.0, `opentelemetry-sdk` 1.13.1 and `opentelemetry-exporter-otlp` 0.37.0; this verifies the merged implementation without dependency changes.
- Verify one unpublished FilmAnalysis was saved, with content and quality candidates matching the validated response; generation must not publish the analysis or create FilmQuality/AnalysisQuality records. Verify the model refuses further generation eligibility after the successful seed without making another provider request.
- Retrieve the trace/observations through the Langfuse CLI using the Langfuse skill and current API documentation. Verify root/child linkage, prompt name/version, supplied input, returned output, actual model/usage and application outcome. Record provider usage and reported cost when available, distinguishing missing data from zero cost. A local trace ID alone does not prove remote ingestion.
- Review the original generated content against the actual supplied TMDB snapshot and the [analysis requirements](../film_analysis_requirements.md). Identify unsupported scene detail or audience claims, explicit gaps, source/evidence-reference consistency, and whether candidate qualities have support and meaningful distinctions. Separate structural validity and honest incomplete coverage from factual or recommendation-quality claims. Do not add sources or rewrite the output to make the run look successful.
- Record reproducible commands, film/model/token settings, prompt hash, artifact path/hash, response and analysis IDs, verified trace link and review findings in `docs/research/generated_analysis_verification/README.md`. Preserve the original artifact locally; do not commit credentials or present edited text as model output.

## Scope restrictions

- One Film knowledge verification outcome, one film and at most one billable generation attempt. No bulk processing, background jobs, automatic retries, extra research sources or enrichment stages. If the attempt fails, retain the failure evidence and propose the smallest follow-up; another billable attempt requires authorization.
- No production deployment, prompt edits/promotion, model benchmarking, vocabulary redesign, evaluation framework, schema changes or new services. Evidence from this run can justify a separately scoped fix; do not tune the prompt during verification.
- Leave the generated draft unpublished. No manual authoring revision, shared-quality creation, community review workflow, browser UI, Ratings/Library/Recommendations changes, scoring or domain events.
- All revisions remain manual. Use model actions and scopes for state inspection; do not add instance-variable access, new freshness state or concurrency machinery.

## Acceptance criteria

- **AC1:** An authorized real request saves exactly one initial unpublished draft through the existing workflow.
  Check: record before/after analysis and quality counts, execute the command once with approved settings, compare the saved content/candidates with the artifact, and check `film.can_generate_analysis?` is false after success. On failure, record the actual outcome and unchanged/partial state instead of claiming success.
  Result: Passed. The owner-approved single command completed with `gpt-4.1-2025-04-14`, cap 12,000 and pinned prompt v2. Before: no Alien record and counts 0/0/0. After: Film 1, unpublished FilmAnalysis 1 and counts 1/0/0 for analyses/qualities/associations. Saved content and candidates exactly match the original response; `can_generate_analysis?` is false. All seven post-run assertions passed without another provider call. See the [evidence report](../research/generated_analysis_verification/README.md) for command and artifact details.
- **AC2:** The exact request and remote trace can be reconciled with the saved result.
  Check: preserve the artifact/hash and query the actual Langfuse observations through the CLI. Check prompt linkage, span hierarchy, input/output, model, usage and persistence outcome. Record any ingestion limitation explicitly.
  Result: Passed. Preflight reverified the pinned prompt hash. CLI observations retrieval returned the root and three correctly parented children, including exactly one generation linked to `film-analysis` v2. Exact input/output, saved outcome, actual model and 2,653 input / 1,682 output tokens reconcile with the artifact. Langfuse reports USD $0.018762 calculated cost. Model parameters match after decoding Langfuse JSON-string representations. The first read saw partial ingestion; the later read retrieved all four observations. Artifact and observation hashes, trace link and comparison limitations are recorded in the report.
- **AC3:** A concise review identifies what the generated analysis supports and where evidence is missing.
  Check: read the source snapshot, original output and saved draft; record supported/unsupported examples and candidate-quality findings without changing the prompt or draft. Verify local report links and `git diff --check`. Runtime tests need not be repeated for a report-only change; any separately authorized code fix requires its own verification.
  Result: Passed (review completed; editorial weaknesses found). Reviewed the supplied snapshot, original response and saved draft. The draft correctly exposes unknown version, ending and audience evidence, but adds unsupported creature naming, graphicness, reputation, duration and likely ending/response claims. Four candidates have valid references yet insufficiently qualified support; the draft is not publication-ready. Findings and the smallest separately scoped follow-up are documented without modifying the draft or prompt. Local report/spec links and `git diff --check` passed. No runtime test suite was rerun for this report-only change.

## Implementation notes

Completed the single authorized live attempt and evidence report on 27 October 2026, after PR #43 merge. No application code changed. The workflow saved an unpublished draft and remote tracing reconciled; editorial review exposed unsupported claims. No retry, prompt edit, draft revision or publication was performed. This is a single real-workflow verification, not a claim of corpus-wide factual accuracy or predictive recommendation quality. Use the Langfuse skill for the trace audit and the OpenAI docs skill to verify the chosen model's current Responses/schema support and settings before executing.

Owner acceptance / merge: Pending. The owner approved the spec and starting implementation on 27 October 2026; the single paid attempt is authorized with `gpt-4.1-2025-04-14` and a 12,000 output-token cap.

## Preflight evidence — 27 October 2026

- `bin/rails db:migrate:status` found only the merged Film knowledge migration `20261027130000` pending. `bin/rails db:migrate` applied it successfully to `glutton_development`. No new migration or schema contract was introduced. Incidental schema-dump formatting changes were removed.
- Read-only `bin/rails runner` checks used `Film.find_by(tmdb_id: 348)` and `FilmAnalysis.count`, `FilmQuality.count`, `AnalysisQuality.count`: film absent, all counts zero. Both configured integration objects were present; no secrets were printed.
- `bin/rails runner` retrieved `FilmKnowledge::AnalysisPrompt.call(version: 2)` and asserted `prompt.fetch("sha256")` equals the expected hash above; passed. No OpenAI request was made.
- The sandbox could not access local PostgreSQL; these checks and the existing migration succeeded with approved local access.

## Completed live verification — 27 October 2026

[Evidence report](../research/generated_analysis_verification/README.md) records the original artifact `tmp/film_analysis_runs/cb0f165c-8e92-45fc-a366-86414c8a2283.json`, its SHA-256, response ID, settings, persistence assertions, remote observations and editorial findings. The paid request completed once at 17:29 UTC; original output remains local and unchanged. Scope was preserved. Ready for review; owner acceptance and merge remain pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
