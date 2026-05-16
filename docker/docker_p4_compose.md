# 🐳 DOCKER TOÀN TẬP - PHẦN 4: DOCKER COMPOSE & NETWORKING NÂNG CAO

---

## 1. Docker Compose Là Gì?

Docker Compose là công cụ để **định nghĩa và chạy multi-container applications** bằng file YAML. Thay vì gõ nhiều lệnh `docker run` phức tạp, bạn viết một file `docker-compose.yml` và chạy bằng một lệnh.

```bash
# Thay vì:
docker network create app-net
docker volume create db-data
docker run -d --name db --network app-net -v db-data:/data -e POSTGRES_PASSWORD=secret postgres:15
docker run -d --name api --network app-net -p 3000:3000 -e DB_HOST=db myapi:latest
docker run -d --name nginx --network app-net -p 80:80 nginx:alpine

# Chỉ cần:
docker compose up -d
```

---

## 2. Cú Pháp Docker Compose File

### 2.1 Cấu Trúc Cơ Bản

```yaml
# docker-compose.yml
version: "3.9"   # Version của compose file format

services:         # Định nghĩa các containers
  service-name-1:
    # config...
  service-name-2:
    # config...

networks:         # Định nghĩa networks
  network-name:
    # config...

volumes:          # Định nghĩa volumes
  volume-name:
    # config...
```

### 2.2 Tất Cả Các Config Quan Trọng Trong Service

```yaml
services:
  backend:
    # Image để dùng (hoặc build từ Dockerfile)
    image: mycompany/backend:v1.2.3
    
    # Hoặc build từ Dockerfile
    build:
      context: ./backend          # Thư mục chứa Dockerfile
      dockerfile: Dockerfile.prod # Tên Dockerfile (mặc định: Dockerfile)
      args:
        APP_VERSION: "1.2.3"
        BUILD_ENV: "production"
      target: runtime             # Build đến stage nào (multi-stage)
    
    # Tên container
    container_name: my-backend
    
    # Port mapping
    ports:
      - "3000:3000"        # host:container
      - "127.0.0.1:3000:3000"  # Chỉ bind localhost (bảo mật hơn)
    
    # Biến môi trường
    environment:
      NODE_ENV: production
      PORT: 3000
      DB_HOST: postgres
    
    # Hoặc từ file
    env_file:
      - .env
      - .env.production
    
    # Volumes
    volumes:
      - ./logs:/app/logs          # Bind mount
      - app-data:/app/data        # Named volume
      - ./config.json:/app/config.json:ro  # Read-only
    
    # Networks
    networks:
      - internal-net
      - proxy-net
    
    # Phụ thuộc vào service khác
    depends_on:
      postgres:
        condition: service_healthy  # Chờ cho đến khi healthy
      redis:
        condition: service_started  # Chỉ cần started
    
    # Restart policy
    restart: unless-stopped
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 256M
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    
    # Command override
    command: ["node", "server.js", "--port", "3000"]
    
    # Entrypoint override
    entrypoint: ["/docker-entrypoint.sh"]
    
    # Labels
    labels:
      app.version: "1.2.3"
      app.team: "backend"
    
    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
    
    # Security
    security_opt:
      - no-new-privileges:true
    read_only: true             # Filesystem read-only
    tmpfs:
      - /tmp                   # Writable temp dir
      - /run
    user: "1000:1000"          # Run as user
```

---

## 3. Ví Dụ Thực Tế: Full Stack Web App

### 3.1 Cấu Trúc Project

```
myapp/
├── docker-compose.yml
├── docker-compose.override.yml   # Override cho development
├── docker-compose.prod.yml       # Production config
├── .env
├── backend/
│   ├── Dockerfile
│   └── src/
├── frontend/
│   ├── Dockerfile
│   └── src/
└── nginx/
    └── nginx.conf
```

### 3.2 docker-compose.yml (Base Config)

```yaml
version: "3.9"

services:
  # =============================
  # DATABASE: PostgreSQL
  # =============================
  postgres:
    image: postgres:15-alpine
    container_name: myapp-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-myapp}
      POSTGRES_USER: ${POSTGRES_USER:-appuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - internal-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-appuser} -d ${POSTGRES_DB:-myapp}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    # Giới hạn tài nguyên
    deploy:
      resources:
        limits:
          memory: 512M

  # =============================
  # CACHE: Redis
  # =============================
  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:-redispass} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    networks:
      - internal-net
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redispass}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  # =============================
  # BACKEND: Python FastAPI
  # =============================
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: runtime
    container_name: myapp-backend
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER:-appuser}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-myapp}
      REDIS_URL: redis://:${REDIS_PASSWORD:-redispass}@redis:6379/0
      SECRET_KEY: ${SECRET_KEY:?SECRET_KEY is required}
      ENVIRONMENT: ${ENVIRONMENT:-production}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - internal-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
    volumes:
      - backend-uploads:/app/uploads
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"

  # =============================
  # FRONTEND: Next.js
  # =============================
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      target: runtime
      args:
        NEXT_PUBLIC_API_URL: ${API_URL:-http://localhost/api}
    container_name: myapp-frontend
    restart: unless-stopped
    environment:
      NODE_ENV: production
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - internal-net

  # =============================
  # REVERSE PROXY: Nginx
  # =============================
  nginx:
    image: nginx:1.25-alpine
    container_name: myapp-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - frontend
      - backend
    networks:
      - internal-net
      - proxy-net
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  # =============================
  # BACKGROUND JOBS: Celery Worker
  # =============================
  worker:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: runtime
    container_name: myapp-worker
    restart: unless-stopped
    command: ["celery", "-A", "app.celery", "worker", "--loglevel=info", "--concurrency=4"]
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER:-appuser}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-myapp}
      REDIS_URL: redis://:${REDIS_PASSWORD:-redispass}@redis:6379/0
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - internal-net

  # =============================
  # MONITORING: Flower (Celery Monitor)
  # =============================
  flower:
    image: mher/flower:2.0
    container_name: myapp-flower
    restart: unless-stopped
    command: ["celery", "flower", "--broker=redis://:${REDIS_PASSWORD:-redispass}@redis:6379/0"]
    ports:
      - "127.0.0.1:5555:5555"  # Chỉ expose trên localhost
    depends_on:
      - redis
    networks:
      - internal-net

# =============================
# NETWORKS
# =============================
networks:
  internal-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  proxy-net:
    driver: bridge

# =============================
# VOLUMES
# =============================
volumes:
  postgres-data:
    driver: local
  redis-data:
    driver: local
  backend-uploads:
    driver: local
```

### 3.3 .env File

```bash
# .env (KHÔNG commit file này lên git!)
POSTGRES_DB=myapp_prod
POSTGRES_USER=appuser
POSTGRES_PASSWORD=very-secure-password-here
REDIS_PASSWORD=redis-secure-password
SECRET_KEY=your-very-long-random-secret-key-here
API_URL=https://myapp.company.com/api
ENVIRONMENT=production
```

### 3.4 docker-compose.override.yml (Development)

```yaml
# File này tự động được merge khi chạy docker compose up
# Dùng cho môi trường development
version: "3.9"

services:
  backend:
    build:
      target: development          # Dùng dev stage
    volumes:
      - ./backend/src:/app/src     # Hot reload
    environment:
      ENVIRONMENT: development
      DEBUG: "true"
    ports:
      - "8000:8000"               # Expose port để debug

  frontend:
    build:
      target: development
    volumes:
      - ./frontend/src:/app/src   # Hot reload
    environment:
      NODE_ENV: development

  postgres:
    ports:
      - "5432:5432"               # Expose để kết nối từ host

  redis:
    ports:
      - "6379:6379"               # Expose để kết nối từ host
```

---

## 4. Các Lệnh Docker Compose

```bash
# Khởi động tất cả services (background)
docker compose up -d

# Khởi động chỉ một số services
docker compose up -d postgres redis backend

# Build lại images trước khi start
docker compose up -d --build

# Dừng tất cả services
docker compose down

# Dừng và xóa luôn volumes (cẩn thận!)
docker compose down -v

# Xem trạng thái
docker compose ps

# Xem logs
docker compose logs
docker compose logs -f backend         # Follow logs service backend
docker compose logs -f backend worker  # Nhiều services

# Scale service (chạy nhiều instance)
docker compose up -d --scale backend=3

# Restart một service
docker compose restart backend

# Chạy lệnh trong service
docker compose exec backend bash
docker compose exec backend python manage.py migrate

# Chạy lệnh mà không cần service đang running
docker compose run --rm backend python manage.py createsuperuser

# Pull images mới nhất
docker compose pull

# Build images
docker compose build
docker compose build backend --no-cache

# Xem config đã merge (debug)
docker compose config

# Dùng file compose khác
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 5. Networking Nâng Cao

### 5.1 Service Discovery Trong Compose

```yaml
# Trong docker compose, các services tự động có DNS records
# Backend có thể kết nối với postgres bằng hostname "postgres"
services:
  backend:
    environment:
      DB_HOST: postgres    # ← Đây chính là service name
      CACHE_HOST: redis

  postgres:
    image: postgres:15

  redis:
    image: redis:7
```

```bash
# Kiểm tra DNS resolution bên trong container
docker compose exec backend nslookup postgres
docker compose exec backend ping redis
```

### 5.2 Nhiều Networks - Phân Tầng Bảo Mật

```yaml
# Pattern phổ biến trong doanh nghiệp:
# - DMZ network: Chỉ nginx expose ra ngoài
# - Internal network: Services nội bộ
# - Database network: Chỉ services cần DB mới access được

services:
  nginx:
    networks:
      - dmz          # Tiếp nhận traffic từ internet
      - internal     # Giao tiếp với frontend/backend

  frontend:
    networks:
      - internal     # Không cần biết DB tồn tại

  backend:
    networks:
      - internal     # Giao tiếp với frontend/nginx
      - database     # Kết nối với DB

  postgres:
    networks:
      - database     # Chỉ backend mới kết nối được

  redis:
    networks:
      - database

networks:
  dmz:
    driver: bridge
  internal:
    driver: bridge
    internal: true   # Không có internet access
  database:
    driver: bridge
    internal: true
```

### 5.3 External Networks (Kết Nối Các Compose Files)

```yaml
# Project A: monitoring-stack/docker-compose.yml
services:
  prometheus:
    networks:
      - monitoring

networks:
  monitoring:
    name: monitoring-network   # Đặt tên cụ thể

# ---

# Project B: myapp/docker-compose.yml
services:
  backend:
    networks:
      - internal
      - monitoring   # Kết nối vào monitoring stack của project A

networks:
  internal:
    driver: bridge
  monitoring:
    external: true             # Network này không do compose file này tạo
    name: monitoring-network   # Dùng network đã có sẵn
```

---

## 6. Volumes Nâng Cao

### 6.1 Volume Drivers

```yaml
volumes:
  # Local volume (mặc định)
  db-data:
    driver: local
  
  # NFS mount (share storage giữa nhiều servers)
  shared-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs-server.company.com,rw
      device: ":/exports/myapp"
  
  # External volume (tạo sẵn bên ngoài compose)
  production-data:
    external: true   # Phải tạo thủ công: docker volume create production-data
```

### 6.2 Tmpfs Mounts (Dữ Liệu Trong RAM)

```yaml
services:
  api:
    tmpfs:
      - /tmp              # Temp files trong RAM
      - /run:size=100m    # Giới hạn size
    # Dùng cho: session data, temp uploads, secrets
```

---

## 7. Profiles - Chạy Services Có Điều Kiện

```yaml
services:
  # Luôn chạy (không có profile)
  backend:
    image: mybackend

  postgres:
    image: postgres:15

  # Chỉ chạy khi chỉ định profile
  pgadmin:
    image: dpage/pgadmin4
    profiles:
      - debug
    ports:
      - "5050:80"

  mailhog:             # Fake email server cho dev
    image: mailhog/mailhog
    profiles:
      - debug
    ports:
      - "8025:8025"

  nginx:
    image: nginx:alpine
    profiles:
      - production
```

```bash
# Chạy mặc định (không có profile services)
docker compose up -d

# Bật thêm debug profile
docker compose --profile debug up -d

# Bật production profile
docker compose --profile production up -d
```

---

## 8. Thực Hành: Monitoring Stack (Prometheus + Grafana)

```yaml
# monitoring/docker-compose.yml
version: "3.9"

services:
  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    ports:
      - "127.0.0.1:9090:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/datasources:/etc/grafana/provisioning/datasources:ro
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.6.1
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring:
    name: monitoring-network
```

---

> **Tiếp theo: Phần 5** - Bảo mật, Production Best Practices, Registry Private, CI/CD Integration
