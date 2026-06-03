# 4. Kiến thức Mạng máy tính (Networking)

## Ngày 21: Bức tranh toàn cảnh về NetDevOps
- **NetDevOps là gì?**
  - Sự kết hợp giữa Networking và nguyên tắc DevOps.
  - Chuyển đổi từ quản lý cấu hình thủ công (CLI) sang tự động hóa bằng phần mềm (Software-Defined).
  - Dùng IaC (Infrastructure as Code) để quản lý cấu hình mạng như quản lý mã nguồn phần mềm.
  - Loại bỏ tình trạng hệ thống mạng trở thành "điểm thắt cổ chai" làm chậm quá trình CI/CD.
- **Các khái niệm cơ bản**
  - **Host (Máy chủ/Thiết bị đầu cuối):** Máy tính, server, hoặc thiết bị IoT có khả năng gửi và nhận dữ liệu.
  - **IP Address:** Địa chỉ logic, định danh duy nhất cho từng thiết bị trên mạng (Internet hoặc LAN).
  - **Network:** Hệ thống vật lý và logic vận chuyển dữ liệu giữa các máy chủ.
- **Phân loại Thiết bị mạng**
  - **Switch (Bộ chuyển mạch - Lớp 2):** Hoạt động trong cùng một mạng LAN. Sử dụng bảng địa chỉ MAC để chuyển tiếp gói dữ liệu nội mạng nhanh chóng.
  - **Router (Bộ định tuyến - Lớp 3):** Kết nối các mạng (Subnets) khác nhau. Định tuyến gói tin xuyên mạng dựa trên địa chỉ IP đích (Default Gateway).
  - **Firewall (Tường lửa):** Kiểm tra và kiểm soát luồng traffic ra/vào dựa trên các chính sách bảo mật (Access Control Lists).
  - **Load Balancer (Cân bằng tải):** Phân phối luồng truy cập đồng đều đến các server backend nhằm tránh quá tải hệ thống.
  - **Các thiết bị khác:** Access Points (Mạng không dây), L3 Switches, IDS/IPS (Phát hiện/Ngăn chặn xâm nhập), Proxies.

## Ngày 22: Mô hình mạng 7 Lớp OSI & Đi sâu vào Giao thức
- **Mục đích của Mô hình OSI**
  - Bộ tiêu chuẩn quốc tế giúp các thiết bị, phần mềm từ các hãng khác nhau có thể giao tiếp đồng nhất.
  - Quá trình **Đóng gói (Encapsulation)** đi từ Lớp 7 xuống Lớp 1 ở máy gửi, và **Mở gói (Decapsulation)** từ Lớp 1 lên Lớp 7 ở máy nhận.
- **Chi tiết 7 Lớp (Từ dưới lên)**
  - **Lớp 1 - Physical (Vật lý):** Truyền tải dữ liệu vật lý (tín hiệu bit 0 và 1) qua môi trường cáp đồng, cáp quang, sóng Wi-Fi.
  - **Lớp 2 - Data Link (Liên kết dữ liệu):** Nhóm bit thành các Frame(KHUNG DỮ LIỆU). 
    - Sử dụng địa chỉ vật lý (MAC Address) do nhà sản xuất gán cứng để giao tiếp tới trạm kế tiếp. 
    - Cung cấp cơ chế phát hiện lỗi (FCS). Là nơi hoạt động của Switch.
  - **Lớp 3 - Network (Mạng):** Phân mảnh và đóng gói thành Packet. 
    - Cung cấp địa chỉ logic (IP) và tìm đường (Routing) từ điểm đầu đến điểm cuối. Là nơi hoạt động của Router.
  - **Lớp 4 - Transport (Giao vận):** Đóng gói thành Segment(ĐOẠN DỮ LIỆU). Thiết lập kết nối bằng cách sử dụng Cổng (Port) để phân biệt các ứng dụng. Có 2 giao tLIỆUcốt lõi:
    - **TCP (Transmission Control Protocol - Chậm mà chắc):** Giao thức hướng kết nối, đảm bảo dữ liệu đến nơi trọn vẹn, đúng thứ tự, không bị mất mát.
      - **Cơ chế Bắt tay 3 bước (3-way Handshake):** Quá trình "chào hỏi" bắt buộc trước khi gửi dữ liệu.
      - *Bước 1 (SYN - Synchronize):* Máy A gửi gói `SYN` (Hỏi: "Alo B, mày rảnh nhận dữ liệu không?").
      - *Bước 2 (SYN-ACK):* Máy B trả lời bằng gói `SYN-ACK` ("Tao rảnh, nghe rõ. Mày nghe rõ tao không?").
      - *Bước 3 (ACK - Acknowledge):* Máy A xác nhận bằng gói `ACK` ("Nghe rõ, chuẩn bị gửi dữ liệu đây!"). Mở ra đường truyền an toàn.
    - **UDP (User Datagram Protocol - Nhanh mà ẩu):** Giao thức không hướng kết nối (Connectionless).
      - Không có cơ chế bắt tay, cứ thế "bắn" dữ liệu đi càng nhanh càng tốt.
      - Không kiểm tra lỗi mất mát, không gửi lại (Phù hợp cho Game Online, Livestream, Call Video).
  - **Lớp 5 - Session (Phiên):** Thiết lập, duy trì, đồng bộ và chấm dứt các phiên làm việc giữa các ứng dụng trên hai máy khác nhau.
  - **Lớp 6 - Presentation (Trình diễn):** Định dạng, nén, và mã hóa/giải mã dữ liệu.
    - **TLS/SSL (Lớp giáp bảo vệ):** TLS (Transport Layer Security) là bản nâng cấp hiện đại của SSL (đã bị khai tử).
    - Biến dữ liệu lướt web từ "tấm bưu thiếp lộ thiên" thành "két sắt khóa kín".
    - **Quá trình Bắt tay TLS (TLS Handshake):**
      - *Client Hello:* Trình duyệt xin chào và báo cáo các chuẩn mã hóa nó hỗ trợ.
      - *Server Hello & Giấy tờ:* Máy chủ trình **Chứng chỉ TLS** (chứa Khóa Công Khai - Public Key) để chứng minh danh tính.
      - *Tạo khóa bí mật:* Trình duyệt sinh ra một khóa bí mật (Symmetric Key), dùng Khóa Công Khai của Server bọc lại rồi gửi đi.
      - *Kết nối an toàn:* Chỉ có Server mới có Khóa Bí Mật (Private Key) để mở bọc, lấy chìa khóa dùng chung. Cả 2 bắt đầu mã hóa dữ liệu.
  - **Lớp 7 - Application (Ứng dụng):** Cung cấp giao diện trực tiếp cho người dùng. Hoạt động của **HTTP** và **HTTPS**:
    - **HTTP (HyperText Transfer Protocol - Port 80):**
      - Giao thức truyền tải siêu văn bản nền tảng của Web.
      - *Vô trạng thái (Stateless):* Server không nhớ ai là ai (cần dùng Cookie để nhớ).
      - *Văn bản thuần túy (Plaintext):* Không mã hóa, hacker dễ dàng đọc trộm mật khẩu bằng cách bắt gói tin.
    - **HTTPS (HTTP Secure - Port 443):**
      - Là sự kết hợp: `HTTPS = HTTP + TLS`.
      - Đảm bảo 3 yếu tố (CIA): Bảo mật (Mã hóa), Toàn vẹn (Không bị chỉnh sửa), và Xác thực (Đúng server thật).
    - **Các phương thức HTTP (Methods):**
      - `GET`: Yêu cầu lấy dữ liệu về.
      - `POST`: Gửi dữ liệu mới lên Server (đăng ký, bình luận).
      - `PUT` / `PATCH`: Cập nhật dữ liệu đã có.
      - `DELETE`: Xóa dữ liệu.
    - **Mã trạng thái HTTP (Status Codes):**
      - `2xx`: Thành công (200 OK, 201 Created).
      - `3xx`: Chuyển hướng (301 Moved Permanently).
      - `4xx`: Lỗi phía người dùng (400 Bad Request, 401 Unauthorized, 404 Not Found).
      - `5xx`: Lỗi phía Server (500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable).

## Ngày 23: Các giao thức mạng tiêu chuẩn & Mạng con
- **Các Giao thức Tiêu chuẩn (Internet Standards)**
  - **ARP (Address Resolution Protocol):** Phân giải địa chỉ IP (Lớp 3) sang địa chỉ MAC (Lớp 2) để Frame có thể được gửi đi trên đường truyền vật lý.
  - **DNS (Domain Name System):** Hệ thống phân giải tên miền (như `vntechies.dev`) thành địa chỉ IP (như `104.21.x.x`) để máy tính hiểu được.
  - **DHCP (Dynamic Host Configuration Protocol):** Tự động cấp phát 4 thông số mạng thiết yếu cho thiết bị truy cập: Địa chỉ IP, Subnet Mask, Default Gateway, và DNS Server.
- **Mạng con (Subnetting)**
  - Quá trình chia một dải địa chỉ IP lớn thành nhiều mạng logic nhỏ hơn.
  - **Lợi ích thực tiễn:** - Tối ưu và tiết kiệm địa chỉ IP.
    - Giảm kích thước miền quảng bá (Broadcast domain) giúp giảm tắc nghẽn mạng.
    - Tăng cường bảo mật bằng cách cô lập các phòng ban/khu vực mạng, dễ dàng chặn các luồng dữ liệu bất thường.

## Ngày 24: Tự động hóa thiết lập mạng
- **Mục tiêu của Tự động hóa mạng**
  - Thay thế các tác vụ cấu hình thủ công dễ sinh ra lỗi con người (fat-finger errors).
  - Giảm chi phí vận hành, quản lý cấu hình tập trung (ngăn chặn Configuration Drift).
  - Đạt sự linh hoạt, dễ dàng mở rộng và tuân thủ các quy tắc bảo mật.
- **Phương pháp và Quy trình tiếp cận**
  - Lập bản đồ các tác vụ thủ công lặp đi lặp lại thường xuyên (cấp VLAN, mở Port tường lửa).
  - Phân chia mạng thành các khu vực dễ quản lý: Định tuyến, Tường lửa, Cân bằng tải (ADC), DDI (DNS/DHCP).
  - Tiếp cận từng bước: Viết script tự động hóa các tác vụ nhỏ -> Kiểm thử -> Phối hợp luồng công việc cấp cao.
- **Công cụ sinh thái (NetDevOps Tools)**
  - **Hệ điều hành & IDE:** Linux, VS Code.
  - **Quản lý cấu hình (Configuration Management):** Ansible (sử dụng file YAML, kết nối qua SSH, hoạt động agentless - không cần cài phần mềm lên thiết bị mạng).
  - **Kiểm soát phiên bản & CI/CD:** Git, GitHub, GitLab, Jenkins.
  - **Tương tác API & Mã hóa:** Python, Nornir, nền tảng Postman để test API (GET, POST, PUT, DELETE).

## Ngày 25: Lập trình Python trong tự động hóa mạng
- **Lý do chọn ngôn ngữ Python**
  - Là tiêu chuẩn công nghiệp hiện tại (De-facto standard) nhờ hệ sinh thái thư viện khổng lồ (`pip install`).
  - Cú pháp đơn giản, đa nền tảng, dễ đọc.
  - Được hậu thuẫn mạnh mẽ bằng các bộ API từ Cisco, Juniper, Arista.
- **Sự tiến hóa của quản trị mạng hiện đại**
  - **SDN (Software-Defined Network):** Tách biệt Control Plane và Data Plane, điều khiển tự động qua một Bộ điều khiển trung tâm (Controller) thay vì SSH vào từng thiết bị lẻ.
  - **Policy-based Management:** Cấu hình bằng cách khai báo "trạng thái mong muốn" (Desired state), hệ thống tự lo việc áp dụng chính sách.
  - **High-Level Orchestration:** Tích hợp việc cấu hình mạng đan xen vào luồng tự động hóa của Cloud, VMware, Kubernetes.
- **Môi trường Lab giả lập**
  - Nhấn mạnh tầm quan trọng của việc ảo hóa mạng (như EVE-NG, GNS3, Containerlab) để tạo môi trường an toàn (sandbox) test các script Python trước khi đẩy lên mạng thật.

## Ngày 26: Xây dựng Lab mô phỏng (EVE-NG)
- **Chuẩn bị hạ tầng Ảo hóa**
  - Triển khai máy ảo EVE-NG trên nền tảng VMware Workstation (yêu cầu bật Nested Virtualization).
  - Cài đặt EVE-NG Client Pack trên máy Host để tích hợp sẵn Wireshark (bắt gói tin), Putty (SSH/Telnet).
- **Nạp Network Images (Hệ điều hành mạng)**
  - Sử dụng giao thức SFTP qua phần mềm FileZilla/WinSCP.
  - Tải các file ổ cứng ảo `.qcow2` (như hệ điều hành Cisco vIOS L2, vIOS L3) vào đúng thư mục addon của EVE-NG và sửa quyền (fix permissions).
- **Thiết lập Topology (Mô hình mạng)**
  - Triển khai 1 x Router Cisco vIOS (Làm Gateway, IP: `10.10.88.110`).
  - Triển khai 4 x Switch Cisco vIOS L2 (SW1 đến SW4, IP từ `10.10.88.111` đến `114`).
  - Sử dụng giao diện web EVE-NG để kéo thả, liên kết các thiết bị bằng cáp ảo và Power On toàn bộ node.

## Ngày 27: Thực hành tự động hóa bằng Python
- **Tạo cầu nối truy cập vào Lab**
  - Cấu hình một node Management Network (Cloud0) trên EVE-NG.
  - Bridging node này với card mạng ảo của máy Host (nhận dải IP tĩnh như `192.168.169.x`) để máy tính thật có thể dùng SSH (Putty) bắn lệnh thẳng vào các thiết bị ảo bên trong lab.
- **Các Kịch bản Tự động hóa (Python Scripts)**
  - **Script 1 - Thu thập thông tin (`netmiko_con_multi.py`):** Dùng vòng lặp quét qua danh sách IP, tự động đăng nhập SSH đa thiết bị để đẩy lệnh `show ip int brief` và xuất log cấu hình cổng.
  - **Script 2 - Cấu hình hàng loạt (`netmiko_sendchange.py`):** Dùng module `send_config_set()` để tự động đẩy các lệnh thiết lập cấu hình Trunking (đường Trunk) giữa 2 Switch (SW1 và SW2) nhanh chóng và không sai sót.
  - **Script 3 - Sao lưu hệ thống (`backup.py`):** Đọc danh sách thiết bị (IP, thông tin xác thực) từ file ngoài (như `backup.txt` hoặc CSV), tự động lưu trữ output của lệnh `show run` thành các file cấu hình dự phòng được gắn timestamp.
- **Các Thư viện chuyên dụng thiết yếu**
  - `paramiko`: Thư viện lõi cấp thấp bằng Python chuyên xử lý kết nối giao thức SSHv2.
  - `netmiko`: Bao bọc bên ngoài Paramiko, thiết kế riêng cho mạng đa hãng, tự động xử lý các rắc rối màn hình chờ CLI (`>`,`#`,`--More--`).
  - `netaddr`: Hỗ trợ thao tác, tính toán và phân giải chuyên sâu cho cấu trúc IP / Subnet mask.
  - `xlrd` / `openpyxl`: Module hỗ trợ xuất hoặc đọc mảng dữ liệu cấu hình trực tiếp từ file Excel.