# 🐳 DOCKER TOÀN TẬP - PHẦN 2: LỆNH CƠ BẢN & LÀM VIỆC VỚI CONTAINER

---

## 1. Các Lệnh Docker Cơ Bản - Images

### 1.1 Tìm Kiếm & Pull Images

```bash
# Tìm image trên Docker Hub
docker search nginx

# Kết quả:
# NAME                DESCRIPTION                    STARS    OFFICIAL
# nginx               Official build of Nginx         19000    [OK]
# nginx/nginx-ingress NGINX and NGINX Plus Ingress    84

# Pull image về máy (mặc định tag: latest)
docker pull nginx

# Pull image với tag cụ thể (KHUYẾN NGHỊ - luôn dùng tag cụ thể)
docker pull nginx:1.25-alpine
docker pull python:3.11-slim
docker pull postgres:15

# Pull từ private registry
docker pull registry.company.com/myteam/backend:v2.3.1
```

### 1.2 Liệt Kê & Xem Thông Tin Images

```bash
# Liệt kê tất cả images đã có trên máy
docker images
# hoặc
docker image ls

# Kết quả:
# REPOSITORY    TAG           IMAGE ID       CREATED        SIZE
# nginx         1.25-alpine   abc123def456   2 weeks ago    42.6MB
# python        3.11-slim     789xyz012345   3 weeks ago    149MB
# postgres      15            111aaa222bbb   4 weeks ago    379MB

# Liệt kê kèm digest (hash đầy đủ, dùng cho production verification)
docker images --digests

# Lọc images
docker images --filter "dangling=true"   # Images không có tag (orphaned)
docker images --filter "reference=nginx" # Lọc theo tên

# Xem chi tiết một image
docker inspect nginx:1.25-alpine

# Xem size của image theo từng layer
docker history nginx:1.25-alpine --no-trunc
```

### 1.3 Xóa Images

```bash
# Xóa một image
docker rmi nginx:latest

# Xóa bằng IMAGE ID
docker rmi abc123def456

# Xóa nhiều images cùng lúc
docker rmi nginx:latest python:3.9

# Xóa image đang được dùng (force) - NGUY HIỂM
docker rmi -f nginx:latest

# Xóa TẤT CẢ images không dùng
docker image prune

# Xóa TẤT CẢ images (kể cả đang dùng) - NGUY HIỂM
docker image prune -a

# Dọn dẹp toàn bộ (images + containers + networks + cache)
docker system prune -a
```

---

## 2. Chạy Containers - `docker run`

### 2.1 Cú Pháp Và Các Flag Quan Trọng

```bash
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

**Ví dụ từ đơn giản đến phức tạp:**

```bash
# Chạy đơn giản nhất - chạy và xóa container sau khi xong
docker run hello-world

# Chạy nginx và xóa container khi stop (-rm)
docker run --rm nginx:alpine

# Chạy ở background (-d = detach)
docker run -d nginx:alpine

# Chạy với tên cụ thể (--name)
docker run -d --name my-nginx nginx:alpine

# Map port: host_port:container_port (-p)
docker run -d --name my-nginx -p 8080:80 nginx:alpine
# Bây giờ truy cập http://localhost:8080

# Map port ngẫu nhiên (-P - docker chọn port cho bạn)
docker run -d --name my-nginx2 -P nginx:alpine
docker port my-nginx2   # Xem port được assign

# Chạy interactive với terminal (-it)
docker run -it ubuntu:22.04 bash
# -i = interactive (giữ STDIN mở)
# -t = allocate a pseudo-TTY (terminal)

# Chạy một lệnh và thoát
docker run --rm ubuntu:22.04 echo "Hello from container"
docker run --rm python:3.11-slim python -c "print('Python in Docker!')"
```

### 2.2 Biến Môi Trường (-e, --env-file)

```bash
# Set biến môi trường
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:15

# Set nhiều biến từ file .env
cat > .env << 'EOF'
POSTGRES_PASSWORD=secretpass
POSTGRES_USER=myuser
POSTGRES_DB=mydb
EOF

docker run -d \
  --name my-postgres \
  --env-file .env \
  -p 5432:5432 \
  postgres:15

# Kiểm tra biến môi trường trong container
docker exec my-postgres env | grep POSTGRES
```

### 2.3 Resource Limits (Rất Quan Trọng Trong Production)

```bash
# Giới hạn RAM
docker run -d \
  --name api-server \
  --memory="512m" \
  --memory-swap="512m" \  # Tắt swap (= memory limit)
  nginx:alpine

# Giới hạn CPU
docker run -d \
  --name api-server \
  --cpus="1.5" \          # Dùng tối đa 1.5 CPU cores
  nginx:alpine

# Kết hợp cả hai - ví dụ production
docker run -d \
  --name backend-api \
  --memory="1g" \
  --memory-swap="1g" \
  --cpus="0.5" \
  --restart=unless-stopped \
  -p 3000:3000 \
  myapp:v1.2

# Kiểm tra resource usage real-time
docker stats
docker stats backend-api   # Chỉ xem 1 container
```

**Giải thích `--memory-swap`:**
- `--memory-swap` = tổng RAM + swap
- Nếu `--memory="512m"` và `--memory-swap="1g"` → swap = 512MB
- Nếu `--memory-swap="512m"` (= --memory) → tắt swap hoàn toàn
- Trong production: thường tắt swap để tránh performance không ổn định

### 2.4 Restart Policy

```bash
# Không tự restart (mặc định)
docker run --restart=no nginx

# Luôn restart (kể cả khi docker daemon restart)
docker run --restart=always nginx

# Restart trừ khi bị stop thủ công (dùng trong production)
docker run --restart=unless-stopped nginx

# Restart tối đa N lần khi bị lỗi
docker run --restart=on-failure:5 nginx
```

---

## 3. Quản Lý Containers Đang Chạy

### 3.1 Liệt Kê Containers

```bash
# Xem containers đang chạy
docker ps

# Xem tất cả containers (kể cả đã stop)
docker ps -a
# hoặc
docker ps --all

# Xem với format tùy chỉnh
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Chỉ lấy container IDs
docker ps -q          # Đang chạy
docker ps -aq         # Tất cả

# Lọc theo trạng thái
docker ps --filter "status=exited"
docker ps --filter "name=nginx"
docker ps --filter "ancestor=nginx:alpine"  # Theo image
```

### 3.2 Start, Stop, Restart Containers

```bash
# Start container đã tạo/stopped
docker start my-nginx

# Stop container (gửi SIGTERM, chờ 10 giây rồi SIGKILL)
docker stop my-nginx

# Stop nhưng chờ lâu hơn (cho app graceful shutdown)
docker stop --time=30 my-nginx

# Kill ngay lập tức (SIGKILL - không graceful)
docker kill my-nginx

# Restart
docker restart my-nginx

# Stop TẤT CẢ containers đang chạy
docker stop $(docker ps -q)

# Xóa container (phải stop trước)
docker rm my-nginx

# Xóa container kể cả đang chạy (force)
docker rm -f my-nginx

# Xóa tất cả containers đã stopped
docker container prune

# Xóa tất cả containers (dừng trước, rồi xóa)
docker stop $(docker ps -aq) && docker rm $(docker ps -aq)
```

### 3.3 Vào Bên Trong Container - `docker exec`

```bash
# Mở shell bash trong container đang chạy
docker exec -it my-nginx bash
# Nếu container dùng alpine (không có bash):
docker exec -it my-nginx sh

# Chạy một lệnh trong container
docker exec my-nginx nginx -t        # Test nginx config
docker exec my-nginx cat /etc/hosts  # Đọc file

# Chạy với user cụ thể
docker exec -it -u root my-nginx bash

# Chạy với biến môi trường
docker exec -e DEBUG=true my-nginx printenv DEBUG

# Ví dụ thực tế: Vào postgres container để chạy SQL
docker exec -it my-postgres psql -U myuser -d mydb
```

### 3.4 Xem Logs

```bash
# Xem logs của container
docker logs my-nginx

# Xem logs + timestamp
docker logs -t my-nginx

# Theo dõi logs real-time (như tail -f)
docker logs -f my-nginx

# Chỉ xem N dòng cuối
docker logs --tail=100 my-nginx

# Xem logs từ thời điểm cụ thể
docker logs --since="2024-01-15T10:00:00" my-nginx
docker logs --since="1h" my-nginx   # 1 giờ trở lại

# Kết hợp
docker logs -f --tail=50 my-nginx

# Xem logs của nhiều container (dùng với grep)
docker logs my-nginx 2>&1 | grep "ERROR"
```

### 3.5 Inspect - Xem Thông Tin Chi Tiết

```bash
# Xem toàn bộ thông tin (JSON)
docker inspect my-nginx

# Lấy thông tin cụ thể bằng --format
docker inspect --format='{{.NetworkSettings.IPAddress}}' my-nginx
docker inspect --format='{{.State.Status}}' my-nginx
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' my-nginx

# Ví dụ thực tế: Lấy IP của tất cả containers
docker inspect --format='{{.Name}} - {{.NetworkSettings.IPAddress}}' \
  $(docker ps -q)
```

---

## 4. Volumes - Lưu Trữ Dữ Liệu Bền Vững

> **Lý do cần volumes:** Container là ephemeral (tạm thời). Khi container bị xóa, **tất cả dữ liệu bên trong cũng mất**. Volumes giải quyết vấn đề này.

### 4.1 Ba Loại Storage Trong Docker

```
┌─────────────────────────────────────────────┐
│              Docker Host                    │
│                                             │
│  /var/lib/docker/volumes/    ~/mydata/      │
│         │                       │           │
│  Named  │              Bind     │           │
│  Volume │              Mount    │           │
│         ▼                ▼      ▼           │
│    ┌─────────────────────────────────┐      │
│    │         Container               │      │
│    │   /app/data    /app/config      │      │
│    │       ▲              ▲          │      │
│    │       │              │          │      │
│    │  tmpfs mount    (RAM only)      │      │
│    └─────────────────────────────────┘      │
└─────────────────────────────────────────────┘
```

**1. Named Volumes** (Docker quản lý - khuyến nghị)
**2. Bind Mounts** (Map thư mục host vào container - dùng khi dev)
**3. tmpfs Mounts** (Lưu trong RAM - dùng cho sensitive data tạm thời)

### 4.2 Named Volumes

```bash
# Tạo volume
docker volume create my-data

# Liệt kê volumes
docker volume ls

# Xem thông tin volume
docker volume inspect my-data
# Kết quả cho thấy: Mountpoint: /var/lib/docker/volumes/my-data/_data

# Dùng volume khi chạy container
docker run -d \
  --name my-postgres \
  -v my-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Xóa container nhưng dữ liệu VẪN CÒN trong volume
docker rm -f my-postgres

# Chạy lại, dữ liệu vẫn ở đó!
docker run -d \
  --name my-postgres-new \
  -v my-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Xóa volume (phải chắc chắn không cần nữa)
docker volume rm my-data

# Xóa tất cả volumes không dùng
docker volume prune
```

### 4.3 Bind Mounts (Dùng Khi Development)

```bash
# Map thư mục local vào container
# Thay đổi code local → container thấy ngay (hot reload)
docker run -d \
  --name dev-server \
  -v /home/user/myapp:/app \      # Đường dẫn tuyệt đối
  -v /home/user/myapp:/app:ro \   # Read-only
  -p 3000:3000 \
  node:18-alpine \
  node /app/server.js

# Ví dụ thực tế: Dev Python Flask với hot reload
docker run -d \
  --name flask-dev \
  -v $(pwd):/app \                # $(pwd) = thư mục hiện tại
  -p 5000:5000 \
  -e FLASK_ENV=development \
  python:3.11-slim \
  bash -c "pip install flask && python /app/app.py"
```

---

## 5. Networking Cơ Bản

### 5.1 Docker Networks

```bash
# Liệt kê networks
docker network ls

# Kết quả mặc định:
# NETWORK ID     NAME      DRIVER    SCOPE
# abc123         bridge    bridge    local   ← Default
# def456         host      host      local
# ghi789         none      null      local

# Tạo network mới
docker network create my-network

# Tạo network với subnet cụ thể
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  my-network

# Xóa network
docker network rm my-network
```

### 5.2 Kết Nối Containers Với Nhau

```bash
# Tạo network cho app
docker network create app-network

# Chạy database trong network đó
docker run -d \
  --name postgres-db \
  --network app-network \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_DB=appdb \
  postgres:15

# Chạy app trong cùng network → kết nối với db qua tên container
docker run -d \
  --name backend-api \
  --network app-network \
  -e DATABASE_URL=postgresql://appuser:secret@postgres-db:5432/appdb \
  -p 3000:3000 \
  mybackend:latest

# Container backend-api có thể ping postgres-db bằng tên!
docker exec backend-api ping postgres-db
```

**Tại sao dùng custom network thay vì default bridge?**
- **Custom bridge:** Containers liên lạc qua **tên container** (DNS tự động)
- **Default bridge:** Containers chỉ liên lạc qua **IP** (phải hardcode)

### 5.3 Các Loại Network Driver

| Driver | Dùng khi |
|--------|----------|
| `bridge` | Mặc định, cho single-host |
| `host` | Performance cao nhất, container dùng chung network với host |
| `none` | Hoàn toàn cô lập, không có network |
| `overlay` | Multi-host (Docker Swarm) |
| `macvlan` | Container có MAC address riêng, như VM thật |

```bash
# Host network - container dùng port của host trực tiếp
# (Không cần -p, không có NAT overhead)
docker run -d --network host nginx:alpine
# nginx chạy ở port 80 của HOST machine luôn
```

---

## 6. Thực Hành: Chạy Stack Thực Tế

### 6.1 Chạy WordPress + MySQL (Ví Dụ Thực Tế)

```bash
# Tạo network
docker network create wordpress-net

# Tạo volumes
docker volume create mysql-data
docker volume create wordpress-data

# Chạy MySQL
docker run -d \
  --name wordpress-db \
  --network wordpress-net \
  --restart unless-stopped \
  -v mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootsecret \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wpuser \
  -e MYSQL_PASSWORD=wppass \
  mysql:8.0

# Chờ MySQL khởi động
sleep 10

# Chạy WordPress
docker run -d \
  --name wordpress-app \
  --network wordpress-net \
  --restart unless-stopped \
  -v wordpress-data:/var/www/html \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=wordpress-db:3306 \
  -e WORDPRESS_DB_USER=wpuser \
  -e WORDPRESS_DB_PASSWORD=wppass \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress:6.4-php8.2

echo "WordPress đang chạy tại: http://localhost:8080"
```

### 6.2 Backup & Restore Data Từ Volume

```bash
# BACKUP volume ra file tar
docker run --rm \
  -v mysql-data:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar czf /backup/mysql-backup-$(date +%Y%m%d).tar.gz -C /data .

# RESTORE từ file tar vào volume
docker run --rm \
  -v mysql-data:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar xzf /backup/mysql-backup-20240115.tar.gz -C /data

# Giải thích:
# --rm: xóa container tạm sau khi xong
# -v mysql-data:/data: mount volume cần backup
# -v $(pwd):/backup: mount thư mục local để chứa file backup
# ubuntu: dùng ubuntu như một "công cụ" để chạy tar
```

---

## 7. Một Số Lệnh Hữu Ích Khác

```bash
# Copy file từ host vào container
docker cp ./config.json my-nginx:/etc/nginx/config.json

# Copy file từ container ra host
docker cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf.bak

# Xem sự thay đổi trong container (so với image gốc)
docker diff my-nginx
# A = Added, C = Changed, D = Deleted

# Pause/Unpause container (freeze processes)
docker pause my-nginx
docker unpause my-nginx

# Xem thông tin hệ thống Docker
docker system df          # Disk usage
docker system info        # Thông tin tổng quan
docker system events      # Real-time events

# Tạo image từ container đang chạy (không khuyến nghị, dùng Dockerfile)
docker commit my-container my-new-image:v1

# Lưu image ra file
docker save nginx:alpine | gzip > nginx-alpine.tar.gz

# Load image từ file (dùng khi không có internet)
docker load < nginx-alpine.tar.gz
```

---

> **Tiếp theo: Phần 3** - Viết Dockerfile chuyên nghiệp, build images tối ưu
