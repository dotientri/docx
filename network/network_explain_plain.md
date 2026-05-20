# 🧠 GIẢI THÍCH BẰNG LỜI - NETWORKING TỪ A ĐẾN Z

---

## 1. Network là gì và tại sao cần hiểu sâu?

Mọi thứ trong DevOps đều liên quan đến network:
- CI/CD pipeline pull code từ GitHub → network
- Docker pull image từ ACR → network
- K8s pods giao tiếp với nhau → network
- User access app → network
- Monitoring metrics được scrape → network
- Database replication → network

Khi một trong những thứ trên fail, nếu không hiểu networking bạn sẽ bị mù hoàn toàn. Hiểu networking = biết đặt câu hỏi đúng khi debug.

---

## 2. OSI Model - Tại sao cần biết 7 tầng?

OSI model không phải để học thuộc 7 tầng - mà là **framework để suy nghĩ về vấn đề mạng**.

Khi có lỗi mạng, bạn đặt câu hỏi từng tầng từ dưới lên:

**Tầng 1 - Physical:** Dây cắm chưa? LED đèn mạng có nhấp nháy không? (Không liên quan khi làm DevOps cloud, nhưng trong data center thì có)

**Tầng 2 - Data Link:** MAC address, ARP. "Server có biết MAC address của router không?" - thường không cần debug tầng này.

**Tầng 3 - Network (IP):** Đây là tầng quan trọng nhất trong cloud/DevOps. IP routing, subnet, firewall rules ở tầng này. "Packet có đến được đích không?" → `ping`, `traceroute`, kiểm tra routing table.

**Tầng 4 - Transport (TCP/UDP):** Port numbers, connections. "TCP connection có được established không?" → `telnet host port`, `nc -zv host port`, `ss -tn`.

**Tầng 5-6-7 - Session/Presentation/Application:** HTTP, TLS, DNS - tầng application. "Request đúng format chưa? Auth đúng chưa? Response body là gì?" → `curl -v`, inspect headers.

**Ứng dụng thực tế:**

Khi K8s pod không kết nối được database:
1. Tầng 3: Pod có route đến DB network không? `kubectl exec pod -- ping db-ip`
2. Tầng 4: Port 5432 có open không? `kubectl exec pod -- nc -zv db-host 5432`
3. Tầng 7: Auth đúng không? Connection string đúng chưa?

Không cần đọc toàn bộ logs - đặt câu hỏi từng tầng, narrow down vấn đề.

---

## 3. IP Addressing - Hiểu subnet thực sự

**IP address** = địa chỉ duy nhất của một device trên mạng. Như địa chỉ nhà vậy.

**IPv4** = 4 số từ 0-255, ngăn cách bằng dấu chấm: `192.168.1.100`

Thực ra đây là số nhị phân 32 bit:
```
192.168.1.100
= 11000000.10101000.00000001.01100100
```

**Subnet mask - Phần nào là "khu phố", phần nào là "số nhà"?**

`192.168.1.100/24` - số /24 gọi là CIDR notation, nghĩa là 24 bits đầu là "network part" (khu phố), 8 bits sau là "host part" (số nhà).

```
192.168.1  .100
└─────────┘ └──┘
 Network     Host
 (24 bits)  (8 bits)
```

Tất cả devices trong cùng subnet `192.168.1.0/24` chia sẻ "khu phố" `192.168.1`. Chúng có thể communicate trực tiếp không cần router. Devices ở subnet khác (ví dụ `192.168.2.x`) cần qua router.

**/24 có bao nhiêu hosts?**

8 bits host = 2^8 = 256 addresses. Trừ 1 network address (192.168.1.0) và 1 broadcast (192.168.1.255) = **254 usable hosts**.

**Các subnet thường gặp:**
- `/32` = 1 host (chính IP đó)
- `/30` = 4 total, 2 usable (point-to-point links)
- `/28` = 16 total, 14 usable
- `/24` = 256 total, 254 usable (1 class C)
- `/16` = 65,536 hosts (VNet trong Azure thường dùng)
- `/8` = 16,777,216 hosts

**Private IP ranges (không route được trên internet):**
- `10.0.0.0/8` - thường dùng cho cloud VNets, VPCs
- `172.16.0.0/12` - Docker default bridge dùng range này
- `192.168.0.0/16` - home/office networks

---

## 4. TCP vs UDP - Khi nào dùng cái nào?

**TCP (Transmission Control Protocol):**

TCP đảm bảo data **đến nơi đầy đủ, đúng thứ tự, không lỗi**.

Cơ chế:
- **Three-way handshake** trước khi gửi data: SYN → SYN-ACK → ACK
- **Acknowledgment**: Mỗi packet phải được xác nhận nhận. Không ACK trong timeout → retransmit
- **Sequencing**: Đánh số thứ tự packets, receiver reorder nếu đến không thứ tự
- **Flow control**: Điều chỉnh tốc độ gửi dựa vào capacity của receiver
- **Congestion control**: Giảm tốc độ nếu mạng tắc nghẽn

**Chi phí:** Overhead từ handshake, ACK, retransmission. Chậm hơn UDP nhưng reliable.

**Dùng TCP khi:** Data phải chính xác 100% - HTTP/HTTPS, SSH, FTP, database connections, email.

**UDP (User Datagram Protocol):**

UDP gửi packet và **không quan tâm đến đích**. "Fire and forget."

Không có handshake, không có ACK, không guarantee order, không retransmit. Nhưng vì vậy:
- Overhead thấp hơn nhiều
- Latency thấp hơn
- Sender không cần chờ receiver

**Dùng UDP khi:**
- **DNS**: Query/response, mất 1 query thì retry ngay
- **Video streaming**: Bị mất 1 frame thì hiển thị frame blur là OK, không cần retransmit frame cũ
- **Online gaming**: 1ms lag quan trọng hơn 1 packet mất
- **VoIP**: Nói chuyện, mất vài milliseconds tiếng OK hơn là delay để đợi retransmit
- **QUIC (HTTP/3)**: UDP nhưng implement reliability ở application layer

---

## 5. DNS - Hệ thống phân giải tên miền

**Tại sao cần DNS?**

IP address như `142.250.185.46` khó nhớ. `google.com` dễ nhớ. DNS là hệ thống "danh bạ" chuyển đổi giữa hai loại.

Nhưng DNS không chỉ là danh bạ đơn giản - nó là hệ thống **phân tán phân cấp** chịu tải hàng tỷ queries mỗi ngày.

**Tại sao phân cấp?**

Nếu có 1 server DNS duy nhất cho cả Internet → single point of failure. Bị DDoS là toàn thế giới mù mạng. Không scale được.

Phân cấp thành:
- **Root servers** (13 clusters, hàng nghìn servers vật lý): Biết ai quản lý .com, .net, .vn...
- **TLD servers** (Top-Level Domain): Biết ai quản lý google.com, amazon.com...
- **Authoritative servers**: Biết chính xác google.com = IP nào, www.google.com = IP nào...
- **Recursive resolvers** (ISP, Google 8.8.8.8, Cloudflare 1.1.1.1): Làm thay bạn, cache kết quả

**Caching và TTL:**

Mỗi DNS record có TTL (Time To Live). Resolver cache kết quả, không cần query authoritative server mỗi lần. Khi TTL hết, query lại.

Ý nghĩa thực tế: Khi bạn thay đổi IP của `api.company.com` (chuyển server mới), cần chờ TTL của record cũ expire ở tất cả resolvers trên thế giới. Nếu TTL là 3600s (1 giờ), có thể mất đến 1 giờ để thay đổi propagate hoàn toàn.

**Best practice khi migrate:** Giảm TTL xuống 300s (5 phút) từ 48 giờ trước → migrate → sau khi verify OK → tăng TTL lên lại.

**DNS trong Kubernetes:**

K8s có DNS server riêng (CoreDNS). Khi pod A muốn connect pod B, nó không query public DNS mà query CoreDNS trong cluster.

CoreDNS biết: `myservice.mynamespace.svc.cluster.local` = ClusterIP của service. Đây là lý do pods có thể dùng tên service thay vì IP (IP có thể thay đổi khi pod restart).

---

## 6. TLS/HTTPS - Tại sao phức tạp hơn chỉ "mã hóa"?

**HTTPS giải quyết 3 vấn đề:**

1. **Confidentiality (Bí mật):** Data được mã hóa, MITM không đọc được
2. **Integrity (Toàn vẹn):** Data không bị sửa trên đường truyền
3. **Authentication (Xác thực):** Đây thực sự là server của google.com, không phải server giả mạo

**Tại sao cần #3 - Authentication?**

Nếu chỉ mã hóa mà không xác thực: Attacker ở giữa (MITM) có thể:
1. Chặn connection của bạn đến google.com
2. Tự tạo connection đến google.com
3. Trao đổi data với cả hai bên, relay qua lại
4. Đọc và sửa tất cả data

Bạn nghĩ bạn đang nói chuyện với google.com, thực ra là nói với attacker.

**Certificate Authority (CA) giải quyết:**

CA = Tổ chức được tin tưởng (Let's Encrypt, DigiCert, Comodo). Browser/OS đã pre-install list của ~100 CA được tin tưởng.

Google phải chứng minh với CA rằng mình thực sự sở hữu `google.com` (qua DNS record hoặc file verification). CA cấp certificate (certificate = "passport" có chữ ký của CA).

Khi bạn kết nối, browser:
1. Nhận certificate từ server
2. Verify chữ ký của CA trên certificate
3. CA này có trong trusted list không?
4. Có → Certificate hợp lệ → Server này thực sự là google.com

MITM không thể giả mạo vì không có private key của CA để tạo certificate giả.

**TLS 1.3 - Tại sao nhanh hơn?**

TLS 1.2: 2 Round Trips (4 messages) trước khi gửi data. Nếu latency 50ms, thêm 100ms chỉ cho handshake.

TLS 1.3: 1 Round Trip. Client gửi luôn "đây là cipher suites tôi hỗ trợ và key share" trong ClientHello đầu tiên. Server có thể reply với certificate và cả ứng dụng data trong 1 response.

Với 0-RTT (Session Resumption): Client đã kết nối trước đó, có "session ticket". Lần sau gửi data luôn trong request đầu tiên.

---

## 7. Load Balancer - Tại sao cần nhiều servers?

**Vấn đề với 1 server:**

1 server vật lý có giới hạn - 32 CPU cores, 256GB RAM. Không thể handle 1 triệu concurrent users chỉ bằng thêm RAM/CPU vô hạn.

Ngoài ra: 1 server = single point of failure. Server down = toàn bộ users không access được.

**Giải pháp: Scale Horizontally (Scale Out)**

Thêm nhiều servers nhỏ hơn chạy cùng app. Load balancer đứng trước, phân phối traffic.

Benefits:
- **Capacity:** 10 servers × 100 users/server = 1000 users
- **High Availability:** 1 server down, 9 server còn lại handle traffic
- **Rolling Deployments:** Update từng server, không cần downtime

**Các thuật toán phân phối:**

*Round Robin:* Lần lượt A→B→C→A→B→C. Đơn giản, fair. Nhưng không quan tâm server nào đang bận hơn.

*Least Connections:* Gửi request mới đến server đang có ít connections nhất. Tốt khi requests có duration khác nhau (1 request có thể mất 5s, request khác mất 50ms).

*Weighted Round Robin:* Server mạnh hơn nhận nhiều request hơn. Server A có 8 cores, server B có 4 cores → A nhận 2x requests.

*IP Hash:* Hash IP của client, luôn gửi đến cùng 1 server. Cần thiết cho "stateful" apps giữ session data trong memory (không nên dùng pattern này - stateless better).

**Health Checks:**

Load balancer liên tục kiểm tra các backend servers: HTTP GET /health, nếu fail → remove khỏi pool, không gửi traffic nữa. Khi recover → add lại.

---

## 8. Firewall - Bảo vệ như thế nào?

**Firewall** = "bảo vệ cửa" quyết định traffic nào được vào/ra.

**Packet Filtering (Stateless):**

Quy tắc đơn giản: "Cho phép traffic từ IP X, port Y vào", "Chặn tất cả traffic vào port 22 trừ IP Z".

Mỗi packet được kiểm tra độc lập, không có "context" của connection.

**Stateful Firewall:**

Track connections. Biết rằng packet này thuộc về 1 established TCP connection → cho qua mà không cần rule explicit.

Ví dụ: Bạn tạo rule "allow outbound HTTP". Khi bạn send HTTP request ra ngoài, firewall biết response packet thuộc về connection đó → tự động allow response về, không cần rule riêng.

**Network Security Groups (NSG) trong Azure:**

Azure NSG là stateful firewall cho VNet. Mỗi subnet hoặc NIC có thể attach một NSG.

Rule có priority (thấp hơn = ưu tiên hơn): Priority 100 được check trước 200.

Default rules Azure tạo sẵn:
- Allow VNet inbound (VMs trong cùng VNet communicate)
- Allow Azure Load Balancer inbound (health probes)
- Deny All inbound (chặn mọi thứ khác)

**Tại sao cần Defense in Depth?**

Không nên chỉ có 1 lớp firewall. Ví dụ:
- **Layer 1:** Azure Firewall / WAF ở edge - block IPs, country filtering, OWASP rules
- **Layer 2:** NSG ở subnet level - chỉ cho phép ports cần thiết
- **Layer 3:** NSG ở NIC level - control individual VM
- **Layer 4:** OS-level firewall (iptables/ufw) - last line of defense

Nếu attacker bypass layer 1, vẫn còn 3 lớp nữa.

---

## 9. VPN vs Reverse Proxy vs Forward Proxy - Sự khác nhau

**Forward Proxy:**

Client → **Forward Proxy** → Internet

Client biết về proxy, gửi request đến proxy, proxy forward đến destination. Internet thấy IP của proxy, không thấy IP client.

Use cases:
- Công ty block Internet, cho phép qua proxy (kiểm soát, logging)
- VPN (loại này là forward proxy)
- Anonymity (Tor, commercial VPNs)

**Reverse Proxy:**

Client → **Reverse Proxy** → Backend servers

Client không biết (và không cần biết) về backend servers phía sau. Client nghĩ mình đang nói với `api.company.com` - thực ra đang nói với Nginx, Nginx mới forward đến actual API servers.

Use cases:
- Load balancing (phân phối traffic)
- SSL termination (decrypt HTTPS một lần, forward HTTP nội bộ)
- Caching
- Compression
- API Gateway

**VPN (Virtual Private Network):**

Tạo "đường hầm mã hóa" (encrypted tunnel) qua Internet public. Traffic trong tunnel được mã hóa, ISP không đọc được.

Site-to-Site VPN: Kết nối hai mạng riêng (on-premise office ↔ Azure VNet). Traffic đi qua Internet nhưng trong tunnel mã hóa.

Point-to-Site VPN: Developer connect laptop vào Azure VNet private resources khi làm việc từ xa.

**Tại sao Azure ExpressRoute tốt hơn VPN?**

VPN: Đi qua Internet public, bandwidth và latency không guaranteed, có thể bị congestion.

ExpressRoute: Dedicated private connection từ data center của bạn đến Azure data center, KHÔNG qua Internet. Guaranteed bandwidth, lower latency, more security.

Nhưng ExpressRoute tốn kém hơn nhiều (vài nghìn USD/tháng). Chỉ enterprise cần high-bandwidth, low-latency connection mới dùng.

---

## 10. Container Networking trong Kubernetes

**Kubernetes networking giải quyết vấn đề phức tạp:**

Có thể có hàng nghìn pods, trên hàng chục nodes, pods có thể được tạo/xóa bất kỳ lúc nào. Làm sao chúng communicate được?

**K8s Networking Rules (flat model):**

1. Mỗi Pod có IP riêng
2. Pods có thể communicate với nhau qua Pod IP **không cần NAT** (dù ở nodes khác nhau)
3. Nodes có thể communicate với Pods không cần NAT

Đây gọi là "flat network" - không có NAT phức tạp giữa pods.

**CNI (Container Network Interface) plugins thực hiện điều này:**

Calico, Flannel, Cilium là các plugins giúp implement K8s networking model. Mỗi plugin có cách khác nhau nhưng cùng kết quả.

**Service - Stable Endpoint:**

Pod IPs thay đổi khi pod restart (IP mới được assign). App không thể hardcode Pod IP.

Service = virtual IP (ClusterIP) stable không đổi. Kube-proxy tạo iptables/IPVS rules để route traffic từ ClusterIP đến Pod IPs hiện tại.

Khi Pod restart với IP mới, Service tự update backend. Client vẫn dùng cùng Service IP.

**DNS trong K8s:**

CoreDNS (DNS server của K8s) biết tất cả Services và resolve chúng:
`myservice.mynamespace.svc.cluster.local` → ClusterIP của service

Pods trong cùng namespace chỉ cần `myservice` (không cần full name). Pods ở namespace khác cần `myservice.mynamespace`.
