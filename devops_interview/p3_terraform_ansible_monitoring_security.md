# 🎯 DEVOPS INTERN INTERVIEW - CI/CD, TERRAFORM, MONITORING, SECURITY

---

## PHẦN 1: CI/CD (CHI TIẾT)

---

### Q1. Giải thích toàn bộ quy trình CI/CD pipeline từ A → Z?

```
Developer workflow:
feature/login → PR → CI pipeline → Merge → CD pipeline → Production

═══════════════════════════════════════════════════════
CI PIPELINE (Chạy mỗi lần push/PR)
═══════════════════════════════════════════════════════

1. Trigger
   - Git push vào feature branch → PR pipeline
   - Merge vào main → Release pipeline

2. Checkout Code
   - Clone repo, switch to commit SHA

3. Install Dependencies
   - npm ci, pip install -r requirements.txt, go mod download
   - Cache để tăng tốc

4. Lint & Format
   - eslint, ruff, golangci-lint, terraform fmt
   - Fail fast nếu code không đúng style

5. Unit Tests
   - jest, pytest, go test
   - Coverage report
   - FAIL pipeline nếu coverage < threshold

6. Security Scan
   - Dependency vulnerabilities: npm audit, pip-audit, nancy
   - SAST (Static Analysis): sonarqube, semgrep
   - Secret detection: trufflesecurity/trufflehog, git-secrets

7. Build Docker Image
   - docker build với cache
   - Tag: ${git-sha}, ${branch}-${timestamp}

8. Image Scan
   - Trivy, Grype, Azure Defender
   - Block on CRITICAL vulnerabilities

9. Push to Registry
   - Azure Container Registry (ACR)
   - Tag as: registry/image:sha + registry/image:branch-latest

═══════════════════════════════════════════════════════
CD PIPELINE (Deploy sau CI pass)
═══════════════════════════════════════════════════════

10. Deploy to Staging (Auto)
    - helm upgrade --install
    - Run database migrations
    - Smoke tests

11. Integration Tests (trên Staging)
    - End-to-end tests, API tests
    - Performance tests (k6, Locust)

12. Manual Approval Gate
    - Notify team via Slack/Teams
    - Chờ approval từ Tech Lead / Release Manager

13. Deploy to Production
    - Same helm command, different values file
    - Canary: 10% → verify → 50% → 100%

14. Post-deploy Verification
    - Health check endpoints
    - Smoke tests trong production
    - Monitor metrics 15 phút sau deploy

15. Notify
    - Slack: ✅ deployed or ❌ failed
    - Update Jira/Linear ticket
```

---

### Q2. Viết GitHub Actions pipeline đầy đủ?

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: myappregistry.azurecr.io
  IMAGE_NAME: myapp-api
  AKS_CLUSTER: aks-myapp-prod
  AKS_RG: myapp-rg

jobs:
  # ===== CI JOBS =====
  lint:
    name: Lint & Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Check formatting
        run: npm run format:check

  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: lint
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports: ['5432:5432']
        options: --health-cmd pg_isready --health-interval 10s

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test -- --coverage
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/testdb
          NODE_ENV: test

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/

      - name: Coverage gate
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "❌ Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit
        run: npm audit --audit-level=high

      - name: Run Trivy (repo scan)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          ignore-unfixed: true
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

  build:
    name: Build & Push Image
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.push.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Generate image metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,format=short
            type=ref,event=branch
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Login to Azure Container Registry
        uses: azure/docker-login@v1
        with:
          login-server: ${{ env.REGISTRY }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}

      - name: Build and push
        id: push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
          cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max

      - name: Scan pushed image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}
          severity: 'CRITICAL'
          exit-code: '1'

  # ===== CD JOBS =====
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    environment: staging
    if: github.ref == 'refs/heads/develop'

    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set AKS context
        uses: azure/aks-set-context@v3
        with:
          resource-group: myapp-rg
          cluster-name: aks-myapp-staging

      - name: Deploy to Staging
        run: |
          IMAGE_TAG=$(echo ${{ needs.build.outputs.image-tag }} | head -1)
          helm upgrade --install myapp ./helm/myapp \
            -n staging \
            --create-namespace \
            -f helm/myapp/values-staging.yaml \
            --set image.repository=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }} \
            --set image.tag=${IMAGE_TAG##*:} \
            --wait --timeout 10m

      - name: Run smoke tests
        run: |
          sleep 30
          curl -f https://staging.company.com/health

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    environment: production   # GitHub environment với required reviewers
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set AKS context (Production)
        uses: azure/aks-set-context@v3
        with:
          resource-group: myapp-rg
          cluster-name: aks-myapp-prod

      - name: Deploy to Production
        run: |
          IMAGE_TAG=$(echo ${{ needs.build.outputs.image-tag }} | head -1)
          helm upgrade --install myapp ./helm/myapp \
            -n production \
            -f helm/myapp/values-production.yaml \
            --set image.repository=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }} \
            --set image.tag=${IMAGE_TAG##*:} \
            --wait --timeout 15m

      - name: Post-deploy verification
        run: |
          sleep 60
          curl -f https://api.company.com/health
          # Run smoke test suite
          npm run test:smoke -- --env production

      - name: Notify success
        if: success()
        uses: slackapi/slack-github-action@v1.25.0
        with:
          payload: |
            {"text": "✅ Deployed ${{ env.IMAGE_NAME }} to production"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Notify failure
        if: failure()
        uses: slackapi/slack-github-action@v1.25.0
        with:
          payload: |
            {"text": "❌ Production deploy FAILED for ${{ env.IMAGE_NAME }}"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

### Q3. Tại sao phải dùng Git branching strategy?

```
Vấn đề nếu mọi người commit thẳng vào main:
- Code chưa review → bugs vào production
- 2 người sửa cùng file → conflicts liên tục
- Không rollback được một feature cụ thể

Git Flow:
┌─────────────────────────────────────────────────────┐
│                                                     │
│  main ────●─────────────────────────●──────── [v2]  │
│           │                         │              │
│           └── release/1.0 ──────────┘              │
│                                                     │
│  develop ────●────●────●────●────●──────── [latest]│
│              │    │    │    │                       │
│              │    │    │    └── hotfix/urgent-fix   │
│              │    │    └── feature/payment          │
│              │    └── feature/login                 │
│              └── feature/signup                     │
└─────────────────────────────────────────────────────┘

Trunk-Based Development (Modern, preferred với CI/CD):
- Commit thẳng vào trunk/main (hoặc short-lived branches < 2 days)
- Feature Flags để ẩn incomplete work
- Phù hợp với high-frequency deploys
```

---

## PHẦN 2: TERRAFORM

---

### Q4. Giải thích Terraform workflow từ đầu đến cuối?

```bash
# === WORKFLOW ===
terraform init    → Download providers, setup backend
terraform plan    → Compare current state với desired state, tạo execution plan
terraform apply   → Execute plan (tạo/sửa/xóa resources)
terraform destroy → Xóa tất cả resources

# === INIT ===
terraform init -backend-config="resource_group_name=tfstate-rg" \
               -backend-config="storage_account_name=tfstorestorage001" \
               -backend-config="container_name=tfstate" \
               -backend-config="key=myapp/prod/terraform.tfstate"

# Terraform init làm gì?
# 1. Download providers (azurerm, aws, random...)
# 2. Initialize backend (connect to Azure Storage)
# 3. Create .terraform directory

# === PLAN ===
terraform plan -var-file="environments/prod.tfvars" -out=tfplan
# Output:
# + = Create
# - = Destroy
# ~ = Update in-place
# -/+ = Destroy and recreate (dangerous!)

# === APPLY ===
terraform apply tfplan          # Apply saved plan
terraform apply -auto-approve   # Skip confirmation (CI/CD)

# === STATE ===
terraform state list                          # List all resources in state
terraform state show azurerm_kubernetes_cluster.aks   # Show specific resource
terraform state rm azurerm_resource_group.old          # Remove from state
terraform import azurerm_resource_group.existing /subscriptions/.../resourceGroups/existing-rg

# === OTHER USEFUL ===
terraform fmt -recursive    # Format all .tf files
terraform validate          # Validate syntax
terraform output            # Show outputs
terraform taint resource    # Force recreate on next apply (deprecated → use -replace)
terraform apply -replace=azurerm_virtual_machine.web  # Force recreate specific resource
```

---

### Q5. Terraform modules - viết module cho Azure AKS?

```hcl
# modules/aks/variables.tf
variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
}
variable "resource_group_name" {
  type        = string
}
variable "location" {
  type        = string
  default     = "southeastasia"
}
variable "kubernetes_version" {
  type        = string
  default     = "1.29.2"
}
variable "system_node_count" {
  type        = number
  default     = 3
  validation {
    condition     = var.system_node_count >= 1 && var.system_node_count <= 10
    error_message = "Node count must be between 1 and 10"
  }
}
variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}
variable "log_analytics_workspace_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

# modules/aks/main.tf
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard"

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.node_vm_size
    zones               = [1, 2, 3]
    vnet_subnet_id      = var.subnet_id
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"
    
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/24"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  azure_policy_enabled = true
  
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,   # Autoscaler manages this
      kubernetes_version                  # Managed upgrade
    ]
    prevent_destroy = true   # Protection against accidental destroy
  }

  tags = var.tags
}

# modules/aks/outputs.tf
output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}
output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}
output "kube_config" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}
output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

# main.tf (root) - dùng module
module "aks_production" {
  source = "./modules/aks"
  
  cluster_name               = "aks-myapp-prod"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  kubernetes_version         = "1.29.2"
  system_node_count          = 3
  node_vm_size               = "Standard_D4s_v5"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  subnet_id                  = azurerm_subnet.aks.id
  
  tags = {
    Environment = "production"
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
}
```

---

## PHẦN 3: MONITORING

---

### Q6. Giải thích Prometheus scraping và alerting?

```yaml
# Prometheus cách hoạt động:
# 1. Prometheus scrape metrics từ targets qua HTTP GET /metrics
# 2. Targets expose metrics ở format:
#    http_requests_total{method="GET",status="200"} 1234
# 3. Prometheus lưu vào time-series DB
# 4. Alertmanager nhận alerts, dedup, route, silence

# prometheus.yml (scrape config)
global:
  scrape_interval: 15s       # Scrape mỗi 15 giây
  evaluation_interval: 15s   # Evaluate rules mỗi 15 giây

scrape_configs:
  # Kubernetes pods với annotations
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    # Chỉ scrape pods có annotation prometheus.io/scrape: "true"
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      target_label: __address__
      regex: (.+)
      replacement: $1:${1}

  # AKS node metrics (node-exporter)
  - job_name: 'node-exporter'
    kubernetes_sd_configs:
    - role: node

# Alerting rules
groups:
- name: production-alerts
  rules:
  # Pod restart rate
  - alert: PodFrequentlyRestarting
    expr: |
      rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 3
    for: 5m
    labels:
      severity: warning
      team: platform
    annotations:
      summary: "Pod {{ $labels.pod }} in {{ $labels.namespace }} is restarting frequently"
      description: "Restarted {{ $value }} times in last 15 minutes"
      runbook: "https://wiki.company.com/runbooks/pod-restarts"

  # High error rate
  - alert: HighHTTPErrorRate
    expr: |
      sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
      / sum(rate(http_requests_total[5m])) by (service)
      > 0.05
    for: 3m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ $labels.service }} has >5% error rate"

  # Memory usage
  - alert: ContainerMemoryUsageHigh
    expr: |
      container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Container {{ $labels.container }} using >85% memory limit"

  # Disk pressure
  - alert: NodeDiskPressure
    expr: |
      (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.15
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.instance }} disk is >85% full"
```

---

### Q7. Khi nào dùng metrics vs logs vs traces?

```
METRICS → "Điều gì đang xảy ra?"
  - Định lượng theo thời gian
  - CPU/Memory/Request rate/Error rate/Latency
  - Alerting: "Error rate > 5%"
  - Tools: Prometheus, Azure Monitor Metrics
  - Retention: Lâu dài, compressed, chi phí thấp

LOGS → "Tại sao điều đó xảy ra?"
  - Events có cấu trúc hoặc text
  - Error messages, stack traces, debug info
  - Debugging: "Lỗi cụ thể là gì?"
  - Tools: Azure Log Analytics, ELK, Loki
  - Retention: Trung bình (30-90 ngày), chi phí cao hơn

TRACES → "Nó xảy ra ở đâu?"
  - End-to-end request path qua microservices
  - Latency per service, bottleneck
  - "Tại sao request này mất 2 giây?"
  - Tools: Jaeger, Azure Application Insights, Zipkin
  - Sampling: Không trace 100% (quá tốn), thường 1-10%

Ví dụ thực tế:
  Alert: Error rate tăng (metrics)
  ↓
  Xem logs: Lỗi "Connection timeout to database" (logs)
  ↓
  Trace request: Service A → Service B → Database (traces)
  ↓  
  Bottleneck: Database query mất 1.8s (traces + database metrics)
```

---

## PHẦN 4: SECURITY

---

### Q8. Làm thế nào để bảo mật CI/CD pipeline?

```
1. SECRETS MANAGEMENT
   ❌ Không commit secrets vào git
   ❌ Không dùng plaintext trong pipeline logs
   ✅ GitHub Secrets / Azure DevOps Variable Groups
   ✅ Azure Key Vault (truy xuất trong pipeline)
   ✅ Secret scanning: trufflesecurity/trufflehog trong CI

2. DOCKER IMAGE SECURITY
   ✅ Non-root user trong container
   ✅ Minimal base image (alpine, distroless)
   ✅ Scan vulnerabilities: Trivy, Snyk, Azure Defender
   ✅ Không install development tools trong production image
   ✅ Read-only filesystem khi có thể
   ✅ .dockerignore để không copy .env, .git, node_modules

3. REGISTRY SECURITY
   ✅ Private registry (ACR, not public Docker Hub)
   ✅ ACR + Azure Defender enabled
   ✅ Image signing (Cosign/Notary)
   ✅ Vulnerability scanning khi push

4. K8S SECURITY
   ✅ RBAC: Least privilege
   ✅ Network Policies: Deny by default
   ✅ Pod Security Standards (restricted)
   ✅ Sealed Secrets / External Secrets Operator
   ✅ Azure Key Vault CSI Driver

5. SUPPLY CHAIN SECURITY
   ✅ Pin dependency versions (package-lock.json, go.sum)
   ✅ Verify checksums
   ✅ SBOM (Software Bill of Materials)
   ✅ Signed commits (GPG)
```

---

## PHẦN 5: CÂU HỎI HÀNH VI (BEHAVIORAL)

---

### "Kể về lần bạn làm hỏng production. Bạn đã làm gì?"

**Cấu trúc STAR:**
```
Situation: Tôi đang deploy version mới của API service lúc 14h.
Task: Deploy hotfix cho bug authentication.
Action: 
  - Nhận ra lỗi 2 phút sau khi deploy (error rate tăng từ 0.1% → 35%)
  - Ngay lập tức ping #incidents trên Slack
  - Rollback trong vòng 5 phút: kubectl rollout undo deployment/api
  - Xác nhận metrics trở về bình thường
  - Investigate root cause: Missing env var trong config
  - Fix và redeploy sau 30 phút, kèm thêm test case

Result:
  - Total impact: ~7 phút elevated error rate
  - Không có data loss
  - Thêm: Integration test kiểm tra env vars
  - Thêm: Pre-deploy checklist

Lessons learned:
  - Luôn monitor metrics 15 phút sau deploy
  - Test env vars trong staging environment
  - Chuẩn bị rollback script sẵn
```

---

### "Bạn không đồng ý với quyết định kỹ thuật của Senior Dev. Bạn làm gì?"

```
Cách tiếp cận chuyên nghiệp:

1. HIỂU TRƯỚC KHI PHẢN ĐỐI
   "Anh có thể giải thích thêm về approach này không?
   Tôi muốn hiểu đầy đủ trước khi đưa ra ý kiến."

2. RAISE CONCERNS VỚI DỮ LIỆU
   "Tôi đọc được benchmark này cho thấy approach X
   có latency cao hơn 20% so với Y trong use case của mình.
   Anh có muốn xem không?"

3. PROPOSE ALTERNATIVE
   "Tôi nghĩ có thể làm theo cách Y vì... 
   Đây là trade-offs: [pro/con]. Anh nghĩ sao?"

4. ACCEPT DECISION
   Nếu Senior Dev vẫn giữ ý kiến sau khi đã nghe:
   "OK tôi hiểu reasoning của anh. Mình proceed với approach này.
   Tôi sẽ viết document lại trade-offs để tham khảo sau."

→ KHÔNG bao giờ: Bỏ qua và tự làm theo cách mình muốn
→ KHÔNG bao giờ: Escalate lên manager ngay mà chưa nói thẳng
```

---

### Questions bạn NÊN hỏi interviewer?

```
Technical:
  "Stack hiện tại của team là gì? K8s version? Cloud provider?"
  "Team deploy bao nhiêu lần mỗi ngày?"
  "Incident response process như thế nào?"
  "Monitoring và alerting setup hiện tại?"

Culture/Growth:
  "Intern sẽ được assigned vào project thật hay chỉ internal tools?"
  "Mentorship program như thế nào?"
  "Có on-call rotation không?"
  "Learning & development budget có không?"

Role:
  "Trong 3 tháng đầu, intern cần achieve gì để được đánh giá tốt?"
  "Team size và structure như thế nào?"
```

---

## CHEAT SHEET - CÁC CON SỐ CẦN NHỚ

| Khái niệm | Con số |
|-----------|--------|
| K8s NodePort range | 30000 - 32767 |
| Default K8s Service ClusterIP CIDR | 10.96.0.0/12 |
| Docker bridge subnet default | 172.17.0.0/16 |
| HTTP status codes | 2xx OK, 3xx Redirect, 4xx Client err, 5xx Server err |
| Exit code OOMKilled | 137 (128+9) |
| CPU limits: 1000m | = 1 CPU core |
| Prometheus default scrape | 15 seconds |
| etcd default port | 2379 (client), 2380 (peer) |
| K8s API server port | 6443 |
| SSH port | 22 |
| DNS port | 53 (UDP) |
| HTTP/HTTPS ports | 80 / 443 |
