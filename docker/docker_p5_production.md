# ---
markmap:
  title: "Docker — Production, Security & Hardening"
  collapse: false
# ---

# 🐳 DOCKER TOÀN TẬP - PHẦN 5: BẢO MẬT, PRODUCTION & THỰC CHIẾN

## Theory
- Production-ready container images require scanning, minimal base images, runtime security controls, and runtime observability.

## Practice
- Thực hành: scan images with Trivy, use non-root users, enable read-only filesystems, resource limits, and runtime monitoring.

## 1. Bảo Mật Docker

### 1.1 Các Nguy Cơ Phổ Biến

```
Nguy cơ 1: Container chạy với quyền root
→ Nếu app bị hack, attacker có quyền root trong container
→ Có thể leo quyền ra host trong một số cấu hình

Nguy cơ 2: Dùng image không tin cậy
→ Image độc hại có thể chứa malware, cryptominer

Nguy cơ 3: Secrets lộ trong environment variables
→ docker inspect tiết lộ tất cả env vars

Nguy cơ 4: Container có thể truy cập Docker socket
→ Attacker có thể tạo container mới với quyền root trên host

Nguy cơ 5: Image không được cập nhật
→ Chứa các CVE (lỗ hổng bảo mật) đã biết
```

### 1.2 Chạy Container Không Phải Root

```dockerfile
# Trong Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Cài dependencies với root trước
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Tạo user không có đặc quyền
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/false --create-home appuser

# Set ownership cho files cần thiết
COPY --chown=appuser:appgroup . .

# Chuyển sang user không có quyền root
USER appuser

CMD ["python", "app.py"]
```

```bash
# Kiểm tra container đang chạy với user nào
docker exec my-container id
# uid=1001(appuser) gid=1001(appgroup)  ← Tốt!
# uid=0(root) gid=0(root)              ← Nguy hiểm!

# Force chạy với user cụ thể (ngay cả khi image dùng root)
docker run --user 1001:1001 myimage
```

### 1.3 Read-Only Filesystem

```bash
# Chạy với filesystem read-only
docker run --read-only \
  --tmpfs /tmp \          # Chỉ /tmp có thể ghi
  --tmpfs /run \
  myimage

# Trong Docker Compose
services:
  api:
    read_only: true
    tmpfs:
      - /tmp
      - /run
```

### 1.4 Security Options

```bash
# Ngăn container leo quyền
docker run --security-opt no-new-privileges:true myimage

# Drop tất cả Linux capabilities, chỉ add lại những gì cần
docker run \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \   # Cho phép bind port < 1024
  myimage

# Seccomp profile (giới hạn system calls)
docker run \
  --security-opt seccomp=/path/to/seccomp-profile.json \
  myimage

# Trong Compose
services:
  api:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

### 1.5 Scan Image Tìm Vulnerabilities

```bash
# Docker Scout (tích hợp sẵn)
docker scout cves myimage:latest

# Trivy (open source, phổ biến trong doanh nghiệp)
# Cài Trivy
sudo apt-get install trivy

# Scan image
trivy image myimage:latest

# Scan Dockerfile
trivy config ./Dockerfile

# Scan với threshold (fail nếu có CRITICAL vuln)
trivy image --exit-code 1 --severity CRITICAL myimage:latest

# Output JSON cho CI/CD
trivy image --format json --output results.json myimage:latest
```

### 1.6 Quản Lý Secrets Đúng Cách

```bash
# ❌ KHÔNG làm thế này:
docker run -e DB_PASSWORD=mysecret myimage
# Lý do: Có thể thấy qua docker inspect, ps aux, logs

# ✅ CÁCH 1: Docker Secrets (chỉ trong Docker Swarm)
echo "mysecret" | docker secret create db_password -
docker service create \
  --name myservice \
  --secret db_password \
  myimage
# Secret được mount tại /run/secrets/db_password

# ✅ CÁCH 2: Dùng tool quản lý secrets (production)
# HashiCorp Vault, AWS Secrets Manager, etc.

# ✅ CÁCH 3: Mount file secret
docker run \
  --mount type=bind,source=/secure/secrets/db.conf,target=/run/secrets/db.conf,readonly \
  myimage

# ✅ CÁCH 4: Build-time secrets (không lưu vào layer)
docker build \
  --secret id=mytoken,src=/home/user/.tokens/mytoken \
  .
# Trong Dockerfile:
# RUN --mount=type=secret,id=mytoken \
#     cat /run/secrets/mytoken | curl -H "Authorization: Bearer $(cat -)" ...
```


## 2. Private Registry

### 2.1 Tại Sao Cần Private Registry?

- **Bảo mật:** Code nguồn, business logic không muốn public
- **Performance:** Pull image nhanh hơn từ registry nội bộ
- **Kiểm soát:** Quản lý ai được pull/push image gì
- **Compliance:** Quy định bảo mật dữ liệu trong doanh nghiệp

### 2.2 Chạy Registry Riêng (Docker Registry)

```bash
# Chạy registry đơn giản (không có UI, không có authentication)
docker run -d \
  --name registry \
  --restart=unless-stopped \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  registry:2

# Test push/pull
docker pull nginx:alpine
docker tag nginx:alpine localhost:5000/nginx:alpine
docker push localhost:5000/nginx:alpine
docker pull localhost:5000/nginx:alpine
```

### 2.3 Registry Với Authentication & TLS (Production)

```bash
# Tạo thư mục
mkdir -p ~/registry/{certs,auth,data}

# Tạo TLS certificate (self-signed cho internal use)
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout ~/registry/certs/domain.key \
  -x509 -days 365 \
  -out ~/registry/certs/domain.crt \
  -subj "/CN=registry.company.internal"

# Tạo file authentication (htpasswd)
docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn admin strongpassword > ~/registry/auth/htpasswd

# Chạy registry với TLS và auth
docker run -d \
  --name secure-registry \
  --restart=unless-stopped \
  -p 443:443 \
  -v ~/registry/data:/var/lib/registry \
  -v ~/registry/certs:/certs \
  -v ~/registry/auth:/auth \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

# Login vào registry
docker login registry.company.internal

# Push image
docker tag myapp:v1.0 registry.company.internal/myteam/myapp:v1.0
docker push registry.company.internal/myteam/myapp:v1.0
```

### 2.4 Harbor (Enterprise Registry - Khuyến Nghị)

Harbor là private registry cấp enterprise, có:
- Web UI đẹp
- RBAC (phân quyền chi tiết)
- Vulnerability scanning tích hợp
- Image replication
- Audit logs

```bash
# Cài Harbor bằng Docker Compose
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz
tar xzf harbor-offline-installer-v2.9.0.tgz
cd harbor
cp harbor.yml.tmpl harbor.yml
# Sửa harbor.yml: hostname, passwords, TLS certs
./install.sh
```


## 3. Production Best Practices

### 3.1 Tagging Strategy

```bash
# ❌ Không bao giờ dùng :latest trong production
docker pull myapp:latest  # Không biết đây là version nào!

# ✅ Dùng Semantic Versioning
myapp:1.2.3          # Major.Minor.Patch

# ✅ Dùng Git commit hash (immutable - không thay đổi)
myapp:a1b2c3d        # Git short SHA

# ✅ Kết hợp version + commit (best practice)
myapp:1.2.3-a1b2c3d

# ✅ Dùng build number của CI/CD
myapp:build-456

# Script trong CI/CD:
GIT_SHA=$(git rev-parse --short HEAD)
VERSION=$(cat VERSION)
docker build -t myapp:${VERSION}-${GIT_SHA} .
docker tag myapp:${VERSION}-${GIT_SHA} myapp:${VERSION}
docker tag myapp:${VERSION}-${GIT_SHA} myapp:latest
```

### 3.2 Health Checks & Graceful Shutdown

```python
# app.py - Implement health endpoint
from flask import Flask, jsonify
import signal
import sys

app = Flask(__name__)
is_healthy = True

@app.route('/health')
def health():
    if is_healthy:
        return jsonify({'status': 'healthy', 'version': '1.2.3'}), 200
    return jsonify({'status': 'unhealthy'}), 503

@app.route('/ready')
def ready():
    # Check DB connection, cache, etc.
    try:
        db.session.execute('SELECT 1')
        return jsonify({'status': 'ready'}), 200
    except:
        return jsonify({'status': 'not ready'}), 503

# Graceful shutdown
def handle_shutdown(sig, frame):
    global is_healthy
    is_healthy = False  # Health check fails → load balancer stops sending traffic
    # Chờ requests hiện tại xử lý xong
    import time
    time.sleep(10)
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_shutdown)
```

### 3.3 Logging Best Practices

```bash
# ✅ Log ra STDOUT/STDERR (Docker chuẩn)
# Đừng ghi file log trong container

# Config logging trong compose
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"   # Tối đa 100MB mỗi file
        max-file: "5"      # Giữ 5 file rotate
        labels: "app,env"
        tag: "{{.Name}}/{{.ID}}"

# Shipping logs ra ELK stack
services:
  backend:
    logging:
      driver: "fluentd"
      options:
        fluentd-address: "localhost:24224"
        tag: "myapp.backend"
```

### 3.4 Resource Management

```yaml
# docker-compose.yml với resource limits
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '0.50'      # Tối đa 50% của 1 CPU
          memory: 512M      # Tối đa 512MB RAM
        reservations:
          cpus: '0.25'      # Đảm bảo ít nhất 25% CPU
          memory: 256M      # Đảm bảo ít nhất 256MB RAM
      replicas: 3           # Chạy 3 instances (Docker Swarm)
      update_config:
        parallelism: 1      # Update 1 instance 1 lúc
        delay: 10s          # Chờ 10s giữa mỗi update
        failure_action: rollback
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
```


## 4. Xử Lý Sự Cố Thường Gặp

### 4.1 Container Không Start

```bash
# Xem lý do tại sao container exit
docker logs my-container

# Xem exit code
docker inspect my-container --format='{{.State.ExitCode}}'
# 0 = Success
# 1 = General error
# 137 = Killed (OOM hoặc docker kill)
# 139 = Segfault
# 143 = SIGTERM (graceful stop)

# Chạy shell thay vì CMD để debug
docker run -it --entrypoint sh myimage

# Xem events của Docker daemon
docker events --filter container=my-container
```

### 4.2 Container Bị OOM Killed (Hết RAM)

```bash
# Kiểm tra
docker inspect my-container --format='{{.State.OOMKilled}}'
# true → bị kill vì hết RAM

# Giải pháp:
# 1. Tăng memory limit
docker run --memory="1g" myimage

# 2. Kiểm tra memory leak trong app
docker stats my-container  # Xem RAM tăng liên tục không

# 3. Kiểm tra logs trước khi bị kill
docker logs --tail=100 my-container
```

### 4.3 Disk Đầy

```bash
# Kiểm tra Docker đang chiếm bao nhiêu disk
docker system df

# Kết quả:
# TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
# Images          47        12        18.3GB    14.1GB (77%)
# Containers      23        3         1.4GB     1.2GB (85%)
# Local Volumes   12        4         23.4GB    5.6GB (23%)
# Build Cache     0         0         0B        0B

# Dọn dẹp an toàn (chỉ xóa những gì không dùng)
docker system prune

# Dọn dẹp mạnh hơn (kể cả images không dùng)
docker system prune -a

# Dọn dẹp từng loại
docker container prune   # Containers đã stopped
docker image prune -a    # Images không được dùng bởi container nào
docker volume prune      # Volumes orphaned
docker network prune     # Networks không dùng
docker builder prune     # Build cache
```

### 4.4 Không Kết Nối Được Giữa Containers

```bash
# Kiểm tra containers có cùng network không
docker network inspect my-network

# Kiểm tra DNS
docker exec container1 nslookup container2
docker exec container1 ping container2

# Kiểm tra port có mở không
docker exec container1 nc -zv container2 5432

# Xem network của container
docker inspect container1 --format='{{json .NetworkSettings.Networks}}'

# Kết nối container vào network
docker network connect my-network container1

# Ngắt kết nối
docker network disconnect my-network container1
```

### 4.5 Permission Denied

```bash
# Lỗi khi ghi vào volume
# Permission denied: '/app/data/file.txt'

# Kiểm tra ownership
docker exec my-container ls -la /app/data

# Sửa trong Dockerfile
RUN mkdir -p /app/data && chown -R appuser:appgroup /app/data
USER appuser

# Hoặc thêm permissions cho volume directory trên host
sudo chown -R 1001:1001 ./data/
```


## 5. CI/CD Integration

### 5.1 GitHub Actions + Docker

```yaml
# .github/workflows/docker.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha   # GitHub Actions cache
          cache-to: type=gha,mode=max

      - name: Run Trivy security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
```

### 5.2 Jenkinsfile Với Docker

```groovy
pipeline {
    agent any
    
    environment {
        REGISTRY = 'registry.company.com'
        IMAGE = "${REGISTRY}/myteam/backend"
        GIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
        VERSION = sh(returnStdout: true, script: 'cat VERSION').trim()
        FULL_TAG = "${VERSION}-${GIT_SHA}-${BUILD_NUMBER}"
    }
    
    stages {
        stage('Build') {
            steps {
                sh """
                    docker build \
                        --build-arg BUILD_DATE=\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                        --build-arg GIT_COMMIT=${GIT_SHA} \
                        --build-arg VERSION=${VERSION} \
                        --cache-from ${IMAGE}:latest \
                        -t ${IMAGE}:${FULL_TAG} \
                        -t ${IMAGE}:latest \
                        .
                """
            }
        }
        
        stage('Security Scan') {
            steps {
                sh "trivy image --exit-code 1 --severity CRITICAL ${IMAGE}:${FULL_TAG}"
            }
        }
        
        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'registry-creds',
                    usernameVariable: 'REG_USER',
                    passwordVariable: 'REG_PASS'
                )]) {
                    sh """
                        echo \$REG_PASS | docker login ${REGISTRY} -u \$REG_USER --password-stdin
                        docker push ${IMAGE}:${FULL_TAG}
                        docker push ${IMAGE}:latest
                        docker logout ${REGISTRY}
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh "kubectl set image deployment/backend backend=${IMAGE}:${FULL_TAG}"
                sh "kubectl rollout status deployment/backend --timeout=300s"
            }
        }
    }
    
    post {
        always {
            sh "docker image prune -f"
        }
    }
}
```


## 6. Checklist Production

### Trước Khi Deploy

```
Image:
[ ] Image dùng tag cụ thể, không phải :latest
[ ] Image đã qua security scan (trivy/docker scout)
[ ] Không có CRITICAL vulnerabilities
[ ] Image chạy với user không phải root
[ ] Image size được tối ưu (multi-stage build)
[ ] .dockerignore đã cấu hình
[ ] Không có secrets trong image layers

Container:
[ ] Resource limits đã set (CPU + Memory)
[ ] Restart policy đã cấu hình
[ ] Health check đã implement
[ ] Log rotation đã cấu hình
[ ] Read-only filesystem (nếu có thể)
[ ] no-new-privileges đã bật

Network:
[ ] Chỉ expose ports thực sự cần thiết
[ ] Sensitive services không expose ra ngoài
[ ] Internal services dùng internal network

Data:
[ ] Data quan trọng trong named volumes
[ ] Backup strategy đã có
[ ] Backup đã test restore
```


## 7. Lộ Trình Học Tiếp Theo

```
Docker Cơ Bản (Phần 1-5) ✅
           │
           ▼
    Docker Compose ✅
           │
           ▼
    Docker Swarm          ← Orchestration đơn giản
    (Multi-node cluster)
           │
           ▼
    Kubernetes / k3s      ← Orchestration mạnh mẽ (đã có guide)
           │
      ┌────┴────┐
      ▼         ▼
   Helm      ArgoCD       ← Package manager & GitOps
      │         │
      └────┬────┘
           ▼
    Service Mesh          ← Istio, Linkerd
    (Advanced networking,
     mTLS, observability)
```

### Tài Liệu Tham Khảo Chính Thức

| Tài liệu | Link |
|----------|------|
| Docker Docs | docs.docker.com |
| Docker Hub | hub.docker.com |
| Compose Spec | compose-spec.io |
| Docker Best Practices | docs.docker.com/develop/dev-best-practices |
| CIS Docker Benchmark | cisecurity.org (security hardening) |


## 8. Quick Reference Card

```bash
# === IMAGES ===
docker pull nginx:alpine           # Download image
docker build -t myapp:v1 .        # Build từ Dockerfile
docker images                      # Liệt kê images
docker rmi myapp:v1                # Xóa image
docker push myapp:v1               # Push lên registry

# === CONTAINERS ===
docker run -d -p 80:80 --name web nginx   # Chạy container
docker ps                                  # Containers đang chạy
docker ps -a                               # Tất cả containers
docker stop web                            # Dừng container
docker start web                           # Khởi động lại
docker rm web                              # Xóa container
docker rm -f web                           # Force xóa

# === DEBUG ===
docker logs -f web                 # Xem logs real-time
docker exec -it web sh             # Vào shell trong container
docker inspect web                 # Xem thông tin chi tiết
docker stats                       # Resource usage real-time

# === DOCKER COMPOSE ===
docker compose up -d               # Khởi động tất cả
docker compose down                # Dừng tất cả
docker compose down -v             # Dừng và xóa volumes
docker compose logs -f             # Xem logs
docker compose exec web sh         # Vào container
docker compose ps                  # Xem trạng thái

# === DỌN DẸP ===
docker system prune                # Dọn dẹp an toàn
docker system prune -a             # Dọn dẹp mạnh
docker system df                   # Xem disk usage
```
