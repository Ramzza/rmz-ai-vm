Keep instructions concise, direct, and actionable. Avoid repetition and unnecessary explanation.
Always check whether an rmz-* skill can be used for a given task or step before proceeding.
Work on a feature or bugfix branch created from origin/main; when the task is finished, commit, push, and open a PR.
Use the `rmz-commit` skill when creating commits; it defines the required Conventional Commit format.
Every line of code must be covered by unit tests; add or update tests for any code change.
Every repository must have a concise root `PRD.md` as the single source of truth for business requirements; keep it current, assign stable IDs, and map every requirement to explicit unit or end-to-end tests.
Code must not contradict the PRD; tests must fail when a requirement is unmet.
Before implementing behavior changes, write the tests first and verify they fail against unchanged production code for the expected assertion; if behavior already exists, prove they fail under a controlled mutation. Use `rmz-test` and the appropriate language-specific testing skill.
Use TypeScript for new projects when practical and prefer type-safe, idiomatic TS over JavaScript.
Never return early from a function or exit a script early.
Never commit secrets or personal data; always work as if you are in a public repository.
Use the `rmz-create-pr` skill when creating or updating pull requests; it defines the required body formatting and rendered-body verification.
Use the `rmz-create-repo` skill when creating GitHub repositories; it documents the canonical repository settings.
Use `rmz-create-skill` for new repository skills and `rmz-update-skill` for existing skills.
