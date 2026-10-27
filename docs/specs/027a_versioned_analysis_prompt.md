# 027a — Record a reproducible film analysis prompt

Status: Merged via PR #41  
Owner: Film knowledge / analysis design

## Goal

Provide the first saved analysis-generation prompt and a documented OpenAI API run protocol. Remove the pilot's accidental fixed narrative/moment counts without rewriting historical research.

## Scope

- Write version 1 instructions covering evidence-led narrative, experiential analysis and editable quality candidates, with film-dependent section counts.
- Define per-film inputs, output expectations, API provenance and editorial evaluation.
- Record that future AI analyses use the OpenAI Responses API with saved prompt/input/output artifacts; distinguish this new prompt from the unsaved pilot instructions.

## Scope restrictions

- Documentation only. No API calls, API client, model selection, paid runs, ingestion, runtime/schema changes or task 028 implementation.
- Preserve baseline pilot files and their hashes. No fabricated API evaluation, model identifiers or retroactive provenance.
- No new cross-domain communication or scoring. Prompt output is an unactivated Film knowledge draft.

## Acceptance criteria

- **AC1:** A standalone versioned prompt covers evidence, detailed narrative, meaningful moments, dimensions and quality candidates without numerical quotas.
  Check: inspect instructions against the analysis requirements, including thin sources, conflicting cuts, quiet scenes and unsupported audience claims.
  Result: Passed — manual review: v1 requires causal narrative and contextual moments with variable counts, separates the seven dimensions from narrative structure, and explicitly handles sparse evidence, conflicting versions, quiet scenes and attributed responses. No model evaluation was performed.
- **AC2:** Future API runs can be audited without relying on conversation history.
  Check: inspect documented input assembly and required prompt, model, source, request/response and review records; verify official API guidance.
  Result: Passed — documented separate instructions/input assembly, source packet, exact prompt/request/output retention, model identifiers/settings, failed attempts and editorial changes. Official OpenAI prompt-engineering guidance was searched and fetched on 27 October 2026. No API call was made.
- **AC3:** Historical pilots are preserved and the documentation links resolve.
  Check: run the pilot verifier, relative-link/anchor check and git diff --check. Do not claim model-output validation without a run.
  Result: Passed — pilot verifier passed six baseline hashes, 196 links/anchors, twenty associations and thirteen historical selections. Additional Python link/anchor check passed 122 references across six documents. git diff --check passed. No runtime tests were needed for documentation-only changes.

## Implementation notes

Initially created a local v1 draft and its run/evaluation protocol. Task 027b subsequently published it to Langfuse; the owner then requested removal of the duplicate local text. Updated requirements, implementation plan and the task 028 reference without expanding runtime scope. This is a new prompt, not the unsaved historical pilot prompt. The owner reports configuring an API key; its value was not read and its validity was not tested. No client, paid generation or task 028 implementation was performed.

Owner acceptance / merge: Pending.

Owner-requested relevance pass: removed the application-boundary section and activation/persistence instructions from the prompt, simplified the role and variable-count instructions, and retained evidence/output requirements. Inspected against the reported redundant language; no API-based film-analysis evaluation is claimed. Runtime client/tracing work is separately scoped in task 001m.

Merge record: owner authorised merge after CI. [PR #41](https://github.com/adambelton/glutton/pull/41) merged on 27 October 2026 at 12:41:52 UTC, squash commit `1eee2a13d4238b98dca39b5cbc7928626e0d59a6`. Hosted checks passed on exact head `95968c58dd10d0169fd62d59859703c942d30ce4` at 12:41:31 UTC. Earlier review/pending notes describe pre-merge history.
