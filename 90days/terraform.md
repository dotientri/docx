# 9. Cơ sở hạ tầng dưới dạng mã (IaC - Infrastructure as Code)

## Ngày 56: Bức tranh toàn cảnh về IaC
- **Định nghĩa:** Quản lý hạ tầng IT thông qua mã nguồn thay vì thao tác thủ công (Click-Ops).
- **Triết lý DevOps cho hạ tầng:**
  - **Pets vs Cattle:** Chuyển dịch từ việc "chăm sóc" từng máy chủ thủ công (Pets) sang quản lý hạ tầng hàng loạt, tự động (Cattle).
  - **Declarative (Khai báo):** Chỉ định "trạng thái cuối mong muốn" (Desired State). Công cụ (Terraform) tự động thực hiện các bước để đạt được trạng thái đó.
  - **Procedural (Trình tự):** Định nghĩa chi tiết từng bước thực hiện (bash scripts).
  - **Immutable (Bất biến):** Hạ tầng không bị sửa đổi sau triển khai. Nếu cần cập nhật, tài nguyên cũ sẽ bị huỷ và thay bằng tài nguyên mới (Docker Image, VM mới).
- **Lợi ích:** Tính tái sử dụng, khả năng kiểm thử, kiểm soát phiên bản (Git), và loại bỏ lỗi do con người.

## Ngày 57: Giới thiệu về Terraform
- **Terraform:** Công cụ IaC mã nguồn mở của HashiCorp.
- **Đặc tính:** **Cloud Agnostic** (Hỗ trợ đa nền tảng: AWS, Azure, GCP, v.v.).
- **Workflow (Vòng đời):**
  - `terraform init`: Cài đặt các plugin (Providers) và khởi tạo thư mục.
  - `terraform plan`: So sánh code với hạ tầng thực tế, đưa ra kế hoạch thay đổi (dry-run).
  - `terraform apply`: Thực thi tạo/sửa hạ tầng.
  - `terraform destroy`: Hủy toàn bộ tài nguyên đã quản lý.
- **Terraform vs Vagrant:**
  - Vagrant: Quản lý VM trên máy cục bộ (Dev/Test).
  - Terraform: Quản lý tài nguyên quy mô lớn trên Cloud.

## Ngày 58: Cú pháp HCL và Trạng thái (State)
- **HCL (HashiCorp Configuration Language):** Ngôn ngữ cấu hình thân thiện, dễ đọc/viết.
- **Cấu trúc tệp `.tf`:**
  - **Provider:** Khai báo nhà cung cấp (AWS, Azure...).
  - **Resource:** Khối định nghĩa tài nguyên cần tạo (ví dụ: VM, Network, Database).
- **Terraform State (File `terraform.tfstate`):**
  - **Vai trò:** Bản đồ (mapping) giữa code của bạn và tài nguyên thực tế trên Cloud.
  - **Lưu ý:** Chứa thông tin nhạy cảm. Cần lưu trữ an toàn (Terraform Cloud hoặc Remote Backend như S3/Azure Blob Storage).

## Ngày 59: Tạo máy ảo, Biến (Variables) và Outputs
- **Cơ chế Scaling:** Dùng tham số `count` hoặc `for_each` để tạo hàng loạt tài nguyên từ 1 block mã.
- **Variables (`variables.tf`):**
  - Giúp tham số hóa cấu hình (ví dụ: kích thước VM, Region, Instance type).
  - Tránh hardcode, tăng tính linh hoạt cho nhiều môi trường (Dev/Prod).
- **Outputs (`outputs.tf`):**
  - Trích xuất thông tin tài nguyên sau khi triển khai (VD: IP Public, DNS Name) để người dùng hoặc các module khác sử dụng.

## Ngày 60: Docker Containers, Provisioners & Modules
- **Docker Provider:** Quản lý vòng đời container (Image, Network, Container) trực tiếp qua Terraform.
- **Provisioners:**
  - Dùng để thực thi script cấu hình (vd: `remote-exec` chạy lệnh trên VM mới tạo).
  - Khuyến nghị: Ưu tiên dùng Ansible hoặc Packer để tạo sẵn Image (Golden Image) thay vì dùng nhiều Provisioners.
- **Modules (Tái sử dụng mã):**
  - **Khái niệm:** Gom nhóm các tài nguyên thành một "gói" (như function trong lập trình).
  - **Tính DRY (Don't Repeat Yourself):** Viết module 1 lần, dùng cho nhiều dự án khác nhau.
  - **Terraform Registry:** Nguồn tham khảo các module mẫu chuẩn từ cộng đồng.

## Ngày 61: Xử lý Đa môi trường với Kubernetes
- **Kubernetes Provider:** Triển khai trực tiếp Pod, Deployment, Service từ Terraform code.
- **Quản lý đa môi trường:**
  - **Workspaces:** Tạo các "không gian" riêng biệt cho Dev/Staging/Prod trên cùng một cấu hình.
  - **File Structure (Khuyên dùng):** Cấu trúc thư mục tách biệt hoàn toàn (`/env/dev`, `/env/prod`) kết hợp dùng chung Modules để đảm bảo tính an toàn cao nhất.

## Ngày 62: Kiểm thử, Bảo mật và Thay thế
- **Quản lý mã (Maintenance):**
  - `terraform fmt`: Định dạng code tự động.
  - `terraform validate`: Kiểm tra lỗi cú pháp (Syntax).
- **Công cụ bảo mật (Security Scanners):**
  - **tfsec / checkov:** Tự động quét code để phát hiện lỗ hổng bảo mật (ví dụ: S3 công khai, Open Port).
- **Kiểm thử tự động:**
  - **Terratest:** Kiểm thử hạ tầng bằng code (Golang) sau khi đã triển khai.
- **Công cụ thay thế:**
  - **Pulumi:** Cho phép viết IaC bằng ngôn ngữ lập trình mạnh mẽ (Python, JS, Go).
  - **Cloud-native tools:** AWS CloudFormation, Azure ARM, Google Deployment Manager.
- **Tự động hóa nâng cao:**
  - **Terragrunt:** Công cụ giúp giữ code DRY, xử lý state từ xa dễ dàng.
  - **Atlantis:** Thực hiện `terraform plan/apply` tự động trực tiếp từ Pull Request.

## Thuật ngữ

- **IaC (Infrastructure as Code):** Quản lý và phiên bản hóa hạ tầng bằng mã nguồn.
- **Provider:** Plugin Terraform giao tiếp với nhà cung cấp Cloud (AWS, Azure, GCP).
- **Resource:** Khối khai báo tài nguyên cần tạo/quản lý (VM, Network, DB).
- **Module:** Tập hợp các resource và biến tái sử dụng như một thành phần đóng gói.
- **State (`terraform.tfstate`):** Bản đồ giữa mã và tài nguyên thực tế; cần lưu trữ an toàn.
- **Plan / Apply / Destroy:** `plan` xem sự khác biệt, `apply` thực thi thay đổi, `destroy` xóa tài nguyên.
- **Workspace:** Không gian tách biệt để quản lý nhiều môi trường (dev/prod) trên cùng config.
- **Backend:** Nơi lưu state (local, S3, Azure Blob); remote backend hỗ trợ khóa (locking) để tránh race.
- **HCL:** Ngôn ngữ cấu hình HashiCorp dùng viết file `.tf`.
- **Provisioner:** Cơ chế chạy script trên resource sau khi tạo (remote-exec, local-exec); dùng tiết chế.
- **tfsec / checkov:** Công cụ quét bảo mật cho mã Terraform.