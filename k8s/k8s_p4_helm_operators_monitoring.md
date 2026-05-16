# ☸️ KUBERNETES TOÀN TẬP - PHẦN 4: HELM, OPERATORS, MONITORING & CI/CD

---

## 1. Helm - Package Manager cho K8s

### 1.1 Helm Là Gì?

```
Không có Helm:
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f rbac.yaml
... 20+ files

Với Helm:
helm install myapp ./myapp-chart
# Một lệnh install tất cả, có version, có rollback
```

**Helm Concepts:**
- **Chart:** Package của K8s manifests (như Debian package)
- **Release:** Instance của chart được install vào cluster
- **Repository:** Nơi chứa charts (như apt repo)
- **Values:** Variables để customize chart

### 1.2 Cài Đặt và Commands Cơ Bản

```bash
# Cài Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version

# ===== REPOS =====
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update                    # Update repo index

helm repo list
helm search repo nginx              # Tìm chart
helm search hub nginx               # Tìm trên Artifact Hub

# ===== INSTALL =====
helm install myapp bitnami/nginx                       # Install với default values
helm install myapp bitnami/nginx -n production         # Specific namespace
helm install myapp bitnami/nginx --create-namespace    # Tạo namespace nếu chưa có
helm install myapp ./myapp-chart                       # Local chart
helm install myapp ./myapp-chart -f values.yaml        # Custom values
helm install myapp ./myapp-chart \
  --set ingress.enabled=true \
  --set ingress.hostname=app.company.com

# ===== INSPECT =====
helm list                           # Xem releases
helm list -n production
helm list -A                        # All namespaces
helm status myapp                   # Status của release
helm get values myapp               # Values được dùng
helm get manifest myapp             # Generated manifests

# ===== UPGRADE =====
helm upgrade myapp ./myapp-chart -f values.yaml
helm upgrade --install myapp ./myapp-chart  # Install nếu chưa có, upgrade nếu có

# ===== ROLLBACK =====
helm history myapp                  # Release history
helm rollback myapp 2               # Rollback to revision 2
helm rollback myapp 0               # Rollback to previous

# ===== UNINSTALL =====
helm uninstall myapp
helm uninstall myapp -n production

# ===== DRY RUN =====
helm install myapp ./chart --dry-run          # Preview
helm template myapp ./chart                   # Render templates locally
helm lint ./chart                             # Lint chart
```

### 1.3 Tạo Helm Chart

```bash
# Khởi tạo chart
helm create myapp

# Cấu trúc:
# myapp/
# ├── Chart.yaml          ← Metadata
# ├── values.yaml         ← Default values
# ├── templates/          ← K8s manifests (Jinja2-like)
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   ├── ingress.yaml
# │   ├── configmap.yaml
# │   ├── hpa.yaml
# │   ├── serviceaccount.yaml
# │   ├── NOTES.txt       ← Post-install notes
# │   └── _helpers.tpl    ← Template helpers/partials
# ├── charts/             ← Sub-charts (dependencies)
# └── .helmignore
```

```yaml
# Chart.yaml
apiVersion: v2
name: myapp
description: My Application Helm Chart
type: application
version: 1.2.0         # Chart version (semver)
appVersion: "2.1.0"    # Application version

maintainers:
  - name: DevOps Team
    email: devops@company.com

dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled    # Tùy chọn bật/tắt
```

```yaml
# values.yaml - Default values
replicaCount: 2

image:
  repository: company/myapp
  pullPolicy: IfNotPresent
  tag: ""              # Nếu trống, dùng Chart.AppVersion

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

env: []
envFrom: []

config:
  dbHost: localhost
  dbPort: "5432"
  logLevel: info

postgresql:
  enabled: false
  auth:
    username: myapp
    database: myapp
```

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
    
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
      
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
      annotations:
        # Force rollout when configmap changes
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        
    spec:
      serviceAccountName: {{ include "myapp.serviceAccountName" . }}
      
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
              
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          
          envFrom:
            - configMapRef:
                name: {{ include "myapp.fullname" . }}
          {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
```

```
# templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

```bash
# Dùng chart với environment-specific values
# values-staging.yaml
replicaCount: 1
ingress:
  enabled: true
  hosts:
    - host: staging.company.com
      paths:
        - path: /
          pathType: Prefix
resources:
  limits:
    cpu: 200m
    memory: 256Mi

# values-production.yaml
replicaCount: 5
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
ingress:
  enabled: true
  hosts:
    - host: app.company.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-company-tls
      hosts:
        - app.company.com

# Deploy
helm upgrade --install myapp ./myapp-chart \
  -f values.yaml \
  -f values-production.yaml \
  --set image.tag=$CI_COMMIT_SHA \
  -n production \
  --wait \
  --timeout 5m
```

---

## 2. Kubernetes Operators

### 2.1 Operator Pattern

```
Operator = Controller + Custom Resource Definition (CRD)
Dùng để automate complex application lifecycle

Ví dụ: PostgreSQL Operator
- Tạo CR: kind: PostgreSQLCluster
- Operator tự: tạo Pods, Services, PVCs, xử lý failover, backup, restore
```

### 2.2 CRD - Custom Resource Definition

```yaml
# CRD: Thêm resource type mới vào K8s API
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.company.io
  
spec:
  group: company.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                replicas:
                  type: integer
                  minimum: 1
                image:
                  type: string
                database:
                  type: object
                  properties:
                    host:
                      type: string
                    port:
                      type: integer
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames: ["app"]
```

```yaml
# Custom Resource (instance của CRD)
apiVersion: company.io/v1
kind: Application
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
  image: company/myapp:2.1.0
  database:
    host: postgres.production
    port: 5432
```

### 2.3 Popular Operators

```bash
# ===== DATABASE OPERATORS =====

# CloudNativePG - PostgreSQL Operator
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.22.0.yaml

kubectl apply -f - << 'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-prod
spec:
  instances: 3
  storage:
    size: 100Gi
    storageClass: managed-premium
  backup:
    barmanObjectStore:
      destinationPath: "https://myappbackupstore.blob.core.windows.net/postgresql-backups"
      azureCredentials:
        storageAccount:
          name: azure-storage-creds
          key: STORAGE_ACCOUNT_NAME
        storageKey:
          name: azure-storage-creds
          key: STORAGE_ACCOUNT_KEY
  monitoring:
    enablePodMonitor: true
EOF

# Strimzi - Kafka Operator
kubectl create namespace kafka
kubectl apply -f https://strimzi.io/install/latest?namespace=kafka

kubectl apply -f - << 'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    storage:
      type: persistent-claim
      size: 100Gi
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
EOF
```

---

## 3. Monitoring Stack

### 3.1 Prometheus + Grafana với kube-prometheus-stack

```bash
# Cài tất cả trong 1 Helm chart
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Cài kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f monitoring-values.yaml

# monitoring-values.yaml
cat > monitoring-values.yaml << 'EOF'
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
              
    # Scrape external services
    additionalScrapeConfigs:
      - job_name: 'myapp-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true

grafana:
  adminPassword: "SecretGrafanaPass"
  persistence:
    enabled: true
    size: 10Gi
  ingress:
    enabled: true
    hosts:
      - grafana.company.com
    tls:
      - secretName: grafana-tls
        hosts: [grafana.company.com]
  
  # Pre-install dashboards
  dashboards:
    default:
      k8s-cluster:
        gnetId: 15760    # Grafana.com dashboard ID
        revision: 1
        datasource: Prometheus

alertmanager:
  alertmanagerSpec:
    route:
      receiver: slack
    receivers:
      - name: slack
        slack_configs:
          - api_url: https://hooks.slack.com/services/XXX
            channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
EOF

# Xem
kubectl get pods -n monitoring
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# → http://localhost:3000
```

### 3.2 Custom Metrics và Dashboards

```yaml
# ServiceMonitor - Prometheus tự discover service
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
  namespace: production
  labels:
    release: monitoring    # Match với Prometheus selector
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
    - port: metrics        # Port name trong Service
      path: /metrics
      interval: 30s
  namespaceSelector:
    matchNames:
      - production

---
# PrometheusRule - Alert rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: production
  labels:
    release: monitoring
spec:
  groups:
    - name: myapp
      rules:
        - alert: HighErrorRate
          expr: |
            rate(http_requests_total{status=~"5.."}[5m]) /
            rate(http_requests_total[5m]) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate: {{ $value | humanizePercentage }}"
            
        - alert: PodNotReady
          expr: kube_pod_status_ready{namespace="production"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.pod }} not ready"
```

---

## 4. CI/CD với Kubernetes

### 4.1 GitHub Actions → Kubernetes Deploy

```yaml
# .github/workflows/deploy-k8s.yml
name: Deploy to Kubernetes

on:
  push:
    tags: ['v*']

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=sha,prefix={{branch}}-
            
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0
          
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBECONFIG }}
          
      - name: Deploy with Helm
        run: |
          helm upgrade --install myapp ./helm/myapp \
            -n production \
            --set image.repository=ghcr.io/${{ github.repository }} \
            --set image.tag=${{ github.ref_name }} \
            --set ingress.enabled=true \
            -f helm/myapp/values-production.yaml \
            --wait \
            --timeout 10m
            
      - name: Verify deployment
        run: |
          kubectl rollout status deployment/myapp -n production
          kubectl get pods -n production -l app=myapp
```

### 4.2 ArgoCD - GitOps cho Kubernetes

```bash
# ArgoCD: GitOps - K8s state sync với Git repo

# Cài đặt
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Lấy password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# argocd CLI
brew install argocd
argocd login localhost:8080 --username admin --insecure
```

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/company/k8s-manifests.git
    targetRevision: HEAD
    path: production/myapp
    
    # Hoặc với Helm:
    # helm:
    #   releaseName: myapp
    #   valueFiles:
    #     - values-production.yaml
    
  destination:
    server: https://kubernetes.default.svc
    namespace: production
    
  syncPolicy:
    automated:
      prune: true        # Xóa resources không còn trong Git
      selfHeal: true     # Tự fix nếu ai đó edit trực tiếp trong cluster
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        maxDuration: 3m
        factor: 2
```

```bash
# ArgoCD commands
argocd app list
argocd app get myapp-production
argocd app sync myapp-production          # Manual sync
argocd app history myapp-production
argocd app rollback myapp-production      # Rollback to previous
argocd app diff myapp-production          # See what changed
```

---

## 5. Logging Stack - EFK

```bash
# Elasticsearch + Fluentd + Kibana

helm repo add elastic https://helm.elastic.co

# Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  -n logging \
  --create-namespace \
  --set replicas=3 \
  --set volumeClaimTemplate.resources.requests.storage=100Gi

# Kibana
helm install kibana elastic/kibana \
  -n logging \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=kibana.company.com

# Fluent Bit (nhẹ hơn Fluentd, DaemonSet)
helm install fluent-bit fluent/fluent-bit \
  -n logging \
  --set config.outputs="[OUTPUT]\n    Name es\n    Match *\n    Host elasticsearch-master\n    Port 9200"
```

---

> **Tiếp theo: Phần 5** - Troubleshooting, Best Practices & Cheat Sheet
