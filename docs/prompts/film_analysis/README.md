# Retired generated-analysis integration

The catalogue uses Quality, QualityCategory, Film and FilmQuality for current accepted associations and Film source context. The former OpenAI analysis generator, prompt retrieval/check CLI and draft/publication lifecycle are retired. See the [current requirements](../../film_quality_requirements.md).

Existing remote Langfuse prompts/traces and shared AI configuration remain untouched. There is no runtime fallback to the former analysis workflow, and no prompt migration is required for the source-context JEV baseline.
