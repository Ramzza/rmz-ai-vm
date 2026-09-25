---
name: rmz-clean-workspace
description: Update clean Git repositories in a workspace and remove local-only branches; use when asked to clean workspace repositories.
---

# Clean a workspace

Use this skill when asked to refresh repositories in a workspace and remove local branches that have no remote counterpart. Work only within the requested workspace.

1. Find Git repositories under the requested workspace. For each repository, inspect staged, unstaged, and untracked changes before taking action.
2. Treat a repository as clean when it has no staged or unstaged content changes, allowing only CRLF-versus-LF differences at line endings. Check staged and unstaged diffs with `git diff --cached --ignore-cr-at-eol --quiet` and `git diff --ignore-cr-at-eol --quiet`; any untracked files make it dirty. Do not stash, reset, or overwrite user changes. Skip dirty repositories and report why.
3. In each eligible repository, fetch and prune its remotes. Prefer `origin` as the primary remote; otherwise use the sole configured remote. Choose its default branch from the remote `HEAD`; if unavailable, use `main` or `master` only when exactly one exists remotely. If no unambiguous remote and branch can be identified, skip the repository and report why.
4. Check out that branch and fast-forward it only (`git pull --ff-only`). Do not merge or rebase local commits.
5. Compare local branch names against branch names on all fetched remotes. Delete only local branches with no remote counterpart, after switching off them; do not delete a branch checked out in another worktree. Since the user explicitly requested their removal, delete those exact branches even if they contain unmerged commits, and report the names.
6. Report updated repositories, skipped repositories, and deleted branches. Line-ending-only modifications may still appear in `git status`; leave them intact and explain that they were treated as clean.
