# Glutton implementation workflow

Read `docs/implementation_plan.md`, the current task spec and relevant brief sections before implementing.

- Create a tightly scoped spec before every task, using `docs/task_template.md`. Define scope and scope restrictions, including constraints that prevent in-scope work from inflating. Put verification methods and actual evidence directly under the acceptance criteria.
- Every task has exactly one owning domain (or supporting area) and a small, independently verifiable outcome. Do not cross domain boundaries, including for UI/wiring. First review apparent cross-domain work for a wrong boundary or misplaced invariant. Do not mechanically create contracts/tasks to conceal coupling. Agree explicit synchronous contracts, including inputs/results/failures, before implementing them. Implement and test the provider and consumer in separate tasks owned by their respective domains. Calls to established contracts are allowed; changing the other domain is not. Do not introduce asynchronous domain communication or a generic integration layer. Deferred AI processing is a separate concern.
- Keep work within the spec. Update it before materially changing scope; split unrelated work into another task.
- After implementation, record what changed and verification evidence: the checks actually run and their results, plus deviations or limitations. Include reproducible commands/manual steps. Never imply unrun checks passed.
- Mark completed work `Ready for review` and update the plan. Owner acceptance and actual merge are separate; do not self-approve or merge automatically.
- Writing a spec alone does not start implementation or authorise external communication, paid services or deployment.
- Prefer simple Rails designs justified by current behaviour. Preserve unrelated files, including `.obsidian/`, and do not overwrite project documents during generation.

## User-facing content

- Put all new or changed application-authored user-facing text in Rails locale files (`config/locales/`), starting with English. This includes page titles, headings, labels, buttons, placeholders, accessibility text, notices, errors, validation messages, and email subjects/bodies. Use Rails `t`/`I18n.t` at runtime and symbolic Active Model validation errors; do not hard-code copy or cache translated strings in constants.
- Use named interpolation and locale pluralization rather than concatenating sentences. Share identical copy where appropriate, preserve HTML escaping, and check rendered content with missing-translation errors enabled in development/tests.
- Do not translate user-entered content. Developer-only logs/configuration diagnostics and static emergency pages that must work without Rails are exceptions; any text surfaced to users through the application must use locale entries.
