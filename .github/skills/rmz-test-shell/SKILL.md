---
name: rmz-test-shell
description: Create and verify shell-script tests against PRD requirements; use for Bash, POSIX shell, and Bats changes.
---

# Testing shell behavior

1. Read the root `PRD.md` and identify the requirement IDs affected by the shell change. Include those IDs in Bats test names.
2. Follow the repository's existing test runner, especially Bats conventions. Use temporary directories and stub commands through `PATH` for external effects; do not run system provisioning or destructive commands against the host.
3. Test observable behavior: exit status, output, file contents, permissions, and preservation of existing data. Prefer executing scripts over searching their source; use source-contract checks only for declarative configuration that cannot be exercised safely.
4. Add tests before changing the shell implementation and verify the expected assertion fails against unchanged code. If the implementation already exists, use a disposable baseline or controlled temporary mutation; do not count shell syntax, missing-command, or fixture failures as a red test.
5. Run the focused Bats file, the repository's full Bats suite, and applicable `bash -n`, ShellCheck, and line-ending checks. Ensure the tests run in CI.
