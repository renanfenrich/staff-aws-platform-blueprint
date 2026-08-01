# Goal: protected bootstrap state migration

## Mode A status

The reviewed repository support for Phase 2 is prepared on the migration
branch. It keeps bootstrap state local by default, adds an explicit partial S3
backend and untracked backend configuration, and provides credential-free
static validation. No operational migration is approved or complete.

The separate publication-evidence documentation prerequisite is merged in
`develop` at the base commit used for this change.

## State-machine distinctions

- Backend migration support merged: not yet; this branch is under review.
- Migration approved: no.
- State actually migrated: no; bootstrap state remains local.
- Remote state verified: no.
- Native locking verified: no.
- Local plaintext state removed: no.

Mode B requires an independently reviewed and merged change, an exact approved
commit, a maintenance window, explicit `APPROVE_BOOTSTRAP_STATE_MIGRATION`, a
short-lived human AWS session, ignored variable/backend files, and an encrypted
recoverable backup. Mode A performs no AWS call, remote initialization, state
movement, apply, destroy, or lock-object operation.
