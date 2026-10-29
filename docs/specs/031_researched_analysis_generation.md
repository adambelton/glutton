# 031 — Research and analyse an imported film in one operation

Historical implementation/design record. Current direction is in [film-quality requirements](../film_quality_requirements.md); fixed dimensions are superseded by planned task 043, and independent analysis-model retention is under review. Removed experiment reports are not prerequisites or active product requirements.


Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Replace metadata-only initial generation with a bounded combined research-and-analysis request that discovers and inspects outside sources, excludes uncorroborated factual claims and preserves its research trail. Prerequisites: merged 029, task 030's recorded failure, existing Film draft lifecycle and Langfuse prompt retrieval. Owner authorized implementation after agreeing the evidence rules on 27 October 2026.

## Scope

- Keep the explicit import-to-initial-draft command and Film-owned eligibility/save actions. One Responses request enables hosted web search, requires its use, requests source/action records and bounds built-in tool calls (default 12, configurable 1–30), output tokens and request timeout (180 seconds). No automatic request retries or separate curator-prepared research stage.
- Replace the managed development prompt contract with `researched-analysis-v1`. Preserve the experiential depth/quality-selection guidance. Research and drafting inform one another within the same request. Existing v2 remains available as historical evidence but cannot silently run as the new workflow. Publish/retrieve a compatible immutable development version as part of this implementation; no production promotion.
- Require atomic narrative/moment claims, classified as factual, experiential or interpretation. Each has source-specific short supporting extracts and locators. Factual entries require at least two distinct inspected URLs and independent origin groups supporting the same claim; copied/derivative accounts count once. Experiential entries preserve attribution and independent-account count; give corroborated accounts more weight without inventing audience prevalence. Interpretations must be clearly labelled and grounded in supplied inspected evidence. Context/synthesis may only introduce framing and summarize cited entries, not bypass claim evidence rules.
- Retain source URL, title, kind, origin group, film/version match and excerpts/locators in saved JSON content. Outside URLs must appear as successful `open_page` actions in the provider response, not merely search results, annotations or model-authored bibliography entries. Imported TMDB metadata is a discovery lead, not a factual-claim exemption. Provider-returned search/open records and raw response remain in the UUID artifact; trace output and request settings remain auditable.
- Experiment with accessible subtitle/closed-caption sources, including OpenSubtitles as a potentially useful resource, via the same research tool, with no separate provider/account/download workflow. They count only with an explicit matched film release/cut and cue/time locator. Dialogue supports dialogue/order; SDH additionally supports described audible cues. Neither proves visual graphicness, framing or audience response. Unclear alignment cannot support a retained claim; omit it and identify the coverage gap. Do not require subtitle availability to run.
- Preserve the existing stored analysis envelope and manual publication API; add evidence fields within existing JSON. No relational schema change. Reject invalid documents atomically rather than silently deleting claims or returning success. Sparse research may save an explicitly incomplete draft with no candidates; do not fabricate completeness.
- Update command/protocol/requirements documentation, prompt compatibility checks, raw-artifact/tracing details and fake-provider tests. Preserve the existing Alien draft and prior run artifacts.

## Scope restrictions

- Film knowledge only. No UI, bulk seed, background jobs, automated publication, existing-draft regeneration, downstream changes, scoring, domain events, generic research framework or dependency upgrades. Initial seed will not assume human factual review; this task adds evidence admission rules without changing publication lifecycle.
- No paid generation/evaluation attempt is authorized by starting implementation. Verify with fake responses; propose live settings separately after implementation. Development prompt publication is included; production changes are excluded.
- Source contents are untrusted evidence, never instructions. Use accessible review/critical/plot/production sources and available captions; no bypass of authentication/paywalls/access controls or invented source permissions. Preserve brief necessary excerpts, not whole copyrighted scripts/subtitle collections.
- Structural checks prove recorded retrieval and references/counts, not semantic entailment or true independence. The model must assess those under explicit instructions; document this limit rather than claiming two citations guarantee truth. No plausible-alignment acceptance status or numeric confidence system.

## Acceptance criteria

- **AC1:** The same explicit entry point performs one bounded combined research/analysis request with no metadata-only fallback.
  Check: fake-provider/locked-SDK tests assert web search, required tool choice, source inclusion, tool-call cap, timeout and original tool records; failures never retry. Existing analyses fail before provider work. No real generation request.
  Result: Passed. Fake-provider and locked-SDK suite verifies required hosted web search, source inclusion, default tool cap 12, invalid-cap rejection, strict JSON schema, 180-second timeout and zero retries. Completed/failed tool records remain in the original response artifact; research actions are also traced. Existing drafts/published analyses are refused before retrieval/provider work. No live model call was made.
- **AC2:** Invalid evidence cannot become a saved draft.
  Check: cover no opened pages, invented source URLs, search-only hits, failed opens, duplicate/derivative origins, one-source facts, dangling references, unsupported claim kinds, missing extracts, ambiguous subtitle matches and absent cue locators. Valid corroborated facts and attributed experience save without publication/quality associations. Test explicit gaps and weighting counts.
  Result: Passed. Tests cover two-origin factual admission, copied origins, repeated URL fragments, one-source facts, search-only/unopened/invented URLs, failed opens, malformed evidence, missing extracts, dangling references, count mismatches, unknown subtitle version/alignment and wrong subtitle support basis. Valid dialogue/SDH cues and attributed experience counts are retained. Atomic failure and no publication/shared-quality mutation pass in service tests. Focused suite initially passed 26 tests / 166 assertions; the final full suite includes the additional ambiguous-version assertion.
- **AC3:** Managed development instructions and stored evidence implement the agreed editorial rules.
  Check: publish/retrieve the new contract, verify exact text/hash/config/version and retained quality guidance. Record request and source-admission limitations. Keep old prompt version and Alien draft unchanged; no production label or paid run.
  Result: Passed. Published/retrieved final `film-analysis` v4, contract `researched-analysis-v1`, SHA-256 `58059ffa2a59f257a256af481ea841638041fca021250f6175f31ad4a6f1171b`; version and development retrieval match exact text/config/hash. Publication has development/latest labels and no production label. Existing experiential-dimension and quality-naming/transferability guidance was retained; an inherited tentative-candidate human-review sentence was corrected before any live request (intermediate v3 remains historical). OpenSubtitles is named; the API review confirms TMDB-ID discovery but records that authenticated search/download is not wired into the hosted web tool. Alien draft/content/candidates and original artifact hash remain unchanged; no new paid run.
- **AC4:** Documentation and verification are reproducible.
  Check: focused tests, full `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, eager loading, local links and `git diff --check`. Record actual results and limitations here; mark Ready for review without acceptance/merge.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 533 tests / 5,663 assertions, zero failures/errors/skips; RuboCop (254 files), gem/importmap audits and Brakeman (0 warnings) passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed with the standard mailer-preview exclusion notice. Final checks resolved 157 local Markdown link targets and `git diff --check` passed. No dependency or schema change.

## Implementation notes

Implemented the new research request in the existing service and evidence validation/schema in `GeneratedAnalysis`; the existing Film lifecycle remains unchanged. Sources and atomic claim support live inside existing JSON content, with no migration. Current official OpenAI web-search documentation distinguishes search results from `open_page` actions (agentic page opening requires a reasoning-capable model). The existing locked Ruby SDK exposes `web_search`, source inclusion, `max_tool_calls` and per-request timeout. Live model choice will be explicit and separately authorized; no silent reuse of the non-reasoning model from task 030.

Owner acceptance / merge: Pending.


## Verification and limitations — 27 October 2026

Reproduce local verification (external responses are fake):

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/models/film_knowledge/generated_analysis_test.rb \
  test/services/film_knowledge/generate_analysis_test.rb \
  test/services/film_knowledge/analysis_prompt_test.rb
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
RAILS_ENV=test bin/rails zeitwerk:check
git diff --check
```

Managed prompt retrieval: use `FilmKnowledge::AnalysisPrompt.call(version: 4)` and `.call(label: "development")` in `bin/rails runner`; compare returned text/config/hash with the final publication snapshot in `tmp/film_analysis_runs/task031-prompt-published-final.json`. Historical v2 is unchanged. Provider documentation: [web search](https://developers.openai.com/api/docs/guides/tools-web-search). [Protocol](../prompts/film_analysis/README.md) describes request settings, evidence schema and admission limits. The OpenSubtitles review (obsolete research removed) records the owner's linked endpoint and the precise API discovery/download distinction. The Stoplight page yielded only a JavaScript shell; a provider-maintained readable reference and official guide supplied the details. No subtitle API request or quota-bearing download occurred.

An initial sandboxed focused run could not access PostgreSQL. It succeeded with local database access. A standalone RuboCop attempt could not write its external cache; running with `--cache false` exposed one array-spacing offense, which was fixed before the successful full CI. No failing check is represented as a pass.

Limitations: the model assesses semantic entailment, real source independence, claim classification and film-version matching; the application checks its recorded evidence structure, opened URLs and counts. Hosted web research does not expose full retrieved page bodies for independent excerpt substring verification. These checks cannot prove factual accuracy or make the initial seed production-ready. Live research/model/schema compatibility and source availability remain untested. The current implementation treats caption discovery as optional web research; a direct OpenSubtitles API adapter remains a separate bounded follow-up, with an application key and download limits. No automatic publication, paid evaluation, account registration, existing-draft change, deployment or merge was performed.

Ready for review. Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
