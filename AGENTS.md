# Glutton implementation workflow

Read `docs/implementation_plan.md`, the current task spec and relevant brief sections before implementing.

- Create a tightly scoped spec before every task, using `docs/task_template.md`. Define scope and scope restrictions, including constraints that prevent in-scope work from inflating. Put verification methods and actual evidence directly under the acceptance criteria.
- Every task has exactly one owning domain (or supporting area) and a small, independently verifiable outcome. Do not cross domain boundaries, including for UI/wiring. First review apparent cross-domain work for a wrong boundary or misplaced invariant. Do not mechanically create contracts/tasks to conceal coupling. Agree explicit synchronous contracts, including inputs/results/failures, before implementing them. Implement and test the provider and consumer in separate tasks owned by their respective domains. Calls to established contracts are allowed; changing the other domain is not. Do not introduce asynchronous domain communication or a generic integration layer. Deferred AI processing is a separate concern.
- Keep work within the spec. Update it before materially changing scope; split unrelated work into another task.
- After implementation, record what changed and verification evidence: the checks actually run and their results, plus deviations or limitations. Include reproducible commands/manual steps. Never imply unrun checks passed.
- Mark completed work `Ready for review` and update the plan. Owner acceptance and actual merge are separate; do not self-approve or merge automatically.
- Writing a spec alone does not start implementation or authorise external communication, paid services or deployment.
- Prefer simple Rails designs justified by current behaviour. Preserve unrelated files, including `.obsidian/`, and do not overwrite project documents during generation.

## Object roles and behaviour

- Treat every object as a role. Name variables and arguments for the role the operation actually requires, at the appropriate specificity: a concrete class, a superclass, or behaviour shared through a module. Use `library_film` for film-specific work; use `library_content` when an implemented role spans library films and television shows. Do not invent broader roles or modules before concrete behaviour requires them.
- Always trust a declared role unless there is a specific, documented reason not to. An internal argument named `user` is assumed to fulfil that role; do not redundantly guard it with `is_a?`, `instance_of?`, `kind_of?` or `respond_to?`. If an input is genuinely uncertain, express that uncertainty in its name and prefer validation of the behaviour actually required.
- Be skeptical of class awareness, including class/type switches and disguised equivalents such as `registered?` when callers use them to select behaviour. Merely hiding a class test behind a predicate or capability flag does not fix misplaced behaviour.
- Methods should describe and perform behaviour, not identify a classification from which callers infer behaviour. Rules about what an object can or cannot do belong inside that object. Callers delegate operations; workflow orchestration coordinates collaborators without rediscovering their class-specific rules. Meaningful domain-state predicates such as `active?` remain appropriate; do not replace a type switch with a differently named type switch.
- Validate genuinely untrusted input at its boundary. Concrete-class or capability checks need an explicit reason, such as a real risk that external input does not fulfil the expected role; the burden of justification is on the check. Retain schema constraints and targeted failure handling that enforce actual invariants, rather than mechanically removing all references to types.
- Freshness is independent of class or role. Refresh/re-read objects when stale state could affect correctness, and lock where concurrent changes require it. An in-memory `persisted?` value does not prove that a row still exists. Use nil-safe behaviour checks where absence is expected; do not add redundant `presence` wrappers or treat freshness checks as permission to add class guards.

## Testing conventions

- Test observable outcomes and agreed contracts, including meaningful failures and persistence invariants, rather than internal state details, whole attribute snapshots, incidental query structure or implementation-specific collaborator types. Apply the same role trust and behaviour ownership rules in tests as in application code. Do not invent a production API solely to make tests assert internal classifications. Direct schema tests are appropriate when verifying an explicit storage contract.

## User-facing content

- Put all new or changed application-authored user-facing text in Rails locale files (`config/locales/`), starting with English. This includes page titles, headings, labels, buttons, placeholders, accessibility text, notices, errors, validation messages, and email subjects/bodies. Use Rails `t`/`I18n.t` at runtime and symbolic Active Model validation errors; do not hard-code copy or cache translated strings in constants.
- Use named interpolation and locale pluralization rather than concatenating sentences. Share identical copy where appropriate, preserve HTML escaping, and check rendered content with missing-translation errors enabled in development/tests.
- Do not translate user-entered content. Developer-only logs/configuration diagnostics and static emergency pages that must work without Rails are exceptions; any text surfaced to users through the application must use locale entries.
