# 🐳 DOCKER TOÀN TẬP - PHẦN 1: LÝ THUYẾT NỀN TẢNG

> **Đọc theo thứ tự:** P1 → P2 → P3 → P4 → P5

---

## 1. Docker Là Gì? Tại Sao Cần Dùng?

### 1.1 Vấn Đề "Works On My Machine"

Đây là tình huống thực tế trong doanh nghiệp:

```
Dev A (Windows 11, Python 3.11, Node 18):
  → Code chạy OK trên máy mình ✅

Dev B (macOS, Python 3.9, Node 16):
  → Chạy bị lỗi ❌

Server Production (Ubuntu 20.04, Python 3.8):
  → Lại lỗi khác ❌❌

→ Cả team mất 2 ngày debug môi trường, không ai làm được tính năng mới
```

**Docker giải quyết vấn đề này** bằng cách đóng gói **toàn bộ môi trường** (OS libraries, runtime, dependencies, config, code) vào một **container** duy nhất. Container đó chạy **giống hệt nhau** ở mọi nơi.

### 1.2 Docker Là Gì (Định Nghĩa Chính Xác)

**Docker** là một nền tảng mã nguồn mở để:
- **Build** (đóng gói) ứng dụng và môi trường của nó vào một **image**
- **Ship** (vận chuyển) image đó đến bất kỳ đâu
- **Run** (chạy) image thành **container** - một tiến trình cô lập

> Hãy nghĩ Docker như một **"cái hộp tiêu chuẩn"** trong vận chuyển hàng hải.
> Trước đây: mỗi hàng hóa có hình dạng khác nhau, khó xếp. 
> Sau khi có container chuẩn: ship hàng đi khắp thế giới, tàu nào cũng chở được.

### 1.3 Lợi Ích Thực Tế Trong Doanh Nghiệp

| Lợi ích | Trước Docker | Sau Docker |
|---------|-------------|-----------|
| Onboard dev mới | 1-2 ngày setup môi trường | 5 phút: `docker compose up` |
| Deploy production | Downtime 30 phút | Zero-downtime rolling update |
| Chạy nhiều service | Xung đột port/version | Mỗi service cô lập hoàn toàn |
| Scale ứng dụng | Mua thêm server, cài lại | Tăng số container trong giây lát |
| Thử nghiệm DB mới | Cài vào máy, lỡ phá | Chạy container, xong xóa |
| CI/CD | Môi trường build khác nhau | Build environment nhất quán |

---

## 2. Kiến Trúc Docker

### 2.1 Các Thành Phần Cốt Lõi

```
┌─────────────────────────────────────────────────┐
│              DOCKER ARCHITECTURE                │
│                                                 │
│  ┌──────────────┐      ┌──────────────────────┐ │
│  │  Docker CLI  │─────▶│   Docker Daemon      │ │
│  │ (docker cmd) │      │   (dockerd)          │ │
│  └──────────────┘      │                      │ │
│                        │  ┌────────────────┐  │ │
│  ┌──────────────┐      │  │  Containers    │  │ │
│  │  Docker      │      │  │  ┌──┐ ┌──┐    │  │ │
│  │  Desktop     │      │  │  │C1│ │C2│    │  │ │
│  │  (GUI)       │      │  │  └──┘ └──┘    │  │ │
│  └──────────────┘      │  └────────────────┘  │ │
│                        │                      │ │
│                        │  ┌────────────────┐  │ │
│                        │  │  Images Cache  │  │ │
│                        │  └────────────────┘  │ │
│                        └──────────────────────┘ │
│                                  │               │
│                        ┌─────────▼─────────┐    │
│                        │   Docker Registry  │    │
│                        │   (Docker Hub/     │    │
│                        │    Private)        │    │
│                        └───────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Docker Client (CLI):** Công cụ dòng lệnh bạn dùng (`docker build`, `docker run`, ...)

**Docker Daemon (dockerd):** Tiến trình chạy ngầm, thực sự làm mọi việc: build image, tạo/chạy container, quản lý network/storage

**Docker Registry:** Kho lưu trữ Docker images. Docker Hub là registry công khai. Doanh nghiệp thường dùng **private registry** (Harbor, **Azure Container Registry**, GCP Artifact Registry)

### 2.2 Docker Hoạt Động Như Thế Nào (Bên Dưới)

Docker sử dụng **3 tính năng của Linux kernel**:

```
┌─────────────────────────────────────────┐
│           Linux Kernel Features         │
│                                         │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │  Namespaces │  │   cgroups        │  │
│  │             │  │                  │  │
│  │ Cô lập:     │  │ Giới hạn tài     │  │
│  │ - PID       │  │ nguyên:          │  │
│  │ - Network   │  │ - CPU            │  │
│  │ - Mount     │  │ - RAM            │  │
│  │ - UTS(host) │  │ - Disk I/O       │  │
│  │ - IPC       │  │ - Network BW     │  │
│  └─────────────┘  └──────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  Union File System (OverlayFS)   │   │
│  │  Layer hóa filesystem            │   │
│  │  → Images dùng chung layers      │   │
│  │  → Tiết kiệm disk đáng kể        │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Namespaces** cho mỗi container "nghĩ" rằng nó có hệ điều hành riêng.
**cgroups** giới hạn tài nguyên mỗi container được dùng.
**OverlayFS** cho phép nhiều container dùng chung phần read-only của image, tiết kiệm disk.

---

## 3. Container vs Virtual Machine

### 3.1 So Sánh Kiến Trúc

```
┌─────────────────────┐    ┌─────────────────────┐
│   VIRTUAL MACHINE   │    │      CONTAINER       │
├─────────────────────┤    ├─────────────────────┤
│   App A   │  App B  │    │   App A   │  App B  │
├───────────┼─────────┤    ├───────────┼─────────┤
│ Guest OS  │Guest OS │    │  Libs/Bins│Libs/Bins│
│(Ubuntu)   │(CentOS) │    │           │         │
├───────────┴─────────┤    ├─────────────────────┤
│    Hypervisor       │    │    Docker Engine     │
├─────────────────────┤    ├─────────────────────┤
│   Host OS (Linux)   │    │   Host OS (Linux)   │
├─────────────────────┤    ├─────────────────────┤
│     Hardware        │    │     Hardware        │
└─────────────────────┘    └─────────────────────┘

VM App B muốn chạy:         Container App B muốn chạy:
→ Khởi động cả Guest OS     → Chạy ngay, dùng chung kernel
→ 30 giây - vài phút        → Dưới 1 giây
→ Tốn 1-4GB RAM/VM          → Tốn vài MB RAM overhead
```

### 3.2 Bảng So Sánh Chi Tiết

| Tiêu chí | VM | Container |
|----------|-----|-----------|
| Khởi động | 30s - 5 phút | < 1 giây |
| RAM overhead | 512MB - 4GB/instance | Vài chục MB |
| Disk | 10-50GB/instance | Vài trăm MB (dùng chung) |
| Cô lập | Hoàn toàn (kernel riêng) | Gần hoàn toàn (kernel chung) |
| Bảo mật | Cao hơn | Thấp hơn một chút |
| Tính di động | Khó (file .vmdk nặng) | Dễ (image trên registry) |
| Mật độ | 10-20 VM/server | Hàng trăm container/server |

### 3.3 Khi Nào Dùng VM, Khi Nào Dùng Container?

**Dùng VM khi:**
- Cần OS khác nhau hoàn toàn (chạy Windows app trên Linux server)
- Yêu cầu bảo mật tuyệt đối (banking, healthcare)
- Legacy software không thể container hóa

**Dùng Container khi:**
- Microservices, web apps, APIs
- CI/CD pipelines
- Development environments
- Hầu hết use case hiện đại

> **Thực tế doanh nghiệp:** Nhiều công ty dùng **cả hai** — VM làm host, container chạy bên trong VM để có cả hai lợi ích.

---

## 4. Các Khái Niệm Cốt Lõi

### 4.1 Docker Image

**Image** là một **template read-only** chứa mọi thứ cần thiết để chạy ứng dụng:
- OS base (thường là Linux minimal)
- Runtime (Python, Node.js, Java, ...)
- Libraries/Dependencies
- Application code
- Configuration

**Image được xây dựng theo lớp (layers):**

```
┌─────────────────────────────┐
│     Layer 4: Your Code      │  ← Thay đổi nhiều nhất
│     (COPY app/ /app/)       │
├─────────────────────────────┤
│   Layer 3: Dependencies     │  ← Thay đổi khi update deps
│   (pip install -r req.txt)  │
├─────────────────────────────┤
│  Layer 2: Python 3.11       │  ← Hiếm khi thay đổi
│  (FROM python:3.11-slim)    │
├─────────────────────────────┤
│  Layer 1: Debian Linux      │  ← Gần như không đổi
│  (base OS)                  │
└─────────────────────────────┘
        READ-ONLY
```

**Tại sao cần biết về layers?**
- Layers được **cache**. Nếu Layer 1, 2, 3 không đổi → chỉ build lại Layer 4
- Nhiều image **dùng chung** layers → tiết kiệm disk và download time
- Sắp xếp Dockerfile đúng thứ tự → build nhanh hơn nhiều

### 4.2 Docker Container

**Container** là một **instance đang chạy** của một image.

```
Image (template) ──────┬────▶ Container 1 (đang chạy)
                       ├────▶ Container 2 (đang chạy)  
                       └────▶ Container 3 (đã dừng)
```

Container có thêm một **thin writable layer** ở trên image layers. Mọi thay đổi trong container được ghi vào layer này. Khi container bị xóa, layer này cũng mất.

**Container lifecycle:**

```
docker create ──▶ [Created]
                      │
docker start  ──▶ [Running] ◀──── docker restart
                      │
docker pause  ──▶ [Paused]
docker unpause──▶ [Running]
                      │
docker stop   ──▶ [Stopped/Exited]
                      │
docker rm     ──▶ [Deleted]
```

### 4.3 Docker Registry & Repository

```
Docker Hub (public registry)
│
├── Repository: nginx
│   ├── nginx:latest
│   ├── nginx:1.25
│   └── nginx:1.25-alpine
│
├── Repository: python
│   ├── python:3.11
│   ├── python:3.11-slim
│   └── python:3.11-alpine
│
└── Repository: your-username/my-app
    ├── your-username/my-app:latest
    ├── your-username/my-app:v1.0
    └── your-username/my-app:v1.1
```

**Image naming convention:**
```
[registry/][username/]repository[:tag]

Ví dụ đầy đủ:
  registry.company.com/team/backend-api:v2.3.1

Ví dụ Docker Hub:
  nginx:1.25-alpine
  myusername/myapp:latest
```

**Tag phổ biến:**
- `latest`: mặc định, bản mới nhất (CẢNH BÁO: không dùng trong production!)
- `alpine`: image nhỏ gọn dựa trên Alpine Linux (~5MB)
- `slim`: image nhẹ hơn bản đầy đủ
- `v1.2.3`: version cụ thể (khuyến nghị dùng trong production)

---

## 5. Cài Đặt Docker

### 5.1 Linux (Ubuntu/Debian) - Cài Qua Repository Chính Thức

```bash
# Bước 1: Gỡ các version cũ nếu có
sudo apt-get remove docker docker-engine docker.io containerd runc

# Bước 2: Cài các package cần thiết
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Bước 3: Thêm Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Bước 4: Thêm Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Bước 5: Cài Docker Engine
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Bước 6: Cho phép user dùng Docker không cần sudo
sudo usermod -aG docker $USER

# Bước 7: Áp dụng group mới (hoặc logout/login lại)
newgrp docker

# Kiểm tra
docker --version
docker compose version
docker run hello-world
```

### 5.2 Giải Thích Từng Package Vừa Cài

| Package | Vai trò |
|---------|---------|
| `docker-ce` | Docker Community Edition (Engine chính) |
| `docker-ce-cli` | Command-line interface (`docker` command) |
| `containerd.io` | Container runtime cấp thấp |
| `docker-buildx-plugin` | Build multi-platform images |
| `docker-compose-plugin` | Chạy `docker compose` (v2) |

### 5.3 Cấu Hình Sau Cài Đặt

```bash
# Cho Docker tự start khi boot
sudo systemctl enable docker
sudo systemctl enable containerd

# Kiểm tra status
sudo systemctl status docker

# Xem thông tin Docker
docker info

# Quan trọng: Docker root dir (nơi lưu images/containers)
docker info | grep "Docker Root Dir"
# Thường là: /var/lib/docker
```

### 5.4 Cấu Hình Docker Daemon (daemon.json)

File này cho phép tùy chỉnh Docker daemon:

```bash
sudo nano /etc/docker/daemon.json
```

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://mirror.gcr.io"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

```bash
# Áp dụng config
sudo systemctl restart docker
```

**Giải thích:**
- `log-driver/log-opts`: Giới hạn log file để tránh đầy disk (rất quan trọng trong production!)
- `storage-driver: overlay2`: Driver filesystem tốt nhất trên Linux hiện đại
- `registry-mirrors`: Mirror để download image nhanh hơn
- `default-ulimits`: Giới hạn file descriptor, quan trọng cho app nhiều connections

---

## 6. Hiểu Docker Image Layers Sâu Hơn

### 6.1 Xem Layers Của Một Image

```bash
# Pull image nginx
docker pull nginx:alpine

# Xem lịch sử layers
docker history nginx:alpine

# Kết quả:
# IMAGE          CREATED        CREATED BY                                SIZE
# abc123         2 weeks ago    CMD ["nginx" "-g" "daemon off;"]          0B
# <missing>      2 weeks ago    STOPSIGNAL SIGQUIT                        0B
# <missing>      2 weeks ago    EXPOSE 80                                 0B
# <missing>      2 weeks ago    COPY 10-listen-on-ipv6-by-default.sh /   2.12kB
# <missing>      2 weeks ago    RUN /bin/sh -c set -x && ...             11.5MB
# <missing>      3 weeks ago    /bin/sh -c #(nop) ADD file:...           7.73MB   ← Base Alpine

# Xem chi tiết image (JSON format)
docker inspect nginx:alpine
```

### 6.2 OverlayFS Trong Thực Tế

```bash
# Tình huống: 3 containers chạy từ cùng 1 image nginx (50MB)
# Lãng phí disk nếu không có layer sharing: 3 × 50MB = 150MB
# Với OverlayFS: Chỉ tốn ~50MB + 3 writable layers (vài KB mỗi cái)

# Xem overlayfs đang hoạt động
docker run -d --name web1 nginx:alpine
docker run -d --name web2 nginx:alpine
docker run -d --name web3 nginx:alpine

# Kiểm tra disk usage
docker system df
# TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
# Images          1         1         23.36MB   0B (0%)
# Containers      3         3         3.09kB    0B (0%)   ← Chỉ tốn thêm 3KB!
# Local Volumes   0         0         0B        0B
```

---

## 7. Docker Trong Doanh Nghiệp - Bức Tranh Lớn

### 7.1 Quy Trình Điển Hình

```
Developer                CI/CD Server              Production
    │                         │                        │
    │ git push                │                        │
    ├────────────────────────▶│                        │
    │                         │ docker build           │
    │                         ├─────────┐             │
    │                         │◀────────┘             │
    │                         │ docker push            │
    │                         ├────────────────────▶ Registry
    │                         │                        │
    │                         │ kubectl apply /        │
    │                         │ docker stack deploy    │
    │                         ├───────────────────────▶│
    │                         │                        │ docker pull
    │                         │                        ├──────────▶ Registry
    │                         │                        │
    │                         │                        │ Container running ✅
```

### 7.2 Các Thành Phần Trong Stack Thực Tế

```
Load Balancer (Nginx/HAProxy)
        │
        ▼
┌───────────────────────────────────┐
│         Docker Swarm / K8s        │
│  ┌──────┐  ┌──────┐  ┌──────┐   │
│  │ App  │  │ App  │  │ App  │   │  ← 3 replicas
│  │ :3000│  │ :3000│  │ :3000│   │
│  └──────┘  └──────┘  └──────┘   │
│  ┌──────────────────────────┐    │
│  │      Redis (Cache)       │    │
│  └──────────────────────────┘    │
│  ┌──────────────────────────┐    │
│  │   PostgreSQL (Database)  │    │
│  └──────────────────────────┘    │
│  ┌──────────────────────────┐    │
│  │  RabbitMQ (Message Queue)│    │
│  └──────────────────────────┘    │
└───────────────────────────────────┘
```

---

> **Tiếp theo: Phần 2** - Các lệnh Docker cơ bản, làm việc với Images và Containers
