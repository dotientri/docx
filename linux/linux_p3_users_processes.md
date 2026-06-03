# ---
markmap:
  title: "Linux — Users, Permissions & Processes"
  collapse: false
# ---

# 🐧 LINUX TOÀN TẬP - PHẦN 3: USERS, PERMISSIONS, PROCESSES & MONITORING

## Theory
- User/group model, Unix permissions, ACLs, and process lifecycle underpin system security and multi-tenant isolation; monitoring processes and resources prevents outages.

## Practice
- Manage users with `useradd/usermod`, enforce least privilege via groups/sudoers, inspect processes with `ps/top/htop`, and monitor resources with `vmstat` and `sar`.

## 1. Quản Lý Users & Groups

### 1.1 Hiểu /etc/passwd và /etc/shadow

```bash
# /etc/passwd - Thông tin users (mọi người đọc được)
cat /etc/passwd
# Format: username:x:UID:GID:GECOS:home:shell
# Ví dụ:
# root:x:0:0:root:/root:/bin/bash
# nginx:x:33:33:www-data:/var/www:/usr/sbin/nologin
# tripheo:x:1000:1000:Trinh Pheo,,,:/home/tripheo:/bin/bash

# Giải thích:
# tripheo     → username
# x           → password (đã chuyển sang /etc/shadow)
# 1000        → UID (User ID) - user thường bắt đầu từ 1000
# 1000        → GID (Group ID) - primary group
# Trinh Pheo  → GECOS (full name, info)
# /home/tripheo → home directory
# /bin/bash   → login shell

# UIDs đặc biệt:
# 0           → root (superuser)
# 1-999       → System users (services)
# 1000+       → Regular users

# /etc/shadow - Password đã hash (chỉ root đọc được)
sudo cat /etc/shadow
# Format: username:hashed_password:lastchange:min:max:warn:inactive:expire
# tripheo:$6$salt$hashedpassword...:19742:0:99999:7:::
```

### 1.2 Tạo, Sửa, Xóa Users

```bash
# Tạo user
useradd username                     # Tạo user cơ bản
useradd -m username                  # Tạo kèm home directory (-m)
useradd -m -s /bin/bash -c "Full Name" username
useradd -m -s /bin/bash -G sudo,docker developer1
# -m: tạo home dir
# -s: chỉ định shell
# -c: comment/full name
# -G: thêm vào supplementary groups

# Tạo user hoàn chỉnh (cách khuyến nghị cho doanh nghiệp)
useradd \
  --create-home \
  --shell /bin/bash \
  --comment "John Doe - Backend Developer" \
  --groups sudo,docker,www-data \
  johndoe

# Set password
passwd username           # Set password cho user khác (cần root)
passwd                    # Đổi password của chính mình

# Thay đổi thông tin user
usermod -s /bin/zsh username          # Đổi shell
usermod -G docker,sudo username       # Set groups (THAY THẾ - mất groups cũ!)
usermod -aG docker username           # ADD vào group (an toàn hơn)
usermod -d /new/home -m username      # Đổi home directory
usermod -l newname oldname            # Đổi username
usermod -L username                   # Lock user (không login được)
usermod -U username                   # Unlock user

# Xóa user
userdel username                      # Xóa user (giữ home dir)
userdel -r username                   # Xóa user VÀ home directory

# Xem thông tin user
id username           # uid=1000(tripheo) gid=1000(tripheo) groups=...
id                    # Xem thông tin chính mình
whoami                # Tên user hiện tại
who                   # Ai đang login
w                     # Ai đang làm gì
last                  # Lịch sử login
last -n 20 username   # 20 lần login gần nhất của user cụ thể
```

### 1.3 Quản Lý Groups

```bash
# /etc/group - Thông tin groups
cat /etc/group
# Format: groupname:x:GID:members
# docker:x:998:tripheo,jenkins,ci

# Tạo group
groupadd developers
groupadd -g 2000 devteam    # Chỉ định GID cụ thể

# Thêm user vào group
usermod -aG groupname username      # -a = append (không xóa groups khác)
gpasswd -a username groupname       # Cách khác

# Xóa user khỏi group
gpasswd -d username groupname

# Xóa group
groupdel groupname

# Xem groups của user
groups username
id username

# QUAN TRỌNG: Sau khi thêm vào group, cần logout/login lại
# Hoặc dùng lệnh này để áp dụng ngay:
newgrp docker
```

### 1.4 sudo - Chạy Lệnh Với Quyền Root

```bash
# sudo - Substitute User DO
sudo command              # Chạy với quyền root
sudo -u otheruser command # Chạy với quyền của user khác
sudo -i                   # Mở shell root (interactive login shell)
sudo -s                   # Mở shell root (không load profile root)
sudo su -                 # Chuyển thành root user hoàn toàn

# Xem sudo privileges của mình
sudo -l

# /etc/sudoers - Cấu hình ai được sudo gì
sudo visudo               # LUÔN dùng visudo để sửa (kiểm tra syntax)

# Format của sudoers:
# user    hosts=(run_as) commands
# root    ALL=(ALL:ALL) ALL                → root có full quyền
# tripheo ALL=(ALL:ALL) ALL               → tripheo có full quyền
# tripheo ALL=(ALL:ALL) NOPASSWD:ALL      → không cần password
# developer ALL=/usr/bin/apt,/usr/bin/systemctl  → chỉ được dùng 2 lệnh

# File trong /etc/sudoers.d/ (cách tốt hơn - không sửa sudoers chính)
echo "developer ALL=(ALL) NOPASSWD: /usr/bin/docker" | \
  sudo tee /etc/sudoers.d/docker-developer

# Ví dụ thực tế doanh nghiệp:
# Cho team devops sudo đầy đủ không cần password
cat /etc/sudoers.d/devops
# %devops ALL=(ALL) NOPASSWD: ALL
# (% trước tên = group)
```


## 2. Phân Quyền Chi Tiết

### 2.1 chmod - Thay Đổi Permissions

```bash
# Numeric mode
chmod 755 script.sh         # rwxr-xr-x
chmod 644 config.txt        # rw-r--r--
chmod 600 private.key       # rw-------
chmod -R 755 directory/     # Recursive (cả thư mục con)

# Symbolic mode
chmod u+x script.sh         # Thêm execute cho owner (u = user/owner)
chmod g-w file.txt           # Bỏ write của group
chmod o-rwx private.txt      # Bỏ tất cả quyền của others
chmod a+r file.txt           # Thêm read cho ALL (a = all)
chmod u=rwx,g=rx,o=r file.txt # Set chính xác từng phần
chmod +x script.sh           # Thêm execute cho tất cả

# Umask - permission mặc định khi tạo file/dir
umask                        # Xem umask hiện tại (thường 022)
# File mặc định: 666 - 022 = 644 (rw-r--r--)
# Dir mặc định:  777 - 022 = 755 (rwxr-xr-x)
umask 027                    # Set umask: file=640, dir=750
```

### 2.2 chown & chgrp - Thay Đổi Owner

```bash
# chown - change owner
chown user file.txt                  # Đổi user owner
chown user:group file.txt            # Đổi cả user và group
chown :group file.txt                # Chỉ đổi group
chown -R user:group directory/       # Recursive

# chgrp - change group
chgrp developers file.txt
chgrp -R www-data /var/www/html/

# Ví dụ thực tế:
# Set quyền cho web application
chown -R www-data:www-data /var/www/myapp/
chmod -R 755 /var/www/myapp/
chmod -R 644 /var/www/myapp/*.php

# Set quyền cho private key
chown user:user ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh/
```

### 2.3 Special Permissions (SUID, SGID, Sticky Bit)

```bash
# SUID (Set User ID) - Chạy với quyền của OWNER file
# Ví dụ: /usr/bin/passwd cần quyền root để sửa /etc/shadow
ls -l /usr/bin/passwd
# -rwsr-xr-x root root /usr/bin/passwd
# ↑ 's' thay cho 'x' ở vị trí owner execute = SUID

chmod u+s file           # Set SUID
chmod 4755 file          # Set SUID bằng octal (thêm 4 ở đầu)

# SGID (Set Group ID) - Chạy với quyền của GROUP file
# Trên directory: files tạo trong dir kế thừa group của dir
ls -l /usr/bin/locate
# -rwxr-sr-x root slocate /usr/bin/locate
#       ↑ 's' ở group execute = SGID

chmod g+s directory/     # Set SGID trên directory
chmod 2755 directory/    # Set SGID bằng octal

# Sticky Bit - Chỉ owner file mới xóa được file của mình
# Dùng trên shared directories như /tmp
ls -ld /tmp
# drwxrwxrwt root root /tmp
#          ↑ 't' = sticky bit

chmod +t directory/      # Set sticky bit
chmod 1777 directory/    # Set sticky bit bằng octal

# Tìm files có SUID (security audit)
find / -perm -u+s -type f 2>/dev/null
find / -perm /4000 -type f 2>/dev/null
```

### 2.4 ACL - Access Control Lists (Nâng Cao)

```bash
# ACL cho phép set quyền chi tiết hơn cho nhiều users/groups
# Cài: sudo apt install acl

# Xem ACL
getfacl file.txt

# Set ACL cho user cụ thể
setfacl -m u:developer1:rw file.txt     # developer1 có quyền rw
setfacl -m g:developers:rx directory/  # group developers có rx
setfacl -m o::- file.txt               # Others không có quyền gì

# Default ACL (áp dụng cho files tạo mới trong directory)
setfacl -d -m g:developers:rw /project/

# Xóa ACL
setfacl -x u:developer1 file.txt
setfacl -b file.txt                     # Xóa tất cả ACL

# Ví dụ thực tế: Shared project directory
setfacl -R -m g:team1:rwx /projects/myapp/
setfacl -R -d -m g:team1:rwx /projects/myapp/
```


## 3. Process Management

### 3.1 Xem Processes

```bash
# ps - process snapshot
ps                      # Chỉ processes của shell hiện tại
ps aux                  # TẤT CẢ processes (a=all users, u=user format, x=no tty)
ps aux | grep nginx     # Lọc theo tên
ps -ef                  # Full format (hiện parent PID)
ps -ef --forest         # Hiện dạng cây (parent → child)
ps -p 1234              # Xem process cụ thể theo PID
ps --sort=-%cpu | head  # Sort theo CPU usage

# Giải thích cột ps aux:
# USER   PID  %CPU  %MEM   VSZ    RSS   TTY   STAT  START  TIME  COMMAND
# root     1   0.0   0.1  16952  4456   ?     Ss   Jan01   0:05  /sbin/init

# STAT codes:
# R = Running
# S = Sleeping (interruptible)
# D = Disk sleep (uninterruptible - đang đợi I/O)
# Z = Zombie (đã chết nhưng parent chưa "nhận xác")
# T = Stopped
# s = Session leader
# l = Multi-threaded
# + = Foreground process group

# top - real-time process monitor
top
# Trong top:
# q = quit
# k = kill process (nhập PID)
# r = renice (đổi priority)
# 1 = hiện từng CPU core
# M = sort theo Memory
# P = sort theo CPU (mặc định)

# htop - phiên bản đẹp hơn top (cài thêm)
sudo apt install htop
htop

# pgrep - tìm PID theo tên
pgrep nginx              # 1234 5678 (danh sách PIDs)
pgrep -l nginx           # 1234 nginx
pgrep -a nginx           # 1234 nginx: master process /usr/sbin/nginx

# pidof - tìm PID
pidof nginx
pidof -x script.sh       # Kể cả scripts
```

### 3.2 Kill Processes

```bash
# kill - gửi signal đến process
kill PID                 # Gửi SIGTERM (15) - graceful shutdown
kill -9 PID              # Gửi SIGKILL - force kill (không thể ignore)
kill -l                  # Liệt kê tất cả signals

# Các signals quan trọng:
# SIGTERM (15) → Yêu cầu terminate (có thể bắt và xử lý)
# SIGKILL (9)  → Force kill (KHÔNG THỂ bắt/ignore)
# SIGHUP  (1)  → Reload (nginx: reload config, không restart)
# SIGINT  (2)  → Interrupt (Ctrl+C)
# SIGSTOP (19) → Pause process
# SIGCONT (18) → Continue paused process

# Gửi signal bằng tên
kill -SIGTERM 1234
kill -SIGHUP $(pgrep nginx)     # Reload nginx

# killall - kill theo tên
killall nginx
killall -9 firefox
killall -SIGHUP sshd

# pkill - kill theo pattern
pkill nginx
pkill -9 -u tripheo     # Kill tất cả processes của user tripheo
pkill -f "python app.py"  # Kill theo command line

# Thứ tự nên thử:
# 1. kill PID (SIGTERM - graceful)
# 2. Chờ 5-10 giây
# 3. kill -9 PID (SIGKILL - nếu vẫn còn)
```

### 3.3 Background & Foreground Jobs

```bash
# Chạy command ở background
command &                    # Chạy ngầm, thoát khi terminal đóng
nohup command &              # Chạy ngầm, tiếp tục kể cả khi logout
nohup command > output.log 2>&1 &

# Job control
jobs                         # Xem danh sách jobs
fg                           # Đưa job về foreground (job gần nhất)
fg %1                        # Đưa job số 1 về foreground
bg                           # Tiếp tục job ở background
bg %2                        # Tiếp tục job số 2 ở background

# Workflow thường dùng:
command                      # Chạy foreground
# Ctrl+Z                     → Pause và đưa vào background
bg                           # Tiếp tục chạy ngầm
# Ctrl+C                     → Kết thúc foreground process

# disown - tách job khỏi terminal
command &
disown %1                    # Job tiếp tục chạy kể cả đóng terminal

# screen / tmux - terminal multiplexer (QUAN TRỌNG!)
# Tạo session persistent, không mất khi mất kết nối SSH
screen -S mysession          # Tạo session tên "mysession"
# Ctrl+A, D                  → Detach (thoát nhưng giữ session)
screen -ls                   # Liệt kê sessions
screen -r mysession          # Attach lại

# tmux (hiện đại hơn screen)
tmux new -s deploy           # Tạo session "deploy"
# Ctrl+B, D                  → Detach
tmux ls                      # Liệt kê sessions
tmux attach -t deploy        # Attach lại
```

### 3.4 Process Priority (nice & renice)

```bash
# Nice value: -20 (cao nhất) đến +19 (thấp nhất)
# Mặc định = 0

# Chạy process với priority thấp
nice -n 10 command          # Nice value = 10 (nhường CPU cho các process khác)
nice -n 19 backup.sh        # Rất thấp (backup không ảnh hưởng production)

# Đổi priority của process đang chạy
renice -n 5 -p 1234         # Set nice = 5 cho PID 1234
renice -n -5 -p 1234        # Tăng priority (cần root)
renice -n 15 -u tripheo     # Giảm priority tất cả processes của user

# Trong thực tế:
# Chạy backup với priority thấp để không ảnh hưởng production
nice -n 19 tar -czvf backup.tar.gz /var/lib/database/ &
```


## 4. System Monitoring

### 4.1 CPU Monitoring

```bash
# top / htop (xem phần 3.1)

# vmstat - virtual memory statistics
vmstat 1 5                  # Cập nhật mỗi 1 giây, 5 lần
# Kết quả:
# procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
#  2  0      0 2048000  52000 1500000    0    0     0   100  500 1000 30  5 60  5  0
# r = running/waiting processes
# b = blocked processes (đợi I/O)
# us = user CPU %, sy = system CPU %, id = idle %, wa = I/O wait %

# mpstat - per-CPU statistics
sudo apt install sysstat
mpstat -P ALL 1 5           # Xem từng CPU core, 5 giây

# sar - system activity reporter
sar -u 1 5                  # CPU usage
sar -r 1 5                  # Memory usage
sar -d 1 5                  # Disk I/O
```

### 4.2 Memory Monitoring

```bash
# free
free -h                     # Human readable
free -m                     # MB
free -s 5                   # Cập nhật mỗi 5 giây

# Kết quả free -h:
#               total        used        free      shared  buff/cache   available
# Mem:           15Gi        5.2Gi       2.1Gi       300Mi       8.0Gi       9.5Gi
# Swap:          2.0Gi          0B       2.0Gi

# QUAN TRỌNG: "available" không phải "free"!
# available = free + buff/cache có thể giải phóng
# Linux dùng RAM dư để cache → "free" nhỏ là BÌNH THƯỜNG

# /proc/meminfo - chi tiết hơn
cat /proc/meminfo
grep -E "MemTotal|MemFree|MemAvailable|Cached|Buffers" /proc/meminfo

# smem - xem memory thực sự dùng bởi mỗi process
sudo apt install smem
smem -r | head -20          # Sort theo RSS
smem -p | head -20          # Sort theo PSS (chính xác hơn)
```

### 4.3 Disk Monitoring

```bash
# df - disk filesystem usage
df -h                       # Tất cả filesystems
df -h /                     # Chỉ root
df -i                       # Inode usage (quan trọng!)

# du - disk usage của files/directories
du -sh /var/log             # Size của /var/log
du -sh /var/log/*           # Size từng thứ
du -h --max-depth=2 /       # 2 cấp sâu từ /

# Tìm files to nhất
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20

# iostat - I/O statistics
iostat -x 1 5               # Extended stats, 1 giây/lần, 5 lần
# %util gần 100% = disk đang quá tải

# iotop - xem process nào đang read/write nhiều nhất
sudo apt install iotop
sudo iotop -o               # Chỉ hiện processes đang có I/O
```

### 4.4 Network Monitoring

```bash
# ss - socket statistics (thay thế netstat)
ss -tlnp                    # TCP, Listening, Numeric, with Process
ss -ulnp                    # UDP
ss -s                       # Summary
ss -t state established     # TCP connections đang established

# netstat (cũ hơn nhưng vẫn dùng)
netstat -tlnp               # TCP listening ports với process
netstat -an                 # Tất cả connections
netstat -rn                 # Routing table

# Ví dụ thực tế: Xem gì đang lắng nghe port nào
ss -tlnp | grep LISTEN
# LISTEN  0  128  0.0.0.0:22    0.0.0.0:*  users:(("sshd",pid=1234))
# LISTEN  0  128  0.0.0.0:80    0.0.0.0:*  users:(("nginx",pid=5678))
# LISTEN  0  128  127.0.0.1:5432 0.0.0.0:*  users:(("postgres",pid=9012))

# Xem connections đến port cụ thể
ss -tnp | grep :443

# iftop - bandwidth per connection
sudo apt install iftop
sudo iftop -i eth0

# nload - bandwidth theo interface
sudo nload eth0

# nethogs - bandwidth per process
sudo apt install nethogs
sudo nethogs eth0
```

### 4.5 Xem Logs Hệ Thống

```bash
# journalctl - systemd journal (hiện đại)
journalctl                           # Tất cả logs
journalctl -f                        # Follow (real-time)
journalctl -n 100                    # 100 dòng cuối
journalctl -u nginx                  # Logs của service nginx
journalctl -u nginx --since today    # Hôm nay
journalctl --since "2024-01-15 10:00:00" --until "2024-01-15 12:00:00"
journalctl -p err                    # Chỉ errors (emerg, alert, crit, err)
journalctl -p warning                # Warning trở lên
journalctl --disk-usage              # Xem journal chiếm bao nhiêu disk

# Log files cổ điển
tail -f /var/log/syslog              # System logs
tail -f /var/log/auth.log            # Authentication logs
tail -f /var/log/nginx/error.log     # Nginx errors
tail -f /var/log/mysql/error.log     # MySQL errors

# Phân tích log nhanh
grep "ERROR" /var/log/app.log | wc -l                         # Số lỗi
grep "ERROR" /var/log/app.log | tail -20                      # 20 lỗi gần nhất
awk '/ERROR/{print $0}' /var/log/app.log | sort | uniq -c    # Group lỗi
```


## 5. Package Management

### 5.1 APT (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Upgrade packages
sudo apt upgrade                    # Upgrade tất cả (an toàn)
sudo apt full-upgrade               # Upgrade kể cả thay đổi dependencies
sudo apt dist-upgrade               # Tương tự full-upgrade

# Cài package
sudo apt install nginx
sudo apt install -y nginx           # Không hỏi yes/no
sudo apt install nginx=1.25.0       # Version cụ thể

# Gỡ package
sudo apt remove nginx               # Gỡ nhưng giữ config
sudo apt purge nginx                # Gỡ kể cả config
sudo apt autoremove                 # Xóa dependencies không cần nữa

# Tìm kiếm package
apt search nginx
apt-cache search "web server"
apt show nginx                      # Xem thông tin package

# Liệt kê packages
apt list --installed                # Packages đã cài
apt list --upgradable               # Packages có thể upgrade

# Dọn dẹp
sudo apt clean                      # Xóa downloaded packages
sudo apt autoclean                  # Xóa packages lỗi thời

# Thực tế: Cài một stack web
sudo apt update && sudo apt install -y \
    nginx \
    postgresql \
    redis-server \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    vim \
    htop \
    net-tools
```

### 5.2 DNF/YUM (RHEL/Rocky/Fedora)

```bash
# Update
sudo dnf update

# Cài package
sudo dnf install nginx
sudo dnf install -y nginx

# Gỡ package
sudo dnf remove nginx

# Tìm kiếm
dnf search nginx
dnf info nginx

# Liệt kê
dnf list installed
dnf list available

# Groups (cài nhiều packages liên quan)
dnf grouplist
dnf groupinstall "Development Tools"
```

### 5.3 Cài Phần Mềm Không Qua Package Manager

```bash
# Cách 1: Download binary trực tiếp
wget https://github.com/example/releases/download/v1.0/tool-linux-amd64
chmod +x tool-linux-amd64
sudo mv tool-linux-amd64 /usr/local/bin/tool

# Cách 2: Compile từ source
wget https://example.com/source-1.0.tar.gz
tar xzf source-1.0.tar.gz
cd source-1.0/
./configure --prefix=/usr/local
make
sudo make install

# Cách 3: Snap (Ubuntu)
sudo snap install code --classic

# Cách 4: Flatpak
flatpak install flathub org.gimp.GIMP

# Cách 5: Script cài đặt (phổ biến)
curl -fsSL https://get.docker.com | sh
```
