# The Thing — screenplay-led retry

Date: 27 October 2026  
Owner: Film knowledge  
Task: [034](../../specs/034_screenplay_led_research_retry.md)  
Status: Ready for review

The owner-authorized retry succeeded and saved unpublished FilmAnalysis 2. The explicit page-open validator was removed without a replacement retrieval-history gate. The model used a Bill Lancaster second-draft screenplay as a narrative source and independent released-film accounts as corroboration. The original response and six quality candidates are saved unchanged. This establishes that the revised workflow runs and persists; it does not establish complete narrative coverage or independent verification of every factual clause.

## Changes and checks

`GeneratedAnalysis` no longer accepts a provider response or checks `opened_urls`. The provider response/tool history is still preserved for diagnostics. Source structure, URL validity, OpenSubtitles exclusion, reference integrity, independent-origin counts, two-source factual admission, candidate validation and existing caption rules remain. `screenplay` is now an explicit source kind. No new source service, corpus import, dependency or schema was added.

The screenplay decision is recorded in the [evidence requirements](../../film_analysis_requirements.md), [architecture brief](../../architecture_brief.md) and [protocol](../../prompts/film_analysis/README.md). The model reads substantive source passages supplied by search or page opening; a separate open action is unnecessary. It must distinguish script versions from the finished film and use independent finished-film corroboration for retained script events/details. Script copies/derivatives count once, and script-only material does not establish final editing, performance or audience experience.

Final verification before spending:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci
RAILS_ENV=test bin/rails zeitwerk:check
git diff --check
```

CI passed 534 tests / 5,665 assertions, zero failures/errors/skips; RuboCop (254 files), dependency/importmap audits and Brakeman (0 warnings) passed. Eager loading passed with the existing mailer-preview exclusion notice. The first CI attempt passed tests/security but found one test-file blank-line offense; it was fixed before the final passing run. Focused coverage ran in the full suite, including saving with no page-open history and representing screenplay/review support while rejecting one-source facts, copied origins and bad references.

## Run evidence

| Field | Recorded value |
| --- | --- |
| Film / environment | The Thing (1982), TMDB 1091, Film 2; development |
| Model | Requested/returned `gpt-5.5-2026-04-23` |
| Settings | 16,000 output tokens; 12 tool calls; 180-second timeout; zero retries; default reasoning effort |
| Prompt | `film-analysis` v6, contract `researched-analysis-v1` |
| Prompt SHA-256 | `1c945160e6c8014b4f263e6c2b4aa178c7aadb1ce129eb601059845daef5f7cb` |
| Start / completion | `2026-10-27T18:25:19.786954Z` / `2026-10-27T18:27:35.692212Z` |
| Provider response | `resp_0883bb58e35be7be016ae0ec91acb887d1bb427d996c39cb3e`, completed |
| Outcome | Saved unpublished analysis 2 |
| Tokens | 85,865 input; 6,262 output including 2,890 reasoning; 92,127 total; zero cached input |
| Tool usage | Four reported web-search requests; eleven recorded actions overall |
| Langfuse model-token cost | USD $0.617185: input $0.429325, output $0.187860 |
| Search estimate | Four searches at published $0.01/request adds $0.04; estimated model-plus-search subtotal $0.657185, not invoice-reconciled |
| Original artifact | `tmp/film_analysis_runs/099fd1b4-e632-4b39-8ff2-3cab5df48f65.json` |
| Artifact SHA-256 | `b58604dfd2626da0432199f665437d0b3e48338d4ad385e7a637625ad3b832ad` |
| Remote observation snapshot | `tmp/film_analysis_runs/task034-observations.json` |
| Observation SHA-256 | `917635dab4a29eb3ab2c903f7c89c1e4f1b75794a6b93ad18624812a92ade978` |

The original UUID artifact remains local and Git-ignored, with owner-only permissions. Local `task034-baseline.json`, `task034-prompt-source.json`, `task034-prompt-published.json` and `task034-verification.json` retain preflight, managed-prompt and state evidence. No source credentials were put into the request/report. Prompt v6 was published/retrieved by exact version and development label with matching text/config/hash; labels are development/latest, with no production promotion.

The exact paid command ran once under this authorization:

```sh
TMDB_ID=1091 OPENAI_MODEL=gpt-5.5-2026-04-23 \
  ANALYSIS_MAX_OUTPUT_TOKENS=16000 ANALYSIS_MAX_TOOL_CALLS=12 \
  ANALYSIS_PROMPT_VERSION=6 bin/rails film_knowledge:generate_analysis
```

The [prior rejected attempt](the_thing.md) and Alien's original artifact/draft were preserved. Baseline global analysis/quality/association counts were 1/0/0; afterward they were 2/0/0. The Thing has exactly one analysis, nil `published_at`, content/candidates exactly equal to the parsed original response, and generation eligibility is now false. Alien remains unpublished with exact original content/candidates and original artifact hash. No shared qualities, associations, publication or regeneration occurred.

## Research and screenplay use

The response cites seven sources: BFI, Universal, the screenplay, Deep Focus Review, AFI, a SYFY oral history and an Arrow essay containing transcribed finished-film dialogue. No cited source is an OpenSubtitles domain and no matched timed subtitle/caption evidence was used. Tool history includes four searches, three screenplay page opens and two screenplay find operations, plus AFI and transcript-page opening. These are diagnostic records, not admission prerequisites.

The [screenplay scan](https://assets.scriptslug.com/live/pdf/scripts/the-thing-1982.pdf) identifies itself as Bill Lancaster's second draft. The response identifies it as March 4, 1981 and explicitly distinguishes it from the final cut. It uses screenplay support in n2 (kennel), n4 (sabotaged blood), n5 (heated-blood test) and m5 (interpretation of the test), each alongside the [Deep Focus released-film essay](https://www.deepfocusreview.com/definitives/the-thing/). It does not treat a second script mirror as independent corroboration.

The model specifically flags a final-scene difference involving screenplay chess-table material. Its ending entry instead uses the finished-film essay and [Arrow's film-dialogue discussion](https://s1.thcdn.com/design-assets/documents/arrowfilms/The%20Thing.pdf); the uncorroborated script ending is not inserted into the narrative. This is a concrete example of the intended handling of script/release differences. A post-run audit read the screenplay cover and relevant released-film discussion; these audit reads were not supplied to generation or used to rewrite the result.

The result has six narrative entries, five experiential/interpretive entries, five explicit gaps and six quality candidates. The candidates cover imitation/paranoia, trapped-group mistrust, suspense/body-horror eruptions, grotesque practical horror, unresolved aftermath and evidence-tracking engagement. All factual entries retain two declared independent origins; interpretations/experiences retain their source counts, including one-source blood-test experience and multi-account intensity evidence. Actual corroboration and origin independence remain model assessments rather than proven by those counts.

The narrative remains selective: it covers setup, kennel, mimicry, blood sabotage/testing and the ending, without a complete account of all intervening events or deaths. The response acknowledges that gap. Some factual entries still combine several details; for example, n5 names Palmer while its second quoted support describes the test mechanics without naming him. That is a support-granularity limitation to evaluate, not a new validator imposed on this run. The revised workflow saves the original document and leaves these findings visible. No claim of complete film understanding or validated recommendation performance is made.

## Remote trace verification

The [remote trace](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/7048dd224e62cd807b81088aecd064d0) has root `5eb17524ae61642b`, generation `00be3a9874d8adde`, prompt retrieval `98e141967175ec0f` and validation `3f6f23de0623eed0`. All three children have the root parent; exactly one generation is present.

The credential-loaded Rails/Open3 CLI read used:

```text
npx --yes langfuse-cli api observations list \
  --trace-id 7048dd224e62cd807b81088aecd064d0 \
  --fields core,basic,io,model,usage,prompt,metadata,trace_context \
  --expand-metadata research_actions --limit 100 --json
```

Parsed comparisons verified exact root input, instructions/input, raw generated output, settings (normalizing Langfuse JSON-string parameters), research-action metadata, prompt v6, actual model/usage and root saved outcome/analysis ID. All thirteen reconciliation assertions passed. Trace export reported `flushed`, and actual remote observations establish ingestion. Cost is the Langfuse model-token calculation plus a separately identified search estimate using [published rates](https://developers.openai.com/api/docs/pricing#built-in-tools); no invoice reconciliation or Batch discount is claimed.

Local Markdown links and whitespace checks passed. No second retry, further prompt tuning, corpus integration, Batch submission, publication or merge occurred. The request used the existing initial-only save path, and the report preserves the difference between successful persistence and complete/correct analysis.

Owner acceptance / merge: Pending.
