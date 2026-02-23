# Monitoring and Logging Stack

## Overview
Complete observability stack with Prometheus for metrics, Grafana for visualization, and Loki for log aggregation.

## Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Features**: Service discovery, alerting, time-series database
- **Port**: 9090

### Grafana
- **Purpose**: Metrics visualization and dashboards
- **Features**: Multi-datasource support, alerting, user management
- **Port**: 3000 (HTTP)

### Loki
- **Purpose**: Log aggregation system
- **Features**: Like Prometheus but for logs, label-based indexing
- **Port**: 3100

### Promtail
- **Purpose**: Log collection agent
- **Features**: Automatic Kubernetes pod discovery, log parsing

### AlertManager
- **Purpose**: Alert management and routing
- **Features**: Grouping, deduplication, silencing
- **Port**: 9093

## Installation

### Automated Installation
```bash
./scripts/install-monitoring.sh
```

This script will:
1. Create monitoring namespace
2. Add Helm repositories
3. Install Prometheus + Grafana stack
4. Install Loki stack for logging
5. Configure ServiceMonitors
6. Display access credentials

### Manual Installation

#### Prerequisites
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

#### Create Namespace
```bash
kubectl apply -f kubernetes/namespaces/monitoring-namespace.yaml
```

#### Install Prometheus Stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values kubernetes/helm/monitoring/prometheus-values.yaml
```

#### Install Loki Stack
```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --values kubernetes/helm/monitoring/loki-values.yaml
```

## Access Dashboards

### Grafana

**Get Admin Password:**
```bash
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

**Access UI:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Then visit: http://localhost:3000
- Username: `admin`
- Password: (from command above)

### Prometheus

**Access UI:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Then visit: http://localhost:9090

### AlertManager

**Access UI:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```
Then visit: http://localhost:9093

## Pre-configured Dashboards

Grafana comes with several pre-installed dashboards:

1. **Kubernetes Cluster (7249)**: Overall cluster health and resource usage
2. **Kubernetes Pods (6417)**: Pod-level metrics and health
3. **Istio Mesh (7639)**: Service mesh overview
4. **Istio Service (7636)**: Individual service metrics
5. **Istio Workload (7630)**: Workload-level service mesh metrics
6. **Node Exporter (1860)**: Detailed node metrics

### Accessing Dashboards
1. Login to Grafana
2. Click "Dashboards" → "Browse"
3. Select any dashboard from the list

## Configuration

### Prometheus Configuration

The Prometheus stack is configured via `kubernetes/helm/monitoring/prometheus-values.yaml`:

**Key Settings:**
- **Retention**: 7 days
- **Storage**: 20Gi persistent volume
- **Scrape Interval**: 30 seconds
- **Evaluation Interval**: 30 seconds

**Istio Integration:**
- Automatic discovery of Istio telemetry endpoints
- Envoy proxy metrics collection
- Service mesh observability

### Loki Configuration

Loki is configured via `kubernetes/helm/monitoring/loki-values.yaml`:

**Key Settings:**
- **Retention**: 7 days (168h)
- **Storage**: 20Gi persistent volume
- **Log Limits**: 5000 entries per query

**Promtail Configuration:**
- Automatic Kubernetes pod log collection
- Label extraction from pod metadata
- CRI log format parsing

### Grafana Configuration

**Datasources:**
- Prometheus (pre-configured, default)
- Loki (pre-configured)

**Storage:**
- Dashboards: Persistent (10Gi)
- Settings: Persistent

## Monitoring Your Applications

### Add Metrics to Your Application

1. **Expose Metrics Endpoint**
   Your application should expose metrics at `/metrics` endpoint in Prometheus format.

2. **Add Prometheus Annotations** (for basic scraping)
   ```yaml
   annotations:
     prometheus.io/scrape: "true"
     prometheus.io/port: "8080"
     prometheus.io/path: "/metrics"
   ```

3. **Create ServiceMonitor** (recommended)
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: my-app
     namespace: development
   spec:
     selector:
       matchLabels:
         app: my-app
     endpoints:
     - port: http
       interval: 30s
       path: /metrics
   ```

### Example: Sample App ServiceMonitor

```bash
kubectl apply -f kubernetes/manifests/sample-app-servicemonitor.yaml
```

## Querying Metrics

### Common PromQL Queries

**CPU Usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="development"}[5m])
```

**Memory Usage:**
```promql
container_memory_usage_bytes{namespace="development"}
```

**Request Rate:**
```promql
rate(http_requests_total[5m])
```

**Error Rate:**
```promql
rate(http_requests_total{status=~"5.."}[5m])
```

**Pod Count:**
```promql
count(kube_pod_info{namespace="development"})
```

**Istio Request Duration:**
```promql
histogram_quantile(0.95, 
  rate(istio_request_duration_milliseconds_bucket[5m])
)
```

## Querying Logs with Loki

### LogQL Examples

**All logs from namespace:**
```logql
{namespace="development"}
```

**Logs from specific pod:**
```logql
{namespace="development", pod="sample-app-xxxxx"}
```

**Filter by log level:**
```logql
{namespace="development"} |= "ERROR"
```

**Count errors per minute:**
```logql
sum(rate({namespace="development"} |= "ERROR" [1m])) by (pod)
```

**Parse JSON logs:**
```logql
{namespace="development"} | json | level="error"
```

## Alerting

### AlertManager Configuration

Edit AlertManager configuration:
```bash
kubectl edit secret alertmanager-prometheus-kube-prometheus-alertmanager -n monitoring
```

**Example Slack Configuration:**
```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  receiver: 'slack-notifications'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#alerts'
    title: 'Kubernetes Alert'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Creating Custom Alerts

**PrometheusRule Example:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} requests/sec"
    
    - alert: PodDown
      expr: up{job="kubernetes-pods"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is down"
        description: "{{ $labels.pod }} in {{ $labels.namespace }} is down"
```

Apply the rule:
```bash
kubectl apply -f my-prometheus-rules.yaml
```

## Creating Custom Dashboards

### Using Grafana UI

1. Login to Grafana
2. Click "+" → "Dashboard"
3. Click "Add new panel"
4. Enter PromQL query
5. Configure visualization
6. Save dashboard

### Import Dashboard from JSON

1. Click "+" → "Import"
2. Upload JSON file or paste JSON
3. Select Prometheus datasource
4. Click "Import"

### Dashboard as Code

Save dashboards as ConfigMaps:
```bash
kubectl create configmap my-dashboard \
  --from-file=dashboard.json \
  --namespace monitoring \
  -o yaml --dry-run=client > my-dashboard.yaml
```

Add label:
```yaml
labels:
  grafana_dashboard: "1"
```

Apply:
```bash
kubectl apply -f my-dashboard.yaml
```

## Storage and Retention

### Prometheus Storage

**Current Configuration:**
- **Size**: 20Gi PVC
- **Retention Time**: 7 days
- **Retention Size**: 10GB

**To modify:**
Edit `prometheus-values.yaml` and upgrade Helm release:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kubernetes/helm/monitoring/prometheus-values.yaml
```

### Loki Storage

**Current Configuration:**
- **Size**: 20Gi PVC
- **Retention**: 7 days (168h)

**To modify:**
Edit `loki-values.yaml` and upgrade:
```bash
helm upgrade loki grafana/loki-stack \
  -n monitoring \
  -f kubernetes/helm/monitoring/loki-values.yaml
```

### Grafana Storage

Dashboards and configuration are stored in a 10Gi PVC.

## Monitoring Istio Service Mesh

### Istio Metrics

Prometheus automatically scrapes Istio components:
- Control plane (istiod)
- Envoy sidecars
- Ingress/egress gateways

**Key Istio Metrics:**
- `istio_requests_total`: Total requests
- `istio_request_duration_milliseconds`: Request duration
- `istio_request_bytes`: Request size
- `istio_response_bytes`: Response size

### Istio Dashboards

Pre-installed dashboards:
1. **Mesh Dashboard (7639)**: Overview of all services
2. **Service Dashboard (7636)**: Per-service metrics
3. **Workload Dashboard (7630)**: Per-workload metrics

## Performance Tuning

### Reduce Metrics Cardinality

**Relabel Configs:**
```yaml
metric_relabel_configs:
- source_labels: [__name__]
  regex: '(high_cardinality_metric_.*)'
  action: drop
```

### Optimize Scrape Intervals

For low-change metrics:
```yaml
scrape_configs:
- job_name: 'slow-metrics'
  scrape_interval: 5m  # Instead of 30s
```

### Reduce Log Volume

**In Loki:**
```yaml
limits_config:
  max_entries_limit_per_query: 1000  # Reduce from 5000
```

**In Promtail:**
Filter out noisy logs:
```yaml
pipeline_stages:
- match:
    selector: '{job="kubernetes-pods"}'
    stages:
    - drop:
        expression: ".*health check.*"
```

## Troubleshooting

### Prometheus Issues

**No Data Appearing:**
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check ServiceMonitor
kubectl get servicemonitor -A
kubectl describe servicemonitor sample-app -n development
```

**High Memory Usage:**
```bash
# Check retention settings
kubectl get prometheus -n monitoring -o yaml | grep retention

# Reduce retention or increase storage
```

### Grafana Issues

**Can't Login:**
```bash
# Reset admin password
kubectl delete secret prometheus-grafana -n monitoring
kubectl rollout restart deployment prometheus-grafana -n monitoring
```

**Dashboards Not Loading:**
```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/prometheus-grafana

# Verify datasource
# Grafana UI → Configuration → Data Sources → Prometheus → Test
```

### Loki Issues

**No Logs Appearing:**
```bash
# Check Promtail pods
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail

# Verify Loki is receiving logs
kubectl logs -n monitoring -l app=loki
```

**Query Timeout:**
```bash
# Reduce time range or increase limits
# Edit loki ConfigMap and restart
```

## Security Considerations

### Network Policies

Restrict access to monitoring components:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-ingress
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - namespaceSelector:
        matchLabels:
          name: istio-system
```

### RBAC

Prometheus has RBAC configured by default.

**View ClusterRole:**
```bash
kubectl get clusterrole prometheus-kube-prometheus-prometheus -o yaml
```

### Authentication

**Enable Grafana OAuth:**
Edit `prometheus-values.yaml`:
```yaml
grafana:
  grafana.ini:
    server:
      root_url: https://grafana.example.com
    auth.google:
      enabled: true
      client_id: YOUR_CLIENT_ID
      client_secret: YOUR_CLIENT_SECRET
```

## Backup and Restore

### Backup Prometheus Data
```bash
# Snapshot PVC
kubectl get pvc -n monitoring
# Use your cloud provider's snapshot feature
```

### Backup Grafana Dashboards
```bash
# Export all dashboards
kubectl get configmap -n monitoring -l grafana_dashboard=1 -o yaml > grafana-dashboards-backup.yaml
```

### Restore
```bash
# Restore dashboards
kubectl apply -f grafana-dashboards-backup.yaml
```

## Cost Optimization

### Storage Costs
- Adjust retention periods based on needs
- Use cheaper storage classes for old data
- Consider object storage for long-term retention

### Compute Costs
- Right-size Prometheus/Grafana resources
- Use horizontal pod autoscaling for query load
- Consider federated Prometheus for multi-cluster

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
