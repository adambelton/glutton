# 001e — Record object-role design conventions

Status: Ready for review  
Owner: Foundation / development conventions

## Goal

Record the owner's agreed role/behaviour conventions in repository instructions and align the architecture brief, so future tasks and reviews apply them consistently. No application contract changes.

## Scope

- Add concise implementation/review rules to AGENTS.md covering role trust, behaviour ownership/naming, class-awareness smells, role-specific collaborator names and separate freshness handling.
- Replace the architecture brief's narrower argument-guard guidance with the same conventions and link to AGENTS.md as the maintained instruction source.
- Record the transition exception: models own ordinary actions and permissions; transition services own coordination and changes between types, without source-model sibling knowledge.
- Record outcome/contract-focused testing conventions, applying the same role rules to tests and avoiding APIs invented only for test assertions.
- Record this supporting documentation task in the implementation plan.

## Scope restrictions

- Documentation only. No application/test/schema changes, broad audit, refactor, speculative module/type, publication, PR changes or merge.
- Preserve existing unrelated architecture notes and task 010 work. Do not equate meaningful domain-state predicates with disguised class identification or treat freshness validation as role validation.

## Acceptance criteria

- **AC1:** Repository instructions cover the agreed conventions with concrete role-name examples and justified boundary exceptions.  
  Check: Read AGENTS.md and the architecture cross-reference against the owner's discussion; inspect the diff for consistency and preserved unrelated text.  
  Result: Passed — manually compared AGENTS.md rules with the owner's four conventions and subsequent clarification. They cover role-specific naming, default trust, behaviour ownership, disguised class predicates, explicit boundary justification and independent freshness. The architecture brief links to the maintained instruction section; unrelated notes are preserved.
- **AC2:** Only scoped documentation changes are made and whitespace checks pass.  
  Check: Inspect changed paths and run `git diff --check`. No runtime tests are needed for documentation-only work.  
  Result: Passed — only AGENTS.md, architecture brief, implementation plan and this documentation spec were changed for task 001e. `git diff --check` passed. Runtime tests were not run because no executable code changed.

## Implementation notes

Added the object-role conventions to AGENTS.md, replaced the architecture brief's narrower class-guard guidance with a cross-reference and aligned summary, and registered the documentation follow-up in the plan. No application code, tests, schema, PR state or remote branches changed. Owner subsequently requested the testing-convention addition: tests verify observable outcomes/contracts and follow the same role rules, with explicit storage contracts remaining testable. Recorded this in AGENTS.md and the architecture brief. No deviations.

Owner authorization: Owner requested recording the conventions on 20 October 2026.

Owner acceptance / merge: Pending review and merge.
