# 040 — Install the TypeSafe skill for Codex

Status: Ready for review  
Owner: Foundation

## Goal

Install the user-requested TypeSafe agent skill using only the non-Claude `npx skills add` method, read it, and record that this project's TypeSafe/JEV work uses it. User authorized installation on 28 October 2026. Implementation plan and task template already read.

## Scope

- Inspect CLI installation options, install `typesafe-ai/skills` / `typesafe-ai` for Codex, and verify the installed SKILL.md and supporting resources.
- Read the installed skill and apply its relevant instructions to ongoing JEV work. Record a durable project instruction and installation evidence.

## Scope restrictions

- One installation method only; do not also use Claude marketplace/plugin commands or the skill-installer helper. Do not install unrelated skills/agents, change provider accounts/credentials, buy credits, run another model experiment or change application code.
- Preserve ongoing Film knowledge experiment artifacts and all unrelated files. Skill setup does not accept or merge research or authorize production changes.

## Acceptance criteria

- **AC1:** The TypeSafe skill is installed for Codex using the requested npx method.  
  Check: CLI result, installed path and source files.  
  Result: Passed. `npx --yes skills add typesafe-ai/skills --skill typesafe-ai --agent codex --yes` completed using the requested single npx method. Installed project-local `.agents/skills/typesafe-ai/SKILL.md` and MIT LICENSE; `skills-lock.json` records source `typesafe-ai/skills`. `npx --yes skills list --agent codex --json` confirms project scope and Codex registration. No Claude/plugin or helper-script installation method used.
- **AC2:** Installed guidance is read and project usage is recorded.  
  Check: inspect SKILL.md/supporting references relevant to current work; verify project instruction, local links and whitespace.  
  Result: Passed. Read installed SKILL.md and relevant current official TypeSafe index/citation-checking guidance. Added the project instruction in AGENTS.md. Applied guidance to the JEV result review: identify compound questions, preserve raw results and recommend atomic judgments rather than interpret confidence as correctness. Local links/skill manifest checks and `git diff --check` passed. No application runtime tests needed or run for skill installation.

## Implementation notes

Installed on 28 October 2026 for this project's Codex agent. Installed SKILL.md SHA-256 `d1513cb2e0f72f58c11ac004ce99fd828fce8668a741b6a274247201e57db724`; lock metadata `computedHash` is the CLI's package hash, a different quantity. Full skill text was read and applied in the ongoing investigation after the already authorized 12 JEV requests had completed. No model request was repeated because of the installation. The skill is available for discovery on the next turn; current work has already used its read guidance.

Owner acceptance / merge: Pending.
