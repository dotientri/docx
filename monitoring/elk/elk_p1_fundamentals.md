# 🔍 ELK STACK TOÀN TẬP - PHẦN 1: ELASTICSEARCH & KIBANA

---

## 1. ELK Stack Là Gì?

```
ELK = Elasticsearch + Logstash + Kibana
ELK Stack flow:

Logs/Events
    │
    ▼
┌──────────┐    ┌─────────────┐    ┌───────────────┐    ┌────────┐
│ Filebeat │───▶│  Logstash   │───▶│ Elasticsearch │───▶│ Kibana │
│(shipper) │    │(transform)  │    │  (storage+    │    │  (UI)  │
└──────────┘    └─────────────┘    │   search)     │    └────────┘
                                   └───────────────┘
Hoặc đơn giản hơn (không cần Logstash):
Filebeat → Elasticsearch → Kibana
```

**Use cases:**
- **Log centralization**: Thu thập log từ nhiều server/container
- **Full-text search**: Tìm kiếm trong log nhanh
- **Security analytics**: SIEM, threat detection
- **APM**: Application Performance Monitoring

**ELK vs Loki:**
| | ELK | Loki |
|--|-----|------|
| Full-text search | ✅ Rất mạnh | ❌ Giới hạn |
| Indexing | Full index | Label-based |
| Storage cost | Cao hơn | Thấp hơn |
| K8s native | Partial | ✅ Native |
| Azure integration | Có | Có |

---

## 2. Cài Đặt ELK trên Docker Compose

```yaml
# docker-compose-elk.yml
version: '3.8'

services:
  # ===== ELASTICSEARCH =====
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=es-docker-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - ES_JAVA_OPTS=-Xms2g -Xmx2g
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - ELASTIC_PASSWORD=StrongPass123!
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - elk
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -q 'green\\|yellow'"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ===== LOGSTASH =====
  logstash:
    image: docker.elastic.co/logstash/logstash:8.12.0
    container_name: logstash
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml
    ports:
      - "5044:5044"   # Beats input
      - "5000:5000"   # TCP input
      - "9600:9600"   # Logstash API
    environment:
      LS_JAVA_OPTS: "-Xmx1g -Xms1g"
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - elk

  # ===== KIBANA =====
  kibana:
    image: docker.elastic.co/kibana/kibana:8.12.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_URL: http://elasticsearch:9200
      ELASTICSEARCH_HOSTS: '["http://elasticsearch:9200"]'
      ELASTICSEARCH_USERNAME: kibana_system
      ELASTICSEARCH_PASSWORD: StrongPass123!
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - elk

  # ===== FILEBEAT =====
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.12.0
    container_name: filebeat
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: filebeat -e -strict.perms=false
    depends_on:
      - logstash
    networks:
      - elk

volumes:
  elasticsearch_data:

networks:
  elk:
```

---

## 3. Cài ELK trên Kubernetes (ECK - Elastic Cloud on Kubernetes)

```bash
# ===== CÀI ECK OPERATOR =====
kubectl create -f https://download.elastic.co/downloads/eck/2.11.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.0/operator.yaml

# Xem operator logs
kubectl logs -n elastic-system statefulset.apps/elastic-operator
```

```yaml
# elasticsearch.yaml - Elasticsearch Cluster
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: myapp-elk
  namespace: monitoring
spec:
  version: 8.12.0
  nodeSets:
    # Master nodes
    - name: masters
      count: 3
      config:
        node.roles: ["master"]
        xpack.ml.enabled: false
      podTemplate:
        spec:
          containers:
            - name: elasticsearch
              resources:
                requests:
                  memory: 2Gi
                  cpu: 1000m
                limits:
                  memory: 4Gi
                  cpu: 2000m
              env:
                - name: ES_JAVA_OPTS
                  value: "-Xms2g -Xmx2g"
      volumeClaimTemplates:
        - metadata:
            name: elasticsearch-data
          spec:
            accessModes: [ReadWriteOnce]
            resources:
              requests:
                storage: 10Gi
            storageClassName: managed-premium

    # Data nodes
    - name: data
      count: 3
      config:
        node.roles: ["data", "ingest"]
      podTemplate:
        spec:
          containers:
            - name: elasticsearch
              resources:
                requests:
                  memory: 4Gi
                  cpu: 2000m
                limits:
                  memory: 8Gi
                  cpu: 4000m
              env:
                - name: ES_JAVA_OPTS
                  value: "-Xms4g -Xmx4g"
      volumeClaimTemplates:
        - metadata:
            name: elasticsearch-data
          spec:
            accessModes: [ReadWriteOnce]
            resources:
              requests:
                storage: 100Gi
            storageClassName: managed-premium

---
# kibana.yaml
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: myapp-kibana
  namespace: monitoring
spec:
  version: 8.12.0
  count: 1
  elasticsearchRef:
    name: myapp-elk
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  podTemplate:
    spec:
      containers:
        - name: kibana
          resources:
            requests:
              memory: 1Gi
              cpu: 500m
            limits:
              memory: 2Gi
```

---

## 4. Logstash Pipeline

```ruby
# logstash/pipeline/main.conf

# ===== INPUT =====
input {
  # Từ Filebeat
  beats {
    port => 5044
  }

  # TCP input (ứng dụng gửi log trực tiếp)
  tcp {
    port => 5000
    codec => json_lines
  }

  # Kafka (cho throughput cao)
  # kafka {
  #   bootstrap_servers => "kafka:9092"
  #   topics => ["app-logs", "system-logs"]
  #   codec => json
  #   consumer_threads => 4
  # }
}

# ===== FILTER =====
filter {
  # Parse JSON logs
  if [fields][log_type] == "application" {
    json {
      source => "message"
      target => "app"
      remove_field => ["message"]
    }

    # Extract fields
    mutate {
      rename => { "[app][level]"      => "log_level" }
      rename => { "[app][timestamp]"  => "app_timestamp" }
      rename => { "[app][service]"    => "service" }
      rename => { "[app][trace_id]"   => "trace_id" }
      rename => { "[app][message]"    => "message" }
    }

    # Convert log level to uppercase
    mutate {
      uppercase => ["log_level"]
    }
  }

  # Parse nginx access log
  if [fields][log_type] == "nginx" {
    grok {
      match => {
        "message" => '%{IPORHOST:client_ip} - %{USER:ident} \[%{HTTPDATE:timestamp}\] "%{WORD:method} %{URIPATHPARAM:request} HTTP/%{NUMBER:http_version}" %{NUMBER:response_code:int} %{NUMBER:bytes:int} "%{URI:referrer}" "%{GREEDYDATA:user_agent}" %{NUMBER:response_time:float}'
      }
    }

    # Geoip lookup
    geoip {
      source => "client_ip"
      target => "geoip"
    }

    # User agent parsing
    useragent {
      source => "user_agent"
      target => "ua"
    }
  }

  # Drop health check logs
  if [request] =~ "/health" or [request] =~ "/readyz" {
    drop {}
  }

  # Add environment tag
  mutate {
    add_field => {
      "environment" => "%{[kubernetes][namespace]}"
    }
  }

  # Date filter (set @timestamp từ app log)
  if [app_timestamp] {
    date {
      match => ["app_timestamp", "ISO8601"]
      target => "@timestamp"
    }
  }
}

# ===== OUTPUT =====
output {
  elasticsearch {
    hosts => ["https://elasticsearch:9200"]
    user  => "elastic"
    password => "${ELASTIC_PASSWORD}"
    ssl => false

    # Dynamic index theo date và type
    index => "logs-%{[fields][log_type]}-%{+YYYY.MM.dd}"

    # ILM (Index Lifecycle Management)
    ilm_enabled => true
    ilm_rollover_alias => "logs-%{[fields][log_type]}"
    ilm_policy => "logs-policy"
  }

  # Debug output
  # stdout { codec => rubydebug }
}
```

---

## 5. Filebeat Config

```yaml
# filebeat/filebeat.yml
filebeat.inputs:
  # Docker/K8s container logs
  - type: container
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_kubernetes_metadata:
          host: ${NODE_NAME}
          matchers:
            - logs_path:
                logs_path: "/var/lib/docker/containers/"
    fields:
      log_type: application

  # System logs
  - type: filestream
    id: system-logs
    paths:
      - /var/log/syslog
      - /var/log/auth.log
    fields:
      log_type: system

# Output tới Logstash
output.logstash:
  hosts: ["logstash:5044"]
  loadbalance: true
  bulk_max_size: 2048

# Hoặc trực tiếp Elasticsearch (bỏ qua Logstash)
# output.elasticsearch:
#   hosts: ["https://elasticsearch:9200"]
#   username: "elastic"
#   password: "${ELASTIC_PASSWORD}"
#   index: "filebeat-%{+yyyy.MM.dd}"

# Monitoring
monitoring.enabled: true
monitoring.elasticsearch:
  hosts: ["https://elasticsearch:9200"]
  username: beats_system
  password: "${ELASTIC_PASSWORD}"

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~    # Azure VM metadata
  - add_docker_metadata: ~
```

---

## 6. Elasticsearch Index Lifecycle Management (ILM)

```json
// PUT _ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "1d"
          },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "freeze": {},
          "set_priority": { "priority": 0 }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

---

## 7. Kibana KQL Queries

```kql
# ===== KIBANA QUERY LANGUAGE (KQL) =====

# Tìm lỗi theo level
log_level: "ERROR"

# Tìm theo nhiều điều kiện
log_level: "ERROR" AND service: "myapp-api"

# Wildcard search
message: *database* AND NOT message: *connection pool*

# Range query
response_code >= 500 AND response_code <= 599

# Tìm trong khoảng thời gian (dùng UI hoặc)
@timestamp >= "2024-01-01" AND @timestamp <= "2024-01-31"

# Full-text search
message: "NullPointerException"

# Tìm theo traceId để debug distributed tracing
trace_id: "abc123def456"

# Nginx: response time cao
response_time > 2 AND response_code: 200

# Tìm theo IP
client_ip: "1.2.3.4"
```

---

> **Tiếp theo: Phần 2** - ELK Security (SIEM), Azure Integration & Production Tuning
