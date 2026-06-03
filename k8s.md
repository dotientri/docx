# 8. Nền tảng Kubernetes (K8s)

## Ngày 49: Bức tranh toàn cảnh về Kubernetes
- **Điều phối container (Container Orchestration):** Quản lý toàn bộ vòng đời (triển khai, scaling, tự phục hồi) của hàng ngàn container một cách tự động.
- **Tại sao cần K8s?**
  - **Service Discovery & Load Balancing:** Tự động phân phối traffic giữa các Pods.
  - **Storage Orchestration:** Tự động gắn kết các loại lưu trữ (Local, Cloud).
  - **Self-healing:** Tự động thay thế/khởi động lại các container bị lỗi.
  - **Zero-downtime:** Cập nhật ứng dụng mà không gây gián đoạn dịch vụ.
- **Kiến trúc Cluster:**
  - **Control Plane:** "Bộ não" điều hành.
    - **API Server:** Cửa ngõ giao tiếp chính (REST API).
    - **Scheduler:** Quyết định Pod chạy trên Worker Node nào.
    - **Controller Manager:** Duy trì trạng thái mong muốn (desired state).
    - **etcd:** Cơ sở dữ liệu lưu trữ cấu hình/trạng thái cluster.
  - **Worker Node:** "Sức mạnh" tính toán.
    - **kubelet:** Agent điều phối container trên mỗi node.
    - **kube-proxy:** Quản lý quy tắc mạng.
    - **Container Runtime:** (Docker, containerd, CRI-O).
- **Resources chính:**
  - **Pod:** Đơn vị nhỏ nhất, chứa 1 hoặc nhiều container cùng chia sẻ network/storage.
  - **Deployment:** Quản lý các Pod, cho phép update/rollback.
  - **ReplicaSet:** Đảm bảo số lượng Pod luôn đúng.
  - **StatefulSet:** Dành cho DB, đảm bảo định danh Pod duy nhất và dữ liệu ổn định.
  - **DaemonSet:** Chạy 1 Pod trên MỌI node (log/monitoring).
  - **Service:** Tạo Endpoint ổn định (IP/DNS) cho các Pods.

## Ngày 50: Các nền tảng chạy Kubernetes
- **Cục bộ (Local - Dev/Test):**
  - **Minikube:** Cluster 1 node, dễ dùng, tích hợp nhiều addon.
  - **Kind (Kubernetes in Docker):** Chạy các node K8s bên trong Docker containers. Rất nhẹ và nhanh.
- **Quản lý (Managed Services - Cloud):** Giao Control Plane cho nhà cung cấp.
  - **EKS** (AWS), **AKS** (Azure), **GKE** (GCP).
- **Tự quản lý (Self-managed):**
  - **Bare-Metal:** Chạy trực tiếp trên phần cứng vật lý.
  - **Virtual Machines:** Chạy trên cluster VM (VMware, vSphere).
  - **Rancher:** Nền tảng quản lý đa cluster (multi-cluster) qua GUI.

## Ngày 51: Triển khai Cluster đầu tiên (Minikube)
- **Cài đặt:** `arkade get minikube`, `arkade get kubectl`.
- **Khởi tạo:** `minikube start --driver=docker --addons=ingress`.
- **Lệnh quản trị (kubectl):**
  - `kubectl get nodes`: Kiểm tra trạng thái Cluster.
  - `kubectl get pods -A`: Xem tất cả Pods ở mọi namespace.
  - `kubectl describe <resource> <name>`: Xem chi tiết trạng thái, lỗi (rất quan trọng để debug).
  - `kubectl delete <resource> <name>`: Xóa tài nguyên.
- **Tên rút gọn:** `po` (pods), `deploy` (deployments), `svc` (services), `ns` (namespaces), `no` (nodes).

## Ngày 52: Thiết lập Cluster đa Node (Vagrant/VM)
- **Mục tiêu:** Mô phỏng thực tế với 1 Master + N Worker nodes.
- **Vagrant:** Tự động tạo VM bằng code.
- **Quy trình triển khai (Scripting):**
  - **Common.sh:** Cài container runtime (Containerd), kubeadm, kubelet, kubectl trên tất cả node.
  - **Master.sh:** `kubeadm init` để khởi tạo Cluster.
  - **Worker.sh:** `kubeadm join` để kết nối vào Master.
- **Xác thực:** Copy file `~/.kube/config` từ Master về máy Host để dùng `kubectl` từ máy thật.

## Ngày 53: Quản trị với Rancher
- **Tính năng:** GUI tập trung, quản lý RBAC (phân quyền), bảo mật, Marketplace ứng dụng.
- **Triển khai:** `docker run -d --privileged -p 80:80 -p 443:443 rancher/rancher`.
- **Kết nối Cluster:** Rancher cung cấp dòng lệnh `docker run ... rancher-agent` để dán vào các Worker Node, biến chúng thành cluster quản lý qua Rancher.

## Ngày 54: Triển khai ứng dụng (YAML & Helm)
- **YAML:** Định nghĩa trạng thái mong muốn (Namespace, Deployment, Service).
  - `kubectl apply -f app.yaml`: Áp dụng cấu hình.
- **Scaling:**
  - `kubectl scale deployment <name> --replicas=3`.
- **Truy cập (Service):**
  - **ClusterIP:** Mặc định, chỉ gọi được trong cluster.
  - **NodePort:** Mở port trên mỗi node (30000-32767).
  - **LoadBalancer:** Cung cấp IP từ cloud provider.
- **Helm:** Trình quản lý gói cho K8s.
  - `helm install <release_name> <chart_name>`: Cài đặt app phức tạp chỉ với 1 lệnh.

## Ngày 55: State & Ingress
- **Stateful Apps:** Dùng `StatefulSet` để đảm bảo dữ liệu (DB) không mất khi Pod khởi động lại.
- **Persistent Storage:**
  - **StorageClass:** Định nghĩa "loại" ổ đĩa.
  - **PV (Persistent Volume):** Ổ đĩa vật lý/cloud.
  - **PVC (Persistent Volume Claim):** Yêu cầu (yêu sách) ổ đĩa từ PV.
- **Ingress:**
  - Lớp định tuyến thông minh (Lớp 7 - HTTP/HTTPS).
  - Hỗ trợ định tuyến dựa trên Hostname (domain) hoặc Path (đường dẫn URL).
  - Cần **Ingress Controller** (ví dụ Nginx Ingress).
- **Config & Secrets:**
  - **ConfigMaps:** Chứa file cấu hình, biến môi trường (plain text).
  - **Secrets:** Chứa mật khẩu, token (mã hóa base64/tự động mã hóa).

  ## Thuật ngữ

  - **Cluster:** Tập hợp Control Plane và Worker Nodes chạy Kubernetes.
  - **Pod:** Đơn vị nhỏ nhất có thể deploy, chứa 1 hoặc nhiều container chia sẻ network và volume.
  - **Deployment:** Resource khai báo mong muốn về số lượng replica của Pod, cho phép update/rollback.
  - **ReplicaSet:** Đảm bảo số lượng Pod phù hợp với khai báo.
  - **Service:** Cung cấp IP/DNS ổn định để truy cập nhóm Pod (ClusterIP, NodePort, LoadBalancer).
  - **Ingress / Ingress Controller:** Định tuyến L7, xử lý hostname/path, TLS termination.
  - **ConfigMap / Secret:** Cung cấp cấu hình không nhạy cảm / nhạy cảm cho Pod.
  - **StatefulSet:** Triển khai stateful application cần định danh và lưu trữ bền vững.
  - **DaemonSet:** Đảm bảo 1 Pod chạy trên mọi node (ví dụ: log collector).
  - **kubelet:** Agent trên mỗi node chịu trách nhiệm khởi tạo và giám sát container.
  - **etcd:** Kho dữ liệu key-value phân tán lưu trữ state cluster.
  - **Control Plane:** Tập hợp các thành phần điều khiển (API Server, Scheduler, Controller Manager).