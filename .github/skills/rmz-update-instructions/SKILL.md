---
name: rmz-update-instructions
description: Add concise, non-duplicative global Copilot instructions to rmz-ai-vm.
---

# Update global Copilot instructions

Use this skill to add a new general instruction to `.github/copilot-instructions.md`.

1. Read the current file and identify the requested instruction's intent.
2. Check for existing instructions with the same or substantially overlapping meaning. Do not add a duplicate; report that the guidance is already covered.
3. Add only genuinely new, broadly applicable guidance. Keep it concise, direct, and actionable; remove repetition and unnecessary explanation.
4. Review the complete file to ensure the addition is clear, non-duplicative, and consistent with the existing instructions.

The file is provisioned as `$HOME/.copilot/copilot-instructions.md` in the VM. Edit only the repository copy; reprovisioning is not needed for edits to the file's contents.
