# ---
markmap:
  title: "Networking — Firewall, iptables & Security"
  collapse: false
# ---

# 🌐 NETWORK PHẦN 3: FIREWALL, IPTABLES & NETWORK SECURITY

## 1. Firewall - Tường Lửa

### 1.1 Firewall Là Gì?
- Hệ thống lọc traffic dựa trên **rules**
- Quyết định traffic nào được phép, traffic nào bị chặn

### 1.2 Các Loại Firewall
#### Packet Filter (L3/L4)
- Ví dụ: iptables
- Nhanh, đơn giản, dựa trên IP/Port

#### Stateful Firewall (L3/L4)
- Ví dụ: nftables, Azure NSG
- Track connections, thông minh hơn

#### Application Firewall (L7)
- Ví dụ: WAF, ModSecurity
- Hiểu HTTP, API, chặn SQL injection

#### Next-Gen Firewall (NGFW)
- Ví dụ: Palo Alto, Fortinet
- Deep packet inspection

## 2. iptables - Linux Firewall

### 2.1 Kiến Trúc iptables
#### Packet Flow
```
Packet đến → PREROUTING → [For this host?]
                            ├── Yes → INPUT → Local process → OUTPUT
                            └── No  → FORWARD → POSTROUTING → Out
```

#### Tables Trong iptables
| Table | Dùng Cho |
|-------|---------|
| `filter` | Firewall (ACCEPT/DROP) — **Mặc định** |
| `nat` | NAT (PREROUTING, POSTROUTING) |
| `mangle` | Modify packet (QoS, TTL) |
| `raw` | Connection tracking bypass |

### 2.2 iptables Commands Cơ Bản
#### Xem Rules
```bash
sudo iptables -L -n -v                # Xem tất cả
sudo iptables -L -n -v --line-numbers # Kèm số thứ tự
sudo iptables -t nat -L -n -v         # NAT table
```

#### Thêm Rules
```bash
# Cho phép IP cụ thể
sudo iptables -A INPUT -s 192.168.1.100 -j ACCEPT

# Chặn IP
sudo iptables -A INPUT -s 203.0.113.5 -j DROP

# Cho phép port
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# SSH chỉ từ dải IP
sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT

# Established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Default deny
sudo iptables -P INPUT DROP
```

#### Xóa Rules
```bash
sudo iptables -D INPUT -p tcp --dport 80 -j ACCEPT  # Theo nội dung
sudo iptables -D INPUT 3                             # Theo số thứ tự
sudo iptables -F                                     # Flush tất cả
```

### 2.3 Production Firewall Script
#### Reset Rules
```bash
iptables -F && iptables -X
iptables -t nat -F && iptables -t nat -X
```

#### Default Policies
```bash
iptables -P INPUT DROP      # Drop incoming mặc định
iptables -P FORWARD DROP    # Drop forward mặc định
iptables -P OUTPUT ACCEPT   # Cho phép outgoing
```

#### Essential Rules
```bash
# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH (từ management network)
iptables -A INPUT -p tcp --dport 22 -s 10.0.100.0/24 -j ACCEPT

# Web traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```

#### Rate Limiting (Chống DDoS)
```bash
# SSH: max 5/minute per IP
iptables -A INPUT -p tcp --dport 22 -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m recent --update \
    --seconds 60 --hitcount 5 --name SSH -j DROP
```

#### Lưu Rules
```bash
sudo iptables-save > /etc/iptables/rules.v4
# apt install iptables-persistent
```

### 2.4 nftables - Thế Hệ Mới
- Successor của iptables (Linux 3.13+)
- Syntax sạch hơn, hiệu quả hơn

```bash
# /etc/nftables.conf
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ct state established,related accept
        tcp dport { 80, 443 } accept
        tcp dport 22 limit rate 5/minute accept
    }
}
```

## 3. UFW - Uncomplicated Firewall (Ubuntu)

### 3.1 UFW Là Gì?
- **Wrapper** của iptables, đơn giản hơn nhiều
- Phù hợp cho Ubuntu servers

### 3.2 UFW Commands
#### Setup Cơ Bản
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh           # BẮT BUỘC trước khi enable!
sudo ufw enable
```

#### Allow Services
```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 'Nginx Full'  # Profile (80 + 443)
sudo ufw allow from 10.0.1.0/24 to any port 5432  # PostgreSQL
```

#### Quản Lý
```bash
sudo ufw status numbered
sudo ufw delete 3            # Xóa rule số 3
sudo ufw disable
sudo ufw reset
```

## 4. Network Troubleshooting Tools

### 4.1 ping & traceroute
#### ping
```bash
ping -c 5 google.com         # Ping 5 lần
ping -s 1400 google.com      # Test MTU
```
- `ttl=55` → Time to Live
- `time=25.3ms` → Round-trip time

#### traceroute
```bash
traceroute -n google.com     # Không resolve DNS
```
- Mỗi dòng = 1 hop (router)
- `* * *` = Hop bị block ICMP

#### MTR (My Traceroute)
```bash
mtr --report google.com      # Kết hợp ping + traceroute
```

### 4.2 ss & netstat
#### ss (Socket Statistics) - Lệnh Mới
```bash
ss -tlnp                     # TCP Listening ports
ss -tnp                      # All TCP connections
ss -s                        # Summary
ss -tlnp sport = :80         # Lọc port 80
```

#### netstat (Cũ Nhưng Vẫn Dùng)
```bash
netstat -tlnp                # TCP listening
netstat -rn                  # Routing table
```

### 4.3 tcpdump - Bắt Gói Tin
#### Lệnh Cơ Bản
```bash
sudo tcpdump -i eth0                   # Bắt tất cả
sudo tcpdump -i eth0 host 192.168.1.1  # Lọc host
sudo tcpdump -i eth0 port 80           # Lọc port
sudo tcpdump -i eth0 -w capture.pcap   # Lưu file
```

#### Thực Tế
```bash
# Debug HTTP
sudo tcpdump -i eth0 -A port 80 | grep "GET\|POST\|Host"

# Monitor DNS
sudo tcpdump -i eth0 port 53

# Debug DB connection
sudo tcpdump -i any host 10.0.3.10 and port 5432
```

### 4.4 curl - Test HTTP
#### GET & POST
```bash
curl -v https://api.company.com/users      # Verbose
curl -I https://api.company.com/users      # Headers only
curl -X POST https://api.company.com/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Tri"}'
```

#### Measure Timing
```bash
curl -w "namelookup: %{time_namelookup}s
connect: %{time_connect}s
total: %{time_total}s" \
  -o /dev/null -s https://google.com
```

#### Useful Options
```bash
curl -L url              # Follow redirects
curl -k url              # Ignore SSL (dev only!)
curl --retry 3 url       # Retry on failure
curl --http2 url         # Force HTTP/2
```

### 4.5 nmap - Network Scanner
#### ⚠️ Chỉ Scan Network Của Mình!
#### Host Discovery
```bash
nmap -sn 192.168.1.0/24
```

#### Port Scan
```bash
nmap 192.168.1.10                    # Default ports
nmap -p 80,443,8080 192.168.1.10    # Specific ports
nmap -p- 192.168.1.10               # All 65535 ports
```

#### Service & OS Detection
```bash
nmap -sV 192.168.1.10               # Service versions
nmap -O 192.168.1.10                # OS detection
nmap -A 192.168.1.10                # Full scan
```

#### Vulnerability Scan
```bash
nmap --script vuln 192.168.1.10
nmap --script ssl-enum-ciphers -p 443 192.168.1.10
```

## 5. VPN - Virtual Private Network

### 5.1 OpenVPN
#### Server Setup
```bash
sudo apt install openvpn easy-rsa

# Tạo CA & certificates
make-cadir /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
```

#### Server Config
```
port 1194
proto udp
dev tun
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
cipher AES-256-CBC
```

### 5.2 WireGuard - Modern VPN
#### Tại Sao WireGuard?
- **Đơn giản hơn** OpenVPN
- **Nhanh hơn** (kernel module)
- **Bảo mật hơn** (modern crypto only)
- Code chỉ ~4000 dòng (vs OpenVPN ~100,000)

#### Server Setup
```bash
sudo apt install wireguard
wg genkey | tee server_private.key | wg pubkey > server_public.key

# /etc/wireguard/wg0.conf
# [Interface]
# PrivateKey = SERVER_PRIVATE_KEY
# Address = 10.10.0.1/24
# ListenPort = 51820
```

#### Client Setup
```bash
wg genkey | tee client_private.key | wg pubkey > client_public.key

# client.conf
# [Interface]
# PrivateKey = CLIENT_KEY
# Address = 10.10.0.2/24
# [Peer]
# PublicKey = SERVER_PUBLIC_KEY
# AllowedIPs = 0.0.0.0/0
# Endpoint = server-ip:51820
```

#### Quản Lý WireGuard
```bash
sudo wg show                   # Status
sudo wg-quick up wg0           # Start
sudo wg-quick down wg0         # Stop
```

## 6. Network Performance Tuning

### 6.1 Kernel Parameters (sysctl)
#### TCP Optimizations
```bash
# Tăng connection backlog
net.core.somaxconn = 65535

# TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728

# Giảm TIME_WAIT
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576
```

#### Security Parameters
```bash
# SYN Cookies (chống SYN flood)
net.ipv4.tcp_syncookies = 1

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
```

### 6.2 Bandwidth Testing
```bash
# iperf3 - Đo băng thông
iperf3 -s                       # Server
iperf3 -c server-ip             # Client TCP
iperf3 -c server-ip -u -b 1G   # Client UDP
```

### 6.3 MTU Tuning
```bash
# Test MTU (mặc định 1500)
ping -M do -s 1472 8.8.8.8

# Xem/Set MTU
ip link show eth0
ip link set eth0 mtu 9000       # Jumbo frames
```
