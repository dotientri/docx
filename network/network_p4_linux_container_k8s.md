# 🌐 NETWORK PHẦN 4: LINUX NETWORKING & CONTAINER NETWORKING
# ---
markmap:
  title: "Networking — Linux & Container Networking"
  collapse: false
# ---

# 🌐 NETWORK PHẦN 4: LINUX NETWORKING & CONTAINER NETWORKING

## Theory
- Linux network namespaces, veth pairs, bridges, and Docker/K8s network drivers provide isolation and connectivity; understanding these primitives explains container networking behavior.

## Practice
- Use `ip netns`, `bridge`, and `iptables` to prototype container networking; for Docker use networks (`bridge`, `host`, `macvlan`), and ensure CNI plugins satisfy K8s networking requirements.

## 1. Linux Network Interfaces

### 1.1 Xem Interfaces
#### ip command (Modern)
```bash
ip link show              # Tất cả interfaces
ip addr show              # Xem IP addresses
ip addr show eth0         # Interface cụ thể
ip -4 addr show           # Chỉ IPv4
```

#### ifconfig (Cũ)
```bash
ifconfig                  # Tất cả
ifconfig eth0             # Cụ thể
```

#### ethtool - Thông Tin NIC
```bash
sudo ethtool eth0         # Speed, Duplex, Link
sudo ethtool -S eth0      # Statistics
```

### 1.2 Quản Lý Interfaces
```bash
# Bật/Tắt
sudo ip link set eth0 up
sudo ip link set eth0 down

# Thêm/Xóa IP tạm thời
sudo ip addr add 192.168.1.50/24 dev eth0
sudo ip addr del 192.168.1.50/24 dev eth0
```

### 1.3 Network Configuration Persistent
#### Ubuntu: Netplan (18.04+)
```yaml
# /etc/netplan/01-config.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses: [192.168.1.10/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```
```bash
sudo netplan apply
sudo netplan try         # Apply + rollback nếu lỗi
```

#### CentOS/RHEL: NetworkManager
```bash
nmcli device status
nmcli connection add type ethernet \
  con-name eth0-static ifname eth0 \
  ip4 192.168.1.10/24 gw4 192.168.1.1
```

#### Bond (Link Aggregation)
```yaml
bonds:
  bond0:
    interfaces: [eth2, eth3]
    parameters:
      mode: active-backup
```

#### VLAN
```yaml
vlans:
  vlan10:
    id: 10
    link: eth0
    addresses: [10.10.0.1/24]
```

## 2. Network Namespaces - Nền Tảng Container Networking

### 2.1 Network Namespace Là Gì?
- **Linux kernel feature** cô lập tài nguyên mạng
- Mỗi namespace có **interfaces, routing table, firewall riêng**
- Docker/K8s dùng namespace để cô lập network containers
- Đây là **bí quyết** hoạt động của Docker networking

### 2.2 Thực Hành: Tạo & Kết Nối Namespaces
#### Tạo Namespace
```bash
sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns exec ns1 ip link show  # Chỉ có loopback!
```

#### Kết Nối 2 Namespaces Bằng veth Pair
- **veth** = Virtual Ethernet pair (2 đầu của 1 cable ảo)
```bash
# Tạo veth pair
sudo ip link add veth0 type veth peer name veth1

# Đặt mỗi đầu vào 1 namespace
sudo ip link set veth0 netns ns1
sudo ip link set veth1 netns ns2

# Cấu hình IP
sudo ip netns exec ns1 ip addr add 10.0.0.1/24 dev veth0
sudo ip netns exec ns1 ip link set veth0 up
sudo ip netns exec ns2 ip addr add 10.0.0.2/24 dev veth1
sudo ip netns exec ns2 ip link set veth1 up

# Test
sudo ip netns exec ns1 ping 10.0.0.2  # ✅
```

### 2.3 Bridge - Virtual Switch
- **Bridge** = cho phép nhiều namespaces/containers giao tiếp
```bash
# Tạo bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 172.17.0.1/16 dev br0

# Kết nối container vào bridge
sudo ip link add veth-c1 type veth peer name veth-c1-br
sudo ip link set veth-c1 netns container1
sudo ip link set veth-c1-br master br0  # ← Nối vào bridge

# Internet access cho containers
sudo iptables -t nat -A POSTROUTING -s 172.17.0.0/16 -j MASQUERADE
```

## 3. Docker Networking

### 3.1 Docker Network Drivers
#### Bridge (Mặc Định) ⭐
- Docker tạo virtual bridge `docker0`
- Mỗi container có veth pair nối vào docker0
- Containers cùng bridge network giao tiếp được
```bash
docker network create --driver bridge \
  --subnet 172.20.0.0/16 myapp-network

docker run -d --name db --network myapp-network postgres:15
docker run -d --name api --network myapp-network myapp
# api reach db qua hostname "db"
```

#### Host
- Dùng trực tiếp host network → **Nhanh nhất**
- Không cần port mapping
- Nhưng **không cô lập** network

#### None
- Container **không có** network access
- Dùng cho batch jobs, security isolation

#### Macvlan
- Container có **MAC address riêng**
- Xuất hiện như physical host trên mạng

### 3.2 Port Mapping
```bash
docker run -p 80:8080 nginx           # host:container
docker run -p 127.0.0.1:80:8080 nginx # Chỉ localhost
docker run -p 80:8080 -p 443:8443 nginx # Nhiều ports

# Docker tạo iptables DNAT rules tự động
# DNAT: 0.0.0.0:80 → 172.17.0.2:8080
```

### 3.3 Docker Compose Networking
#### Ví Dụ: Multi-Network Architecture
```yaml
services:
  nginx:
    networks: [frontend]
  api:
    networks: [frontend, backend]
  postgres:
    networks: [backend]

networks:
  frontend:
    driver: bridge
  backend:
    internal: true  # Không có internet!
```

#### Kết Quả
- **nginx**: frontend (có internet)
- **api**: frontend + backend (bridge giữa 2 networks)
- **postgres**: backend only (**isolated**, không internet)

## 4. Kubernetes Networking

### 4.1 K8s Networking Requirements (4 Rules)
1. Tất cả Pods giao tiếp với nhau **không NAT**
2. Tất cả Nodes giao tiếp với Pods
3. Pod thấy IP = IP mà Pods khác thấy
4. Containers cùng Pod chia sẻ network namespace

### 4.2 Pod Networking
```
Node 1                    Node 2
┌─────────────────┐      ┌──────────────┐
│ Pod A: 10.244.0.2│      │Pod C: 10.244.1.2│
│ Pod B: 10.244.0.3│      │                  │
└────────┬────────┘      └──────┬───────┘
    bridge/flannel0         bridge/flannel0
         └──── Overlay Network (VXLAN) ────┘

Pod A → Pod C: Xuyên nodes, không NAT!
```

### 4.3 CNI Plugins
#### Flannel (Đơn Giản Nhất)
- VXLAN overlay network
- Tốt cho small clusters

#### Calico (Production Phổ Biến) ⭐
- BGP routing (không overlay overhead)
- Network policies
- Excellent performance

#### Cilium (eBPF-based, Advanced)
- Kernel-level networking
- Excellent observability
- L7 network policies

### 4.4 Kubernetes Services
#### ClusterIP (Mặc Định)
- **Chỉ accessible trong cluster**
```yaml
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
```

#### NodePort
- Expose qua **Node's IP** (port 30000-32767)

#### LoadBalancer
- Cloud provider tạo **External LB** tự động
- Azure → Azure Load Balancer

#### DNS Trong K8s
- Format: `<service>.<namespace>.svc.cluster.local`
- Cùng namespace: chỉ cần `service-name`

## 5. Network Policies (K8s Firewall)

### 5.1 Mặc Định
- Tất cả Pods giao tiếp tự do

### 5.2 Deny All
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

### 5.3 Allow API → DB
```yaml
spec:
  podSelector:
    matchLabels:
      app: postgres
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: api
      ports:
        - port: 5432
```

## 6. Service Mesh - Istio

### 6.1 Service Mesh Là Gì?
- Layer 7 networking infrastructure
- Inject sidecar proxy (**Envoy**) vào mỗi Pod
- Tất cả traffic đi qua proxy → Observability + Security

### 6.2 Traffic Management
#### Canary Deployment
```yaml
# 90% → v1, 10% → v2
- destination:
    host: api-service
    subset: v1
  weight: 90
- destination:
    host: api-service
    subset: v2
  weight: 10
```

#### Circuit Breaker
```yaml
outlierDetection:
  consecutive5xxErrors: 5
  interval: 30s
  baseEjectionTime: 60s
```

#### Retry & Timeout
```yaml
retries:
  attempts: 3
  perTryTimeout: 2s
timeout: 5s
```
