---
name: rmz-update-skill
description: Update an existing repository GitHub Copilot CLI skill in rmz-ai-vm; use when a requested skill already exists.
---

# Update a repository Copilot skill

Use this skill only to update an existing custom skill for the rmz-ai-vm environment. Before making changes, check whether `.github/skills/<skill-name>/SKILL.md` exists for the requested skill. If it does not exist, do not create it here; hand off to the `rmz-create-skill` skill. If it exists, update it here.

## Source of truth and location

- The canonical copy of every repository skill is in this repository at `.github/skills/<skill-name>/SKILL.md`. Update that copy; do not edit only a copy inside a project or on another machine.
- Keep the skill directory and its `name` frontmatter value matching, concise, lowercase, and kebab-case.
- Preserve valid YAML frontmatter with a specific `description` that says what the skill does and when Copilot should use it.
- Keep supporting scripts and references inside the skill's directory, and update them only when needed for the requested change.

## Updating a useful skill

1. Read the existing skill and any directly relevant supporting files before editing.
2. Preserve the skill's intended trigger and scope unless the request explicitly changes them.
3. Make the smallest complete change that addresses the request, keeping instructions actionable and in the order they should be done.
4. Prefer repository conventions and existing tools. Do not duplicate instructions already provided by Copilot or the VM.
5. Do not add secrets, machine-specific credentials, or generated state.

## Validation

- Check that the directory name still matches its frontmatter `name`, that the YAML frontmatter parses, and that paths and commands in the instructions are accurate.
- The repository file is canonical; run `copilot-init` inside the VM to link it into `$HOME/.copilot/skills/<skill-name>`.
- Update the README if the skill storage convention changes.
