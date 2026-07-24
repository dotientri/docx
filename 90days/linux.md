# 3. Kiến thức cơ bản về Linux (Từ Ngày 14 đến Ngày 20)

## Ngày 14: Bức tranh lớn: DevOps và Linux
- **Mối liên hệ giữa DevOps và Linux:** Cả hai đều tập trung vào khả năng tùy biến, kiểm soát và mở rộng. Rất nhiều công nghệ và công cụ mã nguồn mở của DevOps (Docker, Kubernetes, Ansible, Terraform) bắt đầu và hoạt động tối ưu nhất trên nền tảng Linux.
- **Môi trường thực hành (Ảo hóa):**
  - Khuyến nghị triển khai máy ảo (Virtual Machine) an toàn để thực hành bằng cách sử dụng **VirtualBox** và công cụ tự động hóa cung cấp môi trường **Vagrant**.
  - **Các lệnh Vagrant cơ bản:**
    - `vagrant init <box_name>`: Khởi tạo tệp cấu hình Vagrantfile.
    - `vagrant up`: Khởi động và chạy máy ảo.
    - `vagrant ssh`: Truy cập thẳng vào bên trong máy ảo thông qua giao thức SSH.
    - `vagrant halt`: Tắt máy ảo an toàn.
    - `vagrant destroy`: Xóa hoàn toàn máy ảo để làm sạch môi trường.
  - **Thông tin truy cập mặc định:** Username: `vagrant`, Password: `vagrant`.

## Ngày 15: Các lệnh Linux cho DevOps (Thực tế là tất cả mọi người)
### Trợ giúp & Thao tác terminal cơ bản
- `man <lệnh>`: Xem trang hướng dẫn sử dụng (manual) chi tiết cho lệnh đó (vd: `man ls`). Bấm phím `q` để thoát.
- `sudo <lệnh>`: (Superuser do) Chạy câu lệnh với đặc quyền quản trị cao nhất (root). Yêu cầu nhập mật khẩu tài khoản.
- `clear`: Xóa sạch giao diện hiển thị trên màn hình terminal.
- `history`: Xem lịch sử tất cả các lệnh đã chạy trước đó. Dùng `!<số>` (vd: `!123`) để chạy lại lệnh tại dòng tương ứng.

### Quản lý Thư mục & Tệp tin
- `pwd`: (Print working directory) In ra đường dẫn tuyệt đối của thư mục hiện tại đang đứng.
- `ls`: Liệt kê các tệp và thư mục.
  - `ls -al`: Xem danh sách chi tiết (quyền, chủ sở hữu, kích thước) bao gồm cả các tệp ẩn (có dấu chấm ở đầu).
- `cd <đường_dẫn>`: Di chuyển thư mục (vd: `cd /etc`). Dùng `cd ..` để lùi lại thư mục cha, `cd ~` để quay về thư mục home.
- `mkdir <tên_thư_mục>`: Tạo một hoặc nhiều thư mục mới.
- `touch <tên_tệp>`: Tạo một tệp tin trống mới hoặc cập nhật thời gian sửa đổi của tệp nếu tệp đã tồn tại.
- `cp <nguồn> <đích>`: Sao chép tệp tin. Thêm cờ `cp -r` để sao chép đệ quy toàn bộ thư mục và nội dung bên trong.
- `mv <nguồn> <đích>`: Di chuyển tệp tin vào thư mục khác hoặc dùng để đổi tên tệp (vd: `mv file.txt newfile.txt`).
- `rm <tên_tệp>`: Xóa tệp tin.
  - `rm -r <thư_mục>`: Xóa đệ quy toàn bộ thư mục.
  - `rm -rf <thư_mục>`: Xóa bắt buộc, không cần xác nhận (Cực kỳ nguy hiểm, `sudo rm -rf /` sẽ xóa sạch hệ điều hành).
- `find <đường_dẫn> -name "<tên>"`: Tìm kiếm tệp tin trực tiếp theo tên, hỗ trợ wildcard.
- `locate <tên_tệp>`: Tìm kiếm cực nhanh vị trí tệp tin bằng cơ sở dữ liệu chỉ mục (cần chạy `sudo updatedb` để cập nhật index trước).

### Thao tác với nội dung tệp & Dữ liệu
- `echo "<nội_dung>"`: In chuỗi văn bản ra màn hình.
  - `echo "text" > file.txt`: Ghi đè chuỗi văn bản vào tệp.
  - `echo "text" >> file.txt`: Ghi nối thêm văn bản vào cuối tệp mà không xóa dữ liệu cũ.
- `cat <tên_tệp>`: Đọc và hiển thị toàn bộ nội dung tệp tin lên màn hình.
- `less` / `more`: Xem nội dung tệp tin dài theo từng trang, cho phép cuộn lên/xuống dễ dàng.
- `tail -f <tên_tệp>`: Xem luồng trực tiếp các dòng mới nhất đang được ghi vào tệp (công cụ đắc lực để xem log hệ thống realtime).
- `grep "<từ_khóa>"`: Tìm kiếm một chuỗi hoặc từ khóa cụ thể trong văn bản hoặc output (vd: `cat system.log | grep "ERROR"`).
- `awk`: Công cụ phân tích và trích xuất dữ liệu mạnh mẽ theo định dạng cột (vd: `who | awk '{print $1}'` để chỉ in ra cột tên người dùng).

### Quản lý Người dùng & Quyền hạn
- `su <tên_người_dùng>`: Chuyển đổi (Switch user) sang tài khoản người dùng khác.
- `passwd`: Thay đổi mật khẩu cho người dùng hiện tại hoặc người dùng được chỉ định (nếu có quyền sudo).
- `chmod <quyền> <tên_tệp>`: Thay đổi quyền Đọc (Read=4), Ghi (Write=2), Thực thi (Execute=1) (vd: `chmod 755 script.sh` hoặc `chmod +x script.sh`). Cờ `-R` dùng để áp dụng đệ quy.
- `chown <user>:<group> <tên_tệp>`: Thay đổi chủ sở hữu và nhóm sở hữu tệp (vd: `sudo chown root:root config.txt`).

## Ngày 16: Quản lý Hệ thống Linux, Hệ thống Tệp & Lưu trữ
### Cấu trúc thư mục gốc `/` (Filesystem Hierarchy)
- `/bin`: Tệp nhị phân và các lệnh thực thi cơ bản của hệ thống dành cho mọi người dùng.
- `/boot`: Các tệp thiết yếu để khởi động hệ điều hành (chứa Kernel, cấu hình Bootloader).
- `/dev`: Thư mục chứa các tệp thiết bị đại diện cho phần cứng (vd: ổ cứng gắn vào thường là `/dev/sda` hoặc `/dev/nvme0n1`).
- `/etc`: Thư mục cốt lõi nhất, nơi lưu trữ hầu hết các tệp cấu hình của hệ thống và phần mềm.
- `/home`: Thư mục cá nhân riêng biệt cho từng người dùng hệ thống (vd: `/home/vagrant`).
- `/lib`: Nơi chứa các thư viện chia sẻ (shared libraries) cần thiết cho các tệp nhị phân trong `/bin` và `/sbin`.
- `/media` & `/mnt`: Thư mục dùng làm điểm gắn kết (mount point) tạm thời cho các thiết bị lưu trữ như USB, ổ đĩa ngoài.
- `/opt`: Lưu trữ các gói phần mềm tùy chọn hoặc tiện ích của bên thứ ba không thuộc repository mặc định (vd: Docker, Containerd).
- `/proc`: Hệ thống tệp ảo chứa thông tin chi tiết về Kernel và các tiến trình (processes) đang chạy trên RAM.
- `/root`: Thư mục home riêng biệt của tài khoản đặc quyền Superuser (`root`).
- `/run`: Chứa dữ liệu trạng thái tạm thời của các ứng dụng, daemon từ lúc khởi động.
- `/sbin`: Công cụ quản trị hệ thống, thường chỉ người dùng có quyền root/sudo mới thực thi được.
- `/tmp`: Thư mục dành cho các tệp tin tạm thời, thường sẽ tự động bị xóa khi khởi động lại máy.
- `/usr`: Chứa các ứng dụng, mã nhị phân, tài liệu và mã nguồn do người dùng cài đặt thêm (nhất là trong `/usr/bin`).
- `/var`: Lưu trữ dữ liệu có tính thay đổi thường xuyên, quan trọng nhất là các tệp log hệ thống (`/var/log`).

### Quản lý Phần mềm (Package Management)
- Tùy thuộc vào bản phân phối Linux đang dùng:
- **Hệ Debian/Ubuntu (Sử dụng APT):**
  - `sudo apt update`: Đồng bộ/cập nhật danh sách gói mới nhất từ server.
  - `sudo apt install <tên_gói>`: Cài đặt phần mềm.
- **Hệ RHEL/CentOS/Rocky (Sử dụng YUM/DNF):** `sudo yum install <tên_gói>`.

### Quản lý Lưu trữ (Storage & Mounting)
- `lsblk`: Hiển thị cấu trúc cây của toàn bộ các khối thiết bị lưu trữ (ổ cứng, phân vùng) đang kết nối.
- `df -h`: Kiểm tra dung lượng trống/đã dùng trên toàn hệ thống tệp với định dạng dễ đọc (GB, MB).
- `du -sh <thư_mục>`: Tính toán và kiểm tra dung lượng mà một thư mục cụ thể đang chiếm dụng.
- **Gắn kết thiết bị lưu trữ (Mounting):**
  - `mount <thiết_bị> <thư_mục_đích>`: Gắn kết một phân vùng vào thư mục một cách thủ công (tạm thời).
  - **`/etc/fstab`:** Tệp cấu hình siêu quan trọng dùng để gắn kết ổ đĩa tự động khi hệ thống khởi động. Khi sửa file này, phải luôn chạy `sudo mount -a` để test lỗi cấu hình ngay lập tức thay vì khởi động lại bị kẹt.

## Ngày 17: Text Editors - nano vs vim
### nano (Trình soạn thảo cơ bản)
- Giao diện trực quan, hiển thị sẵn các phím tắt ở cuối màn hình. Cực kỳ thích hợp cho người mới dùng Linux để sửa file cấu hình nhanh.
- **Mở tệp:** `nano <tên_tệp>`.
- **Lưu và thoát:** Nhấn `Ctrl + O` (Để lưu/Write Out), nhấn `Enter` (Xác nhận tên file), sau đó nhấn `Ctrl + X` (Để thoát).

### vim (Trình soạn thảo nâng cao)
- Trình soạn thảo cực kỳ mạnh mẽ, dựa trên hệ thống phím tắt để tối ưu tốc độ gõ mà không cần dùng chuột. Gồm 4 chế độ hoạt động: Normal, Insert, Visual, Command.
- **Mở tệp:** `vim <tên_tệp>`. Mặc định sẽ vào **Normal Mode**.
- **Insert Mode (Chế độ gõ văn bản):** Bấm phím `i` (để chèn trước con trỏ) hoặc `a` (chèn sau con trỏ). Bấm `Esc` để thoát về chế độ Normal.
- **Command Mode (Lưu & Thoát):** Từ chế độ Normal, gõ `:` để vào Command Mode:
  - `:w` -> Lưu tệp.
  - `:q` -> Thoát tệp.
  - `:wq` hoặc phím tắt `ZZ` -> Lưu và thoát.
  - `:q!` -> Buộc thoát và hủy bỏ toàn bộ các thay đổi chưa lưu.
- **Tìm kiếm và Thay thế hàng loạt:** Dùng cú pháp `:%s/<từ_cũ>/<từ_mới>/g` (vd: `:%s/Day/90DaysOfDevOps/g` để thay từ "Day" bằng "90DaysOfDevOps" trên toàn bộ tệp).
- **Copy & Paste (Yank & Put):** `yy` (Sao chép 1 dòng), `p` (Dán xuống dưới con trỏ), `P` (Dán lên trên con trỏ).
- **Xóa/Cắt (Delete):** `dd` (Xóa/Cắt toàn bộ 1 dòng). Gõ `5dd` để xóa 5 dòng liên tiếp.
- **Hoàn tác (Undo/Redo):** Bấm `u` (Hoàn tác lệnh vừa làm), bấm `Ctrl + R` (Làm lại lệnh vừa hoàn tác).
- **Điều hướng (Trong Normal Mode):**
  - Không cần dùng phím mũi tên, dùng: `H` (Trái), `J` (Xuống), `K` (Lên), `L` (Phải).
  - Gõ `/<từ_khóa>` để tìm kiếm văn bản đi xuống, bấm `n` để di chuyển nhanh tới kết quả tiếp theo.

## Ngày 18: SSH & máy chủ web (LAMP)
### Giao thức SSH (Secure Shell)
- Giao thức mạng tiêu chuẩn của ngành để thiết lập kênh giao tiếp mã hóa, cho phép đăng nhập và điều khiển máy chủ Linux từ xa.
- **Kết nối cơ bản:** `ssh username@ip_address` (vd: `ssh ubuntu@192.168.1.10`).
- **Xác thực bằng SSH Keys (Không dùng mật khẩu):**
  - Tạo cặp khóa (Public/Private Key) trên máy cá nhân: `ssh-keygen -t rsa`.
  - Đẩy khóa Public lên máy chủ đích: `ssh-copy-id username@ip_address`.
- **Cấu hình Bảo mật (Security Hardening):** Mở tệp cấu hình `/etc/ssh/sshd_config`, tìm dòng `PasswordAuthentication yes` và sửa thành `no` để cấm tin tặc dò mật khẩu brute-force.
- **Áp dụng cấu hình:** Bắt buộc chạy lệnh `sudo systemctl restart sshd` để thay đổi có hiệu lực.

### Thiết lập LAMP Stack (Linux, Apache, MySQL, PHP)
- Bộ khung (stack) huyền thoại gồm 4 thành phần mã nguồn mở để thiết lập máy chủ lưu trữ và vận hành Website động.
- **L (Linux):** Hệ điều hành nền.
- **A (Apache):** Máy chủ xử lý luồng Web.
  - Cài đặt: `sudo apt install apache2`
  - Khởi động dịch vụ: `sudo systemctl start apache2` và `sudo systemctl enable apache2`.
- **M (MySQL/MariaDB):** Hệ quản trị cơ sở dữ liệu.
  - Cài đặt: `sudo apt install mysql-server`.
  - Khóa bảo mật mặc định: Chạy công cụ `sudo mysql_secure_installation`.
- **P (PHP):** Ngôn ngữ kịch bản xử lý logic backend, làm cầu nối giữa giao diện và Database.
  - Cài đặt module: `sudo apt install php libapache2-mod-php php-mysql`.
- **Thực hành:** Vận dụng toàn bộ ngăn xếp LAMP để tự triển khai, cấu hình CSDL và chạy thành công một trang web **WordPress** thực tế trên máy ảo.

## Ngày 19: Tự động hóa các tác vụ với các tập lệnh bash
### Khái niệm & Thiết lập Bash Script
- **Bash Scripting là gì:** Ngôn ngữ kịch bản giúp đóng gói nhiều câu lệnh terminal rời rạc thành một tệp duy nhất để tự động hóa, loại bỏ thao tác thủ công, tránh sai sót.
- **Shebang (Dòng khai báo):** Dòng đầu tiên của tệp script bắt buộc phải là `#!/bin/bash` hoặc `#!/usr/bin/env bash` để hệ thống biết trình thông dịch nào sẽ chạy mã.
- **Chú thích (Comments):** Dùng ký tự `#` ở đầu dòng để giải thích mã nguồn (không được thực thi).
- **Thực thi Script:**
  - Tệp bash mới tạo không có quyền chạy. Phải cấp quyền bằng: `chmod +x script.sh`.
  - Chạy script: `./script.sh`.

### Biến (Variables), Đối số và Đầu vào
- **Khai báo biến:** `ten_bien="Gia tri"` (Lưu ý: Không được có khoảng trắng quanh dấu `=`). Gọi biến bằng ký hiệu `$ten_bien` (vd: `echo $ten_bien`).
- **Nhập liệu từ người dùng (Input):** Sử dụng lệnh `read` (vd: `read -p "Vui lòng nhập tên của bạn: " username`).
- **Đối số dòng lệnh (Arguments):** Khả năng truyền dữ liệu từ bên ngoài vào trong kịch bản qua các biến `$1`, `$2`, `$3`... khi gọi lệnh.
  - Ví dụ: Chạy `./create_user.sh Michael MậtKhẩu123`.
  - Lúc này `$1` sẽ mang giá trị "Michael", `$2` mang giá trị "MậtKhẩu123".

### Cấu trúc điều khiển (Điều kiện)
- Sử dụng cú pháp `if - elif - else - fi` để phân nhánh logic xử lý:
  ```bash
  if [ "$username" == "Michael" ]; then
    echo "Xin chào quản trị viên Michael!"
  else
    echo "Người dùng không được ủy quyền."
  fi

## Thuật ngữ

- **Kernel:** Nhân hệ điều hành chịu trách nhiệm quản lý tài nguyên (CPU, memory, I/O) và giao tiếp phần cứng.
- **Distribution (Distro):** Phiên bản Linux phân phối kèm package manager và cấu hình riêng (Ubuntu, CentOS, Debian).
- **Shell:** Trình thông dịch dòng lệnh (bash, zsh) nhận và thực thi lệnh.
- **Daemon:** Tiến trình nền chạy liên tục, thường quản lý dịch vụ hệ thống.
- **systemd:** Hệ thống init hiện đại quản lý service, unit và boot process trên nhiều distro.
- **Process:** Tiến trình đang chạy, có PID, trạng thái, người sở hữu.
- **Inode:** Mô tả metadata của file (không phải tên file), lưu trữ location blocks trên đĩa.
- **Package Manager:** Công cụ cài/xóa/gỡ gói (apt, yum/dnf) cho việc quản lý phần mềm.
- **Permissions (rwx):** Quyền đọc/ghi/thực thi áp cho User/Group/Other, điều khiển truy cập file.
- **SSH Keys:** Cặp khoá dùng để xác thực không cần mật khẩu, an toàn hơn authentication bằng mật khẩu.
- **Shebang:** Dòng khai báo đầu script chỉ định interpreter (ví dụ `#!/bin/bash`).