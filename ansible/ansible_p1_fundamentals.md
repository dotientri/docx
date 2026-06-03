---
markmap:
  title: "Ansible Toàn Tập — Nền tảng & Kiến trúc"
  collapse: false
---

# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

## Theory

### Ansible là gì & giải pháp
- Agentless, declarative, idempotent, push-based orchestration tool.
- Giải quyết vấn đề configuration drift, không reproducible, khó scale.

#### Đặc tính chính
- Agentless (SSH/WinRM)
- Idempotent (chạy nhiều lần không gây thay đổi thừa)
- Declarative: mô tả trạng thái mong muốn
- Dễ đọc: YAML + mô-đun sẵn có

### Kiến trúc tổng quan
- Control node: nơi lưu playbooks, inventory, ansible.cfg
- Managed nodes: servers được quản lý qua SSH/WinRM
- Ansible Engine: phân tích playbook → thực thi modules → thu thập facts

### Thành phần
- Inventory, Playbook, Play, Task, Module, Role, Handler, Facts, Variables

## Practice

### Minh họa vấn đề trước Ansible
```bash
# Thực thi thủ công trên 100 servers → quá tốn thời gian và lỗi
ssh server1 "apt update && apt install nginx -y && systemctl enable nginx"
ssh server2 "apt update && apt install nginx -y && systemctl enable nginx"
```

### Ví dụ playbook cơ bản (install + enable nginx)
```yaml
- name: Install and configure Nginx
  hosts: webservers
  become: yes

  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Ensure Nginx is running and enabled
      service:
        name: nginx
        state: started
        enabled: yes
```

### Cài đặt control node nhanh
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible
# hoặc
pip3 install --user ansible

# Kiểm tra
ansible --version
```

### SSH keys và `ansible.cfg` tối thiểu
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@control"
ssh-copy-id -i ~/.ssh/ansible_key.pub user@host

cat > ansible.cfg <<'EOF'
[defaults]
inventory = ./inventory
remote_user = ubuntu
private_key_file = ~/.ssh/ansible_key
host_key_checking = False
forks = 10
EOF
```

### Inventory (tóm tắt)
- Static INI: nhóm hosts, biến nhóm
- YAML: cấu trúc cây rõ ràng
- Dynamic: plugin (cloud/CMDB)

### Lệnh cơ bản
```bash
ansible-inventory --list
ansible all -m ping
ansible webservers -m shell -a "uptime"
ansible-playbook playbook.yml
```

### Tips thực hành
- Test trên staging trước production
- Dùng roles để tách concern và tái sử dụng
- Dùng `--check` và `--diff` để dry-run
- Bật logging và quản lý secrets (Ansible Vault)


# copy - Copy file
ansible webservers -m copy -a "src=nginx.conf dest=/etc/nginx/nginx.conf owner=root mode=0644"

# fetch - Lấy file từ remote về local
ansible all -m fetch -a "src=/var/log/nginx/error.log dest=./logs/ flat=no"

# file - Quản lý files/directories
ansible all -m file -a "path=/var/app state=directory owner=app mode=0755"

# apt/yum - Package management
ansible webservers -m apt -a "name=nginx state=present update_cache=yes"
ansible databases -m apt -a "name=postgresql-15 state=present"

# service - Manage services
ansible webservers -m service -a "name=nginx state=started enabled=yes"

# user - Manage users
ansible all -m user -a "name=deploy shell=/bin/bash groups=sudo state=present"

# authorized_key - SSH keys
ansible all -m authorized_key -a "user=deploy key='ssh-ed25519 AAAA...'"

# cron - Cron jobs
ansible webservers -m cron -a "name='log rotate' hour=2 minute=0 job='/usr/local/bin/rotate-logs.sh'"

# git - Git operations
ansible webservers -m git -a "repo=https://github.com/company/app.git dest=/var/www/app version=main"

# uri - HTTP requests
ansible localhost -m uri -a "url=https://api.company.com/health return_content=yes"

# ===== OPTIONS =====
# Chạy với sudo
ansible webservers -m apt -a "name=nginx state=present" --become

# Verbose output
ansible all -m ping -v
ansible all -m ping -vvv    # Very verbose (debug connection)

# Parallel (mặc định 5 forks)
ansible all -m ping -f 20   # 20 hosts song song

# Check mode (dry run - không thay đổi gì)
ansible all -m apt -a "name=nginx state=present" --check --diff
```


## 6. Facts - Thông Tin Hệ Thống

### 6.1 Ansible Facts Là Gì?

Facts là **thông tin tự động thu thập** từ managed nodes khi bắt đầu play.

```bash
# Xem tất cả facts của host
ansible web01 -m setup

# Lọc facts
ansible web01 -m setup -a "filter=ansible_*"
ansible web01 -m setup -a "filter=ansible_os_family"
ansible web01 -m setup -a "filter=ansible_default_ipv4"
ansible web01 -m setup -a "filter=ansible_memory_mb"
```

**Facts quan trọng:**

```yaml
ansible_hostname: web01
ansible_fqdn: web01.company.com
ansible_default_ipv4:
  address: 192.168.1.20
  interface: eth0
  gateway: 192.168.1.1
ansible_os_family: Debian        # Debian, RedHat, Darwin, Windows
ansible_distribution: Ubuntu
ansible_distribution_version: "22.04"
ansible_distribution_release: jammy
ansible_architecture: x86_64
ansible_processor_cores: 4
ansible_processor_count: 1
ansible_memtotal_mb: 8192
ansible_memfree_mb: 4096
ansible_mounts:
  - mount: /
    size_total: 50000000000
    size_available: 30000000000
    device: /dev/sda1
ansible_date_time:
  iso8601: "2024-01-15T08:30:00+07:00"
  date: "2024-01-15"
ansible_env:
  PATH: /usr/local/bin:/usr/bin:/bin
  HOME: /root
```

### 6.2 Sử Dụng Facts Trong Playbook

```yaml
- name: Configure based on OS
  hosts: all
  tasks:
    # Cài package theo OS
    - name: Install Nginx (Debian)
      apt:
        name: nginx
        state: present
      when: ansible_os_family == "Debian"
      
    - name: Install Nginx (RedHat)
      yum:
        name: nginx
        state: present
      when: ansible_os_family == "RedHat"
      
    # Cấu hình theo RAM
    - name: Set high-memory config
      template:
        src: nginx-highram.conf.j2
        dest: /etc/nginx/nginx.conf
      when: ansible_memtotal_mb >= 8192
      
    # Dùng fact làm variable
    - name: Display server info
      debug:
        msg: "Server {{ ansible_hostname }} has {{ ansible_processor_cores }} CPU cores and {{ ansible_memtotal_mb }}MB RAM"
```

### 6.3 Custom Facts

```bash
# Tạo custom facts trên managed nodes
# Đặt trong /etc/ansible/facts.d/*.fact (INI hoặc JSON)

# Trên managed node:
sudo mkdir -p /etc/ansible/facts.d

cat > /etc/ansible/facts.d/application.fact << 'EOF'
[app]
name=myapp
version=2.1.0
environment=production
deploy_user=deploy
EOF

cat > /etc/ansible/facts.d/maintenance.fact << 'EOF'
{
  "maintenance_window": "Sunday 02:00-04:00",
  "backup_schedule": "daily",
  "monitoring": "enabled"
}
EOF

# Truy cập trong playbook:
# {{ ansible_local.application.app.version }}
# {{ ansible_local.maintenance.monitoring }}
```
