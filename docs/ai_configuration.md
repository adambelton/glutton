# OpenAI and Langfuse configuration

Owner: Foundation / observability. Task [001m](specs/001m_langfuse_tracing.md).

Rails configures the official OpenAI Ruby client and an isolated OpenTelemetry provider for Langfuse. No requests run at boot. The legacy generated-analysis runner exists, but further generative research/testing is not the current direction; its replacement or retirement is separately scoped. Only explicitly instrumented operations are exported, not Rails requests, SQL or arbitrary HTTP traffic.

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

## Existing legacy integration

The configured OpenAI client/tracer supports the currently implemented generated-analysis path. JEV is the chosen engine for the new quality direction; question design and request packing remain open. See [film-quality requirements](film_quality_requirements.md). No provider request is needed to edit these documents or plan category persistence.

Former live diagnostic results, trial reports and test-running instructions have been removed. Existing configuration, secrets and remote traces remain untouched. Later code removal or provider adaptation requires its own scoped task; this cleanup does not disable the current runner.
