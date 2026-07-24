# 12. Quản lý, Lưu trữ & Bảo vệ Dữ liệu

## Ngày 84: Bức tranh toàn cảnh về Quản lý dữ liệu
- **Tầm quan trọng:** Dữ liệu là tài sản giá trị nhất. Hạ tầng (Infrastructure) có thể "vô trạng thái" (stateless) và thay thế dễ dàng, nhưng dữ liệu (stateful) thì KHÔNG.
- **Quan niệm sai lầm:** - HA (High Availability) hoặc Cluster không thay thế được sao lưu (Backup).
  - Lệnh xóa nhầm (`DROP TABLE`) trên cluster HA vẫn sẽ xóa dữ liệu trên toàn bộ các node.
- **Nguyên lý 3 yếu tố:**
  - **Accuracy (Chính xác):** Dữ liệu sao lưu phải đúng với dữ liệu gốc.
  - **Consistency (Nhất quán):** Đảm bảo toàn vẹn dữ liệu khi sao chép/sao lưu.
  - **Security (Bảo mật):** Kiểm soát truy cập nghiêm ngặt vào file sao lưu.
- **DataOps:** Quy trình quản lý vòng đời dữ liệu, kết hợp giữa Data Engineering, Data Science và Vận hành hạ tầng.

## Ngày 85: Các dịch vụ dữ liệu & Cơ sở dữ liệu
- **Cơ sở dữ liệu Quan hệ (SQL):** Dữ liệu dạng bảng (Schema cứng). Phù hợp tính nhất quán cao. (VD: PostgreSQL, MySQL).
- **Cơ sở dữ liệu Phi quan hệ (NoSQL):** Linh hoạt, mở rộng ngang (Horizontal Scaling).
  - **Key-Value:** Tốc độ cao (VD: Redis).
  - **Document:** Định dạng JSON (VD: MongoDB).
  - **Wide Column:** Tối ưu phân tích lớn (VD: Cassandra).
  - **Graph:** Phân tích quan hệ (VD: Neo4j).
- **Multi-model DB:** Hỗ trợ nhiều mô hình truy vấn (SQL/NoSQL) trong cùng 1 hệ thống (VD: Azure Cosmos DB).

## Ngày 86: Nguyên tắc sao lưu & Công cụ Kopia
- **Quy tắc 3-2-1:**
  - **3:** Bản sao lưu (1 gốc, 2 dự phòng).
  - **2:** Lưu trên các môi trường khác nhau (Disk, NAS).
  - **1:** Một bản lưu ngoài site (Offsite/Cloud).
- **Công cụ Kopia:**
  - **Đặc điểm:** Mã nguồn mở, đa nền tảng, hiệu năng cao.
  - **Tính năng:** Nén (compression), Xóa trùng (deduplication), Mã hóa (encryption).
- **Thực hành:** Cấu hình mật khẩu, trỏ tới Object Storage (S3), thiết lập lịch tự động (Schedule) và chính sách lưu giữ (Retention).

## Ngày 87: Sao lưu Kubernetes với Kasten K10
- **Bối cảnh:** Bảo vệ ứng dụng Stateful (có dữ liệu) trong K8s.
- **Thực hành:** - Triển khai app **Pac-Man** (NodeJS + MongoDB).
  - Cài đặt **Kasten K10**: Giải pháp chuyên dụng cho K8s, tự động phát hiện ứng dụng.
- **Kịch bản DR:**
  - Tạo dữ liệu (High score).
  - Tạo Policy sao lưu Pod + Volume.
  - Xóa dữ liệu (Phá hoại).
  - **Phục hồi:** Sử dụng Kasten K10 để restore lại trạng thái dữ liệu an toàn.

## Ngày 88: Tính nhất quán với Kanister
- **Vấn đề:** Sao lưu ổ đĩa thông thường (Crash-consistent) dễ làm hỏng dữ liệu DB khi restore.
- **Giải pháp:** **Application-consistent backup** (Sao lưu ở mức ứng dụng).
- **Kanister:** Framework mã nguồn mở trên K8s.
  - **Profile:** Khai báo vị trí lưu (Bucket S3).
  - **Blueprint:** Định nghĩa cách tương tác với DB (câu lệnh `mongodump`, `mysqldump`).
  - **ActionSet:** Thực thi sao lưu/khôi phục theo Blueprint.

## Ngày 89: Khôi phục thảm họa (Disaster Recovery - DR)
- **Định nghĩa:** Kế hoạch khôi phục toàn bộ dịch vụ khi Data Center/Cluster bị sập hoàn toàn.
- **Luồng công việc (DR Flow):**
  - **Export:** Từ Cluster A -> Lưu vào kho lưu trữ độc lập (S3 Bucket).
  - **Dựng môi trường mới:** Khởi tạo Cluster B (Cluster DR).
  - **Import:** Dùng Kasten K10 tại Cluster B trỏ vào S3 để tải danh mục sao lưu.
  - **Failover:** Restore ứng dụng từ S3 sang Cluster B.

## Ngày 90: Tính di động & Tổng kết hành trình
- **Tính di động (Portability):** Khả năng chuyển dịch ứng dụng giữa các Cloud (AWS/Azure/GCP) hoặc On-premise.
- **Biến đổi khi khôi phục (Transformations):**
  - Thay đổi StorageClass (ví dụ: từ HDD sang SSD tốc độ cao hơn) ngay khi restore.
  - Thay đổi số lượng Pod (Scaling) để chịu tải tốt hơn tại môi trường mới.
- **Tổng kết:** Bạn đã đi qua 90 ngày hành trình từ Linux, Mạng, Containers, Kubernetes, IaC, CI/CD, Giám sát cho đến Quản lý dữ liệu.

## Thuật ngữ

- **ETL / ELT:** ETL (Extract-Transform-Load) chuyển dữ liệu -> xử lý -> nạp; ELT nạp vào trước rồi xử lý trong hệ thống đích.
- **Data Lake:** Kho lưu trữ thô (raw) ghi nhận mọi dạng dữ liệu, thường dùng cho phân tích và machine learning.
- **Data Warehouse:** Kho dữ liệu cấu trúc, tối ưu cho truy vấn phân tích (OLAP).
- **OLTP vs OLAP:** OLTP cho giao dịch ngắn, ít latency; OLAP cho phân tích khối lượng lớn, truy vấn phức tạp.
- **Backup 3-2-1:** Quy tắc sao lưu phổ biến: 3 bản, ở 2 loại lưu trữ khác nhau, 1 bản offsite.
- **Deduplication (Xóa trùng):** Kỹ thuật giảm không gian lưu trữ bằng cách chỉ lưu một bản của dữ liệu lặp.
- **Compression (Nén):** Giảm kích thước tệp backup để tiết kiệm băng thông và chi phí lưu trữ.
- **Kasten K10:** Giải pháp sao lưu & phục hồi dữ liệu cho Kubernetes, phát hiện ứng dụng stateful tự động.
- **Kanister:** Framework định nghĩa blueprint để thực hiện backup/restore ở mức ứng dụng trên K8s.
- **S3/Object Storage:** Lưu trữ đối tượng phổ biến dùng làm backend cho backup (AWS S3, MinIO, Azure Blob).