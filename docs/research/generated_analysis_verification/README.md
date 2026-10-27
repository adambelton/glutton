# Alien initial analysis verification

Date: 27 October 2026  
Owner: Film knowledge  
Task: [030](../../specs/030_live_analysis_verification.md)  
Status: Ready for review

The single authorized import-to-draft attempt succeeded. The saved unpublished draft exactly matches the original generated document, and remote Langfuse observations reconcile with the local artifact. Editorial review found unsupported specificity and overconfident experiential claims. This verifies the workflow; it does not establish publication readiness, factual accuracy across a catalogue, or recommendation usefulness.

## Run and preserved evidence

| Setting / result | Recorded value |
| --- | --- |
| Film | Alien (1979), TMDB 348; local Film 1 |
| Environment | Local development |
| Requested and returned model | `gpt-4.1-2025-04-14` |
| Output cap | 12,000 tokens |
| Prompt | `film-analysis`, version 2, contract `tmdb-analysis-v1` |
| Prompt SHA-256 | `9e937b0eaab4ae7885789c9d66bec3a4aed21172c92248afd5e76c78410bb79f` |
| Started / completed | `2026-10-27T17:29:30.096350Z` / `2026-10-27T17:29:42.375655Z` |
| Provider response | `resp_0de22f5b9386cdbd016ae0df7b588c87d2894e697a32892773`, `completed` |
| Application outcome | `saved`, FilmAnalysis 1, unpublished |
| Usage | 2,653 input; 1,682 output; 4,335 total tokens; zero cached input and reasoning tokens |
| Cost | Langfuse-calculated USD $0.018762: input $0.005306, output $0.013456; not an invoice reconciliation |
| Trace export | `flushed`; actual remote ingestion independently verified |
| Original artifact | `tmp/film_analysis_runs/cb0f165c-8e92-45fc-a366-86414c8a2283.json` |
| Artifact SHA-256 | `aa1ce2e48d0fcd89e966571be481e345eae71739d4cd4f573aa034e576fec2f6` |
| Remote observation snapshot | `tmp/film_analysis_runs/alien-observations.json` |
| Observation snapshot SHA-256 | `22206c9f34e2de92dd75777f680b3746929b4dd5c73422e84aa0f4a7b8793fd3` |

Both evidence files remain local under the repository's ignored `tmp` directory. The UUID artifact retains the exact supplied source, prompt, request and unedited provider response. It has owner-only file permissions. No credentials are included in this report. No generated content or prompt was revised, and no additional model attempt was made.

The owner explicitly approved this film, model and cap before execution. Preflight discovered that the already merged `20261027130000` Film analysis migration had not been applied to development. Applying it succeeded; no migration or schema change was authored. Before import, TMDB 348 was absent and FilmAnalysis, FilmQuality and AnalysisQuality counts were all zero. Prompt retrieval immediately before execution matched the pinned hash.

## Persistence and trace verification

After the run, Film 1 has exactly one analysis. Global counts are FilmAnalysis 1, FilmQuality 0 and AnalysisQuality 0. `published_at` is nil, and both saved `content` and `quality_candidates` equal the document parsed from the original response. `film.can_generate_analysis?` is false after saving. This checks model eligibility without another provider invocation; the command was not retried to test rejection.

The draft contains four narrative entries, three moments, six gaps and four new quality proposals. The original vocabulary was empty. These counts describe the output and are not completeness criteria. All source IDs remain `TMDB`, sources match the supplied array, and all candidate evidence references resolve to narrative/moment IDs. Application validation passed; that validation establishes structure and reference integrity, not whether the linked prose is supported.

The [remote trace](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/c3c2da38f5ad9281e89b8bf54355e54a) was retrieved via the Langfuse CLI's modern observations endpoint. The first read returned only the prompt-retrieval span during ingestion; a later read returned all four observations:

| Observation | ID | Parent |
| --- | --- | --- |
| `generate-film-analysis` | `781220296ebeec77` | none |
| `retrieve-film-analysis-prompt` | `09ed879b0f233770` | root |
| `generate-film-analysis-response` (GENERATION) | `60ca93f99f68d89b` | root |
| `validate-film-analysis` | `a2c7f0a71e095b96` | root |

Exactly one generation was present. Its prompt linkage is `film-analysis` v2, prompt ID `fefbe71c-9d52-4e8e-a0c6-f57c0277aab8`. All observations share the expected trace ID and development context. Root input equals the artifact input; generation input equals the exact instructions and serialized input sent to Responses; generation output equals the original response text after decoding Langfuse's JSON string. Root output reports `saved` and analysis ID 1. Actual model and token usage match the provider response.

Langfuse normalizes model parameters: `max_output_tokens` remains numeric, while `store` and nested `text` are JSON strings. A raw parameter-object comparison initially failed on these representations; decoding those two fields reconciled them exactly with the artifact. No trace or artifact was edited to make the comparison pass. Retrieval and validation spans have no separate input/output; the root and generation contain the request/result evidence needed for reconciliation.

## Editorial review against the supplied snapshot

The only inspected source was the imported TMDB movie-details snapshot fetched at `2026-10-27T17:29:30Z`. It supplies identity, runtime, genres, tagline, production/release context and a short overview: a commercial spaceship intercepts a distress signal, three crew members find an egg chamber, a creature attacks an explorer and a parasite is subsequently born. It supplies no detailed later plot, ending, audience testimony or presentation evidence. This review used that snapshot and the original generated document, without acquiring additional sources.

The draft correctly identifies its sole source and unknown cut/version. It acknowledges missing character arcs, scene detail, ending/survivors and audience evidence. N1–N2 broadly preserve the overview's setup and attack, and the egg-chamber discovery is supported. These are useful preliminary narrative anchors, with single-source provenance rather than independent corroboration. Leaving the ending uncovered is an honest coverage gap; it would be inappropriate to fill it from memory.

However, limitations elsewhere do not qualify every unsupported claim:

- N1 adds that the crew are involuntarily drawn into danger. The overview does not establish their decision constraints. N3 supplies the return-to-ship connection that the snapshot does not explicitly describe.
- M2 names the creature a facehugger. The supplied overview does not use that name. Marking it implied does not make the identifier source-supported.
- M3 describes the birth as visceral and shocking, invokes the film's reputation, and asserts explicit presentation. The overview establishes a parasite's birth, without describing its visual treatment, reputation or viewer impact.
- The synthesis asserts sustained dread, fatalism, distrust, a relentless bleak tone and viewers' anticipation/theorizing. These exceed the available evidence or need explicit tentative framing. The tagline supports an interpretation of isolation, not a demonstrated account of the whole film's emotional rhythm.
- The synthesis speculates that ambiguity and trauma are more probable outcomes and suggests little relief despite conceding that the ending is unknown. Unknown resolution does not support that prediction.

No named viewer testimony or fabricated external source was added. Nevertheless, references to reputation and likely viewer effects violate the intended separation between source facts, supported interpretation and missing response evidence. The gaps are valuable but do not cure this overreach. The result does not meet the evidence standard for publication.

## Quality-candidate findings

| Proposal | Assessment from supplied evidence |
| --- | --- |
| Sustained dread from ordinary people confronting an incomprehensible threat | Encountering an alien threat is supported; sustained duration, ordinary-person characterization and the claimed experience need stronger support or tentative framing. |
| Graphic bodily horror in the alien's life cycle | Parasitism supports a possible bodily-invasion interpretation; graphic presentation is unestablished. This candidate's defining intensity claim is unsupported. |
| Relentless bleak tone in an isolated, uncaring environment | Isolation is a plausible tagline-based interpretation; relentless duration and whole-film bleakness are not established. |
| Escalating tension from initial curiosity to catastrophic threat | The overview supports a change from exploration to danger; curiosity, pacing and catastrophic escalation go beyond its demonstrated detail. |

The proposals use different dimensions and resolve their references without invented vocabulary IDs. Dread, bleakness and escalating tension still overlap substantially around the same sparse events. Their distinctions and transferability are plausible editorial ideas, not validated preference signals. Candidate-specific uncertainty, scope and reasons for preference relevance are insufficiently explicit. All four remain unpublished proposals; no shared qualities or associations were created.

The smallest useful follow-up is a separately scoped prompt correction that requires each claim/candidate to preserve its support level and forbids inferred explicitness, duration, reputation and ending outcomes from sparse metadata. Keep incomplete or empty candidates valid. This report does not authorize prompt changes or a second paid run. A larger model or token cap would not supply the missing source evidence.

## Reproduction and checks actually run

The following generation command ran exactly once. It is historical evidence, not an instruction to run another paid attempt:

```sh
TMDB_ID=348 OPENAI_MODEL=gpt-4.1-2025-04-14 \
  ANALYSIS_MAX_OUTPUT_TOKENS=12000 ANALYSIS_PROMPT_VERSION=2 \
  bin/rails film_knowledge:generate_analysis
```

Before execution, a Rails runner retrieved `FilmKnowledge::AnalysisPrompt.call(version: 2)` and asserted its SHA-256 against the value above. Read-only Rails runner checks before and after execution used the existing Film/analysis models and counts. The post-run checks asserted all seven outcomes: exactly one analysis globally, nil publication time, exact content equality, exact candidate equality, generation ineligibility, zero shared qualities and zero associations. All passed.

Reproduce the remote read with environment loaded by Rails, without printing credentials:

```sh
bin/rails runner '
  require "open3"
  artifact = JSON.parse(File.read("tmp/film_analysis_runs/cb0f165c-8e92-45fc-a366-86414c8a2283.json"))
  output, _errors, status = Open3.capture3(
    { "LANGFUSE_HOST" => ENV.fetch("LANGFUSE_BASE_URL") },
    "npx", "--yes", "langfuse-cli", "api", "observations", "list",
    "--trace-id", artifact.fetch("trace_id"),
    "--fields", "core,basic,io,model,usage,prompt,metadata,trace_context",
    "--limit", "100", "--json")
  abort "Observation retrieval failed" unless status.success?
  puts output
'
```

The actual audit preserved that output locally and compared parsed root/generation input, original output, hierarchy, prompt linkage, model and usage against the artifact. All matched; model parameters matched after the documented JSON normalization. SHA-256 values were computed with Python `hashlib.sha256`. The source snapshot, complete original output and saved draft were inspected for the editorial findings above.

Local Markdown file links in this report/spec were checked, and `git diff --check` passed. Runtime tests were not rerun: task 030 changes documentation and exercises the existing live workflow without changing application code. Local PostgreSQL and provider access required sandbox escalation; those executions succeeded. No deployment, publication, prompt edit, PR creation or merge was performed.

Documentation basis: [OpenAI model support](https://developers.openai.com/api/docs/models/gpt-4.1), [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Langfuse observations/Public API](https://langfuse.com/docs/api-and-data-platform/features/public-api). Model support was verified before the run; the Langfuse CLI and its current endpoint help supplied the read contract. See the [analysis requirements](../../film_analysis_requirements.md) for the editorial standard.

Owner acceptance / merge: Pending.
