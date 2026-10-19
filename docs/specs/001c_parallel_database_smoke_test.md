# 001c — Parallel test database smoke check

Status: Ready for review  
Owner: Foundation

## Goal

Keep the PostgreSQL isolation smoke test valid when Rails creates numbered worker databases. GitHub CI for task 006 exposed the existing fixed-name assumption.

## Scope

- Accept only `glutton_test` or a numbered Rails worker variant in the existing database-name assertion.

## Scope restrictions

- Test assertion only; no Identity changes, database configuration changes, test parallelism changes, workflow changes or dependency changes.
- Do not relax the assertion to accept development/production or arbitrary database names.

## Acceptance criteria

- **AC1:** The smoke check accepts the serial and worker database names while retaining PostgreSQL/connectivity checks.  
  Check: `PARALLEL_WORKERS=1 bin/rails test test/integration/scaffold_test.rb` and GitHub CI with its normal parallel Rails test execution.  
  Result: Passed — serial focused run: 3 tests / 13 assertions. [Hosted CI run 39293312855](https://github.com/adambelton/glutton/actions/runs/39293312855) passed with four workers: 59 tests / 498 assertions, no failures/errors/skips.
- **AC2:** Scope stays limited to the Foundation test and its documentation.  
  Check: Inspect diff and run `git diff --check`.  
  Result: Passed — diff contains only the Foundation smoke-test assertion, this spec and plan entry; `git diff --check` passed.

## Implementation notes

Initial hosted run 39292996704 failed only because actual `glutton_test_1` did not equal the hard-coded `glutton_test`. All style/security checks passed in that run. This follow-up belongs to Foundation and is recorded separately from Identity task 006.

Owner acceptance / merge: Pending.
