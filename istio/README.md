# Istio Service Mesh

## Overview
Istio provides advanced traffic management, security, and observability for microservices.

## Architecture
- **Control Plane**: istiod manages configuration and certificate issuance
- **Data Plane**: Envoy sidecars handle traffic and enforce policies
- **Security**: mTLS encryption and authorization policies
- **Traffic Management**: VirtualServices and DestinationRules

## Installation

### Prerequisites
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH
```

### Install Istio
```bash
# Install with default profile
istioctl install --set profile=default -y

# Verify installation
kubectl get pods -n istio-system
istioctl verify-install
```

### Enable Sidecar Injection
```bash
# Label namespaces for automatic injection
kubectl label namespace development istio-injection=enabled
kubectl label namespace staging istio-injection=enabled
kubectl label namespace production istio-injection=enabled

# Verify labels
kubectl get namespace -L istio-injection
```

## Security Configuration

### Strict mTLS
Apply PeerAuthentication to enforce mutual TLS:
```bash
kubectl apply -f security/peer-authentication-strict.yaml
```

This enforces mTLS in STRICT mode across all workloads.

### Authorization Policies
Apply zero-trust authorization:
```bash
kubectl apply -f security/authorization-policy.yaml
```

The policies implement:
- Deny-all-by-default
- Explicit allow rules per service
- Namespace isolation
- Ingress gateway permissions

### Verify mTLS
```bash
# Check mTLS status
istioctl authn tls-check

# View policy status
kubectl get peerauthentication -A
kubectl get authorizationpolicy -A
```

## Traffic Management

### Virtual Services
```bash
kubectl apply -f traffic/virtual-service.yaml
```

Features:
- Header-based routing
- Weighted traffic splitting
- Fault injection
- Request timeouts

### Destination Rules
```bash
kubectl apply -f traffic/destination-rule.yaml
```

Features:
- Connection pool settings
- Circuit breaking
- Load balancing
- Subset definitions

## Observability

### Kiali Dashboard
```bash
# Install Kiali (optional)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Access dashboard
istioctl dashboard kiali
```

### Prometheus Metrics
```bash
# Install Prometheus (optional)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
```

### Jaeger Tracing
```bash
# Install Jaeger (optional)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# Access dashboard
istioctl dashboard jaeger
```

## Common Operations

### Analyze Configuration
```bash
# Check for configuration issues
istioctl analyze -A

# Validate specific namespace
istioctl analyze -n development
```

### Debug Sidecar Injection
```bash
# Check if namespace has injection enabled
kubectl get namespace development -o jsonpath='{.metadata.labels}'

# Verify sidecar in pod
kubectl get pod -n development <pod-name> -o jsonpath='{.spec.containers[*].name}'

# Should show both app container and istio-proxy
```

### View Envoy Configuration
```bash
# Get proxy configuration
istioctl proxy-config all <pod-name>.<namespace>

# View specific config
istioctl proxy-config routes <pod-name>.<namespace>
istioctl proxy-config clusters <pod-name>.<namespace>
```

## Security Best Practices

1. **Always use STRICT mTLS** in production
2. **Implement deny-all-by-default** authorization
3. **Use namespace isolation** for multi-tenant environments
4. **Limit ingress gateway permissions** to only required services
5. **Regularly rotate certificates** (automatic with Istio CA)
6. **Monitor authorization denials** in metrics

## Troubleshooting

### Sidecar Not Injected
```bash
# Check namespace label
kubectl get namespace development -o yaml | grep istio-injection

# Restart deployment
kubectl rollout restart deployment -n development <deployment>
```

### Connection Refused Errors
```bash
# Check PeerAuthentication
kubectl get peerauthentication -A

# Check AuthorizationPolicy
kubectl get authorizationpolicy -n development

# View denied requests in logs
kubectl logs -n development <pod> -c istio-proxy | grep RBAC
```

### Performance Issues
```bash
# Check resource usage
kubectl top pods -n istio-system

# View proxy stats
istioctl proxy-status

# Check for config sync issues
istioctl proxy-config endpoints <pod>.<namespace>
```

### Certificate Issues
```bash
# Check certificate validity
istioctl proxy-config secret <pod>.<namespace>

# Force certificate rotation
kubectl delete secret istio-ca-secret -n istio-system
```

## Upgrading Istio

```bash
# Download new version
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.0 sh -

# Check upgrade compatibility
istioctl x precheck

# Perform upgrade
istioctl upgrade

# Verify upgrade
istioctl version
```

## Configuration Files Structure

```
istio/
├── base/
│   └── Installation configs
├── security/
│   ├── peer-authentication-strict.yaml
│   └── authorization-policy.yaml
└── traffic/
    ├── virtual-service.yaml
    └── destination-rule.yaml
```

## Performance Tuning

### Resource Limits
Adjust sidecar resources based on traffic:
```yaml
# In deployment annotations
sidecar.istio.io/proxyCPU: "100m"
sidecar.istio.io/proxyMemory: "128Mi"
sidecar.istio.io/proxyCPULimit: "500m"
sidecar.istio.io/proxyMemoryLimit: "512Mi"
```

### Concurrency
Adjust based on load:
```yaml
# In IstioOperator
spec:
  meshConfig:
    defaultConfig:
      concurrency: 2
```

## References
- [Istio Documentation](https://istio.io/latest/docs/)
- [Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
