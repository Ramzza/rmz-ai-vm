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
7. Clone or initialize the repository and create a feature branch from `origin/main`. Before implementing the starter project, add a concise root `PRD.md` as the single source of truth for business requirements; give every requirement a stable ID and explicit unit/E2E test mapping. Use `rmz-test` and its relevant language-specific skill to verify tests fail against unchanged code before implementation. Add a GitHub Actions workflow that runs on pull requests to the default branch and pushes to it. Use the detected stack and lockfile for reproducible dependency installation; run the build and tests, plus existing lint and type checks.
8. Run the workflow, then require its successful build-and-test check in the default-branch ruleset using the exact name GitHub reports. Where the project and organization support Sonar, configure PR analysis and publish test coverage in the supported format. Require the provider's stable Sonar quality-gate check in the default-branch ruleset; treat coverage as gated by that quality gate unless an existing, separately emitted coverage check is available. Use exact check names after they run. Do not invent coverage thresholds or commit tokens. If Sonar credentials, service access, or a project threshold are unavailable, keep build-and-test checks enforced and report what is needed to enable the additional gate.
9. Commit using Conventional Commits, push, and open a PR targeting the default branch. Use clear Markdown with real line breaks in the PR body and verify the rendered body.
10. Verify the resulting repository metadata, security settings, Dependabot alerts and updates, CI workflow results, active default-branch rulesets with required CI checks, license file, pushed branch, and PR. Report unavailable settings or other differences explicitly.
