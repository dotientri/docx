# ---
markmap:
  title: "ELK — Azure Integration & Production"
  collapse: false
# ---

# 🔍 ELK STACK TOÀN TẬP - PHẦN 2: AZURE INTEGRATION & PRODUCTION

## Theory
- Integrating ELK with Azure lets you use Elastic Cloud or ECK and forward logs to Azure Monitor; index templates and lifecycle policies are key for large-scale, cost-effective logging.

## Practice
- Use Elastic Cloud or deploy ECK, configure Filebeat/Logstash outputs to Azure or Elasticsearch, set index templates, mappings, and JVM tuning for production clusters.

## 1. ELK với Azure

### 1.1 Elastic trên Azure Marketplace

```bash
# ===== DÙNG ELASTIC CLOUD TRÊN AZURE =====
# Không cần self-manage Elasticsearch

# Tạo Elastic deployment qua Azure Portal hoặc Terraform
resource "azurerm_elastic_cloud_elasticsearch" "main" {
  name                = "elastic-myapp-prod"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  sku_name            = "ess-monthly-consumption_Monthly"
  
  elastic_cloud_email_address = "devops@company.com"
}
```

### 1.2 Filebeat → Azure Monitor Logs

```yaml
# filebeat.yml - gửi logs lên Azure Monitor (Log Analytics)
output.logstash:
  hosts: ["logstash:5044"]

# Hoặc dùng Azure Logstash plugin
# output.azureloganalytics:
#   workspace_id: "<LOG_ANALYTICS_WORKSPACE_ID>"
#   workspace_key: "<WORKSPACE_KEY>"
#   custom_log_table_name: "MyAppLogs"
```

```ruby
# logstash/pipeline/azure-output.conf
output {
  # Azure Monitor Log Analytics
  microsoft-logstash-output-azure-loganalytics {
    workspace_id   => "${AZURE_WORKSPACE_ID}"
    workspace_key  => "${AZURE_WORKSPACE_KEY}"
    custom_log_table_name => "AppLogs"
  }

  # Elasticsearch (vẫn giữ để search)
  elasticsearch {
    hosts    => ["https://elasticsearch:9200"]
    user     => "elastic"
    password => "${ELASTIC_PASSWORD}"
    index    => "logs-%{+YYYY.MM.dd}"
  }
}
```

### 1.3 Azure Data Explorer (ADX) cho Log Analytics

```kql
// Azure Data Explorer - Kusto Query Language (KQL)
// Tương tự ELK nhưng native Azure

// Kết nối với Log Analytics Workspace
// Ingestion từ Event Hubs, Storage, hoặc trực tiếp

// ===== KQL QUERIES =====

// Log errors từ container
ContainerLog
| where LogEntry contains "ERROR"
| project TimeGenerated, ContainerID, LogEntry
| order by TimeGenerated desc
| take 100

// Error rate theo service
ContainerLog
| where LogEntry contains "ERROR"
| extend service = extract('"service":"([^"]+)"', 1, LogEntry)
| summarize errorCount = count() by service, bin(TimeGenerated, 5m)
| render timechart

// AKS events
KubeEvents
| where Type == "Warning"
| project TimeGenerated, Namespace, Name, Reason, Message
| order by TimeGenerated desc

// HTTP request latency từ Application Insights
requests
| where timestamp > ago(1h)
| summarize
    avgDuration = avg(duration),
    p95Duration = percentile(duration, 95),
    count = count()
  by name
| order by p95Duration desc
```


## 2. ELK Security (SIEM)

### 2.1 Security Analytics với Watcher

```json
// Elasticsearch Watcher Alert - phát hiện brute force
// PUT _watcher/watch/brute-force-detection
{
  "trigger": {
    "schedule": { "interval": "5m" }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["logs-nginx-*"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "match": { "response_code": 401 } },
                { "range": { "@timestamp": { "gte": "now-10m" } } }
              ]
            }
          },
          "aggs": {
            "by_ip": {
              "terms": { "field": "client_ip.keyword", "size": 10 },
              "aggs": {
                "failed_attempts": { "value_count": { "field": "client_ip" } }
              }
            }
          }
        }
      }
    }
  },
  "condition": {
    "script": {
      "source": "return ctx.payload.aggregations.by_ip.buckets.stream().anyMatch(b -> b.failed_attempts.value > 10)"
    }
  },
  "actions": {
    "notify_slack": {
      "webhook": {
        "method": "POST",
        "url": "https://hooks.slack.com/services/xxx",
        "body": "{\"text\": \"🚨 Brute force detected!\"}"
      }
    }
  }
}
```

### 2.2 Index Template & Mappings

```json
// PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "refresh_interval": "5s",
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs"
    },
    "mappings": {
      "properties": {
        "@timestamp":   { "type": "date" },
        "log_level":    { "type": "keyword" },
        "service":      { "type": "keyword" },
        "trace_id":     { "type": "keyword" },
        "message":      { "type": "text", "analyzer": "standard" },
        "client_ip":    { "type": "ip" },
        "response_code":{ "type": "integer" },
        "response_time":{ "type": "float" },
        "geoip": {
          "properties": {
            "location": { "type": "geo_point" }
          }
        }
      }
    }
  }
}
```


## 3. Production Performance Tuning

### 3.1 Elasticsearch JVM & Heap

```bash
# /etc/elasticsearch/jvm.options

# Heap: không vượt quá 50% RAM, tối đa 32GB (compressed OOP)
-Xms8g
-Xmx8g

# GC: G1GC (mặc định cho ES 7+)
-XX:+UseG1GC
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=30

# GC logging
-Xlog:gc*,gc+age=trace,safepoint:file=/var/log/elasticsearch/gc.log:utctime,pid,tags:filecount=32,filesize=64m
```

### 3.2 Elasticsearch Cluster Health

```bash
# ===== KIỂM TRA CLUSTER =====

# Health status
curl -s http://elasticsearch:9200/_cluster/health?pretty

# Node thông tin
curl -s http://elasticsearch:9200/_cat/nodes?v

# Index status
curl -s http://elasticsearch:9200/_cat/indices?v&s=index

# Shard allocation
curl -s http://elasticsearch:9200/_cat/shards?v

# Pending tasks
curl -s http://elasticsearch:9200/_cat/pending_tasks?v

# Hot threads (debug performance)
curl -s http://elasticsearch:9200/_nodes/hot_threads

# ===== XỬ LÝ CLUSTER RED/YELLOW =====

# Xem unassigned shards
curl -s "http://elasticsearch:9200/_cat/shards?h=index,shard,prirep,state,unassigned.reason&s=state" | grep UNASSIGNED

# Force reroute (cẩn thận!)
curl -X POST "http://elasticsearch:9200/_cluster/reroute?retry_failed=true"

# Xem vì sao shard không được assign
curl -X GET "http://elasticsearch:9200/_cluster/allocation/explain?pretty" \
  -H "Content-Type: application/json" \
  -d '{"index": "logs-2024.01.01", "shard": 0, "primary": true}'
```

### 3.3 Snapshot Backup lên Azure Blob

```bash
# 1. Cài Azure plugin
/usr/share/elasticsearch/bin/elasticsearch-plugin install repository-azure

# 2. Thêm credentials vào keystore
/usr/share/elasticsearch/bin/elasticsearch-keystore add azure.client.default.account
/usr/share/elasticsearch/bin/elasticsearch-keystore add azure.client.default.key

# 3. Restart Elasticsearch

# 4. Tạo repository
curl -X PUT "http://elasticsearch:9200/_snapshot/azure-backup" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "azure",
    "settings": {
      "client": "default",
      "container": "elasticsearch-snapshots",
      "base_path": "snapshots"
    }
  }'

# 5. Tạo snapshot policy (SLM - Snapshot Lifecycle Management)
curl -X PUT "http://elasticsearch:9200/_slm/policy/daily-snapshots" \
  -H "Content-Type: application/json" \
  -d '{
    "schedule": "0 30 1 * * ?",
    "name": "<daily-snap-{now/d}>",
    "repository": "azure-backup",
    "config": {
      "indices": ["*"],
      "ignore_unavailable": false,
      "include_global_state": false
    },
    "retention": {
      "expire_after": "30d",
      "min_count": 7,
      "max_count": 30
    }
  }'

# 6. Chạy snapshot ngay
curl -X PUT "http://elasticsearch:9200/_slm/policy/daily-snapshots/_execute"

# 7. Xem snapshots
curl "http://elasticsearch:9200/_snapshot/azure-backup/_all?pretty"
```


## 4. Kibana Dashboards & Spaces

### 4.1 Tạo Dashboard bằng Kibana API

```bash
# Import saved objects (dashboards, visualizations)
curl -X POST "http://kibana:5601/api/saved_objects/_import" \
  -H "kbn-xsrf: true" \
  -F "file=@./kibana/exports/dashboards.ndjson"

# Export
curl -X POST "http://kibana:5601/api/saved_objects/_export" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"type": ["dashboard", "visualization", "index-pattern"]}' \
  -o ./kibana/exports/dashboards.ndjson
```

### 4.2 Kibana Spaces (Multi-tenant)

```bash
# Tạo space cho từng team
curl -X POST "http://kibana:5601/api/spaces/space" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "devops",
    "name": "DevOps Team",
    "description": "Infrastructure & DevOps dashboards",
    "color": "#0077CC",
    "initials": "DO",
    "disabledFeatures": []
  }'

# Phân quyền qua Azure AD groups
# Elastic Security → Role mappings → Map Azure AD group → Kibana role
```


## 5. Monitoring ELK Với Prometheus

```yaml
# elasticsearch-exporter - expose ES metrics cho Prometheus
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch-exporter
  template:
    metadata:
      labels:
        app: elasticsearch-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9114"
    spec:
      containers:
        - name: elasticsearch-exporter
          image: prometheuscommunity/elasticsearch-exporter:v1.7.0
          args:
            - '--es.uri=http://elasticsearch:9200'
            - '--es.all'
            - '--es.indices'
            - '--es.shards'
          ports:
            - containerPort: 9114
          env:
            - name: ES_USERNAME
              value: "elastic"
            - name: ES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: elasticsearch-credentials
                  key: password
```

```promql
# Prometheus alerts cho Elasticsearch

# Cluster not green
elasticsearch_cluster_health_status{color="green"} == 0

# Disk sắp đầy
elasticsearch_filesystem_data_available_bytes / elasticsearch_filesystem_data_size_bytes < 0.15

# JVM heap cao
elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"} > 0.85

# Indexing latency cao
rate(elasticsearch_indices_indexing_index_time_seconds_total[5m]) /
rate(elasticsearch_indices_indexing_index_total[5m]) > 0.1
```


> **Xem thêm:** `prometheus/` cho metrics, `grafana/` cho visualization tổng hợp
