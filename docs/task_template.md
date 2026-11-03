This is a temporary working record for scope and validation before/during implementation, not a permanent delivery record. Amend it for review refinements; do not create another task for routine corrections, CI repair, PR publication or handoff. When preparing the PR, turn the final scope/behaviour/verification/limits into its description, update maintained progress/decisions, and delete this file as part of the PR. Track subsequent review/CI/merge on GitHub. Cite a PR in maintained docs only when specific evidence or a decision needs provenance; routine citations and history duplication are unnecessary.

# Task title

Status: Draft  
Owner: One domain or supporting area

## Goal

One independently verifiable outcome, prerequisites and any existing contracts consumed from other domains.

## Scope

- Work included in this task.

## Scope restrictions

- Preserve domain ownership: shared-data reads are allowed, but do not mutate another domain’s records or change its implementation. New behavioural contracts require agreement and independently scoped provider/consumer changes; an ordinary read does not require a new contract or projection. Review misplaced ownership or unnecessary coupling.
- Exclusions and constraints that prevent the included work from expanding: relevant design limits, dependencies, side effects or decisions deferred to another task.

## Acceptance criteria

For each criterion, state the observable result and how to check it. After implementation, add the exact command or manual steps and actual result here. Use result statuses **Not run**, **Passed**, **Failed** or **Blocked**, followed by concise evidence. Keep evidence proportionate.

- **AC1:** Required behaviour or boundary.  
  Check: …  
  Result: Not run.

## Implementation notes

After implementation, briefly describe what changed, relevant decisions, deviations and remaining limitations. Until then: Not implemented.

Review handoff: Pending. After opening the PR, continue scope/evidence/review tracking there and remove this record.
