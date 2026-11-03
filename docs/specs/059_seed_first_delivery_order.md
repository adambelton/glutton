# 059 — Record seed-first admin delivery order

Status: Accepted  
Owner: Film knowledge

## Goal

Align the active roadmap with the owner's explicit order: load the initial seed, view canonical content, add manual editing, then introduce refresh/change-evaluation workflows. Defer expression-led missing-quality investigation until after initial release. Documentation only.

## Scope

- Update implementation plan, current quality requirements, product brief and workflow proposal to use the same ordered stages.
- Distinguish initial seed assignment from later evaluation of proposed changes. Initial assignment uses the chosen baseline; standalone refresh suggestions are not a seed prerequisite.
- Put manual TMDB/Wikipedia refresh before wiring its JEV quality check; keep source refresh, suggestions and explicit association application separate.
- Mark expression-led vocabulary discovery as post-release, without deferring the core interpretation of expressions for personal preferences.
- Keep task 058 deferred until the later change-evaluation stage; no new implementation/research prerequisite.

## Scope restrictions

- No runtime changes, database work, provider calls, new testing experiments, admin implementation or task-058 implementation. Preserve existing baseline/model decisions, domain ownership, historical delivery evidence and unrelated workspace changes.

## Acceptance criteria

- **AC1:** Active documents agree on the delivery sequence and release boundary.  
  Check: seed -> read-only canonical inspection -> manual editing -> manual source refresh -> JEV suggestion evaluation; expression-led gap discovery explicitly post-release. Core expression scoring remains in release scope.  
  Result: Passed — manually reviewed implementation plan, requirements, product brief and workflow proposal against the six ordered stages. Seed and read-only viewing are first, editing is next, manual TMDB/Wikipedia refresh precedes JEV change checking, and expression-led vocabulary discovery/testing is explicitly post-release. Initial JEV assignment remains part of seeding; the core expression-preference/scoring scope is preserved.
- **AC2:** Documentation is consistent and bounded.  
  Check: remove contrary initial-release expression-discovery and mandatory immediate sync/check language; retain explicit application and transient-suggestion design. Validate local links/whitespace; no application/data-baseline changes.  
  Result: Passed — removed earlier mandatory immediate refresh/check coupling and periodic-first language; removed expression-discovery tooling from foundational MVP scope and marked task 058 for stage 5 only. Transient suggestions and explicit application remain. python3 /private/tmp/glutton-057-handoff-check.py passed: 201 local Markdown links/anchors across 13 changed files, whitespace clean, all five retained baseline files unchanged and post-merge app/config/db/test/lib/script diff empty. git diff --check passed. No runtime tests, database changes or provider calls made for this documentation-only task.

## Implementation notes

Owner supplied priorities on 29 October 2026. This task records that implementation order; no new research or broad design exercise is required before starting the seed path.

Owner acceptance / merge: Accepted by owner on 3 November 2026; not merged.


Changes: reordered the active implementation plan and task-058 priority, updated release scope and staged refresh semantics in the requirements/brief/workflow, and explicitly deferred admin expression-gap discovery until after release. No new research, implementation approval gate or future task-spec tree was introduced.

Reproduce verification: read the ordered lists in the four active documents and compare them to AC1; inspect product-brief section 6.1.1/section 7 and task 058 for the release/priority boundary. The temporary handoff checker validates local file links/heading anchors and baseline hashes using the retained session snapshot. Run git diff --check and git diff -- app config db test lib script to confirm whitespace and documentation-only scope.
