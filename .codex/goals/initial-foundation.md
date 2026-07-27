# Initial foundation

Establish the smallest reviewable base that can safely support later AWS
resource work. The slice ends at local and pull-request validation. It must not
deploy infrastructure.

Definition of done:

- API behavior and shutdown path are testable.
- Container runs as non-root.
- Terraform validates and plans without AWS credentials.
- CI and security workflows are SHA-pinned and least-privileged.
- Target architecture and known gaps are explicit.
