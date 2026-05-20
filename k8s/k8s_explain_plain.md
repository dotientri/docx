# 🧠 GIẢI THÍCH BẰNG LỜI - KUBERNETES TỪ A ĐẾN Z

---

## 1. Kubernetes ra đời để giải quyết vấn đề gì?

**Scenario:** Công ty có 50 microservices. Mỗi service cần:
- Deploy lên nhiều servers (để HA)
- Auto-restart khi crash
- Scale up khi traffic tăng, scale down khi traffic giảm
- Rolling updates (không downtime)
- Service discovery (service A biết địa chỉ của service B)
- Load balancing
- Health monitoring

Làm thủ công với shell scripts và cron jobs = nightmare. Sai sót, không consistent.

**Kubernetes** = hệ thống tự động hóa việc deploy, scale, và operate containerized applications. Tự làm tất cả những điều trên.

**"Container Orchestration"** - orchestrate = điều phối, giống nhạc trưởng điều phối dàn nhạc.

---

## 2. Tại sao K8s lại phức tạp vậy?

K8s giải quyết bài toán thực sự phức tạp: **Distributed systems**.

Khi bạn có hàng nghìn containers chạy trên hàng chục/trăm servers:
- Server nào đang còn capacity để chạy container mới?
- Container trên server X crash → tự restart ở đâu?
- Khi deploy version mới, làm sao update từng container mà không gây downtime?
- Container A cần biết container B đang chạy ở đâu (IP, port), nhưng B có thể di chuyển giữa servers?
- Secrets (passwords, API keys) cần inject vào containers mà không expose trong code?

Mỗi vấn đề trên có thể viết cả quyển sách. K8s giải quyết tất cả, nên phức tạp là tất nhiên.

---

## 3. Control Plane - "Não" của Kubernetes

Control plane không chạy apps của bạn - nó **quản lý** cluster, quyết định điều gì xảy ra và điều phối workers.

**kube-apiserver - Cổng vào duy nhất:**

Mọi thứ trong K8s đều thông qua API server. `kubectl get pods` → kubectl gọi REST API của apiserver. Node kubelet báo cáo status → gọi apiserver. Controller cập nhật state → gọi apiserver.

API server là "single source of truth" về cluster state. Nó validate mọi request (schema đúng không? user có permission không?), rồi persist vào etcd.

**etcd - "Database" của K8s:**

etcd = distributed key-value store, lưu toàn bộ cluster state. Có bao nhiêu pods, config của mỗi pod, secrets, service definitions...

Tại sao distributed? Nếu etcd có 1 node, nó down = toàn bộ control plane down = không thể tạo/xóa pods (pods đang chạy vẫn chạy nhưng không thể quản lý). Thường deploy 3 hoặc 5 etcd nodes (quorum-based).

**kube-scheduler - "Người tuyển dụng":**

Khi có Pod mới cần chạy (chưa có nodeName), scheduler quyết định node nào "hire" Pod đó.

Scheduler xem xét:
- **Resource requests:** Pod cần 2 CPU, 4GB RAM → node phải có ít nhất đó
- **Node selector/Affinity:** "Pod này chỉ chạy trên nodes có label `zone=us-east-1a`"
- **Taints/Tolerations:** "Node này chỉ dành cho GPU workloads, pods thường không được schedule"
- **Anti-affinity:** "Không đặt 2 replicas của cùng 1 app trên cùng 1 node (để HA)"
- **Actual availability:** Node có đủ allocatable resources không?

**kube-controller-manager - Tập hợp các "vòng lặp điều hòa":**

Đây là trái tim của K8s automation. Gồm nhiều controllers, mỗi cái watch một loại resource và đảm bảo "actual state = desired state".

*Deployment Controller:* "Desired state: 3 replicas app-v2. Actual: 2 replicas app-v1, 1 replica app-v2." → Tạo thêm 1 replica app-v2, xóa 1 replica app-v1. Lặp lại cho đến khi match.

*Node Controller:* Watch nodes. Node không heartbeat trong 40s? Mark as "NotReady". Sau 5 phút? Evict tất cả pods trên node đó, reschedule ở nơi khác.

*ReplicaSet Controller:* Đảm bảo số pods đúng với replicas spec.

---

## 4. Worker Nodes - "Tay chân" của K8s

**kubelet - Agent trên mỗi node:**

kubelet chạy trên mỗi worker node, là cầu nối giữa API server và container runtime.

kubelet liên tục:
1. Watch API server: "Có Pod nào được assign cho node này không?"
2. Nếu có: gọi container runtime (containerd) để start containers
3. Monitor containers: healthy? unhealthy?
4. Report status về API server: Pod running, container restart count, resource usage

kubelet cũng chạy probes (liveness, readiness, startup) và act accordingly.

**kube-proxy - "Bảng định tuyến" của Services:**

kube-proxy chạy trên mỗi node, quản lý network rules (iptables hoặc IPVS) để implement Services.

Khi bạn tạo Service với ClusterIP `10.96.100.50:80`, kube-proxy tạo iptables rules trên mỗi node: "Packet đến `10.96.100.50:80` → forward đến một trong các pods `10.244.1.5:3000` hoặc `10.244.2.7:3000`".

Khi Pod restart với IP mới, Endpoints object update → kube-proxy update iptables rules → traffic tự động đến Pod mới.

**Container Runtime - "Người thực sự chạy container":**

containerd (hoặc CRI-O) là container runtime, được kubelet gọi để:
- Pull images từ registry
- Create/start/stop containers
- Manage container storage (overlayfs layers)
- Network setup (gọi CNI plugin)

---

## 5. Pod - Tại sao không deploy Container trực tiếp?

**Pod** = wrapper xung quanh 1 hoặc nhiều containers, với shared storage và network namespace.

**Tại sao cần Pod thay vì deploy container thẳng?**

*Shared network namespace:* Các containers trong cùng Pod chia sẻ 1 IP address và localhost. Container A và B trong cùng Pod có thể communicate qua `localhost:port` mà không cần Service.

Useful cho **sidecar pattern**: App container + logging sidecar container, sidecar read log files và forward đến log aggregator. Chúng cần filesystem access chung và network access dễ dàng.

*Shared storage:* Volumes được mount ở Pod level, tất cả containers trong Pod có thể access cùng volumes.

*Atomic scheduling:* Scheduler deploy cả Pod (tất cả containers) lên cùng 1 node. Đảm bảo sidecar container luôn cùng node với main container.

**Pod là ephemeral (tạm thời):**

Pod không tự heal. Nếu Pod die, nó chết luôn - không được reschedule. Đó là lý do không ai tạo Pod trực tiếp - thay vào đó dùng Deployment hoặc StatefulSet, chúng mới có trách nhiệm đảm bảo số pods đúng.

---

## 6. Deployment - Tại sao quan trọng nhất?

**Deployment** = "Spec" mô tả app bạn muốn chạy: image, replicas, resources, env vars...

Deployment tạo ReplicaSet → ReplicaSet tạo Pods.

**Tại sao có 2 layer Deployment → ReplicaSet → Pod?**

Khi bạn update Deployment (đổi image version):
1. Deployment tạo ReplicaSet MỚI với image mới
2. Tăng dần replicas của ReplicaSet mới
3. Giảm dần replicas của ReplicaSet cũ
4. Rolling update: zero-downtime

Nếu cần rollback, Deployment chỉ cần scale lại ReplicaSet cũ (vẫn còn đó, chỉ có 0 replicas) → instant rollback.

**Deployment vs StatefulSet:**

*Deployment* = stateless apps. Pods giống nhau hoàn toàn (interchangeable). Tên pods random: `api-7f9d8c-xyz`. Thứ tự tạo/xóa không quan trọng.

*StatefulSet* = stateful apps (databases, Kafka, ZooKeeper). Pods có tên dự đoán được: `postgres-0`, `postgres-1`, `postgres-2`. Tạo và xóa theo thứ tự (0→1→2 khi scale up, 2→1→0 khi scale down). Mỗi Pod có PersistentVolume riêng không bị xóa khi Pod xóa.

---

## 7. Service - Tại sao không dùng Pod IP trực tiếp?

**Vấn đề:** Pod IPs thay đổi. Khi Pod restart, nó có IP mới. Nếu Service B hardcode IP của Service A's pod, sẽ fail khi pod A restart.

**Service** = stable virtual IP (ClusterIP) không bao giờ thay đổi. Service dùng **label selector** để tìm pods.

```
Service (ClusterIP: 10.96.100.50) → selector: {app: api}
                                                    ↓
                                  Pods với label {app: api}:
                                  - 10.244.1.5  (node-1)
                                  - 10.244.2.7  (node-2)
                                  - 10.244.3.12 (node-3)
```

Khi pod restart với IP mới, nó vẫn có label `app: api` → Service tự cập nhật backend.

**ClusterIP** không có nghĩa là IP của cluster - nó là "virtual IP chỉ accessible từ trong cluster." External traffic không reach được ClusterIP.

**Endpoints object:** K8s tự maintain object này listing actual pod IPs cho mỗi Service. Khi Pod tạo/xóa/restart → Endpoints tự update → kube-proxy update routing rules.

---

## 8. Ingress - Tại sao không dùng Service LoadBalancer cho mọi thứ?

**LoadBalancer Service vấn đề:**

Mỗi `type: LoadBalancer` Service tạo 1 external load balancer (Azure LB, AWS ELB). Mỗi cái có external IP riêng. 10 microservices = 10 external LBs = 10 external IPs = tốn tiền, khó quản lý.

**Ingress giải quyết:**

1 Ingress Controller (Nginx, Traefik, etc.) với 1 external IP. Routing rules quyết định traffic đến đâu:
- `api.company.com/users` → users-service
- `api.company.com/orders` → orders-service
- `admin.company.com` → admin-service

TLS termination tập trung: Decrypt HTTPS một lần ở Ingress, forward HTTP nội bộ. Certificates manage ở 1 nơi.

**Ingress Controller vs Ingress object:**

*Ingress Controller* = phần mềm thực sự chạy (Nginx pod, Traefik pod...), watch Ingress objects và configure mình theo.

*Ingress object* = YAML config định nghĩa routing rules. Không có Ingress Controller thì Ingress object vô dụng.

**Trong AKS:** Azure cung cấp AGIC (Application Gateway Ingress Controller) - dùng Azure Application Gateway làm Ingress. Hoặc dùng Nginx Ingress Controller với LoadBalancer Service.

---

## 9. ConfigMap và Secret - Tại sao tách cấu hình ra khỏi code?

**"12-Factor App" principle:** Configuration phải tách khỏi code.

**Tại sao?**
- Staging và production cùng code nhưng khác config (database URL, API keys)
- Secrets (passwords, API keys) không được commit vào Git
- Thay đổi config không cần rebuild image

**ConfigMap** = non-sensitive config (database host, port, log level, feature flags).

**Secret** = sensitive data (passwords, API keys, certificates).

**Quan trọng:** K8s Secrets mặc định chỉ được base64 encoded, KHÔNG encrypted. Ai có quyền đọc secrets trong namespace là đọc được. Base64 decode là trivial.

**Để thực sự bảo mật:**
- Enable etcd encryption at rest (data trong etcd được mã hóa bằng AES-256)
- Dùng Azure Key Vault + CSI Driver: Secrets không lưu trong K8s etcd, pull từ AKV vào runtime
- Sealed Secrets: Encrypt secret bằng public key, chỉ cluster controller có private key decrypt

---

## 10. Horizontal Pod Autoscaler (HPA) - Tự động scale

**Vấn đề:** Traffic fluctuates. Black Friday: 100x traffic bình thường. 3 giờ sáng: gần như zero.

Nếu fix 10 replicas: Lãng phí 90% thời gian, insuffcient trong Black Friday.

**HPA giải quyết:**

HPA watch metrics (CPU, memory, custom metrics từ Prometheus) và tự động điều chỉnh số replicas.

**Cách hoạt động:**

1. HPA controller check metrics mỗi 15 giây (mặc định)
2. So sánh actual với target: Actual CPU = 80%, target = 50%
3. Tính desired replicas: `ceil(current_replicas × (actual/target))` = `ceil(3 × (80/50))` = 5
4. Scale deployment lên 5 replicas

**Scale down chậm hơn scale up (deliberate design):**

Scale up: Ngay lập tức khi cần (traffic đang tăng → cần capacity nhanh)
Scale down: Chờ 5 phút ổn định mới scale down (tránh "flapping" - scale up/down liên tục vì load oscillate)

**VPA (Vertical Pod Autoscaler):**

Thay vì thêm pods, VPA điều chỉnh resources request/limit của từng pod. "Thay vì 10 pods × 1CPU, dùng 5 pods × 2CPU."

Thường dùng VPA ở recommendation mode - nó gợi ý values nhưng không tự apply (vì thay đổi resources = pod restart).

---

## 11. Helm - Package Manager cho Kubernetes

**Vấn đề khi không có Helm:**

Deploy app lên K8s cần nhiều YAML files: Deployment, Service, ConfigMap, Secret, Ingress, HPA, ServiceAccount, RBAC...

Mỗi environment (dev, staging, prod) cần values khác nhau. Copy-paste và sửa = error-prone, không maintainable.

**Helm giải quyết:**

*Chart* = package chứa templates + default values. Templates dùng Go template syntax để parameterize.

*Values* = parameters override defaults. Mỗi environment có `values-staging.yaml`, `values-production.yaml`.

*Release* = instance của chart deployed vào cluster. `helm install myapp ./chart -f values-prod.yaml`

Helm track revision history. `helm rollback myapp 2` = rollback về version 2.

**Tại sao Helm quan trọng:**

Kubernetes ecosystem đã adopt Helm làm standard. Hầu hết open-source tools (prometheus, grafana, cert-manager, nginx-ingress) cung cấp official Helm charts. Thay vì tự viết YAML, bạn chỉ cần `helm install cert-manager jetstack/cert-manager`.

---

## 12. K3s vs AKS - Khi nào dùng cái nào?

**K3s** = Kubernetes nhẹ, single binary ~100MB, chạy tốt trên VM nhỏ (1 vCPU, 512MB RAM), Raspberry Pi.

Tại sao nhẹ hơn K8s đầy đủ?
- Không có etcd mặc định → dùng SQLite (lightweight) hoặc PostgreSQL/MySQL
- Containerd thay vì Docker
- Không có nhiều cloud-specific features
- Loại bỏ alpha/legacy features

*Dùng K3s khi:* Edge computing, IoT, home lab, development environment, small-scale production (dưới 5 nodes), CI/CD runners.

*Không dùng K3s khi:* Large-scale production (hundreds of nodes), cần enterprise support, complex networking (service mesh).

**AKS (Azure Kubernetes Service)** = Managed K8s trên Azure.

Microsoft lo:
- Control plane (kube-apiserver, etcd, scheduler...) - bạn không quản lý, không trả tiền
- Upgrades (1-click upgrade K8s version)
- Integration với Azure (Azure AD, Azure Monitor, Azure LB, Azure Disks...)
- Node OS patches

Bạn chỉ trả tiền cho worker nodes (VMs).

*Dùng AKS khi:* Production workloads, cần enterprise features, team không muốn quản lý control plane, đã dùng Azure ecosystem.

*Trade-off:* Less control, vendor lock-in (nếu migrate sang on-prem hoặc AWS sẽ có khác biệt).
