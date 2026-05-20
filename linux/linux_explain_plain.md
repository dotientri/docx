# 🧠 GIẢI THÍCH BẰNG LỜI - LINUX TỪ A ĐẾN Z

---

## 1. Linux là gì và tại sao DevOps phải biết?

Linux là **hệ điều hành mã nguồn mở** - nghĩa là bạn có thể đọc, sửa, và phân phối lại toàn bộ code của nó miễn phí. Khác với Windows (Microsoft sở hữu, bạn phải trả tiền và không xem được code bên trong), Linux được cộng đồng toàn cầu xây dựng và duy trì.

**Tại sao DevOps phải biết Linux?**
- **99% server trên thế giới chạy Linux** - AWS, Azure, GCP, mọi Kubernetes cluster đều chạy Linux
- Docker và Kubernetes **không thể chạy nếu không có Linux kernel** (họ dùng trực tiếp tính năng của Linux kernel)
- Khi deploy lên cloud, bạn đang deploy lên Linux VM
- Tất cả CI/CD runners (GitHub Actions, Azure Pipelines) chạy trên Linux

---

## 2. Kernel là gì? Tại sao quan trọng?

Hãy tưởng tượng máy tính như một tòa nhà:
- **Hardware** (CPU, RAM, Disk) = móng nhà, vật liệu xây dựng
- **Kernel** = người quản lý tòa nhà - quyết định ai được dùng phòng nào, bao nhiêu điện nước
- **Applications** (nginx, python, java) = người thuê phòng

**Kernel làm gì cụ thể?**

*Quản lý bộ nhớ:* RAM có 8GB, nhiều app cùng chạy - kernel quyết định app nào dùng vùng nhớ nào, ngăn app này đọc dữ liệu của app kia (bảo mật). Khi RAM đầy, kernel chuyển bớt ra swap disk.

*Quản lý CPU:* Dù bạn có 4 lõi CPU, nhưng có thể có 500 processes đang "chạy". Kernel dùng kỹ thuật **time-slicing** - chia nhỏ CPU thành từng lát 1-10ms, mỗi process được 1 lát, đổi nhau rất nhanh đến mức ta thấy như chạy song song.

*Quản lý I/O:* Khi app muốn đọc file, nó không tự đọc disk - phải nhờ kernel. Kernel biết cách nói chuyện với hardware, còn app thì không.

*Networking:* Khi app gửi HTTP request, kernel xử lý toàn bộ stack TCP/IP - đóng gói data thành packets, gửi qua network card.

---

## 3. Filesystem - Hệ thống file Linux hoạt động ra sao?

**Everything is a file** - đây là triết lý cốt lõi của Linux. Không chỉ file text, ảnh - mà cả ổ cứng, USB, keyboard, network socket... đều được biểu diễn như file.

**Cây thư mục Linux (giải thích từng thư mục):**

```
/ (root)
├── /bin    → Các lệnh cơ bản: ls, cp, mv, bash (user binaries)
├── /sbin   → Lệnh cho admin: fdisk, iptables (system binaries)
├── /etc    → Toàn bộ config files: nginx.conf, sshd_config, hosts
│             ETCetera - nơi chứa những thứ không biết để đâu :)
├── /home   → Home directory của users: /home/alice, /home/bob
├── /root   → Home của root user (tách riêng vì quan trọng)
├── /tmp    → Temp files, tự xóa khi reboot
├── /var    → Variable data - thứ thay đổi liên tục
│   ├── /var/log    → Log files (nginx, syslog, auth...)
│   ├── /var/lib    → App data (postgres data, docker data)
│   └── /var/spool  → Queue data (print jobs, cron jobs)
├── /usr    → User programs (thứ không cần thiết để boot)
│   ├── /usr/bin    → Phần lớn commands: python3, git, curl
│   ├── /usr/lib    → Libraries (.so files)
│   └── /usr/local  → Software bạn tự cài (không qua package manager)
├── /opt    → Optional software từ vendors: /opt/java, /opt/chrome
├── /proc   → Virtual filesystem - thông tin về running processes
│             /proc/1234/cmdline = command của process 1234
│             /proc/meminfo = RAM usage
│             /proc/cpuinfo = CPU thông tin
├── /sys    → Virtual filesystem - thông tin hardware
├── /dev    → Device files
│   ├── /dev/sda    → Ổ cứng thứ nhất
│   ├── /dev/sda1   → Partition 1 của ổ cứng thứ nhất
│   ├── /dev/null   → "Hố đen" - ghi vào đây là mất hết
│   ├── /dev/zero   → Nguồn bytes 0 vô hạn (dùng tạo file trống)
│   └── /dev/random → Random bytes (dùng tạo password, key)
└── /mnt, /media → Mount points cho USB, external drives
```

**Tại sao quan trọng khi làm DevOps?**
- Biết logs ở `/var/log/` - khi app crash thì tìm ở đây
- Config ở `/etc/` - khi cần sửa nginx/sshd/cron
- `/proc` và `/sys` - khi debug performance issues (xem CPU frequency, memory)
- App data ở `/var/lib/` - khi backup database (postgres data dir, mysql data dir)

---

## 4. Process và Thread - Sự khác nhau quan trọng

**Process** = một chương trình đang chạy, có không gian bộ nhớ riêng biệt hoàn toàn
**Thread** = một "luồng thực thi" trong cùng process, chia sẻ bộ nhớ với nhau

Ví dụ dễ hiểu: Một nhà hàng (process) có nhiều nhân viên (threads) phục vụ cùng lúc. Nhân viên chia sẻ kitchen (memory), nhưng nhà hàng khác thì tách biệt hoàn toàn.

**Tại sao cần hiểu điều này?**

Khi một process crash, nó chỉ ảnh hưởng mình nó. Nhưng khi một thread crash, nó có thể crash toàn bộ process (vì chia sẻ memory).

Docker containers = processes riêng biệt (isolated bằng namespaces). Đó là lý do khi 1 container crash, các container khác vẫn sống.

**Process States (trạng thái process):**

*Running (R):* Đang thực sự dùng CPU ngay lúc này.

*Sleeping (S):* Đang chờ gì đó - chờ network response, chờ user input, chờ timer. Không dùng CPU. Phần lớn thời gian process ở trạng thái này.

*Uninterruptible Sleep (D):* Đang chờ I/O không thể bị ngắt. Thường khi process đang đọc/ghi disk. Nếu nhiều process ở state D = disk quá tải.

*Zombie (Z):* Process đã chết nhưng entry vẫn còn trong process table vì parent chưa "dọn dẹp" (chưa gọi wait()). Zombie không tốn CPU/RAM nhưng tốn PID. Nếu quá nhiều zombie = có bug trong parent process.

*Stopped (T):* Process bị tạm dừng bởi signal SIGSTOP. Ctrl+Z trong terminal làm điều này.

---

## 5. File Permissions - Tại sao cần và hoạt động ra sao?

**Vấn đề cần giải quyết:** Trên cùng 1 server có nhiều users, nhiều apps. Làm sao ngăn user A đọc file của user B? Ngăn app web server xóa file hệ thống?

Linux dùng mô hình **DAC (Discretionary Access Control)** - chủ sở hữu file quyết định ai được làm gì.

**Ba loại entities:**
- **User (u):** Người tạo ra file (chủ sở hữu)
- **Group (g):** Nhóm được assign cho file
- **Others (o):** Tất cả mọi người còn lại

**Ba loại permissions:**
- **Read (r = 4):** Đọc nội dung file, hoặc list thư mục
- **Write (w = 2):** Sửa/xóa file, hoặc tạo/xóa file trong thư mục
- **Execute (x = 1):** Chạy file như program, hoặc "cd" vào thư mục

**Tại sao Execute cho thư mục lại là "cd vào"?**

Trong Linux, để truy cập file `/home/alice/secret.txt`, bạn cần:
1. Execute permission trên `/` (root directory)
2. Execute permission trên `/home`
3. Execute permission trên `/home/alice`
4. Read permission trên `secret.txt`

Execute trên directory = quyền "đi qua" directory đó. Thiếu x trên thư mục cha thì không bao giờ vào được file con.

**Ví dụ thực tế tại sao permissions quan trọng:**

Web server (chạy với user `www-data`) cần đọc files trong `/var/www/html/` nhưng không được phép ghi (để tránh bị hack → ghi web shell). Cấu hình đúng:
- `/var/www/html/` owned by `www-data:www-data`
- Files: `644` (www-data đọc được, others cũng đọc được - vì web server serve public)
- Script PHP: `755` nếu cần execute

Nếu đặt `777` cho web directory: Nếu bị SQL injection hoặc RCE, attacker có thể upload file bất kỳ → backdoor → chiếm server.

---

## 6. SSH - Tại sao an toàn hơn Password?

**Password authentication vấn đề:**
- Brute force: thử hàng triệu passwords/giây → dictionary attack
- Phishing: lừa bạn nhập password vào site giả
- Man-in-the-middle: chặn password trong transit
- Password database bị leak → credential stuffing

**SSH Key Authentication hoạt động ra sao?**

Đây là **asymmetric cryptography** (mã hóa bất đối xứng):

Bạn tạo 1 cặp key:
- **Private key** (`~/.ssh/id_ed25519`): Giữ bí mật tuyệt đối, KHÔNG bao giờ chia sẻ. Đây là "bằng chứng danh tính" của bạn.
- **Public key** (`~/.ssh/id_ed25519.pub`): Chia sẻ thoải mái, copy lên mọi server bạn muốn access.

**Quy trình xác thực:**
1. Client kết nối server, gửi "tôi muốn login bằng key này"
2. Server tạo một **chuỗi random** (challenge)
3. Server gửi challenge đó cho client
4. Client **ký** challenge bằng private key → tạo ra signature
5. Client gửi signature về server
6. Server dùng **public key** để verify signature
7. Nếu verify thành công → chứng minh client có private key → cho vào

Tại sao an toàn? Chỉ ai có private key mới tạo được signature hợp lệ. Không cần gửi password qua mạng. Brute force không hiệu quả vì không có gì để đoán.

---

## 7. Package Managers - apt, yum, dnf hoạt động ra sao?

**Vấn đề thủ công:** Muốn cài nginx → download từ nginx.org → compile từ source → link libraries → handle dependencies → configure → setup service. Mất 2 giờ, dễ lỗi.

**Package manager giải quyết:** Một lệnh `apt install nginx` → tự động download binary đã compile sẵn, kiểm tra dependencies, install chúng, configure, register service.

**Repository là gì?**

Repository = kho phần mềm online. Ubuntu duy trì repository tại `archive.ubuntu.com`. Khi chạy `apt install`, apt kết nối repository, tìm package, download về.

**Dependency resolution:**

Nginx cần `libssl`, `libpcre`, `zlib`. Những libraries đó lại cần các libraries khác. Package manager tự giải quyết "cây phụ thuộc" này - bạn chỉ cần nói "tôi muốn nginx" và nó tự lo phần còn lại.

**Tại sao quan trọng cho DevOps?**

Trong Dockerfile, bạn thường thấy:
```
RUN apt-get update && apt-get install -y curl wget git
```

`apt-get update` = refresh danh sách packages từ repository (lấy version mới nhất)
`apt-get install -y` = install, `-y` auto-yes không hỏi

Nếu không chạy `update` trước `install`, có thể cài phiên bản cũ hoặc fail vì repository list lỗi thời.

---

## 8. Signals - Cách giao tiếp với Processes

**Signals** = "tin nhắn" từ kernel hoặc user gửi đến process.

**Các signals quan trọng:**

*SIGTERM (15):* "Làm ơn dừng lại." Process nhận được, có thể ignore hoặc handle - thường là dọn dẹp (close connections, flush logs) rồi thoát. Đây là cách lịch sự để stop process.

*SIGKILL (9):* "Dừng ngay lập tức." Kernel force-kill, process KHÔNG thể ignore. Không có thời gian dọn dẹp. Dùng khi process không phản hồi SIGTERM. Nguy hiểm vì có thể gây data corruption nếu process đang write file.

*SIGHUP (1):* Historically = "terminal disconnected." Ngày nay nhiều daemons (nginx, sshd) handle signal này để **reload configuration** mà không cần restart (zero-downtime config reload).

*SIGINT (2):* Ctrl+C trong terminal. Giống SIGTERM nhưng đến từ keyboard.

*SIGSTOP (19):* Pause process. Ctrl+Z trong terminal.

*SIGCONT (18):* Resume process bị stopped.

**Tại sao quan trọng cho containers?**

Khi `docker stop container` → Docker gửi SIGTERM → chờ 10s → nếu không dừng thì gửi SIGKILL.

Nếu app của bạn không handle SIGTERM, nó sẽ bị SIGKILL sau 10s → có thể mất data, connections bị cut đột ngột, requests đang xử lý bị drop. 

Best practice: App phải handle SIGTERM để graceful shutdown - đợi requests hiện tại xong, close DB connections, flush logs, RỒI mới exit.

---

## 9. Cron - Scheduled Tasks

**Cron** = scheduler chạy command tự động theo lịch.

**Crontab syntax:** `phút giờ ngày_trong_tháng tháng ngày_trong_tuần command`

```
*     *     *     *     *     command
│     │     │     │     │
│     │     │     │     └─── Thứ (0=CN, 1=T2, ..., 7=CN)
│     │     │     └───────── Tháng (1-12)
│     │     └─────────────── Ngày trong tháng (1-31)
│     └───────────────────── Giờ (0-23)
└─────────────────────────── Phút (0-59)
```

**Ký hiệu đặc biệt:**
- `*` = mọi giá trị
- `*/5` = mỗi 5 đơn vị (mỗi 5 phút, mỗi 5 giờ...)
- `1-5` = từ 1 đến 5
- `1,3,5` = 1, 3, và 5
- `@reboot` = chạy khi boot

**Ứng dụng thực tế:**
- Backup database mỗi ngày lúc 2 giờ sáng
- Clear temp files mỗi tuần
- Check disk usage mỗi 15 phút và alert nếu > 80%
- Rotate logs hàng ngày

**Chú ý quan trọng:**
- Cron chạy với môi trường tối thiểu, **không có PATH đầy đủ** như terminal bình thường. Nên dùng full path: `/usr/bin/python3`, `/usr/local/bin/docker`
- Cron không có stdout/stderr - output bị email đến user hoặc mất. Nên redirect: `command >> /var/log/myscript.log 2>&1`

---

## 10. Swap - Virtual Memory

**RAM đầy thì sao?**

Linux dùng **swap** (có thể là swap partition hoặc swap file trên disk) làm "RAM ảo". Khi RAM đầy, kernel chọn những vùng nhớ ít được dùng gần đây, copy sang swap (disk), giải phóng RAM cho process mới.

**Tại sao swap trên SSD vẫn chậm hơn RAM?**

RAM speed: ~50 GB/s
NVMe SSD: ~3.5 GB/s (14x chậm hơn)
SATA SSD: ~550 MB/s (90x chậm hơn)
HDD: ~150 MB/s (333x chậm hơn)

Khi server "swap" nhiều (gọi là **thrashing**), performance giảm thảm hại. Nếu thấy `si` và `so` cao trong `vmstat` = đang swap nhiều = cần thêm RAM hoặc giảm memory usage.

**Trong containers và Kubernetes:**

Nên **disable swap** hoặc set giới hạn rõ ràng. Kubernetes khuyến cáo tắt swap vì scheduler dựa vào memory requests/limits để schedule pods - nếu có swap thì tính toán không chính xác.

---

## 11. Linux Networking Fundamentals

**Khi bạn gõ `curl https://google.com`, điều gì xảy ra từng bước?**

**Bước 1: DNS Resolution**
`curl` hỏi OS: "google.com IP là gì?"
OS check `/etc/hosts` → không có
OS gửi UDP query đến DNS server (trong `/etc/resolv.conf`, thường là router `192.168.1.1`)
DNS server trả về: `142.250.185.46`

**Bước 2: TCP Three-Way Handshake**
`curl` gửi SYN packet đến `142.250.185.46:443`
Google server gửi SYN-ACK về
`curl` gửi ACK
→ TCP connection established

**Bước 3: TLS Handshake**
Negotiate cipher suite, verify certificate, establish encrypted session
Tốn thêm 1 RTT (Round Trip Time) với TLS 1.3, 2 RTT với TLS 1.2

**Bước 4: HTTP Request**
`curl` gửi HTTP GET request (được mã hóa bởi TLS)

**Bước 5: HTTP Response**
Google trả về HTML (mã hóa, curl giải mã)

**Bước 6: TCP Connection Close**
FIN-ACK handshake để đóng connection

**Tổng thời gian:** Có thể chỉ 50-200ms - đó là lý do mọi thứ có vẻ "tức thì"

---

## 12. Tại sao phải học Bash Scripting?

**Scenario thực tế:** Mỗi sáng bạn phải:
1. SSH vào 20 servers
2. Check disk usage
3. Check service status
4. Restart nếu down
5. Gửi report

Làm thủ công = 30-45 phút mỗi ngày, dễ bỏ sót, chán.
Bash script = 5 giây, tự động, không bao giờ bỏ sót.

**"Automate everything that runs more than once"** - DevOps principle cốt lõi.

Bash không phải ngôn ngữ đẹp hay hiện đại, nhưng nó có sẵn **trên mọi Linux system** - không cần install gì thêm. Đó là lý do nó vẫn là tool số 1 cho system automation.
