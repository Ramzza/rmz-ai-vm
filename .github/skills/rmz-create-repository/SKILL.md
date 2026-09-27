---
name: rmz-create-repository
description: Create a GitHub repository matching the canonical rmz-ai-vm settings; use when asked to create a repository.
---

# Create a matching GitHub repository

Use this skill when creating a repository that should follow the `rmz-ai-vm` GitHub configuration. Treat that repository as the source of truth; do not rely on defaults from `gh repo create`.

1. Inspect the reference repository's visibility, default branch, repository options, merge methods, Actions permissions, security settings, default-branch rulesets, and `LICENSE`. Use GitHub CLI/API reads and record the actual values before creating the new repository.
2. Create the requested repository as public. Initialize its default branch as needed, then apply the reference's applicable repository options and merge settings.
3. Reproduce the reference default-branch ruleset, including its target, enforcement, rules, parameters, and bypass actors. Enable matching secret scanning, push protection, Dependabot alerts, and Dependabot security updates. Copy the reference license file exactly, including its copyright notice.
4. Read the new repository's settings and rulesets back from GitHub and compare them with the reference. Verify the license file in the repository; GitHub's detected license metadata may take time to appear. If GitHub rejects or does not support a setting, report the exact difference instead of claiming parity.
5. Leave unrelated repository configuration unchanged and never put credentials or private data in the repository.
