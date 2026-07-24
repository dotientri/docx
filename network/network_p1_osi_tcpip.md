# 🌐 NETWORK PHẦN 1: MÔ HÌNH OSI & TCP/IP

## 1. Tại Sao Phải Học Network?

### 1.1 Network Là Nền Tảng Mọi Thứ
- Không debug được service communication
- Không hiểu tại sao latency cao
- Không cấu hình firewall, load balancer, DNS
- Không hiểu K8s networking

### 1.2 Vai Trò Trong Hệ Thống Phân Tán

## 2. Mô Hình OSI - 7 Tầng
# ---
markmap:
  title: "Networking — OSI & TCP/IP"
  collapse: false
# ---

# 🌐 NETWORK PHẦN 1: MÔ HÌNH OSI & TCP/IP

## Theory
- OSI and TCP/IP models provide layered abstractions to reason about networking functions from physical links up to application protocols; encapsulation and addressing are core concepts.

## Practice
- Use `ss`, `tcpdump`, `traceroute`, and `dig` to inspect each layer; understand TCP states and practice reproducing handshake/teardown to debug connection issues.


- Giải thích **cách dữ liệu đi từ app máy A đến app máy B**
- Câu nhớ: "**P**lease **D**o **N**ot **T**hrow **S**ausage **P**izza **A**way"

### 2.2 Layer 1 - Physical (Vật Lý)
#### Nhiệm vụ
- Truyền **bits** (0 và 1) qua môi trường vật lý

#### Thiết bị
- Cables (Cat5/6, fiber), Hubs, Repeaters, NICs

#### Đặc điểm
- Không hiểu địa chỉ hay logic — chỉ biến điện thành bit

### 2.3 Layer 2 - Data Link (Liên Kết Dữ Liệu)
#### Nhiệm vụ
- Truyền frames giữa thiết bị trên **cùng mạng LAN**

#### Địa chỉ
- **MAC Address** (48-bit): `aa:bb:cc:dd:ee:ff`

#### Thiết bị & Protocol
- Switches, NICs
- Ethernet (IEEE 802.3), WiFi (IEEE 802.11)

#### PDU: Frame
```
Ethernet Frame:
┌────────────────┬────────────────┬──────┬────────────┬─────┐
│ Dest MAC (6B)  │ Src MAC (6B)   │ Type │  Data      │ FCS │
└────────────────┴────────────────┴──────┴────────────┴─────┘
```

### 2.4 Layer 3 - Network (Mạng) ⭐
#### Nhiệm vụ
- Định tuyến (routing) packets giữa **các mạng khác nhau**

#### Địa chỉ
- **IP Address** (IPv4: 32-bit, IPv6: 128-bit)

#### Thiết bị & Protocol
- Routers, Layer 3 Switches
- IP, ICMP, ARP, OSPF, BGP

#### PDU: Packet
```
IP Packet Header:
┌───────┬────────┬───────────────────┬──────────────┐
│Version│ TTL    │ Source IP         │ Destination IP│
│  4    │ 64     │ 192.168.1.10      │ 8.8.8.8      │
└───────┴────────┴───────────────────┴──────────────┘
```

### 2.5 Layer 4 - Transport (Vận Chuyển)
#### Nhiệm vụ
- End-to-end communication, error recovery, flow control

#### Địa chỉ
- **Port Numbers** (0-65535)

#### Protocol
- **TCP** (reliable), **UDP** (fast)

#### PDU: Segment (TCP) / Datagram (UDP)
```
TCP Segment:
┌───────────┬──────────────┬────────────────┬─────────┐
│ Src Port  │ Dest Port    │ Sequence Num   │  Data   │
│  45678    │  80 (HTTP)   │  1234567890    │         │
└───────────┴──────────────┴────────────────┴─────────┘
```

### 2.6 Layers 5, 6, 7 - Session/Presentation/Application
#### Session (Layer 5)
- Quản lý sessions: HTTP cookies, TCP connections

#### Presentation (Layer 6)
- Encoding, encryption: TLS/SSL, JPEG compression

#### Application (Layer 7)
- Giao thức user-facing: HTTP, DNS, SMTP, SSH

#### Thực tế
- Trong TCP/IP stack, layers 5-7 thường **gộp lại** thành 1 tầng Application

## 3. Mô Hình TCP/IP - 4 Tầng Thực Tế

### 3.1 So Sánh TCP/IP vs OSI
```
┌──────────────────────────────────────────────┐
│ Application Layer  ← HTTP, DNS, SSH, FTP     │ (OSI 5,6,7)
│ Transport Layer    ← TCP, UDP                │ (OSI 4)
│ Internet Layer     ← IP, ICMP, ARP           │ (OSI 3)
│ Network Access     ← Ethernet, WiFi          │ (OSI 1,2)
└──────────────────────────────────────────────┘
```

### 3.2 Encapsulation - Data Đi Như Thế Nào?
#### Khi Mở Browser Truy Cập google.com
##### Bước 1: Application Layer
- HTTP Request: `GET / HTTP/1.1\r\nHost: google.com`
- TLS encrypt (HTTPS)

##### Bước 2: Transport Layer (TCP)
- Thêm TCP Header: Src Port, Dst Port 443, Sequence Number

##### Bước 3: Internet Layer (IP)
- Thêm IP Header: Src IP, Dst IP `142.250.185.46`

##### Bước 4: Network Access (Ethernet)
- Thêm MAC Header + FCS

##### Bước 5: Physical
- Chuyển thành bits: `01001000 01100101...` qua cable

#### De-encapsulation
- Phía nhận: **bóc lớp bọc** từng tầng ngược lại

## 4. TCP - Hiểu Sâu

### 4.1 TCP Là Gì?
- **Connection-oriented, reliable** protocol
- Đảm bảo delivery, thứ tự, flow control

### 4.2 TCP 3-Way Handshake
```
Client                          Server
  │──── SYN (seq=x) ─────────────►│
  │◄─── SYN-ACK (seq=y, ack=x+1)─│
  │──── ACK (ack=y+1) ───────────►│
  │         DATA TRANSFER         │
```
#### Tại Sao 3-Way (Không Phải 2-Way)?
- Client cần biết server có thể nhận
- Server cần biết client có thể nhận
- 3 messages đủ verify **cả 2 chiều**

### 4.3 TCP 4-Way Teardown
```
Client                          Server
  │──── FIN ─────────────────────►│
  │◄─── ACK ──────────────────────│
  │◄─── FIN ──────────────────────│
  │──── ACK ─────────────────────►│
```

### 4.4 TCP States Quan Trọng
```bash
# Xem TCP connections
ss -tnp

# States:
# ESTABLISHED: Kết nối active
# TIME_WAIT:   Connection đóng, chờ 2MSL (60s)
# CLOSE_WAIT:  Server chờ close từ app
# SYN_SENT:    Client gửi SYN, chờ reply

# Đếm TCP states
ss -tn | awk 'NR>1{print $1}' | sort | uniq -c
```

### 4.5 TCP Flow Control & Congestion Control
#### Flow Control
- Receiver advertises **receive window** = bao nhiêu bytes có thể nhận
- Sender không gửi quá window size
- Window thay đổi dynamically

#### Congestion Control
- **Slow Start**: Bắt đầu nhỏ, tăng exponential
- **Congestion Avoidance**: Gần threshold → tăng linear
- **Fast Retransmit**: 3 duplicate ACKs → retransmit ngay
- **Fast Recovery**: Không về slow start sau fast retransmit

## 5. UDP - Hiểu Sâu

### 5.1 UDP Là Gì?
- **Connectionless, unreliable, fast**
- Không handshake, không ACK, không guarantee

### 5.2 UDP Header (Chỉ 8 Bytes!)
```
┌──────────────┬──────────────┐
│ Src Port (2B)│ Dst Port (2B)│
├──────────────┼──────────────┤
│ Length (2B)  │ Checksum (2B)│
└──────────────┴──────────────┘
```

### 5.3 Khi Nào Dùng UDP?
| Use Case | Tại Sao |
|----------|---------|
| DNS | Query nhỏ, retry được |
| Video streaming | Mất 1 frame OK hơn delay |
| VoIP | Latency quan trọng hơn |
| Gaming | Real-time, loss OK |
| DHCP | Broadcast, không có connection |
| QUIC (HTTP/3) | Tự implement reliability |

### 5.4 So Sánh TCP vs UDP
| Đặc Điểm | TCP | UDP |
|-----------|-----|-----|
| Kết nối | Connection-oriented | Connectionless |
| Reliability | Đảm bảo | Không |
| Speed | Chậm hơn | Nhanh hơn |
| Header | 20-60 bytes | 8 bytes |
| Flow Control | Có | Không |
| Use cases | HTTP, SSH, email | DNS, video, gaming |

## 6. IP Addressing

### 6.1 IPv4 - 32 Bit
```
IP: 192.168.1.100
Binary: 11000000.10101000.00000001.01100100
        └────────┘└────────┘└────────┘└────────┘
         Octet 1   Octet 2   Octet 3   Octet 4
```
- Phạm vi: 0.0.0.0 → 255.255.255.255 (4.29 tỷ)

### 6.2 Subnet Mask & CIDR
#### CIDR Notation
```
/24 = 24 bits network, 8 bits host → Mask 255.255.255.0
/16 = 16 bits network, 16 bits host → Mask 255.255.0.0
/8  = 8 bits network, 24 bits host → Mask 255.0.0.0
```

#### Tính Network, Broadcast, Host Range
```
Network: 192.168.1.0/24
Network Address:   192.168.1.0   (host bits = 0)
Broadcast Address: 192.168.1.255 (host bits = 1)
Usable Hosts:      192.168.1.1 → .254 (254 hosts)
```

#### Thực hành tính subnet
```bash
ipcalc 192.168.1.0/24
```

### 6.3 Private vs Public IPs
#### Private IP Ranges (RFC 1918)
| Range | CIDR | Dùng cho |
|-------|------|----------|
| Class A | 10.0.0.0/8 | Azure VNet |
| Class B | 172.16.0.0/12 | Docker |
| Class C | 192.168.0.0/16 | Home network |

#### Special IPs
- `127.0.0.0/8` → Loopback (localhost)
- `169.254.0.0/16` → Link-local (APIPA)
- `0.0.0.0` → Bind to all interfaces
- `255.255.255.255` → Limited broadcast

### 6.4 Subnetting Thực Tế
#### Ví Dụ: Chia Mạng Công Ty 10.0.0.0/8
```
Production: 10.0.0.0/16  (65534 hosts)
  Web tier:   10.0.1.0/24   (254 hosts)
  App tier:   10.0.2.0/24   (254 hosts)
  DB tier:    10.0.3.0/24   (254 hosts)
  K8s nodes:  10.0.10.0/23  (510 hosts)
  K8s pods:   10.0.128.0/17 (32766 hosts)
Staging:    10.1.0.0/16
Dev:        10.2.0.0/16
```

### 6.5 IPv6 - 128 Bit
- `2001:db8:85a3::8a2e:370:7334`
- 2^128 ≈ 340 undecillion addresses
- Không cần NAT, tích hợp IPsec

#### Special IPv6
- `::1` = loopback
- `fe80::/10` = link-local
- `fc00::/7` = Unique Local (private)

## 7. Routing - Định Tuyến

### 7.1 Routing Table
```bash
ip route show
# default via 192.168.1.1 dev eth0     ← Default gateway
# 192.168.1.0/24 dev eth0              ← Local network
# 10.0.0.0/8 via 10.1.0.1 dev eth1    ← Internal route

# Thêm/Xóa route
sudo ip route add 10.0.0.0/8 via 10.1.0.1 dev eth1
sudo ip route del 10.0.0.0/8
```

### 7.2 Quá Trình Routing Khi Ping 8.8.8.8
#### Bước 1: PC kiểm tra routing table
- 8.8.8.8 không match subnet nào → dùng default route

#### Bước 2: Gửi đến router
- ARP: "Ai là 192.168.1.1?" → Router reply MAC
- Đóng gói: IP Dst=8.8.8.8, MAC Dst=router's MAC

#### Bước 3: Router xử lý
- Lookup routing table → forward ra WAN
- **NAT**: thay Src IP private → public IP

#### Bước 4: ISP routing
- BGP routing tìm path tốt nhất đến Google

#### Bước 5: Reply quay về
- Router reverse NAT: thay Dst IP public → private
- Gửi về PC

### 7.3 NAT (Network Address Translation)
#### Cách NAT Hoạt Động
```
PC A: 192.168.1.10:45678 → 8.8.8.8:80
      ↓ NAT
      1.2.3.4:10001 → 8.8.8.8:80

NAT Table:
Private IP:Port       Public IP:Port
192.168.1.10:45678    1.2.3.4:10001
192.168.1.20:56789    1.2.3.4:10002
```

#### Các Loại NAT
- **SNAT**: Thay source IP (outbound, nhiều người chung 1 public IP)
- **DNAT**: Thay destination IP (port forwarding, load balancing)
- **Masquerade**: Dynamic SNAT (IP public thay đổi)

#### NAT Với iptables
```bash
# Cho phép internal ra internet
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Port forwarding: port 80 → 8080 nội bộ
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 \
  -j DNAT --to-destination 192.168.1.10:8080

# Xem NAT table
iptables -t nat -L -n -v
```

## 8. ARP - Address Resolution Protocol

### 8.1 ARP Là Gì?
- Chuyển đổi **IP Address ↔ MAC Address**
- "Ai có IP 192.168.1.1? Cho tôi biết MAC!"

### 8.2 Các Lệnh ARP
```bash
# Xem ARP cache
arp -n
ip neigh show

# Xóa ARP entry
sudo arp -d 192.168.1.1
```

### 8.3 Gratuitous ARP
- Broadcast ARP không ai hỏi
- Dùng cho: IP takeover, HA failover, update ARP cache

### 8.4 ARP Spoofing (Tấn Công)
- Kẻ tấn công gửi ARP giả mạo → redirect traffic
- Phòng chống: **Dynamic ARP Inspection (DAI)** trên switch
