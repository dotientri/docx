# ---
markmap:
  title: "Networking — Overview & Fundamentals"
  collapse: false
# ---

# 🧠 NETWORKING TỪ A ĐẾN Z - GIẢI THÍCH BẰNG LỜI

## Theory
- Networking is the backbone of distributed systems: understand layers (OSI), IP/subnetting, TCP/UDP, DNS, and routing to design and debug resilient infrastructure.

## Practice
- Use `ping`, `traceroute`, `ss`, `tcpdump`, and `dig` to narrow issues by OSI layer; design subnets with CIDR, validate firewall rules, and test connectivity from both ends.

## 1. Network Là Gì Và Tại Sao Cần Hiểu Sâu?

### 1.1 Định Nghĩa Network
- **Network** = Hệ thống các thiết bị (máy tính, server, router, switch) được kết nối với nhau để **trao đổi dữ liệu**
- Mọi ứng dụng hiện đại đều phụ thuộc vào network: từ gửi email, xem web, đến chạy microservices

### 1.2 Tại Sao DevOps Phải Hiểu Network?
- CI/CD pipeline pull code từ GitHub → **network**
- Docker pull image từ ACR → **network**
- K8s pods giao tiếp với nhau → **network**
- User access app → **network**
- Monitoring metrics được scrape → **network**
- Database replication → **network**

### 1.3 Lợi Ích Khi Hiểu Network
- **Debug nhanh hơn**: Biết đặt câu hỏi đúng khi lỗi mạng
- **Cấu hình chính xác**: Firewall, load balancer, DNS không còn hộp đen
- **Bảo mật tốt hơn**: Hiểu attack vectors, defense in depth
- **Thiết kế hệ thống**: Chọn đúng topology, subnet, routing

## 2. OSI Model - Framework Suy Nghĩ Về Mạng

### 2.1 OSI Model Là Gì?
- **OSI** (Open Systems Interconnection) = mô hình tham chiếu 7 tầng
- **Mục đích thực tế**: Không phải để học thuộc — mà là **framework để debug mạng**
- Khi có lỗi, đặt câu hỏi từng tầng **từ dưới lên** → narrow down vấn đề

### 2.2 Tầng 1 - Physical
- Dây cắm chưa? LED đèn mạng có nhấp nháy không?
- Không liên quan nhiều khi làm DevOps cloud, nhưng quan trọng trong data center

### 2.3 Tầng 2 - Data Link
- **MAC address**, ARP
- "Server có biết MAC address của router không?"
- Thường không cần debug ở tầng này trong DevOps

### 2.4 Tầng 3 - Network (IP) ⭐ Quan Trọng Nhất
- **IP routing**, subnet, firewall rules ở tầng này
- Câu hỏi: "Packet có đến được đích không?"
- Công cụ debug: `ping`, `traceroute`, kiểm tra routing table

### 2.5 Tầng 4 - Transport (TCP/UDP)
- **Port numbers**, connections
- Câu hỏi: "TCP connection có được established không?"
- Công cụ debug: `telnet host port`, `nc -zv host port`, `ss -tn`

### 2.6 Tầng 5-6-7 - Session/Presentation/Application
- HTTP, TLS, DNS
- Câu hỏi: "Request đúng format? Auth đúng? Response body là gì?"
- Công cụ debug: `curl -v`, inspect headers

### 2.7 Ứng Dụng Thực Tế: Debug K8s Pod Không Kết Nối DB
#### Bước 1 - Tầng 3: Pod có route đến DB không?
```bash
kubectl exec pod -- ping db-ip
```
#### Bước 2 - Tầng 4: Port DB có mở không?
```bash
kubectl exec pod -- nc -zv db-host 5432
```
#### Bước 3 - Tầng 7: Auth đúng chưa?
- Kiểm tra connection string, username/password, SSL certificate
- **Kết luận**: Không cần đọc toàn bộ logs — đặt câu hỏi từng tầng, narrow down vấn đề

## 3. IP Addressing - Hiểu Subnet Thực Sự

### 3.1 IP Address Là Gì?
- **IP address** = địa chỉ duy nhất của một device trên mạng (như địa chỉ nhà)
- **IPv4** = 4 số từ 0-255, ngăn cách bằng dấu chấm: `192.168.1.100`
- Thực ra là **số nhị phân 32 bit**: `11000000.10101000.00000001.01100100`

### 3.2 Subnet Mask - Phần "Khu Phố" Và "Số Nhà"
- `192.168.1.100/24` → số `/24` = **CIDR notation**
- 24 bits đầu = **network part** (khu phố)
- 8 bits sau = **host part** (số nhà)
```
192.168.1  .100
└─────────┘ └──┘
 Network     Host
 (24 bits)  (8 bits)
```

### 3.3 Cách Tính Số Host Trong Subnet
- `/24` = 8 bits host = 2^8 = 256 addresses
- Trừ 1 network address + 1 broadcast = **254 usable hosts**

### 3.4 Các Subnet Thường Gặp
| CIDR | Total | Usable | Ghi chú |
|------|-------|--------|---------|
| `/32` | 1 | 1 | Chính IP đó |
| `/30` | 4 | 2 | Point-to-point links |
| `/28` | 16 | 14 | Small subnet |
| `/24` | 256 | 254 | 1 class C |
| `/16` | 65,536 | 65,534 | VNet trong Azure |
| `/8` | 16,777,216 | 16,777,214 | Lớn nhất |

### 3.5 Private IP Ranges (Không Route Được Trên Internet)
- `10.0.0.0/8` → Cloud VNets, VPCs
- `172.16.0.0/12` → Docker default bridge dùng range này
- `192.168.0.0/16` → Home/office networks

## 4. TCP vs UDP - Khi Nào Dùng Cái Nào?

### 4.1 TCP (Transmission Control Protocol)
#### TCP Là Gì?
- Đảm bảo data **đến nơi đầy đủ, đúng thứ tự, không lỗi**
- **Connection-oriented**: Thiết lập kết nối trước khi gửi data

#### Cơ Chế Hoạt Động
- **Three-way handshake**: SYN → SYN-ACK → ACK
- **Acknowledgment**: Mỗi packet phải được xác nhận, không ACK → retransmit
- **Sequencing**: Đánh số thứ tự packets, receiver reorder nếu đến không thứ tự
- **Flow control**: Điều chỉnh tốc độ gửi theo capacity receiver
- **Congestion control**: Giảm tốc độ nếu mạng tắc nghẽn

#### Chi Phí Của TCP
- Overhead từ handshake, ACK, retransmission
- **Chậm hơn UDP nhưng reliable**

#### Khi Nào Dùng TCP?
- Data phải chính xác 100%: HTTP/HTTPS, SSH, FTP, database connections, email

### 4.2 UDP (User Datagram Protocol)
#### UDP Là Gì?
- Gửi packet và **không quan tâm đến đích** — "Fire and forget"
- Không có handshake, không ACK, không guarantee order

#### Ưu Điểm Của UDP
- Overhead thấp hơn nhiều
- Latency thấp hơn
- Sender không cần chờ receiver

#### Khi Nào Dùng UDP?
- **DNS**: Query/response nhỏ, mất thì retry ngay
- **Video streaming**: Mất 1 frame → hiển thị blur, không cần retransmit frame cũ
- **Online gaming**: 1ms lag quan trọng hơn 1 packet mất
- **VoIP**: Mất vài milliseconds tiếng OK hơn delay retransmit
- **QUIC (HTTP/3)**: UDP nhưng implement reliability ở application layer

### 4.3 So Sánh TCP vs UDP
| Đặc điểm | TCP | UDP |
|-----------|-----|-----|
| Kết nối | Connection-oriented | Connectionless |
| Reliability | Đảm bảo | Không đảm bảo |
| Thứ tự | Đảm bảo | Không đảm bảo |
| Speed | Chậm hơn | Nhanh hơn |
| Header | 20-60 bytes | 8 bytes |
| Use cases | HTTP, SSH, email | DNS, video, gaming |

## 5. DNS - Hệ Thống Phân Giải Tên Miền

### 5.1 Tại Sao Cần DNS?
- IP address `142.250.185.46` khó nhớ → `google.com` dễ nhớ
- DNS = hệ thống **"danh bạ"** chuyển đổi tên miền ↔ IP

### 5.2 Tại Sao DNS Phải Phân Cấp?
- 1 server DNS duy nhất → **single point of failure**, không scale
- Bị DDoS → toàn thế giới mù mạng

### 5.3 Cấu Trúc Phân Cấp DNS
#### Root Servers
- 13 clusters, hàng nghìn servers vật lý
- Biết ai quản lý `.com`, `.net`, `.vn`...

#### TLD Servers (Top-Level Domain)
- Biết ai quản lý `google.com`, `amazon.com`...

#### Authoritative Servers
- Biết chính xác `google.com` = IP nào, `www.google.com` = IP nào

#### Recursive Resolvers
- ISP, Google `8.8.8.8`, Cloudflare `1.1.1.1`
- Làm thay bạn, cache kết quả

### 5.4 Caching Và TTL
- Mỗi DNS record có **TTL** (Time To Live)
- Resolver cache kết quả, không query authoritative mỗi lần
- Khi TTL hết → query lại

### 5.5 Ý Nghĩa Thực Tế Của TTL
- Thay đổi IP `api.company.com` → cần chờ TTL expire
- TTL 3600s (1 giờ) → mất đến 1 giờ propagate
- **Best practice migrate**: Giảm TTL xuống 300s (5 phút) từ 48 giờ trước → migrate → verify → tăng TTL lại

### 5.6 DNS Trong Kubernetes
- K8s có DNS riêng: **CoreDNS**
- Pod A connect pod B → query CoreDNS, không phải public DNS
- `myservice.mynamespace.svc.cluster.local` = ClusterIP của service
- Pods dùng tên service thay vì IP (IP thay đổi khi pod restart)

## 6. TLS/HTTPS - Không Chỉ Là "Mã Hóa"

### 6.1 Ba Vấn Đề HTTPS Giải Quyết
#### Confidentiality (Bí mật)
- Data được mã hóa, MITM không đọc được

#### Integrity (Toàn vẹn)
- Data không bị sửa trên đường truyền

#### Authentication (Xác thực) ⭐
- Đây **thực sự** là server của `google.com`, không phải server giả mạo

### 6.2 Tại Sao Authentication Quan Trọng?
- Nếu chỉ mã hóa mà không xác thực → MITM attack:
  1. Attacker chặn connection đến google.com
  2. Tự tạo connection đến google.com
  3. Relay data qua lại, đọc và sửa tất cả
- Bạn nghĩ đang nói với google.com → thực ra nói với attacker

### 6.3 Certificate Authority (CA) Giải Quyết Thế Nào?
- **CA** = Tổ chức được tin tưởng (Let's Encrypt, DigiCert, Comodo)
- Browser/OS pre-install ~100 CA trusted
- Google chứng minh sở hữu `google.com` → CA cấp certificate ("passport" có chữ ký)

### 6.4 Quy Trình Verify Certificate
1. Browser nhận certificate từ server
2. Verify chữ ký CA trên certificate
3. CA có trong trusted list?
4. **Có** → Certificate hợp lệ → Server thực sự là `google.com`
- MITM không thể giả mạo vì không có private key của CA

### 6.5 TLS 1.3 - Tại Sao Nhanh Hơn?
#### TLS 1.2
- 2 Round Trips trước khi gửi data
- Latency 50ms → thêm 100ms chỉ cho handshake

#### TLS 1.3
- Chỉ 1 Round Trip
- Client gửi luôn cipher suites + key share trong ClientHello đầu tiên

#### 0-RTT (Session Resumption)
- Client đã kết nối trước → có "session ticket"
- Lần sau gửi data luôn trong request đầu tiên

## 7. Load Balancer - Tại Sao Cần Nhiều Servers?

### 7.1 Vấn Đề Với 1 Server
- 1 server có giới hạn (32 CPU, 256GB RAM)
- Không handle 1 triệu concurrent users
- **Single point of failure**: Server down = toàn bộ users mất access

### 7.2 Giải Pháp: Scale Horizontally
- Thêm nhiều servers nhỏ chạy cùng app
- Load balancer đứng trước, phân phối traffic

### 7.3 Lợi Ích Scale Horizontal
- **Capacity**: 10 servers × 100 users = 1000 users
- **High Availability**: 1 server down → 9 server handle
- **Rolling Deployments**: Update từng server, zero downtime

### 7.4 Các Thuật Toán Phân Phối
#### Round Robin
- Lần lượt A→B→C→A→B→C
- Đơn giản, fair nhưng không quan tâm server nào đang bận

#### Least Connections
- Gửi request đến server ít connections nhất
- Tốt khi requests có duration khác nhau

#### Weighted Round Robin
- Server mạnh hơn nhận nhiều request hơn
- Server A (8 cores) nhận 2x so với Server B (4 cores)

#### IP Hash
- Hash IP client → luôn gửi đến cùng 1 server
- Cần cho stateful apps (nhưng không nên dùng pattern này)

### 7.5 Health Checks
- Load balancer liên tục kiểm tra backend: HTTP GET `/health`
- Fail → remove khỏi pool
- Recover → add lại

## 8. Firewall - Bảo Vệ Như Thế Nào?

### 8.1 Firewall Là Gì?
- "Bảo vệ cửa" quyết định traffic nào được vào/ra

### 8.2 Packet Filtering (Stateless)
- Quy tắc đơn giản: "Cho phép IP X, port Y vào"
- Mỗi packet kiểm tra **độc lập**, không có context

### 8.3 Stateful Firewall
- Track connections
- Biết packet thuộc established TCP connection → cho qua tự động
- Ví dụ: Rule "allow outbound HTTP" → response tự động allowed

### 8.4 NSG Trong Azure
- **Azure NSG** = stateful firewall cho VNet
- Mỗi subnet/NIC attach một NSG
- Rule priority (thấp = ưu tiên): Priority 100 check trước 200

#### Default Rules Azure
- Allow VNet inbound (VMs cùng VNet communicate)
- Allow Azure Load Balancer (health probes)
- **Deny All inbound** (chặn mọi thứ khác)

### 8.5 Defense in Depth - Tại Sao Cần Nhiều Lớp?
- **Layer 1**: Azure Firewall/WAF ở edge → block IPs, country, OWASP
- **Layer 2**: NSG ở subnet → chỉ cho phép ports cần thiết
- **Layer 3**: NSG ở NIC → control individual VM
- **Layer 4**: OS firewall (iptables/ufw) → last line of defense
- Attacker bypass layer 1 → vẫn còn 3 lớp nữa

## 9. VPN vs Reverse Proxy vs Forward Proxy

### 9.1 Forward Proxy
- Client → **Forward Proxy** → Internet
- Client biết về proxy, Internet thấy IP proxy, không thấy IP client
#### Use Cases
- Công ty kiểm soát Internet qua proxy
- Anonymity (Tor, VPN thương mại)

### 9.2 Reverse Proxy
- Client → **Reverse Proxy** → Backend servers
- Client **không biết** backend phía sau
- Client nghĩ nói với `api.company.com` → thực ra nói với Nginx
#### Use Cases
- Load balancing
- SSL termination (decrypt HTTPS 1 lần, forward HTTP nội bộ)
- Caching, Compression, API Gateway

### 9.3 VPN (Virtual Private Network)
- Tạo **"đường hầm mã hóa"** qua Internet public
- ISP không đọc được traffic trong tunnel

#### Site-to-Site VPN
- Kết nối hai mạng riêng: Office ↔ Azure VNet

#### Point-to-Site VPN
- Developer connect laptop → Azure VNet private resources

### 9.4 Azure ExpressRoute vs VPN
#### VPN
- Đi qua Internet public, bandwidth/latency không guaranteed

#### ExpressRoute
- **Dedicated private connection** → Azure, KHÔNG qua Internet
- Guaranteed bandwidth, lower latency, more security
- **Nhưng**: Tốn kém (vài nghìn USD/tháng), chỉ enterprise cần

## 10. Container Networking Trong Kubernetes

### 10.1 Vấn Đề Phức Tạp
- Hàng nghìn pods, hàng chục nodes
- Pods tạo/xóa bất kỳ lúc nào
- Làm sao communicate?

### 10.2 K8s Networking Rules (Flat Model)
1. Mỗi Pod có **IP riêng**
2. Pods communicate qua Pod IP **không cần NAT** (dù khác nodes)
3. Nodes communicate với Pods không cần NAT
- Đây gọi là **"flat network"** — không có NAT phức tạp giữa pods

### 10.3 CNI Plugins
- **Calico**, **Flannel**, **Cilium** = plugins implement K8s networking
- Mỗi plugin cách khác nhau nhưng cùng kết quả

### 10.4 Service - Stable Endpoint
- Pod IPs **thay đổi** khi restart → App không thể hardcode
- **Service** = virtual IP (ClusterIP) **stable** không đổi
- Kube-proxy tạo iptables/IPVS rules route traffic từ ClusterIP → Pod IPs
- Pod restart IP mới → Service tự update backend

### 10.5 DNS Trong K8s
- **CoreDNS** biết tất cả Services
- `myservice.mynamespace.svc.cluster.local` → ClusterIP
- Cùng namespace: chỉ cần `myservice`
- Khác namespace: `myservice.mynamespace`
