# ---
markmap:
  title: "Kubernetes — Fundamentals & Architecture"
  collapse: false
# ---

# ☸️ KUBERNETES TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

## Theory
- Core architecture: control plane components (`kube-apiserver`, `etcd`, `kube-scheduler`, `controller-manager`) manage desired state; worker nodes run `kubelet` and `kube-proxy` to host Pods and route traffic.

## Practice
- Install local clusters with `minikube`/`kind`/`k3s`, use `kubectl` to inspect resources, configure `kubeconfig` contexts, and ensure etcd backups and HA control plane in production.

## 1. Kubernetes Là Gì?

### 1.1 Vấn Đề Docker Giải Quyết... Nhưng Chưa Đủ

Docker giải quyết packaging và isolation. Nhưng khi scale lên:

```
Không có Kubernetes:
- 100 containers trên 10 servers → Quản lý thủ công
- Server chết → Containers chết, không tự restart
- Load balancing → Tự cấu hình
- Updates → Downtime hoặc script phức tạp
- Secrets → Truyền qua environment variables không an toàn
- Health checks → Tự implement
- Scaling → Thủ công
```

#### Kubernetes (K8s) giải quyết
- **Self-healing:** Pod chết → K8s tự restart
- **Auto-scaling:** Load tăng → K8s tự thêm instances
- **Rolling updates:** Zero-downtime deployments
- **Service discovery:** Containers tự tìm thấy nhau
- **Load balancing:** Tự động distribute traffic
- **Secret management:** Mã hóa và inject secrets
- **Storage orchestration:** Dynamic provisioning

### 1.2 Kubernetes = Container Orchestration Platform

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                        │
│                                                                  │
│  ┌─────────────────────────┐   ┌──────────────────────────────┐ │
│  │    Control Plane         │   │         Worker Nodes         │ │
│  │  (Master Node)           │   │                              │ │
│  │                          │   │  ┌────────┐  ┌────────┐     │ │
│  │  ┌──────────────────┐   │   │  │Node 1  │  │Node 2  │     │ │
│  │  │   kube-apiserver  │   │   │  │        │  │        │     │ │
│  │  │  (API Gateway)    │   │   │  │ ┌────┐ │  │ ┌────┐ │     │ │
│  │  └──────────────────┘   │   │  │ │Pod │ │  │ │Pod │ │     │ │
│  │                          │   │  │ └────┘ │  │ └────┘ │     │ │
│  │  ┌──────────────────┐   │   │  │ ┌────┐ │  │ ┌────┐ │     │ │
│  │  │    etcd          │   │   │  │ │Pod │ │  │ │Pod │ │     │ │
│  │  │  (Cluster state) │   │   │  │ └────┘ │  │ └────┘ │     │ │
│  │  └──────────────────┘   │   │  └────────┘  └────────┘     │ │
│  │                          │   │                              │ │
│  │  ┌──────────────────┐   │   │  ┌────────┐                 │ │
│  │  │ kube-scheduler   │   │   │  │Node 3  │                 │ │
│  │  └──────────────────┘   │   │  │        │                 │ │
│  │                          │   │  │ ┌────┐ │                 │ │
│  │  ┌──────────────────┐   │   │  │ │Pod │ │                 │ │
│  │  │ controller-manager│  │   │  │ └────┘ │                 │ │
│  │  └──────────────────┘   │   │  └────────┘                 │ │
│  └─────────────────────────┘   └──────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```


## 2. Kiến Trúc Chi Tiết

### 2.1 Control Plane Components

#### kube-apiserver
- API gateway duy nhất của cluster
- Xác thực và ủy quyền mọi request
- Validate và persist resources vào etcd
- kubectl, dashboard, operators đều giao tiếp qua API server

#### etcd
- Distributed key-value store
- Lưu toàn bộ state của cluster
- Highly available (consensus với Raft algorithm)
- **CRITICAL:** Backup etcd = backup toàn bộ cluster!

#### kube-scheduler
- Quyết định Pod nên chạy ở Node nào
- Xem xét: resource requirements, node capacity, affinity rules, taints/tolerations
- Scheduling policies: spread, binpack, most/least requested

#### kube-controller-manager
- Tập hợp các controllers chạy trong 1 process
- Deployment Controller, ReplicaSet Controller, Node Controller, Endpoint Controller...
- Watch state → Compare với desired → Take action

#### cloud-controller-manager
- Tích hợp với cloud provider (AWS, GCP, Azure)
- Quản lý: Load Balancers, Storage volumes, Node lifecycle

### 2.2 Worker Node Components

#### kubelet
- Agent chạy trên mỗi worker node
- Nhận PodSpec từ API Server
- Đảm bảo containers trong Pod đang chạy và healthy
- Report node/pod status lên API Server

#### kube-proxy
- Network proxy chạy trên mỗi node
- Implement K8s Service networking (iptables/IPVS rules)
- Load balancing traffic đến Pods

#### Container Runtime
- containerd (phổ biến nhất)
- CRI-O (RedHat)
- Docker (deprecated)


## 3. Cài Đặt Kubernetes

### 3.1 Local Development - minikube

```bash
# ===== MINIKUBE (Single-node cluster cho dev) =====
# Cài đặt
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start                          # Default driver
minikube start --driver=docker          # Docker driver
minikube start --cpus=4 --memory=8192  # More resources
minikube start --kubernetes-version=v1.29.0

# Quản lý
minikube status
minikube stop
minikube delete
minikube dashboard                      # Web UI

# Addons
minikube addons list
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# Tạo tunnel cho LoadBalancer services
minikube tunnel

# SSH vào node
minikube ssh

# ===== KIND (K8s in Docker - Multi-node) =====
# Tốt hơn để test multi-node scenarios
go install sigs.k8s.io/kind@v0.20.0

cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

kind create cluster --config=kind-config.yaml --name=myapp
kind delete cluster --name=myapp

# ===== K3S (Lightweight K8s) =====
# Production-ready nhưng nhẹ, tốt cho edge/IoT
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get node
```

### 3.2 kubectl - CLI Client

```bash
# Cài kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# ===== KUBECONFIG =====
# Default: ~/.kube/config
kubectl config view
kubectl config get-contexts         # Xem tất cả contexts
kubectl config current-context      # Context hiện tại
kubectl config use-context prod     # Switch context
kubectl config set-context --current --namespace=myapp  # Default namespace

# Merge nhiều kubeconfig files
export KUBECONFIG=~/.kube/config:~/.kube/staging.yaml:~/.kube/prod.yaml
kubectl config view --merge --flatten > ~/.kube/merged.yaml

# kubectx và kubens (helper tools)
brew install kubectx
kubectx                 # List và switch contexts
kubens                  # List và switch namespaces
```


## 4. Kubernetes Objects - Building Blocks

### 4.1 Pod - Đơn Vị Nhỏ Nhất

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  namespace: default
  labels:                           # Labels cho selector
    app: myapp
    version: v1
    environment: production
  annotations:                      # Metadata, không dùng làm selector
    kubernetes.io/description: "Main application pod"
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    
spec:
  # ===== CONTAINERS =====
  containers:
    - name: myapp                   # Container name
      image: myapp:2.1.0            # Image
      
      ports:
        - name: http
          containerPort: 8080
          protocol: TCP
          
      # Resource limits/requests
      resources:
        requests:                   # Minimum guaranteed
          memory: "256Mi"
          cpu: "250m"              # 250m = 0.25 vCPU
        limits:                    # Maximum allowed
          memory: "512Mi"
          cpu: "500m"
          
      # Environment variables
      env:
        - name: APP_ENV
          value: "production"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:        # Từ ConfigMap
              name: myapp-config
              key: db_host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:           # Từ Secret
              name: myapp-secrets
              key: db_password
              
      # Volume mounts
      volumeMounts:
        - name: config-volume
          mountPath: /etc/myapp/config
          readOnly: true
        - name: data-volume
          mountPath: /data
          
      # Health checks
      readinessProbe:               # Traffic sent khi Ready
        httpGet:
          path: /health/ready
          port: 8080
        initialDelaySeconds: 10
        periodSeconds: 5
        failureThreshold: 3
        
      livenessProbe:                # Restart nếu Unhealthy
        httpGet:
          path: /health/live
          port: 8080
        initialDelaySeconds: 30
        periodSeconds: 10
        failureThreshold: 3
        
      startupProbe:                 # Cho slow-starting apps
        httpGet:
          path: /health/started
          port: 8080
        failureThreshold: 30
        periodSeconds: 10
        
      # Lifecycle hooks
      lifecycle:
        preStop:
          exec:
            command: ["/bin/sh", "-c", "sleep 15"]  # Graceful shutdown
            
      # Security context
      securityContext:
        runAsUser: 1000
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
          
  # Sidecar container
    - name: log-forwarder
      image: fluentd:v1.16
      volumeMounts:
        - name: log-volume
          mountPath: /var/log/myapp
          
  # Init container (chạy trước main containers)
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nc -z $DB_HOST 5432; do echo waiting; sleep 2; done']
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: db_host
              
  # ===== VOLUMES =====
  volumes:
    - name: config-volume
      configMap:
        name: myapp-config
    - name: data-volume
      persistentVolumeClaim:
        claimName: myapp-data-pvc
    - name: log-volume
      emptyDir: {}                  # Shared giữa containers trong Pod
      
  # ===== POD SETTINGS =====
  restartPolicy: Always             # Always, OnFailure, Never
  terminationGracePeriodSeconds: 30
  serviceAccountName: myapp
  
  # Node selection
  nodeSelector:
    kubernetes.io/arch: amd64
    node-type: app
    
  # Tolerations (run on tainted nodes)
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "app"
      effect: "NoSchedule"
```

### 4.2 Deployment - Quản Lý Pods

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
    
spec:
  replicas: 3                       # Số Pods
  
  selector:
    matchLabels:
      app: myapp                    # Chọn Pods nào để manage
      
  # Rolling update strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1                   # Max Pods vượt quá replicas khi update
      maxUnavailable: 0             # Max Pods down khi update (0 = zero-downtime)
      
  template:
    metadata:
      labels:
        app: myapp                  # PHẢI match selector
        version: v2.1.0
    spec:
      containers:
        - name: myapp
          image: company/myapp:2.1.0
          
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
              
          ports:
            - containerPort: 8080
            
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
```

```bash
# ===== DEPLOYMENT COMMANDS =====
kubectl apply -f deployment.yaml

# Xem Deployments
kubectl get deployments
kubectl get deploy -n production
kubectl describe deployment myapp

# Scale
kubectl scale deployment myapp --replicas=5

# Update image (rolling update)
kubectl set image deployment/myapp myapp=company/myapp:2.2.0

# Xem rollout status
kubectl rollout status deployment/myapp
# Waiting for deployment "myapp" rollout to finish: 1 out of 3 new replicas have been updated...

# Xem rollout history
kubectl rollout history deployment/myapp
kubectl rollout history deployment/myapp --revision=2

# Rollback
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=3

# Pause và resume (canary-like)
kubectl rollout pause deployment/myapp
kubectl rollout resume deployment/myapp

# Restart (tạo lại Pods với image mới nếu có)
kubectl rollout restart deployment/myapp
```


## 5. Namespaces - Isolation

```bash
# Namespace = Virtual cluster trong cluster
# Dùng để: Phân chia environments, teams, applications

# Xem namespaces
kubectl get namespaces
# NAME              STATUS   AGE
# default           Active   10d
# kube-system       Active   10d   ← K8s system components
# kube-public       Active   10d   ← Public readable
# kube-node-lease   Active   10d   ← Node heartbeats

# Tạo namespace
kubectl create namespace production
kubectl create namespace staging

# Namespace manifest
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    team: backend
EOF

# Chạy trong namespace
kubectl get pods -n production
kubectl get all -n production
kubectl get all --all-namespaces    # Tất cả namespaces

# Set default namespace
kubectl config set-context --current --namespace=production
kubectl get pods                    # Bây giờ mặc định là production

# ResourceQuota cho namespace
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    pods: "100"
    persistentvolumeclaims: "20"
    services.loadbalancers: "5"
EOF

kubectl describe resourcequota -n production

# LimitRange - Default limits cho Pods
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "4Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
EOF
```


## 6. kubectl Quick Reference

```bash
# ===== GET - Xem resources =====
kubectl get pods
kubectl get pods -o wide            # Thêm IP, Node info
kubectl get pods -o yaml            # Full YAML
kubectl get pods -o json
kubectl get pods --sort-by='.metadata.creationTimestamp'
kubectl get pods --field-selector=status.phase=Running

# Label selectors
kubectl get pods -l app=myapp
kubectl get pods -l 'app in (myapp, api)'
kubectl get pods -l 'app!=monitoring'

# Watch mode
kubectl get pods -w
kubectl get events -w

# ===== DESCRIBE - Chi tiết =====
kubectl describe pod myapp-xxx
kubectl describe node node1
kubectl describe service myapp

# ===== LOGS =====
kubectl logs pod-name
kubectl logs pod-name -c container-name    # Specific container
kubectl logs pod-name -f                   # Follow
kubectl logs pod-name --tail=100           # Last 100 lines
kubectl logs pod-name --since=1h           # Last 1 hour
kubectl logs -l app=myapp                  # All pods với label
kubectl logs pod-name --previous           # Previous crashed container

# ===== EXEC - Run commands =====
kubectl exec -it pod-name -- bash
kubectl exec -it pod-name -c container -- sh
kubectl exec pod-name -- ls /etc
kubectl exec pod-name -- env | grep APP_

# ===== PORT FORWARD =====
kubectl port-forward pod/pod-name 8080:8080
kubectl port-forward service/myapp 8080:80
kubectl port-forward deployment/myapp 8080:8080

# ===== COPY FILES =====
kubectl cp pod-name:/etc/app/config.yaml ./local-config.yaml
kubectl cp ./local-file.txt pod-name:/tmp/

# ===== APPLY & DELETE =====
kubectl apply -f manifest.yaml
kubectl apply -f ./k8s/                    # Tất cả files trong thư mục
kubectl apply -f ./k8s/ --recursive
kubectl delete -f manifest.yaml
kubectl delete pod pod-name
kubectl delete pod pod-name --grace-period=0  # Force delete

# ===== LABELS & ANNOTATIONS =====
kubectl label pod pod-name app=myapp
kubectl label pod pod-name environment=prod --overwrite
kubectl annotate pod pod-name description="Main app"

# ===== TOP (Resource usage) =====
kubectl top nodes                   # Node resource usage
kubectl top pods                    # Pod resource usage
kubectl top pods -n production
```
