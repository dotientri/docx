# 10. Quản lý cấu hình với Ansible

## Ngày 63: Khái niệm & So sánh (Ansible vs Terraform)
- **Quản lý cấu hình (Configuration Management - CM):** Quá trình duy trì hệ thống ở trạng thái mong muốn (Desired State) một cách nhất quán, tự động và lặp lại được.
- **Ansible vs Terraform (Sự bổ trợ):**
  - **Terraform (Infrastructure as Code - IaC):** Chuyên trách **Khởi tạo hạ tầng** (Provisioning). Tạo máy ảo, mạng, database. Hoạt động theo mô hình khai báo (Declarative).
  - **Ansible (Configuration Management):** Chuyên trách **Cấu hình phần mềm** (Config & Deployment). Cài đặt package, chỉnh sửa tệp cấu hình, quản lý dịch vụ (services). Hoạt động theo mô hình thủ tục (Procedural).
- **Tại sao chọn Ansible?**
  - **Agentless:** Không cần cài bất kỳ phần mềm nào lên máy đích, chỉ cần SSH và Python.
  - **YAML:** Dễ đọc, dễ học, cú pháp gần gũi với ngôn ngữ tự nhiên.
  - **Mã nguồn mở & Hệ sinh thái mạnh:** Cộng đồng rộng lớn, thư viện Modules cực kỳ phong phú.

## Ngày 64: Kiến trúc Ansible & Bắt đầu
- **Kiến trúc:** - **Control Node:** Nơi cài đặt Ansible, thực thi các Playbooks.
  - **Managed Nodes (Hosts):** Các máy chủ bị quản lý.
  - **Inventory:** Tệp chứa danh sách IP/Hostname và phân nhóm các máy chủ đích (ví dụ: `[webservers]`, `[dbservers]`).
- **Thao tác cơ bản (Ad-hoc Commands):**
  - Thực thi nhanh lệnh đơn trên các máy đích mà không cần tạo file playbook.
  - Ví dụ: `ansible webservers -m ping` (gọi module `ping` để kiểm tra kết nối).
  - Ví dụ: `ansible webservers -a "df -h"` (gọi module `command` để xem dung lượng đĩa).

## Ngày 65: Playbooks - Trái tim của Ansible
- **Playbooks (YAML):** Tệp kịch bản định nghĩa các bước thực thi tuần tự.
- **Thành phần:**
  - **Play:** Chỉ định nhóm máy chủ (`hosts`) và quyền thực thi (`become: yes` để dùng sudo).
  - **Tasks:** Danh sách các tác vụ (thực thi module).
  - **Handlers:** Tác vụ đặc biệt, chỉ chạy khi có sự thay đổi (`notify`). Ví dụ: Khởi động lại Apache (`restart service`) khi file cấu hình (`.conf`) bị thay đổi.
- **Quy tắc quan trọng:** Ansible hoạt động theo cơ chế **Idempotency** (Tính lũy đẳng) - bạn có thể chạy playbook 100 lần, nếu hệ thống đã đúng trạng thái mong muốn thì Ansible sẽ không thực hiện lại thao tác, đảm bảo an toàn tuyệt đối.

## Ngày 66: Quản lý với Roles & Ansible Galaxy
- **Roles:** Phương pháp cấu trúc hóa playbook. Chia nhỏ playbooks thành các thư mục chức năng: `tasks`, `handlers`, `templates`, `vars`, `files`.
- **Lợi ích:**
  - Dễ bảo trì, phân chia công việc cho team.
  - Tái sử dụng (Reusability): Một role cấu hình Nginx có thể dùng cho hàng trăm project khác nhau.
- **Ansible Galaxy:**
  - Công cụ quản lý đóng gói: `ansible-galaxy init <tên_role>`.
  - Cửa hàng trực tuyến để tải về các Roles chuẩn do cộng đồng xây dựng.

## Ngày 67: Triển khai Web & Load Balancer thực tế
- **Phân tách Role:**
  - `common`: Role cài đặt công cụ thiết yếu (vim, git, curl) cho mọi máy chủ.
  - `apache2`: Role cài và config Web Server.
  - `nginx`: Role cài đặt Reverse Proxy để làm Load Balancer.
- **Workflow:** - Máy chủ A, B chạy Apache. 
  - Máy chủ C chạy Nginx cấu hình hướng traffic cân bằng tải tới A và B.
- **Tích hợp:** Cấu hình file `site.yml` (Main Playbook) để gọi lần lượt các Roles này.

## Ngày 68: Tags, Variables, Inventory & Database
- **Variables (Biến):**
  - **Ansible Facts:** Thông tin phần cứng/OS được thu thập tự động.
  - **User Variables:** Định nghĩa tại `group_vars/` hoặc trong Playbook.
  - **Jinja2 Templates (`.j2`):** Cú pháp cho phép chèn biến vào file cấu hình (ví dụ: file `index.html` tự động hiển thị IP của máy chủ).
- **Tags:** Gắn thẻ cho tasks/plays. Lệnh chạy: `ansible-playbook site.yml --tags "nginx"`.
- **Database Server:** Sử dụng Role `mysql` để tự động hóa: Cài đặt -> Tạo DB -> Tạo User -> Gán quyền (chỉ chạy 1 lần).

## Ngày 69: Hệ sinh thái mở rộng (Controller, Vault, Linting)
- **Ansible Vault:** Mã hóa các tệp chứa dữ liệu nhạy cảm (password, API keys) bằng mật khẩu (`ansible-vault encrypt secret.yml`).
- **Automation Controller / AWX:** Giao diện Web (GUI) để quản lý playbook, lên lịch chạy (Schedule), phân quyền (RBAC) và theo dõi lịch sử chạy trên quy mô doanh nghiệp.
- **Kiểm thử (Testing):**
  - **Ansible Lint:** Kiểm tra cú pháp, lỗi logic và định dạng code theo chuẩn.
  - **Molecule:** Công cụ kiểm thử chuyên sâu (Unit Test) cho các Ansible Roles trên nhiều môi trường khác nhau.
  ## Thuật ngữ

  - **Configuration Management (Quản lý cấu hình):** Quá trình tự động đảm bảo hệ thống đạt và duy trì trạng thái mong muốn (desired state) trên nhiều máy.
  - **Playbook:** Tệp YAML chứa danh sách các Play (mỗi Play áp dụng lên một nhóm host) và Tasks sẽ thực thi trên host.
  - **Inventory:** Tệp hoặc nguồn (file/đynamic inventory) liệt kê các Managed Nodes (hosts) và group của chúng.
  - **Module:** Thành phần chức năng nhỏ của Ansible được gọi để thực hiện tác vụ (ví dụ: `apt`, `service`, `copy`).
  - **Role:** Cấu trúc chuẩn để đóng gói các Tasks, Handlers, Templates, Vars, giúp tái sử dụng và phân chia công việc.
  - **Task:** Một bước công việc trong Playbook, thường gọi một Module cụ thể.
  - **Handler:** Task đặc biệt chỉ chạy khi có thông báo (`notify`) từ Task khác (thường dùng để khởi động lại service sau khi thay đổi config).
  - **Idempotency (Tính lũy đẳng):** Thuộc tính cho phép chạy cùng 1 Playbook nhiều lần mà không gây thay đổi nếu hệ thống đã ở trạng thái mong muốn.
  - **Ansible Vault:** Cơ chế mã hóa tệp chứa bí mật (password, keys) để lưu trữ an toàn trong repo.
  - **Facts:** Thông tin hệ thống thu thập tự động bởi Ansible (OS, IP, CPU...), có thể dùng trong Templates/Jinja2.
  - **Jinja2 Template:** Cú pháp template để chèn biến và logic nhỏ vào tệp cấu hình sinh ra bởi Ansible.