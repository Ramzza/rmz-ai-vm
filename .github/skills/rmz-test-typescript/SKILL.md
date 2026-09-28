---
name: rmz-test-typescript
description: Create and verify TypeScript or JavaScript tests against PRD requirements; use when changing TS/JS behavior or tests.
---

# Testing TypeScript and JavaScript behavior

1. Read the root `PRD.md` and identify the requirement IDs affected by the change. Include those IDs in test names or the repository's established test mapping.
2. Reuse the package manager, lockfile, and test runner already configured by the project. Do not add a testing dependency unless the project lacks a suitable runner and the task requires one.
3. Test observable behavior and edge cases: use unit tests for isolated logic and E2E tests for user-visible workflows or integration boundaries.
4. Write tests before changing production behavior and verify the expected assertion fails against unchanged code. If implementation was changed first or the behavior already exists, use a disposable baseline or controlled temporary mutation to prove the test detects the missing behavior; do not alter the user's working tree.
5. Run focused tests, the full project test command, and applicable type-check, lint, and build commands. Ensure the tests run in CI and every affected PRD requirement has explicit coverage.
