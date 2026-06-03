# 12. Giám sát & Quản lý Log

## Ngày 77: Bức tranh toàn cảnh về Giám sát
- **Giám sát (Monitoring) là gì:** Theo dõi, đo lường và ghi lại trạng thái của hệ thống (hạ tầng, ứng dụng, services).
- **Tại sao cần giám sát:**
  - Phát hiện lỗi (bugs) trước khi người dùng báo cáo.
  - Kiểm tra trạng thái sức khỏe (health) của hệ thống.
  - **High-level view:** Cái nhìn tổng thể về hiệu suất.
  - Tránh thao tác thủ công (đăng nhập vào từng server kiểm tra).
- **Các công cụ phổ biến:**
  - **Nagios:** Công cụ giám sát truyền thống, ổn định, hỗ trợ plugin mạnh mẽ.
  - **Zabbix:** Nền tảng giám sát doanh nghiệp (Enterprise-grade), tích hợp đa dạng giao thức (SNMP, IPMI, JMX).

## Ngày 78: Thực hành với Prometheus
- **Prometheus:** Hệ thống giám sát mã nguồn mở tối ưu cho **Cloud-Native**.
- **Cơ chế hoạt động:**
  - **Pull-based:** Prometheus chủ động "kéo" (scrape) dữ liệu metrics từ các endpoints.
  - **PromQL:** Ngôn ngữ truy vấn mạnh mẽ để lọc và tính toán dữ liệu metrics.
- **Thành phần:**
  - **Prometheus Server:** Lưu trữ dữ liệu chuỗi thời gian (Time-series data).
  - **AlertManager:** Xử lý và gửi cảnh báo (Slack, Email, PagerDuty).
  - **PushGateway:** Hỗ trợ cho các job chạy ngắn (short-lived jobs).
- **Thực hành trên K8s:**
  - Cài đặt qua Helm: `helm install prometheus prometheus-community/prometheus`.
  - Truy vấn: `container_cpu_usage_seconds_total` (đo mức độ dùng CPU của container).

## Ngày 79: Bức tranh toàn cảnh về Quản lý Log
- **Mục tiêu:**
  - Thu thập, lưu trữ, và gắn thẻ (tagging) log từ nhiều dịch vụ (microservices).
  - Tìm kiếm và phân tích lỗi (diagnostics) bằng cách dùng **Correlation ID** để theo dõi luồng request xuyên suốt hệ thống.
- **Các khái niệm:**
  - **APM (Application Performance Monitoring):** Giám sát hiệu suất ứng dụng trong môi trường thực.
  - **Log Security:** Bảo mật log (log chứa token/password cần được lọc/che giấu - masking).
- **Công cụ:** ELK Stack (Logstash/Fluentd), Datadog, Splunk, AWS CloudWatch.

## Ngày 80: Thu thập và Trực quan hóa với ELK Stack
- **Elasticsearch:** CSDL tìm kiếm/phân tích (Search Engine), lưu trữ log dưới dạng chỉ mục (index).
- **Logstash:** Đường ống xử lý dữ liệu (ETL pipeline): Thu thập -> Chuyển đổi (Parse) -> Gửi đến Elasticsearch.
- **Kibana:** Giao diện Web trực quan để vẽ Dashboard, tìm kiếm log theo thời gian.
- **Beats:** Agents nhẹ, chạy trên máy chủ để đẩy log về stack.
- **Thực hành:** Dùng **Docker Compose** để khởi chạy `elasticsearch`, `logstash`, `kibana`. Trải nghiệm load dữ liệu mẫu qua kibana dashboard.

## Ngày 81: Fluentd & Fluent Bit
- **Tại sao cần thay thế?** Logstash tiêu tốn tài nguyên cao, khó quản lý ở quy mô lớn.
- **Fluentd:** "Logging layer" mã nguồn mở, kiến trúc **Pluggable** (300+ plugins), hiệu năng cao, viết bằng Ruby/C.
- **Fluent Bit:** Phiên bản siêu nhẹ (Lightweight) của Fluentd, viết bằng C.
  - **Vai trò trong K8s:** Thường chạy dưới dạng **DaemonSet** (1 instance mỗi node), thu thập log từ mọi container và metadata từ K8s API.
- **Cấu hình:** Dùng **ConfigMap** trong K8s để định nghĩa input, filter và output.

## Ngày 82: EFK Stack cho Kubernetes
- **EFK (Elasticsearch - Fluentd - Kibana):** Chuẩn mực cho logging trong Kubernetes.
- **Triển khai:**
  - **Fluentd (DaemonSet):** Thu thập toàn bộ log trên Node.
  - **Elasticsearch (StatefulSet):** Lưu trữ dữ liệu.
  - **Kibana (Deployment):** Trực quan hóa.
- **Thực hành:** Dùng `kubectl port-forward` để truy cập Kibana. Sử dụng tab **Discover** để filter log theo namespace hoặc pod.

## Ngày 83: Trực quan hóa với Grafana
- **Grafana:** Nền tảng chuyên dụng để trực quan hóa dữ liệu **Metrics** (cực mạnh khi kết hợp với Prometheus).
- **Quy trình triển khai:**
  - Triển khai `kube-prometheus-stack` (bao gồm Prometheus, Grafana, Alertmanager).
  - **DataSource:** Cấu hình Prometheus làm nguồn dữ liệu chính cho Grafana.
  - **Dashboards:** Import các mẫu dashboard có sẵn (ví dụ: Kubernetes Cluster view) giúp xem ngay tình trạng Cluster mà không cần tạo mới.
- **Cảnh báo (Alerting):** Tích hợp Alertmanager để gửi notification khi CPU/RAM vượt ngưỡng (ví dụ qua Slack).

## Thuật ngữ

- **Metrics:** Số liệu theo thời gian (time-series) như CPU, memory, latency, thường thu thập bởi Prometheus.
- **Logs:** Bản ghi sự kiện, lỗi và hành vi ứng dụng; hữu ích cho debugging và forensic.
- **Traces:** Theo dõi luồng request xuyên nhiều dịch vụ (distributed tracing) giúp tìm cổ chai performance.
- **APM (Application Performance Monitoring):** Công cụ đo hiệu năng ứng dụng (traces, metrics, errors).
- **Prometheus:** Hệ thống thu thập metrics kiểu pull, lưu trữ time-series và cung cấp PromQL.
- **Alertmanager:** Thành phần xử lý cảnh báo (aggregation, dedup, routing) và gửi thông báo.
- **Pull vs Push:** Pull: server thu thập metrics từ endpoint; Push: client đẩy dữ liệu vào gateway.
- **Grafana:** Nền tảng trực quan hóa metrics và xây dựng dashboard.
- **ELK / EFK:** Stack xử lý log: Elasticsearch (store), Logstash/Fluentd (ingest), Kibana (visualize).
- **SLI / SLO / SLA:** SLI (chỉ số dịch vụ), SLO (mục tiêu), SLA (thỏa thuận dịch vụ với khách hàng).