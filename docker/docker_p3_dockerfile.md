# 🐳 DOCKER TOÀN TẬP - PHẦN 3: DOCKERFILE CHUYÊN NGHIỆP


---
markmap:
    title: "Docker — Dockerfile Best Practices"
    collapse: false
---

# DOCKERFILE - VIẾT CHUẨN & TỐI ƯU

## Theory
- Dockerfile layers and build caching determine image size and build speed; multi-stage builds reduce final image footprint.

## Practice
- Thực hành: cung cấp mẫu multi-stage Dockerfile, healthchecks, non-root user, and label/metadata practices.

## 1. Dockerfile Là Gì?

**Dockerfile** là một file văn bản chứa tập hợp các **instruction** (chỉ thị) để Docker biết cách build image. Mỗi instruction tạo ra một layer mới trong image.

```
Dockerfile (instructions) ──▶ docker build ──▶ Docker Image ──▶ docker run ──▶ Container
```


## 2. Tất Cả Instruction Trong Dockerfile

### 2.1 FROM - Chỉ Định Base Image

```dockerfile
# Bắt buộc phải có, thường là dòng đầu tiên
FROM ubuntu:22.04
FROM python:3.11-slim
FROM scratch          # Image rỗng, dùng cho Go/Rust binaries

# Đặt tên cho build stage (dùng trong multi-stage build)
FROM node:18-alpine AS builder
FROM python:3.11-slim AS runtime
```

**Chọn base image nào?**

| Image | Size | Dùng khi |
|-------|------|---------|
| `ubuntu:22.04` | ~77MB | Cần apt-get, tools đầy đủ |
| `debian:slim` | ~75MB | Tương tự ubuntu, nhẹ hơn |
| `alpine:3.18` | ~7MB | Cần image nhỏ nhất |
| `python:3.11` | ~900MB | Python đầy đủ |
| `python:3.11-slim` | ~150MB | Python bỏ bớt dev tools |
| `python:3.11-alpine` | ~50MB | Python trên Alpine |
| `distroless` | ~20MB | Security tối đa, không có shell |

### 2.2 WORKDIR - Thư Mục Làm Việc

```dockerfile
# Đặt working directory (tạo tự động nếu chưa có)
WORKDIR /app

# Tất cả lệnh sau đó sẽ chạy trong /app
COPY . .           # Nghĩa là: COPY . /app
RUN ls             # Chạy ls trong /app
```

## Tại sao cần WORKDIR?
- Tránh dùng `cd` rải rác trong Dockerfile (khó đọc, dễ sai)
- Tạo cấu trúc rõ ràng
- Khi `docker exec -it container bash`, bắt đầu ở đây

### 2.3 COPY vs ADD

```dockerfile
# COPY: copy file/dir từ host vào image (ĐƠN GIẢN, KHUYẾN NGHỊ)
COPY src/ /app/src/
COPY requirements.txt .
COPY --chown=appuser:appuser . .   # Giữ ownership

# ADD: mạnh hơn COPY (CÓ THỂ NGUY HIỂM, ít dùng)
ADD archive.tar.gz /app/           # Tự động extract tar
ADD https://example.com/file.txt . # Download URL (KHÔNG NÊN DÙNG)

# NGUYÊN TẮC: Dùng COPY trừ khi cần extract tar
```

### 2.4 RUN - Chạy Lệnh Khi Build

```dockerfile
# Shell form (chạy qua /bin/sh -c)
RUN apt-get update && apt-get install -y curl

# Exec form (không qua shell - khuyến nghị cho CMD/ENTRYPOINT)
RUN ["apt-get", "install", "-y", "curl"]

# QUAN TRỌNG: Gộp nhiều lệnh apt-get vào 1 RUN
# Mỗi RUN tạo 1 layer → gộp lại để giảm số layer
RUN apt-get update && \
    apt-get install -y \
        curl \
        git \
        vim \
    && rm -rf /var/lib/apt/lists/*
    # ↑ Xóa apt cache để giảm size image
```

### 2.5 ENV - Biến Môi Trường

```dockerfile
# Set biến môi trường (tồn tại cả khi container chạy)
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_HOME=/app

# Có thể set nhiều biến
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info

# Dùng trong Dockerfile
WORKDIR $APP_HOME

# Override khi chạy container:
# docker run -e NODE_ENV=development myimage
```

### 2.6 ARG - Build Arguments (Chỉ Tồn Tại Khi Build)

```dockerfile
# ARG chỉ có trong quá trình build, không còn trong container
ARG APP_VERSION=1.0.0
ARG BUILD_DATE
ARG GIT_COMMIT

# Dùng trong build
LABEL version="$APP_VERSION" \
      build-date="$BUILD_DATE" \
      git-commit="$GIT_COMMIT"

# Override khi build:
# docker build --build-arg APP_VERSION=2.0.0 .
```

## Khác biệt ARG vs ENV
```dockerfile
ARG SECRET_KEY      # ✅ An toàn: không tồn tại trong container
ENV SECRET_KEY=xxx  # ❌ Nguy hiểm: có thể thấy qua docker inspect!
```

### 2.7 EXPOSE - Khai Báo Port

```dockerfile
# Khai báo container lắng nghe port nào (chỉ là documentation!)
EXPOSE 80
EXPOSE 443
EXPOSE 3000/tcp
EXPOSE 5353/udp

# EXPOSE KHÔNG TỰ ĐỘNG MAP PORT!
# Vẫn cần -p 8080:80 khi docker run
```

### 2.8 VOLUME - Khai Báo Volume Mount Point

```dockerfile
# Khai báo thư mục này sẽ là volume
VOLUME ["/app/data", "/app/logs"]

# Khi container chạy, Docker tự tạo anonymous volume nếu không mount
# Dùng -v để mount volume cụ thể
```

### 2.9 CMD vs ENTRYPOINT - Lệnh Khởi Động Container

Đây là phần **hay nhầm lẫn nhất** trong Dockerfile:

```dockerfile
# CMD: Lệnh mặc định khi chạy container (CÓ THỂ OVERRIDE)
CMD ["python", "app.py"]
CMD ["npm", "start"]
CMD ["nginx", "-g", "daemon off;"]

# Override CMD:
# docker run myimage python debug.py  ← Thay thế CMD

# ENTRYPOINT: Lệnh luôn luôn chạy (KHÓ OVERRIDE HƠN)
ENTRYPOINT ["python", "app.py"]

# Kết hợp: ENTRYPOINT = program, CMD = default arguments
ENTRYPOINT ["python", "app.py"]
CMD ["--port", "5000"]           # Default arguments

# docker run myimage               → python app.py --port 5000
# docker run myimage --port 8000   → python app.py --port 8000
# docker run --entrypoint bash myimage  → Vào shell (override ENTRYPOINT)
```

## Exec form vs Shell form
```dockerfile
# Shell form: chạy qua /bin/sh -c → PID 1 là sh, app là child
CMD python app.py

# Exec form: chạy trực tiếp → app là PID 1 (KHUYẾN NGHỊ)
CMD ["python", "app.py"]

# Tại sao quan trọng? 
# PID 1 nhận SIGTERM khi docker stop
# Shell form: sh nhận SIGTERM, có thể KHÔNG forward cho app
# → App không graceful shutdown được!
```

### 2.10 HEALTHCHECK - Kiểm Tra Sức Khỏe Container

```dockerfile
# Khai báo health check
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=5s \
            --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# --interval: Kiểm tra mỗi 30 giây
# --timeout: Timeout mỗi lần check
# --start-period: Cho app thời gian khởi động
# --retries: Sau N lần fail mới mark là unhealthy

# Kiểm tra health status
docker ps  # Cột STATUS hiện: Up 2 minutes (healthy)
docker inspect --format='{{.State.Health.Status}}' container-name
```

### 2.11 USER - Chạy Với User Không Phải Root

```dockerfile
# Tạo user không có quyền root (QUAN TRỌNG cho bảo mật!)
RUN groupadd -r appgroup && \
    useradd -r -g appgroup -s /bin/false appuser

# Chuyển sang user đó
USER appuser

# Từ đây, tất cả lệnh chạy với appuser
CMD ["python", "app.py"]

# CẢNH BÁO: Đặt USER SAU KHI đã làm tất cả việc cần root
# (install packages, copy files, set permissions)
```

### 2.12 LABEL - Metadata

```dockerfile
LABEL maintainer="team@company.com"
LABEL version="1.2.3"
LABEL description="Backend API service"
LABEL org.opencontainers.image.source="https://github.com/company/repo"

# Xem labels
docker inspect --format='{{json .Config.Labels}}' image-name
```


## 3. Best Practices Viết Dockerfile

### 3.1 Sắp Xếp Layers Đúng Thứ Tự (Cache Optimization)

```dockerfile
# ❌ SAI: Code thay đổi thường → invalidate tất cả layers sau
FROM python:3.11-slim
WORKDIR /app
COPY . .                      # Copy cả code vào
RUN pip install -r requirements.txt  # Cài deps SAU khi copy code
CMD ["python", "app.py"]

# Vấn đề: Khi sửa 1 dòng code → COPY . . thay đổi → 
# pip install chạy lại dù requirements.txt không đổi!


# ✅ ĐÚNG: Tách dependencies ra riêng
FROM python:3.11-slim
WORKDIR /app

# Bước 1: Copy CHỈ file requirements (ít thay đổi)
COPY requirements.txt .
# Bước 2: Install deps (cache nếu requirements.txt không đổi)
RUN pip install --no-cache-dir -r requirements.txt

# Bước 3: Copy code (thay đổi thường xuyên)
COPY . .
CMD ["python", "app.py"]
```

**Nguyên tắc:** Copy/thực hiện những thứ **ít thay đổi trước**, **thay đổi nhiều sau**.

### 3.2 Giảm Size Image

```dockerfile
# 1. Dùng base image nhỏ
FROM python:3.11-alpine  # 50MB thay vì 900MB

# 2. Gộp RUN commands, xóa cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. Dùng --no-cache-dir cho pip
RUN pip install --no-cache-dir -r requirements.txt

# 4. Dùng .dockerignore (xem bên dưới)
```

### 3.3 .dockerignore File

Giống `.gitignore`, ngăn không copy files không cần thiết vào image:

```
# .dockerignore
.git/
.gitignore
*.md
*.log
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.env
.env.*
node_modules/
.DS_Store
Thumbs.db
tests/
docs/
*.test.js
coverage/
dist/
.vscode/
.idea/
```

### 3.4 Không Lưu Secrets Trong Image

```dockerfile
# ❌ NGUY HIỂM: Secret hardcode trong image
ENV DB_PASSWORD=supersecret123
RUN curl -H "Authorization: Bearer mytoken" https://api.example.com

# ❌ NGUY HIỂM: Dù xóa sau vẫn còn trong layer trước!
RUN echo "mysecret" > /tmp/secret && \
    do_something_with_secret && \
    rm /tmp/secret    # Layer trước vẫn có secret!

# ✅ ĐÚNG: Truyền secrets khi RUN, không lưu trong image
RUN --mount=type=secret,id=mytoken \
    curl -H "Authorization: Bearer $(cat /run/secrets/mytoken)" \
    https://api.example.com

# ✅ ĐÚNG: Dùng biến môi trường khi chạy container (không build)
# docker run -e DB_PASSWORD=secret myimage
```


## 4. Multi-Stage Build (Quan Trọng!)

### 4.1 Vấn Đề Với Single Stage

```dockerfile
# Để build Go binary, cần Go compiler (~300MB)
# Nhưng binary chỉ cần runtime environment (~0MB)
# Single stage → image nặng 300MB+ chỉ để chạy binary nhỏ!
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o server .
CMD ["./server"]
# Image size: ~800MB 😱
```

### 4.2 Multi-Stage Build Giải Quyết Vấn Đề Này

```dockerfile
# Stage 1: Builder - có đầy đủ tools để build
FROM golang:1.21-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server .

# Stage 2: Runtime - chỉ có những gì cần để chạy
FROM alpine:3.18 AS runtime
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
# Chỉ copy binary từ stage builder, không copy Go compiler!
COPY --from=builder /build/server .
EXPOSE 8080
USER nobody
CMD ["./server"]
# Image size: ~15MB 🎉 (giảm từ 800MB!)
```

### 4.3 Multi-Stage Cho Node.js

```dockerfile
# Stage 1: Install dependencies & Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production    # ci: install từ lock file chính xác
COPY . .
RUN npm run build               # Compile TypeScript, bundle assets

# Stage 2: Production runtime
FROM node:18-alpine AS runtime
RUN apk --no-cache add dumb-init   # Proper PID 1 handler
WORKDIR /app
ENV NODE_ENV=production

# Chỉ copy những gì cần
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json .

USER node
EXPOSE 3000
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

### 4.4 Multi-Stage Cho Python

```dockerfile
# Stage 1: Build stage - compile dependencies
FROM python:3.11-slim AS builder
WORKDIR /app

# Cài build tools (chỉ cần khi compile C extensions)
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Cài vào thư mục /install thay vì system
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runtime
WORKDIR /app

# Chỉ cài runtime libs (không phải dev libs)
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages từ builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ .

# Security: chạy với user không có quyền root
RUN useradd --create-home appuser
USER appuser

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:5000/health')"
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:create_app()"]
```


## 5. Ví Dụ Dockerfile Hoàn Chỉnh Theo Ngôn Ngữ

### 5.1 Java Spring Boot

```dockerfile
# Stage 1: Build với Maven
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
# Download dependencies trước (cache layer)
RUN mvn dependency:go-offline -B
COPY src/ ./src/
RUN mvn package -DskipTests -B

# Stage 2: Runtime với JRE (nhỏ hơn JDK)
FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app

# Tạo user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy jar từ builder
COPY --from=builder /build/target/*.jar app.jar

# JVM tuning cho containers
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+OptimizeStringConcat \
               -Djava.security.egd=file:/dev/./urandom"

USER spring
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 5.2 Nginx Static Site

```dockerfile
# Stage 1: Build với Node
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build  # Output ra /app/dist

# Stage 2: Serve với Nginx
FROM nginx:1.25-alpine AS runtime
# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html
# Custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -qO- http://localhost/health || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

## `nginx.conf`
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;
    
    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
}
```


## 6. Build Image

```bash
# Build cơ bản
docker build -t myapp:v1.0 .

# Build với tag multiple
docker build -t myapp:v1.0 -t myapp:latest .

# Build với ARG
docker build \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  -t myapp:1.0.0 .

# Build stage cụ thể (multi-stage)
docker build --target builder -t myapp-builder .

# Build từ Dockerfile khác tên
docker build -f Dockerfile.prod -t myapp:prod .

# Build không dùng cache (khi cần rebuild hoàn toàn)
docker build --no-cache -t myapp:latest .

# Build và push ngay (BuildKit)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  -t myusername/myapp:latest .

# Xem output chi tiết
docker build --progress=plain -t myapp:latest .
```


## 7. Kiểm Tra & Debug Image

```bash
# Xem size image
docker images myapp

# Xem layers và size từng layer
docker history myapp:latest

# Phân tích image chi tiết (cài dive tool)
# https://github.com/wagoodman/dive
dive myapp:latest

# Chạy shell trong image để debug
docker run --rm -it myapp:latest sh

# Kiểm tra image không có gì nguy hiểm
docker scan myapp:latest          # Dùng Snyk (cũ)
docker scout cves myapp:latest    # Docker Scout (mới)
```
