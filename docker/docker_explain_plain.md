---
markmap:
	title: "Docker — Giải thích ngắn gọn"
	collapse: false
---

# DOCKER - GIẢI THÍCH NGẮN GỌN

## Theory
- Docker cung cấp containerization bằng cách sử dụng kernel features (namespaces, cgroups) và image layering.

## Practice
- Thực hành: chạy container, build image, push/pull registry, và debug networking với `docker` CLI.

Đây là file tóm tắt ngắn gọn về Docker...
# 🧠 DOCKER TỪ A ĐẾN Z - GIẢI THÍCH BẰNG LỜI

## 1. Docker Ra Đời Để Giải Quyết Gì?

### 1.1 Vấn Đề "It Works On My Machine"
- Dev A (Windows, Python 3.11) → Code chạy OK ✅
- Dev B (macOS, Python 3.9) → Lỗi ❌
- Server Production (Ubuntu, Python 3.8) → Lỗi khác ❌❌
- **Nguyên nhân**: Mỗi máy có OS, runtime version, libraries khác nhau

### 1.2 Docker Giải Quyết Bằng Cách Nào?
- Đóng gói **TẤT CẢ** vào một "container": Code + Runtime + Libraries + Config
- Container chạy **y hệt nhau** ở mọi nơi: laptop, server, CI/CD, K8s

### 1.3 Ví Dụ Trực Quan
- **Như container vận chuyển hàng hải**: Trước đây mỗi hàng hóa hình dạng khác → khó xếp. Sau khi có container chuẩn → ship đi khắp thế giới, tàu nào cũng chở được

## 2. Container Khác VM Như Thế Nào?

### 2.1 VM (Virtual Machine)
- Xây **nguyên ngôi nhà mới** — có móng, tường, mái riêng
- Có OS riêng, kernel riêng
- Tốn nhiều RAM, CPU
- Boot mất **vài phút**

### 2.2 Container
- **Thuê phòng trong chung cư** — dùng chung nền móng (kernel)
- Mỗi phòng có cửa riêng, khóa riêng, nội thất riêng
- Nhẹ hơn rất nhiều
- Khởi động **vài milliseconds**

### 2.3 Kỹ Thuật Bên Dưới
#### Namespaces - "Ảo Giác Cô Lập"
- Container thấy PID 1 (process đầu tiên) nhưng trên host là PID 12345
- Container nghĩ mình có network, filesystem riêng — **ảo giác do kernel tạo**

#### cgroups - "Giới Hạn Tài Nguyên"
- Kernel giới hạn mỗi container dùng bao nhiêu CPU, RAM, disk I/O
- Container A không thể "ăn hết" RAM của server

## 3. Docker Image & Layers

### 3.1 Image Là Gì?
- **"Bản vẽ"** để tạo container
- Như ISO của OS — tạo nhiều máy từ 1 ISO

### 3.2 Tại Sao Có Layer System?
#### Không Có Layers
- 5 apps × 500MB Ubuntu+Python = **2.5GB** tổng

#### Có Layers
- Layer 1: Ubuntu (100MB) — **dùng chung**
- Layer 2: Python (150MB) — **dùng chung**
- Layer 3: App code (10MB) — riêng
- Docker store Ubuntu+Python **MỘT LẦN** dù 100 images dùng chung

### 3.3 Copy-on-Write (CoW)
- Image = read-only layers
- Container start → Docker thêm 1 **writable layer** ở trên
- Mọi thay đổi chỉ ảnh hưởng writable layer
- Container bị xóa → writable layer mất → **cần volume cho persistent data**

## 4. Dockerfile - Mỗi Lệnh Có Ý Nghĩa Gì?

### 4.1 FROM - Bắt Đầu Từ Image Nào?
- `FROM node:20-alpine` thay vì `FROM ubuntu`
- **Alpine** = distro siêu nhỏ (5MB), ít CVE, pull nhanh

### 4.2 RUN - Chạy Lệnh Khi Build
- Mỗi `RUN` tạo **1 layer mới**
- Dùng `&&` trên 1 dòng = 1 layer, đảm bảo update + install cùng nhau

### 4.3 COPY vs ADD
- **COPY**: Đơn giản copy files → **Best practice**
- **ADD**: Thêm tính năng extract tar.gz, download URL → chỉ dùng khi cần

### 4.4 WORKDIR - Thư Mục Làm Việc
- Như `cd` nhưng **persist** sang bước tiếp theo
- Nếu không tồn tại thì tạo luôn

### 4.5 EXPOSE - Documentation Port
- **Chỉ thông báo** "container listen port X"
- **Không thực sự mở port** — phải dùng `-p` khi `docker run`

### 4.6 CMD vs ENTRYPOINT
#### ENTRYPOINT
- **Executable sẽ chạy** — khó override

#### CMD
- **Arguments mặc định** cho ENTRYPOINT — dễ override

#### Ví Dụ
```
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
```
- `docker run myimage` → `nginx -g daemon off;`
- `docker run myimage -t` → `nginx -t` (override CMD)
- `docker run --entrypoint sh myimage` → `sh` (override cả ENTRYPOINT)

## 5. Docker Networking

### 5.1 Vấn Đề
- Container nginx muốn nói chuyện với container postgres
- Container nghĩ `localhost` = **chính nó**, không phải postgres

### 5.2 Docker Bridge Network
- Docker tạo virtual switch (`docker0`)
- Mỗi container được cấp IP riêng (172.17.0.x)
- Chúng có thể ping nhau qua IP

### 5.3 Tại Sao Cần Custom Bridge?
#### Default Bridge
- Chỉ communicate qua **IP**, không resolve hostname

#### Custom Bridge ⭐
- Docker có **built-in DNS**: container tên "postgres" → DNS tự resolve
- `curl http://postgres:5432` tự động tìm đúng IP

### 5.4 Container Ra Internet Thế Nào?
- Container → docker0 bridge → iptables NAT → host network → router → internet
- Host dùng **NAT**: thay IP container (172.17.0.x) bằng IP public của host

## 6. Docker Volumes - Persistent Storage

### 6.1 Vấn Đề
- Container là **ephemeral** (tạm thời)
- Xóa container → data bên trong **mất hết**
- PostgreSQL data, user uploads → cần persistent

### 6.2 Volume Giải Quyết
- Mount thư mục từ HOST vào container
- Data nằm trên HOST, container chỉ **"nhìn thấy"** nó
- Container bị xóa → data trên host vẫn còn

### 6.3 Named Volumes vs Bind Mounts
#### Bind Mount
- Chỉ định chính xác path: `/home/user/pgdata:/var/lib/postgresql/data`
- Tốt cho **dev** (hot reload code)

#### Named Volume ⭐
- Docker quản lý: `docker volume create pgdata`
- Tốt cho **production** — không phụ thuộc đường dẫn host

## 7. Docker Compose

### 7.1 Vấn Đề Khi Không Có Compose
- App cần nginx + node + postgres + redis = 4 lệnh `docker run` dài
- Phải đúng thứ tự, đúng network, đúng volumes, đúng env vars
- Chia sẻ teammate = gửi 4 lệnh + hướng dẫn thứ tự

### 7.2 Compose Giải Quyết
- **Một file** `docker-compose.yml` mô tả toàn bộ stack
- Mọi người chỉ cần: `docker compose up`
- **Infrastructure as Code** cho local development

## 8. Container Security

### 8.1 Non-root User
- Mặc định process chạy với **root** → nguy hiểm
- Container escape + root = **root trên host**
- Chạy non-root: escape chỉ có quyền hạn chế

### 8.2 Minimal Base Image
| Image | Size | Đặc điểm |
|-------|------|-----------|
| `ubuntu` | 77MB | Nhiều tools → attack surface lớn |
| `alpine` | 5MB | Chỉ sh + busybox → ít CVE |
| `scratch` | 0MB | Chỉ binary → secure nhất |
| `distroless` | ~20MB | Không shell, không pkg manager |

### 8.3 Read-only Filesystem
```bash
docker run --read-only myapp
```
- Ngăn attacker upload malicious files, modify binaries

### 8.4 Linux Capabilities
- Drop ALL, chỉ thêm những gì cần
```bash
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp
```

## 9. Container Registry

### 9.1 Registry Là Gì?
- **"Kho lưu trữ images"** — như GitHub nhưng cho Docker images

### 9.2 Docker Hub vs Private Registry
#### Docker Hub
- Public, miễn phí, mặc định

#### Private Registry (ACR, ECR) ⭐
- **Bảo mật**: Code công ty không public
- **Vulnerability scanning**: Tích hợp security scanner
- **Performance**: Gần cluster → pull nhanh hơn

### 9.3 Image Naming Convention
```
registry/namespace/image:tag
myregistry.azurecr.io/mycompany/api:1.2.3-alpine
```
- Tránh dùng `latest` trong production — không rõ version

## 10. Multi-stage Build

### 10.1 Vấn Đề
- Build TypeScript cần: Node.js + TS compiler + devDependencies = **~800MB**
- Chạy app chỉ cần: Node.js runtime + dist/ folder = **~120MB**
- Image production có typescript compiler, source code → **thừa, nguy hiểm**

### 10.2 Giải Pháp Multi-stage
#### Stage 1 (Builder)
- Full Node.js image, install everything, compile TypeScript

#### Stage 2 (Production)
- Fresh Node.js slim, chỉ **COPY compiled output** từ stage 1

#### Kết Quả
- Image **~120MB** thay vì ~800MB
- Không có gì thừa, không leak source code
