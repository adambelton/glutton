# Capture optional recommendation rejection reasons

Status: Draft  
Owner: Recommendations

## Goal

Give viewers a way to explain why they rejected a recommendation so we can identify patterns in what the engine suggests.

## Proposed scope

- Keep the reason optional and associate it with the Recommendations-owned rejection.
- Keep rejection reasons out of automatic taste-profile updates. Post-viewing feedback and any reporting interface are separate tasks.

## Decisions to review

- Choose structured reasons, free text, or both based on the patterns we want to recognize.
- Decide when to offer the field and how to let viewers reject without filling it in.
- Agree storage and retention for the chosen format.

## Acceptance criteria

- A viewer can reject a recommendation with or without a reason and proceeds to the next recommendation in either case.  
  Check: browser coverage for both paths.  
  Result: Not run.
- A supplied reason belongs to the viewer's rejected recommendation and cannot be recorded on another viewer's record.  
  Check: request coverage for persistence and ownership.  
  Result: Not run.

## Implementation notes

Exploration only.
