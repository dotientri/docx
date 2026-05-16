# 🌐 NETWORK TOÀN TẬP - PHẦN 1: MÔ HÌNH OSI & TCP/IP

---

## 1. Tại Sao Phải Học Network?

Nếu làm DevOps/SRE/Backend Developer mà không hiểu networking:
- Không debug được tại sao service này không nói chuyện được với service kia
- Không hiểu tại sao latency cao
- Không cấu hình được firewall, load balancer, DNS
- Không hiểu tại sao Kubernetes networking hoạt động

Network là **nền tảng của mọi thứ** trong hệ thống phân tán.

---

## 2. Mô Hình OSI - 7 Tầng

### 2.1 Tổng Quan

OSI (Open Systems Interconnection) là mô hình tham chiếu giải thích **cách dữ liệu đi từ application của máy A đến application của máy B**.

```
┌─────────────────────────────────────────────────────┐
│  Layer 7: Application   HTTP, FTP, SMTP, DNS, SSH   │
│  Layer 6: Presentation  TLS/SSL, JPEG, MPEG          │
│  Layer 5: Session       NetBIOS, RPC, SQL Session    │
│  Layer 4: Transport     TCP, UDP                     │
│  Layer 3: Network       IP, ICMP, Routing            │
│  Layer 2: Data Link     Ethernet, WiFi (MAC address) │
│  Layer 1: Physical      Cables, Hubs, Bits           │
└─────────────────────────────────────────────────────┘
```

**Câu nhớ:** "**P**lease **D**o **N**ot **T**hrow **S**ausage **P**izza **A**way"
(Physical, Data Link, Network, Transport, Session, Presentation, Application)

### 2.2 Từng Tầng Chi Tiết

#### Layer 1 - Physical (Vật Lý)
- **Nhiệm vụ:** Truyền **bits** (0 và 1) qua môi trường vật lý
- **Thiết bị:** Cables (Cat5/6, fiber), Hubs, Repeaters, NICs
- **Không hiểu** địa chỉ hay logic gì cả — chỉ biến điện thành bit

```
Bit: 01001000 01100101 01101100 01101100 01101111
     ← Truyền qua cable hoặc sóng radio →
```

#### Layer 2 - Data Link (Liên Kết Dữ Liệu)
- **Nhiệm vụ:** Truyền frames giữa các thiết bị trên **cùng mạng cục bộ (LAN)**
- **Địa chỉ:** MAC Address (48-bit, ví dụ: `aa:bb:cc:dd:ee:ff`)
- **Thiết bị:** Switches, Network Interface Cards (NICs)
- **Protocols:** Ethernet (IEEE 802.3), WiFi (IEEE 802.11)
- **PDU (Protocol Data Unit):** Frame

```
Ethernet Frame:
┌────────────────┬────────────────┬──────┬────────────┬─────┐
│ Dest MAC (6B)  │ Src MAC (6B)   │ Type │  Data      │ FCS │
│ aa:bb:cc:11:22 │ aa:bb:cc:33:44 │ 0800 │ (IP Packet)│     │
└────────────────┴────────────────┴──────┴────────────┴─────┘
```

#### Layer 3 - Network (Mạng)
- **Nhiệm vụ:** Định tuyến (routing) packets giữa **các mạng khác nhau**
- **Địa chỉ:** IP Address (IPv4: 32-bit, IPv6: 128-bit)
- **Thiết bị:** Routers, Layer 3 Switches
- **Protocols:** IP, ICMP, ARP, OSPF, BGP
- **PDU:** Packet

```
IP Packet Header:
┌───────┬────────┬───────────────────┬──────────────┐
│Version│ TTL    │ Source IP         │ Destination IP│
│  4    │ 64     │ 192.168.1.10      │ 8.8.8.8      │
└───────┴────────┴───────────────────┴──────────────┘
```

#### Layer 4 - Transport (Vận Chuyển)
- **Nhiệm vụ:** End-to-end communication, error recovery, flow control
- **Địa chỉ:** Port Numbers (0-65535)
- **Protocols:** TCP, UDP
- **PDU:** Segment (TCP) / Datagram (UDP)

```
TCP Segment:
┌───────────┬──────────────┬────────────────┬─────────┐
│ Src Port  │ Dest Port    │ Sequence Num   │  Data   │
│  45678    │  80 (HTTP)   │  1234567890    │         │
└───────────┴──────────────┴────────────────┴─────────┘
```

#### Layers 5, 6, 7 - Thực Tế
Trong TCP/IP stack thực tế (Internet), layers 5-7 thường được gộp lại:
- **Session:** Quản lý sessions (HTTP cookies, TCP connections)
- **Presentation:** Encoding, encryption (TLS/SSL, JPEG compression)
- **Application:** Giao thức user-facing (HTTP, DNS, SMTP, SSH)

---

## 3. Mô Hình TCP/IP - Thực Tế Hơn

TCP/IP model có **4 tầng** (đơn giản hóa từ OSI):

```
┌─────────────────────────────────────────────────────┐
│  Application Layer  ← HTTP, DNS, SMTP, SSH, FTP     │  (OSI 5,6,7)
│  Transport Layer    ← TCP, UDP                       │  (OSI 4)
│  Internet Layer     ← IP, ICMP, ARP                 │  (OSI 3)
│  Network Access     ← Ethernet, WiFi                │  (OSI 1,2)
└─────────────────────────────────────────────────────┘
```

### 3.1 Encapsulation - Data Đi Như Thế Nào?

Khi bạn mở browser và truy cập `https://google.com`:

```
Application Layer:
  HTTP Request: "GET / HTTP/1.1\r\nHost: google.com\r\n\r\n"
  ↓ TLS encrypt (HTTPS)
  
Transport Layer (TCP):
  [TCP Header: Src:45678, Dst:443, Seq:1234] + [Encrypted HTTP Data]
  ↓
  
Internet Layer (IP):
  [IP Header: Src:192.168.1.10, Dst:142.250.185.46] + [TCP Segment]
  ↓
  
Network Access (Ethernet):
  [MAC Header: Src:aa:bb:cc, Dst:aa:bb:dd] + [IP Packet] + [FCS]
  ↓
  
Physical:
  01001000 01100101...  (bits qua cable)
```

**De-encapsulation** xảy ra ở phía nhận — mỗi tầng bóc lớp bọc của mình.

---

## 4. TCP vs UDP - Hiểu Sâu

### 4.1 TCP (Transmission Control Protocol)

TCP là giao thức **connection-oriented, reliable**.

**Đặc điểm:**
- Thiết lập kết nối trước (3-way handshake)
- Đảm bảo delivery (acknowledge, retransmit nếu mất)
- Đảm bảo thứ tự (sequence numbers)
- Flow control (tránh overwhelm receiver)
- Congestion control (tránh overwhelm mạng)

#### TCP 3-Way Handshake

```
Client                          Server
  │                               │
  │──── SYN (seq=x) ─────────────►│
  │                               │
  │◄─── SYN-ACK (seq=y, ack=x+1)─│
  │                               │
  │──── ACK (ack=y+1) ───────────►│
  │                               │
  │         DATA TRANSFER         │
  │◄─────────────────────────────►│
  │                               │
  │──── FIN ─────────────────────►│  (4-way teardown)
  │◄─── ACK ──────────────────────│
  │◄─── FIN ──────────────────────│
  │──── ACK ─────────────────────►│
```

**Tại sao 3-way (không phải 2-way)?**
- Client cần biết server có thể nhận
- Server cần biết client có thể nhận
- Chỉ 3 messages là đủ để verify cả 2 chiều

```bash
# Xem TCP connections
ss -tnp                    # Socket Statistics (mới hơn netstat)
netstat -tnp               # Cách cũ

# States quan trọng:
# ESTABLISHED: Kết nối đang active
# TIME_WAIT:   Connection đóng, đang chờ 2MSL (60 giây)
# CLOSE_WAIT:  Server chờ close từ application
# SYN_SENT:    Client gửi SYN, chờ reply

# Xem TCP states count
ss -tn | awk 'NR>1{print $1}' | sort | uniq -c

# Theo dõi real-time
watch -n1 'ss -tn | awk "NR>1{print \$1}" | sort | uniq -c'
```

#### TCP Flow Control & Congestion Control

```
TCP Window Size:
- Receiver advertises "receive window" = bao nhiêu bytes nó có thể nhận
- Sender không gửi quá window size
- Window thay đổi dynamically

Congestion Control:
- Slow Start: Bắt đầu nhỏ, tăng dần (exponential)
- Congestion Avoidance: Khi gần threshold, tăng linear
- Fast Retransmit: Sau 3 duplicate ACKs → retransmit ngay (không chờ timeout)
- Fast Recovery: Không về slow start sau fast retransmit
```

### 4.2 UDP (User Datagram Protocol)

UDP là giao thức **connectionless, unreliable, fast**.

**Đặc điểm:**
- Không handshake → gửi ngay
- Không đảm bảo delivery
- Không đảm bảo thứ tự
- Không flow control
- Header nhỏ (8 bytes vs TCP 20+ bytes)
- **Nhanh hơn, overhead ít hơn**

```
UDP Header (chỉ 8 bytes!):
┌──────────────┬──────────────┐
│ Src Port (2B)│ Dst Port (2B)│
├──────────────┼──────────────┤
│ Length (2B)  │ Checksum (2B)│
└──────────────┴──────────────┘
```

**Dùng khi nào:**
| Use Case | Tại Sao UDP |
|----------|------------|
| DNS queries | Query nhỏ, retry được |
| Video streaming | Mất 1 frame OK hơn delay |
| VoIP (calls) | Latency quan trọng hơn reliability |
| Gaming | Real-time, loss OK |
| DHCP | Broadcast, không có connection |
| QUIC (HTTP/3) | Tự implement reliability trong user space |

### 4.3 So Sánh TCP vs UDP

| Đặc Điểm | TCP | UDP |
|-----------|-----|-----|
| Kết nối | Connection-oriented | Connectionless |
| Reliability | Đảm bảo | Không đảm bảo |
| Thứ tự | Đảm bảo | Không đảm bảo |
| Speed | Chậm hơn | Nhanh hơn |
| Header Size | 20-60 bytes | 8 bytes |
| Flow Control | Có | Không |
| Use cases | HTTP, SSH, email | DNS, video, gaming |

---

## 5. IP Addressing - Địa Chỉ IP

### 5.1 IPv4 - 32-bit

```
IP Address: 192.168.1.100
Binary:     11000000.10101000.00000001.01100100
            └────────┘└────────┘└────────┘└────────┘
              Octet 1   Octet 2   Octet 3   Octet 4
```

**Phạm vi:** 0.0.0.0 → 255.255.255.255 (4,294,967,296 địa chỉ)

### 5.2 Subnet Mask & CIDR

CIDR (Classless Inter-Domain Routing) notation: `192.168.1.0/24`

```
/24 = 24 bits cho network, 8 bits cho host
Subnet mask: 255.255.255.0

/16 = 16 bits network, 16 bits host
Subnet mask: 255.255.0.0

/8  = 8 bits network, 24 bits host  
Subnet mask: 255.0.0.0
```

**Tính network, broadcast, host range:**

```
Network: 192.168.1.0/24
Binary:  11000000.10101000.00000001.00000000

Network Address:   192.168.1.0   (tất cả host bits = 0)
Broadcast Address: 192.168.1.255 (tất cả host bits = 1)
Usable Hosts:      192.168.1.1 → 192.168.1.254 (254 hosts)
Total IPs:         256 (2^8)
Usable IPs:        254 (256 - 2)
```

```bash
# Tính subnet với ipcalc
ipcalc 192.168.1.0/24
# Address:   192.168.1.0          11000000.10101000.00000001. 00000000
# Netmask:   255.255.255.0 = 24   11111111.11111111.11111111. 00000000
# Wildcard:  0.0.0.255            00000000.00000000.00000000. 11111111
# =>
# Network:   192.168.1.0/24       11000000.10101000.00000001. 00000000
# HostMin:   192.168.1.1          11000000.10101000.00000001. 00000001
# HostMax:   192.168.1.254        11000000.10101000.00000001. 11111110
# Broadcast: 192.168.1.255        11000000.10101000.00000001. 11111111
# Hosts/Net: 254
```

### 5.3 Private vs Public IPs

**Private IP Ranges (RFC 1918) - Không route được trên Internet:**

| Range | CIDR | Từ | Đến | Dùng Cho |
|-------|------|-----|-----|---------|
| Class A | 10.0.0.0/8 | 10.0.0.0 | 10.255.255.255 | Lớn (Azure VNet mặc định) |
| Class B | 172.16.0.0/12 | 172.16.0.0 | 172.31.255.255 | Vừa (Docker dùng) |
| Class C | 192.168.0.0/16 | 192.168.0.0 | 192.168.255.255 | Nhỏ (home network) |

**Special IPs:**
```
127.0.0.0/8      → Loopback (localhost = 127.0.0.1)
169.254.0.0/16   → Link-local (APIPA - khi không có DHCP)
0.0.0.0          → Unspecified (bind to all interfaces)
255.255.255.255  → Limited broadcast
```

### 5.4 Subnetting Thực Tế - Chia Mạng

```
Tình huống: Công ty có 10.0.0.0/8
Cần chia thành nhiều subnets:
- Production: 10.0.0.0/16    (10.0.0.0 - 10.0.255.255, 65534 hosts)
- Staging:    10.1.0.0/16    (10.1.0.0 - 10.1.255.255, 65534 hosts)
- Dev:        10.2.0.0/16    (10.2.0.0 - 10.2.255.255, 65534 hosts)

Trong Production (10.0.0.0/16), chia thêm:
- Web tier:   10.0.1.0/24   (254 hosts)
- App tier:   10.0.2.0/24   (254 hosts)
- DB tier:    10.0.3.0/24   (254 hosts)
- K8s nodes:  10.0.10.0/23  (510 hosts)
- K8s pods:   10.0.128.0/17 (32766 hosts)
```

### 5.5 IPv6 - 128-bit

```
IPv6 Address: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
Shortened:    2001:db8:85a3::8a2e:370:7334
             (:: = một hoặc nhiều groups 0000 liên tiếp)

Đặc điểm:
- 2^128 địa chỉ ≈ 340 undecillion
- Không cần NAT (đủ public IPs cho tất cả)
- Tích hợp IPsec
- Stateless Address Autoconfiguration (SLAAC)

Loopback:    ::1  (tương đương 127.0.0.1)
Link-local:  fe80::/10
Private:     fc00::/7 (Unique Local)

# Xem IPv6 addresses
ip -6 addr show
ping6 ::1
```

---

## 6. Routing - Định Tuyến

### 6.1 Routing Table

```bash
# Xem routing table
ip route show
# default via 192.168.1.1 dev eth0              ← Default gateway
# 192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100
# 10.0.0.0/8 via 10.1.0.1 dev eth1             ← Route cho internal

# Thêm route
sudo ip route add 10.0.0.0/8 via 10.1.0.1 dev eth1

# Xóa route
sudo ip route del 10.0.0.0/8

# Route tĩnh vĩnh viễn (Ubuntu Netplan)
cat /etc/netplan/01-network-manager-all.yaml
```

### 6.2 Quá Trình Routing

```
PC A (192.168.1.10) muốn ping 8.8.8.8

Bước 1: PC A kiểm tra routing table
  → 8.8.8.8 không match bất kỳ subnet nào
  → Dùng default route: via 192.168.1.1 (router)

Bước 2: PC A gửi packet đến router (192.168.1.1)
  → ARP: "Ai là 192.168.1.1?" → Router reply với MAC của mình
  → PC A đóng gói: IP Dst=8.8.8.8, MAC Dst=router's MAC

Bước 3: Router nhận packet
  → Xem IP Dst = 8.8.8.8 (public IP)
  → Lookup routing table → forward ra WAN interface
  → NAT: thay Src IP từ 192.168.1.10 → public IP (e.g., 1.2.3.4)

Bước 4: ISP routers forward đến Google
  → BGP routing protocols tìm path tốt nhất

Bước 5: Reply từ 8.8.8.8 quay về
  → Router NAT: thay Dst IP từ 1.2.3.4 → 192.168.1.10
  → Gửi về PC A
```

### 6.3 NAT (Network Address Translation)

```
Private Network                    Internet
192.168.1.0/24          Router/Firewall        
                         Public IP: 1.2.3.4

PC A: 192.168.1.10:45678 → 8.8.8.8:80
      ↓ NAT
      1.2.3.4:10001 → 8.8.8.8:80

PC B: 192.168.1.20:56789 → 8.8.8.8:80
      ↓ NAT
      1.2.3.4:10002 → 8.8.8.8:80

NAT Table (trong Router):
Private IP:Port       Public IP:Port
192.168.1.10:45678    1.2.3.4:10001
192.168.1.20:56789    1.2.3.4:10002
```

**Các loại NAT:**
- **SNAT (Source NAT):** Thay đổi source IP/Port (outbound, nhiều người dùng chung 1 public IP)
- **DNAT (Destination NAT):** Thay đổi destination IP/Port (port forwarding, load balancing)
- **Masquerade:** Dynamic SNAT (IP public thay đổi được, dùng trên dynamic interfaces)

```bash
# iptables NAT examples (dùng hàng ngày trên Linux servers)

# MASQUERADE - cho phép internal traffic ra internet
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# DNAT - port forwarding (port 80 ngoài → nội bộ 8080)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 \
  -j DNAT --to-destination 192.168.1.10:8080

# Xem NAT table
iptables -t nat -L -n -v
```

---

## 7. ARP - Address Resolution Protocol

```bash
# ARP: Chuyển đổi IP Address ↔ MAC Address
# "Ai có IP 192.168.1.1? Hãy cho tôi biết MAC của bạn!"

# Xem ARP cache
arp -n
ip neigh show

# Output:
# 192.168.1.1     dev eth0  lladdr aa:bb:cc:dd:ee:ff STALE
# 192.168.1.5     dev eth0  lladdr 11:22:33:44:55:66 REACHABLE

# Xóa ARP entry
sudo arp -d 192.168.1.1
sudo ip neigh del 192.168.1.1 dev eth0

# Gratuitous ARP (broadcast ARP không ai hỏi)
# Dùng cho: IP takeover, HA failover, update ARP cache

# ARP Spoofing (tấn công man-in-the-middle)
# Kẻ tấn công gửi ARP giả mạo → redirect traffic
# Phòng chống: Dynamic ARP Inspection (DAI) trên switch
```

---

> **Tiếp theo: Phần 2** - DNS, DHCP, HTTP/HTTPS Protocol Deep Dive
