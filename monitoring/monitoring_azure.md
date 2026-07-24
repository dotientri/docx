# ---
markmap:
  title: "Monitoring — Azure & Kubernetes"
  collapse: false
# ---

# 📊 MONITORING DÀNH CHO AZURE & KUBERNETES

## Theory
- Azure Monitor centralizes metrics and logs (Log Analytics + Metrics + Application Insights) for cloud-native observability; choose between Azure-native and open-source stacks based on control and customization needs.

## Practice
- Create Log Analytics workspaces, enable AKS monitoring addon, write KQL queries for alerts, and decide when to deploy Prometheus+Grafana vs. use Azure Managed Prometheus.

## 1. Azure Monitor – Giám sát tích hợp toàn bộ

### 1.1 Thành phần chính
| Component | Mô tả |
|----------|------|
| **Log Analytics Workspace** | Nơi lưu trữ log, cho phép query bằng Kusto Query Language (KQL). |
| **Metrics** | Thu thập metrcis CPU/Memory/Network từ VM, App Service, AKS, Container Instances. |
| **Azure Monitor Alerts** | Cảnh báo dựa trên metric hoặc log query, hỗ trợ email, webhook, Slack, Teams. |
| **Azure Dashboard** | Visual UI, có thể ghép các tile từ Log Analytics, Metric charts, Application Insights. |

### 1.2 Tạo Workspace (CLI)
```bash
az monitor log-analytics workspace create \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --location southeastasia \
  --sku PerGB2018 \
  --retention-time 90

# Lấy IDs cho các service downstream
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --query id -o tsv)
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --query primarySharedKey -o tsv)
```

### 1.3 Kết nối AKS với Log Analytics (khi bật add‑on Monitoring)
```bash
az aks enable-addons \
  --addons monitoring \
  --name aks-myapp-prod \
  --resource-group myapp-rg \
  --workspace-resource-id $WORKSPACE_ID
```

Sau khi bật, các log (kube‑apiserver, kube‑controller‑manager, kube‑scheduler, Kubelet) và metrics sẽ tự động gửi tới workspace.

### 1.4 Ví dụ KQL Queries (Sao chép vào Azure portal → Logs)
```kql
// 1. Top 5 CPU‑intensive pods (last 1h)
KubePodInventory
| where TimeGenerated > ago(1h)
| summarize avgCPU = avg(TotalCpuUsageNanoCores) by PodName, Namespace
| top 5 by avgCPU desc

// 2. Errors trong container logs
ContainerLogV2
| where TimeGenerated > ago(30m)
| where LogMessage contains "ERROR" or LogMessage contains "Exception"
| summarize Count = count() by ContainerID, LogMessage, bin(TimeGenerated, 5m)
| order by Count desc

// 3. Thời gian pod startup (Ready → Running)
KubePodInventory
| where TimeGenerated > ago(1d)
| extend ReadyTime = todatetime(TimeGenerated) 
| summarize start = min(TimeGenerated), ready = max(TimeGenerated) by PodName, Namespace
| extend startupSeconds = datetime_diff('second', ready, start)
| top 10 by startupSeconds desc
```

### 1.5 Alert Examples (CLI)
```bash
# CPU usage > 80% trên AKS node pool
az monitor metrics alert create \
  --name high-cpu-node \
  --resource-group myapp-rg \
  --scopes /subscriptions/<SUB>/resourceGroups/myapp-rg/providers/Microsoft.ContainerService/managedClusters/aks-myapp-prod \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/<SUB>/resourceGroups/myapp-rg/providers/microsoft.insights/actionGroups/myapp-alerts \
  --severity 2

# Log alert: > 50 ERROR logs trong 5 phút
az monitor scheduled-query create \
  --name pod-error-alert \
  --resource-group myapp-rg \
  --scopes $WORKSPACE_ID \
  --condition "count > 50" \
  --condition-query "ContainerLogV2 | where LogMessage contains 'ERROR' | summarize count()" \
  --frequency 5m \
  --window-size 5m \
  --severity 1 \
  --action-group myapp-alerts
```


## 2. Prometheus + Grafana trên AKS (Open‑Source stack)

### 2.1 Cài đặt nhanh với Helm chart `kube-prometheus-stack`
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f monitoring-values.yaml   # tùy chỉnh (retention, remote write, …)
```

`monitoring-values.yaml` (đoạn mẫu):
```yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-ssd
          resources:
            requests:
              storage: 100Gi
    remoteWrite:
      - url: https://<workspace-id>.ods.opinsights.azure.com/api/logs?api-version=2016-04-01
        basicAuth:
          username: $WORKSPACE_ID
          password: $WORKSPACE_KEY
        queueConfig:
          maxSamplesPerSend: 5000
          batchSendDeadline: 5s

grafana:
  adminPassword: "SuperSecretGrafana"
  persistence:
    enabled: true
    size: 10Gi
  ingress:
    enabled: true
    hosts:
      - grafana.company.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.company.com
```

### 2.2 Export metrics to Azure Monitor (optional) – Thông qua **Azure Managed Prometheus**
```bash
az monitor prometheus create \
  --resource-group myapp-rg \
  --cluster-name aks-myapp-prod \
  --mode AzureMonitorMetrics
```

Khi bật, Prometheus scrape sẽ được Azure Monitor thu thập, cho phép sử dụng **Azure Dashboard** hoặc **Log Analytics** để query.


## 3. Azure Application Insights (APM) cho app trên AKS

```bash
# Tạo Application Insights component (Linux) – kết nối với Log Analytics workspace
az monitor app-insights component create \
  --app myapp-insights \
  --location southeastasia \
  --resource-group myapp-rg \
  --application-type web \
  --workspace $WORKSPACE_ID
```

Sau khi tạo, lấy connection string:
```bash
APP_INSIGHTS_CS=$(az monitor app-insights component show \
  --app myapp-insights \
  --resource-group myapp-rg \
  --query connectionString -o tsv)
```

Trong pod (Node.js, Java, .NET…) cấu hình env var `APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CS`.


## 4. Tổng kết – Khi nào dùng công cụ nào?
| Scenario | Recommendation |
|----------|----------------|
| **Full‑stack Azure‑native monitoring** | Azure Monitor (Log Analytics + Metrics) + Application Insights |
| **Open‑source stack, high‑customization** | Prometheus + Grafana (kube‑prometheus‑stack) – optionally remote‑write to Azure Monitor |
| **Simple alerting cho AKS** | Azure Monitor Alerts (metric & log) |
| **Dashboards cho team** | Grafana (cloud or self‑hosted) – kết nối tới Prometheus & Azure Log Analytics via Azure Data Explorer plugin |
