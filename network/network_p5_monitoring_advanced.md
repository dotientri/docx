# 🌐 NETWORK TOÀN TẬP - PHẦN 5: MONITORING, OBSERVABILITY & ADVANCED PROTOCOLS

---

## 1. Network Monitoring Thực Tế

### 1.1 System Network Metrics

```bash
# ===== INTERFACES STATS =====
# Xem traffic real-time
cat /proc/net/dev
# eth0:  bytes  packets  errors drops   bytes  packets  errors drops
# Receive                            Transmit

# Bandwidth monitoring với iftop
sudo apt install iftop
sudo iftop -i eth0           # Interface eth0
sudo iftop -n                # Không resolve DNS (nhanh hơn)
sudo iftop -P                # Hiện ports
sudo iftop -B                # Bytes thay vì bits

# nethogs - Bandwidth theo process
sudo apt install nethogs
sudo nethogs eth0

# nload - Simple bandwidth monitor
sudo apt install nload
nload eth0

# bmon - Multiple interfaces
sudo apt install bmon
bmon

# ===== VNSTAT - Long-term Bandwidth Tracking =====
sudo apt install vnstat
sudo systemctl enable --now vnstat

# Xem traffic theo ngày/tháng
vnstat -d        # Daily
vnstat -m        # Monthly
vnstat -h        # Hourly
vnstat -l        # Live traffic
vnstat -i eth0   # Specific interface

# ===== SS STATISTICS =====
# Xem TCP connection stats
ss -s
# Total: 234 (kernel 316)
# TCP:   45 (estab 32, closed 8, orphaned 0, timewait 5)
# UDP:   12

# Xem connections theo state
ss -tn state established | wc -l     # Số connections established
ss -tn state time-wait | wc -l       # Số TIME_WAIT connections
```

### 1.2 Packet Loss và Latency

```bash
# ===== PING STATISTICS =====
ping -c 100 -i 0.1 8.8.8.8 2>&1 | tail -5
# --- 8.8.8.8 ping statistics ---
# 100 packets transmitted, 99 received, 1% packet loss, time 9992ms
# rtt min/avg/max/mdev = 1.234/5.678/15.432/2.123 ms

# ===== CONTINUOUS MONITORING =====
# SmokePing-like với ping
while true; do
    result=$(ping -c 5 -W 1 8.8.8.8 | tail -1)
    echo "$(date '+%Y-%m-%d %H:%M:%S') $result" >> /var/log/ping-monitor.log
    sleep 60
done &

# Xem log
tail -f /var/log/ping-monitor.log

# ===== PATHPING (MTR alternative) =====
mtr --report --report-cycles 100 google.com
# HOST: server1              Loss%   Snt   Last   Avg  Best  Wrst StDev
# 1. 192.168.1.1             0.0%   100    0.5   0.6   0.4   1.2   0.2
# 2. 10.0.0.1                0.0%   100    1.2   1.5   1.0   3.4   0.4
# ...
# 8. 216.58.196.78           0.0%   100   25.3  25.8  24.9  28.1   0.5
```

### 1.3 Prometheus + Grafana Network Monitoring

```yaml
# prometheus.yml - Scrape node exporter
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - 'server1:9100'
        - 'server2:9100'
        - 'server3:9100'

# Node Exporter thu thập metrics từ /proc và /sys
# Network metrics tự động:
# node_network_receive_bytes_total
# node_network_transmit_bytes_total
# node_network_receive_packets_total
# node_network_receive_drop_total
# node_network_transmit_drop_total
```

```bash
# Cài Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/

# Systemd service
cat > /etc/systemd/system/node-exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.netstat \
    --collector.tcpstat \
    --collector.conntrack
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now node-exporter
```

```
Grafana Dashboard queries (PromQL):

# Network bandwidth (bytes per second)
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8  # Bits/s

# Packet loss percentage
rate(node_network_receive_drop_total[5m]) / 
rate(node_network_receive_packets_total[5m]) * 100

# TCP connections
node_netstat_Tcp_CurrEstab

# Error rate
rate(node_network_receive_errs_total[5m])

# Top connections by IP
sum by (destination_ip) (
  rate(nginx_connections_total[5m])
)
```

---

## 2. Advanced Network Debugging

### 2.1 Wireshark - GUI Packet Analysis

```bash
# Capture và mở trong Wireshark
sudo tcpdump -i eth0 -w capture.pcap -s 0
wireshark capture.pcap

# Hoặc capture thẳng trong Wireshark (remote)
# Edit → Preferences → Remote interfaces
# host: production-server, port: 2002

# SSH remote capture (không cần Wireshark trên server)
ssh user@server "sudo tcpdump -i eth0 -w - -s 0" | wireshark -k -i -

# ===== WIRESHARK DISPLAY FILTERS (phổ biến) =====
# HTTP traffic
http

# Packets đến/từ IP cụ thể
ip.addr == 192.168.1.10

# Source/Destination
ip.src == 10.0.0.1
ip.dst == 8.8.8.8

# Port
tcp.port == 443
tcp.dstport == 80
udp.port == 53

# HTTP method
http.request.method == "POST"

# HTTP status errors
http.response.code >= 400

# TLS handshake
tls.handshake.type == 1    # ClientHello

# DNS queries
dns.flags.response == 0

# Packets với errors
tcp.analysis.flags

# Large packets
frame.len > 1400
```

### 2.2 Network Performance Debugging Checklist

```bash
# ===== BƯỚC 1: KIỂM TRA KẾT NỐI CƠ BẢN =====
ping destination-host
traceroute destination-host
telnet destination-host port     # Test TCP connection
nc -zv destination-host port     # Netcat check port

# ===== BƯỚC 2: XEM INTERFACE ERRORS =====
ip -s link show eth0
# RX: bytes  packets  errors  dropped  overrun  mcast
#     errors và dropped phải bằng 0

ethtool -S eth0 | grep -i "error\|drop\|miss\|fail"

# ===== BƯỚC 3: XEM SYSTEM BUFFERS =====
sysctl net.core.rmem_max
sysctl net.core.wmem_max
sysctl net.ipv4.tcp_mem

# Buffer overflows (thể hiện qua dropped packets)
ss -nmr

# ===== BƯỚC 4: XEM ROUTING =====
ip route show
ip route get 8.8.8.8         # Route cho destination cụ thể
# 8.8.8.8 via 192.168.1.1 dev eth0 src 192.168.1.100

# ===== BƯỚC 5: XEM FIREWALL =====
sudo iptables -L -n -v | grep -v "0     0"  # Rules với traffic
sudo iptables -t nat -L -n

# ===== BƯỚC 6: BẮT GÓI TIN =====
sudo tcpdump -i eth0 host destination -vnn

# ===== BƯỚC 7: PROFILE APPLICATION =====
strace -e network -p PID        # System calls về network
lsof -i :8080                   # Process dùng port 8080
lsof -i TCP -n -P               # Tất cả TCP connections
```

---

## 3. Advanced Protocols

### 3.1 BGP - Border Gateway Protocol

```bash
# BGP là giao thức định tuyến của Internet
# AS (Autonomous System) = Mạng độc lập (ISP, company)
# BGP exchange routing information giữa ASes

# Ví dụ thực tế:
# AS64512 (Company network) ↔ AS15169 (Google) ↔ AS32934 (Facebook)

# ===== FRRouting (Free Range Routing) - BGP Software =====
sudo apt install frr

# /etc/frr/frr.conf
cat > /etc/frr/frr.conf << 'EOF'
frr version 9.0
frr defaults traditional

router bgp 64512             # Our AS number
 bgp router-id 192.168.1.1
 
 # Neighbor (BGP peer - ISP)
 neighbor 203.0.113.1 remote-as 65000
 neighbor 203.0.113.1 description ISP-1
 
 address-family ipv4 unicast
  # Announce our networks
  network 192.168.0.0/16
  network 10.0.0.0/8
  
  # Accept routes from ISP
  neighbor 203.0.113.1 activate
  neighbor 203.0.113.1 soft-reconfiguration inbound
  
  # Filters (prevent route leaking)
  neighbor 203.0.113.1 prefix-list OUR-PREFIXES out
  neighbor 203.0.113.1 prefix-list ISP-PREFIXES in
 exit-address-family

# Prefix lists
ip prefix-list OUR-PREFIXES seq 10 permit 192.168.0.0/16
ip prefix-list ISP-PREFIXES seq 10 permit 0.0.0.0/0 le 24
EOF

vtysh -c "show bgp summary"
vtysh -c "show bgp neighbors"
vtysh -c "show ip route bgp"
```

### 3.2 OSPF - Link State Routing

```bash
# OSPF = Open Shortest Path First
# Link-state protocol - mỗi router biết topology toàn bộ network
# Dùng Dijkstra algorithm tìm shortest path
# Phổ biến trong enterprise networks

# FRRouting OSPF config
cat >> /etc/frr/frr.conf << 'EOF'
router ospf
 ospf router-id 10.0.0.1
 
 # Announce networks
 network 10.0.0.0/24 area 0
 network 10.0.1.0/24 area 0
 
 # Tuning
 auto-cost reference-bandwidth 100000  # 100Gbps reference
 
interface eth0
 ip ospf hello-interval 5
 ip ospf dead-interval 20
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 secretkey
EOF

vtysh -c "show ip ospf neighbor"
vtysh -c "show ip ospf route"
vtysh -c "show ip ospf database"
```

### 3.3 VLAN - Virtual LAN

```bash
# VLAN phân chia 1 physical network thành nhiều logical networks
# Tăng security, giảm broadcast domain

# Tạo VLAN interface trên Linux
sudo apt install vlan

sudo ip link add link eth0 name eth0.10 type vlan id 10
sudo ip addr add 10.10.0.1/24 dev eth0.10
sudo ip link set eth0.10 up

# Persistent (Netplan)
cat > /etc/netplan/01-vlans.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      
  vlans:
    vlan10:
      id: 10
      link: eth0
      addresses: [10.10.0.1/24]
    vlan20:
      id: 20
      link: eth0
      addresses: [10.20.0.1/24]
    vlan30:
      id: 30
      link: eth0
      addresses: [10.30.0.1/24]
      
  # Routing giữa VLANs
  routes:
    - to: 10.10.0.0/24
      via: 10.10.0.254
    - to: 10.20.0.0/24
      via: 10.20.0.254
EOF

sudo netplan apply

# Cisco switch VLAN config (tham khảo)
# vlan 10
#  name WEB-SERVERS
# vlan 20
#  name DB-SERVERS
# vlan 30
#  name MANAGEMENT
# interface GigabitEthernet0/1
#  switchport mode trunk
#  switchport trunk allowed vlan 10,20,30
```

### 3.4 QUIC & HTTP/3

```bash
# QUIC: Giao thức transport của Google, nền tảng của HTTP/3
# - Chạy trên UDP
# - Multiplexing không có HoL blocking
# - 0-RTT connection setup
# - Connection migration (giữ connection khi đổi IP/mạng)
# - Built-in TLS 1.3

# Test HTTP/3 support
curl --http3 https://quic.nginx.org/

# Nginx HTTP/3 config (cần nginx-quic build)
server {
    listen 443 quic reuseport;   # HTTP/3
    listen 443 ssl;               # HTTP/2 fallback
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # Thông báo HTTP/3 support
    add_header Alt-Svc 'h3=":443"; ma=86400';
    
    http3 on;
    http2 on;
}

# Kiểm tra
curl -v --http3 https://your-domain.com 2>&1 | grep -E "HTTP/|ALPN"
```

---

## 4. Network Security Monitoring

### 4.1 Phát Hiện Xâm Nhập

```bash
# ===== FAIL2BAN - Tự động ban IPs bruteforce =====
sudo apt install fail2ban

# /etc/fail2ban/jail.local
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600         # Ban 1 giờ
findtime = 600         # Trong 10 phút
maxretry = 5           # Sau 5 lần thất bại

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 60

[nginx-4xx]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
filter = nginx-4xx
maxretry = 20
EOF

sudo systemctl enable --now fail2ban

# Xem bans
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client get sshd banip list

# Unban IP
sudo fail2ban-client set sshd unbanip 192.168.1.100

# ===== SNORT - Intrusion Detection System =====
sudo apt install snort

# /etc/snort/snort.conf (cơ bản)
# var HOME_NET 192.168.1.0/24
# var EXTERNAL_NET !$HOME_NET

# Rule ví dụ (/etc/snort/rules/local.rules):
# alert tcp any any -> $HOME_NET 22 (msg:"SSH brute force"; \
#   flags:S; threshold:type both,track by_src,count 10,seconds 60; \
#   sid:1000001; rev:1;)

sudo snort -A console -i eth0 -c /etc/snort/snort.conf
```

### 4.2 Network Traffic Analysis

```bash
# ===== ZEEK (Network Security Monitor) =====
sudo apt install zeek

# Zeek tự động parse protocols và tạo logs
zeek -i eth0 /opt/zeek/share/zeek/site/local.zeek

# Logs được tạo ở /opt/zeek/logs/
ls /opt/zeek/logs/current/
# conn.log     ← Tất cả connections (IP, port, duration, bytes)
# http.log     ← HTTP requests
# dns.log      ← DNS queries
# ssl.log      ← TLS handshakes
# weird.log    ← Anomalies

# Phân tích conn.log
zeek-cut id.orig_h id.resp_h id.resp_p proto duration orig_bytes < conn.log | \
  sort -k6 -rn | head -20
# → Top 20 connections theo thời gian

# ===== ANALYSIS SCRIPTS =====
# Top talkers (most traffic)
zeek-cut id.orig_h orig_bytes < conn.log | \
  sort -k1 | awk '{sum[$1]+=$2} END{for(k in sum)print sum[k], k}' | \
  sort -rn | head -10

# Detect port scans
zeek-cut id.orig_h id.resp_p < conn.log | \
  sort | uniq | awk '{count[$1]++} END{for(k in count)if(count[k]>100)print count[k], k}' | \
  sort -rn
```

### 4.3 Bandwidth Shaping (QoS)

```bash
# ===== TC (Traffic Control) - Linux QoS =====
# Giới hạn bandwidth, ưu tiên traffic

# Ví dụ: Giới hạn container sử dụng bandwidth

# Tạo qdisc (queuing discipline) trên interface
sudo tc qdisc add dev eth0 root handle 1: htb default 10

# Tạo class tổng 100Mbps
sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 100mbit

# Subclass: Web traffic - guarantee 40Mbps, max 80Mbps
sudo tc class add dev eth0 parent 1:1 classid 1:10 htb \
  rate 40mbit ceil 80mbit burst 15k

# Subclass: SSH - guarantee 1Mbps, max 10Mbps (priority!)
sudo tc class add dev eth0 parent 1:1 classid 1:20 htb \
  rate 1mbit ceil 10mbit burst 15k prio 1

# Subclass: Bulk downloads - max 20Mbps (low priority)
sudo tc class add dev eth0 parent 1:1 classid 1:30 htb \
  rate 10mbit ceil 20mbit burst 15k prio 3

# Filter traffic vào classes
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 \
  u32 match ip dport 80 0xffff flowid 1:10

sudo tc filter add dev eth0 parent 1: protocol ip prio 1 \
  u32 match ip dport 22 0xffff flowid 1:20

# Xem qdisc và classes
sudo tc qdisc show dev eth0
sudo tc class show dev eth0
sudo tc -s class show dev eth0      # Với statistics

# Xóa tất cả
sudo tc qdisc del dev eth0 root
```

---

## 5. Network Cheat Sheet

### 5.1 Quick Reference

```bash
# ============================================
# KIỂM TRA KẾT NỐI
# ============================================
ping -c 4 host                    # Basic connectivity
traceroute host                   # Path to host
mtr host                          # Better traceroute
telnet host port                  # TCP connection test
nc -zv host port                  # Netcat port check
curl -I https://host              # HTTP check

# ============================================
# INTERFACE MANAGEMENT
# ============================================
ip link show                      # All interfaces
ip addr show                      # IPs
ip route show                     # Routing table
ip route get 8.8.8.8              # Route for specific dest

# ============================================
# DNS
# ============================================
dig domain                        # DNS lookup
dig @8.8.8.8 domain               # Use specific DNS
dig -x IP                         # Reverse lookup
nslookup domain                   # Alternative

# ============================================
# CONNECTIONS & PORTS
# ============================================
ss -tlnp                          # TCP listening ports
ss -tnp                           # All TCP connections
ss -s                             # Summary

# ============================================
# PACKET CAPTURE
# ============================================
tcpdump -i eth0 -vnn              # Capture all
tcpdump port 80 -A                # HTTP capture
tcpdump host IP -w file.pcap      # Save to file

# ============================================
# FIREWALL
# ============================================
iptables -L -n -v                 # View rules
ufw status verbose                # UFW status
nft list ruleset                  # nftables

# ============================================
# BANDWIDTH
# ============================================
iftop -i eth0                     # Real-time by host
nethogs eth0                      # By process
vnstat -d                         # Historical

# ============================================
# PERFORMANCE
# ============================================
iperf3 -c server                  # Bandwidth test
mtr --report host                 # Detailed path test
```

### 5.2 Ports Quan Trọng Phải Nhớ

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 25 | TCP | SMTP |
| 53 | TCP/UDP | DNS |
| 80 | TCP | HTTP |
| 110 | TCP | POP3 |
| 143 | TCP | IMAP |
| 443 | TCP | HTTPS |
| 465/587 | TCP | SMTPS |
| 993/995 | TCP | IMAPS/POP3S |
| 3306 | TCP | MySQL |
| 5432 | TCP | PostgreSQL |
| 6379 | TCP | Redis |
| 27017 | TCP | MongoDB |
| 2181 | TCP | ZooKeeper |
| 9092 | TCP | Kafka |
| 2379/2380 | TCP | etcd |
| 6443 | TCP | Kubernetes API |
| 10250 | TCP | Kubelet |
| 8080 | TCP | HTTP Alt |
| 8443 | TCP | HTTPS Alt |

---

> **Hoàn thành Network Toàn Tập!** Tiếp theo: Ansible, Terraform, Kubernetes, Azure
