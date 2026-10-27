# The Thing — combined research verification

Date: 27 October 2026  
Owner: Film knowledge  
Task: [033](../../specs/033_the_thing_research_verification.md)  
Status: Ready for review

The single approved request completed at the provider, but the application rejected the result as `invalid_sources`. No The Thing analysis was saved or published. The model produced substantially richer, externally sourced material than the metadata-only Alien attempt; six bibliography URLs lacked the explicit page-open records required by the current contract. Semantic review also found compound claims whose individual details were not corroborated by all their cited extracts, and an incorrect source-author attribution. No retry, prompt edit or validation relaxation was performed.

## Original run evidence

| Field | Value |
| --- | --- |
| Film | John Carpenter's The Thing (1982), TMDB 1091, local Film 2 |
| Environment / delivery | Development; synchronous Responses API |
| Requested and returned model | `gpt-5.5-2026-04-23` |
| Settings | 16,000 output-token cap; 12 built-in tool calls; 180-second timeout; zero retries; model default reasoning effort |
| Prompt | `film-analysis` v5; `researched-analysis-v1` |
| Prompt SHA-256 | `03459b64f5760afebfcecb8dd8d1429a23ce75d608afc7d400126da343024f2c` |
| Started / completed | `2026-10-27T18:12:56.762945Z` / `2026-10-27T18:14:59.769667Z` |
| Response | `resp_01519760100b735f016ae0e9a9fe4087d28806fbb816faa550`, status `completed` |
| Application outcome | `invalid_sources`; `FilmKnowledge::GenerationFailed` |
| Analysis ID | None |
| Token usage | 72,414 input; 6,541 output, including 1,790 reasoning; 78,955 total; zero cached input |
| Provider tool usage | Four web-search requests; ten recorded tool actions overall |
| Langfuse model-token cost | USD $0.558300: input $0.362070, output $0.196230 |
| Search cost estimate | Four reported search requests at the published $0.01/request rate adds $0.04; estimated model-plus-search subtotal $0.598300, not an invoice reconciliation |
| Trace export | `flushed`; actual remote ingestion verified separately |
| Original artifact | `tmp/film_analysis_runs/ebb12606-6023-43b4-9e3d-338a8eb9d0bb.json` |
| Artifact SHA-256 | `f15bbd24406c80dc4b20ea2fac9cdce6bb6ca733ba8ec6e711207a1237d893c9` |
| Remote observation snapshot | `tmp/film_analysis_runs/the-thing-observations.json` |
| Observation SHA-256 | `58719153e56e10a12dbfb33477b762f459969cc49b4025ef3f4762986c2e4892` |

The UUID artifact contains the original imported input, instructions/schema/settings, provider response and tool actions. It remains local, ignored by Git and owner-readable. Additional local files `the-thing-baseline.json` and `the-thing-verification.json` preserve the state checks. The output was not edited or manually applied. Provider-returned search sources are discovery evidence, not newly collected independent sources.

[Official model support](https://developers.openai.com/api/docs/models/gpt-5.5) was checked before execution. The search estimate uses [published tool pricing](https://developers.openai.com/api/docs/pricing#built-in-tools); Langfuse's recorded total covers the model-token calculation shown above and does not itself establish all search charges. A rejected analysis still consumed provider work. This single failed attempt is not a measured cost per valid seed or a catalogue cost estimate.

## State verification

Preflight retrieved v5 and verified the exact hash, imported TMDB 1091 through the existing operation, confirmed title/year, and checked no prior analysis existed. Baseline global counts were FilmAnalysis 1, FilmQuality 0 and AnalysisQuality 0.

After execution the global counts remained 1/0/0. Film 2 has zero analyses and remains generation-eligible; metadata is retained. Alien's analysis content and candidates still equal its original artifact, its publication time remains nil, and the original Alien artifact SHA-256 is unchanged. No publication, shared-quality creation or association creation occurred.

## Remote trace reconciliation

The [actual Langfuse trace](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/67b5d602d99bccbdc058b37d71e1a027) contains four observations:

| Observation | ID | Parent |
| --- | --- | --- |
| `generate-film-analysis` | `a71086d3eca9cea2` | None |
| `retrieve-film-analysis-prompt` | `5751f75d6d7eedfc` | Root |
| `generate-film-analysis-response` | `b64db776f1c7e9f0` | Root |
| `validate-film-analysis` | `28c4641b541c1ff1` | Root |

Exactly one observation is a generation. CLI retrieval verified prompt v5 linkage, trace/parent IDs, exact instructions/input, original output, actual model/usage and root outcome `invalid_sources`. Remote model parameters match the artifact after decoding Langfuse's JSON-string representations. Expanded `research_actions` metadata equals all original provider tool-action objects exactly. The generation completed; application validation failed afterward. This is distinct from refusal, truncation, timeout or export failure.

## Research actually recorded

The response records four searches and six page opens. The AFI URL appears in three opens, so there are four unique explicitly opened URLs. The final bibliography contains ten URLs:

| ID | Source | Explicit completed open recorded? |
| --- | --- | --- |
| s1 | [John Carpenter's official film page](https://theofficialjohncarpenter.com/the-thing/) | Yes |
| s2 | [Universal home-entertainment listing](https://www.universalpicturesathome.com/movies/the-thing-1982) | Yes |
| s3 | [AFI catalogue](https://catalog.afi.com/Catalog/moviedetails/67235) | Yes, three actions |
| s4 | [Rotten Tomatoes](https://www.rottentomatoes.com/m/1021244-thing?search=the+thing) | No |
| s5 | [Reactor retrospective](https://reactormag.com/forty-years-later-what-makes-john-carpenters-the-thing-so-effing-scary/) | Yes |
| s6 | [Classic-Horror review](https://classic-horror.com/reviews/thing_1982.html) | No |
| s7 | [Blueprint Blu-ray review](https://blueprintreview.co.uk/2017/10/the-thing/) | No |
| s8 | [Black Gate retrospective](https://www.blackgate.com/2017/08/26/john-carpenter-the-thing-1982/) | No |
| s10 | [Deep Focus Review essay](https://www.deepfocusreview.com/definitives/the-thing/) | No |
| s11 | [Caution Spoilers review](https://www.cautionspoilers.com/film-reviews/the-thing-1982/) | No |

All six URLs without explicit opens were present in recorded search-source lists. Their absence from explicit open actions is not proof that the URLs or quotations were fabricated, or that the hosted search supplied no substantive page content. It does mean that they fail the agreed application's retrieval contract. The stored provider response does not expose the underlying full search/page bodies, so we cannot reconstruct exactly which passages the model saw. It would be incorrect to silently treat discovery URLs as equivalent to explicit inspection merely to save this output.

No admitted bibliography source is an OpenSubtitles domain; no subtitle/caption evidence was used. This run did not download a corpus, screenplay or caption file. The final bibliography's ten distinct sources plus four search actions would need more than a twelve-action allowance if each source required its own open; a bounded workflow must choose fewer fully inspected sources or explicitly change its research allowance. The actual response records ten actions, so the artifact alone does not prove that the model stopped because it reached the configured cap.

## Editorial findings

The original document contains nine factual narrative entries, six experiential/interpretive entries, five gaps and five quality candidates. Reference IDs resolve, and each factual entry declares two or three independent origins. These checks cannot establish whether every clause is corroborated or origins are truly independent.

There is meaningful improvement over the Alien run. Outside accounts discuss the blood-test sequence, isolation, creature transformations, paranoia, pacing and unresolved ending. A post-run audit opened the cited public pages independently, without feeding new material into generation. For example, the [Deep Focus essay](https://www.deepfocusreview.com/definitives/the-thing/) explicitly discusses physical transformations and graphic presentation, while [Caution Spoilers](https://www.cautionspoilers.com/film-reviews/the-thing-1982/) describes disgusting transformations and body detail. Graphic body-horror interpretation here has actual source support, unlike deriving visual explicitness from a bare TMDB birth synopsis. These later audit reads do not retroactively add provider page-open records or satisfy the failed admission check.

However, source counts still overstate support when an entry bundles several details:

- **n1:** combines team size/location with prolonged darkness. The supplied supporting extracts corroborate the setup, but only the official Carpenter extract establishes the darkness detail. Three citations do not establish two-source support for every clause.
- **n7:** combines destroyed blood supplies with the specific suspicion of Garry/Copper and their access to locked storage. Other extracts support test sabotage generally; the specific suspects/access detail appears only in the AFI extract supplied for that claim.
- **n8:** combines the heat test, Palmer's reaction/transformation, Windows's death, burning bodies and clearing other men. The supplied passages are complementary; not every detail has two independent specific supports.
- **n9:** bundles Blair's disappearance, tunnel/project discovery, destruction of the camp and the final meeting/uncertainty. The excerpts do not each corroborate the whole bundled account. The model needs to preserve the two-source rule at an atomic-claim level, not just count references on a paragraph.
- **Source attribution:** s5 records the Reactor author/origin as Keith Phipps. The inspected page identifies Robert Repino. That provenance error is separate from whether the cited article text supports the analysis.

The experiential entries generally preserve attribution to writers and report independent-support counts; multi-account support informs the five proposed qualities. Nonetheless, m3/m5 also mix reported responses with descriptive event/presentation claims. Classification should not let a factual clause bypass corroboration. Candidate names are potentially useful distinctions, but preference relevance/transferability rationale is brief and no predictive usefulness is validated.

The output honestly records no matched captions, uncertain cut/runtime information, incomplete death/disappearance coverage and inaccessible sources. The [AFI page](https://catalog.afi.com/Catalog/moviedetails/67235) does display conflicting runtime values; recording that uncertainty rather than inventing a resolution was appropriate. The analysis is still incomplete and, with the retrieval and claim-granularity failures, is not suitable for automatic seed publication.

## Reproducible commands and next work

Historical command executed exactly once (do not rerun without authorization):

```sh
TMDB_ID=1091 OPENAI_MODEL=gpt-5.5-2026-04-23 \
  ANALYSIS_MAX_OUTPUT_TOKENS=16000 ANALYSIS_MAX_TOOL_CALLS=12 \
  ANALYSIS_PROMPT_VERSION=5 bin/rails film_knowledge:generate_analysis
```

Read-only state checks used `Film.find_by!(tmdb_id: 1091).film_analyses.count`, `can_generate_analysis?`, global analysis/quality/association counts, and exact Alien content/candidate/hash comparison against its retained artifact.

Remote read used the existing credential-loaded Rails runner with `Open3.capture3`, `LANGFUSE_HOST` set from `LANGFUSE_BASE_URL`, and:

```text
npx --yes langfuse-cli api observations list \
  --trace-id 67b5d602d99bccbdc058b37d71e1a027 \
  --fields core,basic,io,model,usage,prompt,metadata,trace_context \
  --expand-metadata research_actions --limit 100 --json
```

The CLI response was preserved locally. A Python JSON comparison verified hierarchy, input/output, settings, prompt, usage, root outcome and research actions; hashes used `hashlib.sha256`. Local Markdown links and `git diff --check` passed. Runtime suites were not rerun for this report-only task; task 031/031a's test evidence remains separate from live compatibility and editorial findings.

The smallest follow-up is to enforce the relation between inspected source records and the final bibliography within the combined workflow, and make factual entries genuinely atomic with support for every retained detail. Audit author/origin extraction rather than accepting a correct URL as proof of correct provenance. The current admission rule caught the retrieval mismatch but cannot independently verify semantic support. More tokens or a larger bibliography alone will not fix that. Any code/prompt fix, revised research budget or paid repeat needs explicit scope; none occurred during task 033. Batch cost evaluation remains planned before expansion, after producing reliable valid results on a small sample.

Owner acceptance / merge: Pending.
