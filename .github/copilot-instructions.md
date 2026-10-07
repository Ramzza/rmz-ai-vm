Keep instructions concise, direct, and actionable. Avoid repetition and unnecessary explanation.
Always check whether an rmz-* skill can be used for a given task or step before proceeding.
RMZ skills are distributed in the `rmz-ai-skills` plugin from `rmz-ai-marketplace`; run `copilot-init` to register the marketplace, then install the plugin with `copilot plugin install rmz-ai-skills@rmz-ai-marketplace`.
Work on a feature or bugfix branch created from origin/main; when the task is finished, commit, push, and open a PR.
Use Conventional Commits: `type(scope): imperative summary` (for example, `fix(auth): reject expired tokens`); choose a fitting type such as `feat`, `fix`, `docs`, `refactor`, `test`, or `chore`.
Every line of code must be covered by unit tests; add or update tests for any code change.
Every repository must have a concise root `PRD.md` as the single source of truth for business requirements; keep it current, assign stable IDs, and map every requirement to explicit unit or end-to-end tests.
Code must not contradict the PRD; tests must fail when a requirement is unmet.
Before implementing behavior changes, write the tests first and verify they fail against unchanged production code for the expected assertion; if behavior already exists, prove they fail under a controlled mutation. Use `rmz-test` and the appropriate language-specific testing skill.
Use TypeScript for new projects when practical and prefer type-safe, idiomatic TS over JavaScript.
Never return early from a function or exit a script early.
Never commit secrets or personal data; always work as if you are in a public repository.
Format every pull request description as clear GitHub Markdown, use real line breaks (not escaped `\n`), and verify the rendered body after creating or updating it.
When creating GitHub repositories, match the public visibility, MIT license, default-branch PR ruleset, secret scanning with push protection, and Dependabot security settings of `Ramzza/rmz-ai-vm`.
When creating or updating skills, prefer scripts for deterministic, repeatable work to reduce token use and improve reliability.
