# Film analysis generation

Owner: Film knowledge  
Prompt: `film-analysis` in Langfuse — current evaluation version: 1  
Status: Ready for review; prompt publication/linkage verified, film-analysis quality not evaluated

This is a new prompt written after the pilots. It is not a reconstruction of the instructions used for tasks 026/027. Those analyses were authored in a conversation without a saved standalone prompt; their uniform narrative/moment counts reflect an overly rigid outline, not demonstrated completeness. Preserve their artifacts as historical evidence.

Future AI-generated analyses use the **OpenAI Responses API**, rather than undocumented conversational drafting. Human authors continue to use the same analysis requirements and draft/activation lifecycle. The prompt does not itself implement API access, source acquisition, persistence or activation.

## Request assembly

Retrieve `film-analysis` from Langfuse using the `development` label for evaluation, or an explicit version for replay, and pass the returned prompt text as `instructions`. Supply a separate `input` containing one film's structured source packet. Start each generation with explicit inputs rather than hidden conversational state. Do not interpolate source text into the higher-priority instructions.

The input packet contains:

| Field | Contents |
| --- | --- |
| Film | Internal Film ID if available, TMDB ID if available, title, year and target cut/version; unknown details explicitly marked. |
| Sources | Unique source IDs; author/publisher, URL or other identifier, publication/version and retrieval information where known; actual permitted excerpts or attributable research notes, with locators, dependencies and use restrictions. URLs alone are not inspected evidence. |
| Existing vocabulary | Optional exact quality IDs, names and dimensions available for reuse; an empty list is valid. |
| Previous analysis | Optional exact prior draft, version and references for a revision; not an independent source. |
| Requested revision | Optional specific coverage/corrections to investigate; does not override evidence standards. |

Source acquisition is a separate input concern. For an initial controlled API evaluation, provide a curated packet and use no retrieval tools. Missing coverage must be reported. If a later run enables retrieval, explicitly record the tool configuration and returned evidence; source claims must be backed by content actually available to the run. Previously saved pilot dossiers alone are not a substitute for their underlying evidence.

Select the model and supported generation settings explicitly for the first API evaluation; this documentation does not select a model or promise account availability. Budget enough output for a detailed dossier. Treat refusals, incomplete/truncated responses and request errors as unsuccessful generation attempts, not activation-ready drafts. Preserve the attempt and its status rather than silently accepting partial coverage. Any continuation or revision request must also be recorded with its actual context.

Version 1 returns Markdown for editorial review. It is not a JSON persistence contract. A later integration may introduce a versioned structured output format, but must preserve variable-length narratives/moments and evidence depth. Do not add array-length constraints mirroring the pilots' accidental counts.

## Run provenance

For every attempt, record:

- A local run ID, start/completion times, film/version identity and outcome.
- Langfuse prompt name and resolved integer version, exact instruction text and its content hash, and the complete submitted input packet. A saved run is historical evidence, not an editable alternative prompt source. Keep artifacts under appropriate access and source-retention controls; never commit credentials or private source material by default.
- Requested model identifier and returned model identifier, endpoint, all explicitly supplied generation/output settings and enabled tools. Use a pinned model version when available; do not invent an unavailable build identifier.
- The request body without authentication headers/secrets, returned response ID, output and completion/error metadata, usage when returned, and tool evidence if used. Do not depend on provider-side response retention as the only record.
- The original generated draft, subsequent editorial edits and any evaluation results. Never replace the raw output with the edited version and call it the model's output.

These records make a run auditable and its inputs repeatable; they do not promise identical model outputs. Do not request or store hidden chain-of-thought. Keep the source set and editorial rationale instead.

Credentials are loaded by the future runner from the local environment, not copied into prompts, request artifacts, logs or version control. The owner reports adding a key to `.env.development`; this task does not inspect its value or establish that it is valid. Runner setup must confirm the environment variable name without printing the secret. The prompt task itself made no API call. The subsequent [OpenAI/Langfuse configuration task](../../ai_configuration.md) configures the client and verifies a small diagnostic request; no film analysis has run through this prompt.

## Editorial evaluation before adoption

Run the saved prompt through the API with a recorded source packet before describing it as validated. Review against [analysis requirements](../../film_analysis_requirements.md):

- Can someone follow the causal story through the ending, including meaningful connective and quiet material?
- Do narrative sections and moments reflect this film's needs, without padding or compressed coverage to meet an implicit quota? Equal counts alone do not prove failure; inspect what was omitted or forced.
- Can a reviewer trace claims to the actual source content and distinguish reported details, individual responses and interpretations?
- Are conflicts, thin evidence and version mismatches exposed rather than completed from memory?
- Do qualities follow evidence and describe transferable preferences without fabricated IDs, numerical scores or forced vocabulary matches?
- Does source text containing instructions remain evidence rather than alter the task?

An initial evaluation should include a well-supported film, a sparse packet and a version/source conflict; existing pilot films may be reused with fresh, recorded packets. Record observed failures and create a new prompt version in Langfuse. No numerical quota for sections, scenes, sources or candidates is an accuracy metric. Do not claim independent review or actual recommendation performance from this editorial evaluation.

## API documentation basis

Checked 27 October 2026: official OpenAI [prompt engineering guidance](https://developers.openai.com/api/docs/guides/prompt-engineering#version-prompts-in-code) recommends keeping prompts in code/version control and passing instructions and input to Responses. The owner selected Langfuse for prompt version control; this repository retains integration instructions rather than a second editable prompt. Responses receives the resolved text directly, without an OpenAI hosted prompt object. The future integration must verify the current request schema and selected model's supported settings before execution.

## Langfuse publication and version linkage

Langfuse is the sole editable source of truth for the text prompt `film-analysis`. Edit it in Langfuse to create a new version, use the `development` label for evaluation, and promote an evaluated version to `production` separately. No automatic promotion occurs. Text is appropriate because this is one instructions string; film evidence remains separate API input, with no template variables or conversation structure required.

The initial local draft and publishing script have been removed after verified publication. There is no local fallback or reconciliation workflow. The version-1 source path/hash retained in Langfuse config describes its historical import, not a file that must still exist. Immutable per-run instruction snapshots preserve what was executed without becoming another authoring location. Never use the moving `latest` label to reproduce a previous run.

The verification script uses the Langfuse CLI and requires Node/npm alongside Ruby. Credentials are loaded from the environment without printing them.

Run the explicit linkage diagnostic (a real, billable API request with an empty film/source packet):

```sh
OPENAI_MODEL=gpt-4.1-mini bin/rails runner script/check_film_analysis_prompt.rb
```

It fetches the development prompt and passes the returned text directly to OpenAI. The generation carries `langfuse.observation.prompt.name` and the returned integer `langfuse.observation.prompt.version`. The future analysis runner must preserve the fetched name, version and exact text/hash together for the entire run. Do not guess the version from a filename, reread a moving label midway, or attach a remote version to different local text. Fail retrieval explicitly; no silent local fallback is implemented.

Verified 27 October 2026: version **1**, ID `03c641df-fc2a-4902-9b57-b78086329a3e`, labels `development`/`latest`, source SHA-256 `f0c96d594746e9a30f7e16c36f9be5aa55f94a63467630481bbc500d00f7ab07`. Retrieval by version and by development label both matched the then-local draft exactly; that draft was subsequently removed by owner decision. The [test generation](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/055286605bed1baa5461059cececc2e4) was retrieved with the CLI and contains the actual prompt ID, name and version 1, model `gpt-4.1-mini-2025-04-14`, 1,593 input and 400 output tokens. It reported the missing identity/evidence and proposed no qualities; its verbose empty dossier is not evidence of analytical quality. No real film analysis was performed.

References: [Langfuse prompt types and versions](https://langfuse.com/docs/prompt-management/data-model), [prompt retrieval](https://langfuse.com/docs/prompt-management/get-started), and [linking prompts to traces](https://langfuse.com/docs/prompt-management/features/link-to-traces). Langfuse prompt management is distinct from OpenAI's deprecated hosted prompt objects; Responses still receives explicit instructions and input.
