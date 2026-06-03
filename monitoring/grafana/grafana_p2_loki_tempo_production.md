# ---
markmap:
  title: "Grafana Stack — Loki, Tempo & Production"
  collapse: false
# ---

# 📈 GRAFANA TOÀN TẬP - PHẦN 2: LOKI, TEMPO & PRODUCTION

## Theory
- Loki aggregates logs with label-based indexing; Tempo stores distributed traces; correlating logs, metrics, and traces gives strong observability for production systems.

## Practice
- Deploy Loki+Promtail and Tempo via Helm, enable derived fields in Grafana for log-trace correlation, and design retention/compaction for cost-effective storage.

## 1. Loki - Log Aggregation

### 1.1 Loki Architecture

```
Ứng dụng / K8s Pods
       │
       ▼ (push logs)
  ┌─────────┐
  │ Promtail│  ← agent thu log
  │ (agent) │
  └────┬────┘
       │ HTTP
       ▼
  ┌─────────┐
  │  Loki   │  ← lưu trữ log
  │ Server  │
  └────┬────┘
       │
       ▼
  ┌─────────┐
  │ Grafana │  ← visualize
  └─────────┘
```

### 1.2 Cài Loki Stack (Helm)

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Cài Loki + Promtail
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.storageClassName=managed-premium \
  --set loki.persistence.size=50Gi \
  --set promtail.enabled=true
```

```yaml
# loki-values.yaml (production config)
loki:
  auth_enabled: false

  storage:
    type: azure
    azure:
      accountName: myapplogsstorage
      accountKey: <STORAGE_KEY>
      container: loki-chunks

  schema_config:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: azure
        schema: v12
        index:
          prefix: loki_index_
          period: 24h

  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 32
    ingestion_burst_size_mb: 64
    max_query_series: 10000

  ruler:
    storage:
      type: azure

  compactor:
    retention_enabled: true
    working_directory: /data/compactor
```

### 1.3 Promtail Config (K8s DaemonSet)

```yaml
# promtail-config.yaml
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push

  scrape_configs:
    # Thu log từ tất cả K8s pods
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
        - role: pod
      pipeline_stages:
        # Parse JSON logs
        - json:
            expressions:
              level:   level
              msg:     message
              traceId: trace_id
        # Set labels từ JSON fields
        - labels:
            level:
            traceId:
        # Drop debug logs (tiết kiệm storage)
        - match:
            selector: '{level="debug"}'
            action: drop
            drop_counter_reason: debug_log_dropped
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app]
          target_label: app
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_container_name]
          target_label: container
```

### 1.4 LogQL Queries

```logql
# ===== LOGQL CƠ BẢN =====

# Xem toàn bộ log của app trong namespace production
{namespace="production", app="myapp"}

# Filter theo level
{app="myapp"} |= "ERROR"
{app="myapp"} != "DEBUG"
{app="myapp"} |~ "error|warning"

# Parse JSON và filter
{app="myapp"} | json | level="error"

# Count errors theo thời gian (metric query)
sum(rate({app="myapp"} |= "ERROR" [5m])) by (pod)

# Top 10 lỗi phổ biến nhất
topk(10,
  sum by (msg) (
    count_over_time({app="myapp"} | json | level="error" [1h])
  )
)

# Latency từ log (nếu app log response time)
{app="myapp"} | json | duration > 1000

# Lọc theo trace ID
{namespace="production"} |= "trace_id" | json | trace_id="abc123"
```


## 2. Grafana Tempo (Distributed Tracing)

### 2.1 Cài Tempo

```bash
helm install tempo grafana/tempo \
  --namespace monitoring \
  --set storage.trace.backend=azure \
  --set storage.trace.azure.storage_account_name=myapptracestorage \
  --set storage.trace.azure.storage_account_key=<KEY> \
  --set storage.trace.azure.container_name=tempo-traces
```

### 2.2 OpenTelemetry Integration (ứng dụng)

```python
# Python - tích hợp OpenTelemetry gửi traces tới Tempo
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Setup tracer
resource = Resource(attributes={
    SERVICE_NAME: "myapp-backend",
    "environment": "production",
})

provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(
    endpoint="http://tempo:4317",
    insecure=True
)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(provider)

# Auto-instrument FastAPI
FastAPIInstrumentor().instrument()
RequestsInstrumentor().instrument()

tracer = trace.get_tracer(__name__)

@app.get("/api/users/{user_id}")
async def get_user(user_id: str):
    with tracer.start_as_current_span("get-user") as span:
        span.set_attribute("user.id", user_id)
        # ...
```

### 2.3 Correlation: Logs → Traces

```yaml
# Trong Grafana data source Loki config:
# Derived Fields để link log → trace

jsonData:
  derivedFields:
    - name: TraceID
      matcherRegex: '"trace_id":"(\w+)"'
      url: '$${__value.raw}'
      datasourceUid: tempo    # Tự động link sang Tempo
      urlDisplayLabel: "View Trace"
```


## 3. Production Best Practices

### 3.1 High Availability Grafana

```yaml
# grafana-ha-values.yaml
replicas: 2

# Database backend (thay vì SQLite mặc định)
grafana.ini:
  database:
    type: postgres
    host: psql-monitoring.postgres.database.azure.com:5432
    name: grafana
    user: grafana_user
    password: ${GF_DATABASE_PASSWORD}
    ssl_mode: require

  # Session lưu trong Redis (shared giữa các replicas)
  session:
    provider: redis
    provider_config: addr=redis:6379,pool_size=100

  # Azure AD SSO
  auth.azuread:
    enabled: true
    name: Azure AD
    allow_sign_up: true
    client_id: ${AZURE_CLIENT_ID}
    client_secret: ${AZURE_CLIENT_SECRET}
    scopes: openid email profile
    auth_url: https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/authorize
    token_url: https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token
    allowed_groups: DevOps,Developers

# Ingress với TLS
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - grafana.company.com
  tls:
    - secretName: grafana-tls
      hosts:
        - grafana.company.com
```

### 3.2 Dashboard Backup với Git

```bash
#!/bin/bash
# scripts/backup-dashboards.sh
# Backup tất cả Grafana dashboards ra file JSON

GRAFANA_URL="https://grafana.company.com"
GRAFANA_TOKEN="<SERVICE_ACCOUNT_TOKEN>"
BACKUP_DIR="./grafana/dashboards"

mkdir -p "${BACKUP_DIR}"

# Lấy danh sách dashboards
DASHBOARDS=$(curl -s -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "${GRAFANA_URL}/api/search?type=dash-db" | jq -r '.[].uid')

for UID in ${DASHBOARDS}; do
  # Lấy dashboard JSON
  TITLE=$(curl -s -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${GRAFANA_URL}/api/dashboards/uid/${UID}" | jq -r '.dashboard.title')
  
  curl -s -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${GRAFANA_URL}/api/dashboards/uid/${UID}" | \
    jq '.dashboard' > "${BACKUP_DIR}/${TITLE}.json"
  
  echo "Backed up: ${TITLE}"
done

# Commit vào git
git add "${BACKUP_DIR}"
git commit -m "chore: backup grafana dashboards $(date +%Y-%m-%d)"
git push

echo "Done! Backed up $(echo "${DASHBOARDS}" | wc -w) dashboards."
```

### 3.3 Grafana as Code (Terraform)

```hcl
# terraform/grafana.tf
terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
  }
}

provider "grafana" {
  url  = "https://grafana.company.com"
  auth = var.grafana_service_account_token
}

# Data source
resource "grafana_data_source" "prometheus" {
  type       = "prometheus"
  name       = "Prometheus"
  url        = "http://prometheus:9090"
  is_default = true

  json_data_encoded = jsonencode({
    timeInterval = "15s"
    httpMethod   = "POST"
  })
}

# Dashboard
resource "grafana_dashboard" "myapp_overview" {
  config_json = file("${path.module}/dashboards/myapp-overview.json")
  folder      = grafana_folder.myapp.id
  overwrite   = true
}

resource "grafana_folder" "myapp" {
  title = "MyApp"
}

# Alert contact point
resource "grafana_contact_point" "slack" {
  name = "Slack Alerts"

  slack {
    url      = var.slack_webhook_url
    channel  = "#alerts"
    username = "Grafana"
  }
}

# Alert rule
resource "grafana_rule_group" "cpu_alerts" {
  name             = "CPU Alerts"
  folder_uid       = grafana_folder.myapp.uid
  interval_seconds = 60

  rule {
    name      = "High CPU"
    condition = "C"
    for       = "5m"

    data {
      ref_id = "A"
      relative_time_range { from = 300; to = 0 }
      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode='idle'}[5m])) * 100)"
      })
    }

    data {
      ref_id = "C"
      relative_time_range { from = 0; to = 0 }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { params = [85], type = "gt" } }]
      })
    }

    labels      = { severity = "warning" }
    annotations = { summary = "High CPU usage" }
  }
}
```


> **Xem thêm:** `prometheus/` cho metrics collection, `elk/` cho log search & analysis
