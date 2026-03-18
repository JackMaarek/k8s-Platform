## What

<!-- Une phrase décrivant ce que ce PR fait. -->

## Why

<!-- Contexte : pourquoi ce changement est nécessaire. -->

## Changes

<!-- Liste des fichiers modifiés et leur raison d'être. -->

- `path/to/file` — reason

## Checklist

- [ ] Branch is based on latest `main` (`git log --oneline main..HEAD`)
- [ ] No env-specific values on `main`-bound files
  ```bash
  grep -r "env: dev\|eu-west-3\|k8s-platform-dev\|esoIrsaRoleArn: \"\"" argocd/ kubernetes/helm/
  ```
- [ ] No unreplaced placeholder in manifests (only allowed in ApplicationSet `elements:`)
  ```bash
  grep -r "__ENV__\|__CLUSTER_NAME__" kubernetes/manifests/ kubernetes/helm/
  ```
- [ ] Commit messages follow Conventional Commits (`type(scope): description`)
- [ ] No file exceeds 200 lines (`find . -name "*.yaml" -o -name "*.go" | xargs wc -l | sort -rn | head -20`)
- [ ] No secrets or credentials committed (`git diff main --name-only | xargs grep -l "password\|secret\|token\|key" 2>/dev/null`)
- [ ] ArgoCD wave order documented in comments if sync order matters
- [ ] SRP respected — one file, one responsibility

## Testing

<!-- Comment as-tu validé ce changement ? -->

- [ ] `kubectl apply --dry-run=server` on changed manifests
- [ ] ArgoCD sync validated on local cluster (Kind)
- [ ] No new CrashLoopBackOff or ImagePullBackOff after sync

## Notes for reviewer

<!-- Tout ce qui aide le reviewer à comprendre les choix techniques. -->
