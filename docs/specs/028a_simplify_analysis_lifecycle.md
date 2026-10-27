# 028a — Simplify the Film analysis lifecycle

Status: Merged via PR #43  
Owner: Film knowledge

## Goal

Simplify PR #42's editing and publication implementation while retaining its Film-owned workflow and historical results. Owner authorized this follow-up on 27 October 2026. Prerequisites: task 028 and the Film aggregate ownership in the architecture brief.

## Scope

- Keep fresh loading and a per-film transaction lock at the existing edit/publication boundaries. Remove nested analysis and association locks, lifecycle permission flags and duplicate publication validation.
- Name the shared draft guard `ensure_unpublished!` so it describes the rule for editing, publication and deletion.
- Model actions enforce draft permissions and supersession rules. Film edit/publish operations are the supported write interface; arbitrary Active Record updates and concurrent direct association writes are not supported lifecycle operations. Remove tests promising those bypass protections. Retain deletion protection and read-only accepted associations/vocabulary.
- Preserve draft inheritance, explicit failures, publication rollback, historical selection and schema constraints. Keep shared-vocabulary conflict handling across films.

## Scope restrictions

- No schema, prompt, provider, generation, UI or other domain changes. Preserve existing uncommitted task 029 work.
- No new abstractions, state machine, version snapshots or compatibility layer. Do not remove atomic publication or history.

## Acceptance criteria

- **AC1:** Film editing reuses drafts and preserves published history; publication resolves qualities and replaces current knowledge atomically, with unchanged failures and rollback.
  Check: existing lifecycle, document/candidate and public-operation concurrency tests.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 521 tests / 5,612 assertions, no failures/errors/skips, including the lifecycle and remaining five concurrency cases. Style and security checks passed.
- **AC2:** Supported operations retain history protection with no nested analysis/association locks or lifecycle flags; publication readiness is checked once.
  Check: inspect changed paths and run full CI, eager loading and whitespace checks.
  Result: Passed. Inspection confirms Film edit and PublishAnalysis retain their existing transaction/lock boundaries; FilmAnalysis and AnalysisQuality no longer acquire locks. Lifecycle flags and the redundant service validation are removed. `git diff --check` passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed, with the existing non-eager-loaded mailer-preview directory notice.

  Follow-up guard rename: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_analysis_test.rb` passed 24 tests / 177 assertions, no failures/errors/skips. `git diff --check` passed.

## Implementation notes

Removed nested locks, save callbacks and lifecycle flags. Retained the simple immutable-film-identity validation, model action permissions, published deletion protection and read-only quality associations. Readiness validation now occurs in `publish!`; any earlier quality creation or supersession rolls back if readiness fails. Removed the direct-association race test and raw lifecycle-update assertions; retained public-operation concurrency and rollback tests. The history test now uses the freshly published record returned by the operation.

Initial focused test attempt was blocked by sandbox PostgreSQL access. The authorized rerun reported one stale-instance test failure (32 tests / 216 assertions); the corrected test and full suite then passed as recorded above. No provider calls or migrations were run.

Direct low-level persistence is not a supported authoring interface; database constraints remain, but callbacks no longer attempt to make every raw write equivalent to a domain action.

Owner acceptance / merge: Pending.

The subsequent [028b boundary sweep](028b_model_behaviour_boundaries.md) moves the retained publication transaction from PublishAnalysis into Film and candidate resolution into FilmAnalysis. The verification above records the completed 028a state; current combined verification is in 028b.

## Owner acceptance — 27 October 2026

The owner accepted the final implementation and authorized PR creation and merge after hosted CI, together with tasks 028a, 028b and 029. Latest combined local CI passed 522 tests / 5,618 assertions with clean style/security checks; eager loading and whitespace checks passed. This acceptance does not authorize a paid film-generation run. Hosted CI and merge evidence will be recorded after merge.

## PR #43 merge — 27 October 2026

Owner-authorized [PR #43](https://github.com/adambelton/glutton/pull/43) merged at 16:38:40 UTC as squash commit `94758745f8b9d1c9a8cb6f7c7fcaa2fdf2cd2fd5`. Hosted [Repository checks](https://github.com/adambelton/glutton/actions/runs/40542518272) passed on exact head `641f6de76daae15c13c82a1fc47dbd0b2c22f6e5` at 16:37:26 UTC. Local main was fast-forwarded. Earlier acceptance/pending statements describe pre-merge history. No real film-generation request was made.
