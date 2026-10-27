# 001m — Configure OpenAI and Langfuse

Status: Merged via PR #41  
Owner: Foundation / observability

## Goal

Configure explicit Ruby OpenTelemetry spans for export to the configured Langfuse project, with a reproducible diagnostic verifying ingestion. The app has no film-analysis runner yet. Configure the official OpenAI Ruby client and verify a small real Responses API call in a diagnostic; do not implement the analysis pipeline.

## Scope

- Use official Ruby OpenTelemetry SDK/OTLP exporter and current Langfuse OTLP endpoint.
- Configure only when all three Langfuse credentials/endpoint variables exist; disable in tests and when explicitly disabled. No Rails/SQL/HTTP auto-instrumentation or automatic capture of application data.
- Batch exports with bounded timeouts, process shutdown flush, explicit diagnostic command and safe configuration failures.
- Verify with in-memory/local tests and an actual non-sensitive diagnostic trace, then retrieve/audit it using the Langfuse CLI.

## Scope restrictions

- Configure the official OpenAI Ruby SDK with environment credentials, explicit timeouts/retry limits and no request at boot. The diagnostic requires an explicit model and captures actual response/model/usage under a generation span.
- No analysis runner, schema changes, domain mutations, prompt hosting migration or generic integration layer. No automatic application payload capture.
- No secrets, request parameters, original user expressions or private source packets in traces. Only explicitly authored spans are exported. Future model instrumentation needs its own payload review.
- No server startup or deployment; no fabricated generation/tokens/model values for a diagnostic.

## Acceptance criteria

- **AC1:** Tracing configuration is optional and uses the documented authenticated OTLP endpoint with bounded batch export.
  Check: configuration tests cover disabled, missing/partial configuration and endpoint validation; inspect exporter options and shutdown.
  Result: Passed — six focused tests / 52 assertions cover absent/disabled configuration, validated authenticated endpoint, bounded timeout/single OpenAI attempt, response capture/nesting and exception-text exclusion. Dependencies locked: OpenAI 0.113.0, OpenTelemetry SDK 1.13.1 and OTLP exporter 0.37.0.
- **AC2:** An explicit diagnostic produces a nested, named trace with safe inputs/outputs and environment metadata.
  Check: run diagnostic and fetch its observations from Langfuse; audit against current best practices and record the trace link. Check real model and token usage for the bounded diagnostic generation; do not claim a film analysis ran.
  Result: Passed — OPENAI_MODEL=gpt-4.1-mini bin/rails ai:check returned OK from gpt-4.1-mini-2025-04-14. Retrieved trace 7894baf13017103e65913a77ba383684 with the Langfuse CLI observations API: root SPAN plus child GENERATION, correct parent, exact diagnostic input/output, model, 21 input / 2 output tokens, environment and tags; no user data/credentials. See the linked configuration guide for the trace URL.
- **AC3:** Existing application behavior and secret handling remain intact.
  Check: focused tests, eager loading, full bin/ci, git diff --check; inspect changed files and confirm no credential files are tracked.
  Result: Passed — RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci: 469 tests / 5,225 assertions, no failures/errors/skips, style and all security checks clean. RAILS_ENV=test bin/rails zeitwerk:check passed application eager loading (existing mail-preview exclusion). Pilot verifier and git diff --check passed. Credential files remain ignored/untracked. Initial unrestricted parallel CI hit a macOS process crash and was interrupted; single-worker rerun passed. Initial bin/ci setup also applied existing pending development migrations; no new migration was authored. Reverted only generated schema formatting drift.

## Implementation notes

User authorised installation and tracing. Official skill installed from langfuse/skills; existing copy backed up outside the repository. Use Ruby OTEL as recommended for languages without the official Python/JS SDKs. Prompt cleanup stays separately owned in task 027a.

Owner acceptance / merge: Pending.

Implemented configuration, an explicit traced connectivity task and focused tests. The [configuration guide](../ai_configuration.md) records setup, actual live trace and limitations. No automatic Rails instrumentation or analysis pipeline was introduced. The prompt relevance pass belongs to task 027a. No dev server was started.

Merge record: owner authorised merge after CI. [PR #41](https://github.com/adambelton/glutton/pull/41) merged on 27 October 2026 at 12:41:52 UTC, squash commit `1eee2a13d4238b98dca39b5cbc7928626e0d59a6`. Hosted checks passed on exact head `95968c58dd10d0169fd62d59859703c942d30ce4` at 12:41:31 UTC. Earlier review/pending notes describe pre-merge history.
