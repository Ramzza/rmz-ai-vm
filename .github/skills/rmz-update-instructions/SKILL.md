---
name: rmz-update-instructions
description: Add concise, non-duplicative repository Copilot instructions to rmz-ai-vm.
---

# Update repository Copilot instructions

Use this skill to add a new general instruction to `.github/copilot-instructions.md`.

1. Read the current file and identify the requested instruction's intent.
2. Check for existing instructions with the same or substantially overlapping meaning. Do not add a duplicate; report that the guidance is already covered.
3. Add only genuinely new, broadly applicable guidance. Keep it concise, direct, and actionable; remove repetition and unnecessary explanation.
4. Review the complete file to ensure the addition is clear, non-duplicative, and consistent with the existing instructions.
5. Put the change on a feature branch based on `origin/main`. Commit only files changed for this request using a Conventional Commit, push the branch, and open a PR or update the existing PR for that branch.

The repository file is canonical; run `copilot-init` inside the VM to link it into `$HOME/.copilot/copilot-instructions.md`.
