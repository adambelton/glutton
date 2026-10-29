# Glutton implementation workflow

- Use the installed [TypeSafe skill](.agents/skills/typesafe-ai/SKILL.md) for TypeSafe/JEV questions, state design, API integration, debugging and evaluation in this project. Read its current guidance and relevant official documentation; preserve agreed experiment budgets and domain ownership.

Read `docs/implementation_plan.md`, the current task spec and relevant brief sections before implementing.

- Create a tightly scoped spec before every task, using `docs/task_template.md`. Define scope and scope restrictions, including constraints that prevent in-scope work from inflating. Put verification methods and actual evidence directly under the acceptance criteria.
- Every task has exactly one owning domain (or supporting area) and a small, independently verifiable outcome. Preserve domain ownership, including for UI/wiring: each domain owns its mutations, invariants and lifecycle. First review apparent cross-domain work for a wrong boundary or misplaced invariant. Do not mechanically create contracts/tasks to conceal coupling. Product-domain coordination uses durable asynchronous domain events, as authorized by the owner on 21 October 2026; see docs/domain_events.md. Agree event meaning, payload, ordering, delivery, duplicate/failure handling and retention before implementation. Implement and test publishers and subscribers in separate tasks owned by their respective domains. All domains may synchronously read the shared data, including through another domain’s models, scopes and read-only queries. Shared reads do not transfer ownership or require an event projection or a separate provider task. Changing another domain’s implementation or mutating its data requires its owning workflow and explicit task scope. Use the narrowly scoped Foundation delivery contract, not a generic workflow engine. Deferred AI processing retains its own domain rules.
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
- Models own their actions and action-permission rules. Transitions between model types are the exception: a transition service coordinates source and destination and executes the change; the source model knows which actions it supports without knowing sibling classes or STI persistence mechanics. Action-specific permissions such as `can_register?` or `can_watch?` are valid domain rules, not permission to infer a class or choose unrelated behaviour. Do not move ordinary model actions into services merely because they have permission rules.
- Controllers own HTTP parameter shape/format validation and response handling. Services own entity loading, existence/ownership/freshness checks and transaction coordination; models retain domain actions and permissions. Do not duplicate entity queries in controllers.
- Validate genuinely untrusted input at its boundary. Concrete-class or capability checks need an explicit reason, such as a real risk that external input does not fulfil the expected role; the burden of justification is on the check. Retain schema constraints and targeted failure handling that enforce actual invariants, rather than mechanically removing all references to types.
- Freshness is independent of class or role. Refresh/re-read objects when stale state could affect correctness, and lock where concurrent changes require it. An in-memory `persisted?` value does not prove that a row still exists. Use nil-safe behaviour checks where absence is expected; do not add redundant `presence` wrappers or treat freshness checks as permission to add class guards.

## Action outcomes and idempotency

- Do not assume user actions should be idempotent successes. Report when a requested transition did not occur, using the agreed domain failure. System workflows may explicitly provide idempotency at their own boundary when safe retry semantics require it; define which duplicate outcomes are handled and let unrelated failures propagate. Do not add silent success fallbacks to domain transitions merely to simplify future consumers.

## Testing conventions

- Test observable outcomes and agreed contracts, including meaningful failures and persistence invariants, rather than internal state details, whole attribute snapshots, incidental query structure or implementation-specific collaborator types. Apply the same role trust and behaviour ownership rules in tests as in application code. Do not invent a production API solely to make tests assert internal classifications. Direct schema tests are appropriate when verifying an explicit storage contract.

## User-facing content

- Put all new or changed application-authored user-facing text in Rails locale files (`config/locales/`), starting with English. This includes page titles, headings, labels, buttons, placeholders, accessibility text, notices, errors, validation messages, and email subjects/bodies. Use Rails `t`/`I18n.t` at runtime and symbolic Active Model validation errors; do not hard-code copy or cache translated strings in constants.
- Use named interpolation and locale pluralization rather than concatenating sentences. Share identical copy where appropriate, preserve HTML escaping, and check rendered content with missing-translation errors enabled in development/tests.
- Do not translate user-entered content. Developer-only logs/configuration diagnostics and static emergency pages that must work without Rails are exceptions; any text surfaced to users through the application must use locale entries.

## Event-handler organization

- Place production event reaction handlers under `ReceivingDomain::EventHandlers::PublishingDomain::EventName`, with matching Rails directories, for example `Ratings::EventHandlers::Library::FilmMarkedWatched`. The publishing namespace names the domain, not its models.
- Keep one ordered subscription for related event reactions whose order matters. An explicit mapping may dispatch to individual handlers; shared boundary validation/loading may remain in the subscription coordinator. Do not split subscriptions solely to match handler files.
- Use explicit top-level publisher constants when a nested publisher namespace would shadow them. Keep model actions and permissions in the receiving domain's models.

- Domain boundaries define ownership, not exclusive read access. LibraryFilm is Library-owned and RatingFilm/Rating are Ratings-owned; other domains may read these records while preserving user access controls. Do not duplicate authoritative state solely to avoid cross-domain reads. Event handlers still apply changes only to their receiving domain; use the event’s agreed meaning and payload for reactions. Name subscription entry points for the publishing domain (for example Ratings::ConsumeLibraryEvent and Library::ConsumeRatingsEvent).
