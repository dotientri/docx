# ☸️ KUBERNETES TOÀN TẬP - PHẦN 3: SCALING, SCHEDULING, RBAC & SECURITY

---

## 1. Autoscaling

### 1.1 HPA - Horizontal Pod Autoscaler

```yaml
# HPA: Tự động tăng/giảm số Pods dựa trên metrics

apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
  
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
    
  minReplicas: 2
  maxReplicas: 20
  
  metrics:
    # CPU scaling
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # Scale khi CPU > 70%
          
    # Memory scaling
    - type: Resource
      resource:
        name: memory
        target:
          type: AverageValue
          averageValue: "400Mi"    # Scale khi memory > 400Mi
          
    # Custom metrics (từ Prometheus)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"    # Scale khi > 1000 RPS per Pod
          
    # External metrics (từ SQS queue)
    - type: External
      external:
        metric:
          name: sqs_queue_depth
          selector:
            matchLabels:
              queue: myapp-job-queue
        target:
          type: Value
          value: "100"           # Scale khi queue depth > 100
          
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30       # Chờ 30s trước khi scale up
      policies:
        - type: Pods
          value: 4
          periodSeconds: 60                 # Max 4 Pods mỗi 60s
    scaleDown:
      stabilizationWindowSeconds: 300      # Chờ 5 phút trước khi scale down
      policies:
        - type: Percent
          value: 25
          periodSeconds: 60                 # Max 25% giảm mỗi 60s
```

```bash
# HPA commands
kubectl get hpa -n production
kubectl describe hpa myapp-hpa

# Xem current metrics
kubectl get hpa myapp-hpa -o yaml | grep -A 10 "currentMetrics"

# Test autoscaling
kubectl run -it --rm load-generator --image=busybox -- \
  sh -c "while true; do wget -q -O- http://myapp.production.svc; done"

# Xem HPA đang scale
kubectl get hpa -w
```

### 1.2 VPA - Vertical Pod Autoscaler

```yaml
# VPA: Tự động điều chỉnh resources requests/limits
# Cần cài VPA addon

apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
  
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
    
  updatePolicy:
    updateMode: "Auto"      # Auto, Initial, Off (chỉ recommend)
    
  resourcePolicy:
    containerPolicies:
      - containerName: myapp
        minAllowed:
          cpu: "50m"
          memory: "64Mi"
        maxAllowed:
          cpu: "4"
          memory: "8Gi"
          
# VPA recommendations:
kubectl describe vpa myapp-vpa
# → Sẽ thấy recommended CPU/memory values
```

### 1.3 KEDA - Event-Driven Autoscaling

```yaml
# KEDA: Scale based on event sources (Kafka, SQS, Redis, Prometheus...)
# Hỗ trợ scale to zero!

# Cài KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace kube-system

# ScaledObject
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: myapp-scaler
  
spec:
  scaleTargetRef:
    name: myapp
    
  minReplicaCount: 0      # Scale to ZERO!
  maxReplicaCount: 50
  
  triggers:
    # Kafka trigger
    - type: kafka
      metadata:
        bootstrapServers: kafka.production:9092
        consumerGroup: myapp-consumer
        topic: job-queue
        lagThreshold: "100"    # Scale khi lag > 100 messages
        
    # Azure Service Bus trigger (thay SQS)
    - type: azure-servicebus
      metadata:
        queueName: myapp-job-queue
        messageCount: "50"
      authenticationRef:
        name: azure-servicebus-auth

    # Redis trigger
    - type: redis
      metadata:
        address: redis.production:6379
        listName: job-list
        listLength: "100"
```

### 1.4 Cluster Autoscaler

```bash
# Cluster Autoscaler: Tự động thêm/xóa NODES (không phải Pods)
# Khi Pods không schedule được vì thiếu tài nguyên → Thêm node
# Khi nodes nhàn rỗi → Xóa node

# AKS Cluster Autoscaler (built-in - không cần cài thêm)
# Bật khi tạo AKS cluster hoặc cập nhật node pool:
az aks nodepool update \
  --resource-group rg-myapp-prod \
  --cluster-name aks-myapp-prod \
  --name nodepool1 \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 20

# Xem autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml

# Logs
kubectl logs -n kube-system -l app=cluster-autoscaler -f

# AKS node pool tự động scale dựa trên resource pressure
# Không cần tag như AWS ASG
```

---

## 2. Advanced Scheduling

### 2.1 Node Selector & Node Affinity

```yaml
spec:
  # ===== NODE SELECTOR (đơn giản) =====
  nodeSelector:
    kubernetes.io/arch: amd64
    node-type: gpu
    
  # ===== NODE AFFINITY (phức tạp hơn) =====
  affinity:
    nodeAffinity:
      # Required - Pod KHÔNG schedule nếu không match
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                  - ap-southeast-1a
                  - ap-southeast-1b
                  
      # Preferred - Cố schedule vào đây nếu có thể
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100    # 1-100, higher = more preferred
          preference:
            matchExpressions:
              - key: node-type
                operator: In
                values:
                  - high-memory
```

### 2.2 Pod Affinity & Anti-Affinity

```yaml
affinity:
  # ===== POD AFFINITY (Schedule cùng với Pods khác) =====
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: cache              # Schedule cùng node với cache Pods
        topologyKey: kubernetes.io/hostname
        
  # ===== POD ANTI-AFFINITY (Tránh schedule cùng với Pods) =====
  podAntiAffinity:
    # Hard: Đảm bảo Pods không cùng node (HA!)
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: myapp              # Không schedule 2 myapp Pods cùng node
        topologyKey: kubernetes.io/hostname
        
    # Soft: Prefer khác AZ
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: myapp
          topologyKey: topology.kubernetes.io/zone  # Prefer khác AZ
```

### 2.3 Taints & Tolerations

```bash
# Taint = "Repel" - Nodes đẩy Pods đi
# Toleration = "Accept" - Pods có thể bỏ qua taint

# ===== TAINT A NODE =====
# Chỉ Pods có toleration mới schedule được
kubectl taint nodes node1 dedicated=gpu:NoSchedule
kubectl taint nodes node1 app=critical:NoExecute    # Evict existing Pods!

# Xóa taint
kubectl taint nodes node1 dedicated=gpu:NoSchedule-

# Xem taints
kubectl describe node node1 | grep Taints

# ===== USE CASES =====
# 1. GPU nodes - chỉ ML workloads
kubectl taint nodes gpu-node1 nvidia.com/gpu=true:NoSchedule

# 2. Spot instances - không phải critical workloads
kubectl taint nodes spot-node1 cloud.google.com/gke-spot=true:NoSchedule

# 3. Dedicated nodes cho monitoring
kubectl taint nodes monitor-node1 dedicated=monitoring:NoSchedule
```

```yaml
# Toleration trong Pod spec
spec:
  tolerations:
    # Tolerate GPU node taint
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
      
    # Tolerate spot nodes
    - key: "cloud.google.com/gke-spot"
      operator: "Exists"         # Không cần value
      effect: "NoSchedule"
      
    # Tolerate ALL taints (không khuyến nghị)
    - operator: "Exists"
```

### 2.4 Priority Classes

```yaml
# PriorityClass - Pods quan trọng hơn được schedule trước
# Khi cluster full, low-priority Pods bị evict để nhường chỗ

apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-apps
value: 1000000              # Cao hơn = quan trọng hơn
globalDefault: false
description: "Critical production applications"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: default-priority
value: 0
globalDefault: true         # Default cho Pods không specify

---
# Dùng trong Pod
spec:
  priorityClassName: critical-apps
```

---

## 3. RBAC - Role-Based Access Control

### 3.1 RBAC Concepts

```
RBAC Entities:
┌──────────────────────────────────────────────┐
│                                              │
│  Subject           Role/ClusterRole          │
│  ┌──────────┐      ┌──────────────────────┐ │
│  │  User    │─────▶│  Rules:              │ │
│  ├──────────┤      │  - apiGroups: [""]   │ │
│  │  Group   │─────▶│  - resources: pods   │ │
│  ├──────────┤      │  - verbs: get, list  │ │
│  │ServiceAcc│─────▶└──────────────────────┘ │
│  └──────────┘                               │
│       │                                      │
│       └──── via RoleBinding/ClusterRoleBinding│
└──────────────────────────────────────────────┘

Role: Namespace-scoped
ClusterRole: Cluster-wide

RoleBinding: Bind Role/ClusterRole vào namespace
ClusterRoleBinding: Bind ClusterRole vào toàn cluster
```

### 3.2 Roles và ClusterRoles

```yaml
# Role (namespace-scoped)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: production
  
rules:
  # Pods: full access
  - apiGroups: [""]             # "" = core API group
    resources: ["pods", "pods/log", "pods/exec"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    
  # Deployments: read-only
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
    
  # ConfigMaps: full access
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
    
  # Secrets: read-only
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
    
  # Services: full access
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

---
# ClusterRole (cluster-wide)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
  
rules:
  - apiGroups: [""]
    resources: ["nodes", "pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
    
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list"]
    
  # Non-resource URLs
  - nonResourceURLs: ["/metrics", "/healthz"]
    verbs: ["get"]
```

### 3.3 RoleBindings

```yaml
# RoleBinding: Gán Role cho User/Group/ServiceAccount trong namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
  
subjects:
  - kind: User
    name: alice@company.com        # Username phải match auth system
    apiGroup: rbac.authorization.k8s.io
    
  - kind: Group
    name: backend-team
    apiGroup: rbac.authorization.k8s.io
    
  - kind: ServiceAccount
    name: ci-runner
    namespace: production          # ServiceAccount namespace

roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRoleBinding: Gán ClusterRole cluster-wide
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-binding
  
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
    
roleRef:
  kind: ClusterRole
  name: monitoring-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3.4 ServiceAccounts

```yaml
# ServiceAccount: Identity cho Pods
# Mặc định: Pods dùng "default" SA (có quyền rất hạn chế)

apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: production
  annotations:
    # Azure: Workload Identity (thay IRSA của AWS)
    azure.workload.identity/client-id: "<AZURE_AD_APP_CLIENT_ID>"
    azure.workload.identity/tenant-id: "<AZURE_TENANT_ID>"

---
# Pod phải có label để sử dụng Workload Identity
spec:
  serviceAccountName: myapp
  automountServiceAccountToken: false  # Tắt nếu không cần K8s API access
```

```bash
# Cấu hình AKS Workload Identity:
az aks update -g rg-myapp-prod -n aks-myapp-prod --enable-oidc-issuer --enable-workload-identity

# Tạo Federated Identity Credential
az identity federated-credential create \
  --name fc-myapp \
  --identity-name mi-myapp \
  --resource-group rg-myapp-prod \
  --issuer "$(az aks show -g rg-myapp-prod -n aks-myapp-prod --query oidcIssuerProfile.issuerUrl -o tsv)" \
  --subject "system:serviceaccount:production:myapp"
```

```bash
# ===== RBAC COMMANDS =====
# Kiểm tra quyền của current user
kubectl auth can-i get pods
kubectl auth can-i create deployments -n production
kubectl auth can-i list secrets --all-namespaces

# Kiểm tra quyền của user khác
kubectl auth can-i get pods --as=alice@company.com
kubectl auth can-i get pods --as=system:serviceaccount:production:myapp

# Xem tất cả roles
kubectl get roles -n production
kubectl get clusterroles | grep -v system:

# Xem bindings
kubectl get rolebindings -n production
kubectl get clusterrolebindings

# Debug RBAC
kubectl auth reconcile -f rbac.yaml  # Check và fix RBAC
```

---

## 4. Pod Security

### 4.1 Pod Security Standards (PSS)

```bash
# PSS thay thế PSP (deprecated K8s 1.21+)
# 3 levels: privileged, baseline, restricted

# Apply PSS cho namespace
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### 4.2 Security Context

```yaml
# Pod level security context
spec:
  securityContext:
    runAsUser: 1000           # Run as non-root user
    runAsGroup: 3000
    fsGroup: 2000             # Volume ownership
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
      
  containers:
    - name: myapp
      securityContext:
        allowPrivilegeEscalation: false   # Không cho escalate privileges
        readOnlyRootFilesystem: true       # Read-only filesystem
        runAsNonRoot: true
        capabilities:
          drop:
            - ALL                          # Drop ALL capabilities
          add:
            - NET_BIND_SERVICE            # Chỉ thêm cái cần thiết
        seccompProfile:
          type: RuntimeDefault
```

### 4.3 Network Policies

```yaml
# NetworkPolicy: Firewall cho Pods

# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# Allow API → Database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - port: 5432

---
# Allow monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
spec:
  podSelector: {}    # Apply to all pods
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - port: 9090
        - port: 8080
```

### 4.4 OPA Gatekeeper - Policy as Code

```yaml
# Gatekeeper: Enforce policies tự động

# Cài đặt
# kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# ConstraintTemplate: Define policy
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: RequireResourceLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requireresourcelimits
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf("Container %v must have CPU limits", [container.name])
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container %v must have memory limits", [container.name])
        }

---
# Constraint: Apply policy
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequireResourceLimits
metadata:
  name: must-have-resource-limits
spec:
  enforcementAction: deny    # deny, warn, dryrun
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces:
      - production
      - staging
```

---

## 5. Health Management

### 5.1 Probes Nâng Cao

```yaml
containers:
  - name: myapp
    # ===== READINESS PROBE =====
    # Pod chỉ nhận traffic khi Ready
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
        httpHeaders:
          - name: X-Probe
            value: k8s-readiness
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 3
      successThreshold: 1     # 1 success = Ready
      failureThreshold: 3     # 3 fails = Not Ready
      
    # ===== LIVENESS PROBE =====
    # Pod restart nếu Unhealthy
    livenessProbe:
      httpGet:
        path: /live
        port: 8080
      initialDelaySeconds: 30    # Chờ 30s trước khi bắt đầu check
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3        # 3 fails → Restart
      
    # ===== STARTUP PROBE =====
    # Cho slow-starting apps, disable liveness cho đến khi started
    startupProbe:
      httpGet:
        path: /started
        port: 8080
      failureThreshold: 30       # 30 * periodSeconds = max startup time
      periodSeconds: 10
      # → 30 * 10 = 5 phút để start
      
    # ===== EXEC PROBE (chạy command) =====
    livenessProbe:
      exec:
        command:
          - /bin/sh
          - -c
          - "redis-cli ping | grep PONG"
          
    # ===== TCP PROBE =====
    livenessProbe:
      tcpSocket:
        port: 5432               # Check TCP port open
```

---

> **Tiếp theo: Phần 4** - Helm, Operators, Monitoring & CI/CD với K8s
