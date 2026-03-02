# Secrets

Secrets are managed by **External Secrets Operator (ESO)** backed by **AWS Secrets Manager**.

## Architecture

```
AWS Secrets Manager  ←  source of truth
      ↓
ClusterSecretStore (aws-secrets-manager)
      ↓
ExternalSecret CRD  →  Kubernetes Secret (native)
      ↓
Pod (envFrom / volumeMount)
```

## Adding a secret

1. Push the secret to AWS SM:
```bash
platform-bot secret add --name <app-name>/<key> --value <value>
```

2. The bot generates an ExternalSecret CRD in `kubernetes/secrets/<namespace>/<name>.yaml`
3. ArgoCD syncs → ESO creates the native Kubernetes Secret

## Structure

```
kubernetes/secrets/
  secret-store.yaml              ← ClusterSecretStore (AWS SM backend)
  argocd/                        ← ArgoCD repo credentials
  development/                   ← app secrets (dev namespace)
  monitoring/                    ← Grafana, Prometheus credentials
  README.md
```

## IAM

ESO uses IRSA (IAM Role for Service Accounts) — no static credentials.
The IAM role is provisioned by Terraform in `terraform/modules/eks/`.
Role ARN is injected by `platform-bot new-cluster` via `__ESO_IRSA_ROLE_ARN__` placeholder.