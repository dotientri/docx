# 11. Đường ống CI/CD (Pipelines)

## Ngày 70: Bức tranh toàn cảnh về CI/CD
- **CI (Continuous Integration - Tích hợp liên tục):**
  - **Mục tiêu:** Tự động hóa việc build và test code mỗi khi có thay đổi.
  - **Lợi ích:** Phát hiện lỗi sớm, đảm bảo mã nguồn luôn ở trạng thái sẵn sàng để merge.
- **CD (Continuous Delivery & Deployment):**
  - **Continuous Delivery:** Đưa phần mềm qua các bước kiểm thử, đóng gói sẵn sàng để triển khai (cần duyệt thủ công).
  - **Continuous Deployment:** Tự động triển khai lên Production sau khi vượt qua tất cả các bước test tự động (không cần can thiệp thủ công).
- **Quy trình chuẩn:** Git (Code) -> Build -> Unit Test -> Package (Docker) -> Deploy (K8s/Cloud).

## Ngày 71: Giới thiệu Jenkins
- **Vai trò:** Công cụ CI/CD "quốc dân" trong hệ sinh thái DevOps.
- **Kiến trúc:** - **Master-Slave:** Node Master điều phối (schedule), Node Slave (Agent) thực thi công việc (build, test).
  - **Plugin Ecosystem:** Hệ sinh thái đồ sộ giúp Jenkins kết nối với mọi công cụ (Git, Docker, K8s, Cloud).
- **Workflow của Jenkins:** - Nhận sự kiện (webhook/poll) từ Git -> Kéo source code -> Build (Maven/Gradle) -> Test (Selenium/JUnit) -> Publish (DockerHub) -> Deploy.

## Ngày 72: Cài đặt và làm quen giao diện
- **Cài đặt trên Kubernetes (Helm Chart):** - Cách triển khai hiện đại: `helm install jenkins jenkinsci/jenkins`.
  - **Volume:** Cần cấu hình Persistent Volume (PV) để lưu cấu hình Jenkins, tránh mất dữ liệu khi Pod khởi động lại.
- **Quản lý Plugin:**
  - Mục **Manage Jenkins** -> **Manage Plugins** (nơi cài đặt các tiện ích mở rộng như Docker Pipeline, Kubernetes CLI, Pipeline Stage View).
- **Pipeline as Code (Jenkinsfile):**
  - Cách tiếp cận chuyên nghiệp: Lưu cấu hình Pipeline dưới dạng mã (tệp `Jenkinsfile`) trực tiếp trong thư mục gốc của dự án thay vì cấu hình trên giao diện Web (UI).

## Ngày 73: Xây dựng Jenkins Pipeline cơ bản
- **Mục tiêu:** Tự động hóa luồng: Code -> Build Docker Image -> Push Image.
- **Kaniko:** Công cụ xây dựng Docker image *bên trong* môi trường Kubernetes mà không cần quyền root hay Docker daemon (tránh vấn đề bảo mật với Docker-in-Docker).
- **Quản lý xác thực (Credentials):**
  - Sử dụng Jenkins Credentials Store để lưu trữ: DockerHub token, GitHub Personal Access Token.
  - Ánh xạ vào Pipeline dưới dạng biến môi trường để an toàn hóa dữ liệu nhạy cảm.
- **Các Stage cơ bản trong Pipeline:**
  - `Checkout`: Pull source code từ Git.
  - `Build`: Biên dịch code và tạo Docker Image bằng Kaniko.
  - `Push`: Đẩy Image lên Registry.

## Ngày 74: Jenkinsfile App Pipeline (Thực tế)
- **Pipeline as Code (SCM):** Thay vì tạo Job thủ công, hãy chọn "Pipeline script from SCM" (Git). Jenkins sẽ tự động cập nhật pipeline mỗi khi bạn cập nhật file `Jenkinsfile`.
- **Triggers (Kích hoạt):**
  - **Poll SCM:** Jenkins chủ động kiểm tra Git định kỳ.
  - **Webhook (Khuyên dùng):** GitHub gửi tín hiệu cho Jenkins ngay khi có `git push` (thời gian thực).
- **Quản lý phiên bản Image:**
  - Sử dụng biến `$BUILD_ID` từ Jenkins để tag image (VD: `my-app:1`, `my-app:2`), giúp dễ dàng Rollback khi có sự cố.

## Ngày 75: GitHub Actions
- **Khái niệm:** CI/CD tích hợp sâu vào GitHub, không cần cài server Jenkins riêng.
- **Cấu trúc (YAML):**
  - `.github/workflows/main.yml`: Nơi định nghĩa mọi thứ.
  - **Workflow:** Chu trình CI/CD.
  - **Event:** (Push, Pull Request, Release).
  - **Job:** Tập hợp các bước chạy trên cùng một Runner.
  - **Action:** Các task tái sử dụng (có thể dùng của cộng đồng hoặc tự viết).
- **Thực hành:** Sử dụng `super-linter` để tự động check định dạng code (lint) mỗi khi tạo Pull Request.

## Ngày 76: ArgoCD (GitOps chuyên sâu)
- **GitOps là gì?** "Git là nguồn sự thật duy nhất". Mọi trạng thái của hạ tầng/ứng dụng đều nằm trên Git.
- **ArgoCD:** Công cụ CD theo mô hình GitOps cho Kubernetes.
  - **Cơ chế:** ArgoCD theo dõi (monitor) repo Git và tự động đồng bộ (sync) trạng thái cluster K8s theo những gì khai báo trên Git.
  - **Ưu điểm:** Tự động khắc phục lỗi cấu hình (Drift detection), rollback cực nhanh chỉ bằng lệnh `git revert`.
- **Thực hành:** Cài đặt ArgoCD trên Minikube, trỏ Git repo vào ArgoCD, quan sát sự kỳ diệu khi pod tự động được tạo ra theo đúng file YAML trên Git.

## Thuật ngữ

- **CI (Continuous Integration):** Thói quen tích hợp code thường xuyên, tự động build và test để phát hiện lỗi sớm.
- **CD (Continuous Delivery / Deployment):** Quy trình đưa phần mềm đến môi trường sản xuất; Delivery có thể cần phê duyệt, Deployment tự động.
- **Pipeline:** Chuỗi các bước (stages/jobs) để build, test, và deploy phần mềm.
- **Job / Stage / Step:** Đơn vị công việc trong Pipeline; Stage nhóm các Job, Job chứa Steps.
- **Runner / Agent:** Thực thi các job của pipeline (ví dụ: GitHub Actions runner, Jenkins agent).
- **Artifact:** Kết quả build (binary, docker image) được lưu trữ để deploy hoặc kiểm chứng.
- **Webhook:** Cơ chế push sự kiện từ dịch vụ (Git) tới hệ thống CI để kích hoạt pipeline ngay lập tức.
- **Blue-Green / Canary Deployments:** Chiến lược triển khai giảm rủi ro bằng cách tách traffic hoặc test trên nhóm nhỏ trước khi mở rộng.
- **GitOps:** Triết lý dùng Git là nguồn sự thật, hệ thống tự đồng bộ cluster dựa trên repo.
- **Jenkins Master/Agent:** Kiến trúc phân tán; Master điều phối, Agent thực thi build.
- **Action (GitHub Actions):** Các component tái sử dụng trong workflow, có thể là công đoạn build/test/publish.