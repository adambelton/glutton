# 001g — Refresh current implementation guidance

Status: Ready for review  
Owner: Foundation / documentation

## Goal

Make maintained implementation summaries consistent with implemented choices and review status (audit A4).

## Scope

- Refresh README introduction, architecture open decisions and implementation-plan summaries; link current review tasks and record verification without modifying historical merge evidence.

## Scope restrictions

- Documentation only; no product decisions, implementation, retrospective approval, external communication, deployment or merge. Preserve the audit baseline and existing historical specs.
- No automatic acceptance or merge. User authorized these fixes on 20 October 2026.

## Acceptance criteria

- **AC1:** Current summaries distinguish merged work, ready-for-review changes and planned work; Rails/PostgreSQL/Hotwire are settled while deployment/jobs remain open.  
  Check: Inspect source and task statuses against current summaries, verify local links and git diff --check.  
  Result: Passed — Manually compared README, architecture decisions and the implementation plan with current code, task specs and recorded merge history. Added an authoritative current-status section, corrected stale convention-fix wording and separated implemented Rails/PostgreSQL/Hotwire from open production/job choices. Local Markdown link checks and `git diff --check` passed.
- **AC2:** Changes stay within this owner and the stated scope; actual evidence and limitations are recorded.  
  Check: inspect scoped diff; record reproducible commands/results and mark Ready for review.  
  Result: Passed — Scoped diff inspected; no other-domain implementation changes within this task. `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed: 232 tests / 2,633 assertions, zero failures/errors/skips (seed 41651); RuboCop 127 files clean; gem/importmap audits clean; Brakeman zero errors/warnings. `RAILS_ENV=test bin/rails zeitwerk:check` passed application eager loading with the existing mail-preview exclusion. `git diff --check` passed.

## Implementation notes

Refreshed maintained summaries and documented the verified authentication/confirmation behaviour. Historical task specs, audit baseline and merge evidence remain intact. Added remediation links to the audit so baseline findings are not mistaken for outstanding implementation work. Status is Ready for review, not acceptance or merge; no new product decisions.

Verification used isolated local test records and deterministic fake providers. Local database/process/network checks required approved sandbox elevation. No live mail, live TMDB request, deployment, hosted CI, PR or merge occurred.

Owner acceptance / merge: Pending.

Publication authorization: On 20 October 2026, the owner requested a PR for online review. Acceptance and merge remain pending.
