# 047 — Record neutral JEV matching evaluation

Status: Ready for review  
Owner: Film knowledge

Artifact disposition, 29 October 2026: this is a historical task record. Research filenames, commands and check results below describe work completed then; superseded tuning artifacts and replay scripts were intentionally removed in [task 050](050_jev_research_cleanup.md). Current inputs and reusable examples are in the [working baseline](../film_qualities/README.md); historical commands are not current reproduction instructions.

## Goal

Record the owner’s source-context matching baseline, without qualitative prioritisation. Prerequisites read: implementation plan, task template, quality requirements, pipeline notes and frozen task-045 questions.

## Scope

- Separate concept definitions and evidence boundaries from guidance about importance, desirability or preference relevance.
- Record a neutral question shape and a quantitative evaluation focused on supported assignments and omissions, before capping.
- Identify steering in historical templates, including presence criteria; preserve historical artifacts.

## Scope restrictions

- Documentation only. No provider calls, production/schema changes, automatic assignments, category weights or new thresholds. No claim that current definitions have been fully audited or a revised question has been tested.
- Keep the accepted max-20 cap separate from this evaluation. Do not rewrite frozen requests/results or broaden into vocabulary replacement. Preserve unrelated work.

## Acceptance criteria

- **AC1:** Baseline asks contextual support, without importance or preference guidance.  
  Check: inspect requirements and pipeline example; distinguish semantic definitions from ranking rules.  
  Result: Passed manual review: neutral support question, no importance/preference ranking guidance, explicit definition/shared-state audit requirement. Full vocabulary audit remains unperformed.
- **AC2:** Quantitative evaluation has explicit limits.  
  Check: supported/unsupported/uncertain assignments, omissions and denominators are specified; no recall claim from selected positives alone.  
  Result: Passed manual review: assignment support and omissions have explicit adjudicated denominators; uncertain and insufficient-source cases remain visible; selected-only review cannot establish recall.
- **AC3:** Historical research and runtime are unchanged.  
  Check: SHA-256 comparison of task-045 JSON files, production diff, changed document links and whitespace.  
  Result: Passed: all 10 task-045 JSON SHA-256 hashes unchanged; `git diff --name-only -- app db test config lib` empty. Changed-document local links and `git diff --check` passed. No runtime tests or provider calls run.

## Implementation notes

Updated film-quality requirements and pipeline notes. Audited representative historical support/importance wording, including the hidden centrality criterion in presence-only haunting. Revised the unexecuted perception example to remove added substantiality guidance. This is a methodology clarification, not a completed vocabulary audit or tested new pipeline.

Owner acceptance / merge: Pending.
