# ---
markmap:
  title: "Prometheus — Fundamentals & Installation"
  collapse: false
# ---

# 📊 PROMETHEUS TOÀN TẬP - PHẦN 1: NỀN TẢNG & CÀI ĐẶT

## Theory
- Prometheus is a pull-based time-series monitoring system with PromQL for queries; it stores metrics in a TSDB and integrates with Alertmanager and Grafana for visualization and alerting.

## Practice
- Install via binaries or `kube-prometheus-stack` Helm chart, configure `prometheus.yml` scrape targets and retention, and secure storage with PVCs and resource limits.

## 1. Prometheus Là Gì?

### 1.1 Kiến Trúc

```
┌─────────────────────────────────────────────┐
│              PROMETHEUS SERVER               │
│                                             │
│  ┌──────────┐    ┌──────────┐    ┌───────┐  │
│  │  Scraper │───▶│  TSDB    │───▶│ HTTP  │  │
│  │ (Pull)   │    │(Storage) │    │  API  │  │
│  └──────────┘    └──────────┘    └───────┘  │
│       │                               │     │
│  ┌──────────┐                   ┌───────┐   │
│  │  Service │                   │ Rules │   │
│  │Discovery │                   │/Alert │   │
│  └──────────┘                   └───────┘   │
└─────────────────────────────────────────────┘
       │ pull /metrics                │
       ▼                              ▼
  ┌─────────┐                  ┌──────────┐
  │Exporters│                  │AlertMgr  │
  │node,k8s │                  │Slack/PD  │
  └─────────┘                  └──────────┘
                                      │
                                 ┌────────┐
                                 │Grafana │
                                 └────────┘
```

#### Đặc điểm
- **Pull-based**: Prometheus tự đến pull metrics từ targets
- **Time Series DB**: Lưu metrics dạng `metric_name{labels} value timestamp`
- **PromQL**: Ngôn ngữ query mạnh mẽ
- **Azure Monitor**: Tích hợp với Azure Monitor & AKS

### 1.2 Metric Types

```
4 loại metric:

1. Counter   → Chỉ tăng (request count, errors)
   http_requests_total{method="GET"} 1234

2. Gauge     → Tăng/giảm (CPU %, memory, connections)
   node_memory_MemFree_bytes 2.5e+09

3. Histogram → Phân phối giá trị (latency buckets)
   http_request_duration_seconds_bucket{le="0.1"} 240
   http_request_duration_seconds_sum 48.0
   http_request_duration_seconds_count 300

4. Summary   → Quantiles (p50, p95, p99)
   rpc_duration_seconds{quantile="0.95"} 0.123
```


## 2. Cài Đặt

### 2.1 Cài Thủ Công Trên Linux / Azure VM

```bash
# ===== CÀI PROMETHEUS =====
PROM_VERSION="2.50.1"
cd /tmp

wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

# Di chuyển binaries
sudo mv prometheus /usr/local/bin/
sudo mv promtool   /usr/local/bin/

# Tạo thư mục
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mv prometheus.yml /etc/prometheus/
sudo mv consoles/      /etc/prometheus/
sudo mv console_libraries/ /etc/prometheus/

# Tạo user
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# ===== SYSTEMD SERVICE =====
sudo tee /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=10GB \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \
  --web.enable-admin-api
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus

# Truy cập: http://<server-ip>:9090
```

### 2.2 Cài Trên Kubernetes (Helm - Kube-Prometheus-Stack)

```bash
# ===== HELM CHART: kube-prometheus-stack =====
# Bao gồm: Prometheus + Grafana + AlertManager + Node Exporter + kube-state-metrics

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Tạo namespace
kubectl create namespace monitoring

# Cài với custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait
```

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: "10GB"
    
    # Storage (Azure Disk)
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: managed-premium
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    # Resources
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi
    
    # Service discovery: scrape toàn bộ namespace
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: managed-premium
          resources:
            requests:
              storage: 10Gi

grafana:
  adminPassword: "StrongPassword123!"
  
  persistence:
    enabled: true
    storageClassName: managed-premium
    size: 10Gi
  
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.company.com

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true
```

### 2.3 Prometheus Trên Azure (Azure Monitor + Managed Prometheus)

```bash
# Azure Managed Prometheus - không cần self-host!
# Tích hợp với AKS qua Azure Monitor workspace

# 1. Tạo Azure Monitor Workspace
az monitor account create \
  --name amw-myapp-prod \
  --resource-group rg-myapp-prod \
  --location southeastasia

# 2. Enable Managed Prometheus cho AKS
az aks update \
  --name aks-myapp-prod \
  --resource-group rg-myapp-prod \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod/providers/microsoft.monitor/accounts/amw-myapp-prod

# 3. Link với Grafana
az grafana update \
  --name grafana-myapp \
  --resource-group rg-myapp-prod \
  --data-links /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod/providers/microsoft.monitor/accounts/amw-myapp-prod

# Query bằng PromQL trong Azure Managed Grafana hoặc Azure Portal
```


## 3. Cấu Hình prometheus.yml

```yaml
# /etc/prometheus/prometheus.yml

global:
  scrape_interval:     15s   # Pull metrics mỗi 15 giây
  evaluation_interval: 15s   # Evaluate rules mỗi 15 giây
  scrape_timeout:      10s

  # Labels gắn vào mọi time series
  external_labels:
    cluster: 'aks-myapp-production'
    region:  'southeastasia'
    env:     'production'

# ===== ALERTMANAGER =====
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

# ===== RULES =====
rule_files:
  - "/etc/prometheus/rules/*.yml"

# ===== SCRAPE CONFIGS =====
scrape_configs:

  # Prometheus tự monitor chính nó
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (hardware metrics)
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - 'node1.internal:9100'
          - 'node2.internal:9100'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+).*'
        replacement: '${1}'

  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes Nodes
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Kubernetes Pods (có annotation prometheus.io/scrape: "true")
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  # ServiceMonitor (dùng với kube-prometheus-stack)
  - job_name: 'myapp-backend'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names: ['production']
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_app]
        action: keep
        regex: myapp-backend
```


## 4. PromQL Cơ Bản

### 4.1 Queries Thường Dùng

```promql
# ===== INSTANT QUERIES =====

# CPU usage (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage (%)
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage (%)
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# HTTP request rate (req/s)
rate(http_requests_total[5m])

# HTTP error rate (%)
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# ===== K8S QUERIES =====

# Pod restart count
increase(kube_pod_container_status_restarts_total[1h])

# Pod memory usage
container_memory_working_set_bytes{namespace="production", container!=""}

# Deployment replicas available vs desired
kube_deployment_status_replicas_available /
kube_deployment_spec_replicas

# Node CPU cores
kube_node_status_capacity{resource="cpu"}

# ===== AGGREGATIONS =====

# Tổng request theo service
sum by (service) (rate(http_requests_total[5m]))

# Max memory usage theo namespace
max by (namespace) (
  container_memory_working_set_bytes{container!=""}
)

# Top 5 services nhiều lỗi nhất
topk(5, sum by (service) (rate(http_requests_total{status=~"5.."}[5m])))
```

### 4.2 Alert Rules

```yaml
# /etc/prometheus/rules/alerts.yml
groups:
  - name: infrastructure
    interval: 30s
    rules:
      # CPU cao
      - alert: HighCPUUsage
        expr: |
          100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        labels:
          severity: warning
          team: infra
        annotations:
          summary: "High CPU on {{ $labels.instance }}"
          description: "CPU usage {{ $value | printf \"%.1f\" }}% > 85%"

      # Memory cao
      - alert: HighMemoryUsage
        expr: |
          (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High Memory on {{ $labels.instance }}"
          description: "Memory {{ $value | printf \"%.1f\" }}% > 90%"

      # Disk sắp đầy
      - alert: DiskSpaceLow
        expr: |
          (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Only {{ $value | printf \"%.1f\" }}% disk remaining"

  - name: application
    rules:
      # HTTP 5xx cao
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) /
          sum(rate(http_requests_total[5m])) by (service) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate for {{ $labels.service }}"
          description: "Error rate {{ $value | printf \"%.2f\" }}% > 5%"

      # Latency cao
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P95 latency for {{ $labels.service }}"
          description: "P95 latency {{ $value | printf \"%.3f\" }}s > 1s"

  - name: kubernetes
    rules:
      # Pod crash looping
      - alert: PodCrashLooping
        expr: |
          increase(kube_pod_container_status_restarts_total[15m]) > 3
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} crash looping"

      # Deployment không đủ replicas
      - alert: DeploymentReplicasMismatch
        expr: |
          kube_deployment_spec_replicas != kube_deployment_status_replicas_available
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch"
```


## 5. AlertManager Cấu Hình

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  receiver: 'default'
  group_by: ['alertname', 'cluster', 'service']
  group_wait:      30s
  group_interval:  5m
  repeat_interval: 4h

  routes:
    # Critical → PagerDuty + Slack
    - match:
        severity: critical
      receiver: critical-alerts
      repeat_interval: 1h

    # Warning → Slack only
    - match:
        severity: warning
      receiver: slack-warnings

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
        title: '{{ template "slack.title" . }}'
        text:  '{{ template "slack.text" . }}'

  - name: 'critical-alerts'
    pagerduty_configs:
      - service_key: '<PAGERDUTY_KEY>'
    slack_configs:
      - channel: '#alerts-critical'
        color: 'danger'

  - name: 'slack-warnings'
    slack_configs:
      - channel: '#alerts-warning'
        color: 'warning'

inhibit_rules:
  # Nếu có critical thì suppress warning cùng alertname
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'cluster']
```
