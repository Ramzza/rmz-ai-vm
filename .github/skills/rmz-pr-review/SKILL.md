---
name: rmz-pr-review
description: Review a newly created pull request by launching a code-review subagent; use immediately after opening any PR.
---

# Review a newly created pull request

Use immediately after creating a pull request. Launch the `code-review` subagent to review the PR's changes and return findings to the PR creator. This is separate from requesting a review from `copilot-pull-request-reviewer[bot]`.

## Inputs

Pass the PR URL (or repository and PR number), base/head branches, and any relevant task context to the subagent.

## Procedure

1. Identify the PR's base and head revisions and review the complete PR diff.
2. Launch the `code-review` subagent with the PR URL, repository context, base/head revisions, and relevant task context. Ask it to report only actionable, high-confidence bugs, logic errors, or design flaws introduced by the diff; include changed-file line references, impact, and confidence.
3. Return the subagent's findings to the PR creator. If it finds none, say so. Do not modify code or post a PR comment unless explicitly requested.

Report each finding with severity, file and line range, concise explanation of impact, and confidence (1–10). Do not report speculative issues or style-only preferences.
