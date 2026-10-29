# 046 — Record equal base treatment of qualities and categories

Status: Ready for review  
Owner: Film knowledge

Artifact disposition, 29 October 2026: this is a historical task record. Research filenames, commands and check results below describe work completed then; superseded tuning artifacts and replay scripts were intentionally removed in [task 050](050_jev_research_cleanup.md). Current inputs and reusable examples are in the [working baseline](../film_qualities/README.md); historical commands are not current reproduction instructions.

## Goal

Record the owner's clarification that narrative centrality must not privilege one quality over another in the initial product. All qualities and categories begin with equal base weight; category weighting is a possible later feature. Prerequisites: implementation plan, task template, product/film-quality requirements, scoring design and task 045 results read.

## Scope

- Explain the experimental greed/minimal-dialogue ranking through the actual defining-characteristic question: plot/conflict/atmosphere/outlook centrality, not personal enjoyment influence.
- Record equal base quality treatment and category multipliers of 1 conceptually; do not use JEV centrality or confidence as scoring weights or a default importance eligibility gate. Support remains an evidence question.
- Keep the max-20 cap and vocabulary relevance criterion. The within-cap selection policy remains open; neither top confidence nor centrality alone guarantees a useful set. Avoid generic theme-over-presentation bias without introducing category quotas.
- Record future system- or user-controlled category weighting as an option, without choosing a controller, UI, storage or formula. Preserve existing rating-strength/sentiment/evidence distinctions; equal concept/category base treatment does not assert identical user-derived contributions.
- Align maintained docs and qualify prior research recommendations while preserving frozen inputs/results. Planning/docs only.

## Scope restrictions

- No production source/schema, scoring engine, weight fields, category implementation, automatic assignment, new event contracts or provider calls. No new question tuning, experiment or source acquisition.
- Documentation belongs to Film knowledge; cross-domain design docs only reflect the owner's baseline clarification. Ratings and Recommendations retain ownership of their implementation and user-derived scores.
- Do not relabel research outcomes or claim user preference validation. Preserve previous research, .agents/, .obsidian/ and unrelated work. No deployment/merge.

## Acceptance criteria

- **AC1:** Current docs distinguish centrality, evidence support and personal importance.  
  Check: product/quality/scoring/architecture wording and the task-045 qualification agree; greed is not declared universally more preference-relevant than minimal dialogue.  
  Result: Passed manual review of product, film-quality, scoring and architecture docs. Both experimental reports now flag the centrality judgments as historical; the greed/minimal-dialogue distinction is explicit.
- **AC2:** The equal baseline and deferred options are unambiguous.  
  Check: equal base qualities/categories, no model-importance/confidence weights or default importance gate, no category preference/quota; existing user-evidence rules and cap 20 retained. Selection and future category control remain open.  
  Result: Passed manual review. Equal base treatment and conceptual category multiplier 1 are recorded without new fields/formulas; rating strength, sentiment and evidence rules remain. The max-20 cap remains, while selection policy and future category controls are explicitly open.
- **AC3:** Only documentation changes, with research preserved.  
  Check: before/after hashes of task-045 inputs/results, production diff, local links/anchors and whitespace; update plan and Ready for review without self-acceptance.  
  Result: Passed: SHA-256 comparison preserved all 10 frozen task-045 input/result files; `git diff --name-only -- app db test config lib` was empty; 945 local Markdown links/anchors passed before the final plan link; `git diff --check` passed. Verification summary: `/tmp/glutton-046-verification.json`. Plan updated. No runtime tests or paid calls were run for this documentation-only task.

## Implementation notes

Updated maintained product, quality, architecture and scoring docs. Added current-baseline notices to both historical JEV experiment reports and the vocabulary pipeline notes, preserving experimental inputs/results and their historical conclusions. No production implementation, category controls or score changes. Owner acceptance remains separate from these checks.

Owner acceptance / merge: Pending.
