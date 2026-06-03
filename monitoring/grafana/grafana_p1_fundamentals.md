# ---
markmap:
  title: "Grafana — Fundamentals & Dashboards"
  collapse: false
# ---

# 📈 GRAFANA TOÀN TẬP - PHẦN 1: CÀI ĐẶT & DASHBOARD CƠ BẢN

## Theory
- Grafana is a visualization platform that supports many data sources (Prometheus, Loki, Azure Monitor) and enables dashboard-as-code and alerting for observability.

## Practice
- Install via package, Docker, or Helm; provision datasources and dashboards; secure admin credentials and enable SSO (Azure AD) for team access.

## 1. Grafana Là Gì?

```
Grafana = Nền tảng visualization & observability

Data Sources:          Panels:
- Prometheus    ────▶  Line Charts
- Loki (logs)   ────▶  Bar Charts
- Azure Monitor ────▶  Gauges
- Elasticsearch ────▶  Tables
- InfluxDB      ────▶  Heatmaps
- MySQL/Postgres────▶  Alerts
```

### Ưu điểm
- Hỗ trợ 50+ data sources
- Alerting tích hợp
- Dashboard as Code (JSON/Terraform/Grafonnet)
- Azure Managed Grafana: fully managed, không cần self-host
- SSO với Azure AD


## 2. Cài Đặt

### 2.1 Trên Linux / Azure VM

```bash
# Ubuntu/Debian
sudo apt-get install -y apt-transport-https software-properties-common wget

wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key

echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y grafana

sudo systemctl enable --now grafana-server
# Truy cập: http://localhost:3000 (admin/admin)
```

### 2.2 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=StrongPass123!
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_DOMAIN=grafana.company.com
      - GF_SERVER_ROOT_URL=https://grafana.company.com
      # Azure AD SSO
      - GF_AUTH_AZUREAD_ENABLED=true
      - GF_AUTH_AZUREAD_CLIENT_ID=${AZURE_CLIENT_ID}
      - GF_AUTH_AZUREAD_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
      - GF_AUTH_AZUREAD_TENANT_ID=${AZURE_TENANT_ID}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - monitoring

volumes:
  grafana_data:

networks:
  monitoring:
    external: true
```

### 2.3 Helm trên Kubernetes

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=StrongPass123! \
  --set persistence.enabled=true \
  --set persistence.storageClassName=managed-premium \
  --set persistence.size=10Gi \
  --set ingress.enabled=true \
  --set ingress.hosts[0]=grafana.company.com
```

### 2.4 Azure Managed Grafana

```bash
# Tạo Azure Managed Grafana (fully managed, tích hợp với Azure AD)
az grafana create \
  --name grafana-myapp \
  --resource-group rg-monitoring \
  --location southeastasia \
  --sku Standard \
  --public-network-access Enabled

# Lấy endpoint
az grafana show \
  --name grafana-myapp \
  --resource-group rg-monitoring \
  --query properties.endpoint -o tsv

# Thêm data source Azure Monitor tự động
az grafana data-source create \
  --name grafana-myapp \
  --resource-group rg-monitoring \
  --definition '{
    "name": "Azure Monitor",
    "type": "grafana-azure-monitor-datasource",
    "access": "proxy",
    "isDefault": true
  }'
```


## 3. Provisioning (Dashboard as Code)

### 3.1 Cấu Hình Data Source Tự Động

```yaml
# grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: "15s"
      httpMethod: POST
      exemplarTraceIdDestinations:
        - name: traceID
          datasourceUid: tempo

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      derivedFields:
        - name: TraceID
          matcherRegex: '"trace_id":"(\w+)"'
          url: '$${__value.raw}'
          datasourceUid: tempo

  - name: Azure Monitor
    type: grafana-azure-monitor-datasource
    access: proxy
    jsonData:
      cloudName: azuremonitor
      subscriptionId: '<SUBSCRIPTION_ID>'
    secureJsonData:
      clientSecret: '<CLIENT_SECRET>'
    jsonData:
      tenantId: '<TENANT_ID>'
      clientId: '<CLIENT_ID>'
```

### 3.2 Dashboard Provisioning

```yaml
# grafana/provisioning/dashboards/dashboards.yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: 'Infrastructure'
    folderUid: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```


## 4. Dashboard Quan Trọng (JSON Model)

### 4.1 Tải Dashboard Từ Grafana.com

```bash
# Các dashboard ID phổ biến:
# 1860  - Node Exporter Full
# 315   - Kubernetes cluster monitoring
# 13659 - Kubernetes Pods
# 7587  - Prometheus 2.0 Stats
# 12006 - Azure Monitor
# 10956 - Loki Dashboard

# Import qua API
curl -X POST http://admin:password@grafana:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {"id": 1860, "uid": null},
    "overwrite": false,
    "inputs": [{"name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "Prometheus"}],
    "folderId": 0
  }'
```

### 4.2 Tạo Dashboard Bằng JSON (Application Overview)

```json
{
  "title": "MyApp Overview",
  "uid": "myapp-overview",
  "refresh": "30s",
  "time": {"from": "now-1h", "to": "now"},
  "panels": [
    {
      "id": 1,
      "title": "Request Rate (req/s)",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "targets": [
        {
          "datasource": "Prometheus",
          "expr": "sum(rate(http_requests_total{job='myapp'}[5m])) by (status)",
          "legendFormat": "{{status}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "reqps",
          "color": {"mode": "palette-classic"}
        }
      }
    },
    {
      "id": 2,
      "title": "P95 Latency",
      "type": "gauge",
      "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
      "targets": [
        {
          "datasource": "Prometheus",
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job='myapp'}[5m]))",
          "legendFormat": "P95"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 0.5},
              {"color": "red", "value": 1.0}
            ]
          }
        }
      }
    },
    {
      "id": 3,
      "title": "Error Rate (%)",
      "type": "stat",
      "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
      "targets": [
        {
          "datasource": "Prometheus",
          "expr": "sum(rate(http_requests_total{job='myapp',status=~'5..'}[5m])) / sum(rate(http_requests_total{job='myapp'}[5m])) * 100"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 1},
              {"color": "red", "value": 5}
            ]
          }
        }
      }
    }
  ]
}
```


## 5. Alerting trong Grafana

### 5.1 Alert Rules (Grafana Unified Alerting)

```yaml
# Tạo alert rule qua API
curl -X POST http://admin:pass@grafana:3000/api/v1/provisioning/alert-rules \
  -H "Content-Type: application/json" \
  -d '{
    "title": "High CPU Usage",
    "ruleGroup": "Infrastructure",
    "folderUID": "infra",
    "noDataState": "NoData",
    "execErrState": "Error",
    "for": "5m",
    "condition": "C",
    "data": [
      {
        "refId": "A",
        "datasourceUid": "prometheus",
        "model": {
          "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "intervalMs": 1000,
          "maxDataPoints": 43200
        }
      },
      {
        "refId": "C",
        "datasourceUid": "__expr__",
        "model": {
          "type": "threshold",
          "conditions": [{"evaluator": {"params": [85], "type": "gt"}}]
        }
      }
    ],
    "labels": {"severity": "warning"},
    "annotations": {
      "summary": "High CPU on {{ $labels.instance }}",
      "description": "CPU {{ $values.A }}% > 85%"
    }
  }'
```

### 5.2 Notification Channels

```yaml
# grafana/provisioning/alerting/contact-points.yaml
apiVersion: 1

contactPoints:
  - orgId: 1
    name: slack-alerts
    receivers:
      - uid: slack-critical
        type: slack
        settings:
          url: "https://hooks.slack.com/services/xxx"
          channel: "#alerts"
          username: "Grafana"
          iconEmoji: ":bell:"
          title: |
            [{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}
          text: |
            {{ range .Alerts }}
            *Summary:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            {{ end }}

  - orgId: 1
    name: email-alerts
    receivers:
      - uid: email-devops
        type: email
        settings:
          addresses: devops@company.com
          singleEmail: false
```


## 6. Azure Monitor Integration

```bash
# Grafana với Azure Monitor data source
# Xem metrics AKS, VMs, App Services, Databases

# Ví dụ query Azure Monitor trong Grafana:
# Metric: Percentage CPU
# Resource: /subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Compute/virtualMachines/<VM>
# Aggregation: Average
# Time grain: 1 minute

# Ví dụ query Log Analytics (KQL):
# Workspace: myapp-law
# Query:
# AzureMetrics
# | where ResourceProvider == "MICROSOFT.CONTAINERSERVICE"
# | where MetricName == "node_cpu_usage_percentage"
# | summarize avg(Average) by bin(TimeGenerated, 5m), Resource
# | render timechart
```
