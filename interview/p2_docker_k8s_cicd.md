---
markmap:
  title: "DevOps Interview — Docker & Kubernetes"
  collapse: false
---

# 🎯 DEVOPS INTERN INTERVIEW - DOCKER & KUBERNETES (CHI TIẾT ĐẦY ĐỦ)

## Theory
- Container runtime architecture, image layering, networking models, and orchestration concepts (pods, services, deployments) are key.

## Practice
- Provide sample multi-stage Dockerfile, networking examples, compose files, and Kubernetes manifests with probes, readiness/liveness, and HPA examples.

## PHẦN 1: DOCKER


### Q1. Docker hoạt động như thế nào? Giải thích kiến trúc?

**Trả lời đầy đủ:**

```
Docker Architecture:

┌────────────────────────────────────────────────────┐
│                  Docker Client (CLI)               │
│   docker build / run / pull / push / exec ...      │
└──────────────────────┬─────────────────────────────┘
                       │ REST API / Unix socket
┌──────────────────────▼─────────────────────────────┐
│               Docker Daemon (dockerd)              │
│   - Manages images, containers, networks, volumes  │
│   - Communicates with containerd                   │
└──────────────────────┬─────────────────────────────┘
                       │
┌──────────────────────▼─────────────────────────────┐
│                   containerd                       │
│   - Manages container lifecycle                    │
│   - Pulls images, creates containers               │
└──────────────────────┬─────────────────────────────┘
                       │
┌──────────────────────▼─────────────────────────────┐
│                   runc (OCI)                       │
│   - Actually creates and runs containers           │
│   - Uses Linux kernel: namespaces + cgroups        │
└────────────────────────────────────────────────────┘

Kernel features Docker dùng:
- Namespaces: Cách ly process, network, filesystem, user
  → pid, net, mnt, uts, ipc, user namespaces
- cgroups: Giới hạn CPU, memory, disk I/O
- UnionFS: Layer filesystem (overlay2, aufs)
```

#### Container KHÔNG phải VM
- Container: Processes chạy trực tiếp trên kernel host, isolated bởi namespaces
- VM: OS riêng, chạy trên hypervisor, nặng hơn nhiều


### Q2. Viết Dockerfile chuẩn cho Node.js app?

```dockerfile
# ===== PRODUCTION-GRADE DOCKERFILE =====

# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app

# Copy package files trước để cache tốt hơn
COPY package.json package-lock.json ./

# ci: clean install - đảm bảo đúng package-lock.json
# --only=production: chỉ install production deps cho runtime
RUN npm ci --only=production && cp -R node_modules /tmp/prod_modules

# Install all deps (including dev) for build stage
RUN npm ci

# Stage 2: Builder
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build
# Nếu TypeScript: tsc → ./dist
# Nếu Next.js: next build → ./.next

# Stage 3: Production image (nhỏ gọn nhất)
FROM node:20-alpine AS production

# Security: tạo non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodeuser

WORKDIR /app

# Copy chỉ những gì cần thiết
COPY --from=deps --chown=nodeuser:nodejs /tmp/prod_modules ./node_modules
COPY --from=builder --chown=nodeuser:nodejs /app/dist ./dist
COPY --chown=nodeuser:nodejs package.json ./

# Labels (metadata)
LABEL maintainer="devops@company.com" \
      version="1.0.0" \
      description="Production Node.js API"

# Env vars
ENV NODE_ENV=production \
    PORT=3000

# Health check (Docker sẽ monitor này)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

# Không dùng root
USER nodeuser

EXPOSE 3000

# CMD vs ENTRYPOINT:
# - CMD: Default command, có thể override khi docker run
# - ENTRYPOINT: Luôn chạy, CMD trở thành arguments
ENTRYPOINT ["node"]
CMD ["dist/index.js"]
```

## Giải thích tại sao multi-stage
- Stage `deps`: Separate dev và prod dependencies
- Stage `builder`: Chỉ cần khi build (TypeScript, Webpack, etc.)
- Stage `production`: Final image không có dev tools, source code TS, chỉ có compiled output
- **Kết quả**: Image giảm từ ~800MB → ~150MB


### Q3. Docker layer caching - tại sao COPY package.json TRƯỚC?

```dockerfile
# ❌ WRONG - Mỗi lần code thay đổi → rebuild npm install (~3-5 phút)
FROM node:20-alpine
WORKDIR /app
COPY . .           # Copy tất cả → cache invalidated mỗi khi file nào thay đổi
RUN npm ci         # Build lại từ đầu

# ✅ CORRECT - npm install chỉ rebuild khi package.json thay đổi
FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json ./   # Chỉ thay đổi khi deps thay đổi
RUN npm ci                                # Cache layer này
COPY . .                                  # Code changes chỉ ảnh hưởng từ đây
RUN npm run build
```

## Nguyên tắc cache
- Docker cache một layer nếu: layer đó và tất cả layers TRƯỚC nó không thay đổi
- Sắp xếp: những gì ít thay đổi nhất → lên đầu
- `COPY . .` luôn invalidate cache → để cuối cùng


### Q4. Docker networking - giải thích chi tiết từng loại?

```bash
# ===== BRIDGE (default) =====
# Container có IP riêng trong subnet 172.17.0.0/16
# Giao tiếp qua NAT để ra ngoài
# Containers trong cùng bridge network có thể ping nhau qua IP
# KHÔNG resolve bằng hostname (trừ custom bridge)

docker run --network bridge nginx     # Default

# Custom bridge - containers có thể resolve nhau bằng NAME
docker network create myapp-net
docker run --network myapp-net --name api  myapi:latest
docker run --network myapp-net --name db   postgres:15
# api container có thể `curl http://db:5432` (resolve bằng hostname "db")

# ===== HOST =====
# Container dùng network stack của host trực tiếp
# Port của container = port của host (không cần -p)
# Hiệu suất tốt nhất, nhưng không cách ly network
docker run --network host nginx
# nginx bind port 80 trực tiếp trên host

# ===== NONE =====
# Hoàn toàn không có network
# Dùng cho batch jobs không cần network
docker run --network none myprocessor

# ===== OVERLAY (Swarm/K8s) =====
# Multi-host networking
# Containers trên different hosts có thể communicate

# Xem networks
docker network ls
docker network inspect myapp-net
docker network connect myapp-net container-name   # Add container to network

# Port mapping
docker run -p 80:3000 nginx    # Host port 80 → Container port 3000
docker run -p 127.0.0.1:8080:3000 nginx   # Chỉ bind localhost
docker run -P nginx            # Auto-map random ports
```


### Q5. Docker Compose cho development environment?

```yaml
# docker-compose.yml - Complete example
version: '3.9'

services:
  # ===== API Service =====
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: development    # Multi-stage target
    image: myapp-api:dev
    container_name: myapp-api
    restart: unless-stopped
    
    ports:
      - "3000:3000"
      - "9229:9229"   # Node.js debugger
    
    volumes:
      - .:/app                    # Mount source code (hot reload)
      - /app/node_modules         # Prevent overwriting node_modules
    
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    
    env_file:
      - .env.local                # Local overrides (gitignored)
    
    depends_on:
      db:
        condition: service_healthy    # Wait for DB healthy
      redis:
        condition: service_started
    
    networks:
      - app-network
    
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ===== Database =====
  db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: unless-stopped
    
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres   # Dev only - never in production
    
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    
    ports:
      - "5432:5432"   # Dev: expose to host for DB GUI
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    
    networks:
      - app-network

  # ===== Redis =====
  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    restart: unless-stopped
    command: redis-server --save 60 1 --loglevel warning
    
    volumes:
      - redis_data:/data
    
    ports:
      - "6379:6379"
    
    networks:
      - app-network

  # ===== Nginx Reverse Proxy =====
  nginx:
    image: nginx:alpine
    container_name: myapp-nginx
    
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/sites:/etc/nginx/conf.d:ro
    
    ports:
      - "80:80"
      - "443:443"
    
    depends_on:
      - api
    
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
```

```bash
# Các lệnh Docker Compose
docker compose up -d                    # Start all services (detached)
docker compose up -d api                # Start specific service
docker compose down                     # Stop và remove containers
docker compose down -v                  # + xóa volumes
docker compose logs -f api              # Follow logs của api
docker compose exec api bash            # Shell vào container
docker compose ps                       # Xem status
docker compose restart api              # Restart service
docker compose build --no-cache api     # Rebuild image
docker compose pull                     # Pull latest images
docker compose scale worker=3           # Scale service
```


### Q6. Debug Docker containers?

```bash
# ===== CONTAINER KHÔNG START =====
docker ps -a                           # Xem all containers kể cả stopped
docker logs container-name             # Xem logs
docker logs --tail 50 container-name   # 50 lines cuối
docker inspect container-name          # Chi tiết JSON (env, mounts, network...)

# ===== EXEC VÀO CONTAINER ĐANG CHẠY =====
docker exec -it container-name bash    # Interactive bash
docker exec -it container-name sh      # sh (Alpine không có bash)
docker exec container-name env         # Xem env vars
docker exec container-name cat /etc/hosts

# ===== CONTAINER ĐÃ CRASH =====
# Không exec được vì container không chạy
# Chạy container với command override để debug
docker run -it --rm \
  --entrypoint sh \
  --env-file .env \
  myapp:latest                         # Override entrypoint

# Hoặc copy file ra
docker cp container-name:/app/logs/error.log ./

# ===== NETWORK DEBUG =====
# Chạy debug pod cùng network
docker run --rm -it \
  --network myapp-net \
  nicolaka/netshoot bash
# Trong container: curl http://api:3000, ping db, nslookup db

# ===== RESOURCE USAGE =====
docker stats                           # Real-time stats
docker stats --no-stream container     # Snapshot

# ===== IMAGE DEBUG =====
docker history myapp:latest            # Xem layers + size
dive myapp:latest                      # Interactive layer explorer (tool)

# ===== COMMON ISSUES =====
# 1. Permission denied → wrong user, wrong file ownership
# 2. Port already in use → kill process dùng port đó: lsof -i :3000 | kill
# 3. Out of memory → tăng memory limit
# 4. Cannot connect to DB → kiểm tra network, depends_on, healthcheck
# 5. Environment var không có → kiểm tra --env-file, docker inspect
```


## PHẦN 2: KUBERNETES (CHI TIẾT)


### Q7. Kubernetes kiến trúc - giải thích từng component?

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTROL PLANE                                │
│                                                                 │
│  ┌──────────────────┐  ┌─────────────┐  ┌───────────────────┐ │
│  │   kube-apiserver  │  │    etcd     │  │  kube-scheduler   │ │
│  │                  │  │             │  │                   │ │
│  │ - REST API gateway│  │ - Key-value │  │ - Quyết định Pod  │ │
│  │ - Auth (RBAC)    │  │   store     │  │   chạy node nào   │ │
│  │ - Validation     │  │ - Cluster   │  │ - Dựa vào:        │ │
│  │ - Persistence    │  │   state     │  │   resources,      │ │
│  └──────────────────┘  └─────────────┘  │   affinity,taints │ │
│                                          └───────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              kube-controller-manager                     │   │
│  │  ReplicaSet controller, Deployment controller,          │   │
│  │  Node controller, Job controller, ...                   │   │
│  │  → Reconciliation loop: "actual state → desired state"  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      WORKER NODES                               │
│                                                                 │
│  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────┐   │
│  │   kubelet   │  │   kube-proxy    │  │Container Runtime │   │
│  │             │  │                 │  │                  │   │
│  │ - Agent     │  │ - iptables/     │  │- containerd      │   │
│  │ - Pod       │  │   ipvs rules    │  │- Docker (legacy) │   │
│  │   lifecycle │  │ - Service→Pod   │  │- CRI-O           │   │
│  │ - Reports   │  │   routing       │  │                  │   │
│  │   to API    │  │                 │  │                  │   │
│  └─────────────┘  └─────────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

#### Khi bạn chạy `kubectl apply -f deployment.yaml` điều gì xảy ra?
```
1. kubectl gửi request đến kube-apiserver
2. API server authenticate (RBAC) và validate YAML
3. API server lưu vào etcd
4. Deployment controller phát hiện Deployment mới → tạo ReplicaSet
5. ReplicaSet controller phát hiện ReplicaSet → tạo Pods
6. Scheduler phát hiện Pods chưa có nodeName → schedule lên node phù hợp
7. kubelet trên node đó phát hiện có Pod mới → pull image → start container
8. kubelet report status về API server
9. kubectl rollout status hiển thị tiến trình
```


### Q8. Pod lifecycle và trạng thái?

```yaml
# Pod có các phases:
Pending   → Pod được tạo, chờ schedule hoặc pull image
Running   → Ít nhất 1 container đang chạy
Succeeded → Tất cả containers exit 0 (Jobs)
Failed    → Ít nhất 1 container exit non-zero
Unknown   → API server mất liên lạc với node

# Container states:
Waiting   → Chờ image pull, hoặc previous container exit
Running   → Đang chạy
Terminated → Exit với code

# Debug Pod status:
kubectl describe pod api-pod-xyz    # Events, resource, probes
kubectl logs api-pod-xyz            # Container logs
kubectl logs api-pod-xyz --previous # Logs lần chạy trước (nếu restarted)
kubectl logs api-pod-xyz -c sidecar # Logs của container cụ thể
kubectl get events -n production --sort-by='.lastTimestamp'  # Cluster events
```

**Các lý do Pod không start:**

| Status | Nguyên nhân | Cách debug |
|--------|-------------|-----------|
| `ImagePullBackOff` | Sai image name, registry auth fail | `kubectl describe pod` → xem Events |
| `CrashLoopBackOff` | App crash, OOM, wrong config | `kubectl logs --previous` |
| `Pending` (lâu) | Không đủ resource, taint không match | `kubectl describe pod` → xem Events |
| `OOMKilled` | Vượt memory limit | Tăng `resources.limits.memory` |
| `ContainerCreating` (lâu) | PV mount fail, secret/configmap missing | `kubectl describe pod` → Events |


### Q9. Services trong Kubernetes - giải thích TỪNG loại kèm use case?

```yaml
# ===== ClusterIP (DEFAULT) =====
# Chỉ accessible TRONG cluster
# Có virtual IP (ClusterIP) stable dù Pods thay đổi
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: ClusterIP
  selector:
    app: api          # Route đến pods có label này
  ports:
  - port: 80          # Service port (clients dùng)
    targetPort: 3000   # Container port

# Use case: Microservices giao tiếp nội bộ
# worker gọi: http://api-service:80  (hoặc http://api-service.production.svc.cluster.local)

---
# ===== NodePort =====
# Expose qua port cố định trên TẤT CẢ nodes (30000-32767)
# client → NodeIP:NodePort → Service → Pod
apiVersion: v1
kind: Service
metadata:
  name: api-nodeport
spec:
  type: NodePort
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 3000
    nodePort: 30080   # Nếu không set → random trong range

# Use case: Dev/staging environment khi chưa có LB
# Nhược điểm: Phải biết Node IP, không có HA

---
# ===== LoadBalancer =====
# Cloud provider tạo External Load Balancer (Azure LB, AWS ELB...)
# Có External IP public
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"  # Azure: Internal LB
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
  - port: 443
    targetPort: 3000

# AKS sẽ tự tạo Azure Load Balancer và assign External IP
# Use case: Production external-facing services

---
# ===== ExternalName =====
# DNS alias → external service (không route traffic)
apiVersion: v1
kind: Service
metadata:
  name: postgres-external
spec:
  type: ExternalName
  externalName: mydb.postgres.database.azure.com
# Pods có thể gọi: postgres-external:5432 → resolve đến Azure DB
# Use case: Kết nối managed cloud DB mà không thay đổi app code
```


### Q10. Ingress - tại sao cần Ingress?

```
Vấn đề với LoadBalancer:
- Mỗi Service cần 1 LoadBalancer = 1 public IP = 1 External LB (tốn tiền)
- Không có routing rules (path-based, host-based)

Ingress giải quyết:
- 1 External LB/IP cho nhiều services
- Routing rules: /api → api-service, /admin → admin-service
- TLS termination tại Ingress
- Rate limiting, auth, WAF (tùy Ingress controller)
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    # NGINX Ingress Controller specific
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"   # Auto TLS
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.company.com
    - admin.company.com
    secretName: myapp-tls         # cert-manager sẽ tạo secret này

  rules:
  # Host-based routing
  - host: api.company.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      - path: /health
        pathType: Exact
        backend:
          service:
            name: health-service
            port:
              number: 80

  - host: admin.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```


### Q11. Resource Requests và Limits - tại sao quan trọng?

```yaml
# Requests: Guaranteed resources cho scheduling
# Limits: Max resources có thể dùng

containers:
- name: api
  image: myapp:1.0
  resources:
    requests:
      memory: "128Mi"    # Scheduler dùng để chọn node (node phải có ≥128Mi free)
      cpu: "250m"         # 250 millicores = 0.25 CPU core
    limits:
      memory: "512Mi"    # Vượt quá → OOMKilled (Linux kill process)
      cpu: "500m"         # Vượt quá → CPU throttled (không bị kill)
```

## Tại sao PHẢI set resources
- **Không có requests**: Scheduler không biết đặt pod lên node nào → có thể overload node
- **Không có limits**: 1 pod có thể dùng hết tài nguyên → ảnh hưởng pods khác (noisy neighbor)
- **OOMKilled**: App dùng nhiều hơn memory limit → Linux kernel kill process → `CrashLoopBackOff`

## Best practice
```yaml
# Dùng VPA (Vertical Pod Autoscaler) để recommend values
# Bắt đầu với:
requests: 50% của expected usage
limits: 2x requests (cho spikes)

# Ví dụ cho Node.js API:
requests: cpu=100m, memory=128Mi
limits: cpu=500m, memory=512Mi
```


### Q12. Deployment strategy thực tế?

```yaml
# Rolling Update (default)
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Tối đa 6+2=8 pods trong quá trình update
      maxUnavailable: 1  # Tối thiểu 6-1=5 pods phải running
  # Kết quả: Update từng pod, không down service
  # Tổng max: 8 pods đang running cùng lúc
  # Tối thiểu: 5 pods healthy

# Recreate (có downtime, không dùng cho production)
  strategy:
    type: Recreate
    # Xóa tất cả v1 pods → tạo v2 pods

# Canary với Argo Rollouts (advanced)
# 10% traffic → v2, kiểm tra, tăng dần lên 100%

# Rollback
kubectl rollout undo deployment/api              # Về version trước
kubectl rollout undo deployment/api --to-revision=3  # Về version cụ thể
kubectl rollout history deployment/api           # Xem history
kubectl rollout status deployment/api            # Monitor progress
```


### Q13. ConfigMap và Secret - best practices?

```bash
# Tạo ConfigMap từ file config
kubectl create configmap app-config \
  --from-file=config.yaml \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_WORKERS=4

# Tạo Secret an toàn
# ❌ WRONG: Lưu secret trong git
kubectl create secret generic db-secret \
  --from-literal=password=mysecret

# ✅ BETTER: Từ environment variable (không lộ trong terminal history)
kubectl create secret generic db-secret \
  --from-literal=password=$DB_PASSWORD

# ✅ BEST: Dùng Azure Key Vault + CSI Driver
# Secret lưu trong AKV, K8s chỉ reference, không store thật

# Inject vào pod
envFrom:
- configMapRef:
    name: app-config
- secretRef:
    name: db-secret

# Mount như file (cho config.yaml)
volumeMounts:
- name: config-volume
  mountPath: /etc/myapp
  readOnly: true

volumes:
- name: config-volume
  configMap:
    name: app-config
```


## PHẦN 3: TÌNH HUỐNG THỰC TẾ KHI PHỎNG VẤN


### "Production pod đột ngột crash, bạn xử lý như thế nào?"

```bash
# Bước 1: Triage nhanh (< 2 phút)
kubectl get pods -n production              # Pod status gì?
kubectl get events -n production --sort-by='.lastTimestamp' | tail -20

# Bước 2: Xác định nguyên nhân
kubectl describe pod api-pod-xyz -n production
# → Xem Events, Last State, Exit Code

# Exit code meanings:
# 0   = Graceful exit
# 1   = General error (app crash)
# 137 = OOMKilled (137 = 128 + 9, signal 9 = SIGKILL)
# 139 = Segfault (C/C++ crash)
# 143 = SIGTERM (timeout, graceful but forced)

kubectl logs api-pod-xyz -n production --previous
# Logs của lần chạy trước khi crash

# Bước 3: Giải pháp ngay lập tức
# Nếu OOMKilled → Tăng memory limit tạm thời
kubectl patch deployment api -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","resources":{"limits":{"memory":"1Gi"}}}]}}}}'

# Nếu app bug → Rollback
kubectl rollout undo deployment/api -n production
# Verify
kubectl rollout status deployment/api -n production

# Bước 4: Investigate root cause (không vội)
# Check metrics (Grafana/Azure Monitor) trước thời điểm crash
# Check recent deployments
kubectl rollout history deployment/api

# Bước 5: Communicate
# Update Slack #incidents với: Impact, Status, ETA fix
```

### "Deployment mới vừa gây incident, rollback như thế nào?"

```bash
# Kiểm tra history
kubectl rollout history deployment/api -n production
# REVISION  CHANGE-CAUSE
# 1         Initial deployment
# 2         Update to v1.1.0
# 3         Update to v1.2.0  ← broken version

# Rollback về revision 2
kubectl rollout undo deployment/api --to-revision=2 -n production

# Hoặc nếu dùng Helm
helm rollback myapp 2 -n production

# Monitor
kubectl rollout status deployment/api -n production
kubectl get pods -n production -w   # Watch pod status

# Notify team
# "Rolled back api from v1.2.0 to v1.1.0 at 14:35 UTC.
#  Impact: ~5 minutes elevated error rate.
#  Root cause: Being investigated."
```
