# 001h — Asynchronous product-domain communication design

Status: Merged  
Owner: Foundation / architecture documentation

## Goal

Replace the synchronous-only product-domain communication decision with durable asynchronous domain events, as explicitly requested by the owner. Map Library, Ratings and Recommendations publication/consumption and revise the delivery plan before runtime implementation.

## Scope

- Record ownership, event meanings, delivery/ordering/retry guarantees, eventual consistency and consumer outcomes in docs/domain_events.md.
- Update the current architecture/product briefs, implementation plan, task 013 draft and AGENTS.md to reflect the owner's superseding decision.
- Keep publisher/consumer implementation separate and identify prerequisites, including durable jobs and event retention.

## Scope restrictions

- Documentation only; no runtime, schema, jobs, packages, deployment or external publication.
- Preserve historical merged task specs as implementation evidence. Do not claim events or workers are implemented.
- No broker, event-sourced domain model, generic workflow engine or speculative events without identified consumers. Provider/consumer contracts still require scoped implementation specs.

## Acceptance criteria

- **AC1:** A domain communication map covers Library facts, Ratings submissions/preferences and recommendation responses, with no circular action replay.
  Check: inspect the event matrix, distinguish recorded user requests from successful Library changes, and define delivery/retry/ordering and conflicts.
  Result: Passed — reviewed docs/domain_events.md against all three domains: facts versus action requests, outcome acknowledgements, anti-loop rules, per-stream ordering, replay/bootstrap, independent failures and expired-user handling are explicit.
- **AC2:** Current planning documents consistently use asynchronous communication and task 013 no longer promises synchronous MakeAvailableForRating.
  Check: search current docs and AGENTS.md for obsolete synchronous-only rules; inspect dependencies, exclusions and deferred decisions; run git diff --check.
  Result: Passed — searched current architecture/product/plan documents, task 013 and AGENTS.md for synchronous-only rules and MakeAvailableForRating references. Remaining references describe superseded behaviour or unrelated Identity/internal operations. Updated task ownership/dependencies; git diff --check passed. Documentation links checked locally. No runtime tests run: documentation-only change.

## Implementation notes

Created the domain-event design and updated current briefs, plan, task 013 and AGENTS.md. The owner's explicit event direction supersedes the previous prohibition. Existing merged specs retain historical implementation evidence. Delivery infrastructure is now planned as 001i, Library publication as 012a, and consumers/action publishers remain separately owned tasks. Exact event schemas, backend, retention windows and metadata ordering still need implementation specs. No application code, migrations or dependencies changed.

Owner acceptance / merge: Approved by the owner and merged via [PR #25](https://github.com/adambelton/glutton/pull/25) on 21 October 2026 at 16:16:38 UTC; squash commit `4a0943bcbc94573d6048c534a857388fdc416ff2`. Hosted Repository checks passed on head `cbb297642c092ec712d99574eadd3324e7955791` before merge.
