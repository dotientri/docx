# 5. Điện toán đám mây (Cloud - Azure)

## Ngày 28: Bức tranh toàn cảnh: DevOps & The Cloud
- **Sự kết nối giữa DevOps và Cloud:** - Điện toán đám mây cung cấp môi trường lý tưởng (API-driven) để áp dụng các công cụ tự động hóa IaC và CI/CD của DevOps.
- **Mô hình trách nhiệm chung (Shared Responsibility Model):** - Phân định rõ ràng ranh giới bảo mật và quản lý giữa nhà cung cấp Cloud (Microsoft/AWS) và khách hàng tùy theo loại dịch vụ.
- **Các mô hình Dịch vụ Đám mây:**
  - **SaaS (Phần mềm dưới dạng dịch vụ):** Khách hàng chỉ việc sử dụng (VD: Microsoft 365, Gmail). Nhà cung cấp lo từ A-Z.
  - **PaaS (Nền tảng dưới dạng dịch vụ):** Trừu tượng hóa lớp OS và hạ tầng. Kỹ sư chỉ cần tập trung triển khai mã nguồn và quản lý dữ liệu (VD: Azure App Service).
  - **IaaS (Cơ sở hạ tầng dưới dạng dịch vụ):** Cung cấp tài nguyên thô (CPU, RAM, Mạng). Người dùng phải tự quản lý Hệ điều hành, bản vá và phần mềm (VD: Virtual Machines).
- **Mô hình Triển khai:**
  - **Public Cloud:** Đám mây công cộng (Azure, AWS, GCP).
  - **Private Cloud:** Đám mây dùng riêng nội bộ doanh nghiệp.
  - **Hybrid / Multi-Cloud:** Kết hợp linh hoạt giữa Public và Private, hoặc giữa nhiều nhà cung cấp đám mây khác nhau.

## Ngày 29: Kiến thức cơ bản về Microsoft Azure
- **Kiến trúc Vật lý:**
  - **Khu vực (Regions):** Hơn 60 khu vực phân bố toàn cầu. Hệ thống tính phí dựa trên mức sử dụng (**consumption-based billing**).
  - **Vùng khả dụng (Availability Zones):** Các trung tâm dữ liệu độc lập về nguồn điện, làm mát và mạng lưới trong cùng một Region để đảm bảo tính dự phòng cao.
- **Kiến trúc Quản lý (Từ trên xuống dưới):**
  - **Management Groups (Nhóm quản lý):** Áp dụng chính sách (**Azure Policy**) và phân quyền (**RBAC**) hàng loạt cho nhiều Subscriptions.
  - **Subscriptions (Gói Đăng ký):** Ranh giới thanh toán (billing) và giới hạn tài nguyên. (Pay-as-you-go, Enterprise Agreement).
  - **Resource Groups (Nhóm tài nguyên):** Thư mục logic chứa các tài nguyên có chung vòng đời. Khi xóa một Resource Group, toàn bộ tài nguyên bên trong sẽ bị xóa.
- **Azure Resource Manager (ARM):** - Trình quản lý cốt lõi, tiếp nhận mọi yêu cầu tạo/sửa/xóa qua **REST API**. Hỗ trợ định dạng **JSON** để triển khai hạ tầng.

## Ngày 30: Mô hình bảo mật Microsoft Azure
- **Xác thực và Danh tính (Identity):**
  - **Azure Active Directory (Azure AD / Entra ID):** Dịch vụ lưu trữ định danh, hỗ trợ xác thực **SAML, OpenID Connect, OAuth2**.
- **Quản lý Quyền truy cập (RBAC):**
  - Cấp quyền dựa trên nguyên tắc **Đặc quyền tối thiểu (Least Privilege)**.
  - 3 Role cốt lõi: **Owner** (Toàn quyền + cấp quyền cho người khác), **Contributor** (Toàn quyền tài nguyên, không được cấp quyền), **Reader** (Chỉ xem).
  - Nên gán quyền cho **Group** thay vì gán lẻ tẻ cho từng **User**. Quyền tự động kế thừa từ cấp cao xuống cấp thấp.
- **Microsoft Defender cho Cloud:**
  - Nền tảng CSPM (Quản lý tư thế bảo mật) và CWP (Bảo vệ khối lượng công việc). Có thể giám sát cả AWS/GCP qua **Azure Arc**.
- **Azure Policy:**
  - Định nghĩa các quy tắc tuân thủ (compliance) bằng **JSON**.
  - Các hành động tự động: **Audit** (Ghi log), **Deny** (Chặn tạo tài nguyên sai quy tắc), **DeployIfNotExists** (Tự động triển khai cấu hình còn thiếu).

## Ngày 31: Mô hình Điện toán Microsoft Azure
- **Tính Sẵn sàng Cao (High Availability):**
  - **Availability Sets:** Bảo vệ VM khỏi lỗi phần cứng cục bộ trong cùng 1 Datacenter.
  - **Disaster Recovery (DR):** Khôi phục chéo Region khi có thảm họa diện rộng.
- **Máy ảo (Virtual Machines - IaaS):**
  - Hỗ trợ Windows/Linux. Dòng **B-Series** phù hợp cho các khối lượng công việc đột biến (burst CPU).
  - **VMSS (Virtual Machine Scale Sets):** Tự động nhân bản (scale-out) hoặc thu hẹp (scale-in) lượng VM dựa trên tải CPU/RAM.
- **Cơ sở hạ tầng dưới dạng mã (IaC - Templating):**
  - Tự động hóa tạo tài nguyên bằng **ARM Templates (JSON)** hoặc ngôn ngữ **Azure Bicep** (cú pháp khai báo mới, gọn gàng và dễ đọc hơn).
- **Điều phối Container:**
  - **AKS (Azure Kubernetes Service):** Cụm K8s được quản lý Control Plane miễn phí.
  - **ACI (Azure Container Instances):** Chạy container trực tiếp không cần VM, tính tiền theo giây.
- **Serverless (Máy chủ vô hình):**
  - **App Services:** Nền tảng PaaS để hosting Web App, REST API.
  - **Azure Functions:** Kiến trúc Event-driven (trả tiền theo số lần chạy hàm code).

## Ngày 32: Mô hình lưu trữ và cơ sở dữ liệu Microsoft Azure
- **Tài khoản Lưu trữ (Storage Accounts):**
  - **Các cấp độ dự phòng:**
    - **LRS (Locally):** 3 bản sao ở 1 Datacenter (Rẻ nhất).
    - **ZRS (Zone):** 3 bản sao ở 3 Datacenter khác nhau trong cùng Region.
    - **GRS/GZRS (Geo/Geo-Zone):** Sao chép sang Region thứ 2 cách xa hàng trăm km (An toàn nhất).
  - Xác thực qua **Shared Access Signature (SAS)** (có thời hạn) hoặc Azure AD.
- **Phân loại dịch vụ Lưu trữ:**
  - **Blob Storage:** Lưu trữ đối tượng, file phi cấu trúc (ảnh, video, log). Hỗ trợ phân lớp **Hot, Cool, Archive** (giá rẻ, truy xuất chậm).
  - **File Share:** Ổ đĩa mạng chia sẻ dùng giao thức SMB/NFS.
  - **Managed Disks:** Ổ cứng Block Storage (SSD/HDD) gắn thẳng vào VM.
- **Cơ sở dữ liệu (Databases):**
  - **SQL (Quan hệ):** Azure SQL, Database for MySQL/PostgreSQL.
  - **NoSQL (Phi quan hệ):** **Cosmos DB** (Hỗ trợ đa mô hình Key-Value, Document, Graph; phân tán toàn cầu, độ trễ cực thấp).
  - **In-memory:** Dịch vụ Caching tốc độ cao **Azure Cache for Redis**.

## Ngày 33: Mô hình Mạng Microsoft Azure + Quản lý Azure
- **Mạng ảo (Virtual Networks - VNet):**
  - Không gian IP riêng tư cô lập. Mặc định trên Azure, VM trong VNet có thể kết nối thẳng ra Internet (SNAT).
  - **VNet Peering:** Cầu nối trực tiếp giữa 2 VNet với nhau thông qua mạng trục (backbone) của Microsoft. Nhược điểm: Không có tính bắc cầu (Transitive).
- **Kiểm soát truy cập và Bảo mật:**
  - **NSG (Network Security Group):** Tường lửa Lớp 4 (Transport). Lọc traffic Inbound/Outbound dựa trên IP, Port, Giao thức. Quy tắc dùng số Priority (Càng nhỏ càng ưu tiên).
  - **ASG (Application Security Group):** Nhóm các vNIC (Card mạng ảo) theo chức năng (VD: Nhóm Web, Nhóm DB) để viết rule NSG gọn gàng hơn.
- **Cân bằng tải (Load Balancing):**
  - **Azure Load Balancer:** Hoạt động tại **Lớp 4** (Chỉ biết IP và Port).
  - **Application Gateway:** Hoạt động tại **Lớp 7** (Hiểu được URL, Cookie, HTTP Header). Tích hợp sẵn **WAF** (Tường lửa bảo vệ Web khỏi mã độc).
- **Công cụ Quản trị:**
  - **GUI:** Azure Portal.
  - **CLI:** Azure CLI (`az`), PowerShell, Cloud Shell (chạy trên trình duyệt).
  - **IDE:** Visual Studio Code tích hợp extension Azure.

## Ngày 34: Thực hành với Microsoft Azure
- **Thực hành Networking & Compute:**
  - Sử dụng CLI/PowerShell để tự động hóa việc khởi tạo **VNet**, chia **Subnet**, tạo **VM** và cấu hình cấp phát **Public IP**.
  - Xây dựng mô hình mạng **Hub-Spoke** và kết nối bằng **VNet Peering**.
  - Dùng công cụ **Network Watcher** để kiểm tra và khắc phục sự cố định tuyến (troubleshooting).
- **Thực hành Storage & IAM:**
  - Tạo **Storage Account** và thiết lập quyền truy cập cho bên thứ ba bằng mã **SAS Token**.
- **Thực hành Serverless (PaaS):**
  - Tạo **Azure Web App**.
  - Ứng dụng tính năng **Deployment Slots**: 
    1. Tạo một môi trường **Staging Slot**.
    2. Đẩy (deploy) mã nguồn mới lên Staging để test nội bộ.
    3. Thực hiện thao tác **Swap** để hoán đổi môi trường Staging thành Production mà không gây ra thời gian chết (Zero-downtime).
- **Tích hợp Infrastructure as Code (Bổ sung):**
  - Đề xuất thay thế việc click chuột bằng cách viết script **Terraform** để tự động khởi tạo đồng loạt Resource Group, VNet, App Service cho phép lặp lại quy trình dễ dàng trên mọi môi trường.

  ## Thuật ngữ

  - **Region (Khu vực):** Vùng địa lý mà nhà cung cấp cloud đặt data center, mỗi Region chứa nhiều Availability Zones.
  - **Availability Zone (Vùng khả dụng):** Trung tâm dữ liệu độc lập về mạng/nguồn điện trong cùng Region, dùng để tăng tính sẵn sàng.
  - **Subscription:** Ranh giới tính phí và quota tài nguyên trong Azure.
  - **Resource Group:** Nhóm logic chứa các resource liên quan có cùng vòng đời.
  - **ARM (Azure Resource Manager):** API/khung triển khai trung tâm của Azure, cho phép quản lý tài nguyên qua templates.
  - **Azure AD (Entra ID):** Dịch vụ quản lý danh tính, chứa User, Group, Service Principal.
  - **RBAC (Role-Based Access Control):** Cơ chế phân quyền cho phép gán roles (Owner, Contributor, Reader) lên Resource/Group.
  - **VMSS (Virtual Machine Scale Sets):** Tự động scale số lượng VM dựa trên điều kiện (CPU, metrics).
  - **AKS (Azure Kubernetes Service):** Dịch vụ quản lý Kubernetes, nhà cung cấp chịu trách nhiệm control plane.
  - **Storage Account:** Container cho các dịch vụ lưu trữ (Blob, File, Queue, Table).
  - **SAS (Shared Access Signature):** Token tạm thời cho phép truy cập vào Storage mà không cần chia sẻ khoá chính.
  - **NSG (Network Security Group):** Tập hợp rule lọc lưu lượng IP/Port cho Subnet/Network Interface.
  - **Application Gateway:** Load balancer L7 với khả năng WAF (Web Application Firewall).