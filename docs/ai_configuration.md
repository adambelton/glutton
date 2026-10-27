# OpenAI and Langfuse configuration

Owner: Foundation / observability. Task [001m](specs/001m_langfuse_tracing.md).

Rails configures the official OpenAI Ruby client and an isolated OpenTelemetry provider for Langfuse. No requests run at boot. No film-analysis runner exists yet; task 028 remains unimplemented. Only explicitly instrumented operations are exported, not Rails requests, SQL or arbitrary HTTP traffic.

## Environment

Set secrets in `.env.development` locally (already ignored by Git), or through the deployment's environment/secrets configuration:

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | OpenAI project API key. |
| `OPENAI_MODEL` | Required by the diagnostic command; choose explicitly. It is not a default analysis-model choice. |
| `LANGFUSE_BASE_URL` | Langfuse origin, e.g. `https://cloud.langfuse.com`; match the project's region or deployment. |
| `LANGFUSE_PUBLIC_KEY` | Langfuse project public key. |
| `LANGFUSE_SECRET_KEY` | Langfuse project secret key. |
| `LANGFUSE_TRACING_ENABLED` | Set to `false` to disable export. Otherwise all three Langfuse settings enable it. Tests always disable live clients/export. |

Dotenv loads before Rails initializers in development. The client is available at `Rails.application.config.x.openai_client`; the dedicated provider at `Rails.application.config.x.langfuse_tracer_provider`. Missing OpenAI credentials leave the client absent. Missing Langfuse settings disable export; partial or invalid settings disable it with a sanitized warning. HTTPS is required except for localhost development deployments.

The OpenAI client uses a 60-second timeout and zero automatic retries so a diagnostic has one bounded attempt. Future workflows must choose their retry policy explicitly. Langfuse uses the official Ruby OTLP exporter, Basic authentication and the v4 ingestion header, with a five-second export timeout. Batch export and shutdown flush are handled by the OTEL SDK; its batch processor resets after process forks. Short scripts should explicitly flush, as the check does. Export is best-effort observability, not a transactional delivery guarantee; verify ingestion separately. No public trace sharing is enabled.

Dependencies locked for this implementation: `openai` 0.113.0, `opentelemetry-sdk` 1.13.1, `opentelemetry-exporter-otlp` 0.37.0. Ruby uses native OpenTelemetry because the official Langfuse language SDKs cover Python and JS/TS.

## Connectivity check

This command sends a small, real, billable OpenAI request and traces its result. It does not analyse a film or mutate domain data:

```sh
OPENAI_MODEL=gpt-4.1-mini bin/rails ai:check
```

It requests `OK`, limits output to 32 tokens and uses `store: false`. It prints the trace ID, response ID, actual returned model and reply. The root `check-ai-connection` contains child `check-openai-response`, typed as a generation. Both carry environment, version and diagnostic tags. The child records the exact non-sensitive diagnostic input/output, response status/ID, actual model and returned usage. Exceptions propagate as failures; raw exception text is not exported or printed because it can contain private request data.

The command proves API connectivity; it does not prove delivery merely by returning a trace ID. Retrieve that trace's observations through the Langfuse CLI and confirm the generation's parent, input/output, actual model and token usage. Current `observations list --trace-id ... --fields core,basic,io,model,usage,trace_context` queries the modern observations API. Load credentials into the process environment without printing them; use `LANGFUSE_HOST` with the same value as `LANGFUSE_BASE_URL` for the CLI. Never use `--curl` with live credentials in shared logs.

## Verified live result

27 October 2026: [diagnostic trace](https://cloud.langfuse.com/project/cmvqn97r302f3ad0nifu0wdxj/traces/7894baf13017103e65913a77ba383684) was exported and retrieved through the CLI. It contains a root span and one generation with the correct parent ID, `development` environment, `connection-check` tag, actual `gpt-4.1-mini-2025-04-14` model, response `OK`, 21 input tokens and 2 output tokens. Langfuse calculated the cost from usage. No synthetic model usage, film analysis, user data or credentials appear in the observations. This model was selected for connectivity only.

## Future analysis instrumentation

The analysis runner should use one trace per analysis attempt, one generation per real model invocation and separate spans for actual retrieval/validation work. Capture the exact approved prompt/source context and returned output under the established source/privacy rules; metadata identifies film, prompt revision/hash and analysis/run version. Carry filterable context on each span. Never automatically trace all function arguments, headers or environment variables. Model and usage come from the response, not estimates. Capture provider-returned reasoning summaries only if available and appropriate; do not request hidden reasoning. The subsequent [prompt-management task](specs/027b_langfuse_analysis_prompt.md) publishes the analysis instructions and verifies a version-linked diagnostic. No actual film-analysis pipeline is yet instrumented.

Current official guidance consulted: [Langfuse OpenTelemetry integration](https://langfuse.com/integrations/native/opentelemetry), [trace best practices](https://langfuse.com/docs/observability/best-practices), [Ruby OpenTelemetry instrumentation](https://opentelemetry.io/docs/languages/ruby/instrumentation/) and [OpenAI SDKs](https://developers.openai.com/api/docs/libraries). The installed [Langfuse skill](https://github.com/langfuse/skills/tree/main/skills/langfuse) supplied the setup and trace-audit workflow.
