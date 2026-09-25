---
name: rmz-create-skill
description: Create a new reusable GitHub Copilot CLI skill in rmz-ai-vm; use when a requested skill does not already exist.
---

# Create a VM-provisioned Copilot skill

Use this skill only to create a new custom skill for the rmz-ai-vm environment. Before writing anything, check whether `.github/skills/<skill-name>/SKILL.md` already exists for the requested skill. If it exists, do not create or edit it; hand off to the `rmz-update-skill` skill. If it does not exist, create it here.

## Source of truth and location

- Store every VM-wide skill in this repository at `.github/skills/<skill-name>/SKILL.md`.
- Treat this repository as the source of truth. Do not create the only copy under `~/.copilot`, inside a project, or in another machine-local directory.
- Use a concise, lowercase, kebab-case directory and matching `name` frontmatter value.
- Include YAML frontmatter with a `name` and a specific `description`. The description should say what the skill does and when Copilot should use it.
- Add supporting scripts or references inside that skill's directory only when they materially help the skill perform its task. Keep instructions and resources versioned together.

## Writing a useful skill

1. Define a clear trigger and bounded task; avoid generic advice that belongs in the assistant's global instructions.
2. Write actionable steps in the order the task should be done. State required inputs, expected outputs, and important constraints.
3. Prefer repository conventions and existing tools. Do not duplicate instructions already provided by Copilot or the VM.
4. Keep the `SKILL.md` focused. Move substantial reference material into the skill directory and link to it from the skill instructions.
5. Do not put secrets, machine-specific credentials, or generated state in the skill.

## Provisioning and validation

- The VM provisioner discovers skill directories under `.github/skills` and links them into the `vagrant` user's `~/.copilot/skills`. Preserve this layout so the skill is globally available in the VM and is backed by the mounted, version-controlled repository.
- A newly added skill directory must be registered by running `vagrant provision` from the host in this repository; a Copilot session inside the VM cannot reprovision its own VM. If creating a skill from inside the VM, leave reprovisioning to the VM host/operator.
- Check that the skill directory name matches its frontmatter `name`, that the YAML frontmatter parses, and that paths and commands in the instructions are accurate.
- Update the VM README if the provisioning workflow or skill storage convention changes.
