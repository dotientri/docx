---
markmap:
    title: "DevOps Interview — Linux & Bash"
    collapse: false
---

# 🎯 DEVOPS INTERN INTERVIEW - LINUX & BASH (CHI TIẾT ĐẦY ĐỦ)

## Theory
- Kernel boot flow, process model, filesystems, permissions, and basic networking are essential Linux fundamentals for SRE/DevOps roles.

## Practice
- Include step-by-step diagnostic commands, common remediation actions (disk, processes), and scripts/examples for automation and monitoring.

## PHẦN 1: CÂU HỎI LÝ THUYẾT LINUX


### Q1. Giải thích quy trình boot của Linux từ đầu đến cuối?

**Trả lời chuẩn:**

```
BIOS/UEFI
  ↓
Tìm boot device (HDD/SSD/USB) theo thứ tự trong boot order
  ↓
MBR (Master Boot Record - 512 bytes đầu tiên của disk)
  ↓
GRUB (GRand Unified Bootloader)
  → Đọc /boot/grub/grub.cfg
  → Hiển thị menu chọn kernel
  ↓
Kernel được nạp vào RAM
  → Tự giải nén (vmlinuz là kernel nén)
  → Init hardware (CPU, memory, devices)
  ↓
initrd/initramfs (Initial RAM Disk)
  → Filesystem tạm thời trong RAM
  → Load drivers cần thiết để mount root filesystem
  ↓
Mount root filesystem (/)
  ↓
systemd (PID 1) - Init system
  → Đọc /etc/systemd/system/ và /lib/systemd/system/
  → Activate units theo dependency order
  → Target: multi-user.target (text mode) hoặc graphical.target (GUI)
  ↓
Getty/Login prompt
```

#### Câu hỏi follow-up thường gặp
- "Nếu server không boot được, bạn làm gì?" → Boot vào rescue mode (GRUB → `e` → thêm `rd.break`), mount filesystem và kiểm tra `/var/log/boot.log`
- "systemd là gì?" → Init system thay thế SysVinit, quản lý services (units), parallel startup


### Q2. File permissions trong Linux - giải thích chi tiết?

```
ls -la /etc/nginx/nginx.conf
-rw-r--r-- 1 root root 1234 May 17 10:00 nginx.conf
│├┤├┤├┤
││ │ │ └─ Other permissions
││ │ └─── Group permissions  
││ └───── User (owner) permissions
│└─────── File type: - (regular), d (dir), l (symlink), b (block), c (char)
└──────── (không dùng)

r = read    = 4
w = write   = 2
x = execute = 1

Ví dụ:
  rwxr-xr-x = 755 → Owner: 7(rwx), Group: 5(r-x), Others: 5(r-x)
  rw-r--r-- = 644 → Owner: 6(rw-), Group: 4(r--), Others: 4(r--)
  rwx------ = 700 → Owner: 7(rwx), Group: 0(---), Others: 0(---)
```

#### Các lệnh thực tế
```bash
# Thay đổi permissions
chmod 755 script.sh           # Octal
chmod u+x,g-w,o-r file.txt   # Symbolic
chmod -R 644 /var/www/html/   # Recursive

# Thay đổi owner
chown www-data:www-data /var/www/html
chown -R ubuntu:ubuntu /home/ubuntu/app

# SUID, SGID, Sticky bit
chmod +s /usr/bin/sudo    # SUID: chạy với quyền owner (root)
chmod g+s /shared-dir/    # SGID: files inherit group của dir
chmod +t /tmp/            # Sticky bit: chỉ owner mới xóa được file của mình

# Kiểm tra
stat file.txt             # Xem inode, permissions, timestamps
getfacl file.txt          # ACL (Access Control List) chi tiết hơn
```

## Trả lời khi được hỏi "Sự khác nhau giữa 777 và 755"
- `777`: Everyone có full quyền (read/write/execute) - **nguy hiểm**, thường chỉ dùng cho thư mục tmp tạm thời
- `755`: Owner toàn quyền, Group và Others chỉ read và execute - chuẩn cho scripts và thư mục web
- `644`: Owner read/write, Group và Others chỉ read - chuẩn cho config files


### Q3. Processes trong Linux?

```bash
# Xem processes
ps aux              # All processes (BSD style)
ps -ef              # All processes (UNIX style)
top                 # Real-time, sắp xếp theo CPU
htop                # Interactive (đẹp hơn)
pgrep nginx         # Tìm PID theo tên
pidof nginx         # PID của process nginx

# Process states:
R = Running
S = Sleeping (interruptible)
D = Disk sleep (uninterruptible - đang I/O)
Z = Zombie (đã chết, parent chưa wait)
T = Stopped
I = Idle

# Kill process
kill PID            # Gửi SIGTERM (15) - graceful shutdown
kill -9 PID         # Gửi SIGKILL - force kill (không catch được)
kill -HUP PID       # Reload config (nginx, sshd)
killall nginx        # Kill tất cả process tên nginx

# Background processes
command &           # Run in background
nohup command &     # Run và không bị kill khi terminal đóng
jobs                # List background jobs
fg %1               # Bring job 1 to foreground
bg %1               # Continue job 1 in background
disown %1           # Detach từ terminal

# Process priority (nice)
nice -n 10 command  # Run với priority thấp hơn (-20 highest, 19 lowest)
renice -n 5 PID     # Change priority của running process

# Xem file nào process đang mở
lsof -p PID
lsof /var/log/nginx/access.log   # Ai đang mở file này?

# Xem command của process
cat /proc/PID/cmdline | tr '\0' ' '
```


### Q4. Disk và Memory?

```bash
# ===== DISK =====
df -h               # Disk usage của mounted filesystems
df -h /             # Disk usage của root
du -sh /var/log/    # Thư mục /var/log tốn bao nhiêu
du -sh * | sort -rh | head -10   # Top 10 thư mục lớn nhất
lsblk               # List block devices
fdisk -l            # List partition info

# Tìm file lớn
find / -size +100M -type f 2>/dev/null | sort -k5 -rh
find /var -mtime -1 -size +10M   # Modified trong 1 ngày, lớn hơn 10M

# Kiểm tra inode (khi df -h còn space nhưng không tạo file được)
df -i               # Inode usage

# ===== MEMORY =====
free -h             # RAM overview
cat /proc/meminfo   # Chi tiết hơn
vmstat 1 5          # Memory stats mỗi 1s, 5 lần

# Swap
swapon --show       # Xem swap devices
swapoff /swapfile   # Disable swap
mkswap /swapfile    # Format as swap
swapon /swapfile    # Enable swap

# Tìm process tốn nhiều RAM
ps aux --sort=-%mem | head -10
cat /proc/PID/status | grep VmRSS   # RAM của specific process
```

## Câu hỏi hay gặp: "Server hết disk, bạn làm gì?"
```bash
# Step 1: Xác định vị trí
df -h               # Filesystem nào đầy?
du -sh /* | sort -rh | head -20   # Thư mục nào lớn nhất?
du -sh /var/* | sort -rh | head -10  # Đi sâu dần

# Step 2: Tìm nguyên nhân
find /var/log -name "*.log" -size +1G   # Log file lớn?
find /tmp -size +100M                    # Temp files?
docker system df                          # Docker images?
journalctl --disk-usage                  # systemd journal?

# Step 3: Xử lý
# Nếu log files lớn
truncate -s 0 /var/log/nginx/access.log  # Clear nội dung (không xóa file)
logrotate -f /etc/logrotate.conf          # Force rotate

# Nếu journal logs lớn
journalctl --vacuum-size=100M   # Chỉ giữ 100MB

# Nếu Docker
docker system prune -a --volumes   # Xóa unused images, containers, volumes

# Step 4: Phòng ngừa
# Cấu hình logrotate, monitoring disk usage
```


### Q5. Networking trên Linux?

```bash
# Xem network interfaces
ip addr             # Modern (thay ifconfig)
ip link show
ifconfig            # Old style

# Routing
ip route show       # Routing table
route -n            # Old style
traceroute google.com   # Trace network path
mtr google.com      # Real-time traceroute (more info)

# Ports và connections
ss -tlnp            # TCP listening ports + PID
ss -s               # Summary statistics
netstat -tlnp       # Old style
netstat -an | grep ESTABLISHED | wc -l   # Số connections đang active

# Firewall
ufw status          # Ubuntu Firewall
ufw allow 443/tcp
ufw deny from 192.168.1.100

iptables -L -n -v   # Raw iptables rules
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# DNS
nslookup google.com
dig google.com       # More detailed
dig @8.8.8.8 google.com   # Query specific DNS server
cat /etc/resolv.conf      # DNS config

# Network testing
ping -c 4 google.com     # ICMP ping
curl -v https://api.company.com/health   # HTTP test with headers
wget --spider https://company.com        # Check URL accessibility
nc -zv host 443          # Check TCP port (netcat)
telnet host 25           # Test SMTP

# Bandwidth test
iperf3 -s               # Server mode
iperf3 -c server-ip     # Client mode
```


### Q6. Systemd & Services?

```bash
# Service management
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx          # Reload config (không restart process)
systemctl status nginx          # Xem status + logs gần đây
systemctl enable nginx          # Auto-start khi boot
systemctl disable nginx
systemctl is-active nginx       # Exit 0 = active
systemctl is-enabled nginx

# List services
systemctl list-units --type=service --state=running
systemctl list-units --failed

# Logs
journalctl -u nginx             # Logs của nginx service
journalctl -u nginx -f          # Follow (real-time)
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx -n 100      # Last 100 lines
journalctl -p err               # Only errors
journalctl --since "2024-01-01" --until "2024-01-02"

# Tạo systemd service mới
cat > /etc/systemd/system/myapp.service << 'EOF'
[Unit]
Description=My Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server --config /etc/myapp/config.yaml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=APP_ENV=production
EnvironmentFile=/etc/myapp/environment

# Resource limits
LimitNOFILE=65536
MemoryMax=1G
CPUQuota=80%

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now myapp
```


### Q7. Bash Scripting?

#### Script kiểm tra service và alert - được hỏi rất nhiều
```bash
#!/usr/bin/env bash
# Script template chuyên nghiệp

# ===== SETUP =====
set -euo pipefail          # -e: exit on error, -u: undefined var error, -o pipefail
IFS=$'\n\t'                # Safer word splitting
trap 'cleanup' EXIT        # Run cleanup on any exit
trap 'error_handler $LINENO' ERR   # Handle errors

# ===== VARIABLES =====
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/script.log"
readonly SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
readonly MAX_RETRIES=3

# ===== FUNCTIONS =====
log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@" >&2; }
log_error() { log "ERROR" "$@" >&2; }

cleanup() {
    local exit_code=$?
    log_info "Cleanup complete (exit code: $exit_code)"
}

error_handler() {
    local line="$1"
    log_error "Error on line $line"
    send_alert "❌ Script failed on line $line"
    exit 1
}

send_alert() {
    local message="$1"
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-type: application/json' \
            -d "{\"text\": \"$message on $(hostname) at $(date)\"}" \
            > /dev/null
    fi
    log_warn "ALERT: $message"
}

check_service() {
    local service="$1"
    local retries=0
    
    while (( retries < MAX_RETRIES )); do
        if systemctl is-active --quiet "$service"; then
            log_info "Service $service is running"
            return 0
        fi
        
        (( retries++ ))
        log_warn "Service $service is down (attempt $retries/$MAX_RETRIES)"
        
        if (( retries < MAX_RETRIES )); then
            log_info "Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    # Failed after retries - try restart
    log_warn "Attempting to restart $service..."
    if systemctl restart "$service"; then
        log_info "Service $service restarted successfully"
        send_alert "⚠️ Service $service was down, restarted successfully"
        return 0
    else
        log_error "Failed to restart $service"
        send_alert "❌ Service $service is DOWN and failed to restart"
        return 1
    fi
}

disk_usage_check() {
    local threshold="${1:-80}"
    
    while IFS= read -r line; do
        local usage filesystem
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        filesystem=$(echo "$line" | awk '{print $6}')
        
        if (( usage > threshold )); then
            log_warn "Disk usage on $filesystem is $usage% (threshold: $threshold%)"
            send_alert "⚠️ Disk $filesystem is ${usage}% full"
        fi
    done < <(df -h | grep -vE '^Filesystem|tmpfs|devtmpfs|loop')
}

# ===== ARGUMENT PARSING =====
usage() {
    cat << EOF
Usage: $(basename "$0") [options]
Options:
  -s, --service SERVICE   Service name to monitor
  -t, --threshold NUM     Disk threshold percentage (default: 80)
  -h, --help              Show this help
EOF
}

main() {
    local service=""
    local threshold=80
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--service) service="$2"; shift 2 ;;
            -t|--threshold) threshold="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
    
    if [[ -z "$service" ]]; then
        log_error "Service name is required"
        usage
        exit 1
    fi
    
    log_info "Starting monitoring script"
    check_service "$service"
    disk_usage_check "$threshold"
    log_info "Done"
}

main "$@"
```


### Q8. Các lệnh quan trọng cần thuộc lòng?

```bash
# ===== TEXT PROCESSING =====
grep -r "ERROR" /var/log/              # Recursive search
grep -v "DEBUG" app.log                # Invert match (exclude)
grep -E "ERROR|WARN" app.log           # Extended regex
grep -c "ERROR" app.log                # Count matches
grep -n "pattern" file.txt             # Show line numbers
grep -A 5 "ERROR" app.log             # 5 lines After match
grep -B 2 "ERROR" app.log             # 2 lines Before match
grep -C 3 "ERROR" app.log             # 3 lines Context (both)

awk '{print $1, $4}' access.log                    # Print columns 1 and 4
awk -F: '{print $1}' /etc/passwd                   # Field separator ':'
awk '$9 >= 500 {print $0}' access.log              # HTTP 5xx errors
awk '{sum+=$10} END {print "Total:", sum}' file    # Sum column 10

sed 's/old/new/g' file.txt                # Replace globally
sed '/^#/d' config.conf                   # Delete comment lines
sed -n '10,20p' file.txt                  # Print lines 10-20
sed -i 's/localhost/prod-db.internal/g' config.yaml  # In-place edit

# Sort và unique
sort -k3 -n file.txt         # Sort by column 3, numeric
sort -rh sizes.txt            # Reverse, human-numeric
sort file.txt | uniq          # Unique lines
sort file.txt | uniq -c       # Count occurrences
sort file.txt | uniq -d       # Only duplicates

# Combine tools
cat access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
# → Top 20 IP addresses by request count

# ===== ARCHIVE & COMPRESSION =====
tar -czf backup.tar.gz /etc/nginx/      # Create compressed archive
tar -xzf backup.tar.gz -C /tmp/         # Extract to /tmp
tar -tzf backup.tar.gz                  # List contents without extracting
tar -czf - /data | ssh user@remote 'cat > /backup/data.tar.gz'  # Pipe over SSH

# ===== SSH =====
ssh -i ~/.ssh/key.pem user@host
ssh -L 8080:localhost:8080 user@remote  # Local port forward
ssh -R 9090:localhost:3000 user@remote  # Remote port forward
ssh -J bastion user@target              # Jump host (ProxyJump)
scp -r ./app user@host:/opt/
rsync -avz --delete ./app/ user@host:/opt/app/   # Sync (better than scp)

# SSH config (~/.ssh/config)
Host bastion
    HostName bastion.company.com
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519

Host prod-api
    HostName 10.0.1.10
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
```


## PHẦN 2: TÌNH HUỐNG THỰC TẾ (Scenario Questions)


### Tình huống 1: "Website đang chậm, bạn debug như thế nào?"

```bash
# 1. Kiểm tra server load
uptime              # Load average: 0.5, 1.2, 0.8 (1m, 5m, 15m)
top -bn1 | head -20 # Snapshot processes

# 2. Kiểm tra memory
free -h
# Nếu swap đang được dùng nhiều → app thiếu RAM hoặc memory leak

# 3. Kiểm tra disk I/O
iostat -xz 1 5      # Disk I/O stats
iotop               # Real-time disk I/O per process
# Tìm %util gần 100% → disk bottleneck

# 4. Kiểm tra network
ss -s               # Connection summary
netstat -an | grep ESTABLISHED | wc -l   # Active connections
# Nếu số connections quá cao → có thể bị DDoS hoặc connection leak

# 5. Kiểm tra application logs
journalctl -u myapp -n 100
tail -f /var/log/nginx/error.log

# 6. Kiểm tra database
# (Nếu có quyền)
SHOW PROCESSLIST;   # MySQL: đang chạy queries nào?
SELECT * FROM pg_stat_activity WHERE state = 'active';  # PostgreSQL

# 7. Kiểm tra external services
curl -o /dev/null -s -w "%{time_total}\n" https://api.thirdparty.com

# Kết luận và báo cáo: 
# "CPU ổn, Memory ổn, nhưng phát hiện disk I/O rất cao
#  do application đang write logs quá nhiều (DEBUG mode bật nhầm)"
```

### Tình huống 2: "Không SSH được vào server, bạn làm gì?"

```
1. Kiểm tra xem có thể ping không
   ping server-ip → Nếu không ping được → network issue hoặc server down

2. Kiểm tra từ phía cloud console
   Azure Portal/AWS Console → Check VM status → Start nếu stopped

3. Kiểm tra security group/NSG
   Port 22 có bị block không? IP của bạn có trong whitelist không?

4. Kiểm tra SSH service trên server
   Vào serial console (Azure: Boot diagnostics → Serial console)
   systemctl status sshd
   
5. Kiểm tra SSH key
   Đúng key không? Đúng username không?
   ssh -i ~/.ssh/correct_key user@server -v   # Verbose để debug

6. Kiểm tra /var/log/auth.log trên server
   (Cần access qua console)
   tail /var/log/auth.log | grep sshd

7. Nếu sshd crash: restart via serial console
   systemctl start sshd

8. Nếu disk full → sshd không thể ghi temp files → fail
   Xóa bớt file qua console để giải phóng space
```
