# 027b — Version the analysis prompt in Langfuse

Status: Ready for review  
Owner: Film knowledge / prompt management

## Goal

Publish the reviewed analysis instructions as a Langfuse-managed prompt and verify retrieval and linkage to a real generation, without implementing the film-analysis pipeline.

## Scope

- Inventory: `film-analysis`, text, managed in Langfuse; no template variables. The initial local draft was removed after publication. Film evidence remains separate API input. No production call site exists yet. The Foundation connectivity-check prompt remains independent.
- Initial publication used an explicit CLI script. Owner follow-up makes Langfuse the sole editable prompt source: remove the local text and publishing script, retain retrieval/verification and historical publication evidence. Revisions are created in Langfuse and evaluated under development before production promotion.
- Retrieve the published version and verify exact source equality. Run a small missing-identity diagnostic with those instructions and record the actual prompt name/version on its generation; fetch observations to verify the relationship.
- Document version/label selection and the future runner's requirements; record publication evidence.

## Scope restrictions

- No task 028 implementation, film imports, analysis persistence, real film research run, scoring or new domain communication.
- No automatic publishing at boot, silent fallback to local text, fake prompt links, migration of unrelated diagnostic prompts or production-label changes.
- Credentials stay in the environment; source packets must not enter higher-priority prompt instructions.

## Acceptance criteria

- **AC1:** The configured project contains the exact analysis text as a versioned prompt.
  Check: publish with CLI; retrieve by version and development label; compare text/hash to local source.
  Result: Passed — script published film-analysis version 1 with development/latest labels and source hash. CLI retrieval by version 1 and development label matched the repository text exactly.
- **AC2:** A real generation uses the retrieved instructions and links to their version.
  Check: send a bounded missing-identity input, export and retrieve the generation; verify prompt ID/name/version, model/usage and input/output. This checks wiring, not analytical quality.
  Result: Passed — real missing-identity diagnostic completed, recorded 1,593 input and 400 output tokens, and proposed no unsupported qualities. CLI observation query verified promptId 03c641df-fc2a-4902-9b57-b78086329a3e, promptName film-analysis, promptVersion 1 on trace 055286605bed1baa5461059cececc2e4. No film-analysis quality validation claimed.
- **AC3:** Publishing is explicit, reproducible and scoped.
  Check: syntax/style, pilot verifier, documentation references and git diff --check. No runtime behavior changed in the application.
  Result: Passed — both operational scripts passed Ruby style; pilot verifier and git diff --check passed. Documentation links inspected. No app runtime changes or schema changes; existing Foundation setup is used.

## Implementation notes

User explicitly requested Langfuse prompt management. The skill's production-label migration guidance applies to already-live prompts; this prompt has never served a live analysis, so development is appropriate.

Owner acceptance / merge: Pending.

Published prompt and verification evidence are recorded in the [prompt guide](../prompts/film_analysis/README.md). Initial publication used a script that was subsequently removed. The retained version-linked check runs only when explicitly invoked. Future analysis runtime loading remains part of the separately scoped runner.

Owner-approved follow-up: remove duplicate local prompt storage and publisher; keep the retrieval/check script. Every future analysis run records the Langfuse prompt name/version, exact instructions and content hash as immutable execution provenance, not another editable prompt source.

Follow-up verification: pilot verifier passed (six baseline hashes, 196 links/anchors, twenty associations, thirteen historical selections); 117 local references across four updated documents resolved; git diff --check passed. No runtime changes or additional paid API calls were needed.
