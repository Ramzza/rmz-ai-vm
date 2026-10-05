---
name: rmz-create-agentsmd
description: Create a concise, repository-specific root AGENTS.md after inspecting the target repository; use when asked to add persistent coding-agent instructions.
---

# Create a root AGENTS.md

Use this skill only when the user asks to create a root `AGENTS.md` in a specified repository. Create the file in that repository, not in `rmz-ai-vm`, unless `rmz-ai-vm` is the requested target. Do not create nested instruction files as part of this task.

## Procedure

1. Resolve the target repository from the user's path or the current working directory when it is clearly the target. If the target is ambiguous, ask which repository to use.
2. Confirm the repository root. Check whether its root `AGENTS.md` already exists. If it does, do not replace it; inspect it and ask whether the user wants it updated instead.
3. Inspect only the repository material needed to establish accurate guidance:
   - `README.md`, contributor documentation, and `PRD.md` or `ARCHITECTURE.md` when present.
   - Top-level directories, package or build manifests, and their scripts.
   - CI workflows, test configuration, and documented verification commands.
   - Existing agent instructions, such as nested `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.github/instructions/`, and `.cursor/rules/`.
   - Database, security, generated-file, or deployment documentation when the repository uses those areas.
4. Draft concise, actionable instructions from repository evidence. Include only sections that materially help agents make correct decisions, such as project purpose, directory responsibilities, exact development and test commands, architecture boundaries, conventions not already enforced by tools, security and data handling, migration practices, generated files, and completion reporting.
5. Keep the root file focused on stable, repository-wide guidance:
   - Verify commands against manifests, scripts, CI, or canonical docs. Do not guess commands, structure, stack, or policies.
   - Reference canonical documentation rather than copying the README, PRD, or architecture docs. Where a PRD exists, point to it for requirements instead of duplicating them.
   - Check existing instructions for overlap and conflicts. Do not invent precedence rules; omit disputed guidance and report unresolved conflicts rather than editing other files.
   - Exclude temporary task requirements, vague advice, repeated formatter/linter settings, and large examples.
   - Describe natural-language rules as guidance, not as guarantees; identify CI, permissions, hooks, or other enforcement only when verified.
   - Keep package-specific rules out of the root file. Suggest nested files only when the repository has genuinely distinct local rules, and create them only if requested.
6. Create `<repository-root>/AGENTS.md` once the inspection supports a useful, accurate file. The user's request to create it is authorization to write the file; do not stop at a draft unless the user asked for a proposal.
7. Review the result against the repository evidence. Confirm it is at the root, concise, free of unsupported claims and contradictions, and that every listed command matches the repository. Report the file created, the main evidence used, validation performed, any unresolved conflicts, and any useful nested-file suggestions.

## Reference

Apply the guidance in [Best AGENTS.md Examples for Codex, Cursor, and AI Coding Agents in 2026](https://promptessor.com/blog/best-agentsmd-examples-for-codex-cursor-and-ai-coding-agents-in-2026): inspect before drafting; favor specific, verifiable guidance over generic rules; keep root instructions stable and concise; use exact commands and canonical references; use nested files only for real scope differences; and rely on technical controls for guarantees.
