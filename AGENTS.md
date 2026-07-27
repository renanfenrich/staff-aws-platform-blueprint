# Agent operating rules

These rules apply to every automated or human-assisted change in this
repository.

## Before editing

1. Inspect `README.md`, `GOAL.md`, relevant files under `docs/`, and the current
   git status and branch.
2. Start from updated `develop` and use a dedicated Gitflow branch. Never commit
   directly to `main` or `develop`.
3. Define a small, reviewable slice and preserve existing security boundaries.

## While working

- Prefer standard-library and existing solutions. Justify every new dependency
  in the pull request.
- Pin tools, dependencies, images, and GitHub Actions. Never use `latest`.
- Never create, print, store, or expose credentials. Use GitHub OIDC for AWS.
- Do not run `terraform apply`, deploy, destroy, or mutate cloud resources
  unless the task explicitly authorizes that exact action.
- Stop for approval before an action could create material cost, weaken a
  security boundary, expose data, or broaden public access.
- Avoid destructive cloud operations. An authorized destroy must use the
  repository workflow, an exact environment, and an approved plan.
- Keep containers non-root and preserve read-only runtime filesystem support.
- Update architecture docs and ADRs whenever a decision or boundary changes.

## Before handoff

1. Run every available validation relevant to the change.
2. Review the full diff for scope, secrets, generated files, and unsafe defaults.
3. Report changed files, tests, risks, assumptions, and any blocked validation.
4. Use Conventional Commits and keep the pull request focused on one slice.

Repository context belongs in versioned files under `.codex/`, not in private
prompt assumptions.
