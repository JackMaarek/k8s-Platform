# _core

Platform infrastructure foundation — owned by the platform team. Read-only for domain teams.

## Structure

```
_core/
  modules/    ← reusable single-responsibility modules
  shared/     ← cross-domain cluster foundation (VPC, EKS, IAM, compliance)
```

## Ownership

`_core` is maintained by the **platform-maintainers** group. PRs touching `_core` require review from at least one platform maintainer before merge.

Domain teams consume `_core` outputs via `terraform_remote_state` — they never modify `_core` directly.
