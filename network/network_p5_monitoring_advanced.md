# 🌐 NETWORK PHẦN 5: MONITORING, OBSERVABILITY & ADVANCED

# ---
markmap:
  title: "Networking — Monitoring, Observability & Advanced"
  collapse: false
# ---

# 🌐 NETWORK PHẦN 5: MONITORING, OBSERVABILITY & ADVANCED

## Theory
- Network observability combines metrics, logs, and packet captures to detect latency, packet loss, and topology issues; integrate with Prometheus and Grafana for long-term analysis.

## Practice
- Use node-exporter metrics and PromQL for bandwidth and packet-loss alerts, capture packets with `tcpdump`/Wireshark for root-cause, and monitor connections with `ss`/`netstat`.

## 1. Network Monitoring Thực Tế

### 1.1 Interface Statistics
```bash
cat /proc/net/dev       # Raw stats
```

### 1.2 Bandwidth Monitoring Tools
#### iftop (By Host)
```bash
sudo iftop -i eth0 -n -P  # Interface, no DNS, show ports
```

#### nethogs (By Process)
```bash
sudo nethogs eth0
```

#### nload (Simple)
```bash
nload eth0
```

### 1.3 vnstat - Long-term Tracking
```bash
sudo apt install vnstat
vnstat -d        # Daily traffic
vnstat -m        # Monthly
vnstat -h        # Hourly
vnstat -l        # Live
```

### 1.4 Connection Statistics
```bash
ss -s                                 # Summary
ss -tn state established | wc -l     # Số established
ss -tn state time-wait | wc -l       # Số TIME_WAIT
```

### 1.5 Packet Loss & Latency
```bash
# Ping statistics
ping -c 100 -i 0.1 8.8.8.8 | tail -5

# MTR detailed report
mtr --report --report-cycles 100 google.com
```

### 1.6 Prometheus + Grafana Monitoring
#### Node Exporter Metrics
```
node_network_receive_bytes_total
node_network_transmit_bytes_total
node_network_receive_drop_total
node_netstat_Tcp_CurrEstab
```

#### PromQL Queries
```
# Bandwidth (bits/s)
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8

# Packet loss %
rate(node_network_receive_drop_total[5m]) /
rate(node_network_receive_packets_total[5m]) * 100

# TCP connections
node_netstat_Tcp_CurrEstab
```

#### Cài Node Exporter
```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-*.tar.gz
tar xvf node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
```

## 2. Advanced Network Debugging

### 2.1 Wireshark - GUI Packet Analysis
#### Remote Capture
```bash
ssh user@server "sudo tcpdump -i eth0 -w - -s 0" | wireshark -k -i -
```

#### Display Filters Phổ Biến
| Filter | Mô Tả |
|--------|-------|
| `ip.addr == 192.168.1.10` | Packets đến/từ IP |
| `tcp.port == 443` | Port 443 |
| `http.request.method == "POST"` | HTTP POST |
| `http.response.code >= 400` | HTTP errors |
| `tls.handshake.type == 1` | TLS ClientHello |
| `dns.flags.response == 0` | DNS queries |
| `tcp.analysis.flags` | TCP errors |

### 2.2 Debug Checklist - 7 Bước
#### Bước 1: Kiểm Tra Kết Nối
```bash
ping destination-host
traceroute destination-host
nc -zv destination-host port
```

#### Bước 2: Interface Errors
```bash
ip -s link show eth0
ethtool -S eth0 | grep -i "error\|drop"
```

#### Bước 3: System Buffers
```bash
sysctl net.core.rmem_max
sysctl net.core.wmem_max
```

#### Bước 4: Routing
```bash
ip route show
ip route get 8.8.8.8
```

#### Bước 5: Firewall
```bash
sudo iptables -L -n -v | grep -v "0     0"
```

#### Bước 6: Packet Capture
```bash
sudo tcpdump -i eth0 host destination -vnn
```

#### Bước 7: Application Profile
```bash
strace -e network -p PID
lsof -i :8080
```

## 3. Advanced Protocols

### 3.1 BGP - Border Gateway Protocol
#### BGP Là Gì?
- Giao thức **định tuyến của Internet**
- **AS** (Autonomous System) = Mạng độc lập (ISP, company)
- BGP exchange routing info giữa ASes

#### Ví Dụ
```
AS64512 (Company) ↔ AS15169 (Google) ↔ AS32934 (Facebook)
```

#### FRRouting Config
```bash
router bgp 64512
 neighbor 203.0.113.1 remote-as 65000
 address-family ipv4 unicast
  network 192.168.0.0/16
```

### 3.2 OSPF - Link State Routing
- **Open Shortest Path First**
- Mỗi router biết topology toàn bộ network
- Dùng **Dijkstra algorithm** tìm shortest path
- Phổ biến trong **enterprise networks**

### 3.3 VLAN - Virtual LAN
#### VLAN Là Gì?
- Phân chia 1 physical network → nhiều **logical networks**
- Tăng security, giảm broadcast domain

#### Linux VLAN
```bash
sudo ip link add link eth0 name eth0.10 type vlan id 10
sudo ip addr add 10.10.0.1/24 dev eth0.10
sudo ip link set eth0.10 up
```

#### Netplan VLAN
```yaml
vlans:
  vlan10:
    id: 10
    link: eth0
    addresses: [10.10.0.1/24]
  vlan20:
    id: 20
    link: eth0
    addresses: [10.20.0.1/24]
```

### 3.4 QUIC & HTTP/3
#### QUIC Là Gì?
- Transport protocol của Google, nền tảng HTTP/3
- Chạy trên **UDP**
- Multiplexing **không có HoL blocking**
- **0-RTT** connection setup
- **Connection migration** (giữ connection khi đổi mạng)
- Built-in TLS 1.3

#### Nginx HTTP/3 Config
```nginx
server {
    listen 443 quic reuseport;  # HTTP/3
    listen 443 ssl;              # HTTP/2 fallback
    add_header Alt-Svc 'h3=":443"; ma=86400';
}
```

## 4. Network Security Monitoring

### 4.1 Fail2ban - Auto Ban Brute Force
#### Cài Đặt
```bash
sudo apt install fail2ban
```

#### Config
```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600      # Ban 1 giờ
findtime = 600      # Trong 10 phút
maxretry = 5        # Sau 5 lần fail

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
```

#### Quản Lý
```bash
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip 192.168.1.100
```

### 4.2 Snort - Intrusion Detection
```bash
sudo apt install snort
sudo snort -A console -i eth0 -c /etc/snort/snort.conf
```

### 4.3 Zeek - Network Security Monitor
#### Zeek Là Gì?
- Tự động parse protocols, tạo logs chi tiết

#### Logs Tự Động
| Log | Nội Dung |
|-----|---------|
| `conn.log` | Tất cả connections |
| `http.log` | HTTP requests |
| `dns.log` | DNS queries |
| `ssl.log` | TLS handshakes |
| `weird.log` | Anomalies |

### 4.4 QoS - Bandwidth Shaping
```bash
# TC (Traffic Control)
# Tạo qdisc 100Mbps tổng
sudo tc qdisc add dev eth0 root handle 1: htb default 10

# Web: 40Mbps guaranteed, 80Mbps max
sudo tc class add dev eth0 parent 1:1 classid 1:10 \
  htb rate 40mbit ceil 80mbit

# SSH: 1Mbps guaranteed, priority cao
sudo tc class add dev eth0 parent 1:1 classid 1:20 \
  htb rate 1mbit ceil 10mbit prio 1
```

## 5. Network Cheat Sheet

### 5.1 Kiểm Tra Kết Nối
```bash
ping -c 4 host
traceroute host
mtr host
telnet host port
nc -zv host port
curl -I https://host
```

### 5.2 Interface Management
```bash
ip link show
ip addr show
ip route show
ip route get 8.8.8.8
```

### 5.3 DNS
```bash
dig domain
dig @8.8.8.8 domain
dig -x IP
```

### 5.4 Connections & Ports
```bash
ss -tlnp          # TCP listening
ss -tnp           # All TCP
ss -s             # Summary
```

### 5.5 Packet Capture
```bash
tcpdump -i eth0 -vnn
tcpdump port 80 -A
tcpdump host IP -w file.pcap
```

### 5.6 Firewall
```bash
iptables -L -n -v
ufw status verbose
nft list ruleset
```

### 5.7 Bandwidth
```bash
iftop -i eth0
nethogs eth0
vnstat -d
iperf3 -c server
```

### 5.8 Ports Quan Trọng
| Port | Service |
|------|---------|
| 22 | SSH |
| 53 | DNS |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 6443 | K8s API |
| 8080 | HTTP Alt |
| 9090 | Prometheus |
| 9100 | Node Exporter |
| 27017 | MongoDB |
