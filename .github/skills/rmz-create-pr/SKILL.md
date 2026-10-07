---
name: rmz-create-pr
description: Create or update GitHub pull requests with clear Markdown descriptions; use when opening a PR or revising its body.
---

# Create or update a pull request

Use this skill when creating a pull request or changing an existing pull request's description.

1. Check the current branch, target base branch, and whether a pull request already exists for the branch. Update an existing pull request instead of creating a duplicate.
2. Write a clear GitHub Markdown description with real line breaks. Use a body file with actual newlines and pass it with `--body-file`; do not put escaped `\n` sequences in the description.
3. Create or update the pull request with `gh pr create --base <base> --title "<title>" --body-file <path>` or `gh pr edit <number> --body-file <path>`.
4. After saving, retrieve the pull request with `gh pr view <number> --json title,body,url` and verify the title and stored body. Then inspect its rendered body on GitHub, confirming headings, lists, and line breaks display as intended; fix and recheck any formatting issues.
