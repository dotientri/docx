# ---
markmap:
  title: "Kubernetes — Troubleshooting & Best Practices"
  collapse: false
# ---

# ☸️ KUBERNETES TOÀN TẬP - PHẦN 5: TROUBLESHOOTING, BEST PRACTICES & CHEAT SHEET

## Theory
- Troubleshooting follows a structured approach: inspect pod status/events, logs, node conditions, and networking; follow resource and quota checks to find root causes.

## Practice
- Use `kubectl describe`, `kubectl logs`, `kubectl exec`, debug containers, `kubectl top`, and CoreDNS/Ingress logs; automate workspace cleanup and set resource requests/limits and PodDisruptionBudgets.

## 1. Debugging Pods

### 1.1 Debug Lifecycle

```bash
# ===== POD KHÔNG CHẠY ĐƯỢC =====

# Bước 1: Xem status
kubectl get pods -n production
# NAME          READY   STATUS             RESTARTS   AGE
# myapp-xxx     0/1     CrashLoopBackOff   5          3m
# myapp-yyy     0/1     Pending            0          1m
# myapp-zzz     0/1     ImagePullBackOff   0          2m

# Bước 2: Describe Pod (xem Events!)
kubectl describe pod myapp-xxx -n production
# Events section sẽ chỉ ra vấn đề:
# Warning  BackOff    OOMKilled: Container killed due to memory limit
# Warning  Failed     Error: ImagePullBackOff

# Bước 3: Xem logs
kubectl logs myapp-xxx -n production
kubectl logs myapp-xxx --previous  # Logs của container trước khi crash
kubectl logs myapp-xxx -c sidecar  # Sidecar container logs

# ===== DEBUG THEO STATUS =====

# Pending: Không schedule được
# Nguyên nhân thường gặp:
# - Không đủ resources (CPU/memory)
# - Node không match nodeSelector/affinity
# - PVC chưa được bind

kubectl describe pod pending-pod | grep -A 10 Events:
# Warning  FailedScheduling  0/3 nodes are available: 
#   3 Insufficient memory

# Fix: Xem node resources
kubectl describe nodes | grep -A 5 "Allocated resources"
kubectl top nodes                   # CPU/Memory usage theo node

# CrashLoopBackOff: Container crash sau khi start
# Xem logs của container crash
kubectl logs crashed-pod --previous

# Lỗi thường gặp:
# - Application error (check logs)
# - OOMKilled (tăng memory limits)
# - Bad configuration (check env vars)
# - Readiness probe fail

# ImagePullBackOff: Không pull được image
# Kiểm tra:
# 1. Image name đúng không?
# 2. Registry credentials?
kubectl get events | grep ImagePull
kubectl describe pod | grep "Image:"

# Fix credentials
kubectl create secret docker-registry regcred \
  --docker-server=registry.company.com \
  --docker-username=user \
  --docker-password=pass
  
# Thêm vào Pod spec:
# spec.imagePullSecrets: [{name: regcred}]
```

### 1.2 Debug Running Pods

```bash
# ===== EXEC VÀO POD =====
kubectl exec -it pod-name -- bash
kubectl exec -it pod-name -c container-name -- sh

# Debug tools trong production container (thường không có)
# Dùng ephemeral debug containers (K8s 1.23+)
kubectl debug -it pod-name --image=busybox --target=container-name

# Copy debug tools vào pod
kubectl cp ./tools/debug.sh pod-name:/tmp/

# ===== NETWORK DEBUG =====
# Chạy debug pod
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash
# Trong pod:
ping google.com
curl http://myapp.production.svc.cluster.local/health
nslookup myapp.production.svc.cluster.local
traceroute 8.8.8.8

# Test service connectivity
kubectl exec -it any-pod -- curl http://service-name/endpoint
kubectl exec -it any-pod -- wget -O- http://service-name:port/endpoint

# ===== DNS DEBUG =====
kubectl exec -it any-pod -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it any-pod -- cat /etc/resolv.conf
# nameserver 10.96.0.10 ← CoreDNS ClusterIP

# Kiểm tra CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### 1.3 Resource Debug

```bash
# ===== OOM KILL =====
kubectl describe pod pod-name | grep -i "oom\|killed\|memory"
kubectl get events | grep OOMKilled

# Xem actual memory usage
kubectl top pod pod-name

# Fix: Tăng memory limit
kubectl set resources deployment/myapp --limits=memory=1Gi

# ===== RESOURCE QUOTA =====
kubectl describe resourcequota -n production
# → Xem what's used vs what's allowed

# Pod không schedule do quota
kubectl get events | grep "exceeded quota"

# ===== NODE ISSUES =====
kubectl get nodes
kubectl describe node node1
# Conditions:
# MemoryPressure: True    ← Node sắp hết RAM
# DiskPressure: True      ← Node sắp hết disk
# Ready: False            ← Node down

# Xem taints (có thể node bị taint không mong muốn)
kubectl describe node node1 | grep Taint

# Drain node trước khi maintenance
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node1   # Sau khi maintenance
```


## 2. Common Issues & Solutions

### 2.1 Permission Issues

```bash
# ===== FORBIDDEN ERROR =====
# Error: pods "myapp" is forbidden: User "alice" cannot get resource "pods"

# Kiểm tra quyền
kubectl auth can-i get pods --as=alice -n production

# Xem roles của user
kubectl get rolebindings -n production -o yaml | grep -A 5 alice

# Fix: Thêm role
kubectl create rolebinding alice-developer \
  --role=developer \
  --user=alice \
  -n production

# ===== SERVICE ACCOUNT ISSUES =====
# Kiểm tra service account có đủ quyền
kubectl auth can-i get secrets \
  --as=system:serviceaccount:production:myapp \
  -n production
```

### 2.2 Network Issues

```bash
# ===== SERVICE KHÔNG RESPOND =====

# 1. Service selector match Pods?
kubectl get service myapp -o yaml | grep selector
kubectl get pods -l app=myapp   # Pod labels phải match

# 2. Endpoints được tạo không?
kubectl get endpoints myapp
# NAME     ENDPOINTS                   AGE
# myapp    10.244.0.5:8080,10.244.0.6  5m
# Nếu <none>: Pod không running hoặc selector sai

# 3. Port đúng không?
kubectl get service myapp -o yaml | grep -A 5 ports

# 4. Firewall/NetworkPolicy chặn?
kubectl get networkpolicies -n production

# ===== DNS KHÔNG RESOLVE =====
kubectl exec -it debug-pod -- nslookup myapp.production.svc.cluster.local

# CoreDNS có chạy không?
kubectl get pods -n kube-system -l k8s-app=kube-dns

# ===== INGRESS KHÔNG HOẠT ĐỘNG =====
kubectl describe ingress myapp-ingress
kubectl get ingress myapp-ingress
# Check EXTERNAL-IP column

# Nginx ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Test ingress
curl -H "Host: api.company.com" http://INGRESS_IP/endpoint
```


## 3. Performance Best Practices

### 3.1 Resource Management

```yaml
# ===== LUÔN ĐẶT RESOURCE REQUESTS/LIMITS =====
resources:
  requests:            # Guaranteed resources
    memory: "256Mi"    # QoS: Guaranteed (requests = limits)
    cpu: "250m"        # QoS: Burstable (requests < limits)
  limits:              # Maximum
    memory: "512Mi"    # QoS: BestEffort (no requests/limits - avoid!)
    cpu: "500m"

# Chọn resource profile phù hợp:
# Guaranteed: requests = limits → Cho critical apps
# Burstable:  requests < limits → Cho burst workloads
# BestEffort: Không có requests/limits → Tránh trong production

# ===== NAMESPACE QUOTAS =====
# Đặt ResourceQuota để ngăn resource exhaustion
# Đặt LimitRange để enforce defaults

# ===== POD DISRUPTION BUDGET =====
# Đảm bảo minimum availability khi node drain/upgrade
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2     # Hoặc maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

### 3.2 Image Best Practices

```dockerfile
# ===== DOCKERFILE CHO PRODUCTION =====
# Multi-stage để giảm image size
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /myapp .

# Distroless hoặc minimal base image
FROM gcr.io/distroless/static-debian12
COPY --from=builder /myapp /myapp
ENTRYPOINT ["/myapp"]

# Pinned version tags (không dùng :latest trong production!)
FROM ubuntu:22.04
FROM nginx:1.25.3-alpine3.18
```

```yaml
# Image pull policy
spec:
  containers:
    - name: myapp
      image: company/myapp:2.1.0   # Specific tag!
      imagePullPolicy: IfNotPresent # Always, IfNotPresent, Never
      # IfNotPresent: Pull chỉ nếu không có trong cache
      # Always: Luôn pull (dùng với :latest - không khuyến nghị)
```

### 3.3 High Availability

```yaml
# ===== ANTI-AFFINITY (Spread Pods) =====
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: myapp
        topologyKey: kubernetes.io/hostname
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: myapp
          topologyKey: topology.kubernetes.io/zone

# ===== POD DISRUPTION BUDGET =====
# Minimum 2 Pods always available

# ===== TOPOLOGY SPREAD CONSTRAINTS =====
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: myapp
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp

# ===== GRACEFUL SHUTDOWN =====
spec:
  terminationGracePeriodSeconds: 60
  containers:
    - lifecycle:
        preStop:
          exec:
            command: ["/bin/sh", "-c", "sleep 10"]
      # Cho phép existing requests complete trước khi kill
```


## 4. Production Checklist

```
☐ Resources: Tất cả containers có requests/limits
☐ Health Checks: Readiness và Liveness probes
☐ Security:
  ☐ Chạy với non-root user
  ☐ readOnlyRootFilesystem: true
  ☐ allowPrivilegeEscalation: false
  ☐ Drop ALL capabilities
☐ HA: Anti-affinity rules, min 2 replicas
☐ PDB: Pod Disruption Budget
☐ HPA: Autoscaling configured
☐ NetworkPolicy: Deny all + allow specific
☐ RBAC: Minimal permissions
☐ Secrets: Không hardcode trong image/configmap
☐ Images: Pinned versions, vulnerability scanned
☐ Logging: Structured JSON logs to stdout
☐ Monitoring: ServiceMonitor và alerts
☐ Backup: Persistent data được backup
☐ Resource Quotas: Namespace quotas defined
☐ Update Strategy: RollingUpdate với maxUnavailable: 0
```


## 5. kubectl Cheat Sheet Toàn Tập

```bash
# ===== GET =====
kubectl get pods,svc,deploy,cm,secret,ing,pvc -n default
kubectl get all --all-namespaces
kubectl get pods -o wide
kubectl get pods -l app=myapp
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n production -w

# ===== DESCRIBE =====
kubectl describe pod POD -n NS
kubectl describe node NODE
kubectl describe service SVC

# ===== LOGS =====
kubectl logs POD -f --tail=100
kubectl logs POD --previous
kubectl logs -l app=myapp -f
kubectl logs POD -c CONTAINER

# ===== EXEC =====
kubectl exec -it POD -- bash
kubectl exec POD -- env
kubectl exec POD -- ls /etc

# ===== APPLY =====
kubectl apply -f file.yaml
kubectl apply -f ./dir/
kubectl apply -k ./kustomize/   # Kustomize
kubectl delete -f file.yaml

# ===== SCALE =====
kubectl scale deployment myapp --replicas=5
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=70

# ===== ROLLOUT =====
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp
kubectl rollout undo deployment/myapp
kubectl rollout restart deployment/myapp

# ===== PORT-FORWARD =====
kubectl port-forward pod/POD 8080:8080
kubectl port-forward svc/SERVICE 8080:80
kubectl port-forward deploy/DEPLOY 8080:8080

# ===== RESOURCES =====
kubectl top nodes
kubectl top pods -n production
kubectl top pods --containers

# ===== SECRETS =====
kubectl get secret myapp -o jsonpath='{.data.password}' | base64 -d

# ===== CONTEXT =====
kubectl config get-contexts
kubectl config use-context prod
kubectl config set-context --current --namespace=production

# ===== LABELS =====
kubectl label pod POD app=myapp
kubectl label node NODE node-type=gpu

# ===== PATCH =====
kubectl patch deployment myapp -p '{"spec":{"replicas":5}}'
kubectl set image deployment/myapp myapp=company/myapp:v2
kubectl set resources deployment/myapp --limits=memory=1Gi

# ===== DIFF =====
kubectl diff -f manifest.yaml

# ===== DEBUG =====
kubectl debug -it POD --image=busybox --target=container
kubectl alpha debug -it NODE --image=ubuntu -- bash

# ===== USEFUL ALIASES =====
alias k='kubectl'
alias kp='kubectl get pods'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
```


## 6. Kubernetes vs Docker Swarm vs Nomad

| Feature | Kubernetes | Docker Swarm | Nomad |
|---------|-----------|--------------|-------|
| Learning Curve | Cao | Thấp | Trung bình |
| Feature Set | Rất đầy đủ | Cơ bản | Đầy đủ |
| Auto-scaling | HPA, VPA, KEDA | Cơ bản | Có |
| Multi-cloud | ✅ Tốt nhất | ❌ | ✅ |
| Community | Rất lớn | Trung bình | Trung bình |
| Production-ready | ✅ | ✅ (small) | ✅ |
| Non-container | ❌ Chỉ K8s | ❌ | ✅ VMs, bare metal |
| GitOps tools | ArgoCD, Flux | Hạn chế | Consul |

### Khi nào dùng K8s
- Microservices phức tạp
- Cần auto-scaling mạnh
- Multi-cloud
- Team có K8s experience
- Production workloads lớn

### Khi nào KHÔNG dùng K8s
- Ứng dụng nhỏ, đơn giản
- Team ít người, không có K8s knowledge
- Single-server deployment
- Budget hạn chế (K8s control plane tốn chi phí)


> **Hoàn thành Kubernetes Toàn Tập!** Tiếp theo: Azure
