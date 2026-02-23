# Argo CD - GitOps Continuous Delivery

## Overview
Argo CD provides declarative, GitOps continuous delivery for Kubernetes applications.

## Architecture
- **Repository**: Git repo as single source of truth
- **Application**: Defines what to deploy and where
- **Sync**: Automatic or manual deployment from Git
- **Health**: Application health status tracking

## Installation

### Install Argo CD
```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Access Argo CD

#### CLI Access
```bash
# Install Argo CD CLI
brew install argocd  # macOS
# Or download from https://github.com/argoproj/argo-cd/releases

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Admin password: $ARGOCD_PASSWORD"

# Port forward to access
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure
```

#### Web UI Access
```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Change Admin Password
```bash
argocd account update-password
```

## Application Management

### Deploy Sample Application
```bash
kubectl apply -f applications/sample-app.yaml
```

### Using CLI
```bash
# Create application
argocd app create sample-app \
  --repo https://github.com/your-org/k8s-platform.git \
  --path kubernetes/helm/sample-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace development \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# List applications
argocd app list

# Get application details
argocd app get sample-app

# Sync application
argocd app sync sample-app

# View application logs
argocd app logs sample-app
```

## GitOps Workflow

### 1. Make Changes
```bash
# Edit Helm values or manifests
vim kubernetes/helm/sample-app/values.yaml

# Commit and push
git add .
git commit -m "Update replicas to 5"
git push origin main
```

### 2. Automatic Sync
Argo CD will:
1. Detect changes in Git
2. Compare with cluster state
3. Automatically sync if auto-sync enabled
4. Report health and sync status

### 3. Monitor Status
```bash
# Watch sync status
argocd app watch sample-app

# View sync history
argocd app history sample-app
```

## Sync Policies

### Automatic Sync
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Force sync when drift detected
```

### Manual Sync
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

### Sync Windows
Restrict syncs to specific times:
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
  syncWindows:
  - kind: allow
    schedule: '0 9 * * 1-5'  # Mon-Fri, 9 AM
    duration: 8h
    applications:
    - '*'
```

## Application Structure

### Basic Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-platform.git
    targetRevision: HEAD
    path: kubernetes/helm/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Helm Application
```yaml
spec:
  source:
    repoURL: https://github.com/your-org/k8s-platform.git
    targetRevision: HEAD
    path: kubernetes/helm/sample-app
    helm:
      valueFiles:
        - values.yaml
      parameters:
        - name: replicaCount
          value: "5"
```

### Multiple Sources (App of Apps Pattern)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-platform.git
    targetRevision: HEAD
    path: argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Projects

Create projects to organize applications:
```bash
# Create project
argocd proj create production \
  --description "Production applications" \
  --src https://github.com/your-org/k8s-platform.git \
  --dest https://kubernetes.default.svc,production \
  --allow-cluster-resource '*/*/*'

# List projects
argocd proj list

# Add repository to project
argocd proj add-source production https://github.com/your-org/k8s-platform.git
```

## RBAC and Security

### Create Read-Only User
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, logs, get, */*, allow
    g, readonly-user, role:readonly
```

### SSO Integration
Argo CD supports:
- OIDC (Okta, Google, etc.)
- SAML
- LDAP
- GitHub/GitLab

## Monitoring and Alerts

### Prometheus Metrics
Argo CD exposes metrics at:
```
http://argocd-metrics:8082/metrics
```

Key metrics:
- `argocd_app_sync_total`: Sync count
- `argocd_app_health_status`: Health status
- `argocd_app_sync_status`: Sync status

### Notifications
Configure notifications for sync events:
```bash
# Install notifications controller
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
```

## Troubleshooting

### Application Out of Sync
```bash
# View diff
argocd app diff sample-app

# Force sync
argocd app sync sample-app --force

# Refresh application
argocd app get sample-app --refresh
```

### Connection Issues
```bash
# Check repo credentials
argocd repo list

# Add/update repository
argocd repo add https://github.com/your-org/k8s-platform.git \
  --username your-username \
  --password your-token
```

### Performance Issues
```bash
# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Scale up controller
kubectl scale deployment argocd-application-controller -n argocd --replicas=2
```

### Sync Failures
```bash
# View application events
kubectl describe application sample-app -n argocd

# Check sync operation
argocd app get sample-app -o yaml

# View detailed logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

## Best Practices

1. **Use App of Apps Pattern** for managing multiple applications
2. **Enable Auto-Prune** to remove orphaned resources
3. **Enable Self-Heal** to maintain desired state
4. **Use Projects** to organize applications by team/environment
5. **Implement RBAC** for least privilege access
6. **Tag Git Commits** for production releases
7. **Use Sync Windows** for controlled deployment times
8. **Monitor Health Status** and set up alerts
9. **Regular Backups** of Argo CD configuration
10. **Pin Application Versions** in production

## Disaster Recovery

### Backup Argo CD
```bash
# Export all applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Backup namespace
kubectl get all,cm,secret -n argocd -o yaml > argocd-backup.yaml
```

### Restore Argo CD
```bash
# Restore namespace
kubectl apply -f argocd-backup.yaml

# Restore applications
kubectl apply -f argocd-apps-backup.yaml
```

## References
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://www.gitops.tech/)
