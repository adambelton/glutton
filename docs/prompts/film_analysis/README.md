# Legacy generated-analysis integration

This documents existing code, not the current product direction. Maintained Wikipedia source context and accepted qualities now take priority; whether to retain FilmAnalysis is under review. See [current requirements](../../film_quality_requirements.md) and [planned category replacement](../../specs/043_editable_quality_categories.md).

The application still contains its OpenAI-based initial-analysis generator, strict generated-document validation and Langfuse-managed `film-analysis` prompt. The managed prompt is the sole editable source for that legacy integration; this repository contains no runtime prompt fallback. Configuration and entry points remain in code until a separately scoped change retires or adapts them.

The existing generator accepts only films with no analysis and saves an unpublished draft. It does not publish film qualities or change downstream scores. Removing this documentation's former research protocols does not remove the implementation or change eligibility/publication invariants.

No further generative-analysis testing, paid run, remote prompt update or migration is planned here. Obsolete experiment reports, generated examples, cost comparisons and live-testing instructions were removed at the owner's request. The retained implementation specs record delivered behaviour; they are not the new seed or JEV pipeline contract.
