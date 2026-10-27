# 033 — Verify combined research and analysis for The Thing

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Run and audit one real combined research-and-analysis attempt for John Carpenter's The Thing (1982), following tasks 031/031a and the [generation protocol](../prompts/film_analysis/README.md). The owner selected the film and accepted the recommended model/budget on 27 October 2026. Read the Film knowledge pipeline brief, evidence requirements and current seed plan before execution.

## Scope

- One development attempt for TMDB 1091 using `gpt-5.5-2026-04-23`, max output 16,000 tokens, max built-in tool calls 12, existing 180-second timeout and zero retries. Use synchronous delivery to audit the request; task 032's later Batch compatibility/cost probe remains separate.
- Retrieve and verify `film-analysis` v5 before spending: contract `researched-analysis-v1`, SHA-256 `03459b64f5760afebfcecb8dd8d1429a23ce75d608afc7d400126da343024f2c`. Import through the existing TMDB path, check identity/year and absence of an existing analysis, and preserve Alien and all prior artifacts.
- Retain the original UUID artifact and audit actual search/open actions, cited sources, corroboration, experiential weighting, gaps and original output. Verify no OpenSubtitles sources are admitted. On success compare stored content/candidates exactly with the response, confirm unpublished status and unchanged shared-quality/association counts. On failure retain actual outcome and state rather than silently relaxing checks or retrying.
- Retrieve remote observations using the Langfuse CLI and reconcile prompt, hierarchy, exact request/output, model/usage, research actions and application outcome. Record reported cost when available, with missing data distinguished from zero.
- Produce a bounded evidence report under `docs/research/generated_analysis_verification/`, with reproducible settings, IDs, hashes, trace link, editorial findings and limitations. Update plan/spec evidence.

## Scope restrictions

- Film knowledge verification only; no prompt/code/schema/dependency changes, source integration, corpora downloads, API subscriptions, publication, existing-analysis regeneration, bulk seed or downstream mutations.
- At most one billable generation attempt. No automatic/manual retry under this authorization. Failed or insufficient evidence justifies a separately scoped follow-up, not a second request or weaker admission rule.
- No Batch upload/probe is included. Preserve the combined research/analysis workflow rather than preparing a manual evidence packet.

## Acceptance criteria

- **AC1:** One approved attempt produces an honest recorded application outcome.
  Check: baseline import identity/eligibility and counts, execute once, preserve artifact and verify saved content/candidates/unpublished state or actual failure/unchanged analysis state.
  Result: Failed to save an analysis. One approved request completed at the provider and returned nine narrative entries, six experiential/interpretive entries and five candidates. Application outcome `invalid_sources`: six of ten bibliography URLs lacked explicit completed opens. No The Thing analysis was saved; global counts remain 1/0/0, metadata remains available and Alien/content/candidates/artifact are unchanged. Original response and failure evidence are preserved.
- **AC2:** Actual remote trace reconciles with the original artifact.
  Check: CLI observations verify generation hierarchy, prompt v5, settings/input/output, research actions, actual usage and application outcome. Record actual cost and export/ingestion limitations.
  Result: Passed. CLI retrieved four observations with one generation and correct parents/prompt v5 linkage. Exact input/output, normalized settings, all ten research actions, model, usage and root `invalid_sources` outcome match the artifact. Usage: 72,414 input / 6,541 output (1,790 reasoning). Langfuse model-token cost USD $0.5583; four search requests add an estimated $0.04 at published rates, not invoice-reconciled. Export flushed and remote ingestion was verified.
- **AC3:** Review determines whether the new workflow supplies useful supported analysis.
  Check: review original output and cited extracts/actions for source independence, two-source factual claims, ending/scene coverage and experiential/candidate support; distinguish automatic checks from semantic review. Record failures without altering output.
  Result: Passed (review completed; reliability failures found). Outside articles/reviews provide meaningful scene/experience support, but six source URLs fail the explicit-open contract. Compound narrative claims overstate per-detail corroboration, and one review author is misattributed. No OpenSubtitles/caption evidence was used. The report distinguishes search discovery from explicit opening and does not assert that missing opens prove fabricated sources. No output or prompt was altered.
- **AC4:** Findings and limitations are reviewable.
  Check: report/spec/plan links and `git diff --check`. Do not rerun runtime suites for a report-only verification; use task 031/031a's recorded checks. Mark Ready for review when evidence collection is complete without owner acceptance or merge.
  Result: Passed. Added the [evidence report](../research/generated_analysis_verification/the_thing.md), including IDs, artifact/observation hashes, source/action table, state checks, command, cost limits and smallest follow-up. Local Markdown targets resolved and `git diff --check` passed. No runtime suite was rerun for this report-only task; task 031/031a checks remain separately recorded.

## Implementation notes

Executed exactly once on 27 October 2026. Provider response completed; source admission rejected the result atomically. The original artifact is `tmp/film_analysis_runs/ebb12606-6023-43b4-9e3d-338a8eb9d0bb.json`, SHA-256 `f15bbd24406c80dc4b20ea2fac9cdce6bb6ca733ba8ec6e711207a1237d893c9`. No retry, prompt/code change, publication or bulk work occurred. Official [model documentation](https://developers.openai.com/api/docs/models/gpt-5.5) establishes reasoning, Responses, web search and structured-output support. Actual combined compatibility is part of this run. Model default reasoning effort is medium; no override is supplied. OpenAI/Langfuse skills apply; integrations remain locked to repository versions.

Owner acceptance / merge: Pending. The owner has authorized this single paid attempt, not publication or bulk execution.


Verification commands and comparison steps are recorded in the [report](../research/generated_analysis_verification/the_thing.md). The exact run used `TMDB_ID=1091 OPENAI_MODEL=gpt-5.5-2026-04-23 ANALYSIS_MAX_OUTPUT_TOKENS=16000 ANALYSIS_MAX_TOOL_CALLS=12 ANALYSIS_PROMPT_VERSION=5 bin/rails film_knowledge:generate_analysis`. Read-only Rails/CLI/Python checks reconciled state, remote observations and original response. Post-run independent reads of cited public sources were editorial audit only; they were not supplied to generation and cannot retroactively satisfy its page-open contract. No semantic or publication-readiness success is claimed.

Ready for review. Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
