# ---
markmap:
    title: "Linux — systemd, Scripting & Security"
    collapse: false
# ---

# 🐧 LINUX TOÀN TẬP - PHẦN 5: SYSTEMD, SCRIPTING, CRON & BẢO MẬT

## Theory
- `systemd` modernizes service management with units and timers; scripting automates ops tasks; secure practices (least privilege, safe cron, hardening) reduce incidents.

## Practice
- Write `systemd` service and timer units, use `journalctl` for logs, craft idempotent shell scripts, and schedule with systemd timers or `cron` while following secure file permissions.

## 1. Systemd - Quản Lý Services

### 1.1 Systemd Là Gì?

Systemd là **init system** hiện đại (PID 1), thay thế SysV init cũ. Nó quản lý:
- Services (daemons)
- Mount points
- Devices
- Sockets
- Timers (thay thế cron)

### 1.2 systemctl - Quản Lý Services

```bash
# Xem trạng thái
systemctl status nginx            # Status của nginx
systemctl status                  # Tổng quan toàn hệ thống
systemctl list-units              # Tất cả units đang active
systemctl list-units --type=service  # Chỉ services
systemctl list-units --state=failed  # Services bị lỗi
systemctl list-unit-files         # Tất cả services (enabled/disabled)

# Bật/tắt service
systemctl start nginx             # Khởi động ngay
systemctl stop nginx              # Dừng ngay
systemctl restart nginx           # Dừng rồi khởi động lại
systemctl reload nginx            # Reload config (không restart, graceful)
systemctl reload-or-restart nginx # Reload nếu được, không thì restart

# Tự động khởi động khi boot
systemctl enable nginx            # Enable auto-start
systemctl disable nginx           # Disable auto-start
systemctl enable --now nginx      # Enable + start ngay luôn
systemctl disable --now nginx     # Disable + stop ngay

# Kiểm tra
systemctl is-active nginx         # active / inactive
systemctl is-enabled nginx        # enabled / disabled
systemctl is-failed nginx         # active / failed

# Mask service (không cho phép start kể cả thủ công)
systemctl mask bluetooth
systemctl unmask bluetooth
```

### 1.3 Viết Service File

```bash
# Service files nằm ở:
# /etc/systemd/system/         → User-defined services (ưu tiên cao)
# /lib/systemd/system/         → Package-installed services
# /usr/lib/systemd/system/     → System services

# Ví dụ: Service cho Python Flask app
sudo vim /etc/systemd/system/myapp.service
```

```ini
[Unit]
Description=My Flask Application
Documentation=https://github.com/company/myapp
After=network.target postgresql.service redis.service
Requires=postgresql.service
Wants=redis.service

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/myapp
Environment=FLASK_ENV=production
Environment=DB_HOST=localhost
EnvironmentFile=/etc/myapp/env      # Load từ file
ExecStart=/opt/myapp/venv/bin/gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 4 \
    --threads 2 \
    --timeout 120 \
    --access-logfile /var/log/myapp/access.log \
    --error-logfile /var/log/myapp/error.log \
    app:create_app()
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3

# Limits
LimitNOFILE=65536
LimitNPROC=65536

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/var/log/myapp /tmp

[Install]
WantedBy=multi-user.target
```

```bash
# Áp dụng service mới
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
sudo systemctl status myapp

# Xem logs của service
journalctl -u myapp -f            # Follow logs
journalctl -u myapp -n 100        # 100 dòng cuối
journalctl -u myapp --since today # Hôm nay
```

### 1.4 Systemd Timers (Thay Cron)

```bash
# Timer file (thay cron job)
sudo vim /etc/systemd/system/db-backup.service
```

```ini
[Unit]
Description=Database Backup
[Service]
Type=oneshot
User=postgres
ExecStart=/opt/scripts/backup-db.sh
```

```bash
sudo vim /etc/systemd/system/db-backup.timer
```

```ini
[Unit]
Description=Run database backup every day at 2AM

[Timer]
OnCalendar=*-*-* 02:00:00    # Mỗi ngày lúc 2 giờ sáng
OnCalendar=Mon-Fri 08:00     # Thứ 2-6 lúc 8 giờ
Persistent=true               # Chạy ngay nếu bỏ lỡ (máy đang tắt)

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable --now db-backup.timer
systemctl list-timers          # Xem tất cả timers
```


## 2. Shell Scripting

### 2.1 Cơ Bản

```bash
#!/bin/bash
# Shebang: Dòng đầu tiên, chỉ định interpreter

# Variables
NAME="World"
echo "Hello, $NAME!"
echo "Hello, ${NAME}!"   # Dùng {} khi cần phân biệt rõ ràng

# Command substitution
DATE=$(date +%Y-%m-%d)
FILES=$(ls /etc/*.conf | wc -l)
echo "Today: $DATE, Config files: $FILES"

# Arithmetic
A=10; B=3
echo $((A + B))      # 13
echo $((A * B))      # 30
echo $((A / B))      # 3 (integer division)
echo $((A % B))      # 1 (modulo)

# String operations
STR="Hello World"
echo ${#STR}          # 11 (độ dài)
echo ${STR:0:5}       # Hello (substring)
echo ${STR/World/Linux} # Hello Linux (replace)
echo ${STR^^}          # HELLO WORLD (uppercase)
echo ${STR,,}          # hello world (lowercase)

# Default values
DB_HOST=${DB_HOST:-localhost}     # Dùng localhost nếu DB_HOST chưa set
DB_PORT=${DB_PORT:=5432}          # Set DB_PORT=5432 nếu chưa có
echo "Connecting to ${DB_HOST}:${DB_PORT}"
```

### 2.2 Input, Output, Arguments

```bash
#!/bin/bash

# Script arguments
echo "Script name: $0"
echo "First arg: $1"
echo "Second arg: $2"
echo "All args: $@"
echo "Number of args: $#"

# Đọc input từ user
read -p "Enter your name: " USERNAME
read -sp "Enter password: " PASSWORD  # -s = silent (không hiện ký tự)
echo ""
echo "Hello, $USERNAME!"

# Đọc từ stdin (pipe)
while read -r line; do
    echo "Processing: $line"
done < /etc/passwd

# Read từ file
while IFS=: read -r user pass uid gid info home shell; do
    echo "User: $user, Home: $home, Shell: $shell"
done < /etc/passwd
```

### 2.3 Conditional Statements

```bash
#!/bin/bash

# if/elif/else
age=25
if [ $age -lt 18 ]; then
    echo "Minor"
elif [ $age -lt 65 ]; then
    echo "Adult"
else
    echo "Senior"
fi

# File/Directory tests
FILE="/etc/nginx/nginx.conf"
if [ -f "$FILE" ]; then
    echo "File exists"
fi
if [ -d "/etc/nginx" ]; then
    echo "Directory exists"
fi
if [ ! -f "/tmp/lockfile" ]; then
    echo "No lockfile, proceeding..."
fi

# Test operators:
# -f   → file exists
# -d   → directory exists
# -e   → exists (file or dir)
# -r   → readable
# -w   → writable
# -x   → executable
# -s   → file exists và không rỗng
# -z   → string empty
# -n   → string not empty

# String comparison
ENV="production"
if [ "$ENV" = "production" ]; then
    echo "Running in production!"
fi
if [[ "$ENV" == prod* ]]; then    # [[ ]] hỗ trợ pattern matching
    echo "Some production environment"
fi

# Numeric comparison
[ 5 -eq 5 ]    # equal
[ 5 -ne 4 ]    # not equal
[ 5 -lt 10 ]   # less than
[ 5 -le 5 ]    # less than or equal
[ 10 -gt 5 ]   # greater than
[ 10 -ge 10 ]  # greater than or equal

# Logical operators
if [ $age -gt 18 ] && [ "$ENV" = "production" ]; then
    echo "Adult in production"
fi
if [[ $age -gt 18 && "$ENV" == "production" ]]; then  # Cách hiện đại
    echo "Adult in production"
fi

# case statement
case "$1" in
    start)   systemctl start myapp ;;
    stop)    systemctl stop myapp ;;
    restart) systemctl restart myapp ;;
    status)  systemctl status myapp ;;
    *)       echo "Usage: $0 {start|stop|restart|status}" ;;
esac
```

### 2.4 Loops

```bash
#!/bin/bash

# for loop
for i in 1 2 3 4 5; do
    echo "Number: $i"
done

# for với range
for i in {1..10}; do
    echo "Item $i"
done

# for với step
for i in {0..100..10}; do  # 0, 10, 20, ..., 100
    echo $i
done

# for với array
SERVERS=("web01" "web02" "db01" "cache01")
for server in "${SERVERS[@]}"; do
    echo "Checking $server..."
    ssh $server "uptime"
done

# C-style for loop
for ((i=0; i<10; i++)); do
    echo $i
done

# while loop
COUNT=0
while [ $COUNT -lt 5 ]; do
    echo "Count: $COUNT"
    ((COUNT++))
done

# until loop (ngược với while)
until systemctl is-active --quiet nginx; do
    echo "Waiting for nginx to start..."
    sleep 2
done
echo "Nginx is up!"

# Loop qua output của command
for FILE in $(find /var/log -name "*.log" -mtime +30); do
    echo "Removing old log: $FILE"
    rm -f "$FILE"
done

# Loop qua dòng của file
while IFS= read -r line; do
    echo "Processing: $line"
done < servers.txt
```

### 2.5 Functions

```bash
#!/bin/bash

# Định nghĩa function
greet() {
    local name="$1"      # local = biến chỉ trong function
    local greeting="${2:-Hello}"  # Default value
    echo "$greeting, $name!"
}

# Gọi function
greet "World"
greet "Vietnam" "Xin chào"

# Function trả về giá trị
add() {
    local result=$(( $1 + $2 ))
    echo $result          # "return" bằng echo
}
SUM=$(add 5 3)
echo "Sum: $SUM"

# Return code
check_service() {
    if systemctl is-active --quiet "$1"; then
        return 0    # 0 = success
    else
        return 1    # Non-zero = failure
    fi
}

if check_service nginx; then
    echo "Nginx is running"
else
    echo "Nginx is NOT running"
fi

# Library functions (tái sử dụng)
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE" >&2; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" | tee -a "$LOG_FILE"; }
```

### 2.6 Error Handling (Quan Trọng!)

```bash
#!/bin/bash

# set -e: Exit ngay khi có lỗi
# set -u: Lỗi khi dùng biến chưa định nghĩa
# set -o pipefail: Pipe fail nếu bất kỳ command nào fail
# set -x: Debug mode (in mọi lệnh trước khi chạy)
set -euo pipefail

# Trap - Chạy cleanup khi script thoát
TMPDIR=$(mktemp -d)
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TMPDIR"
}
trap cleanup EXIT         # Chạy khi exit (dù lỗi hay không)
trap 'log_error "Failed at line $LINENO"' ERR  # Khi có lỗi

# Kiểm tra exit code thủ công
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

# Retry logic
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd=("$@")
    local attempt=1
    until "${cmd[@]}"; do
        if [ $attempt -ge $max_attempts ]; then
            echo "Command failed after $max_attempts attempts"
            return 1
        fi
        echo "Attempt $attempt failed. Retrying in ${delay}s..."
        sleep $delay
        ((attempt++))
    done
}

retry 3 5 curl -sf http://api.internal/health
```

### 2.7 Script Thực Tế: Deploy Script

```bash
#!/bin/bash
set -euo pipefail

# ============================================
# Deploy Script - Production
# Usage: ./deploy.sh <version>
# ============================================

# Configuration
APP_NAME="myapp"
DEPLOY_DIR="/opt/${APP_NAME}"
LOG_FILE="/var/log/${APP_NAME}/deploy.log"
BACKUP_DIR="/opt/backups/${APP_NAME}"
MAX_BACKUPS=5

# Functions
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE" >&2; }
die() { log_error "$*"; exit 1; }

# Checks
[ $# -eq 1 ] || die "Usage: $0 <version>"
VERSION="$1"
[ "$(id -u)" -eq 0 ] || die "Must run as root"

log_info "Starting deployment of ${APP_NAME}:${VERSION}"

# Backup current version
log_info "Creating backup..."
mkdir -p "$BACKUP_DIR"
if [ -d "$DEPLOY_DIR" ]; then
    BACKUP="${BACKUP_DIR}/${APP_NAME}-$(date +%Y%m%d%H%M%S).tar.gz"
    tar -czf "$BACKUP" -C "$(dirname $DEPLOY_DIR)" "$(basename $DEPLOY_DIR)"
    log_info "Backup created: $BACKUP"
    # Giữ chỉ MAX_BACKUPS backups gần nhất
    ls -t "${BACKUP_DIR}"/*.tar.gz | tail -n +$((MAX_BACKUPS+1)) | xargs -r rm -f
fi

# Pull Docker image
log_info "Pulling image ${APP_NAME}:${VERSION}..."
docker pull "registry.company.com/${APP_NAME}:${VERSION}" || die "Failed to pull image"

# Zero-downtime deployment
log_info "Updating service..."
docker service update \
    --image "registry.company.com/${APP_NAME}:${VERSION}" \
    --update-parallelism 1 \
    --update-delay 10s \
    "${APP_NAME}_web" || die "Service update failed"

# Health check
log_info "Waiting for health check..."
sleep 10
for i in {1..12}; do
    if curl -sf http://localhost/health >/dev/null; then
        log_info "Health check passed!"
        break
    fi
    [ $i -lt 12 ] || die "Health check failed after 60s"
    log_info "Health check attempt $i/12, retrying..."
    sleep 5
done

log_info "Deployment of ${APP_NAME}:${VERSION} completed successfully!"
```


## 3. Cron Jobs

### 3.1 Cron Syntax

```bash
# Cron format:
# * * * * * command
# │ │ │ │ └── Day of week (0-7, 0 và 7 = Sunday)
# │ │ │ └──── Month (1-12)
# │ │ └────── Day of month (1-31)
# │ └──────── Hour (0-23)
# └────────── Minute (0-59)

# Ví dụ:
0 2 * * *        # Mỗi ngày lúc 2:00 AM
*/5 * * * *      # Mỗi 5 phút
0 9-17 * * 1-5   # Mỗi giờ, từ 9-17h, thứ 2-6
0 0 1 * *        # Ngày đầu mỗi tháng lúc 00:00
30 23 * * 0      # 23:30 mỗi chủ nhật

# Shortcuts:
# @reboot    → Chạy khi boot
# @hourly    → 0 * * * *
# @daily     → 0 0 * * *
# @weekly    → 0 0 * * 0
# @monthly   → 0 0 1 * *
# @yearly    → 0 0 1 1 *
```

### 3.2 Quản Lý Crontab

```bash
# Sửa crontab của user hiện tại
crontab -e

# Sửa crontab của user khác (root)
crontab -e -u www-data

# Xem crontab
crontab -l
crontab -l -u postgres

# Xóa toàn bộ crontab
crontab -r

# Ví dụ crontab hoàn chỉnh:
# Backup database hàng đêm lúc 2AM
0 2 * * * /opt/scripts/backup-db.sh >> /var/log/backup.log 2>&1

# Cleanup temp files mỗi giờ
0 * * * * find /tmp -mtime +1 -delete

# Rotate logs hàng ngày
0 0 * * * /usr/sbin/logrotate /etc/logrotate.conf

# Check disk space mỗi 15 phút, alert nếu > 90%
*/15 * * * * /opt/scripts/check-disk.sh

# System-wide cron (/etc/cron.d/)
cat /etc/cron.d/myapp
# SHELL=/bin/bash
# PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# 0 2 * * * appuser /opt/myapp/scripts/cleanup.sh
```


## 4. Logrotate - Quản Lý Log Files

```bash
# /etc/logrotate.d/myapp
cat > /etc/logrotate.d/myapp << 'EOF'
/var/log/myapp/*.log {
    daily                    # Rotate hàng ngày
    missingok               # Không báo lỗi nếu file không tồn tại
    rotate 30               # Giữ 30 bản cũ
    compress                # Nén bằng gzip
    delaycompress           # Nén sau 1 chu kỳ (giữ file hiện tại uncompressed)
    notifempty              # Không rotate nếu file rỗng
    create 0640 appuser appgroup  # Tạo log file mới với permissions này
    sharedscripts           # Chỉ chạy scripts 1 lần dù nhiều files
    postrotate
        systemctl reload myapp >/dev/null 2>&1 || true
    endscript
}
EOF

# Test logrotate
sudo logrotate -d /etc/logrotate.d/myapp    # Dry-run (debug)
sudo logrotate -f /etc/logrotate.d/myapp    # Force rotate ngay
```


## 5. Bảo Mật Hệ Thống

### 5.1 SSH Hardening

```bash
# Fail2ban - Block IPs brute force
sudo apt install fail2ban

# /etc/fail2ban/jail.local
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600     # Ban 1 giờ
findtime = 600      # Trong 10 phút
maxretry = 5        # 5 lần fail

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400     # Ban SSH 24 giờ
EOF

sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd        # Xem bị ban IPs
sudo fail2ban-client set sshd unbanip 1.2.3.4  # Unban IP
```

### 5.2 Security Auditing

```bash
# Kiểm tra updates bảo mật
sudo apt list --upgradable 2>/dev/null | grep -i security

# Unattended security upgrades
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# Tìm files nguy hiểm
find / -perm -4000 -type f 2>/dev/null  # SUID files
find / -perm -2000 -type f 2>/dev/null  # SGID files
find / -perm -002 -type f 2>/dev/null   # World-writable files

# Check listening ports
ss -tlnp                                 # Có service lạ nào không?

# Check users có shell
grep -v "nologin\|false" /etc/passwd    # Users có thể login

# Check sudo access
cat /etc/sudoers
ls /etc/sudoers.d/

# Lynis - Security auditing tool
sudo apt install lynis
sudo lynis audit system
```

### 5.3 System Hardening Checklist

```bash
# 1. Disable root SSH login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# 2. Disable password auth (dùng keys)
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# 3. Tắt services không cần
systemctl disable avahi-daemon
systemctl disable cups
systemctl disable bluetooth

# 4. Set kernel parameters bảo mật
cat >> /etc/sysctl.conf << 'EOF'
# Disable IP forwarding (nếu không phải router)
net.ipv4.ip_forward = 0
# Protect against SYN flood
net.ipv4.tcp_syncookies = 1
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
EOF
sysctl -p

# 5. Limits cho users
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
```


## 6. Quick Reference - Lệnh Hay Quên

```bash
# ============ NAVIGATION ============
pwd; cd ~; cd -; ls -lah; tree -L 2

# ============ FILES ============
cp -av src/ dst/       # Verbose copy với metadata
mv -n src dst          # Move không ghi đè
rm -rf dir/            # XÓA KHÔNG KHÔI PHỤC ĐƯỢC
find . -name "*.py" -newer ref.txt  # Files mới hơn ref

# ============ TEXT ============
grep -rn "pattern" .               # Tìm recursive + số dòng
grep -E "error|warn" log --color   # Regex OR với màu
sed -i.bak 's/old/new/g' file     # Sửa file + backup
awk -F: '{print $1}' /etc/passwd  # In cột 1

# ============ PROCESS ============
ps aux | grep app                  # Tìm process
kill -9 $(pgrep -f "app.py")      # Kill theo tên
lsof -i :8080                     # Xem ai dùng port 8080
strace -p PID                     # Trace system calls

# ============ NETWORK ============
ss -tlnp                          # Listening ports
curl -sv http://url 2>&1          # Debug HTTP
ssh -L 5432:db:5432 user@jump     # Tunnel DB qua jump host
rsync -avz --delete src/ dst/     # Sync files

# ============ DISK ============
df -h; du -sh * | sort -rh        # Disk usage
lsblk -f                          # Block devices + filesystem

# ============ LOGS ============
journalctl -u nginx -f            # Follow service logs
tail -f /var/log/syslog | grep -v cron  # Tail + filter

# ============ USEFUL COMBOS ============
# Top 10 files to nhất
du -ah / 2>/dev/null | sort -rh | head -10

# Ports đang nghe + process name
ss -tlnp | awk 'NR>1 {print $4, $6}'

# IPs đang kết nối nhiều nhất
ss -tn | awk 'NR>1 {print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn

# Disk I/O nặng nhất
iostat -x 1 | grep -v "^$\|Device\|avg"

# History hay dùng
history | awk '{print $2}' | sort | uniq -c | sort -rn | head -20
```


## 7. Lộ Trình Học Tiếp Theo

```
Linux Cơ Bản (P1-P5) ✅
         │
    ┌────┴────┐
    ▼         ▼
 Scripting  Networking
 Nâng cao   Nâng cao
    │         │
    └────┬────┘
         ▼
   Vim/Neovim (Editor)
         │
    ┌────┴────────┐
    ▼             ▼
 Docker        Ansible
 (đã có)    (Config Mgmt)
    │             │
    └──────┬──────┘
           ▼
    Kubernetes/k3s
    (đã có guide)
```

### Tài Liệu Tham Khảo

| Tài liệu | Link |
|----------|------|
| Linux man pages | `man command` hoặc man7.org |
| The Linux Command Line | linuxcommand.org |
| Bash Scripting Guide | tldp.org/LDP/abs/html |
| Linux Filesystem FHS | pathname.com/fhs |
| ArchWiki | wiki.archlinux.org (tốt nhất!) |
