Keep instructions concise, direct, and actionable. Avoid repetition and unnecessary explanation.
Always check whether an rmz-* skill can be used for a given task or step before proceeding.
Work on a feature or bugfix branch created from origin/main; when the task is finished, commit, push, and open a PR.
Use Conventional Commits: `type(scope): imperative summary` (for example, `fix(auth): reject expired tokens`); choose a fitting type such as `feat`, `fix`, `docs`, `refactor`, `test`, or `chore`.
Every line of code must be covered by unit tests; add or update tests for any code change.
Use TypeScript for new projects when practical and prefer type-safe, idiomatic TS over JavaScript.
Never commit secrets or personal data; always work as if you are in a public repository.
Format every pull request description as clear GitHub Markdown, use real line breaks (not escaped `\n`), and verify the rendered body after creating or updating it.
When creating GitHub repositories, match the public visibility, default-branch PR ruleset, secret scanning with push protection, and Dependabot security settings of `Ramzza/rmz-ai-vm`.
