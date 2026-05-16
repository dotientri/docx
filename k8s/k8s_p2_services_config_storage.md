# ☸️ KUBERNETES TOÀN TẬP - PHẦN 2: SERVICES, INGRESS, CONFIG & STORAGE

---

## 1. Services - Network Abstraction

### 1.1 Tại Sao Cần Service?

```
Vấn đề:
- Pods có IP tạm thời → Khi restart, IP thay đổi
- Deployment có nhiều Pods → Load balancing thế nào?
- Không biết Pod nào đang healthy

Service giải quyết:
- IP ổn định (ClusterIP) → Không đổi khi Pods restart
- DNS name: <service-name>.<namespace>.svc.cluster.local
- Tự động load balance đến healthy Pods
```

### 1.2 ClusterIP - Internal Only

```yaml
# service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
  
spec:
  type: ClusterIP          # Mặc định
  
  selector:
    app: myapp             # Chọn Pods này để forward traffic
    
  ports:
    - name: http
      port: 80             # Service port (external)
      targetPort: 8080     # Pod port (internal)
      protocol: TCP
      
    - name: metrics
      port: 9090
      targetPort: 9090
      
  # ClusterIP: Chỉ accessible trong cluster
  # DNS: myapp.production.svc.cluster.local:80
```

```bash
# Test ClusterIP từ trong cluster
kubectl run tmp --rm -it --image=curlimages/curl -- \
  curl http://myapp.production.svc.cluster.local/health
  
# Hoặc từ bên trong Pod
kubectl exec -it some-pod -- curl http://myapp/health
kubectl exec -it some-pod -- curl http://myapp.production/health
kubectl exec -it some-pod -- curl http://myapp.production.svc.cluster.local/health
```

### 1.3 NodePort - Expose qua Node

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-nodeport
  
spec:
  type: NodePort
  
  selector:
    app: myapp
    
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080       # 30000-32767, tùy chọn (K8s tự assign nếu không chỉ định)
      
# Accessible tại: <any-node-ip>:30080
# Thường dùng trong dev/testing, không production
```

### 1.4 LoadBalancer - Cloud Load Balancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-lb
  annotations:
    # Azure Load Balancer annotations (trên AKS)
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"  # external LB
    service.beta.kubernetes.io/azure-load-balancer-tcp-idle-timeout: "30"
    service.beta.kubernetes.io/azure-pip-name: "pip-myapp-lb"         # Static public IP
    service.beta.kubernetes.io/azure-dns-label-name: "myapp-api"      # DNS label

spec:
  type: LoadBalancer

  selector:
    app: myapp

  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8080

  loadBalancerSourceRanges:        # Giới hạn IPs được phép
    - 10.0.0.0/8
    - 203.0.113.0/24

# Azure tự tạo Azure Load Balancer
# kubectl get service myapp-lb → EXTERNAL-IP hiện Public IP của Azure LB
```

### 1.5 Headless Service - Direct Pod IPs

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-headless
  
spec:
  clusterIP: None           # HEADLESS: Không có ClusterIP
  
  selector:
    app: myapp
    
  ports:
    - port: 8080
    
# DNS trả về tất cả Pod IPs thay vì ClusterIP
# Dùng cho: StatefulSets, databases, service discovery
# DNS: myapp-headless → [10.244.0.2, 10.244.0.3, 10.244.1.5]
```

### 1.6 ExternalName - External Service

```yaml
# Alias cho external service
apiVersion: v1
kind: Service
metadata:
  name: database
  
spec:
  type: ExternalName
  externalName: db.company.com    # External hostname
  
# Dùng: kubectl exec pod -- curl http://database:5432
# → Tự động resolve đến db.company.com
# Dùng khi migration: Từ external DB → Internal DB
```

---

## 2. Ingress - HTTP Load Balancing

### 2.1 Ingress Là Gì?

```
Không có Ingress:
- 3 services cần external access → 3 LoadBalancers → Tốn tiền và quản lý phức tạp

Với Ingress:
- 1 Load Balancer (Nginx/Traefik/ALB)
- Route traffic dựa trên hostname/path
- SSL termination tại 1 điểm
```

```
Internet → Ingress Controller (Nginx) → Service A (api.company.com)
                                      → Service B (app.company.com)
                                      → Service C (api.company.com/v2)
```

### 2.2 Cài Ingress Controller

```bash
# ===== NGINX Ingress Controller (trên AKS) =====
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml

# Kiểm tra
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx ingress-nginx-controller

# ===== Application Gateway Ingress Controller (AGIC) - Native Azure =====
# Dùng với AKS + Azure Application Gateway
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
  -n kube-system \
  --set appgw.subscriptionId="<SUB_ID>" \
  --set appgw.resourceGroup="rg-myapp-prod" \
  --set appgw.name="agw-myapp-prod" \
  --set armAuth.type=aadPodIdentity

# ===== Traefik =====
helm repo add traefik https://helm.traefik.io/traefik
helm install traefik traefik/traefik -n kube-system
```

### 2.3 Ingress Manifest

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "100"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://app.company.com"
    
    # Timeout
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Auth
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    
    # Azure AGIC (nếu dùng Application Gateway Ingress Controller)
    # kubernetes.io/ingress.class: "azure/application-gateway"
    # appgw.ingress.kubernetes.io/ssl-redirect: "true"
    
spec:
  ingressClassName: nginx
  
  # TLS
  tls:
    - hosts:
        - api.company.com
        - app.company.com
      secretName: company-tls-secret    # cert-manager có thể tạo cái này
      
  rules:
    # API server
    - host: api.company.com
      http:
        paths:
          - path: /v1
            pathType: Prefix
            backend:
              service:
                name: api-v1
                port:
                  number: 80
          - path: /v2
            pathType: Prefix
            backend:
              service:
                name: api-v2
                port:
                  number: 80
                  
    # Frontend app
    - host: app.company.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
                  
    # Default backend (no host match)
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: default-backend
                port:
                  number: 80
```

### 2.4 cert-manager - Auto SSL Certificates

```bash
# cert-manager tự động tạo và renew Let's Encrypt certificates

# Cài đặt
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# ClusterIssuer (Let's Encrypt)
kubectl apply -f - << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@company.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# Ingress với cert-manager (auto TLS!)
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Tự động xin cert!
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.company.com
      secretName: app-company-tls    # cert-manager sẽ tạo secret này
  rules:
    - host: app.company.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
EOF
```

---

## 3. ConfigMaps & Secrets

### 3.1 ConfigMap - Non-sensitive Configuration

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
  
data:
  # Key-value pairs
  db_host: "postgres.production.svc.cluster.local"
  db_port: "5432"
  db_name: "myapp"
  redis_host: "redis.production.svc.cluster.local"
  log_level: "info"
  
  # File content (multi-line)
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            proxy_pass http://backend:8080;
            proxy_set_header Host $host;
        }
    }
    
  config.yaml: |
    database:
      host: postgres.production.svc.cluster.local
      port: 5432
      name: myapp
    redis:
      host: redis.production.svc.cluster.local
      port: 6379
    logging:
      level: info
      format: json
```

```yaml
# Sử dụng ConfigMap trong Pod
spec:
  containers:
    - name: myapp
      # Cách 1: Inject từng key thành env var
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: db_host
              
      # Cách 2: Inject tất cả keys thành env vars
      envFrom:
        - configMapRef:
            name: myapp-config
            
      volumeMounts:
        - name: config
          mountPath: /etc/myapp/
          
  volumes:
    # Cách 3: Mount files
    - name: config
      configMap:
        name: myapp-config
        items:
          - key: config.yaml
            path: config.yaml    # Mount thành /etc/myapp/config.yaml
          - key: nginx.conf
            path: nginx.conf
```

```bash
# Create ConfigMap từ command
kubectl create configmap myapp-config \
  --from-literal=db_host=postgres \
  --from-literal=db_port=5432

# Từ file
kubectl create configmap nginx-config \
  --from-file=nginx.conf

# Từ directory
kubectl create configmap app-config \
  --from-file=./config/

# Xem
kubectl get configmap myapp-config -o yaml
kubectl describe configmap myapp-config
```

### 3.2 Secrets - Sensitive Data

```yaml
# Secrets tương tự ConfigMap nhưng cho sensitive data
# QUAN TRỌNG: K8s Secrets mặc định chỉ base64 encoded, KHÔNG encrypted!
# → Cần enable encryption at rest hoặc dùng external secret managers

apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: production
type: Opaque    # Generic secret

data:
  # Values phải base64 encoded!
  db_password: U3VwZXJTZWNyZXQxMjMh    # base64("SuperSecret123!")
  api_key: c2stMTIzNDU2Nzg5MA==
  
# Hoặc dùng stringData (K8s tự encode)
stringData:
  db_password: "SuperSecret123!"        # Plain text → K8s tự base64 encode
  api_key: "sk-1234567890"
```

```bash
# Create secret
kubectl create secret generic myapp-secrets \
  --from-literal=db_password="SuperSecret123!" \
  --from-literal=api_key="sk-1234567890"

# TLS secret
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.company.com \
  --docker-username=myuser \
  --docker-password=mypassword

# Xem secret (decoded)
kubectl get secret myapp-secrets -o jsonpath='{.data.db_password}' | base64 -d

# ===== EXTERNAL SECRETS (Best Practice) =====
# Dùng External Secrets Operator để sync từ Azure Key Vault

# Cài External Secrets Operator
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# SecretStore - trỏ tới Azure Key Vault
kubectl apply -f - << 'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-key-vault
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: "https://kv-myapp-prod.vault.azure.net"
      serviceAccountRef:
        name: external-secrets-sa
        namespace: external-secrets
EOF

# ExternalSecret - sync từ Azure Key Vault vào K8s Secret
kubectl apply -f - << 'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  refreshInterval: 1h     # Sync mỗi giờ
  secretStoreRef:
    name: azure-key-vault    # ClusterSecretStore ở trên
    kind: ClusterSecretStore
  target:
    name: myapp-secrets          # K8s Secret sẽ được tạo
    creationPolicy: Owner
  data:
    - secretKey: db_password
      remoteRef:
        key: postgres-admin-password   # Azure Key Vault secret name
    - secretKey: api_key
      remoteRef:
        key: external-api-key
EOF
```

### 3.3 Sealed Secrets - Encrypt Secrets for Git

```bash
# Kubeseal: Encrypt secrets để commit vào Git an toàn

# Cài controller
helm install sealed-secrets -n kube-system \
  --set-string fullnameOverride=sealed-secrets-controller \
  sealed-secrets/sealed-secrets

# Cài kubeseal CLI
brew install kubeseal

# Encrypt secret
kubectl create secret generic myapp-secret \
  --from-literal=db_password="SuperSecret123!" \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-myapp-secret.yaml

# sealed-myapp-secret.yaml có thể commit vào Git!
# Controller trong cluster sẽ decrypt và tạo K8s Secret thực

git add sealed-myapp-secret.yaml
git commit -m "Add sealed secrets"
```

---

## 4. Persistent Storage

### 4.1 PersistentVolume & PersistentVolumeClaim

```yaml
# PersistentVolume - Admin tạo, represent actual storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: myapp-data-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce          # RWO: 1 node, RWX: many nodes, ROX: many nodes read-only
  persistentVolumeReclaimPolicy: Retain  # Retain, Delete, Recycle
  storageClassName: managed-premium

  # Azure Disk (CSI driver - khuyến nghị)
  csi:
    driver: disk.csi.azure.com
    volumeHandle: "/subscriptions/<SUB_ID>/resourceGroups/rg-myapp/providers/Microsoft.Compute/disks/myapp-data-disk"
    volumeAttributes:
      fsType: ext4

  # Hoặc Azure Files (RWX support):
  # csi:
  #   driver: file.csi.azure.com
  #   volumeHandle: myapp-fileshare
  #   volumeAttributes:
  #     shareName: myapp-data
  #     storageAccountName: myappstorage

---
# PersistentVolumeClaim - Developer request storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data-pvc
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: standard     # Match PV storageClassName
  
# K8s tự động bind PVC → PV phù hợp

---
# Dùng PVC trong Pod
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: myapp-data-pvc
  containers:
    - name: myapp
      volumeMounts:
        - name: data
          mountPath: /data
```

### 4.2 StorageClass - Dynamic Provisioning

```yaml
# StorageClass cho phép dynamic provisioning
# Không cần tạo PV thủ công

# Azure Disk StorageClass (Premium SSD - khuyến nghị cho production)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # Mặc định
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS       # Premium_LRS, StandardSSD_LRS, Standard_LRS
  cachingMode: ReadOnly
  kind: Managed
reclaimPolicy: Delete                        # Delete PV khi PVC bị xóa
allowVolumeExpansion: true                   # Cho phép resize (Azure Disk support)
volumeBindingMode: WaitForFirstConsumer      # Tạo disk trong AZ của Pod

---
# Azure Files StorageClass (RWX - nhiều pods mount cùng lúc)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
  storageAccount: myappaksfiles
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0

---
# PVC với StorageClass (dynamic provisioning)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd    # Sử dụng StorageClass
  resources:
    requests:
      storage: 50Gi
# → K8s tự động tạo EBS volume và PV!
```

---

## 5. StatefulSets - Stateful Applications

```yaml
# StatefulSet cho databases, message queues, etc.
# Khác Deployment:
# - Pods có tên ổn định: pod-0, pod-1, pod-2
# - Ordered deployment/scaling
# - Persistent storage per Pod

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
  
spec:
  serviceName: postgres-headless   # Headless service cho DNS
  replicas: 3
  
  selector:
    matchLabels:
      app: postgres
      
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          
          env:
            - name: POSTGRES_DB
              value: myapp
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secrets
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secrets
                  key: password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
              
          ports:
            - containerPort: 5432
            
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
              
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "4Gi"
              cpu: "2"
              
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - pg_isready -U postgres
            initialDelaySeconds: 10
            periodSeconds: 5
            
  # Volume template - Mỗi Pod gets OWN PVC
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi

---
# Headless service cho StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
    
# DNS của từng Pod:
# postgres-0.postgres-headless.production.svc.cluster.local
# postgres-1.postgres-headless.production.svc.cluster.local
# postgres-2.postgres-headless.production.svc.cluster.local
```

---

## 6. DaemonSet - Run on Every Node

```yaml
# DaemonSet: Chạy 1 Pod trên EVERY node
# Dùng cho: Log collectors, monitoring agents, network plugins

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
  
spec:
  selector:
    matchLabels:
      app: fluentd
      
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccountName: fluentd
      
      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1.16
          
          env:
            - name: FLUENT_ELASTICSEARCH_HOST
              value: "elasticsearch.monitoring"
            - name: FLUENT_ELASTICSEARCH_PORT
              value: "9200"
              
          resources:
            requests:
              memory: "200Mi"
              cpu: "100m"
            limits:
              memory: "500Mi"
              cpu: "200m"
              
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
              
      # Toleration để chạy trên master nodes nếu cần
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
          
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
```

---

## 7. Jobs & CronJobs

```yaml
# Job: Chạy đến completion (batch processing)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  completions: 1        # Cần bao nhiêu successful completions
  parallelism: 1        # Chạy bao nhiêu Pods song song
  backoffLimit: 3       # Retry tối đa 3 lần
  
  template:
    spec:
      restartPolicy: Never    # OnFailure hoặc Never (không phải Always!)
      containers:
        - name: migration
          image: myapp:2.1.0
          command: ["./migrate.sh"]

---
# CronJob: Scheduled jobs
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"          # Cron syntax: 2AM daily
  concurrencyPolicy: Forbid       # Allow, Forbid, Replace
  successfulJobsHistoryLimit: 3   # Keep last 3 successful
  failedJobsHistoryLimit: 1       # Keep last 1 failed
  
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: backup-tool:latest
              command:
                - /bin/bash
                - -c
                - |
                  pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > /backup/$(date +%Y%m%d).sql
                  az storage blob upload-batch \
                    --destination company-backups \
                    --source /backup/ \
                    --account-name myappbackupstore
```

---

> **Tiếp theo: Phần 3** - Scaling, Scheduling, RBAC & Security
