# ---
markmap:
  title: "Linux — Overview"
  collapse: false
# ---

# 🧠 LINUX TỪ A ĐẾN Z - GIẢI THÍCH BẰNG LỜI

## Theory
- Linux is the dominant server OS; understand kernel, processes, filesystems, permissions, and networking to operate and debug servers effectively.

## Practice
- Inspect system state with `top`, `ps`, `journalctl`, check logs under `/var/log`, manage services with `systemctl`, and secure access with SSH keys and correct permissions.

## 1. Linux Là Gì?

### 1.1 Hệ Điều Hành Mã Nguồn Mở
- Đọc, sửa, phân phối lại toàn bộ code **miễn phí**
- Cộng đồng toàn cầu xây dựng và duy trì

### 1.2 Tại Sao DevOps Phải Biết Linux?
- **99% server** trên thế giới chạy Linux
- Docker/K8s **dựa trên Linux kernel**
- Cloud VMs (AWS, Azure, GCP) = Linux
- CI/CD runners chạy trên Linux

## 2. Kernel - Người Quản Lý Tòa Nhà

### 2.1 Kernel Là Gì?
- Hardware (CPU, RAM, Disk) = **móng nhà**
- Kernel = **người quản lý** — quyết định ai dùng phòng nào
- Applications = **người thuê phòng**

### 2.2 Quản Lý Bộ Nhớ
- RAM 8GB, nhiều app cùng chạy
- Kernel quyết định app nào dùng vùng nhớ nào
- **Ngăn** app A đọc data của app B (bảo mật)
- RAM đầy → chuyển ra **swap** disk

### 2.3 Quản Lý CPU
- 4 lõi CPU nhưng 500 processes "chạy"
- **Time-slicing**: Chia nhỏ CPU thành lát 1-10ms
- Mỗi process 1 lát, đổi nhau rất nhanh → có vẻ song song

### 2.4 Quản Lý I/O
- App muốn đọc file → **nhờ kernel**
- Kernel biết cách nói chuyện với hardware, app thì không

### 2.5 Networking
- App gửi HTTP request → kernel xử lý toàn bộ TCP/IP
- Đóng gói data thành packets, gửi qua network card

## 3. Filesystem - Everything Is A File

### 3.1 Triết Lý Cốt Lõi
- Không chỉ file text, ảnh
- Cả ổ cứng, USB, keyboard, network socket = **file**

### 3.2 Cây Thư Mục Linux
#### Lệnh & Chương Trình
- `/bin` → ls, cp, mv, bash (user binaries)
- `/sbin` → fdisk, iptables (system binaries)
- `/usr/bin` → python3, git, curl
- `/usr/local` → Software tự cài
- `/opt` → Software từ vendors (Java, Chrome)

#### Cấu Hình
- `/etc` → **Toàn bộ config**: nginx.conf, sshd_config, hosts

#### Dữ Liệu
- `/home` → Home directory users
- `/root` → Home của root user
- `/tmp` → Temp files, tự xóa khi reboot
- `/var/log` → **Log files** (nginx, syslog, auth)
- `/var/lib` → **App data** (postgres, docker)

#### Virtual Filesystem
- `/proc` → Thông tin processes: meminfo, cpuinfo
- `/sys` → Thông tin hardware
- `/dev` → Device files: sda, null, zero, random

#### Mount Points
- `/mnt`, `/media` → USB, external drives

### 3.3 Tại Sao Quan Trọng Cho DevOps?
- Logs → `/var/log/` (app crash tìm ở đây)
- Config → `/etc/` (sửa nginx/sshd/cron)
- Debug → `/proc`, `/sys` (CPU, memory issues)
- Backup → `/var/lib/` (database data dir)

## 4. Process và Thread

### 4.1 Process
- Chương trình đang chạy
- Có **không gian bộ nhớ riêng biệt hoàn toàn**

### 4.2 Thread
- Luồng thực thi **trong cùng process**
- **Chia sẻ bộ nhớ** với nhau

### 4.3 Ví Dụ
- Nhà hàng (process) có nhiều nhân viên (threads)
- Chia sẻ kitchen (memory)
- Nhà hàng khác → **tách biệt hoàn toàn**

### 4.4 Liên Quan Docker
- Containers = processes riêng biệt (isolated)
- 1 container crash → các container khác **vẫn sống**

### 4.5 Process States
#### Running (R)
- Đang thực sự dùng CPU

#### Sleeping (S)
- Chờ network, user input, timer
- **Không dùng CPU**, phần lớn thời gian ở state này

#### Uninterruptible Sleep (D)
- Chờ I/O không thể ngắt
- Nhiều D processes = **disk quá tải**

#### Zombie (Z)
- Đã chết nhưng parent chưa dọn dẹp
- Không tốn CPU/RAM nhưng tốn PID
- Nhiều zombie = **bug trong parent process**

#### Stopped (T)
- Tạm dừng bởi SIGSTOP (Ctrl+Z)

## 5. File Permissions

### 5.1 Vấn Đề Cần Giải Quyết
- Nhiều users, nhiều apps trên cùng server
- Ngăn user A đọc file user B
- Ngăn web server xóa file hệ thống

### 5.2 Ba Loại Entities
- **User (u)**: Chủ sở hữu
- **Group (g)**: Nhóm được assign
- **Others (o)**: Tất cả còn lại

### 5.3 Ba Loại Permissions
- **Read (r = 4)**: Đọc file / list thư mục
- **Write (w = 2)**: Sửa/xóa file / tạo file trong thư mục
- **Execute (x = 1)**: Chạy file / **cd vào** thư mục

### 5.4 Tại Sao Execute = "cd vào" Thư Mục?
- Truy cập `/home/alice/secret.txt` cần:
  - x trên `/` → x trên `/home` → x trên `/home/alice` → r trên `secret.txt`
- Execute trên directory = quyền **"đi qua"** directory

### 5.5 Ví Dụ Bảo Mật Web Server
- `www-data` cần đọc `/var/www/html/` nhưng **không ghi**
- Files: `644` (đọc OK, không ghi)
- `777` = **thảm họa**: attacker upload backdoor → chiếm server

## 6. SSH - Tại Sao An Toàn Hơn Password?

### 6.1 Password Authentication Vấn Đề
- Brute force: triệu passwords/giây
- Phishing, MITM, credential stuffing

### 6.2 SSH Key = Asymmetric Cryptography
#### Private Key
- `~/.ssh/id_ed25519`
- **KHÔNG BAO GIỜ chia sẻ** — bằng chứng danh tính

#### Public Key
- `~/.ssh/id_ed25519.pub`
- Chia sẻ thoải mái, copy lên servers

### 6.3 Quy Trình Xác Thực
1. Client gửi "tôi muốn login bằng key này"
2. Server tạo **challenge** (chuỗi random)
3. Client **ký** challenge bằng private key → signature
4. Server verify bằng public key
5. Verify OK → **cho vào**

### 6.4 Tại Sao An Toàn?
- Chỉ ai có private key mới tạo được signature
- **Không gửi password qua mạng**
- Brute force không hiệu quả

## 7. Package Managers

### 7.1 Vấn Đề Thủ Công
- Download → compile → link libraries → handle dependencies → configure → mất 2 giờ

### 7.2 Giải Quyết
- `apt install nginx` → tự động download, check dependencies, install, configure

### 7.3 Repository
- Kho phần mềm online (Ubuntu: `archive.ubuntu.com`)
- `apt install` kết nối repo, tìm package, download

### 7.4 Dependency Resolution
- nginx cần libssl, libpcre, zlib → chúng cần thêm libraries khác
- Package manager giải quyết **cây phụ thuộc** tự động

### 7.5 Trong Dockerfile
```
RUN apt-get update && apt-get install -y curl wget git
```
- `update` = refresh danh sách packages
- Không update trước install → cài version cũ hoặc fail

## 8. Signals - Giao Tiếp Với Processes

### 8.1 Signals Là Gì?
- "Tin nhắn" từ kernel hoặc user gửi đến process

### 8.2 Signals Quan Trọng
#### SIGTERM (15)
- "Làm ơn dừng lại" — process có thể **dọn dẹp** rồi thoát
- Cách **lịch sự** để stop

#### SIGKILL (9)
- "Dừng ngay lập tức" — **KHÔNG thể ignore**
- Không dọn dẹp → nguy hiểm nếu đang write file

#### SIGHUP (1)
- **Reload configuration** không cần restart (zero-downtime)

#### SIGINT (2)
- **Ctrl+C** trong terminal

### 8.3 Tại Sao Quan Trọng Cho Containers?
- `docker stop` → SIGTERM → chờ 10s → SIGKILL
- App **phải handle SIGTERM** để graceful shutdown
- Không handle → SIGKILL → mất data, cut connections

## 9. Cron - Scheduled Tasks

### 9.1 Cron Là Gì?
- Scheduler chạy command **tự động theo lịch**

### 9.2 Crontab Syntax
```
*     *     *     *     *     command
│     │     │     │     │
│     │     │     │     └─── Thứ (0-7)
│     │     │     └───────── Tháng (1-12)
│     │     └─────────────── Ngày (1-31)
│     └───────────────────── Giờ (0-23)
└─────────────────────────── Phút (0-59)
```

### 9.3 Ký Hiệu Đặc Biệt
- `*` = mọi giá trị
- `*/5` = mỗi 5 đơn vị
- `1-5` = từ 1 đến 5
- `1,3,5` = 1, 3, và 5

### 9.4 Chú Ý Quan Trọng
- Cron **không có PATH đầy đủ** → dùng full path: `/usr/bin/python3`
- Không có stdout/stderr → redirect: `command >> /var/log/myscript.log 2>&1`

## 10. Swap - Virtual Memory

### 10.1 RAM Đầy Thì Sao?
- Kernel chọn vùng nhớ ít dùng → copy sang **swap** (disk) → giải phóng RAM

### 10.2 Tốc Độ So Sánh
| Media | Speed | So Với RAM |
|-------|-------|-----------|
| RAM | ~50 GB/s | 1x |
| NVMe SSD | ~3.5 GB/s | 14x chậm |
| SATA SSD | ~550 MB/s | 90x chậm |
| HDD | ~150 MB/s | 333x chậm |

### 10.3 Thrashing
- Swap nhiều → performance **thảm hại**
- `vmstat` thấy `si`/`so` cao = cần thêm RAM

### 10.4 Trong K8s
- Nên **disable swap**
- Scheduler dựa vào memory requests/limits → swap làm tính toán sai

## 11. Linux Networking Fundamentals

### 11.1 Khi Gõ `curl https://google.com`
#### Bước 1: DNS Resolution
- Hỏi OS: "google.com IP là gì?"
- Check `/etc/hosts` → DNS server → `142.250.185.46`

#### Bước 2: TCP 3-Way Handshake
- SYN → SYN-ACK → ACK → **connection established**

#### Bước 3: TLS Handshake
- Negotiate cipher, verify certificate, encrypted session
- TLS 1.3: 1 RTT, TLS 1.2: 2 RTT

#### Bước 4: HTTP Request
- Gửi GET request (mã hóa bởi TLS)

#### Bước 5: HTTP Response
- Google trả HTML (mã hóa → curl giải mã)

#### Bước 6: TCP Close
- FIN-ACK handshake

#### Tổng Thời Gian
- 50-200ms — mọi thứ có vẻ "tức thì"

## 12. Bash Scripting

### 12.1 Scenario Thực Tế
- Mỗi sáng: SSH 20 servers, check disk, check service, restart nếu down, gửi report
- Thủ công: **30-45 phút**, dễ bỏ sót
- Bash script: **5 giây**, tự động, không bỏ sót

### 12.2 Tại Sao Bash?
- **Có sẵn trên mọi Linux** — không cần install
- "Automate everything that runs more than once" — DevOps principle
