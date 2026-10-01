---
name: rmz-create-skill
description: Create a new reusable GitHub Copilot CLI skill in rmz-ai-vm; use when a requested skill does not already exist.
---

# Create a repository Copilot skill

Use this skill only to create a new custom skill for the rmz-ai-vm environment. Before writing anything, check whether `.github/skills/<skill-name>/SKILL.md` already exists for the requested skill. If it exists, do not create or edit it; hand off to the `rmz-update-skill` skill. If it does not exist, create it here.

## Source of truth and location

- Store every repository skill at `.github/skills/<skill-name>/SKILL.md`.
- Treat this repository as the source of truth. Provisioning links repository skills into the guest user's `~/.copilot/skills`; do not create or maintain a separate machine-local copy.
- Use a concise, lowercase, kebab-case skill name beginning with `rmz-`; use it for both the directory and matching `name` frontmatter value.
- Include YAML frontmatter with a `name` and a specific `description`. The description should say what the skill does and when Copilot should use it.
- Add supporting scripts or references inside that skill's directory only when they materially help the skill perform its task. Keep instructions and resources versioned together.

## Writing a useful skill

1. Define a clear trigger and bounded task; avoid generic advice that belongs in the assistant's global instructions.
2. Write actionable steps in the order the task should be done. State required inputs, expected outputs, and important constraints.
3. Prefer repository conventions and existing tools. Do not duplicate instructions already provided by Copilot or the VM.
4. Keep the `SKILL.md` focused. Move substantial reference material into the skill directory and link to it from the skill instructions.
5. Do not put secrets, machine-specific credentials, or generated state in the skill.

## Validation

- Check that the skill directory name matches its frontmatter `name`, that the YAML frontmatter parses, and that paths and commands in the instructions are accurate.
- Provisioning links each repository skill into `~/.copilot/skills/<skill-name>` without overwriting an existing user-owned target.
