# 7. Công nghệ Containers

## Ngày 42: Bức tranh toàn cảnh về Containers
- **Container là gì?**
  - Khái niệm ảo hóa cấp hệ điều hành (OS-level virtualization).
  - Gói gọn mã nguồn, thư viện runtime, cấu hình và tất cả dependencies vào một đơn vị độc lập.
  - Đảm bảo tính nhất quán của ứng dụng khi di chuyển giữa các môi trường (Develop -> Test -> Production).
- **Lợi ích cốt lõi:**
  - Giải quyết bài toán "trên máy tôi chạy được, nhưng trên server thì không".
  - Loại bỏ xung đột thư viện giữa các ứng dụng trên cùng một máy chủ.
  - Quản lý tài nguyên, port và cấu hình tách biệt hoàn toàn.
- **So sánh VM vs Container:**
  - **Virtual Machines (VMs):** Ảo hóa phần cứng. Mỗi VM chứa một Guest OS đầy đủ (nặng, tốn RAM/CPU, khởi động chậm).
  - **Containers:** Ảo hóa hệ điều hành. Chia sẻ chung nhân (kernel) với OS của máy chủ (nhẹ, khởi động trong tích tắc).
- **Docker Image:**
  - Là bản mẫu (template) chỉ đọc (read-only).
  - Chứa mã nguồn, runtime, công cụ hệ thống và thư viện.
  - Khi chạy một Image, nó sẽ tạo ra một instance thực thi gọi là **Container**.

## Ngày 43: Docker là gì & Cài đặt
- **Khái niệm:** Hệ sinh thái công cụ hỗ trợ xây dựng, vận chuyển và chạy container theo chuẩn **OCI** (Open Container Initiative).
- **Thành phần Docker Engine:**
  - **Daemon (`dockerd`):** Tiến trình nền quản lý các objects như images, containers, networks, volumes.
  - **REST API:** Giao diện lập trình để các thành phần khác giao tiếp với daemon.
  - **CLI (`docker`):** Giao diện dòng lệnh để người dùng tương tác.
- **Hệ sinh thái hỗ trợ:**
  - **Docker Desktop:** GUI tiện ích (Windows/macOS), tích hợp **WSL2** (Windows) giúp tối ưu hiệu năng.
  - **Docker Compose:** Công cụ định nghĩa và chạy ứng dụng đa container (multi-container) thông qua file YAML.
  - **Docker Hub:** Kho lưu trữ hình ảnh (Image Registry) công cộng lớn nhất thế giới.
- **Dockerfile:** Tệp văn bản chứa tập hợp các lệnh để Docker tự động build ra một Image.

## Ngày 44: Docker Image & Thực hành chạy Container
- **Nguồn lấy Image:**
  - **Official Images:** (Tích xanh) Được Docker bảo chứng, an toàn, chuẩn xác.
  - **Verified Publishers:** Tổ chức/công ty uy tín được xác minh.
- **Thực hành các lệnh chính:**
  - `docker run -d -p 80:80 docker/getting-started`: Chạy ngầm (-d), map cổng (-p) host:container.
  - `docker ps`: Liệt kê các container đang chạy.
  - `docker ps -a`: Liệt kê tất cả container (kể cả đã dừng).
  - `docker run -it ubuntu bash`: Truy cập vào terminal bash của một container Ubuntu.
  - `docker stop <container_id>`: Dừng container.
  - `docker rm <container_id>`: Xóa container khỏi hệ thống.

## Ngày 45: Phân tích Image & Viết Dockerfile
- **Cấu trúc Layer:**
  - Mỗi lệnh trong Dockerfile tạo ra một Layer (chỉ đọc).
  - Tối ưu hóa bằng cách gom lệnh: Dùng `&&` để gộp các lệnh `RUN` nhằm giảm số lượng layer, giúp image nhẹ hơn.
  - Tận dụng Layer Cache: Để những thứ ít thay đổi (cài lib) ở trên, mã nguồn (thường xuyên đổi) ở dưới cùng.
- **Cú pháp Dockerfile:**
  - `FROM`: Image nền tảng.
  - `WORKDIR`: Thiết lập thư mục làm việc.
  - `RUN`: Cài đặt thư viện/cấu hình.
  - `COPY` / `ADD`: Đưa file từ máy host vào container.
  - `ENTRYPOINT` / `CMD`: Lệnh khởi động ứng dụng.
  - `EXPOSE`: Khai báo cổng ứng dụng.
- **Build Image:**
  - Lệnh: `docker build -t <tag_name> .`
  - Dùng `.dockerignore` để loại bỏ các tệp không cần thiết (như .git, log, node_modules) khỏi image.

## Ngày 46: Docker Compose (Đa Container)
- **Mục tiêu:** Quản lý các ứng dụng phụ thuộc lẫn nhau (ví dụ: Website + Database + Cache) bằng 1 file duy nhất.
- **Cấu hình `docker-compose.yml`:**
  - Sử dụng YAML để khai báo: `services`, `networks`, `volumes`.
- **Lệnh điều khiển:**
  - `docker-compose up -d`: Khởi chạy toàn bộ hệ thống ở chế độ ngầm.
  - `docker-compose ps`: Xem trạng thái các container trong dự án.
  - `docker-compose down`: Tắt và dọn dẹp các container đã tạo.
  - `docker-compose down --volumes`: Dọn dẹp cả dữ liệu lưu trữ (xóa trắng volume).

## Ngày 47: Docker Networking & Security
- **Mạng (Networking):**
  - `docker network ls`: Xem các mạng ảo.
  - **Bridge Network:** Mạng mặc định, cô lập container với mạng bên ngoài, chỉ giao tiếp thông qua NAT và Port Mapping.
  - `docker exec -it <id> bash`: "Nhảy" vào bên trong container để debug hoặc kiểm tra cấu hình network.
- **Bảo mật (Security):**
  - **Non-root user:** Luôn tạo và sử dụng user thường trong Dockerfile để chạy app, tránh lỗ hổng leo thang đặc quyền từ container ra host.
  - **Private Registry:** Không đẩy image chứa cấu hình nhạy cảm lên DockerHub public.
  - **Attack Surface:** Chỉ cài những gói thực sự cần thiết (tối giản image bằng Alpine Linux).

## Ngày 48: Các lựa chọn thay thế (Alternative Engines)
- **Podman:**
  - Không cần daemon (daemonless), bảo mật cao hơn.
  - Tương thích tốt với cú pháp Docker (`alias docker=podman`).
- **LXC/LXD:**
  - Ảo hóa cấp hệ điều hành truyền thống, phù hợp cho việc chạy các services lâu dài (giống VM mini).
- **Containerd:**
  - Runtime container tiêu chuẩn công nghiệp, nhẹ, là trái tim của Kubernetes.
- **Quản lý bằng GUI:**
  - **Portainer:** Cung cấp giao diện Web trực quan để quản lý containers, volumes, networks từ xa.

## Thuật ngữ

- **Image:** Bản mẫu chỉ đọc chứa hệ điều hành nhẹ, runtime và ứng dụng; dùng để tạo Container.
- **Container:** Thực thể đang chạy được tạo từ Image, có namespace, cgroups, mạng và filesystem riêng.
- **Dockerfile:** Tập hợp lệnh để build Image tự động (FROM, RUN, COPY, CMD,...).
- **Layer:** Mỗi lệnh trong Dockerfile tạo một layer; layers được cache và tái sử dụng giữa các image.
- **Registry:** Nơi lưu trữ image (Docker Hub, GitHub Container Registry, private registry).
- **Tag:** Nhãn phiên bản của image (ví dụ `myapp:1.0`), giúp phân biệt các bản build.
- **Volume:** Cơ chế lưu trữ bền vững dữ liệu ngoài lifecycle của container.
- **Network (bridge/overlay):** Mạng ảo cho phép container giao tiếp với nhau hoặc với host.
- **ENTRYPOINT vs CMD:** ENTRYPOINT xác định chương trình chính, CMD cung cấp tham số mặc định.
- **Daemon (`dockerd`):** Tiến trình nền quản lý lifecycle của các container và image.
- **Docker Compose:** Công cụ định nghĩa multi-container app bằng 1 file YAML.
- **Podman / containerd:** Các runtime/engine thay thế Docker với model không cần daemon hoặc chuyên cho container runtime.