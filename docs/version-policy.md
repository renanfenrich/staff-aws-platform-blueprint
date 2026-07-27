# Version lifecycle policy

## Runtime

[Node.js `24.18.0`](https://nodejs.org/en/blog/release/v24.18.0) is the active
LTS selected at implementation start. The exact runtime is pinned in `.nvmrc`,
`package.json`, CI, and the container base image. Upgrade within the LTS line
promptly for security releases. Plan a major upgrade before the line enters
maintenance or end of life.

## Dependencies and tools

- npm dependencies use exact versions and a committed lockfile.
- Terraform CLI and providers use exact constraints and a committed provider
  lockfile.
- Container bases use immutable digests and never `latest`.
- GitHub Actions use full commit SHAs with readable release comments.
- Dependabot opens weekly updates against `develop` for npm, Docker, Terraform,
  and GitHub Actions.

Patch updates still pass the full quality and security gates. Major updates get
a dedicated branch with release-note and migration review.

## Review cadence

Dependabot runs weekly. Maintainers review runtime, Terraform, scanner, and
action support monthly and immediately after relevant security advisories.
Unsupported versions block a production promotion.
