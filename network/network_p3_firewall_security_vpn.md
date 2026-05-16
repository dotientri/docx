# 🌐 NETWORK TOÀN TẬP - PHẦN 3: FIREWALL, IPTABLES & NETWORK SECURITY

---

## 1. Firewall - Tường Lửa

### 1.1 Firewall Là Gì?

Firewall là hệ thống lọc traffic dựa trên **rules** — quyết định traffic nào được phép đi qua và traffic nào bị chặn.

**Các loại Firewall:**

| Loại | Layer | Ví Dụ | Đặc Điểm |
|------|-------|-------|-----------|
| Packet Filter | L3/L4 | iptables | Nhanh, đơn giản, dựa trên IP/Port |
| Stateful | L3/L4 | nftables, Azure NSG | Track connections, smarter |
| Application | L7 | WAF, Nginx ModSecurity | Hiểu HTTP, API, SQL injection |
| Next-Gen (NGFW) | L7 | Palo Alto, Fortinet | Deep packet inspection |

---

## 2. iptables - Linux Firewall

### 2.1 Kiến Trúc iptables

```
Packet đến:
          ┌─────────────────────────────────────────────────────────────┐
          │                      PREROUTING                              │  ← NAT, mangle
          └─────────────────────┬───────────────────────────────────────┘
                                │
              ┌─────────────────┴──────────────────┐
              │                                    │
              ▼ (For this host)              ▼ (Forward)
        ┌──────────┐                    ┌──────────────┐
        │  INPUT   │                    │   FORWARD    │
        │ (chain)  │                    │   (chain)    │
        └────┬─────┘                    └──────┬───────┘
             │                                 │
             ▼                                 ▼
        Local process                    ┌──────────────┐
             │                           │  POSTROUTING │  ← NAT outgoing
             ▼                           └──────────────┘
        ┌──────────┐
        │  OUTPUT  │
        │ (chain)  │
        └─────────-┘
```

**Tables trong iptables:**
| Table | Dùng Cho |
|-------|---------|
| `filter` | Firewall (ACCEPT/DROP/REJECT) - **Mặc định** |
| `nat` | NAT (PREROUTING, POSTROUTING) |
| `mangle` | Modify packet (QoS, TTL) |
| `raw` | Connection tracking bypass |

### 2.2 iptables Commands Cơ Bản

```bash
# ===== XEM RULES =====
sudo iptables -L                        # Xem tất cả rules (filter table)
sudo iptables -L -n                     # Không resolve hostnames (nhanh hơn)
sudo iptables -L -n -v                  # Kèm packet/byte counters
sudo iptables -L -n -v --line-numbers   # Kèm số thứ tự dòng
sudo iptables -t nat -L -n -v          # NAT table

# ===== THÊM RULES =====
# -A = Append (thêm vào cuối)
# -I = Insert (chèn vào đầu hoặc vị trí chỉ định)
# -D = Delete rule
# -F = Flush (xóa tất cả rules)
# -P = Policy (default policy)

# Cho phép traffic từ IP cụ thể
sudo iptables -A INPUT -s 192.168.1.100 -j ACCEPT

# Chặn IP
sudo iptables -A INPUT -s 203.0.113.5 -j DROP

# Cho phép port cụ thể
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Cho phép SSH chỉ từ dải IP
sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT

# Cho phép established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Cho phép loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Drop tất cả còn lại (default deny)
sudo iptables -P INPUT DROP

# ===== XÓA RULES =====
# Xóa rule cụ thể (theo nội dung)
sudo iptables -D INPUT -p tcp --dport 80 -j ACCEPT

# Xóa theo số thứ tự
sudo iptables -D INPUT 3

# Xóa tất cả
sudo iptables -F INPUT
sudo iptables -F              # Flush tất cả chains

# Reset hoàn toàn
sudo iptables -F
sudo iptables -X              # Delete user-defined chains
sudo iptables -Z              # Reset counters
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```

### 2.3 Rule Hoàn Chỉnh Cho Production Server

```bash
#!/bin/bash
# /etc/iptables/setup-firewall.sh

# ===== RESET =====
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# ===== DEFAULT POLICIES =====
iptables -P INPUT DROP      # Drop tất cả incoming mặc định
iptables -P FORWARD DROP    # Drop tất cả forward mặc định
iptables -P OUTPUT ACCEPT   # Cho phép tất cả outgoing

# ===== LOOPBACK =====
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ===== ESTABLISHED CONNECTIONS =====
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ===== SSH (chỉ từ management network) =====
iptables -A INPUT -p tcp --dport 22 -s 10.0.100.0/24 -j ACCEPT

# ===== WEB TRAFFIC =====
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# ===== ICMP (ping) =====
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# ===== RATE LIMITING (Chống DDoS/Brute Force) =====
# Giới hạn SSH connections: max 5 per minute per IP
iptables -A INPUT -p tcp --dport 22 -m recent --set --name SSH --rsource
iptables -A INPUT -p tcp --dport 22 -m recent --update \
    --seconds 60 --hitcount 5 --name SSH --rsource -j DROP

# Giới hạn new HTTP connections
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 \
    -j REJECT --reject-with tcp-reset

# ===== BLOCK KNOWN BAD IPs =====
# Tạo ipset (hiệu quả hơn nhiều rules riêng lẻ)
ipset create BLOCKED_IPS hash:ip
ipset add BLOCKED_IPS 203.0.113.1
ipset add BLOCKED_IPS 203.0.113.2
iptables -A INPUT -m set --match-set BLOCKED_IPS src -j DROP

# ===== LƯU RULES =====
sudo iptables-save > /etc/iptables/rules.v4
# Restore khi reboot (trên Ubuntu: apt install iptables-persistent)

# ===== XEM KẾT QUẢ =====
iptables -L -n -v
```

### 2.4 nftables - Thế Hệ Mới Của iptables

```bash
# nftables là successor của iptables (Linux 3.13+)
# Syntax sạch hơn, hiệu quả hơn, tất cả trong 1 tool

sudo apt install nftables

# /etc/nftables.conf
cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Loopback
        iifname "lo" accept
        
        # Established connections
        ct state established,related accept
        
        # SSH từ management network
        ip saddr 10.0.100.0/24 tcp dport 22 accept
        
        # Web
        tcp dport { 80, 443 } accept
        
        # ICMP
        icmp type echo-request accept
        
        # Rate limit SSH
        tcp dport 22 limit rate 5/minute accept
        
        # Log và drop phần còn lại
        log prefix "nftables drop: " level info
        drop
    }
    
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
    
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        
        # Port forwarding
        tcp dport 80 dnat to 192.168.1.10:8080
    }
    
    chain postrouting {
        type nat hook postrouting priority srcnat;
        
        # Masquerade cho internal network
        ip saddr 192.168.1.0/24 oifname "eth0" masquerade
    }
}
EOF

sudo systemctl enable --now nftables
sudo nft list ruleset
```

---

## 3. UFW - Uncomplicated Firewall (Ubuntu)

```bash
# UFW là wrapper của iptables, đơn giản hơn nhiều

# Cài đặt
sudo apt install ufw

# Xem status
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered

# ===== CẤU HÌNH =====
# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Cho phép SSH (BẮT BUỘC trước khi enable!)
sudo ufw allow ssh
sudo ufw allow 22/tcp
sudo ufw allow from 10.0.0.0/8 to any port 22

# Cho phép web
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 'Nginx Full'   # Profile (cả 80 và 443)

# Allow specific service
sudo ufw allow from 10.0.1.0/24 to any port 5432  # PostgreSQL từ app servers
sudo ufw allow from 10.0.1.0/24 to any port 6379  # Redis từ app servers

# Enable firewall
sudo ufw enable

# Xóa rule
sudo ufw delete allow 80
sudo ufw delete 3          # Xóa rule số 3 (từ ufw status numbered)

# Reset
sudo ufw reset

# Disable
sudo ufw disable

# ===== UFW PROFILES =====
ls /etc/ufw/applications.d/    # Xem available profiles
sudo ufw app info "Nginx Full"
```

---

## 4. Network Troubleshooting Tools

### 4.1 ping & traceroute

```bash
# ===== PING =====
ping google.com                  # Ping liên tục
ping -c 5 google.com             # Ping 5 lần
ping -i 0.5 google.com          # Interval 0.5s (nhanh hơn)
ping -s 1400 google.com         # Packet size 1400 bytes (test MTU)
ping -f google.com              # Flood ping (cần root, dùng để test)

# Hiểu output:
# 64 bytes from 142.250.185.46: icmp_seq=1 ttl=55 time=25.3 ms
#                                            └─── Time to Live
#                                                              └─── Round-trip time

# ===== TRACEROUTE =====
traceroute google.com
traceroute -n google.com         # Không resolve hostname (nhanh hơn)

# Mỗi dòng = 1 hop (router)
# * * * = Hop này không respond (blocked ICMP)
# Xem latency tại từng hop

# MTR (My Traceroute) - Kết hợp ping + traceroute, real-time
mtr google.com
mtr --report google.com          # Generate report
mtr -n google.com               # Không resolve DNS
```

### 4.2 ss & netstat

```bash
# ===== SS (Socket Statistics) =====
# Nhanh hơn netstat, là lệnh mới

ss -tlnp                  # TCP Listening ports (với process name)
ss -ulnp                  # UDP Listening ports
ss -tnp                   # All TCP connections
ss -s                     # Summary statistics
ss -i                     # Socket details (internal info)
ss state established      # Chỉ established connections

# Lọc theo port
ss -tlnp sport = :80
ss -tnp dport = :443

# Lọc theo process
ss -tnp | grep nginx

# ===== NETSTAT (cũ nhưng vẫn dùng) =====
netstat -tlnp             # TCP listening
netstat -tnp              # TCP connections
netstat -rn               # Routing table
netstat -i                # Interface statistics
netstat -s                # Protocol statistics

# Count connections theo state
netstat -tn | awk '{print $6}' | sort | uniq -c | sort -rn
```

### 4.3 tcpdump - Bắt Gói Tin

```bash
# tcpdump - Packet analyzer mạnh nhất trên Linux

# Bắt tất cả packets
sudo tcpdump -i eth0

# Bắt trên tất cả interfaces
sudo tcpdump -i any

# Lọc theo host
sudo tcpdump -i eth0 host 192.168.1.1
sudo tcpdump -i eth0 src 192.168.1.1       # Chỉ source
sudo tcpdump -i eth0 dst 8.8.8.8           # Chỉ destination

# Lọc theo port
sudo tcpdump -i eth0 port 80
sudo tcpdump -i eth0 port 80 or port 443
sudo tcpdump -i eth0 tcp port 443

# Lọc kết hợp
sudo tcpdump -i eth0 host google.com and port 443

# Options hay dùng
sudo tcpdump -i eth0 -n                    # Không resolve hostname
sudo tcpdump -i eth0 -nn                   # Không resolve port names
sudo tcpdump -i eth0 -v                    # Verbose
sudo tcpdump -i eth0 -vvv                  # Very verbose
sudo tcpdump -i eth0 -X                    # Hiện hex + ASCII
sudo tcpdump -i eth0 -s 0                  # Capture full packets (không truncate)

# Lưu ra file .pcap để phân tích với Wireshark
sudo tcpdump -i eth0 -w capture.pcap
sudo tcpdump -i eth0 port 80 -w http.pcap -s 0

# Đọc file pcap
sudo tcpdump -r capture.pcap
sudo tcpdump -r capture.pcap -n

# ===== THỰC TẾ =====
# Debug HTTP requests
sudo tcpdump -i eth0 -A port 80 | grep -E "GET|POST|Host:|Content"

# Debug SSL handshake
sudo tcpdump -i eth0 port 443 -vv

# Monitor DNS queries
sudo tcpdump -i eth0 port 53

# Kiểm tra connection đến database
sudo tcpdump -i any host 10.0.3.10 and port 5432

# Phát hiện port scan
sudo tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn) != 0 and tcp[tcpflags] & (tcp-ack) = 0'
```

### 4.4 curl - Test HTTP

```bash
# ===== CÁC CÁCH TEST HTTP =====

# Basic GET
curl https://api.company.com/users

# Verbose (xem headers)
curl -v https://api.company.com/users

# Chỉ xem headers
curl -I https://api.company.com/users

# POST với JSON body
curl -X POST https://api.company.com/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token123" \
  -d '{"name": "Tri Pheo", "email": "tripheo@company.com"}'

# Upload file
curl -X POST https://api.company.com/upload \
  -F "file=@/path/to/file.pdf" \
  -F "name=document"

# Measure timing
curl -w "\n
  namelookup:    %{time_namelookup}s\n
  connect:       %{time_connect}s\n
  appconnect:    %{time_appconnect}s\n
  pretransfer:   %{time_pretransfer}s\n
  starttransfer: %{time_starttransfer}s\n
  total:         %{time_total}s\n
  size:          %{size_download} bytes\n" \
  -o /dev/null -s https://google.com

# Follow redirects
curl -L https://bit.ly/short-url

# Ignore SSL errors (dev only!)
curl -k https://self-signed.example.com

# Save to file
curl -o output.html https://example.com
curl -O https://example.com/file.zip  # Same filename

# Retry on failure
curl --retry 3 --retry-delay 2 https://api.company.com/status

# Test với specific DNS
curl --resolve api.company.com:443:192.168.1.10 https://api.company.com

# HTTP/2
curl --http2 https://api.company.com

# ===== THỰC TẾ: Load Testing =====
# Gửi 100 concurrent requests
for i in {1..100}; do
    curl -s https://api.company.com/health &
done | grep -c "OK"
```

### 4.5 nmap - Network Scanner

```bash
# ===== CẢNH BÁO: Chỉ scan network của mình! Scan unauthorized = vi phạm pháp luật =====

# Ping scan (host discovery)
nmap -sn 192.168.1.0/24

# Port scan
nmap 192.168.1.10
nmap -p 80,443,8080 192.168.1.10
nmap -p 1-1000 192.168.1.10         # Ports 1-1000
nmap -p- 192.168.1.10               # Tất cả 65535 ports

# Service detection
nmap -sV 192.168.1.10               # Detect service versions
nmap -sV --version-intensity 9 192.168.1.10  # Aggressive detection

# OS detection
nmap -O 192.168.1.10

# Full scan
nmap -A 192.168.1.10                # OS + services + scripts + traceroute

# UDP scan
nmap -sU 192.168.1.10

# Scan toàn network
nmap -sn 10.0.0.0/24               # Discover hosts

# Script scan (vulnerability detection)
nmap --script vuln 192.168.1.10
nmap --script ssl-enum-ciphers -p 443 192.168.1.10

# Stealth scan (không complete TCP handshake)
nmap -sS 192.168.1.10

# Output
nmap -oN scan.txt 192.168.1.10     # Normal output
nmap -oX scan.xml 192.168.1.10     # XML
nmap -oG scan.gnmap 192.168.1.10   # Grepable
```

---

## 5. VPN - Virtual Private Network

### 5.1 OpenVPN

```bash
# ===== CÀI ĐẶT OPENVPN SERVER =====
sudo apt install openvpn easy-rsa

# Tạo CA và certificates
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret ta.key

# Server config (/etc/openvpn/server.conf)
cat > /etc/openvpn/server.conf << 'EOF'
port 1194
proto udp
dev tun

# Certificates
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
tls-auth /etc/openvpn/ta.key 0

# Network
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"

# Security
cipher AES-256-CBC
auth SHA256
tls-version-min 1.2

# Performance
keepalive 10 120
compress lz4-v2
push "compress lz4-v2"

# Logging
status /var/log/openvpn/status.log
log-append /var/log/openvpn/openvpn.log
verb 3
EOF

# Bật IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# NAT cho VPN clients
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

sudo systemctl enable --now openvpn@server
```

### 5.2 WireGuard - Modern VPN

```bash
# WireGuard: Đơn giản hơn OpenVPN, nhanh hơn, bảo mật hơn

sudo apt install wireguard

# ===== SERVER SETUP =====
# Tạo key pair
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

SERVER_PRIVATE=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)

# Server config
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE
Address = 10.10.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client 1 - Dev machine
[Peer]
PublicKey = CLIENT1_PUBLIC_KEY
AllowedIPs = 10.10.0.2/32

# Client 2 - CI/CD server
[Peer]
PublicKey = CLIENT2_PUBLIC_KEY
AllowedIPs = 10.10.0.3/32
EOF

# Bật WireGuard
sudo systemctl enable --now wg-quick@wg0

# ===== CLIENT SETUP =====
wg genkey | tee client_private.key | wg pubkey > client_public.key

cat > client.conf << EOF
[Interface]
PrivateKey = $(cat client_private.key)
Address = 10.10.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
AllowedIPs = 0.0.0.0/0        # Route tất cả traffic qua VPN
Endpoint = server-ip:51820
PersistentKeepalive = 25       # Giữ connection (qua NAT)
EOF

# ===== QUẢN LÝ =====
sudo wg show                   # Xem status
sudo wg show wg0 peers         # Xem peers
sudo wg-quick up wg0           # Start
sudo wg-quick down wg0         # Stop
```

---

## 6. Network Performance Tuning

```bash
# ===== KERNEL PARAMETERS (sysctl) =====
cat >> /etc/sysctl.conf << 'EOF'
# Tăng connection backlog
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP optimizations
net.ipv4.tcp_fin_timeout = 15          # Giảm TIME_WAIT
net.ipv4.tcp_tw_reuse = 1             # Reuse TIME_WAIT sockets
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10

# Connection tracking table size
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 600

# File descriptor limits
fs.file-max = 1048576

# Network interface queue
net.core.netdev_max_backlog = 65536

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1

# Disable IP source routing (security)
net.ipv4.conf.all.accept_source_route = 0

# SYN Cookies (chống SYN flood)
net.ipv4.tcp_syncookies = 1
EOF

sysctl -p

# ===== KIỂM TRA NETWORK PERFORMANCE =====
# iperf3 - Đo băng thông giữa 2 hosts
# Server:
iperf3 -s

# Client:
iperf3 -c server-ip              # TCP throughput
iperf3 -c server-ip -u -b 1G    # UDP throughput
iperf3 -c server-ip -P 10       # 10 parallel streams

# ===== MTU DISCOVERY =====
# MTU (Maximum Transmission Unit) mặc định = 1500 bytes Ethernet
# Nếu sai MTU → fragmentation → performance giảm

# Test MTU
ping -M do -s 1472 8.8.8.8    # 1472 + 28 (IP+ICMP header) = 1500
# Nếu "Frag needed" → MTU nhỏ hơn

# Xem MTU của interface
ip link show eth0               # MTU 1500
ip link set eth0 mtu 9000       # Jumbo frames (datacenter)
```

---

> **Tiếp theo: Phần 4** - Linux Networking, Network Namespaces & Container Networking
