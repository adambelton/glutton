# NNN — Task title

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

Owner acceptance / merge: Pending.
