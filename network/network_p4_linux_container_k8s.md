# 🌐 NETWORK TOÀN TẬP - PHẦN 4: LINUX NETWORKING & CONTAINER NETWORKING

---

## 1. Linux Network Interfaces

### 1.1 Xem và Quản Lý Interfaces

```bash
# ===== IP COMMAND (modern, thay thế ifconfig) =====

# Xem tất cả interfaces
ip link show
ip link ls

# Output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT
#     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT
#     link/ether aa:bb:cc:dd:ee:ff brd ff:ff:ff:ff:ff:ff

# Xem IP addresses
ip addr show
ip addr show eth0       # Chỉ interface cụ thể
ip -4 addr show         # Chỉ IPv4
ip -6 addr show         # Chỉ IPv6

# Bật/Tắt interface
sudo ip link set eth0 up
sudo ip link set eth0 down

# Thêm IP address tạm thời
sudo ip addr add 192.168.1.50/24 dev eth0
# Xóa IP
sudo ip addr del 192.168.1.50/24 dev eth0

# ===== IFCONFIG (cũ nhưng vẫn dùng) =====
ifconfig
ifconfig eth0
ifconfig eth0 up / down

# ===== ETHTOOL - Xem thông tin NIC =====
sudo ethtool eth0
# Speed: 1000Mb/s
# Duplex: Full
# Link detected: yes

sudo ethtool -S eth0        # Statistics (packets, errors)
sudo ethtool -i eth0        # Driver info
```

### 1.2 Network Configuration - Persistent

```bash
# ===== UBUNTU: NETPLAN (Ubuntu 18.04+) =====
cat /etc/netplan/01-network-manager-all.yaml

# Static IP config:
cat > /etc/netplan/01-config.yaml << 'EOF'
network:
  version: 2
  renderer: networkd    # hoặc NetworkManager
  
  ethernets:
    eth0:
      addresses:
        - 192.168.1.10/24
        - 192.168.1.11/24  # Multiple IPs
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
        search: [company.internal]
      mtu: 1500
      
    eth1:
      dhcp4: true
      
  bonds:
    bond0:
      interfaces: [eth2, eth3]
      parameters:
        mode: active-backup
        
  vlans:
    vlan10:
      id: 10
      link: eth0
      addresses: [10.10.0.1/24]
EOF

sudo netplan apply             # Apply config
sudo netplan try               # Apply và rollback nếu không OK
sudo netplan generate          # Generate backend configs

# ===== CENTOS/RHEL: NetworkManager =====
# /etc/sysconfig/network-scripts/ifcfg-eth0
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << 'EOF'
TYPE=Ethernet
BOOTPROTO=none        # none/static/dhcp
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=192.168.1.10
PREFIX=24
GATEWAY=192.168.1.1
DNS1=8.8.8.8
DNS2=1.1.1.1
EOF

sudo systemctl restart NetworkManager

# nmcli (NetworkManager CLI)
nmcli device status
nmcli connection show
nmcli connection add type ethernet con-name eth0-static ifname eth0 \
  ip4 192.168.1.10/24 gw4 192.168.1.1
nmcli connection up eth0-static
```

---

## 2. Network Namespaces - Nền Tảng Của Container Networking

### 2.1 Network Namespace Là Gì?

Network Namespace là tính năng **Linux kernel cô lập tài nguyên mạng**:
- Mỗi namespace có **interfaces, routing table, firewall rules riêng**
- Container (Docker, k8s) dùng network namespaces để cô lập network
- Đây là bí quyết hoạt động của Docker networking

```bash
# ===== THỰC HÀNH NETWORK NAMESPACE =====

# Xem namespaces hiện có
ip netns list

# Tạo namespace mới
sudo ip netns add ns1
sudo ip netns add ns2

# Xem network trong namespace
sudo ip netns exec ns1 ip link show
# → Chỉ có loopback! Không có external interfaces

# Chạy command trong namespace
sudo ip netns exec ns1 bash
sudo ip netns exec ns1 ip addr show

# ===== KẾT NỐI 2 NAMESPACES VIA VETH PAIR =====
# veth = Virtual Ethernet (pair of virtual network interfaces)
# Khi gửi packet vào 1 đầu → ra đầu kia (như 2 đầu của 1 cable)

# Tạo veth pair
sudo ip link add veth0 type veth peer name veth1

# Đặt 1 đầu vào namespace ns1, 1 đầu vào ns2
sudo ip link set veth0 netns ns1
sudo ip link set veth1 netns ns2

# Cấu hình IP
sudo ip netns exec ns1 ip addr add 10.0.0.1/24 dev veth0
sudo ip netns exec ns1 ip link set veth0 up
sudo ip netns exec ns1 ip link set lo up

sudo ip netns exec ns2 ip addr add 10.0.0.2/24 dev veth1
sudo ip netns exec ns2 ip link set veth1 up
sudo ip netns exec ns2 ip link set lo up

# Test kết nối
sudo ip netns exec ns1 ping 10.0.0.2
# → Thành công! ns1 có thể giao tiếp với ns2

# Xóa namespace
sudo ip netns del ns1
sudo ip netns del ns2
```

### 2.2 Bridge - Kết Nối Nhiều Namespaces

```bash
# Bridge = Virtual switch trong Linux
# Cho phép nhiều namespaces/containers giao tiếp

# Tạo bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 172.17.0.1/16 dev br0

# Tạo 2 namespaces
sudo ip netns add container1
sudo ip netns add container2

# Kết nối container1 vào bridge
sudo ip link add veth-c1 type veth peer name veth-c1-br
sudo ip link set veth-c1 netns container1
sudo ip link set veth-c1-br master br0      # ← Kết nối vào bridge
sudo ip link set veth-c1-br up

# Cấu hình container1
sudo ip netns exec container1 ip addr add 172.17.0.2/16 dev veth-c1
sudo ip netns exec container1 ip link set veth-c1 up
sudo ip netns exec container1 ip link set lo up
sudo ip netns exec container1 ip route add default via 172.17.0.1

# Tương tự container2
sudo ip link add veth-c2 type veth peer name veth-c2-br
sudo ip link set veth-c2 netns container2
sudo ip link set veth-c2-br master br0
sudo ip link set veth-c2-br up
sudo ip netns exec container2 ip addr add 172.17.0.3/16 dev veth-c2
sudo ip netns exec container2 ip link set veth-c2 up
sudo ip netns exec container2 ip link set lo up
sudo ip netns exec container2 ip route add default via 172.17.0.1

# Cho phép internet access (masquerade)
sudo iptables -t nat -A POSTROUTING -s 172.17.0.0/16 -j MASQUERADE

# Test
sudo ip netns exec container1 ping 172.17.0.3    # container1 → container2
sudo ip netns exec container1 ping 8.8.8.8       # container1 → internet
```

---

## 3. Docker Networking - Thực Tế

### 3.1 Docker Network Drivers

```bash
# ===== BRIDGE (Mặc định) =====
# Docker tạo virtual bridge docker0
# Mỗi container có veth pair nối vào docker0
# Containers trong cùng bridge network giao tiếp được với nhau

docker network ls
# NETWORK ID     NAME      DRIVER    SCOPE
# abc123def456   bridge    bridge    local    ← Mặc định (docker0)
# def456ghi789   host      host      local
# ghi789jkl012   none      null      local

# Xem chi tiết network
docker network inspect bridge

# Tạo custom bridge network
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  --opt com.docker.network.bridge.name=br-myapp \
  myapp-network

# Chạy containers trong cùng network → giao tiếp qua tên
docker run -d --name db --network myapp-network postgres:15
docker run -d --name api --network myapp-network myapp:latest
# api có thể reach db qua hostname "db"

# ===== HOST (Dùng trực tiếp host network) =====
docker run --network host nginx
# Container dùng trực tiếp interfaces của host → Không NAT → Nhanh nhất
# Không cần port mapping
# Nhưng không cô lập network

# ===== NONE (No networking) =====
docker run --network none myapp
# Container không có network access
# Dùng cho batch jobs, security isolation

# ===== MACVLAN (Container có MAC riêng) =====
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  macvlan-net
# Container xuất hiện như physical host trên mạng
# Mỗi container có MAC address riêng
# Dùng trong bare-metal/legacy app scenarios
```

### 3.2 Docker Port Mapping - Chi Tiết

```bash
# Port mapping: host_port:container_port
docker run -p 80:8080 nginx              # TCP mặc định
docker run -p 80:8080/tcp nginx          # Explicit TCP
docker run -p 514:514/udp nginx          # UDP
docker run -p 127.0.0.1:80:8080 nginx   # Chỉ bind localhost

# Nhiều ports
docker run -p 80:8080 -p 443:8443 nginx

# Range ports
docker run -p 8000-8010:8000-8010 myapp

# Random host port (docker chọn)
docker run -p 8080 nginx                 # Docker chọn host port
docker port container_name              # Xem port mapping

# ===== Bên Trong Docker: Iptables Rules =====
# Docker tự động thêm iptables DNAT rules:
# DNAT: 0.0.0.0:80 → 172.17.0.2:8080
sudo iptables -t nat -L -n | grep DOCKER
# DNAT  tcp --  0.0.0.0/0  0.0.0.0/0  tcp dpt:80 to:172.17.0.2:8080
```

### 3.3 Docker Compose Networking

```yaml
# docker-compose.yml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      
  api:
    build: ./api
    environment:
      - DB_HOST=postgres      # Dùng service name làm hostname
      - REDIS_HOST=redis
    networks:
      - frontend
      - backend
      
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - backend              # Chỉ accessible trong backend network
      
  redis:
    image: redis:7-alpine
    networks:
      - backend

networks:
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          
  backend:
    driver: bridge
    internal: true            # Không có internet access!
    ipam:
      config:
        - subnet: 172.21.0.0/24

volumes:
  pgdata:
```

```
Kết quả:
nginx:    frontend (172.20.0.x) ← có internet
api:      frontend + backend     ← bridge giữa 2 networks
postgres: backend (172.21.0.x) ← isolated, không có internet
redis:    backend (172.21.0.x) ← isolated
```

---

## 4. Kubernetes Networking - Overview

### 4.1 K8s Networking Requirements

Kubernetes đặt ra **4 requirements cốt lõi:**
1. Tất cả Pods có thể giao tiếp với tất cả Pods khác (không NAT)
2. Tất cả Nodes có thể giao tiếp với tất cả Pods
3. Pod thấy IP của nó = IP mà các Pods khác thấy
4. Containers trong cùng Pod chia sẻ network namespace

### 4.2 Pod Networking

```
Pod Networking:
┌─────────────────────────────────────────────┐
│                   Node 1                    │
│  ┌───────────┐  ┌───────────┐              │
│  │   Pod A   │  │   Pod B   │              │
│  │ eth0:     │  │ eth0:     │              │
│  │10.244.0.2 │  │10.244.0.3 │              │
│  └─────┬─────┘  └─────┬─────┘              │
│        └──────┬────────┘                   │
│           cbr0/flannel0                    │
│          (bridge/tunnel)                   │
└─────────────────────────────────────────────┘
         ↕ Overlay Network (VXLAN/IPIP)
┌─────────────────────────────────────────────┐
│                   Node 2                    │
│  ┌───────────┐                             │
│  │   Pod C   │                             │
│  │ eth0:     │                             │
│  │10.244.1.2 │                             │
│  └───────────┘                             │
└─────────────────────────────────────────────┘

Pod A (10.244.0.2) → Pod C (10.244.1.2): Xuyên nodes, không NAT
```

### 4.3 CNI Plugins

```bash
# CNI (Container Network Interface) = Plugin system cho k8s networking

# ===== FLANNEL (Đơn giản nhất) =====
# - VXLAN overlay network
# - Tốt cho small clusters
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# ===== CALICO (Phổ biến nhất cho production) =====
# - BGP routing (không overlay overhead)
# - Network policies
# - Excellent performance
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# ===== CILIUM (eBPF-based, most advanced) =====
# - eBPF cho kernel-level networking
# - Excellent observability
# - L7 network policies
helm install cilium cilium/cilium --namespace kube-system

# ===== WEAVE NET =====
kubectl apply -f "https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml"
```

### 4.4 Kubernetes Services - Network Abstraction

```yaml
# ClusterIP - Internal only (mặc định)
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: ClusterIP            # Chỉ accessible trong cluster
  selector:
    app: api
  ports:
    - port: 80               # Service port
      targetPort: 8080       # Pod port

---
# NodePort - Expose qua Node's IP
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
      targetPort: 8080
      nodePort: 30080        # Range 30000-32767

---
# LoadBalancer - External LB (Cloud providers)
apiVersion: v1
kind: Service
metadata:
  name: api-lb
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
  # Cloud provider tạo LB tự động
  # AWS → ELB
  # GCP → Cloud LB
  # Azure → Azure LB
```

```bash
# Xem services
kubectl get services -o wide
# NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
# kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP
# api-service  ClusterIP   10.100.200.50  <none>        80/TCP
# api-lb       LoadBalancer 10.100.200.51  203.0.113.5  80:31234/TCP

# Debug service connectivity
kubectl run tmp --rm -it --image=busybox -- wget -O- api-service
kubectl exec -it pod-name -- curl api-service:80

# DNS trong K8s (CoreDNS)
# Format: <service-name>.<namespace>.svc.cluster.local
curl api-service.default.svc.cluster.local
curl api-service.default.svc.cluster.local:80
```

---

## 5. Network Policies trong Kubernetes

```yaml
# NetworkPolicy - Firewall cho Pods
# Mặc định: Tất cả Pods có thể giao tiếp với nhau
# Khi áp dụng NetworkPolicy: chỉ traffic được allow mới được phép

# ===== DENY ALL BY DEFAULT =====
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}      # Apply cho tất cả pods
  policyTypes:
    - Ingress
    - Egress

---
# ===== ALLOW API → DB =====
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres      # Apply cho postgres pods
  policyTypes:
    - Ingress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: api     # Chỉ allow từ api pods
      ports:
        - port: 5432

---
# ===== ALLOW EXTERNAL TO NGINX =====
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
spec:
  podSelector:
    matchLabels:
      app: nginx
  ingress:
    - {}               # Allow tất cả ingress (không restrict)
  egress:
    - to:
      - podSelector:
          matchLabels:
            app: api   # Chỉ egress đến api pods
```

---

## 6. Service Mesh - Istio Overview

```yaml
# Service Mesh: Layer 7 networking infrastructure
# Istio inject sidecar proxy (Envoy) vào mỗi Pod
# → Tất cả traffic đi qua proxy → Observability + Security + Traffic management

# ===== TRAFFIC MANAGEMENT =====
# VirtualService - Routing rules
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: api-routing
spec:
  hosts:
    - api-service
  http:
    # Canary deployment: 90% traffic → v1, 10% → v2
    - route:
      - destination:
          host: api-service
          subset: v1
        weight: 90
      - destination:
          host: api-service
          subset: v2
        weight: 10
    
    # Retry logic
    - retries:
        attempts: 3
        perTryTimeout: 2s
    
    # Timeout
    - timeout: 5s

---
# DestinationRule - Subset definitions
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: api-destination
spec:
  host: api-service
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 1000
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s  # Circuit breaker!
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

---

> **Tiếp theo: Phần 5** - Network Monitoring, Observability & Advanced Protocols
