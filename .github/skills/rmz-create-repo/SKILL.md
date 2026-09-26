---
name: rmz-create-repo
description: Create a GitHub repository using the canonical rmz-ai-vm settings; use when asked to create or initialize a new repository.
---

# Create a GitHub repository

Use this workflow when creating a new project repository for the user. Match repository settings to `Ramzza/rmz-ai-vm`; do not rely on remembered defaults.

1. Confirm the repository name, owner, purpose, and whether the user requested a specific stack. Use an `rmz-` prefix when required by the user or their instructions. Check that the target repository does not already exist.
2. Read the reference repository's current settings before creating the new repository:
   - `gh api repos/Ramzza/rmz-ai-vm` for visibility, default branch, feature flags, and merge options.
   - `gh api repos/Ramzza/rmz-ai-vm/rulesets` and each ruleset's detail endpoint for branch policies.
   - `security_and_analysis` from the repository endpoint, plus `/vulnerability-alerts` and `/automated-security-fixes`.
   - The `LICENSE` file and its SPDX identifier, plus any directly relevant root-level setup files.
3. Create the repository with the reference visibility, license, and relevant feature settings. Use `gh repo create --license <SPDX>` when creating from a template; if initializing an empty repository, add the exact reference `LICENSE` text to the first pushed branch. For projects covered by the user's rmz repository convention, make it public unless the user explicitly directs otherwise.
4. Apply the reference security settings: secret scanning and push protection, Dependabot vulnerability alerts, and Dependabot security updates. Respect GitHub plan or repository eligibility limits; report any setting that cannot be enabled rather than implying it succeeded.
5. Recreate active rulesets that apply to the default branch. Preserve their rules and enforcement, adapting the ref condition to `~DEFAULT_BRANCH`; never copy the reference ruleset ID. Prefer rulesets if the reference uses them instead of legacy branch protection.
6. Ensure the repository includes the exact reference `LICENSE` text and set any package-manifest license field to the same SPDX identifier. Keep credentials, personal data, and spreadsheet or other project data out of the repository.
7. Clone or initialize the repository, create a feature branch from `origin/main`, implement the requested starter project, and add tests for code changes. Commit using Conventional Commits, push, and open a PR targeting the default branch. Use clear Markdown with real line breaks in the PR body and verify the rendered body.
8. Verify the resulting repository metadata, security settings, Dependabot alerts and updates, active default-branch rulesets, license file, pushed branch, and PR. Report unavailable settings or other differences explicitly.
