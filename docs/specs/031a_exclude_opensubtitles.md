# 031a — Exclude OpenSubtitles from the research trial

Historical implementation/design record. Current direction is in [film-quality requirements](../film_quality_requirements.md); fixed dimensions are superseded by planned task 043, and independent analysis-model retention is under review. Removed experiment reports are not prerequisites or active product requirements.


Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Apply the owner's decision to try the combined research workflow without OpenSubtitles, preserving other accessible source options and existing evidence rules. Prerequisite: task 031. Read the combined-research protocol and Film knowledge brief; no cross-domain contract changes.

## Scope

- Update the managed development prompt to exclude OpenSubtitles and direct research toward accessible independent plot accounts, reviews, criticism and production sources. Other accessible caption sources remain optional under the existing matching/cue rules.
- Reject OpenSubtitles.com/.org source URLs and their subdomains at the generated-document boundary, even if the model opens them. Keep this as a small fixed source policy, not a provider-management framework.
- Publish/retrieve the development update, preserve prior versions, add focused admission tests and update protocol/plan evidence.

## Scope restrictions

- Film knowledge only. No subtitle API adapter, new source subscription, payment, account registration, schema/dependency change, downstream behaviour or publication.
- Preserve Alien's draft and all prior run artifacts. No further paid research attempt until film/model/output allowance is agreed; this follow-up does not select them or authorize regeneration.
- Do not assert the provider's current pricing or that alternative sources guarantee adequate coverage. Two-source corroboration and evidence gaps remain unchanged.

## Acceptance criteria

- **AC1:** OpenSubtitles URLs cannot be admitted as evidence, while unrelated URLs remain usable.
  Check: focused tests cover base domains/subdomains, mixed-case hostnames and lookalike domains; invalid documents cannot save through existing generation validation.
  Result: Passed. Focused admission/generation/prompt suite: 27 tests / 172 assertions, zero failures/errors/skips. Tests exclude base domains, subdomains and mixed-case hosts even after recorded page opens, while admitting an unrelated lookalike hostname. Existing atomic generation validation remains passing.
- **AC2:** Development instructions match the owner's source decision.
  Check: publish/retrieve exact text/hash/version with the same research contract, no production label and no paid generation. Confirm other-source and two-source rules remain.
  Result: Passed. Published and retrieved `film-analysis` v5 by exact version and development label; exact text/config match the local publication snapshot. Contract remains `researched-analysis-v1`; SHA-256 `03459b64f5760afebfcecb8dd8d1429a23ce75d608afc7d400126da343024f2c`. Labels development/latest, no production. No generation request made.
- **AC3:** The change is documented and verified.
  Check: focused generation/admission/prompt tests, RuboCop, local links and `git diff --check`; full CI only if focused checks expose wider concerns. Record actual outcomes; mark Ready for review with acceptance/merge pending.
  Result: Passed. `bin/rubocop --cache false app/models/film_knowledge/generated_analysis.rb test/models/film_knowledge/generated_analysis_test.rb`: 2 files, no offenses. Focused suite passed as above; full CI was not repeated for this small source-policy change (task 031 full CI passed immediately beforehand). Local Markdown links and `git diff --check` passed.

## Implementation notes

Implemented a small source-URL exclusion at the existing generated-document boundary and updated only the relevant development prompt sentence. Other caption sources and all corroboration rules remain intact. No integration or paid-service change. Next live-test settings are requested; no new attempt executed.

Reproduce focused checks:

```sh
RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/models/film_knowledge/generated_analysis_test.rb \
  test/services/film_knowledge/generate_analysis_test.rb \
  test/services/film_knowledge/analysis_prompt_test.rb
bin/rubocop --cache false app/models/film_knowledge/generated_analysis.rb test/models/film_knowledge/generated_analysis_test.rb
git diff --check
```

Use `FilmKnowledge::AnalysisPrompt.call(version: 5)` and `.call(label: "development")` in `bin/rails runner` to verify retrieval. The publication snapshot is retained locally at `tmp/film_analysis_runs/task031a-prompt-published.json`. No factual-support or independence guarantee beyond task 031's documented limits is introduced.

Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
