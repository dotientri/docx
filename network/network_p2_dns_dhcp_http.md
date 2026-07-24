# ---
markmap:
  title: "Networking — DNS, DHCP & HTTP/HTTPS"
  collapse: false
# ---

# 🌐 NETWORK PHẦN 2: DNS, DHCP & HTTP/HTTPS

## Theory
- DNS translates human-friendly names into IPs; DHCP automates IP allocation; HTTP/HTTPS are the core application-layer protocols for web communication and must be secured with TLS.

## Practice
- Use `dig` to debug DNS, follow DORA for DHCP troubleshooting, and use `curl -v` and TLS tools to verify HTTPS certificate chains and headers.

## 1. DNS - Domain Name System

### 1.1 DNS Là Gì?
- **"Danh bạ điện thoại của Internet"**
- Chuyển đổi tên miền (`google.com`) → IP (`142.250.185.46`)
- Không có DNS → phải nhớ IP mọi website

### 1.2 Kiến Trúc DNS - Phân Cấp (Hierarchical)
#### Root DNS Servers
- 13 clusters toàn cầu (`a.root-servers.net` → `m.root-servers.net`)
- Biết ai quản lý `.com`, `.net`, `.vn`...

#### TLD Servers (Top-Level Domain)
- `.com`, `.org`, `.net`, `.vn`
- Biết ai quản lý `google.com`, `amazon.com`...

#### Authoritative Name Servers
- Biết chính xác `www.google.com` = IP nào

#### Recursive Resolvers
- ISP, Google `8.8.8.8`, Cloudflare `1.1.1.1`
- Làm thay bạn toàn bộ quá trình query, cache kết quả

### 1.3 DNS Resolution - Từng Bước
#### Bước 1: Check Local Cache
- Browser cache → OS cache (`/etc/hosts`)

#### Bước 2: Query Recursive Resolver
- OS gửi query đến DNS resolver (router hoặc `8.8.8.8`)

#### Bước 3: Resolver Query Root Server
- "Ai quản lý `.com`?" → Root trả lời TLD server address

#### Bước 4: Resolver Query TLD Server
- "Ai quản lý `google.com`?" → TLD trả lời authoritative NS

#### Bước 5: Resolver Query Authoritative Server
- "`www.google.com` có IP gì?" → `142.250.185.46`

#### Bước 6: Trả Về Kết Quả
- Resolver cache lại (theo TTL) → trả về cho browser

#### Bước 7: Browser Kết Nối
- TCP connect đến `142.250.185.46:443`

### 1.4 Debug DNS
```bash
# Trace từng bước resolution
dig +trace google.com

# Query DNS thông thường
dig google.com
dig A google.com          # IPv4
dig AAAA google.com       # IPv6
dig MX google.com         # Mail servers
dig NS google.com         # Name servers
dig TXT google.com        # SPF, DKIM

# Query server cụ thể
dig @8.8.8.8 google.com
dig @1.1.1.1 google.com

# Reverse DNS (IP → Domain)
dig -x 8.8.8.8
```

### 1.5 DNS Record Types
| Record | Mô Tả | Ví Dụ |
|--------|-------|-------|
| **A** | IPv4 address | `google.com → 142.250.185.46` |
| **AAAA** | IPv6 address | `google.com → 2404:6800:...` |
| **CNAME** | Alias | `www.company.com → company.com` |
| **MX** | Mail exchanger | `company.com → mail.google.com` |
| **NS** | Name server | `company.com → ns1.cloudflare.com` |
| **TXT** | Text data | SPF, DKIM, domain verification |
| **PTR** | Reverse lookup | IP → domain |
| **SOA** | Zone info | Serial number, refresh |
| **SRV** | Service record | Service endpoint + port |
| **CAA** | CA Authorization | Cho phép CA nào issue cert |

### 1.6 Email DNS Records
#### SPF (Sender Policy Framework)
```bash
dig TXT company.com
# "v=spf1 include:_spf.google.com ~all"
```
- Chống email spoofing

#### DKIM (DomainKeys Identified Mail)
```bash
dig TXT google._domainkey.company.com
```
- Chữ ký số cho email

#### DMARC
```bash
dig TXT _dmarc.company.com
# "v=DMARC1; p=reject; rua=mailto:dmarc@company.com"
```

### 1.7 DNS TTL & Caching
#### TTL Thấp (60-300s)
- Thay đổi DNS propagate **nhanh**
- Nhưng query nhiều hơn → tốn bandwidth

#### TTL Cao (3600-86400s)
- Ít query, **nhanh hơn**
- Thay đổi phải chờ lâu

#### Best Practice Khi Migrate
1. Giảm TTL xuống 300s — **48 giờ trước**
2. Thực hiện migrate
3. Verify hoạt động
4. Tăng TTL lại

```bash
# Xem TTL còn lại
dig google.com | grep -A1 "ANSWER SECTION"
# google.com.  299  IN  A  142.250.185.46
#              └── 299 giây TTL còn lại
```

### 1.8 /etc/hosts - Local DNS Override
```bash
cat /etc/hosts
# 192.168.1.100  db.internal db
# 192.168.1.200  api.dev.local

# Thứ tự resolution:
# /etc/hosts trước → DNS sau
```

### 1.9 DNS Server Setup
#### Dnsmasq (Lightweight)
```bash
sudo apt install dnsmasq
# Config: /etc/dnsmasq.conf
# server=8.8.8.8
# cache-size=1000
# address=/api.internal/10.0.1.10
```

#### BIND9 (Full-featured)
```bash
sudo apt install bind9 bind9utils
# Zone file: /etc/bind/zones/db.company.com
```

## 2. DHCP - Dynamic Host Configuration Protocol

### 2.1 DHCP Là Gì?
- Tự động cấp phát cho thiết bị:
  - **IP Address**
  - **Subnet Mask**
  - **Default Gateway**
  - **DNS Servers**
  - **Lease Time**

### 2.2 DORA Process
```
Client              DHCP Server
  │── DISCOVER ────►│  "Ai là DHCP? Tôi cần IP"
  │◄── OFFER ───────│  "Offer 192.168.1.50"
  │── REQUEST ─────►│  "Tôi chấp nhận 192.168.1.50"
  │◄── ACK ─────────│  "OK! Lease 24h"
```

#### D - Discover
- Client broadcast: "Ai là DHCP server?"

#### O - Offer
- DHCP server offer một IP từ pool

#### R - Request
- Client chấp nhận IP được offer

#### A - Acknowledge
- Server xác nhận, gán lease time

### 2.3 DHCP Server Setup
```bash
sudo apt install isc-dhcp-server

# Config: /etc/dhcp/dhcpd.conf
# subnet 192.168.1.0 netmask 255.255.255.0 {
#   range 192.168.1.100 192.168.1.200;
#   option routers 192.168.1.1;
#   option domain-name-servers 8.8.8.8;
# }
```

### 2.4 Static Assignment (IP Cố Định Theo MAC)
```
host web-server {
  hardware ethernet aa:bb:cc:dd:ee:ff;
  fixed-address 192.168.1.10;
}
```
- Đảm bảo server luôn nhận cùng IP

## 3. HTTP/HTTPS - Giao Thức Web

### 3.1 HTTP Request Structure
```
┌────────────────────────────────────────┐
│ GET /api/users?page=1 HTTP/1.1        │ ← Request Line
│ Host: api.company.com                 │
│ Authorization: Bearer eyJhbGci...     │ ← Headers
│ Content-Type: application/json        │
│                                       │
│ {"query": "active users"}             │ ← Body (optional)
└────────────────────────────────────────┘
```

### 3.2 HTTP Response Structure
```
┌────────────────────────────────────────┐
│ HTTP/1.1 200 OK                       │ ← Status Line
│ Content-Type: application/json        │
│ Cache-Control: max-age=3600           │ ← Headers
│                                       │
│ {"users": [...], "total": 100}        │ ← Body
└────────────────────────────────────────┘
```

### 3.3 HTTP Methods
| Method | Dùng Cho | Idempotent | Body |
|--------|---------|-----------|------|
| **GET** | Lấy data | ✓ | Không |
| **POST** | Tạo mới | ✗ | Có |
| **PUT** | Update toàn bộ | ✓ | Có |
| **PATCH** | Update 1 phần | ✗ | Có |
| **DELETE** | Xóa | ✓ | Không |
| **HEAD** | GET không body | ✓ | Không |
| **OPTIONS** | Methods cho phép | ✓ | Không |

- **Idempotent** = gọi nhiều lần, kết quả giống gọi 1 lần

### 3.4 HTTP Status Codes
#### 1xx - Informational
- `100 Continue` — tiếp tục gửi body
- `101 Switching Protocols` — upgrade (WebSocket)

#### 2xx - Success
- `200 OK` — thành công
- `201 Created` — tạo thành công (POST)
- `204 No Content` — thành công, không body (DELETE)

#### 3xx - Redirection
- `301 Moved Permanently` — redirect vĩnh viễn
- `302 Found` — redirect tạm
- `304 Not Modified` — dùng cache

#### 4xx - Client Errors
- `400 Bad Request` — cú pháp sai
- `401 Unauthorized` — chưa login
- `403 Forbidden` — không có quyền
- `404 Not Found` — resource không tồn tại
- `429 Too Many Requests` — rate limiting

#### 5xx - Server Errors
- `500 Internal Server Error` — lỗi server
- `502 Bad Gateway` — upstream down (Nginx → App)
- `503 Service Unavailable` — quá tải / maintenance
- `504 Gateway Timeout` — upstream không reply kịp

### 3.5 HTTP Versions
#### HTTP/1.0 (1996)
- 1 request = 1 TCP connection → **Rất chậm**

#### HTTP/1.1 (1997) - Vẫn Phổ Biến
- **Keep-Alive** — dùng lại TCP connection
- **Pipelining** — nhưng có Head-of-Line blocking
- Browsers mở 6 connections/domain để workaround

#### HTTP/2 (2015) - Phổ Biến Hiện Nay
- **Multiplexing** — nhiều requests song song trên 1 TCP
- **Header compression** (HPACK) — giảm 30-90%
- **Server Push** — server chủ động push resources
- **Binary Protocol** — không phải text

#### HTTP/3 (2022) - Mới Nhất
- Chạy trên **QUIC** (UDP, không phải TCP)
- Giải quyết TCP Head-of-Line blocking
- **0-RTT** connection resumption
- Tốt hơn trên mạng mobile/lossy

```bash
# Kiểm tra HTTP version
curl -I --http2 https://google.com | head -5
```

## 4. HTTPS & TLS/SSL

### 4.1 TLS 1.3 Handshake
```
Client                        Server
  │── ClientHello ────────────►│
  │   (TLS version, ciphers,  │
  │    key share)              │
  │◄── ServerHello ────────────│
  │◄── Certificate ────────────│
  │◄── Finished ───────────────│
  │── Finished ────────────────►│
  │   ← Application Data →    │
```
- TLS 1.3: **1 RTT** cho handshake, **0 RTT** cho resume
- TLS 1.2: 2 RTT → chậm hơn

### 4.2 Certificate Chain
```
Root CA (Trust Store)
  └── Intermediate CA (DigiCert, Let's Encrypt)
        └── Server Certificate (company.com)
```
#### Quy Trình Verify
1. Lấy certificate từ server
2. Verify signature Intermediate CA
3. Verify Intermediate CA được Root CA sign
4. Root CA trong trust store? → **TRUSTED!**

### 4.3 Let's Encrypt (Free SSL)
```bash
# Cài certbot
sudo apt install certbot python3-certbot-nginx

# Lấy cert
sudo certbot --nginx -d company.com -d www.company.com

# Wildcard cert
sudo certbot certonly --dns-cloudflare \
  -d "*.company.com" -d company.com

# Auto-renew
sudo certbot renew --dry-run
```

### 4.4 Self-Signed Cert (Dev/Internal)
```bash
# Tạo CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt

# Tạo server cert
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr

# Sign với CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt
```

### 4.5 Nginx HTTPS Configuration
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate     /path/fullchain.pem;
    ssl_certificate_key /path/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
}
```

## 5. HTTP Caching

### 5.1 Cache-Control Headers
| Directive | Ý Nghĩa |
|-----------|---------|
| `no-store` | Không cache gì hết |
| `no-cache` | Phải revalidate trước khi dùng |
| `private` | Chỉ browser cache, không CDN |
| `public` | CDN + browser đều cache |
| `max-age=3600` | Cache tối đa 1 giờ |
| `s-maxage=86400` | CDN cache tối đa 1 ngày |
| `must-revalidate` | Expire phải revalidate |

### 5.2 ETag & Conditional Requests
1. Server gửi: `ETag: "abc123"`
2. Client request lại: `If-None-Match: "abc123"`
3. Server: chưa đổi → **304 Not Modified** (không gửi body)
4. Client dùng cache → **tiết kiệm bandwidth**

## 6. Load Balancing

### 6.1 Thuật Toán Load Balancing
#### Round Robin
- A → B → C → A → B → C
- Đơn giản, mặc định

#### Weighted Round Robin
- Server mạnh hơn nhận nhiều request hơn
- A(weight=3): nhận 3x so với B(weight=1)

#### Least Connections
- Gửi đến server ít connections nhất
- Tốt khi requests có duration khác nhau

#### IP Hash
- Hash IP client → luôn vào cùng 1 server
- Sticky sessions cho stateful apps

#### Least Response Time
- Gửi đến server response nhanh nhất

### 6.2 Nginx Load Balancer Config
```nginx
upstream backend {
    server 10.0.1.10:8080;
    server 10.0.1.11:8080;
    server 10.0.1.12:8080;
    server 10.0.1.13:8080 backup;
    keepalive 32;
}

server {
    location / {
        proxy_pass http://backend;
        proxy_next_upstream error timeout http_502;
    }
}
```

## 7. WebSocket & Server-Sent Events

### 7.1 WebSocket
- **Bidirectional** persistent connection
- Upgrade từ HTTP: `Upgrade: websocket`
- Use case: Chat, real-time dashboards

### 7.2 Server-Sent Events (SSE)
- **One-way** streaming: server → client
- Simpler than WebSocket
- Use case: Live feeds, notifications

### 7.3 Nginx Config Cho WebSocket/SSE
```nginx
location /ws/ {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}

location /events {
    proxy_pass http://backend;
    proxy_buffering off;  # Quan trọng cho SSE!
}
```
