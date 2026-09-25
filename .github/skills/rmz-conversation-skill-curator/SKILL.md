---
name: rmz-conversation-skill-curator
description: Turn reusable workflows from a completed conversation into a focused Copilot skill, or improve a matching existing skill; use at the end of a conversation when it revealed durable guidance worth preserving.
---

# Curate a skill from a conversation

Use this skill at the end of a conversation, or when asked to preserve its reusable lessons as a skill. Work only from information available in the current conversation and the canonical VM skills repository.

1. Review the conversation for a repeatable task, decision process, or constraint that would help in future conversations. Ignore one-off facts, temporary state, and details that are already adequately covered.
2. If there is no clear, durable improvement, make no changes and briefly explain why.
3. Inspect `.github/skills/*/SKILL.md` in `rmz-ai-vm` for a skill with the same purpose. Prefer improving the closest skill over creating an overlapping one.
4. Before editing an existing skill, load and follow `rmz-update-skill`. Before creating a skill, load and follow `rmz-create-skill`; confirm the intended skill path does not already exist.
5. Distill only the reusable guidance: define its trigger and scope, then write concise, ordered, actionable steps. Keep the skill's name and directory aligned, preserve valid YAML frontmatter, and link supporting files only when needed.
6. Exclude secrets, personal or project-specific details, and unverified claims. Do not copy conversation text wholesale.
7. Validate the changed skill's frontmatter, name/path match, and referenced paths or commands. Report whether a skill was created, updated, or deliberately left unchanged.
