# Retired generated-analysis integration

Owner confirmed FilmAnalysis removal on 29 October 2026. [Task 054](../../specs/054_direct_film_qualities.md) removes the local OpenAI analysis generator, prompt retrieval/check CLI, draft/publication models and generation rake task. The catalogue now uses Quality, QualityCategory, Film and FilmQuality for current accepted associations; see [current requirements](../../film_quality_requirements.md).

The former Langfuse film-analysis prompt and historical traces are not deleted remotely by this task. Shared AI configuration remains available to other application capabilities. No application runtime fallback, legacy generator or independent analysis lifecycle is retained. Historical implementation specs describe the retired system, not active commands or the new JEV pipeline.
