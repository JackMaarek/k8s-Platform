# Kubernetes Manifests and Helm Charts

## Structure
- **helm/**: Reusable Helm charts for applications
- **manifests/**: Raw Kubernetes YAML files
- **namespaces/**: Namespace definitions with labels

## Local Development

### Start Minikube
```bash
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --kubernetes-version=v1.28.3 \
  --addons=metrics-server,ingress
```

### Apply Namespaces
```bash
kubectl apply -f namespaces/base-namespaces.yaml
```

### Install Helm Charts
```bash
# Install sample application
helm install sample-app helm/sample-app -n development

# Upgrade existing release
helm upgrade sample-app helm/sample-app -n development

# Uninstall
helm uninstall sample-app -n development
```

## Helm Chart Development

### Creating a New Chart
```bash
cd helm/
helm create my-new-app
```

### Testing Charts
```bash
# Lint the chart
helm lint helm/sample-app

# Dry-run installation
helm install sample-app helm/sample-app -n development --dry-run --debug

# Template rendering
helm template sample-app helm/sample-app
```

## Common Operations

### Check Cluster Status
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

### Namespace Operations
```bash
# List all namespaces
kubectl get namespaces

# View namespace details
kubectl describe namespace development

# Set default namespace
kubectl config set-context --current --namespace=development
```

### Pod Management
```bash
# View pods in namespace
kubectl get pods -n development

# View pod logs
kubectl logs -n development <pod-name>

# Execute command in pod
kubectl exec -it -n development <pod-name> -- /bin/sh

# View pod events
kubectl get events -n development --sort-by='.lastTimestamp'
```

## Troubleshooting

### Pod Issues
```bash
# Check pod status
kubectl get pods -n development

# Describe pod for events
kubectl describe pod -n development <pod-name>

# View logs
kubectl logs -n development <pod-name>

# Previous container logs (if crashed)
kubectl logs -n development <pod-name> --previous
```

### Service Issues
```bash
# List services
kubectl get svc -n development

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://service-name.development.svc.cluster.local
```

### Resource Issues
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n development

# View resource requests/limits
kubectl describe node minikube
```

### Helm Troubleshooting
```bash
# List releases
helm list -A

# Get release status
helm status sample-app -n development

# View release history
helm history sample-app -n development

# Rollback release
helm rollback sample-app 1 -n development
```

## Best Practices

1. **Always specify namespaces** to avoid accidental operations on default namespace
2. **Use resource requests and limits** for all workloads
3. **Implement readiness and liveness probes** for reliability
4. **Follow security best practices**: run as non-root, drop capabilities
5. **Use ConfigMaps and Secrets** instead of hardcoded values
6. **Implement pod anti-affinity** for high availability
7. **Label all resources** consistently for easy filtering

## Security Considerations

- All namespaces have `istio-injection: enabled` label for automatic sidecar injection
- Pod Security Standards should be enforced at namespace level
- Network policies complement Istio authorization policies
- Secrets should never be committed to Git

## References
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
