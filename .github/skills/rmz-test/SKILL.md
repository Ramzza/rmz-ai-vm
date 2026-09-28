---
name: rmz-test
description: Map tests to PRD requirements and verify tests detect missing behavior; use when adding tests or implementing PRD-backed behavior.
---

# Requirement-driven testing

Use this workflow when implementing business behavior, changing requirements, or adding/updating tests.

1. Read the root `PRD.md` before changing behavior. If it is missing, create a concise one from the confirmed product scope. Give each requirement a stable ID (for example, `PRD-001`) and an explicit unit/E2E test mapping under `Verification`.
2. Identify every affected requirement and choose unit tests for isolated logic or E2E tests for user-visible workflows and component integration. Keep the PRD current when acceptance criteria change.
3. Select and invoke the language-specific workflow: call `rmz-test-shell` for shell/Bats, `rmz-test-typescript` for TypeScript/JavaScript, and both for mixed changes. For other languages, use the repository's existing runner and follow the same red/green process.
4. Add or update tests before production behavior changes. Run the tests against unchanged production code and confirm they fail on the expected assertion; setup, syntax, or missing-tool failures do not count.
5. If implementation was changed first, use a disposable worktree with only test changes applied to the baseline, or a controlled temporary mutation, to prove the expected test fails without the behavior. Do not modify or discard the user's working-tree changes.
6. Implement the smallest change that satisfies the PRD. Never weaken a test or rewrite a requirement merely to make nonconforming code pass.
7. Run the focused tests, the repository's full test command, and applicable lint/type/build checks. Confirm every PRD requirement ID still maps to an executable test included in CI.
