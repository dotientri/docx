# ---
markmap:
  title: "Kubernetes — Overview"
  collapse: false
# ---

# 🧠 KUBERNETES TỪ A ĐẾN Z - GIẢI THÍCH BẰNG LỜI

## Theory
- Kubernetes is a container orchestration system that provides a declarative control plane (API server, etcd, scheduler, controllers) and worker nodes running kubelet/kube-proxy to manage pods, services, storage, and networking at scale.

## Practice
- Start with `minikube`, `kind`, or `k3s` for local clusters; use `kubectl` to inspect the control plane, pods, services, and logs. Validate cluster health with `kubectl get nodes,pods,svc -A` and backup `etcd` regularly.

## 1. Kubernetes Ra Đời Để Giải Quyết Gì?

### 1.1 Bài Toán Thực Tế
- 50 microservices, mỗi cái cần: HA, auto-restart, scale, rolling updates, service discovery, LB, health monitoring
- Làm thủ công với shell scripts = **nightmare**

### 1.2 K8s Giải Quyết
- Tự động hóa **deploy, scale, operate** containerized apps
- **Container Orchestration** = nhạc trưởng điều phối dàn nhạc

## 2. Tại Sao K8s Phức Tạp?

### 2.1 Bài Toán Distributed Systems
- Hàng nghìn containers trên hàng chục/trăm servers
- Server nào còn capacity?
- Container crash → restart ở đâu?
- Container A biết container B đang ở đâu (IP thay đổi)?
- Secrets (passwords) inject vào containers thế nào?

### 2.2 Kết Luận
- Mỗi vấn đề có thể viết cả quyển sách
- K8s giải quyết **tất cả** → phức tạp là tất nhiên

## 3. Control Plane - "Não" Của Kubernetes

### 3.1 kube-apiserver - Cổng Vào Duy Nhất
- **Mọi thứ** trong K8s đều qua API server
- `kubectl` gọi REST API → apiserver
- Node kubelet báo cáo → apiserver
- **Single source of truth** về cluster state
- Validate requests (schema đúng? permission đúng?) → persist vào etcd

### 3.2 etcd - Database Của K8s
- **Distributed key-value store**
- Lưu toàn bộ cluster state: pods, configs, secrets, services
- Deploy 3 hoặc 5 nodes (quorum-based)
- etcd down = không thể tạo/xóa pods (pods đang chạy vẫn OK nhưng không quản lý được)

### 3.3 kube-scheduler - "Người Tuyển Dụng"
- Pod mới cần chạy → scheduler quyết định node nào

#### Xem Xét Gì?
- **Resource requests**: Pod cần 2 CPU, 4GB RAM
- **Node selector/Affinity**: "Chỉ chạy trên nodes zone=us-east-1a"
- **Taints/Tolerations**: "Node chỉ dành cho GPU workloads"
- **Anti-affinity**: "Không đặt 2 replicas cùng app trên 1 node"
- **Actual resources**: Node có đủ allocatable?

### 3.4 kube-controller-manager - Vòng Lặp Điều Hòa
- Trái tim của K8s automation
- Nhiều controllers, mỗi cái: **actual state → desired state**

#### Deployment Controller
- "Desired: 3 replicas app-v2. Actual: 2 v1 + 1 v2" → tạo v2, xóa v1

#### Node Controller
- Node không heartbeat 40s → "NotReady"
- Sau 5 phút → evict pods, reschedule nơi khác

#### ReplicaSet Controller
- Đảm bảo số pods = replicas spec

## 4. Worker Nodes - "Tay Chân" Của K8s

### 4.1 kubelet - Agent Trên Mỗi Node
1. Watch API server: "Có Pod assign cho node này?"
2. Có → gọi container runtime start containers
3. Monitor: healthy? unhealthy?
4. Report status về API server
5. Chạy probes (liveness, readiness, startup)

### 4.2 kube-proxy - Routing Rules
- Quản lý iptables/IPVS rules
- ClusterIP `10.96.100.50:80` → forward đến pod IPs
- Pod restart IP mới → Endpoints update → kube-proxy update rules → traffic tự động đúng

### 4.3 Container Runtime
- **containerd** hoặc CRI-O
- Pull images, create/start/stop containers
- Network setup (gọi CNI plugin)

## 5. Pod - Tại Sao Không Deploy Container Trực Tiếp?

### 5.1 Pod = Wrapper Quanh Containers

### 5.2 Shared Network Namespace
- Containers trong cùng Pod chia sẻ **1 IP + localhost**
- Container A và B communicate qua `localhost:port`
- **Sidecar pattern**: App + logging sidecar → cần chung filesystem + network

### 5.3 Shared Storage
- Volumes mount ở Pod level → tất cả containers access chung

### 5.4 Atomic Scheduling
- Tất cả containers trong Pod → deploy lên **cùng 1 node**

### 5.5 Pod Là Ephemeral
- Pod die → **chết luôn**, không tự reschedule
- Phải dùng **Deployment/StatefulSet** để đảm bảo số pods

## 6. Deployment - Tại Sao Quan Trọng Nhất?

### 6.1 Deployment → ReplicaSet → Pod
- **Deployment** = spec mô tả app (image, replicas, resources)
- Deployment tạo **ReplicaSet** → ReplicaSet tạo **Pods**

### 6.2 Tại Sao 2 Layer?
1. Update image → Deployment tạo **ReplicaSet MỚI**
2. Tăng dần replicas mới, giảm dần replicas cũ
3. **Rolling update**: zero-downtime
4. Rollback = scale lại ReplicaSet cũ → **instant rollback**

### 6.3 Deployment vs StatefulSet
#### Deployment (Stateless)
- Pods giống nhau (interchangeable)
- Tên random: `api-7f9d8c-xyz`
- Thứ tự không quan trọng

#### StatefulSet (Stateful)
- Tên dự đoán: `postgres-0`, `postgres-1`
- Tạo/xóa **theo thứ tự** (0→1→2)
- Mỗi Pod có PersistentVolume riêng

## 7. Service - Tại Sao Không Dùng Pod IP?

### 7.1 Vấn Đề
- Pod restart → IP **thay đổi** → hardcode IP = fail

### 7.2 Service Giải Quyết
- **Stable virtual IP** (ClusterIP) không bao giờ thay đổi
- Dùng **label selector** để tìm pods
- Pod restart, vẫn có label → Service tự update backend

### 7.3 Endpoints Object
- K8s auto maintain danh sách pod IPs cho mỗi Service
- Pod tạo/xóa → Endpoints update → kube-proxy update routing

## 8. Ingress - Tại Sao Không Dùng LoadBalancer?

### 8.1 Vấn Đề LoadBalancer Service
- Mỗi `type: LoadBalancer` = 1 external LB = 1 external IP
- 10 microservices = 10 LBs = **tốn tiền, khó quản lý**

### 8.2 Ingress Giải Quyết
- **1 Ingress Controller** + **1 external IP**
- Routing rules phân traffic:
  - `api.company.com/users` → users-service
  - `api.company.com/orders` → orders-service
- **TLS termination** tập trung

### 8.3 Ingress Controller vs Ingress Object
#### Ingress Controller
- Phần mềm thực sự chạy (Nginx pod, Traefik pod)

#### Ingress Object
- YAML config định nghĩa routing rules
- **Không có Controller → Ingress object vô dụng**

### 8.4 Trong AKS
- **AGIC**: Dùng Azure Application Gateway
- Hoặc Nginx Ingress Controller + LoadBalancer Service

## 9. ConfigMap & Secret

### 9.1 Tại Sao Tách Config Khỏi Code?
- Staging và production: **cùng code, khác config**
- Secrets **không commit vào Git**
- Thay đổi config **không rebuild image**

### 9.2 ConfigMap
- Non-sensitive: database host, port, log level, feature flags

### 9.3 Secret
- Sensitive: passwords, API keys, certificates
- ⚠️ Mặc định chỉ **base64 encoded**, KHÔNG encrypted

### 9.4 Bảo Mật Secret Thực Sự
- **etcd encryption at rest**: AES-256
- **Azure Key Vault + CSI Driver**: Secrets pull từ AKV runtime
- **Sealed Secrets**: Encrypt bằng public key, chỉ cluster controller decrypt

## 10. HPA - Horizontal Pod Autoscaler

### 10.1 Vấn Đề
- Traffic fluctuates: Black Friday 100x vs 3AM gần zero
- Fix 10 replicas → lãng phí 90% thời gian

### 10.2 Cách Hoạt Động
1. Check metrics mỗi **15 giây** (mặc định)
2. Actual CPU 80%, target 50%
3. `ceil(3 × 80/50)` = **5 replicas**
4. Scale deployment lên 5

### 10.3 Scale Up vs Scale Down
- **Scale up**: Ngay lập tức (traffic đang tăng)
- **Scale down**: Chờ **5 phút** ổn định (tránh flapping)

### 10.4 VPA (Vertical Pod Autoscaler)
- Thay vì thêm pods → điều chỉnh **resources request/limit**
- "Thay vì 10 pods × 1CPU, dùng 5 pods × 2CPU"
- Thường dùng **recommendation mode** (gợi ý, không tự apply)

## 11. Helm - Package Manager Cho K8s

### 11.1 Vấn Đề Không Có Helm
- Deploy cần nhiều YAML: Deployment, Service, ConfigMap, Ingress, HPA...
- Mỗi environment values khác nhau → copy-paste = **error-prone**

### 11.2 Helm Giải Quyết
#### Chart
- Package chứa **templates + default values**

#### Values
- Mỗi environment: `values-staging.yaml`, `values-production.yaml`

#### Release
- Instance deployed: `helm install myapp ./chart -f values-prod.yaml`

#### Rollback
- `helm rollback myapp 2` = rollback về version 2

### 11.3 Tại Sao Helm Quan Trọng?
- K8s ecosystem đã adopt Helm làm **standard**
- Prometheus, Grafana, cert-manager đều có official Helm charts

## 12. K3s vs AKS

### 12.1 K3s - Kubernetes Nhẹ
- Single binary ~100MB
- Dùng SQLite thay etcd
- Chạy tốt 1 vCPU, 512MB RAM

#### Dùng Khi
- Edge computing, IoT, home lab, development, small production

#### Không Dùng Khi
- Large-scale (hundreds of nodes), enterprise support

### 12.2 AKS - Azure Managed K8s
- Microsoft quản lý Control plane (miễn phí)
- 1-click upgrade, tích hợp Azure AD/Monitor/LB
- Bạn chỉ trả tiền **worker nodes**

#### Dùng Khi
- Production, enterprise features, Azure ecosystem

#### Trade-off
- Less control, vendor lock-in
