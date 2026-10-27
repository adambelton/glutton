# The Thing — v7 coverage comparison

Date: 27 October 2026  
Owner: Film knowledge  
Task: [036](../../specs/036_coverage_prompt_same_film_test.md)  
Status: Ready for review

The single authorized prompt-v7 evaluation completed and passed the existing generated-document validator. It produced a more continuous causal narrative than v6, with concrete improvement in the previously missing middle of the story. It did not replace the saved The Thing analysis: this was an evaluation-only request using exactly the previous request's input/schema/settings and changing only instructions. Existing analyses and prior artifacts remain unchanged.

This is one observational comparison. The output is better evidence of useful coverage than entry/source counts alone, but one nondeterministic run does not prove that the new instruction caused the improvement or that all factual details are independently corroborated.

## Comparison findings

| Aspect | v6 saved draft | v7 evaluation |
| --- | --- | --- |
| Narrative flow | Setup, kennel, mimicry, blood sabotage/test and ending; major middle-story gaps | Connects the Norwegian pursuit/investigation, recovered remains, spacecraft, global-risk discovery, Bennings, Blair's sabotage/confinement, leadership distrust, MacReady's return, Norris/Palmer revelations, Blair's craft and station destruction to the ending |
| Research emphasis | Screenplay passages, broad plot/critical/production sources | Screenplay plus detailed released-film accounts (Filmsite and Wikipedia), with targeted blood-test and critical sources |
| Narrative / experience-interpretation entries | 6 / 5 | 9 / 5 |
| Cited sources / proposed qualities | 7 / 6 | 9 / 5 |
| Output tokens including reasoning | 6,262 (2,890 reasoning) | 7,302 (2,983 reasoning) |
| Visible-output token difference | 3,372 | 4,319 |
| Provider input tokens | 85,865; zero cached | 93,193; 4,608 cached |
| Completed tool actions | 11 | 12; one additional unfinished open item returned |
| Reported search requests | 4 | 4 |
| Elapsed run | About 136 seconds | About 145 seconds |
| Application outcome | Saved unpublished analysis 2 | `validated_evaluation`, not persisted |

The important improvement is causal continuity. v7 explains why the team investigates the Norwegian camp, how imitation becomes a global containment problem, how containment and sabotaged blood undermine authority, and why destroying the station follows from Blair's escape and the loss of power. v6 often jumped between selected scenes without those connections.

The model researched the second-draft screenplay again and retained the script/released-film distinction. The output explicitly omits unconfirmed screenplay differences and does not resolve the ending's survivor identities from speculation. Qualities follow the fuller narrative and attributed accounts; the five proposals concern imitation/paranoia, procedural suspense, practical body horror, investigative engagement and unresolved containment. Their predictive usefulness has not been tested.

Remaining weaknesses are visible rather than hidden by validation:

- Entries remain paragraphs containing multiple factual details, despite the atomic-claim instruction. In n5, the quoted support for killing the remaining dogs appears in the Wikipedia passage; the other quoted passages cover sabotage generally. Three source IDs do not establish two-source support for every clause.
- n7 bundles torn clothes, MacReady's return, Norris and the blood test into one entry. That improves continuity but makes precise corroboration harder to assess.
- n9 loosely attributes the last companions' deaths/disappearances to the Blair-Thing, while its own support distinguishes Garry's killing from Nauls's disappearance. The latter should not silently become a confirmed killing or removal by a specific creature.
- Most narrative facts rely on the same two detailed accounts. They are declared separate origins, but this evaluation did not prove that every overlapping detail is independently sourced.
- Fuchs and some connective/death details remain compressed or omitted. The output acknowledges those limits. It is more coherent, not a complete account of every meaningful sequence.

No additional validator or paid request was added to address these findings. The evaluation result is preserved as generated. Improved coverage does not establish factual perfection or justify automatic catalogue-wide publication.

## Request, provenance and state

| Field | Recorded value |
| --- | --- |
| Film / input | The Thing (1982), TMDB 1091, exact task 034 imported input snapshot |
| Model | Requested/returned `gpt-5.5-2026-04-23` |
| Bounds | 16,000 output tokens; 12 tool calls; 180-second timeout; zero retries; model default reasoning |
| Prompt | `film-analysis` v7, contract `researched-analysis-v1` |
| Prompt SHA-256 | `79a51106e540703d003b4f482c2289738e35ec7675701b285ee4f9376bb0fd19` |
| Request start / completion | `2026-10-27T18:42:11.263085Z` / `2026-10-27T18:44:36.473191Z` |
| Provider response | `resp_01903f1cb5d68930016ae0f0841c6887d1a1a9cc3d5fb7bbb1`, completed |
| Outcome | `validated_evaluation`, persisted false |
| Usage | 93,193 input; 7,302 output including 2,983 reasoning; 100,495 total |
| Artifact | `tmp/film_analysis_runs/6325be66-097b-4561-a55f-0d657e664be6.json` |
| Artifact SHA-256 | `226f0ff5f979b0037f96ff3c0f48553a8e5b63ea0461d9a06ab6e2ee61f9cbcf` |
| Observation snapshot | `tmp/film_analysis_runs/task036-observations.json` |
| Observation SHA-256 | `61f2020eba0ace1c3cc8659ccd597cd56ddc00a961967f19fa062ff371af8571` |
| One-off runner snapshot | `tmp/film_analysis_runs/task036-evaluation-runner.rb` |
| Runner SHA-256 | `2ea2c8257b6d829637a7f28d10ff7108beacf45ab09f24c9b65f4a08063eae37` |

The managed v7 prompt was fetched and its exact expected hash verified before spending. The one-off runner copied the complete prior request and replaced only `instructions`; an equality assertion verified every other request field unchanged. It used the configured OpenAI client and existing validator, without calling Film generation/save or modifying eligibility. No database transaction was held during provider work.

The runner and original UUID artifact are retained in ignored local diagnostic storage; they are not production APIs or runtime prompt fallbacks. The artifact has owner-only permissions. No manual evidence packet or new source corpus was supplied. The model was responsible for choosing research within the unchanged allowance. OpenSubtitles remains excluded; no cited source is an OpenSubtitles domain and no matched caption source was used.

Post-run read-only verification compared all saved analyses' film/content/candidates/publication/supersession hashes against preflight, along with global counts and the comparison artifact hash. All matched. Counts remain FilmAnalysis 2, FilmQuality 0, AnalysisQuality 0. The saved Thing draft is still analysis 2 from v6; this new output exists only in the evaluation artifact.

## Tool history, trace and cost

The response records four searches, two find operations and seven open items. Twelve action items completed; the thirteenth is an unfinished `open_page` in `searching` state with no URL. The request's `max_tool_calls` remained 12. This is recorded as returned, not interpreted as thirteen completed or billable searches. The overall response status is completed and local document validation passed.

The [actual remote trace](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/d746a1f677f2af94181d42cf2662fddf) contains:

| Observation | ID | Parent |
| --- | --- | --- |
| `evaluate-film-analysis` | `ce58a11000a46443` | None |
| `evaluate-film-analysis-response` | `85dac5d2c1407816` | Root |
| `validate-film-analysis-evaluation` | `9cc1652cade2411d` | Root |

Exactly one generation was recorded. Thirteen reconciliation assertions passed for hierarchy, prompt v7 linkage, exact input/instructions/output, normalized parameters, raw research actions, model/usage and root outcome `validated_evaluation` with persisted false. Export reported `flushed`; actual CLI observations verify remote ingestion.

Langfuse reports model-token cost USD $0.685025 (input $0.465965; output $0.219060). Four reported search requests add an estimated $0.04 at the [published tool rate](https://developers.openai.com/api/docs/pricing#built-in-tools), giving a provisional $0.725025 subtotal, about $0.73. Billing has not been reconciled. The response reports 4,608 cached input tokens, while the existing trace records aggregate input usage without a cached breakdown; Langfuse's input calculation therefore may overstate actual billed input cost. No unsupported cached-token price or exact invoice total is asserted.

Compared with v6's provisional $0.657185 subtotal, this run used more input/output for a fuller narrative. Neither figure is a measured cost per complete, factually verified seed. Batch suitability remains a separate planned check before scale.

## Reproduction and verification

The one-off paid command ran exactly once under this authorization:

```sh
bin/rails runner /tmp/glutton_task036_evaluate.rb
```

The exact runner is preserved at the local diagnostic path above. Its core request construction was:

```ruby
previous = JSON.parse(File.read(previous_artifact_path))
prompt = FilmKnowledge::AnalysisPrompt.call(version: 7)
request = previous.fetch("request").deep_symbolize_keys.merge(instructions: prompt.fetch("prompt"))
response = Rails.application.config.x.openai_client.responses.create(
  **request, request_options: { timeout: 180.0, max_retries: 0 })
```

This is historical reproduction evidence, not authorization to spend again. The preserved runner also records the UUID artifact, baseline, trace and validation outcome, with no persistence call.

The credential-loaded Rails/Open3 remote read used:

```text
npx --yes langfuse-cli api observations list \
  --trace-id d746a1f677f2af94181d42cf2662fddf \
  --fields core,basic,io,model,usage,prompt,metadata,trace_context \
  --expand-metadata research_actions --limit 100 --json
```

`task036-verification.json` retains the state/request/artifact checks. Python JSON comparisons verified remote reconciliation and SHA-256 values. Local Markdown links and `git diff --check` passed. No runtime suite was rerun for this evaluation/documentation-only task; no application code or prompt was changed during the test. No repeat, saved revision, publication, corpus integration, Batch upload or merge occurred.

Owner acceptance / merge: Pending.
