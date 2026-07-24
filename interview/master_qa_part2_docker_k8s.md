# 🚀 BỘ CÂU HỎI PHỎNG VẤN DEVOPS THỰC TẾ (PHẦN 2: DOCKER & KUBERNETES)
*Mức độ: Intern, Fresher, Junior*

Tiếp nối Phần 1, Phần 2 này đi sâu vào mảng Containerization (Docker) và Container Orchestration (Kubernetes). Đây là kỹ năng xương sống của bất kỳ kỹ sư DevOps nào.

---

## 🐳 PHẦN 5: DOCKER & CONTAINERIZATION (Câu 66 - 95)

**66. Giải thích sự khác biệt cốt lõi giữa Container và Virtual Machine (VM)?**
* **Trả lời:** VM ảo hóa ở mức phần cứng (Hardware-level virtualization) thông qua Hypervisor, mỗi VM chạy một hệ điều hành khách (Guest OS) riêng biệt, nặng nề, khởi động mất phút. Container ảo hóa ở mức hệ điều hành (OS-level virtualization), các container dùng chung một Kernel với máy host (thông qua namespace và cgroups), siêu nhẹ, khởi động trong tính bằng giây.

**67. Namespaces và Cgroups trong Linux liên quan gì đến Docker?**
* **Trả lời:** Đây là 2 công nghệ nền tảng của container. 
  - `Namespaces`: Tạo ra sự "cách ly" (Isolation). Phân chia Process ID, Network, Mount point,... để container A không nhìn thấy network hay process của container B.
  - `Cgroups` (Control Groups): Giới hạn "tài nguyên" (Resource limitation). Giới hạn container A chỉ được dùng tối đa 1GB RAM và 20% CPU.

**68. Giải thích kiến trúc của Docker (Docker Engine)?**
* **Trả lời:** Gồm 3 phần:
  1. **Docker Client**: CLI (`docker run`, `docker build`) để người dùng gõ lệnh.
  2. **Docker Daemon (`dockerd`)**: Chạy ngầm trên host, lắng nghe API từ client, quản lý images, containers, networks, volumes.
  3. **Containerd & runc**: Thành phần thực sự tương tác với Linux Kernel để chạy và quản lý vòng đời container.

**69. Sự khác biệt giữa `CMD` và `ENTRYPOINT` trong Dockerfile?**
* **Trả lời:** 
  - `ENTRYPOINT`: Là lệnh *bắt buộc* sẽ được chạy khi container start. Khó bị ghi đè (override) khi dùng lệnh `docker run`.
  - `CMD`: Cung cấp các tham số (arguments) mặc định cho `ENTRYPOINT`, hoặc chạy một lệnh mặc định. Rất dễ bị ghi đè khi gõ `docker run <image> <command_mới>`.
  - *Thực tế:* Thường kết hợp: `ENTRYPOINT ["nginx"]` và `CMD ["-g", "daemon off;"]`.

**70. Tại sao trong Dockerfile, người ta thường COPY `package.json` (hoặc `requirements.txt`) và chạy Install Dependencies TRƯỚC, sau đó mới COPY toàn bộ source code?**
* **Trả lời:** Để tận dụng cơ chế **Layer Caching** của Docker. Source code thường xuyên bị thay đổi, nếu COPY source code lên trước, mọi layer phía sau (kể cả bước `npm install` rất lâu) đều bị invalidate (vô hiệu hóa) cache và phải chạy lại từ đầu. Đưa `package.json` lên trước giúp Docker dùng lại cache của bước install nếu danh sách thư viện không đổi.

**71. Multi-stage build trong Docker là gì? Tại sao phải dùng?**
* **Trả lời:** Là kỹ thuật viết nhiều `FROM` trong một Dockerfile. Stage đầu tiên (builder) dùng base image bự (chứa compiler, dev tools) để build code. Stage cuối cùng dùng base image cực nhỏ (như `alpine` hoặc `distroless`), chỉ copy đúng file thực thi (binary/build folder) từ stage trước sang.
  - *Lợi ích:* Giảm kích thước image từ 1GB xuống còn vài chục MB, tăng tốc độ pull image, giảm bề mặt tấn công bảo mật (giảm CVEs).

**72. Docker Volume khác gì với Bind Mount?**
* **Trả lời:** 
  - **Volume**: Được Docker tự động tạo và quản lý trong thư mục `/var/lib/docker/volumes/`. An toàn, dễ backup, dễ chia sẻ giữa các container. (Nên dùng).
  - **Bind Mount**: Trỏ trực tiếp một thư mục cụ thể trên Host OS (vd: `/home/user/data`) vào container. Phụ thuộc vào cấu trúc thư mục của máy Host. Thường dùng trong môi trường Dev để hot-reload code.

**73. Làm sao để dọn dẹp các container đã tắt, image lửng lơ (dangling), và volume không dùng tới để giải phóng ổ cứng?**
* **Trả lời:** Chạy lệnh `docker system prune -a --volumes`. (Cẩn thận: Lệnh này sẽ xóa sạch sành sanh mọi thứ không đang chạy).

**74. Các loại Network mặc định trong Docker? (Bridge, Host, None)**
* **Trả lời:**
  - `bridge`: Mặc định. Tạo một dải IP private ảo. Các container trong cùng bridge giao tiếp qua IP ảo này. Cần port mapping (`-p`) để ra ngoài.
  - `host`: Bỏ qua cơ chế cách ly mạng. Container xài chung IP và Port với máy Host. (Ví dụ app chạy port 80 trong container thì sẽ chiếm port 80 của host luôn). Nhanh nhưng kém an toàn.
  - `none`: Không có mạng, hoàn toàn cô lập.
  - `overlay`: Dùng trong Docker Swarm để kết nối container xuyên qua nhiều máy chủ vật lý khác nhau.

**75. Bạn chạy lệnh `docker run -d my-app`, nhưng gõ `docker ps` lại không thấy nó. Bạn sẽ debug thế nào?**
* **Trả lời:** 
  1. Gõ `docker ps -a` để xem container đã bị thoát (Exited) với mã lỗi bao nhiêu.
  2. Gõ `docker logs <container_id>` để đọc log xem app báo lỗi gì (thường do thiếu biến môi trường, sai cấu hình, hoặc app không có process nào chạy foreground).
  3. Nếu log không có gì, gõ `docker inspect <container_id>` để xem chi tiết metadata (ExitCode, OOMKilled).

**76. Container bị crash liên tục khởi động lại (Restart loop). Làm sao để vào bên trong nó sửa file cấu hình?**
* **Trả lời:** Vì nó chết ngay lập tức nên không thể `docker exec` vào được. Cách xử lý: Dùng lệnh `docker run` chạy lại image đó nhưng ghi đè entrypoint: `docker run -it --entrypoint /bin/sh <image_name>`. Sau đó sửa file hoặc debug thủ công.

**77. Tham số `-p 8080:80` nghĩa là gì? Khác gì với `-P` (chữ P hoa)?**
* **Trả lời:** `-p 8080:80` map port 80 của container ra port 8080 của máy Host. Ai truy cập IP_Host:8080 sẽ vào được app. `-P` sẽ tự động map tất cả các port được khai báo `EXPOSE` trong Dockerfile ra các port ngẫu nhiên trên máy Host (từ 32768 trở lên).

**78. Làm sao để giới hạn Container chỉ được dùng tối đa 512MB RAM và 0.5 CPU?**
* **Trả lời:** Truyền cờ khi chạy: `docker run --memory="512m" --cpus="0.5" <image>`. Nếu vượt quá RAM, container sẽ bị kernel bắn chết (OOMKilled). Nếu vượt quá CPU, nó chỉ bị chạy chậm lại (Throttling).

**79. Làm sao để chia sẻ data giữa 2 container đang chạy?**
* **Trả lời:** Tạo một Docker Volume, sau đó mount volume đó vào cả 2 container: `docker run -v shared_data:/app/data ...`

**80. Trong `docker-compose.yml`, từ khóa `depends_on` dùng để làm gì? Có đảm bảo database chạy xong thì app mới chạy không?**
* **Trả lời:** `depends_on` xác định thứ tự khởi động (App sẽ đợi DB khởi động trước). **TUY NHIÊN**, theo mặc định nó chỉ đợi container DB *start*, chứ KHÔNG đợi database *sẵn sàng nhận kết nối* (ready). 
  - *Cách khắc phục:* Khai báo thêm `healthcheck` trong service DB, và trong app khai báo `depends_on: db: condition: service_healthy`.

**81. Làm sao để copy một file từ máy Host vào trong 1 container đang chạy?**
* **Trả lời:** Dùng lệnh `docker cp file.txt <container_id>:/path/to/destination/`. (Cũng có thể copy ngược ra bằng cách đảo vị trí).

**82. Nếu Dockerfile có chỉ định `USER root`, điều gì rủi ro sẽ xảy ra?**
* **Trả lời:** Rủi ro Privilege Escalation. Nếu hacker chiếm được quyền điều khiển app trong container, chúng có quyền root, và nếu kết hợp với lỗ hổng kernel (hoặc container chạy chế độ `--privileged`), hacker có thể thoát ra ngoài và kiểm soát cả máy chủ vật lý.
  - *Best practice:* Luôn tạo và dùng non-root user ở bước cuối của Dockerfile.

**83. Tệp `.dockerignore` có tác dụng gì?**
* **Trả lời:** Giống `.gitignore`. Ngăn chặn việc COPY các file không cần thiết (như `node_modules`, `.git`, file `.env` chứa mật khẩu) từ máy host vào image khi gọi `COPY . .`. Giúp image nhỏ hơn và bảo mật hơn.

**84. Phân biệt Image Tag và Image Digest?**
* **Trả lời:** 
  - **Tag** (vd: `nginx:latest`, `nginx:1.21`): Là con trỏ có thể thay đổi (mutable). Người ta có thể push một bản build mới đè lên tag cũ.
  - **Digest** (vd: `nginx@sha256:123abc...`): Là mã băm bất biến (immutable) của image. Deploy bằng Digest đảm bảo 100% môi trường dev, staging, prod chạy đúng duy nhất 1 phiên bản không bị sai lệch.

**85. Làm sao để xem một container đang ăn bao nhiêu RAM/CPU trực tiếp (real-time)?**
* **Trả lời:** Gõ lệnh `docker stats`.

*(Từ câu 86 - 95: Tập trung thực hành)*
**86. Docker Daemon không khởi động được, bạn check log ở đâu?** -> Dùng `journalctl -u docker.service` hoặc check `/var/log/syslog`.
**87. Trong Compose, `restart: unless-stopped` khác `restart: always` chỗ nào?** -> `always` luôn khởi động lại dù bạn đã stop nó thủ công trước khi tắt server. `unless-stopped` sẽ không tự bật lên lại nếu nó đã bị stop thủ công.
**88. Để chạy app Node.js, bạn chọn base image nào: `node:20` hay `node:20-alpine`?** -> `alpine`, vì nó cực nhẹ (~5MB hệ điều hành base) thay vì bản gốc dựa trên Debian nặng hàng trăm MB.
**89. Bạn cần truyền API Key vào container, dùng cách nào an toàn nhất?** -> Không hardcode vào image. Truyền qua `--env-file` hoặc dùng Secret manager khi xài Orchestrator.
**90. Sự khác biệt giữa lệnh `docker create` và `docker run`?** -> `create` chỉ setup layer và config nhưng chưa start. `run` = `create` + `start`.
**91. Có thể chạy Docker trong Docker (DinD) không?** -> Có, thường dùng trong hệ thống CI/CD runner để build image.
**92. `docker attach` khác gì `docker exec`?** -> `attach` móc bạn thẳng vào Process số 1 đang chạy (Ctrl+C sẽ kill container). `exec` tạo một process mới (vd `/bin/sh`) để bạn chui vào tương tác mà không đụng chạm PID 1.
**93. OCI (Open Container Initiative) là gì?** -> Là bộ tiêu chuẩn mở do Docker và ngành công nghiệp tạo ra để thống nhất format của image và runtime. Nhờ nó mà K8s có thể bỏ Docker xài Containerd.
**94. "Docker Hub Rate Limit" là gì và làm sao để vượt qua?** -> Bị giới hạn 100 pull/6 tiếng cho IP ẩn danh. Cần login (auth) để nâng limit, hoặc tự host registry riêng (Harbor, ACR, ECR).
**95. Image Scanning là gì? Kể tên vài tool?** -> Là quá trình soi các lớp image tìm lỗ hổng bảo mật (CVEs) của các gói phần mềm bên trong. Tools: Trivy, Clair, Anchore, Docker Scout.

---

## ☸️ PHẦN 6: KUBERNETES (K8S) (Câu 96 - 140)

**96. Kiến trúc tổng quan của Kubernetes gồm những gì?**
* **Trả lời:** Chia làm 2 phần chính:
  1. **Control Plane (Master Node):** Bộ não. Gồm `kube-apiserver` (giao tiếp mọi thứ), `etcd` (Database lưu trạng thái cluster), `kube-scheduler` (chọn Node để đặt Pod), `kube-controller-manager` (giám sát, giữ trạng thái mong muốn).
  2. **Worker Nodes (Data Plane):** Nơi chạy app. Gồm `kubelet` (Agent quản lý Pod trên node), `kube-proxy` (quản lý Network/Iptables cho Service), và Container Runtime (containerd, CRI-O).

**97. Vai trò của `etcd` là gì? Điều gì xảy ra nếu etcd bị mất dữ liệu?**
* **Trả lời:** `etcd` là kho lưu trữ Key-Value phân tán lưu TOÀN BỘ trạng thái, cấu hình, secrets của K8s. Nếu mất etcd và không có backup, toàn bộ Cluster coi như chết, K8s sẽ quên hết mọi Deployment, Pod, Service.

**98. Khi bạn gõ `kubectl apply -f deployment.yaml`, luồng xử lý bên trong diễn ra như thế nào?**
* **Trả lời:** 
  1. `kubectl` gửi YAML tới `kube-apiserver` (qua REST API).
  2. API server authenticate/authorize và lưu record vào `etcd`.
  3. `Deployment Controller` thấy có thay đổi, ra lệnh tạo ra một `ReplicaSet`.
  4. `ReplicaSet Controller` tính toán thấy thiếu Pod, ra lệnh tạo `Pod` object trong etcd (trạng thái Pending).
  5. `kube-scheduler` phát hiện Pod chưa có Node, nó chấm điểm và gán Pod cho một Worker Node phù hợp.
  6. `kubelet` trên Worker Node đó nhận được lệnh, gọi Container Runtime kéo image và chạy container.
  7. `kubelet` báo cáo trạng thái "Running" về API server.

**99. Pod là gì? Tại sao K8s không chạy trực tiếp Container mà phải bọc trong Pod?**
* **Trả lời:** Pod là đơn vị triển khai nhỏ nhất trong K8s. Một Pod có thể chứa 1 hoặc nhiều Container. Lý do phải có Pod: Giúp các container xài chung Network Namespace (cùng IP, gọi nhau qua localhost) và chung Storage Volumes. Tiện lợi cho mô hình Sidecar (vd: 1 container chạy app, 1 container đẩy log).

**100. Kể tên các trạng thái (Phases) của một Pod?**
* **Trả lời:** Pending (đang chờ schedule hoặc chờ pull image), Running, Succeeded (chạy xong thành công - cho Job), Failed (crash, lỗi), Unknown (mất kết nối với Node).

**101. Phân biệt `Deployment`, `StatefulSet` và `DaemonSet`?**
* **Trả lời:**
  - **Deployment:** Chạy ứng dụng Stateless (Web, API). Các pod giống hệt nhau, có thể chết và sinh ra ở Node khác bất kỳ lúc nào, không lưu data.
  - **StatefulSet:** Chạy ứng dụng Stateful (Database, Kafka). Đảm bảo Pod có định danh cố định (pod-0, pod-1), khởi động theo thứ tự, và gắn liền với một ổ cứng cố định (Persistent Volume).
  - **DaemonSet:** Đảm bảo trên MỖI Node trong cluster đều chạy ĐÚNG 1 Pod. (Dùng cho monitoring agents như Prometheus node-exporter, Log collector như Fluent-bit, CNI).

**102. Các loại Service trong K8s và Use-case của từng loại?**
* **Trả lời:**
  - **ClusterIP** (Mặc định): Chỉ truy cập được nội bộ trong cluster. Use-case: Kết nối Web tới Database.
  - **NodePort**: Mở một port tĩnh (30000 - 32767) trên mọi Node vật lý. Client vào bằng IP_Node:NodePort. Use-case: Dev/Test hoặc tự setup LoadBalancer ngoài.
  - **LoadBalancer**: Ra lệnh cho Cloud Provider (AWS, Azure) tự động cấp một External Load Balancer và IP Public trỏ vào cluster. Use-case: Expose dịch vụ ra Internet (Production).
  - **ExternalName**: Ánh xạ một tên DNS bên ngoài vào trong cluster (như CNAME). Use-case: Giấu Endpoint của External RDS Database dưới tên alias.

**103. Tại sao Ingress lại cần thiết khi đã có Service LoadBalancer?**
* **Trả lời:** Nếu xài Type LoadBalancer, mỗi service sẽ tốn 1 IP Public (và tốn tiền trên Cloud). **Ingress** đóng vai trò là L7 HTTP/HTTPS Router, chỉ cần 1 IP Public (qua Ingress Controller như NGINX) có thể phân luồng traffic về hàng chục Service khác nhau dựa trên Tên miền (Host) hoặc Đường dẫn (Path: /api, /admin), hỗ trợ cả SSL Termination.

**104. Liveness Probe, Readiness Probe và Startup Probe khác nhau thế nào?**
* **Trả lời:**
  - **Liveness:** Kiểm tra xem app còn SỐNG hay bị treo đơ (deadlock). Nếu fail, Kubelet sẽ **kill và restart** Pod.
  - **Readiness:** Kiểm tra xem app đã SẴN SÀNG nhận traffic chưa (vd: Đang load data vào cache, đang nối DB). Nếu fail, K8s sẽ **ngắt traffic** (xóa IP khỏi Service endpoint), nhưng KHÔNG kill Pod.
  - **Startup:** Dùng cho app khởi động quá lâu (legacy). Trong lúc Startup probe đang chạy, Liveness và Readiness sẽ bị pause, tránh việc app bị kill nhầm vì chưa kịp lên.

**105. K8s ConfigMap và Secret khác nhau chỗ nào? Secret có an toàn không?**
* **Trả lời:** ConfigMap dùng lưu cấu hình dạng plain text. Secret dùng lưu thông tin nhạy cảm (pass, key, cert). **Tuy nhiên**, Secret mặc định KHÔNG AN TOÀN vì nó chỉ mã hóa Base64 (có thể giải mã dễ dàng). 
  - *Thực tế:* Kỹ sư DevOps phải cấu hình mã hóa at-rest cho etcd, hoặc dùng các công cụ xịn như HashiCorp Vault, Azure Key Vault (CSI driver), Sealed Secrets.

**106. HPA (Horizontal Pod Autoscaler) hoạt động dựa trên cơ chế nào?**
* **Trả lời:** HPA liên tục query `metrics-server` (hoặc custom metrics api) để đọc CPU/Memory của các Pods. Nếu mức sử dụng trung bình vượt quá Ngưỡng (Threshold) cấu hình, HPA sẽ tự động tăng số lượng Replicas của Deployment lên. Giảm xuống khi tải giảm.

**107. Resource `Requests` và `Limits` là gì? Hậu quả nếu không set Limits?**
* **Trả lời:**
  - `Requests`: Mức tài nguyên TỐI THIỂU K8s đảm bảo Pod sẽ có. Scheduler dùng số này để tìm Node còn chỗ.
  - `Limits`: Mức TỐI ĐA Pod được xài. Vượt RAM Limit = OOMKilled. Vượt CPU Limit = Throttled (chạy chậm).
  - Nếu không set Limits: Một pod bị memory leak có thể ăn sạch tài nguyên của Node, làm crash cả Node và ảnh hưởng các Pod khác (Noisy Neighbor).

**108. Taints, Tolerations và Node Affinity dùng để làm gì?**
* **Trả lời:** Đây là cách điều hướng Pod vào đúng Node mong muốn:
  - **Taints & Tolerations:** Taints giống "thuốc độc" bôi lên Node (vd: node này chỉ dành cho GPU). Pod nào không có "thuốc giải" (Toleration) thì không được vào (Đẩy ra).
  - **Node Affinity:** Lực hút. Yêu cầu/Khuyến khích Pod phải chạy trên Node có các Label nhất định (vd: disk=ssd) (Kéo vào).

**109. StorageClass, Persistent Volume (PV) và Persistent Volume Claim (PVC) là gì?**
* **Trả lời:**
  - **StorageClass (SC):** Khuôn mẫu định nghĩa loại ổ cứng (Azure Disk, AWS EBS, NFS...).
  - **PVC:** Phiếu yêu cầu ổ cứng từ phía Developer (VD: Tui cần 10GB ổ cứng loại Fast).
  - **PV:** Ổ cứng thực tế được K8s cấp phát (thường do Provisioner tự động tạo ra dựa trên SC để đáp ứng PVC).

**110. Pod của bạn bị lỗi `CrashLoopBackOff`, cách debug từng bước?**
* **Trả lời:**
  1. `kubectl get pods` -> Thấy CrashLoop.
  2. `kubectl logs <pod_name>` -> Đọc lỗi mới nhất.
  3. Quan trọng: Nếu log trống trơn vì vừa sập, xài `kubectl logs <pod_name> --previous` để lấy log của lần sập ngay trước đó.
  4. `kubectl describe pod <pod_name>` -> Đọc phần Events ở dưới cùng để xem có lỗi OOMKilled, Liveness probe failed, hay ImagePullBackOff không.

**111. `ImagePullBackOff` hoặc `ErrImagePull` nghĩa là gì?**
* **Trả lời:** Kubelet không thể kéo image về. Thường do: Sai tên image/tag, không có quyền (thiếu ImagePullSecrets truy cập private registry), hoặc Node bị mất mạng.

**112. RBAC (Role-Based Access Control) trong K8s cấu thành từ các thành phần nào?**
* **Trả lời:** Role (quyền ở mức Namespace) hoặc ClusterRole (quyền toàn cụm). RoleBinding (gắn Role cho User/Group) hoặc ClusterRoleBinding. ServiceAccount (định danh cho Pod/App thay vì người dùng).

**113. Bạn vừa Deploy version mới và code bị lỗi 500, làm sao để Rollback ngay lập tức không downtime?**
* **Trả lời:** 
  Dùng lệnh `kubectl rollout undo deployment/<name>`. 
  Lệnh này sẽ kích hoạt quá trình Rolling Update ngược về ReplicaSet (version) trước đó, xóa từ từ pod lỗi và đẻ lại pod cũ.

**114. Helm là gì? Tại sao K8s lại cần Helm?**
* **Trả lời:** Helm là Package Manager cho K8s (giống `apt` hay `npm`). K8s xài toàn file YAML tĩnh, nếu cần đổi số replicas, tag image cho từng môi trường (Dev/Prod) phải copy paste rất khổ. Helm đóng gói YAML thành Template (Chart), cho phép chèn biến (`Values.yaml`) cực kỳ linh hoạt và quản lý history version dễ dàng.

**115. Pod Eviction là hiện tượng gì?**
* **Trả lời:** Xảy ra khi Node bị áp lực tài nguyên quá lớn (Node Pressure) - vd Disk đầy hoặc RAM cạn. Kubelet sẽ tàn nhẫn "trục xuất" (kill) các Pod có độ ưu tiên thấp (những Pod không cấu hình Requests/Limits hoặc xài lố Requests) sang Node khác để cứu Node.

*(Từ câu 116 - 140: Hỏi đáp nhanh & Thực tế K8s)*
**116. Kubeconfig file lưu ở đâu và chứa gì?** -> Mặc định ở `~/.kube/config`, chứa API server URL, chứng chỉ CA, và Client Key/Token để authenticate.
**117. Làm sao để scale một deployment từ 2 lên 5 pods bằng CLI?** -> `kubectl scale deployment <name> --replicas=5`.
**118. Headless Service là gì?** -> Là Service gán `ClusterIP: None`. Nó không cân bằng tải mà trả trực tiếp danh sách IP của tất cả các Pods phía sau (qua DNS), dùng nhiều cho StatefulSet để các node trong DB tự cluster với nhau.
**119. `kubectl exec -it <pod_name> -- /bin/bash` dùng làm gì?** -> Mở shell chui vào bên trong Pod đang chạy để gõ lệnh (Debug).
**120. Nếu một Worker node bị tắt điện đột ngột, điều gì xảy ra với các Pod trên đó?** -> Sau 5 phút (mặc định), K8s đánh dấu Node là `NotReady`, và tự động tạo lại các Pod bị mất sang các Node còn sống (nếu cấu hình ReplicaSet > 0).
**121. Operator Pattern trong K8s là gì?** -> Là phần mềm "Robot" giám sát (Controller) + Custom Resource Definition (CRD). Giúp tự động hóa các tác vụ vận hành phức tạp của con người (vd: Prometheus Operator, DB Operator tự động backup).
**122. Giải thích Network Policies?** -> Giống như Firewall của K8s. Mặc định mọi Pod trong K8s thông nhau 100%. Network Policy giúp chặn traffic (vd: Chỉ cho phép Backend mới được chọc vào DB).
**123. Làm sao để chạy một đoạn code một lần duy nhất, thành công thì thoát (Ví dụ Database Migration)?** -> Dùng `Job`. Nếu muốn chạy theo lịch định kỳ, dùng `CronJob`.
**124. Thay đổi nội dung của ConfigMap thì Pod có tự động update lấy cấu hình mới không?** -> KHÔNG. Trừ khi ứng dụng được code đặc biệt để tự reload file (hoặc dùng tool như Reloader). Cách phổ biến là restart Deployment.
**125. Cấu trúc `initContainers` là gì?** -> Là container chạy trước container chính. Phải chạy xong (Exit 0) thì app chính mới được chạy. Dùng để clone code, chờ DB khởi động, hoặc cấp quyền thư mục.
**126. `kubectl port-forward` dùng để làm gì?** -> Xuyên hầm từ máy local thẳng vào 1 Pod/Service trong K8s để debug web/database mà không cần cấu hình Ingress hay LoadBalancer.
**127. Ephemeral Storage là gì? Khác gì Persistent Volume?** -> Là dung lượng đĩa tạm thời gắn liền với vòng đời Pod. Pod chết, data bay sạch. Phân biệt với PV lưu dữ liệu an toàn.
**128. Pod đang chạy bị OOMKilled, bạn nên tăng Request hay tăng Limit?** -> Phải tăng Limits (vì vượt limit mới bị kill).
**129. Pod bị mắc kẹt ở trạng thái `Terminating` mãi không xóa được, xử lý sao?** -> Thường do lỗi Finalizers hoặc Volume không tháo được khỏi Node. Gỡ thủ công: `kubectl delete pod <name> --grace-period=0 --force`.
**130. Tại sao cần LimitRange và ResourceQuota?** -> Ngăn chặn Developer tàn phá cluster. ResourceQuota giới hạn tổng CPU/RAM toàn Namespace. LimitRange ép từng Pod phải khai báo Request/Limit mặc định.
**131. CNI phổ biến nhất?** -> Calico (Mạnh về Network Policy), Flannel (Đơn giản), Cilium (Hiện đại, dựa trên eBPF siêu nhanh).
**132. Bạn update Secrets, làm sao để pod nhận secret mới mà không gián đoạn?** -> Dùng lệnh `kubectl rollout restart deployment/<name>`, nó sẽ thực hiện Rolling Update an toàn.
**133. Lệnh xem cluster có bao nhiêu Node và trạng thái?** -> `kubectl get nodes`.
**134. Lệnh để xem tải CPU/RAM của các Nodes và Pods?** -> `kubectl top nodes` và `kubectl top pods` (Yêu cầu phải cài metrics-server).
**135. Blue/Green Deployment khác Rolling Update chỗ nào?** -> Rolling update thay thế từ từ. Blue/Green tạo hẳn một cụm V2 song song bằng 100% tài nguyên V1, test chán chê rồi switch router rụp 1 phát qua. Ít rủi ro nhưng tốn gấp đôi Server.
**136. Kustomize là gì, so với Helm?** -> Kustomize là công cụ (có sẵn trong kubectl) dùng cơ chế Patch (ghi đè cấu hình) base YAML. Không xài Template engine như Helm.
**137. ServiceAccount token mount vào pod mặc định nằm ở đâu?** -> `/var/run/secrets/kubernetes.io/serviceaccount/`. Bị hacker lấy được file này có thể dùng API thao túng cluster.
**138. Control Plane có tự phục hồi (HA) được không?** -> Có, với mô hình 3 hoặc 5 Master Nodes chạy etcd cluster (Raft consensus algorithm).
**139. Horizontal (HPA) vs Vertical Pod Autoscaler (VPA)?** -> HPA tăng số lượng Pod (Scale Out). VPA tự động tăng RAM/CPU cho Pod đang chạy (Scale Up). Thường không dùng cả 2 cùng 1 lúc cho CPU.
**140. Tóm tắt một CI/CD pipeline xài K8s điển hình?** -> Git push -> Jenkins build Image -> Push sang Harbor/ACR -> Cập nhật YAML tag -> ArgoCD (GitOps) tự động detect và sync cấu hình xuống K8s.

---
*(Phần tiếp theo: [Phần 3](master_qa_part3_hr_cicd_monitoring_cloud_troubleshooting.md) sẽ tập trung vào HR, Jenkins/CI-CD, Monitoring, Azure và Troubleshooting)*
