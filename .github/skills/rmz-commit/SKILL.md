---
name: rmz-commit
description: Create Conventional Commit messages for repository changes; use when preparing or making a Git commit.
---

# Create a Conventional Commit

Use this skill when preparing a Git commit.

1. Review `git status --short` and the staged diff to confirm the commit contains only intended changes.
2. Write the subject in the format `type(scope): imperative summary`. Choose a fitting type such as `feat`, `fix`, `docs`, `refactor`, `test`, or `chore`, and use a scope that identifies the affected area.
3. Keep the summary concise and imperative, for example: `fix(auth): reject expired tokens`.
