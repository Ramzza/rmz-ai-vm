---
name: rmz-create-repository
description: Create a GitHub repository matching the canonical rmz-ai-vm settings; use when asked to create a repository.
---

# Create a matching GitHub repository

Use this skill when creating a repository that should follow the `rmz-ai-vm` GitHub configuration. Treat that repository as the source of truth; do not rely on defaults from `gh repo create`.

1. Inspect the reference repository's visibility, default branch, repository options, merge methods, Actions permissions, security settings, default-branch rulesets, and `LICENSE`. Use GitHub CLI/API reads and record the actual values before creating the new repository.
2. Create the requested repository as public. Initialize its default branch as needed, then apply the reference's applicable repository options and merge settings.
3. Reproduce the reference default-branch ruleset, including its target, enforcement, rules, parameters, and bypass actors. Enable matching secret scanning, push protection, Dependabot alerts, and Dependabot security updates. Copy the reference license file exactly, including its copyright notice.
4. Initialize the requested starter project with a concise root `PRD.md` before implementation. Treat it as the single source of truth for business requirements, give every requirement a stable ID, and map each to explicit unit/E2E tests. Use `rmz-test` and its relevant language-specific skill to verify tests fail against unchanged code before implementing behavior. Add a GitHub Actions workflow that runs on pull requests to the default branch and pushes to it. Use the detected stack and lockfile for reproducible dependency installation; run its build and tests, plus existing lint and type checks.
5. Run the workflow, then require every mandatory build-and-test job (or one combined job that runs both) in the default-branch ruleset using each exact check name GitHub reports; include lint and type-check jobs when they are part of the gate. If a workflow check is not available to select yet, run it first, then update the default-branch ruleset with its exact check name. Preserve the reference rules and report any platform limitation that prevents enforcement.
6. Where the project and organization support Sonar, configure PR analysis and publish test coverage in the supported format. Make the Sonar quality gate and coverage checks stable PR checks that can be required by the default-branch ruleset; use the exact check names after they run. Do not invent coverage thresholds or commit tokens. If Sonar credentials, service access, or a project threshold are unavailable, leave build-and-test checks enforced and report what is needed to enable the additional gate.
7. Read the new repository's settings, rulesets, and workflow results back from GitHub and compare them with the reference. Verify the license file in the repository; GitHub's detected license metadata may take time to appear. If GitHub rejects or does not support a setting, report the exact difference instead of claiming parity.
8. Leave unrelated repository configuration unchanged and never put credentials or private data in the repository.
