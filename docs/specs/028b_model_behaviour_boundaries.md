# 028b — Keep film lifecycle decisions inside their models

Status: Merged via PR #43  
Owner: Film knowledge

## Goal

Complete the 27 October boundary sweep with Film and FilmAnalysis owning their mutations and lifecycle decisions. Review PRs #39–#42 and the uncommitted task 029 code against AGENTS.md. Prerequisites: tasks 028, 028a and 029, and the Film aggregate ownership recorded in the architecture brief.

## Scope

- Move the ordinary publication workflow from PublishAnalysis into Film and FilmAnalysis. Film selects its draft/current analyses and coordinates replacement under its existing transaction lock; FilmAnalysis validates and resolves its own candidates and saves associations on publication. Remove the redundant service.
- Let FilmAnalysis create a revision from its own content and candidates instead of Film extracting its raw attributes. Keep internal guards and proposal interpretation private.
- Give Film an explicit TMDB metadata predicate and fill operation. The importer retains external retrieval, validation, entity loading and transaction coordination; Film owns checking and merging retained metadata. Filling existing metadata remains an explicitly idempotent system operation.
- Preserve normal read APIs: identity/display fields, scopes, serialized generation input, quality-candidate value readers and persisted outcomes in tests are legitimate shared reads. Do not mechanically wrap every reader.

## Scope restrictions

- Film knowledge implementation only. Review Library changes but do not change another domain's implementation. No events, schemas, prompt/provider changes, publication policy changes or additional workflow abstractions.
- Preserve initial-only generation and manual revisions, existing draft inheritance/clearing, explicit failure semantics, atomic rollback, historical selection and shared-vocabulary identity handling.
- No paid requests, deployment, external communication, commit or merge.

## Acceptance criteria

- **AC1:** Publication, revision inheritance and metadata filling use model actions; callers no longer inspect metadata JSON or analysis associations to implement those rules.
  Check: inspect changed callers and run lifecycle/import/generation tests. Verify repeated metadata fill preserves existing metadata and extra supplied fields do not overwrite the retained snapshot.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/film_test.rb test/models/film_analysis_test.rb test/models/film_analysis_concurrency_test.rb test/models/film_knowledge test/services/film_knowledge` passed 87 tests / 1,284 assertions, no failures/errors/skips. The metadata-fill test verifies preservation of local values and the first source snapshot on repeated filling. Existing import tests verify legacy completion and skipping repeat retrieval.
- **AC2:** Publication preserves atomic replacement, rollback, quality resolution and historical results, including supported-operation concurrency.
  Check: existing lifecycle/concurrency tests and full local CI; eager loading and whitespace checks.
  Result: Passed. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed 522 tests / 5,618 assertions, no failures/errors/skips, with clean style/security checks. `RAILS_ENV=test bin/rails zeitwerk:check` passed (existing mailer-preview directory exclusion notice). `git diff --check` passed.

## Implementation notes

Removed PublishAnalysis. `Film#publish_analysis!` now selects and supersedes its current analysis under the same fresh-film transaction/lock boundary. `FilmAnalysis#publish!` validates once, resolves candidates, saves associations and reports candidate validation failures. `FilmAnalysis#create_revision!` owns copying its authoring fields; guards and proposal interpretation are private. `Film#tmdb_metadata?` and `fill_tmdb_metadata!` own source-state checks and the fill operation; ImportTmdbFilm retains retrieval/loading and the existing fill lock. No new transaction layer or provider behaviour was added.

The boundary sweep includes all four PRs from today and the uncommitted generation/simplification changes. PR #40 adds documentation only; PR #41's configuration/diagnostics do not use application model state. Library navigation uses model permissions for details and an existing batched read projection for collection display. Generation calls explicit Film input/permission/save operations. Quality candidates expose their declared value fields; schema/response validation inspects untrusted transport data. Tests read persisted public outcomes and do not inspect model instance variables. No additional violations were found in today's changed application paths.

Owner acceptance / merge: Pending.

## Owner acceptance — 27 October 2026

The owner accepted the final implementation and authorized PR creation and merge after hosted CI, together with tasks 028a, 028b and 029. Latest combined local CI passed 522 tests / 5,618 assertions with clean style/security checks; eager loading and whitespace checks passed. This acceptance does not authorize a paid film-generation run. Hosted CI and merge evidence will be recorded after merge.

## PR #43 merge — 27 October 2026

Owner-authorized [PR #43](https://github.com/adambelton/glutton/pull/43) merged at 16:38:40 UTC as squash commit `94758745f8b9d1c9a8cb6f7c7fcaa2fdf2cd2fd5`. Hosted [Repository checks](https://github.com/adambelton/glutton/actions/runs/40542518272) passed on exact head `641f6de76daae15c13c82a1fc47dbd0b2c22f6e5` at 16:37:26 UTC. Local main was fast-forwarded. Earlier acceptance/pending statements describe pre-merge history. No real film-generation request was made.
