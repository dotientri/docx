# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

---

## 1. Ansible Là Gì? Tại Sao Dùng Ansible?

### 1.1 Vấn Đề Trước Khi Có Ansible

Trong doanh nghiệp, khi có 100 servers:

```bash
# Cách thủ công - SSH từng server
ssh server1 "apt update && apt install nginx -y && systemctl enable nginx"
ssh server2 "apt update && apt install nginx -y && systemctl enable nginx"
# ... lặp 100 lần
# → Chậm, dễ sai, không reproducible, không có audit trail
```

**Vấn đề:**
- Không nhất quán (configuration drift)
- Không scalable
- Không có documentation tự động
- Khó rollback
- Không biết server đang ở trạng thái gì

### 1.2 Ansible Giải Quyết Thế Nào?

```yaml
# playbook.yml - Mô tả trạng thái mong muốn
- name: Install and configure Nginx
  hosts: webservers           # 100 servers
  become: yes                 # sudo
  
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

```bash
# Chạy 1 lần → Apply trên 100 servers đồng thời
ansible-playbook playbook.yml
# → Nhanh, nhất quán, idempotent, có log
```

### 1.3 Đặc Điểm Cốt Lõi Ansible

**1. Agentless:**
- Không cần cài agent trên managed nodes
- Chỉ cần SSH (Linux) hoặc WinRM (Windows)
- So sánh: Chef/Puppet cần agent cài trước

**2. Idempotent:**
- Chạy playbook nhiều lần = kết quả như chạy 1 lần
- Chỉ thay đổi gì cần thay đổi → Thao tác an toàn
- `apt: name=nginx state=present` → Check trước, chỉ install nếu chưa có

**3. Declarative:**
- Mô tả **"muốn gì"** không phải **"làm thế nào"**
- `state: present` → Ansible tự biết cách achieve

**4. Simple (YAML + Python):**
- Không cần học DSL mới
- YAML dễ đọc, dễ hiểu, dễ review

**5. Push-based:**
- Control node push config đến managed nodes
- So sánh: Puppet/Chef là pull-based (agents tự pull)

---

## 2. Kiến Trúc Ansible

```
┌─────────────────────────────────────────────────────────┐
│                    Control Node                          │
│  ┌─────────────┐ ┌──────────┐ ┌────────────────────┐   │
│  │  Playbooks  │ │Inventory │ │   Ansible Config   │   │
│  │  (YAML)     │ │  (hosts) │ │   (ansible.cfg)    │   │
│  └──────┬──────┘ └────┬─────┘ └─────────────────────┘  │
│         │              │                                  │
│  ┌──────▼──────────────▼──────┐                         │
│  │        Ansible Engine       │                         │
│  │  - Parse playbooks          │                         │
│  │  - Build task list          │                         │
│  │  - Connect to hosts         │                         │
│  │  - Execute modules          │                         │
│  └─────────────┬───────────────┘                         │
└────────────────│────────────────────────────────────────┘
                 │
        SSH / WinRM / API
                 │
     ┌───────────┼───────────┐
     │           │           │
┌────▼───┐  ┌────▼───┐  ┌────▼───┐
│ web01  │  │ web02  │  │ db01   │
│(Ubuntu)│  │(Ubuntu)│  │(CentOS)│
└────────┘  └────────┘  └────────┘
         Managed Nodes
```

**Các thành phần:**

| Thành Phần | Mô Tả |
|-----------|-------|
| **Control Node** | Máy chạy Ansible (laptop, CI server) |
| **Managed Nodes** | Servers được Ansible quản lý |
| **Inventory** | Danh sách managed nodes |
| **Playbook** | YAML file mô tả tasks cần thực hiện |
| **Play** | Một khối trong playbook (hosts + tasks) |
| **Task** | Đơn vị nhỏ nhất (gọi 1 module) |
| **Module** | Đơn vị code thực thi (apt, service, copy...) |
| **Role** | Tập hợp tasks, variables, files có cấu trúc |
| **Handler** | Task chỉ chạy khi được notify |
| **Fact** | Thông tin thu thập từ managed nodes |
| **Variable** | Biến có thể override ở nhiều cấp |

---

## 3. Cài Đặt Ansible

### 3.1 Cài Trên Control Node

```bash
# ===== UBUNTU/DEBIAN =====
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y

# Hoặc qua pip (phiên bản mới nhất)
pip3 install ansible

# ===== CENTOS/RHEL =====
sudo dnf install epel-release
sudo dnf install ansible

# ===== macOS =====
brew install ansible

# Kiểm tra version
ansible --version
# ansible [core 2.15.0]
#   config file = /etc/ansible/ansible.cfg
#   python version = 3.11.0
#   ansible python module location = ...
```

### 3.2 Cấu Hình SSH Keys

```bash
# Ansible dùng SSH để kết nối managed nodes
# Cần SSH key authentication (không dùng password)

# Tạo SSH key trên control node
ssh-keygen -t ed25519 -C "ansible@control-node" -f ~/.ssh/ansible_key

# Copy public key đến tất cả managed nodes
ssh-copy-id -i ~/.ssh/ansible_key.pub user@web01
ssh-copy-id -i ~/.ssh/ansible_key.pub user@web02
ssh-copy-id -i ~/.ssh/ansible_key.pub user@db01

# Test kết nối thủ công
ssh -i ~/.ssh/ansible_key user@web01 echo "connected"

# ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
inventory = ./inventory
remote_user = ubuntu
private_key_file = ~/.ssh/ansible_key
host_key_checking = False    # Dev only! Enable trong production
forks = 10                   # Số hosts xử lý song song
timeout = 30
log_path = ./ansible.log

[privilege_escalation]
become = True                # Mặc định dùng sudo
become_method = sudo
become_user = root
EOF
```

---

## 4. Inventory - Quản Lý Hosts

### 4.1 Static Inventory

```ini
# inventory/hosts (INI format)

# Ungrouped hosts
192.168.1.10
jumpbox.company.com

# Group: webservers
[webservers]
web01.company.com
web02.company.com ansible_host=192.168.1.21   # Custom hostname
web03                                           # Sẽ resolve qua DNS

# Variables cho host cụ thể
web04 ansible_host=192.168.1.24 ansible_port=2222 ansible_user=admin

# Group: databases
[databases]
db01.company.com
db02.company.com

# Group: monitoring
[monitoring]
grafana.company.com
prometheus.company.com

# Group of groups (meta-group)
[production:children]
webservers
databases
monitoring

# Group variables
[webservers:vars]
http_port=80
https_port=443
nginx_worker_processes=4

[databases:vars]
db_port=5432
max_connections=200
```

### 4.2 YAML Inventory (Rõ ràng hơn)

```yaml
# inventory/hosts.yml
all:
  children:
    production:
      children:
        webservers:
          hosts:
            web01.company.com:
              ansible_host: 192.168.1.20
              nginx_worker_processes: 4
            web02.company.com:
              ansible_host: 192.168.1.21
              nginx_worker_processes: 4
          vars:
            http_port: 80
            https_port: 443
            
        databases:
          hosts:
            db01.company.com:
              ansible_host: 192.168.1.30
              pg_max_connections: 200
            db02.company.com:
              ansible_host: 192.168.1.31
              pg_max_connections: 150
          vars:
            db_port: 5432
            
    staging:
      children:
        webservers:
          hosts:
            staging-web01:
              ansible_host: 10.0.1.10
          vars:
            http_port: 80
            env: staging
```

### 4.3 Dynamic Inventory

```python
# Inventory script lấy từ nguồn động (AWS, GCP, CMDB...)

# ===== AWS EC2 Dynamic Inventory =====
pip install boto3
ansible-galaxy collection install amazon.aws

# aws_ec2.yml
cat > inventory/aws_ec2.yml << 'EOF'
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
  - ap-southeast-1

# Lọc instances theo tags
filters:
  tag:Environment:
    - production
  instance-state-name: running

# Keyed groups - tạo groups từ tags
keyed_groups:
  - prefix: env
    key: tags.Environment
  - prefix: role
    key: tags.Role

# Hostnames
hostnames:
  - private-ip-address    # Dùng private IP

# Variables
compose:
  ansible_host: private_ip_address
  ec2_tag_Name: tags.Name
EOF

# Test
ansible-inventory -i inventory/aws_ec2.yml --list
ansible -i inventory/aws_ec2.yml env_production -m ping

# ===== Custom Dynamic Inventory Script =====
#!/usr/bin/env python3
import json
import sys
import requests

def get_inventory():
    # Lấy từ CMDB API
    response = requests.get('https://cmdb.company.com/api/servers',
                           headers={'Authorization': 'Bearer TOKEN'})
    servers = response.json()
    
    inventory = {
        '_meta': {'hostvars': {}},
        'all': {'children': ['webservers', 'databases']},
        'webservers': {'hosts': []},
        'databases': {'hosts': []}
    }
    
    for server in servers:
        hostname = server['hostname']
        inventory[server['role'] + 's']['hosts'].append(hostname)
        inventory['_meta']['hostvars'][hostname] = {
            'ansible_host': server['ip'],
            'datacenter': server['datacenter'],
            'environment': server['environment']
        }
    
    return inventory

if '--list' in sys.argv:
    print(json.dumps(get_inventory()))
elif '--host' in sys.argv:
    print(json.dumps({}))
```

### 4.4 Inventory Commands

```bash
# Xem tất cả hosts trong inventory
ansible-inventory --list
ansible-inventory --graph        # Dạng cây
ansible-inventory --host web01  # Host variables

# Ping tất cả hosts
ansible all -m ping

# Ping group cụ thể
ansible webservers -m ping

# Chạy ad-hoc command
ansible all -m command -a "uptime"
ansible webservers -m shell -a "df -h | grep /dev/sda"
ansible databases -m shell -a "systemctl status postgresql"

# Dry run (check mode)
ansible all -m ping --check

# Giới hạn hosts
ansible webservers -m ping --limit web01
ansible all -m ping --limit 'web01,web02'
ansible all -m ping --limit '!databases'    # Ngoại trừ databases
```

---

## 5. Ad-Hoc Commands - Chạy Nhanh Không Cần Playbook

```bash
# Cú pháp: ansible <pattern> -m <module> -a "<arguments>"

# ===== MODULES PHỔ BIẾN =====

# command - Chạy lệnh (không qua shell, không có pipe/redirect)
ansible all -m command -a "uptime"
ansible all -m command -a "ls -la /etc/nginx"

# shell - Chạy qua shell (có pipe, redirect, variables)
ansible all -m shell -a "cat /etc/passwd | wc -l"
ansible all -m shell -a "echo $HOSTNAME"

# raw - SSH trực tiếp (không cần Python trên remote)
ansible all -m raw -a "apt-get update"

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

---

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

---

> **Tiếp theo: Phần 2** - Playbooks, Variables, Templates & Conditionals
