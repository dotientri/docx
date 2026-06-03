# ---
markmap:
  title: "Linux — Networking, SSH & Storage"
  collapse: false
# ---

# 🐧 LINUX TOÀN TẬP - PHẦN 4: NETWORKING, SSH & STORAGE

## Theory
- Networking basics (interfaces, routing, DNS) and secure remote access (SSH) are crucial; storage management uses mounts, filesystems, and LVM for durable data.

## Practice
- Use `ip`, `netplan`/`nmcli`, `dig/nslookup`, `tcpdump`, and `rsync`; secure SSH with keys, disable password auth, and manage disks with `lsblk`, `mount`, and LVM tools.

## 1. Networking Cơ Bản

### 1.1 Xem Thông Tin Network

```bash
# ip command (hiện đại, thay thế ifconfig)
ip addr                      # Xem tất cả interfaces và IPs
ip addr show eth0            # Chỉ interface eth0
ip link                      # Xem trạng thái interfaces
ip route                     # Xem routing table
ip route show default        # Default gateway

# ifconfig (cũ hơn, vẫn dùng nhiều)
sudo apt install net-tools
ifconfig                     # Xem tất cả
ifconfig eth0                # Chỉ eth0

# Tên interface phổ biến:
# eth0, eth1     → Ethernet (cũ)
# ens3, ens4     → Ethernet (naming mới - systemd)
# enp3s0         → Ethernet (PCI bus naming)
# wlan0, wlp2s0  → WiFi
# lo             → Loopback (127.0.0.1)
# docker0        → Docker bridge
# tun0           → VPN tunnel

# Xem hostname
hostname                     # Tên máy
hostname -I                  # Tất cả IPs
hostname -f                  # Fully qualified domain name (FQDN)

# Thông tin network interfaces
cat /proc/net/dev            # Statistics (bytes, packets, errors)
ethtool eth0                 # Chi tiết interface (speed, duplex...)
```

### 1.2 Cấu Hình IP

```bash
# Xem IP hiện tại
ip addr show eth0

# Thêm IP tạm thời (mất sau reboot)
sudo ip addr add 192.168.1.100/24 dev eth0
sudo ip addr del 192.168.1.100/24 dev eth0

# Thêm route tạm thời
sudo ip route add 10.0.0.0/8 via 192.168.1.1
sudo ip route del 10.0.0.0/8

# Cấu hình IP vĩnh viễn (Ubuntu/Debian - Netplan)
sudo vim /etc/netplan/01-network-manager-all.yaml
```

```yaml
# /etc/netplan/01-network-manager-all.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4, 1.1.1.1]
```

```bash
# Áp dụng config
sudo netplan apply

# RHEL/Rocky - nmcli
nmcli connection show
nmcli device status
nmcli con modify "Wired connection 1" \
  ipv4.addresses "192.168.1.100/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8,8.8.4.4" \
  ipv4.method manual
nmcli con up "Wired connection 1"
```

### 1.3 DNS & Name Resolution

```bash
# /etc/hosts - Local DNS (ưu tiên hơn DNS server)
cat /etc/hosts
# 127.0.0.1    localhost
# 192.168.1.10 db.internal db
# 192.168.1.20 cache.internal redis

# Thêm vào /etc/hosts (thực tế hay dùng khi dev)
echo "192.168.1.10 myapp.local" | sudo tee -a /etc/hosts

# /etc/resolv.conf - DNS servers
cat /etc/resolv.conf
# nameserver 8.8.8.8
# nameserver 8.8.4.4
# search company.internal

# Kiểm tra DNS resolution
nslookup google.com               # Query DNS
nslookup google.com 8.8.8.8      # Query DNS server cụ thể
dig google.com                    # Chi tiết hơn
dig @8.8.8.8 google.com A        # Query A record từ server cụ thể
dig google.com MX                 # Mail records
host google.com                   # Đơn giản hơn dig

# Thứ tự resolution (/etc/nsswitch.conf)
grep hosts /etc/nsswitch.conf
# hosts: files dns   → Kiểm tra /etc/hosts trước, sau mới DNS
```

### 1.4 Kiểm Tra Kết Nối

```bash
# ping
ping google.com                   # Ping liên tục
ping -c 5 google.com             # Chỉ 5 lần
ping -i 0.2 google.com           # Interval 0.2 giây
ping -s 1400 google.com          # Packet size 1400 bytes

# traceroute - xem đường đi của packets
traceroute google.com
tracepath google.com             # Không cần root
mtr google.com                   # Real-time traceroute (cài thêm)

# curl - test HTTP endpoints (rất quan trọng!)
curl http://example.com                      # GET request
curl -I http://example.com                   # Chỉ headers (HEAD)
curl -v http://example.com                   # Verbose (debug)
curl -X POST http://api.example.com/data \  # POST
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
curl -u user:pass http://protected.com      # Basic auth
curl -L http://example.com                  # Follow redirects
curl -o output.txt http://example.com       # Save to file
curl -s http://example.com | jq            # Parse JSON output
curl --max-time 10 http://api.example.com   # Timeout 10 giây

# Thực tế: Test API health
curl -sf http://localhost:8080/health && echo "OK" || echo "FAIL"

# wget - download files
wget http://example.com/file.tar.gz
wget -O output.tar.gz http://example.com/file.tar.gz
wget -r -np http://example.com/dir/         # Download recursive
wget -q --spider http://url                 # Check URL không download

# nc (netcat) - Swiss Army Knife của networking
nc -zv hostname 22                          # Kiểm tra port có mở không
nc -zv 192.168.1.1 1-100                   # Scan ports 1-100
nc -l 1234                                  # Listen trên port 1234
nc hostname 1234                            # Connect đến port

# telnet (kiểm tra port cũ hơn)
telnet hostname 80
# Ctrl+] rồi quit để thoát
```


## 2. SSH - Secure Shell

### 2.1 SSH Cơ Bản

```bash
# Kết nối SSH
ssh username@hostname
ssh username@192.168.1.10
ssh username@hostname -p 2222          # Port khác (mặc định 22)
ssh -i ~/.ssh/mykey.pem user@host     # Dùng private key cụ thể

# SSH với verbose (debug khi gặp vấn đề)
ssh -v user@host                       # Verbose (1 level)
ssh -vvv user@host                     # Very verbose (3 levels)

# Chạy lệnh remote không cần vào shell
ssh user@host "ls -la /var/log"
ssh user@host "cat /etc/nginx/nginx.conf"
ssh user@host "sudo systemctl restart nginx"

# Copy files qua SSH
scp file.txt user@host:/remote/path/       # Copy lên server
scp user@host:/remote/file.txt .           # Copy từ server về
scp -r directory/ user@host:/remote/       # Copy thư mục
scp -P 2222 file.txt user@host:/path/      # Port khác

# rsync - sync files (thông minh hơn scp, chỉ copy phần thay đổi)
rsync -avz source/ user@host:/dest/        # Archive, verbose, compress
rsync -avz --delete source/ user@host:/dest/  # Delete files không có ở source
rsync -avz --progress source/ user@host:/dest/ # Hiện progress
rsync -avz -e "ssh -p 2222" source/ user@host:/dest/  # SSH port khác
rsync -n source/ user@host:/dest/          # Dry-run (không thực sự copy)

# Thực tế: Backup server hàng ngày
rsync -avz --delete \
  --exclude='*.tmp' \
  --exclude='logs/' \
  /var/www/myapp/ \
  backup@backupserver:/backups/myapp/
```

### 2.2 SSH Keys - Xác Thực Không Cần Password

```bash
# Tạo SSH key pair
ssh-keygen -t ed25519 -C "your@email.com"
# Hoặc RSA (phổ biến hơn, tương thích rộng)
ssh-keygen -t rsa -b 4096 -C "your@email.com"

# Kết quả tạo ra 2 files:
# ~/.ssh/id_ed25519      → Private key (KHÔNG ĐƯỢC SHARE, bảo mật như password)
# ~/.ssh/id_ed25519.pub  → Public key (có thể share tự do)

# Copy public key lên server
ssh-copy-id user@hostname                  # Tự động thêm vào authorized_keys
ssh-copy-id -i ~/.ssh/mykey.pub user@host # Key cụ thể

# Cách thủ công
cat ~/.ssh/id_ed25519.pub | ssh user@host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Permissions quan trọng (PHẢI đúng, không sẽ SSH từ chối)
chmod 700 ~/.ssh/
chmod 600 ~/.ssh/id_ed25519          # Private key
chmod 644 ~/.ssh/id_ed25519.pub      # Public key
chmod 600 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts

# SSH Agent - giữ private key trong memory
eval $(ssh-agent)                    # Khởi động agent
ssh-add ~/.ssh/id_ed25519            # Thêm key vào agent
ssh-add -l                           # Liệt kê keys trong agent
ssh-add -D                           # Xóa tất cả keys khỏi agent
```

### 2.3 SSH Config File (~/.ssh/config)

```bash
# ~/.ssh/config - Định nghĩa aliases và config cho các hosts
# Sau khi cấu hình, chỉ cần gõ: ssh prod

# Ví dụ hoàn chỉnh:
cat ~/.ssh/config
```

```
# Default settings cho tất cả
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes

# Production server
Host prod
    HostName 203.0.113.10
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/prod_key.pem
    ForwardAgent no

# Staging server
Host staging
    HostName 203.0.113.20
    User deploy
    IdentityFile ~/.ssh/staging_key

# Database server (chỉ access qua jump host)
Host db-prod
    HostName 10.0.0.100        # Private IP
    User postgres
    ProxyJump prod             # Jump qua prod server trước
    IdentityFile ~/.ssh/db_key

# Development VMs
Host dev-*
    User vagrant
    IdentityFile ~/.vagrant.d/insecure_private_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Bastion host
Host bastion
    HostName bastion.company.com
    User ec2-user
    IdentityFile ~/.ssh/company_key.pem
    ForwardAgent yes            # Forward SSH agent qua bastion

# Internal servers qua bastion
Host internal-*
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/company_key.pem
```

### 2.4 SSH Tunneling (Port Forwarding)

```bash
# Local Port Forwarding: Truy cập service remote qua localhost
# Trường hợp: DB trên server remote chỉ listen localhost:5432
ssh -L 5432:localhost:5432 user@remote-server
# Bây giờ kết nối đến localhost:5432 trên máy local sẽ được forward đến remote:5432

# Ví dụ thực tế: Access database production
ssh -L 15432:db.internal:5432 user@bastion.company.com
# Sau đó kết nối: psql -h localhost -p 15432 -U postgres

# Remote Port Forwarding: Expose local service ra ngoài
ssh -R 8080:localhost:3000 user@remote-server
# Service local :3000 được expose thành remote:8080

# Dynamic Port Forwarding (SOCKS proxy)
ssh -D 1080 user@remote-server
# Cấu hình browser dùng SOCKS5 proxy localhost:1080
# → Tất cả traffic qua remote server

# Tạo tunnel persistent (không tắt)
ssh -f -N -L 5432:localhost:5432 user@remote
# -f = background
# -N = không chạy command, chỉ tunnel
```

### 2.5 SSH Server Configuration

```bash
# /etc/ssh/sshd_config - Cấu hình SSH server
sudo vim /etc/ssh/sshd_config

# Sau khi sửa, reload:
sudo systemctl reload sshd
```

```bash
# /etc/ssh/sshd_config - Config bảo mật cho production

# Đổi port mặc định (giảm brute force attacks)
Port 2222

# Không cho login bằng root
PermitRootLogin no

# Chỉ cho dùng SSH keys, không password
PasswordAuthentication no
PubkeyAuthentication yes

# Chỉ cho phép các users cụ thể
AllowUsers deploy ubuntu cicd

# Hoặc chỉ cho phép group cụ thể
AllowGroups sshusers

# Timeout
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30

# Giới hạn số lần thử
MaxAuthTries 3
MaxSessions 10

# Tắt các features không cần
X11Forwarding no
AllowTcpForwarding yes   # Cần cho tunneling
GatewayPorts no
PermitEmptyPasswords no

# Log level cao hơn để audit
LogLevel VERBOSE

# Chỉ dùng strong algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,diffie-hellman-group16-sha512
```


## 3. Firewall

### 3.1 UFW (Ubuntu Firewall - Đơn Giản)

```bash
# UFW - Uncomplicated Firewall (frontend cho iptables)

# Kiểm tra trạng thái
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered          # Hiện số thứ tự rules

# Bật/tắt UFW
sudo ufw enable
sudo ufw disable

# Rules cơ bản
sudo ufw default deny incoming    # Block tất cả inbound (mặc định)
sudo ufw default allow outgoing   # Allow tất cả outbound

# Cho phép/từ chối port
sudo ufw allow 22                 # SSH
sudo ufw allow 80                 # HTTP
sudo ufw allow 443                # HTTPS
sudo ufw allow 2222/tcp           # SSH port tùy chỉnh
sudo ufw deny 8080               # Block port 8080

# Cho phép service (dùng tên)
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 'Nginx Full'       # Port 80 và 443 cùng lúc

# Cho phép từ IP cụ thể
sudo ufw allow from 192.168.1.0/24            # Cả subnet
sudo ufw allow from 10.0.0.5 to any port 5432 # Chỉ IP này mới vào được postgres

# Xóa rule
sudo ufw delete allow 8080
sudo ufw delete 5                 # Xóa rule số 5 (xem bằng status numbered)

# Ví dụ setup hoàn chỉnh cho web server
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 203.0.113.10 to any port 22  # Chỉ IP của admin
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Reset về mặc định
sudo ufw reset
```

### 3.2 iptables (Nâng Cao)

```bash
# iptables - Firewall cấp thấp, mạnh mẽ hơn ufw

# Xem rules
sudo iptables -L                  # List rules
sudo iptables -L -v               # Verbose (kèm packet counters)
sudo iptables -L -n               # Numeric (không resolve DNS)
sudo iptables -L --line-numbers   # Với số thứ tự

# Chains:
# INPUT   → Packets đến máy này
# OUTPUT  → Packets xuất phát từ máy này
# FORWARD → Packets đi qua máy này (routing)

# Policies mặc định
sudo iptables -P INPUT DROP          # Block tất cả inbound mặc định
sudo iptables -P FORWARD DROP        # Block forward
sudo iptables -P OUTPUT ACCEPT       # Allow tất cả outbound

# Thêm rules
sudo iptables -A INPUT -i lo -j ACCEPT                          # Allow loopback
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT  # Allow established
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT              # SSH
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT              # HTTP
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT             # HTTPS

# Cho phép từ IP cụ thể
sudo iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT              # Subnet
sudo iptables -A INPUT -s 203.0.113.10 -p tcp --dport 5432 -j ACCEPT  # IP cụ thể

# Giới hạn rate (chống brute force)
sudo iptables -A INPUT -p tcp --dport 22 -m recent --set
sudo iptables -A INPUT -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 -j DROP

# Log và drop
sudo iptables -A INPUT -j LOG --log-prefix "DROPPED: "
sudo iptables -A INPUT -j DROP

# Xóa rule
sudo iptables -D INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -D INPUT 5             # Xóa rule thứ 5

# Lưu rules (Ubuntu)
sudo iptables-save > /etc/iptables/rules.v4
sudo apt install iptables-persistent  # Tự load khi boot
```


## 4. Storage Management

### 4.1 Xem Thông Tin Disk

```bash
# lsblk - liệt kê block devices (cách rõ nhất)
lsblk
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda           8:0    0    20G  0 disk
# ├─sda1        8:1    0  19.5G  0 part /
# └─sda2        8:2    0   512M  0 part [SWAP]
# nvme0n1     259:0    0   500G  0 disk
# └─nvme0n1p1 259:1    0   500G  0 part /data

lsblk -f                    # Kèm filesystem type và UUID

# fdisk - xem và quản lý partitions
sudo fdisk -l               # Liệt kê tất cả disks và partitions
sudo fdisk -l /dev/sdb      # Chỉ disk sdb

# df - disk space
df -h                       # Filesystem usage
df -Th                      # Kèm Type

# Xem disk model
sudo hdparm -I /dev/sda | grep "Model Number"
cat /sys/block/sda/device/model

# Xem SMART status (disk health)
sudo apt install smartmontools
sudo smartctl -a /dev/sda
sudo smartctl -H /dev/sda   # Chỉ health status
```

### 4.2 Tạo Partition & Format

```bash
# CẢNH BÁO: Các lệnh này sẽ mất dữ liệu nếu làm sai!

# Tạo partition với fdisk
sudo fdisk /dev/sdb
# n → new partition
# p → primary
# Chấp nhận defaults cho first/last sector
# w → write changes

# Tạo partition với parted (script-friendly)
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 0% 100%

# Format partition
sudo mkfs.ext4 /dev/sdb1           # Ext4 (Linux standard)
sudo mkfs.xfs /dev/sdb1            # XFS (RHEL default, tốt cho big files)
sudo mkfs.btrfs /dev/sdb1          # Btrfs (modern, có snapshots)
sudo mkfs.vfat /dev/sdb1           # FAT32 (USB drives)

# Swap
sudo mkswap /dev/sdb2              # Tạo swap
sudo swapon /dev/sdb2              # Bật swap
sudo swapoff /dev/sdb2             # Tắt swap
swapon --show                       # Xem swap đang dùng
```

### 4.3 Mount & Unmount

```bash
# Mount thủ công
sudo mount /dev/sdb1 /mnt/mydata
sudo mount -t ext4 /dev/sdb1 /mnt/mydata    # Chỉ định filesystem type
sudo mount -o ro /dev/sdb1 /mnt/            # Mount read-only
sudo mount --bind /source /target           # Bind mount

# Unmount
sudo umount /mnt/mydata
sudo umount /dev/sdb1
sudo umount -l /mnt/mydata    # Lazy unmount (unmount khi không dùng nữa)

# Xem mounts hiện tại
mount | column -t
cat /proc/mounts
findmnt                       # Dễ đọc hơn

# /etc/fstab - Mount tự động khi boot
cat /etc/fstab
```

```
# /etc/fstab
# <device>           <mount>      <type>  <options>           <dump> <pass>
UUID=xxxx-xxxx       /            ext4    errors=remount-ro   0      1
UUID=yyyy-yyyy       /data        ext4    defaults            0      2
UUID=zzzz-zzzz       swap         swap    sw                  0      0
//server/share       /mnt/share   cifs    credentials=/etc/.smbcredentials,uid=1000  0  0
```

```bash
# Lấy UUID của partition
blkid /dev/sdb1
# /dev/sdb1: UUID="1234-5678" TYPE="ext4"

# Test fstab trước khi reboot
sudo mount -a                 # Mount tất cả entries trong fstab
sudo findmnt --verify         # Verify fstab

# Thực tế: Cấu hình data disk tự mount
# 1. Format disk
sudo mkfs.ext4 /dev/sdb
# 2. Tạo mount point
sudo mkdir /data
# 3. Lấy UUID
sudo blkid /dev/sdb
# 4. Thêm vào fstab
echo "UUID=xxx-xxx /data ext4 defaults 0 2" | sudo tee -a /etc/fstab
# 5. Mount
sudo mount -a
```

### 4.4 LVM - Logical Volume Manager (Nâng Cao)

```bash
# LVM cho phép quản lý disk linh hoạt:
# - Resize volume mà không cần unmount (xfs có thể, ext4 cần unmount)
# - Tạo snapshot
# - Gộp nhiều disks thành một

# Thuật ngữ:
# PV (Physical Volume) = disk hoặc partition thật
# VG (Volume Group)    = pool gộp nhiều PVs lại
# LV (Logical Volume)  = "partition ảo" được tạo từ VG

# Tạo LVM setup:
# 1. Tạo Physical Volumes
sudo pvcreate /dev/sdb /dev/sdc
sudo pvs                    # Xem PVs

# 2. Tạo Volume Group
sudo vgcreate data-vg /dev/sdb /dev/sdc
sudo vgs                    # Xem VGs

# 3. Tạo Logical Volumes
sudo lvcreate -L 50G -n db-lv data-vg         # 50GB
sudo lvcreate -L 20G -n logs-lv data-vg        # 20GB
sudo lvcreate -l 100%FREE -n data-lv data-vg   # Dùng hết còn lại
sudo lvs                    # Xem LVs

# 4. Format và mount
sudo mkfs.ext4 /dev/data-vg/db-lv
sudo mount /dev/data-vg/db-lv /var/lib/postgresql/

# Extend LV (thêm dung lượng)
sudo lvextend -L +10G /dev/data-vg/db-lv
sudo resize2fs /dev/data-vg/db-lv              # Mở rộng filesystem ext4

# Snapshot (backup point-in-time)
sudo lvcreate -L 5G -s -n db-snapshot /dev/data-vg/db-lv
# Restore từ snapshot:
sudo lvconvert --merge /dev/data-vg/db-snapshot
```


## 5. Cấu Hình Hostname & Hosts

```bash
# Xem và đổi hostname
hostname                          # Xem hostname
sudo hostnamectl set-hostname new-server-name
hostnamectl                       # Xem thông tin đầy đủ

# /etc/hosts cho lab/development
# Thêm entries để resolve internal hosts không cần DNS
cat >> /etc/hosts << 'EOF'
192.168.1.10   db.internal db
192.168.1.20   redis.internal redis
192.168.1.30   api.internal api
192.168.1.100  monitoring.internal
EOF
```
