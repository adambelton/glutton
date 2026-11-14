# Explain the selected recommendation

Status: Draft  
Owner: Recommendations

## Goal

Give the viewer a short, spoiler-safe reason for the selected film based on the evidence used to rank it.

## Proposed scope

- Start with a deterministic explanation from the film's matching quality contributions and the current applied Ratings evidence. Keep ranking and selection behaviour unchanged.
- Prefer the strongest positive match that is safe to show. Distinguish direct evidence from the viewer's notes, profile inference, and rating-only patterns when that distinction is supported by the scoring evidence.
- Leave out the explanation when no match supports a useful and safe reason. A film can still rank first without a positive match.
- Show the reason near the recommendation in localized copy. No provider calls, presentation history, event changes or Registry mutations.

## Decisions to review

- Agree how to identify spoiler-safe quality labels before exposing them. For example, use a small approved set of tone and style qualities for the first version.
- Agree whether to start with one reason per film and whether a ratings-only explanation can mention the viewer's past rating patterns without naming the films.
- Agree the smallest read shape that carries provenance from the same applied score sets used for ranking. Aggregate totals alone do not identify direct versus inferred evidence.
- Decide how explanations should behave when a recommendation stays queued and the viewer submits more ratings. The current queue stores the film and selection time, while `RankFilms` returns contribution totals only at admission. Keeping the original reason would require recording it at admission. Using current evidence would require phrasing it as a current match.

## Acceptance criteria

- Each shown reason is supported by a matching quality that contributed positively to the film's score and by the viewer's current applied evidence. Evidence from other viewers, superseded ratings and unapplied evaluations is excluded.  
  Check: focused Recommendations tests with direct, inferred and rating-only cases.  
  Result: Not run.
- The browser shows a spoiler-safe reason when one is available. A candidate with no suitable reason still displays normally.  
  Check: request or browser coverage for both states.  
  Result: Not run.

## Implementation notes

Not implemented. The architecture brief requires explanations to reflect the evidence used in ranking and distinguish direct expression from inference. The ranking result already carries signed totals by quality. It does not yet carry the contributing evidence by classification.
