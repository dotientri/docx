# 🧠 GIẢI THÍCH BẰNG LỜI - DOCKER TỪ A ĐẾN Z

---

## 1. Docker ra đời để giải quyết vấn đề gì?

**Trước khi có Docker - "It works on my machine" problem:**

Developer code app trên MacBook. Chạy local: OK. Deploy lên server: CRASH.

Tại sao? Vì:
- MacBook dùng Python 3.11, server có Python 3.7
- App cần thư viện `libpq` version 14, server có version 12
- Developer dùng macOS, server dùng Ubuntu 20.04 - file paths, syscalls khác nhau
- App cần biến môi trường đặc biệt, dev có trong `.zshrc`, server không có

**Docker giải quyết bằng cách đóng gói TẤT CẢ** thứ cần thiết vào một "container":
- Code của app
- Python 3.11 (đúng version)
- Tất cả libraries
- Environment variables
- Configuration

Container này chạy y hệt nhau ở mọi nơi: MacBook, Ubuntu server, Windows, CI/CD runner, K8s cluster.

---

## 2. Container khác VM như thế nào? (Giải thích trực quan)

**Tưởng tượng bạn muốn "cô lập" ứng dụng:**

**Cách VM:** Xây nguyên một ngôi nhà mới - có móng riêng, tường riêng, mái riêng, nội thất riêng. Nhà có OS riêng (Windows, Linux), có kernel riêng, tốn nhiều tài nguyên (RAM, CPU), mất vài phút để boot.

**Cách Container:** Thuê một phòng trong căn hộ chung cư - dùng chung nền móng (OS kernel), nhưng mỗi phòng có cửa riêng, khóa riêng, nội thất riêng, không ai vào phòng khác được. Nhẹ hơn rất nhiều, khởi động trong vài milliseconds.

**Kỹ thuật thực sự bên dưới:**

Docker dùng 2 tính năng của Linux kernel:

*Namespaces - "Ảo giác cô lập":*
Mỗi container có "view" riêng về hệ thống. Container thấy mình có PID 1 (process đầu tiên), nhưng thực ra trên host nó là PID 12345. Container nghĩ mình có network interface riêng, filesystem riêng - nhưng đó là ảo giác do kernel tạo ra.

*cgroups (Control Groups) - "Giới hạn tài nguyên":*
Kernel giới hạn mỗi container dùng bao nhiêu CPU, RAM, disk I/O. Container A không thể "ăn hết" RAM của toàn server và làm Container B thiếu tài nguyên.

---

## 3. Docker Image là gì? Tại sao có "layers"?

**Image** = "bản vẽ" để tạo container. Như ISO của OS vậy - bạn có thể tạo nhiều máy ảo từ 1 ISO.

**Layer system - Tại sao thiết kế này thông minh?**

Hãy tưởng tượng bạn build nhiều app, tất cả đều dùng Ubuntu + Python:

Không có layers: Mỗi image chứa Ubuntu + Python + app code riêng biệt → 5 apps × 500MB = 2.5GB tổng.

Có layers: 
- Layer 1: Ubuntu base (100MB) - **dùng chung**
- Layer 2: Python 3.11 (150MB) - **dùng chung**
- Layer 3: App A code (10MB) - riêng
- Layer 4: App B code (8MB) - riêng

Docker chỉ store layers 1 và 2 MỘT LẦN trên disk, dù bạn có 100 images dùng cùng Ubuntu+Python. Tiết kiệm bandwidth khi pull, tiết kiệm disk, build nhanh hơn.

**Copy-on-Write (CoW):**

Khi container start từ image (read-only layers), Docker thêm 1 layer "writable" ở trên. Mọi thay đổi container làm (tạo file, sửa config) chỉ ảnh hưởng writable layer này. Image gốc không thay đổi.

Khi container bị xóa, writable layer bị xóa luôn. Đó là lý do **container không có persistent data** - cần mount volume ra ngoài.

---

## 4. Dockerfile - Mỗi lệnh có ý nghĩa gì?

**FROM** = "Bắt đầu từ image này"

Tại sao dùng `FROM node:20-alpine` thay vì `FROM ubuntu`? Alpine Linux là một distro siêu nhỏ (5MB), minimal - không có bash, không có nhiều tools mặc định. Image nhỏ hơn → pull nhanh hơn → attack surface ít hơn (ít package = ít vulnerability).

**RUN** = "Chạy lệnh này trong quá trình build"

```
RUN apt-get update && apt-get install -y nginx
```

Tại sao `&&` trên 1 dòng? Mỗi `RUN` tạo 1 layer mới. Nếu viết:
```
RUN apt-get update
RUN apt-get install nginx
```
→ 2 layers. Nếu cache hit layer 1 nhưng package list cũ → install phiên bản cũ. Dùng `&&` = 1 layer, đảm bảo update và install cùng nhau.

**COPY vs ADD:**
- `COPY`: Đơn giản chỉ copy files/folders từ build context vào image
- `ADD`: Giống COPY nhưng thêm tính năng: tự extract tar.gz, download từ URL
- **Best practice**: Dùng COPY, chỉ dùng ADD khi cần extract archive

**ENV** = Đặt biến môi trường trong image, tồn tại khi container chạy

**WORKDIR** = Đặt thư mục làm việc (như `cd`). Nếu không tồn tại thì tạo luôn. Tốt hơn `RUN cd /app` vì `cd` trong RUN không persist sang bước tiếp theo.

**EXPOSE** = Thông báo "container này lắng nghe port X" - chỉ là DOCUMENTATION, không thực sự mở port. Phải dùng `-p` khi `docker run` mới thực sự map port.

**CMD vs ENTRYPOINT - Hiểu đúng:**

ENTRYPOINT = "executable sẽ chạy"
CMD = "arguments mặc định cho executable đó"

Ví dụ:
```
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
```

Khi chạy `docker run myimage` → chạy `nginx -g daemon off;`
Khi chạy `docker run myimage -t` → chạy `nginx -t` (override CMD, giữ ENTRYPOINT)
Khi chạy `docker run --entrypoint sh myimage` → chạy `sh` (override cả ENTRYPOINT)

Dùng chỉ CMD thì cả CMD có thể bị override.

---

## 5. Docker Networking - Tại sao containers cần network riêng?

**Bài toán:** Container nginx muốn nói chuyện với container postgres. Hai container đang chạy trên cùng 1 host. Làm thế nào?

**Vấn đề nếu không có Docker network:**
- Container nginx nghĩ `localhost` = chính nó, không phải postgres
- Không có "hostname" để tìm postgres

**Giải pháp: Docker Bridge Network**

Docker tạo một virtual switch (`docker0`) bên trong OS. Mỗi container kết nối vào switch này, được cấp IP riêng (ví dụ 172.17.0.2, 172.17.0.3). Chúng có thể ping nhau qua IP.

**Tại sao cần Custom Bridge Network thay vì default?**

Trên default bridge: containers chỉ communicate được qua IP, không resolve nhau qua hostname.

Trên custom bridge: Docker có built-in DNS server. Bạn đặt tên container là "postgres", container nginx có thể `curl http://postgres:5432` - Docker DNS tự resolve "postgres" thành IP đúng.

**Khi container muốn ra internet:**

Container → docker0 bridge → iptables NAT rules (Linux firewall) → network interface của host → router → internet.

Host dùng NAT (Network Address Translation) - thay IP container (172.17.0.x) bằng IP public của host khi gói tin ra ngoài, và ngược lại khi response về.

---

## 6. Docker Volumes - Persistent Storage

**Vấn đề:** Container là ephemeral (tạm thời). Khi container bị xóa, mọi data bên trong mất.

Scenario: Bạn chạy PostgreSQL trong container. Data được lưu trong `/var/lib/postgresql/data` bên trong container. Khi restart container (để update image) → data mất hết.

**Volume giải quyết bằng cách:**

Mount một thư mục từ HOST vào container. Data thực ra nằm trên HOST, container chỉ "nhìn thấy" nó như thư mục của mình.

```
Host: /home/user/pgdata  ←──────────────── Docker mount
Container: /var/lib/postgresql/data
```

Khi container bị xóa, `/home/user/pgdata` trên host vẫn còn nguyên. Tạo container mới mount vào cùng đường dẫn → data vẫn đó.

**Named volumes vs Bind mounts:**

Bind mount: Bạn chỉ định chính xác path trên host (`/home/user/pgdata`). Tốt cho dev (mount code directory để hot reload).

Named volume: Docker quản lý storage location (`docker volume create pgdata`). Docker lưu ở `/var/lib/docker/volumes/pgdata/`. Tốt cho production vì không phụ thuộc vào đường dẫn trên host.

---

## 7. Docker Compose - Tại sao cần?

**Vấn đề khi không có Compose:**

Một app web đơn giản cần: nginx, node app, postgres, redis. Phải chạy 4 lệnh `docker run` dài thườn thượt, với đúng thứ tự, đúng network, đúng volumes, đúng env vars. Chia sẻ với teammate = gửi 4 lệnh và hướng dẫn thứ tự chạy.

**Docker Compose giải quyết:**

Một file `docker-compose.yml` mô tả toàn bộ "stack" - tất cả services, networks, volumes, dependencies. Mọi người chỉ cần chạy `docker compose up`.

**docker-compose.yml là infrastructure as code cho local development.**

---

## 8. Container Security - Tại sao quan trọng?

**Non-root user trong container:**

Mặc định, process trong container chạy với user root. Nếu có vulnerability trong app và attacker escape container (container escape là possible nhưng hiếm), họ sẽ có root access trên host.

Chạy với non-root user: Ngay cả khi bị escape, attacker chỉ có quyền của user đó (rất hạn chế).

**Minimal base image:**

`FROM ubuntu` = 77MB, có bash, apt, curl, wget, nhiều tools. Attack surface lớn hơn.
`FROM alpine` = 5MB, chỉ có sh và busybox. Ít package hơn = ít CVE hơn.
`FROM scratch` = 0MB, chỉ có binary của bạn. Secure nhất nhưng khó debug.
`FROM gcr.io/distroless/python3` = Google distroless, không có shell, không có package manager.

**Read-only filesystem:**

```
docker run --read-only myapp
```

Container không thể ghi vào filesystem (trừ mounted volumes và tmpfs). Ngăn attacker upload malicious files, modify binaries.

**Capabilities:**

Linux processes có "capabilities" - granular permissions thay vì all-or-nothing root. Ví dụ:
- `CAP_NET_BIND_SERVICE`: Bind port < 1024 (như port 80)
- `CAP_SYS_PTRACE`: Debug processes
- `CAP_NET_RAW`: Tạo raw sockets (dùng trong hacking tools)

Drop ALL capabilities, chỉ thêm những gì cần: `docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE`.

---

## 9. Container Registry - Docker Hub, ACR, ECR

**Registry** = "kho lưu trữ images", giống GitHub nhưng cho Docker images.

**Docker Hub** = Registry public miễn phí của Docker Inc. Mặc định khi bạn `docker pull nginx`, nó kéo từ Docker Hub.

**Tại sao dùng Private Registry (ACR, ECR)?**

1. **Bảo mật:** Code của công ty không nên public trên Docker Hub
2. **Kiểm soát:** Biết ai pull image, khi nào, từ đâu
3. **Vulnerability scanning:** Azure Container Registry (ACR) tích hợp Microsoft Defender để scan CVE
4. **Performance:** Registry gần cluster địa lý hơn → pull nhanh hơn
5. **Availability:** Không phụ thuộc vào Docker Hub uptime (đã có lần bị outage)

**Image naming convention:**

```
registry/namespace/image:tag
myregistry.azurecr.io/mycompany/api-service:1.2.3-alpine
└─────────────────────┘ └───────────────────┘ └────────────┘
     Registry URL          namespace/image name    Tag (version)
```

Tag `latest` là convention thôi, không có gì đặc biệt. Nhiều team tránh dùng `latest` trong production vì không rõ version nào thực sự đang chạy.

---

## 10. Multi-stage Build - Tại sao quan trọng?

**Vấn đề thực tế:**

Để compile TypeScript → JavaScript, bạn cần: Node.js, TypeScript compiler, tất cả devDependencies.

Để CHẠY app compiled, bạn chỉ cần: Node.js runtime + dist/ folder.

Nếu đưa tất cả vào image production:
- Node.js + TypeScript + devDependencies = ~800MB image
- Có typescript compiler trong production (không cần, attack surface thừa)
- Có source .ts files trong image (leaking code)
- Pull image chậm hơn, khởi động chậm hơn

**Multi-stage giải quyết:**

Stage 1 (builder): Dùng full Node.js image, install everything, compile TypeScript
Stage 2 (production): Start fresh với Node.js slim, chỉ copy compiled output từ stage 1

Stage 1 là "staging area" - dùng để build, sau đó vứt đi. Chỉ stage 2 được deploy.

Kết quả: Image ~120MB thay vì ~800MB, không có gì thừa.
