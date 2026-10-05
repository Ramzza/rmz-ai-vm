---
name: rmz-update-agentsmd
description: Refresh an existing root AGENTS.md against current repository evidence; use when asked to update, actualize, or synchronize repository-wide agent instructions.
---

# Update a root AGENTS.md

Use this skill only when asked to update an existing root `AGENTS.md`. Update the target repository, not `rmz-ai-vm`, unless `rmz-ai-vm` is the requested target. Do not update nested instruction files or other repository files.

## Procedure

1. Resolve the target repository from the user's path or the current working directory when it is clearly the target. If the target is ambiguous, ask which repository to use.
2. Confirm the repository root and check for its root `AGENTS.md`. If the file does not exist, do not create it here; hand off to `rmz-create-agentsmd`.
3. Read the existing `AGENTS.md` fully. Preserve accurate, useful guidance, including explicit user preferences and non-obvious lessons, unless the user asks to remove it or current evidence shows it is superseded or unsafe.
4. Inspect current repository evidence needed to verify and update the guidance:
   - `README.md`, contributor documentation, `PRD.md`, and `ARCHITECTURE.md` when present.
   - Top-level folders, manifests, scripts, CI workflows, test configuration, and documented verification commands.
   - Existing agent instructions, including nested `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.github/instructions/`, and `.cursor/rules/`.
   - Relevant implementation and documentation for architecture, abstractions, security, data handling, migrations, generated files, or deployment.
5. Compare every existing claim with the current evidence. Correct stale facts and commands, remove unsupported or contradictory claims, preserve still-valid guidance, and add missing repository-specific information. Do not guess; report unresolved conflicts rather than inventing precedence.
6. Rewrite the root file using exactly these headings, in this order:
   - `# AGENTS.md`
   - `## Project context`
   - `## Conventions`
   - `## Scripts`
   - `## Constraints`

   Keep all five headings. Use brief prose or bullets under Project context and concise bullets under the other sections. If a section has no useful, verified facts, write `- None identified.` Do not add other headings.
7. Keep the content focused and current:
   - In Project context, briefly explain what the project does, how its major parts fit together, and the responsibility of each top-level project folder in one concise line. Omit `.git`, dependency, cache, and generated-output folders unless agents need to work with them.
   - In Conventions, include evidenced language/runtime versions, linter and formatter rules, naming patterns, and established abstractions or interfaces agents should reuse.
   - In Scripts, list exact build and test commands verified against manifests, scripts, CI, or canonical docs; never guess.
   - In Constraints, state explicit do's and don'ts, non-obvious landmines, hard preferences, and verified restrictions. Describe natural-language rules as guidance; identify enforcement only when verified.
   - Include only stable, actionable facts documented in the repository or explicitly provided by the user. Prefer links to canonical documentation over duplicating it, and keep package-specific rules out of the root file.
8. Keep the updated file below 200 lines (maximum 199, including blank lines). Shorten it if needed without removing required, verified guidance.
9. Write only `<repository-root>/AGENTS.md`. Review its accuracy, required headings and order, folder map, exact commands, and line count. Report what changed, the evidence reviewed, any unresolved conflicts, and any suggestions for nested instruction files without creating them.
