# 034 — Legacy source-admission simplification

Status: Historical implementation record — accepted by owner 27 October 2026  
Owner: Film knowledge

Current direction is in [film-quality requirements](../film_quality_requirements.md). This record describes existing legacy code, not future research/testing work. The former live retry report, costs and testing protocol were removed in task 042.

## Delivered behaviour

Removed the requirement that every admitted source URL have an explicit page-open tool action. The generated-document parser no longer accepts the response/history argument or checks `opened_urls`. Source shapes, URL/reference integrity, independent-origin counts, two-source factual admission, caption rules and OpenSubtitles exclusion remain in the legacy implementation. Screenplay became an explicit source kind; the then-managed prompt distinguished script drafts from the released film.

## Historical verification

The delivered code passed `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 534 tests / 5,665 assertions, zero failures/errors/skips; style, dependency/security checks and eager loading passed. These are historical implementation checks, not checks rerun by task 042. Unit coverage verifies valid documents can save without page-open history while malformed evidence still fails.

No new implementation, API run, prompt publication, catalogue mutation or deployment is authorised here. Existing FilmAnalysis data remains unchanged until its future ownership/retention design is settled.
