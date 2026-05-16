# 🌐 NETWORK TOÀN TẬP - PHẦN 2: DNS, DHCP & HTTP/HTTPS

---

## 1. DNS - Domain Name System

### 1.1 DNS Là Gì?

DNS là **"danh bạ điện thoại của Internet"** — chuyển đổi tên miền (`google.com`) thành địa chỉ IP (`142.250.185.46`).

Không có DNS, bạn phải nhớ IP của mọi website.

### 1.2 Kiến Trúc DNS - Hierarchical

```
                    Root DNS Servers (.)
                    13 clusters toàn cầu
                    a.root-servers.net → m.root-servers.net
                           │
                    ┌──────┴──────┐
                    │             │
               .com TLD       .org TLD     ← Top-Level Domain Servers
               .net TLD       .vn TLD
                    │
               google.com NS            ← Authoritative Name Server
               (ns1.google.com)
                    │
               www.google.com → 142.250.185.46   ← A Record
```

### 1.3 DNS Resolution Process - Từng Bước

```
Browser muốn truy cập google.com:

1. CHECK LOCAL CACHE
   Browser cache → Không có
   OS cache (/etc/hosts) → Không có

2. QUERY RECURSIVE RESOLVER
   OS gửi query đến DNS resolver (thường là router hoặc ISP)
   Ví dụ: 192.168.1.1 hoặc 8.8.8.8 (Google DNS)

3. RESOLVER QUERY ROOT SERVER
   Resolver: "Ai quản lý .com?"
   Root: "Hỏi 192.5.6.30 (a.gtld-servers.net)"

4. RESOLVER QUERY TLD SERVER
   Resolver: "Ai quản lý google.com?"
   TLD (.com): "Hỏi ns1.google.com (216.239.32.10)"

5. RESOLVER QUERY AUTHORITATIVE SERVER
   Resolver: "www.google.com có IP gì?"
   ns1.google.com: "142.250.185.46"
   
6. RESOLVER TRẢ VỀ KẾT QUẢ
   Resolver trả về IP cho OS, cache lại (theo TTL)
   OS trả về cho browser
   
7. BROWSER KẾT NỐI
   Browser connect TCP đến 142.250.185.46:443
```

```bash
# Debug DNS step by step
dig +trace google.com
# → Theo dõi từng bước resolution từ root servers

# Query DNS thông thường
dig google.com
dig A google.com          # IPv4
dig AAAA google.com       # IPv6
dig MX google.com         # Mail servers
dig NS google.com         # Name servers
dig TXT google.com        # Text records (SPF, DKIM, etc.)
dig CNAME www.google.com  # Canonical name

# Query server cụ thể
dig @8.8.8.8 google.com       # Dùng Google DNS
dig @1.1.1.1 google.com       # Dùng Cloudflare DNS
dig @192.168.1.1 google.com   # Dùng local DNS

# Reverse DNS lookup (IP → Domain)
dig -x 8.8.8.8
nslookup 8.8.8.8

# nslookup (đơn giản hơn)
nslookup google.com
nslookup google.com 8.8.8.8
```

### 1.4 DNS Record Types

| Record | Mô Tả | Ví Dụ |
|--------|-------|-------|
| **A** | IPv4 address | `google.com → 142.250.185.46` |
| **AAAA** | IPv6 address | `google.com → 2404:6800:4003:c05::64` |
| **CNAME** | Canonical name (alias) | `www.company.com → company.com` |
| **MX** | Mail exchanger | `@company.com → mail.google.com` |
| **NS** | Name server | `company.com → ns1.cloudflare.com` |
| **TXT** | Text data | SPF, DKIM, domain verification |
| **PTR** | Reverse lookup | `46.185.250.142.in-addr.arpa → google.com` |
| **SOA** | Start of Authority | Zone info, serial number |
| **SRV** | Service record | `_sip._tcp.company.com → sip.company.com:5060` |
| **CAA** | Certificate Authority | Chỉ định CA nào được issue cert |

```bash
# SPF Record (chống email spoofing)
dig TXT company.com
# "v=spf1 include:_spf.google.com ~all"

# DKIM Record
dig TXT google._domainkey.company.com
# "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3..."

# DMARC Record
dig TXT _dmarc.company.com
# "v=DMARC1; p=reject; rua=mailto:dmarc@company.com"
```

### 1.5 DNS TTL & Caching

```
TTL (Time To Live): Bao nhiêu giây bản ghi này được cache

TTL thấp (60-300s): 
  + Thay đổi DNS propagate nhanh
  - Query nhiều hơn → tốn băng thông

TTL cao (3600-86400s):
  + Ít query, nhanh hơn
  - Khi thay đổi, phải chờ TTL expire ở tất cả resolvers
```

```bash
# Xem TTL còn lại
dig google.com | grep -A1 "ANSWER SECTION"
# google.com.   299   IN  A  142.250.185.46
#                └── 299 seconds TTL còn lại

# Best practice khi chuẩn bị migrate:
# 1. Giảm TTL xuống 300s (5 phút) 48 giờ trước
# 2. Migrate
# 3. Verify hoạt động
# 4. Tăng TTL lại
```

### 1.6 /etc/hosts - Local DNS Override

```bash
cat /etc/hosts
# 127.0.0.1    localhost
# 127.0.1.1    my-machine
# 
# # Custom entries
# 192.168.1.100   db.internal db
# 192.168.1.101   redis.internal redis
# 192.168.1.200   api.dev.local

# Thứ tự resolution (Ubuntu):
cat /etc/nsswitch.conf | grep hosts
# hosts: files mdns4_minimal [NOTFOUND=return] dns
#         └─── /etc/hosts trước → DNS sau
```

### 1.7 DNS Caching Servers Thực Tế

```bash
# ===== DNSMASQ (Lightweight - phổ biến cho dev/home lab) =====
sudo apt install dnsmasq

cat > /etc/dnsmasq.conf << 'EOF'
# DNS server phía sau
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1

# Cache size
cache-size=1000

# Local domain
domain=company.internal
local=/company.internal/

# Custom records
address=/api.company.internal/10.0.1.10
address=/db.company.internal/10.0.2.10

# Log queries
log-queries
log-facility=/var/log/dnsmasq.log
EOF

sudo systemctl restart dnsmasq

# ===== BIND9 (Full-featured DNS Server) =====
sudo apt install bind9 bind9utils

# Zone file (/etc/bind/zones/company.com)
cat > /etc/bind/zones/db.company.com << 'EOF'
$TTL 3600
@    IN SOA  ns1.company.com. admin.company.com. (
             2024011501  ; Serial
             3600        ; Refresh
             900         ; Retry
             604800      ; Expire
             300 )       ; Negative TTL

; Name servers
@    IN NS   ns1.company.com.
@    IN NS   ns2.company.com.

; A records
@    IN A    203.0.113.10
www  IN A    203.0.113.10
api  IN A    203.0.113.20
db   IN A    10.0.3.10

; Mail
@    IN MX 10 mail.company.com.
mail IN A    203.0.113.30

; CNAME
docs IN CNAME  www.company.com.
EOF
```

---

## 2. DHCP - Dynamic Host Configuration Protocol

### 2.1 DHCP Là Gì?

DHCP tự động cấp phát:
- **IP Address**
- **Subnet Mask**
- **Default Gateway**
- **DNS Servers**
- **Lease Time** (bao lâu thì IP này expire)

### 2.2 DORA Process

```
Client                DHCP Server
  │                       │
  │── DISCOVER ──────────►│  Broadcast: "Ai là DHCP server? Tôi cần IP"
  │                       │
  │◄── OFFER ─────────────│  "Tôi offer cho bạn 192.168.1.50"
  │                       │
  │── REQUEST ───────────►│  "Tôi chấp nhận 192.168.1.50"
  │                       │
  │◄── ACK ───────────────│  "OK! IP của bạn là 192.168.1.50, lease 24h"
```

### 2.3 DHCP Server Setup

```bash
# ===== ISC DHCP Server =====
sudo apt install isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf << 'EOF'
default-lease-time 86400;      # 24 giờ
max-lease-time 604800;         # 7 ngày

# Subnet declaration
subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.100 192.168.1.200;   # Pool
  option routers 192.168.1.1;          # Default gateway
  option domain-name-servers 8.8.8.8, 1.1.1.1;
  option domain-name "company.local";
  option broadcast-address 192.168.1.255;
}

# Static assignment (bind IP cố định theo MAC)
host web-server {
  hardware ethernet aa:bb:cc:dd:ee:ff;
  fixed-address 192.168.1.10;
  option host-name "web-server";
}

host db-server {
  hardware ethernet 11:22:33:44:55:66;
  fixed-address 192.168.1.20;
}
EOF

# Chỉ định interface
echo 'INTERFACESv4="eth0"' > /etc/default/isc-dhcp-server

sudo systemctl start isc-dhcp-server

# Xem leases đã cấp
cat /var/lib/dhcp/dhcpd.leases
```

---

## 3. HTTP/HTTPS - Giao Thức Web

### 3.1 HTTP Request/Response

```
HTTP Request:
┌────────────────────────────────────────────┐
│ GET /api/users?page=1 HTTP/1.1             │  ← Request Line
│ Host: api.company.com                      │
│ Authorization: Bearer eyJhbGci...          │  ← Headers
│ Content-Type: application/json             │
│ Accept: application/json                   │
│ User-Agent: Mozilla/5.0...                 │
│                                            │
│ (empty line - header separator)            │
│                                            │
│ {"query": "active users"}                  │  ← Body (optional)
└────────────────────────────────────────────┘

HTTP Response:
┌────────────────────────────────────────────┐
│ HTTP/1.1 200 OK                            │  ← Status Line
│ Content-Type: application/json             │
│ Content-Length: 1234                       │  ← Headers
│ Cache-Control: max-age=3600                │
│ X-Request-Id: abc-123-def                  │
│                                            │
│ {"users": [...], "total": 100}             │  ← Body
└────────────────────────────────────────────┘
```

### 3.2 HTTP Methods

| Method | Dùng Cho | Idempotent | Body |
|--------|---------|-----------|------|
| GET | Lấy data | ✓ | Không |
| POST | Tạo mới | ✗ | Có |
| PUT | Update toàn bộ | ✓ | Có |
| PATCH | Update 1 phần | ✗ | Có |
| DELETE | Xóa | ✓ | Không |
| HEAD | Như GET nhưng không có body | ✓ | Không |
| OPTIONS | Hỏi methods được phép | ✓ | Không |

**Idempotent:** Gọi nhiều lần = kết quả giống gọi 1 lần

### 3.3 HTTP Status Codes

```
1xx - Informational
  100 Continue              - Tiếp tục gửi body
  101 Switching Protocols   - Upgrade (e.g., WebSocket)

2xx - Success
  200 OK                    - Thành công
  201 Created               - Tạo thành công (POST)
  204 No Content            - Thành công, không có body (DELETE)
  206 Partial Content       - Range request (video streaming)

3xx - Redirection
  301 Moved Permanently     - Redirect vĩnh viễn (update bookmarks)
  302 Found                 - Redirect tạm thời
  304 Not Modified          - Client dùng cache đi (Conditional GET)
  307 Temporary Redirect    - Redirect tạm, giữ nguyên method
  308 Permanent Redirect    - Redirect vĩnh viễn, giữ nguyên method

4xx - Client Errors
  400 Bad Request           - Cú pháp request sai
  401 Unauthorized          - Chưa authenticate (cần login)
  403 Forbidden             - Đã authenticate nhưng không có quyền
  404 Not Found             - Resource không tồn tại
  405 Method Not Allowed    - Method không được phép
  409 Conflict              - Conflict với state hiện tại
  422 Unprocessable Entity  - Validation failed
  429 Too Many Requests     - Rate limiting

5xx - Server Errors
  500 Internal Server Error - Lỗi server không xác định
  502 Bad Gateway           - Upstream server lỗi (Nginx → App down)
  503 Service Unavailable   - Server quá tải hoặc maintenance
  504 Gateway Timeout       - Upstream không reply đúng thời gian
```

### 3.4 HTTP Versions Evolution

#### HTTP/1.0 (1996)
- 1 request = 1 TCP connection → Rất chậm
- Không persistent connections

#### HTTP/1.1 (1997) - Vẫn phổ biến
- **Persistent connections** (Keep-Alive) - Dùng lại TCP connection
- **Pipelining** (gửi nhiều requests không chờ) - Nhưng có Head-of-Line blocking
- **Chunked Transfer Encoding**
- **Virtual hosting** (nhiều domain trên 1 IP)

```bash
# HTTP/1.1 Head-of-Line blocking:
# Request A (chậm) → Request B → Request C
# B và C phải chờ A dù A chậm
# → Browsers mở 6 connections/domain để workaround
```

#### HTTP/2 (2015) - Phổ biến hiện nay
- **Multiplexing:** Nhiều requests song song trên 1 TCP connection
- **Header compression** (HPACK) - Giảm 30-90% header size
- **Server Push** - Server chủ động push resources
- **Binary Protocol** (không phải text như HTTP/1.1)
- **Stream Prioritization**

```bash
# Kiểm tra HTTP version
curl -I --http2 https://google.com | head -5
# HTTP/2 200

curl -I --http1.1 https://google.com | head -5
# HTTP/1.1 200 OK

# Xem bằng OpenSSL
openssl s_client -connect google.com:443 -alpn h2 </dev/null 2>&1 | grep ALPN
# ALPN protocol: h2   ← HTTP/2
```

#### HTTP/3 (2022) - Mới nhất
- Chạy trên **QUIC** (UDP, không phải TCP)
- Giải quyết TCP Head-of-Line blocking
- **0-RTT connection resumption** (kết nối lại nhanh hơn)
- Built-in encryption (TLS 1.3)
- Tốt hơn trên mạng lossy (mobile, satellite)

---

## 4. HTTPS & TLS/SSL

### 4.1 TLS Handshake (TLS 1.3)

```
Client                          Server
  │                               │
  │──── ClientHello ─────────────►│
  │     - TLS version             │
  │     - Cipher suites           │
  │     - Key share               │
  │                               │
  │◄─── ServerHello ──────────────│
  │◄─── Certificate ──────────────│  ← Server's public cert
  │◄─── CertificateVerify ────────│
  │◄─── Finished ─────────────────│
  │                               │
  │──── Finished ────────────────►│
  │                               │
  │  ←── Application Data ──────► │  (TLS 1.3: chỉ 1 RTT!)
```

TLS 1.3 vs TLS 1.2:
- TLS 1.3: **1 RTT** (Round Trip Time) cho handshake mới, **0 RTT** cho resume
- TLS 1.2: 2 RTT → chậm hơn
- TLS 1.3 loại bỏ các cipher suite yếu, an toàn hơn nhiều

### 4.2 Certificates - Chứng Chỉ Số

```
Certificate chain:
Root CA (Mozilla/Browser Trust Store)
   └── Intermediate CA (DigiCert, Let's Encrypt)
          └── End-entity Certificate (company.com)

Khi browser xác minh google.com:
1. Lấy certificate từ server
2. Xác minh signature của Intermediate CA
3. Xác minh Intermediate CA được Root CA sign
4. Root CA trong trust store của browser? → TRUSTED!
```

```bash
# ===== LET'S ENCRYPT (Free SSL) =====
# Cài certbot
sudo apt install certbot python3-certbot-nginx

# Lấy cert cho domain
sudo certbot --nginx -d company.com -d www.company.com

# Wildcard cert (cần DNS challenge)
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d "*.company.com" -d company.com

# Auto-renew (cron job tự động)
sudo certbot renew --dry-run

# Xem cert info
sudo certbot certificates

openssl x509 -in /etc/letsencrypt/live/company.com/cert.pem \
  -noout -text | grep -E "Not After|Subject|Issuer"

# ===== TỰ KÝ CERT (Internal/Dev) =====
# Tạo root CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/C=VN/ST=HCM/O=Company/CN=Company Internal CA"

# Tạo server cert
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/C=VN/ST=HCM/O=Company/CN=api.company.internal"

# Sign với CA
openssl x509 -req -days 365 -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -extensions v3_req \
  -extfile <(cat <<EOF
[v3_req]
subjectAltName = DNS:api.company.internal, DNS:*.company.internal
EOF
)
```

### 4.3 Nginx HTTPS Configuration

```nginx
# /etc/nginx/sites-available/company.com

server {
    listen 80;
    server_name company.com www.company.com;
    
    # Redirect tất cả HTTP → HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name company.com www.company.com;
    
    # SSL Certificates
    ssl_certificate     /etc/letsencrypt/live/company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/company.com/privkey.pem;
    
    # SSL Configuration (Mozilla Intermediate)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # SSL Session (tăng performance)
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;  # 10MB cache
    ssl_session_tickets off;
    
    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    
    # OCSP Stapling (tăng performance certificate validation)
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/company.com/chain.pem;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'";
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 5. HTTP Caching

```
Cache-Control Headers:
  no-store              → Không cache gì hết
  no-cache              → Phải revalidate với server trước khi dùng
  private               → Chỉ browser cache, không CDN
  public                → CDN và browser đều cache được
  max-age=3600          → Cache tối đa 3600 giây (1 giờ)
  s-maxage=86400        → CDN cache tối đa 86400 giây (1 ngày)
  must-revalidate       → Khi expire phải revalidate
  stale-while-revalidate=60  → Dùng stale trong 60s khi đang revalidate

ETag và Last-Modified (Conditional Requests):
  1. Client lấy resource, server gửi: ETag: "abc123" hoặc Last-Modified: Fri, 01 Jan 2024
  2. Client request lại: If-None-Match: "abc123" hoặc If-Modified-Since: Fri, 01 Jan 2024
  3. Server: Resource chưa đổi → 304 Not Modified (không gửi body!)
  4. Client dùng bản đã cache → Tiết kiệm bandwidth
```

---

## 6. Load Balancing

### 6.1 Các Thuật Toán Load Balancing

```
Round Robin: A → B → C → A → B → C
  - Mặc định, đơn giản nhất
  - Không quan tâm server load

Weighted Round Robin: A(weight=3) → B(weight=1)
  - A → A → A → B → A → A → A → B
  - Dùng khi servers có capacity khác nhau

Least Connections:
  - Gửi request đến server có ít connections nhất
  - Tốt khi requests có duration khác nhau

IP Hash:
  - Hash IP của client → luôn vào cùng 1 server
  - Session sticky (stateful apps)

Random:
  - Random chọn server
  - Tốt khi nhiều servers

Least Response Time:
  - Gửi đến server có response time thấp nhất
  - HAProxy: leastconn
```

### 6.2 Nginx Load Balancer

```nginx
# /etc/nginx/nginx.conf

upstream backend {
    # Round Robin (mặc định)
    server 10.0.1.10:8080;
    server 10.0.1.11:8080;
    server 10.0.1.12:8080;
    
    # Weighted
    # server 10.0.1.10:8080 weight=3;
    # server 10.0.1.11:8080 weight=1;
    
    # Least connections
    # least_conn;
    
    # IP Hash (sticky sessions)
    # ip_hash;
    
    # Health check
    server 10.0.1.13:8080 backup;  # Chỉ dùng khi tất cả others down
    server 10.0.1.14:8080 down;    # Tạm thời disabled
    
    # Keepalive connections (performance)
    keepalive 32;
}

server {
    listen 80;
    
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Retry on error
        proxy_next_upstream error timeout http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
    }
}
```

---

## 7. WebSocket & Server-Sent Events

```bash
# WebSocket - Bidirectional persistent connection
# Upgrade từ HTTP:
# GET /ws HTTP/1.1
# Upgrade: websocket
# Connection: Upgrade

# Nginx WebSocket proxy
server {
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;  # Long-lived connection
    }
}

# Server-Sent Events (SSE) - One-way streaming server → client
# Nginx SSE config
server {
    location /events {
        proxy_pass http://backend;
        proxy_buffering off;          # Quan trọng! Disable buffering
        proxy_cache off;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding on;
    }
}
```

---

> **Tiếp theo: Phần 3** - Firewall, iptables, Network Security & VPN
