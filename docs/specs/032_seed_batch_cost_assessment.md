# 032 — Record Batch API evaluation for the initial seed

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Make Batch API suitability and total-cost evaluation an explicit requirement before scaling the initial film seed. Owner requested consideration of batch APIs on 27 October 2026. Prerequisites: current implementation plan, Film knowledge pipeline brief and combined-research contract from tasks 031/031a.

## Scope

- Review current official OpenAI Batch documentation and record confirmed delivery/cost characteristics, remaining research-tool compatibility questions and the small verification needed before selection.
- Update the seed plan and generation protocol to compare Batch delivery with synchronous delivery for the same combined research-and-analysis request. Include model tokens, hosted tools, failures and valid saved outcomes in costing.
- Record result reconciliation and original-artifact preservation requirements for a future Film-owned delivery task; do not implement that task now.

## Scope restrictions

- Documentation only. No provider request/upload, paid probe, bulk execution, new job, scheduler, schema, dependency, generic workflow engine or publication change.
- Preserve combined research/analysis and current factual-source admission. Cost optimization must not silently remove research, lower evidence standards, regenerate existing analyses or turn failed requests into successful seeds.
- Do not claim exact hosted-tool/model/schema compatibility or discounted search-call pricing without verification. The Thing remains the chosen next sample; its model/token approval is still pending.

## Acceptance criteria

- **AC1:** The plan explicitly requires Batch evaluation before scaling the seed.
  Check: read the plan/protocol additions against the owner's request; confirm confirmed facts and unverified compatibility are distinguished.
  Result: Passed. Added an explicit pre-scale Batch evaluation requirement to the plan and current protocol. The assessment preserves combined research/analysis, source standards and Film-owned saves; current synchronous delivery is unchanged.
- **AC2:** Findings cite current official documentation and define a bounded next check.
  Check: fetch the official Batch guide; record Responses endpoint support, general 50% discount, 24-hour completion window, custom-ID reconciliation and per-request failures. Record that research-tool compatibility/cost requires a separately authorized probe of the exact request.
  Result: Passed. Fetched the current official Batch guide on 27 October 2026. Recorded confirmed endpoint/discount/window/reconciliation/failure/retention characteristics. Exact hosted research plus strict-schema compatibility remains explicitly unverified; a small separately authorized probe is required before selection. No Batch submission or paid request was made.
- **AC3:** Documentation remains consistent and usable.
  Check: verify local links and `git diff --check`; no runtime suite needed for this documentation-only outcome.
  Result: Passed. Local Markdown targets resolved and `git diff --check` passed. Runtime tests not run for this documentation-only change.

## Implementation notes

Recorded the Batch assessment in the existing generation protocol and linked it from the implementation plan. No application code, managed prompt or provider state changed. No Batch or live research request has been submitted. Compatibility and billed savings remain untested rather than assumed.

Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.
