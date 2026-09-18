# P2 local application baseline

P2 provides a local React/Vite client and Node.js API backed by PostgreSQL. The
browser uses an HttpOnly, SameSite=Lax opaque-session cookie; PostgreSQL stores
only its SHA-256 digest. Passwords use Argon2id. Projects are always queried by
the authenticated owner, and task access is scoped through the owned project.

Copy `.env.example` to an untracked `.env` and replace its local password
placeholder. Then run `make setup`, `make db-up`, `make db-migrate`, `make run`,
and `npm --prefix frontend run dev`. `make setup` installs dependencies and
initializes Terraform only; it does not create or migrate the database. `make run`
loads `.env` for local development, while containers and production continue to
use their process environment.
Migrations in `db/migrations` are versioned, checksummed, transactional where
PostgreSQL permits, and are deliberately separate from application startup.
`/health` is process-only; `/ready` performs a bounded PostgreSQL `SELECT 1`.

This is local evidence only. P2 does not demonstrate ECS, RDS, Secrets Manager,
VPC endpoints, TLS origin, deployment, or AWS smoke tests. Terraform remains
unchanged and no AWS, Cloudflare, DNS, or state mutation is part of this slice.

## Dependency audit boundary

As of P2, `markdownlint-cli2@0.23.2` is the current upstream release but pulls
`smol-toml@1.7.0`, which has GHSA-7w5x-hrqm-74c2. The only npm-audit proposed
downgrade (`markdownlint-cli2@0.21.0`) replaces that finding with high-severity
`js-yaml` findings. P2 therefore preserves the current toolchain and does not
claim a green dependency audit until upstream provides a safe graph.
