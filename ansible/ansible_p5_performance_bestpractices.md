---
markmap:
  title: "Ansible — Performance, Best Practices & Cheat Sheet"
  collapse: false
---

# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 5: PERFORMANCE, BEST PRACTICES & CHEAT SHEET

## Theory
- Tối ưu performance bằng pipelining, SSH multiplexing, fact caching và tuning forks/serial.
- Bảo mật và testing là phần không thể tách rời của vận hành Ansible production.

## Practice
- Bật `pipelining`, `ControlPersist` và `fact_caching` cho môi trường production.
- Sử dụng `molecule` cho unit testing roles và pipeline để lint/syntax-check.

## 1. Performance Optimization

### 1.1 Pipelining

```ini
# ansible.cfg
[ssh_connection]
pipelining = True   # Giảm SSH round trips ~3x nhanh hơn

# Cần tắt requiretty trong sudoers trên managed nodes:
# /etc/sudoers.d/ansible:
# Defaults:ansible !requiretty
```

### 1.2 SSH Multiplexing

```ini
# ansible.cfg - Tái sử dụng SSH connections
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30
control_path_dir = /tmp/.ansible-ssh
```

### 1.3 Fact Caching

```ini
# ansible.cfg
[defaults]
fact_caching = redis               # Hoặc jsonfile, memcached
fact_caching_connection = localhost:6379:0  # Redis
fact_caching_timeout = 86400       # 24 giờ

# Khi đã cache facts: Skip gathering trên lần chạy tiếp theo
# gather_facts: smart  ← Chỉ gather nếu chưa có cache
```

### 1.4 Forks và Serial

```yaml
# ansible.cfg: forks = 20   (xử lý 20 hosts song song)

# Trong playbook:
- hosts: all
  serial: 10     # Override: 10 hosts cùng lúc
  
# Percentage
- hosts: all
  serial: "25%"  # 25% hosts cùng lúc

# Step-wise rolling
- hosts: all
  serial:
    - 1          # Bắt đầu với 1 host (test)
    - 5          # Sau đó 5 hosts
    - "20%"      # Sau đó 20% mỗi batch
```

### 1.5 Giảm Tasks Không Cần Thiết

```yaml
# ===== 1. Tắt gather_facts khi không cần =====
- hosts: webservers
  gather_facts: no    # Tiết kiệm ~2-5s/host
  tasks:
    - name: Quick check
      command: uptime

# ===== 2. Tắt facts cho specific hosts =====
- hosts: all
  gather_facts: "{{ 'yes' if inventory_hostname in groups['servers'] else 'no' }}"

# ===== 3. Selective fact gathering =====
- hosts: all
  gather_subset:
    - min              # Chỉ hardware/network basics
    - '!hardware'      # Loại trừ hardware facts (chậm)

# ===== 4. Install nhiều packages 1 lúc =====
# Sai (N tasks):
- apt: name={{ item }} state=present
  loop: [nginx, redis, postgresql]

# Đúng (1 task):
- apt:
    name: [nginx, redis, postgresql]
    state: present

# ===== 5. async - Background tasks =====
- name: Run long backup
  command: /usr/bin/backup.sh
  async: 3600        # Timeout sau 3600s
  poll: 0            # Không chờ (fire and forget)
  register: backup_job

# Kiểm tra sau
- name: Wait for backup to complete
  async_status:
    jid: "{{ backup_job.ansible_job_id }}"
  register: backup_result
  until: backup_result.finished
  retries: 60
  delay: 30
```

### 1.6 Profiling

```bash
# Xem timing của từng task
ANSIBLE_CALLBACK_WHITELIST=timer,profile_tasks ansible-playbook site.yml

# Output:
# TASK [nginx : Install Nginx]    Thursday 15 Jan 2024  11:00:01 +0700 (0:00:03.245)
# TASK [nginx : Configure Nginx]  Thursday 15 Jan 2024  11:00:04 +0700 (0:00:01.123)

# Profile per host
ansible-playbook site.yml -v 2>&1 | grep -E "TASK|PLAY|ok:|changed:|failed:|seconds"
```


## 2. Security Best Practices

### 2.1 Checklist Bảo Mật

```bash
# ===== 1. KHÔNG BAO GIỜ COMMIT SECRETS =====
# Dùng ansible-vault cho tất cả passwords, keys, tokens
# .gitignore phải có: *.retry, vault-pass, .vault_pass

# ===== 2. PRINCIPLE OF LEAST PRIVILEGE =====
# Tạo dedicated ansible user với minimal permissions
useradd -m -s /bin/bash ansible
# Chỉ cấp sudo cho những gì cần
echo "ansible ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/sbin/nginx, /usr/bin/systemctl" \
  > /etc/sudoers.d/ansible

# ===== 3. SSH HARDENING =====
# ansible.cfg
[ssh_connection]
ssh_args = -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10

# ===== 4. VALIDATE TRƯỚC KHI DEPLOY =====
# Luôn dùng --syntax-check và --check trước khi chạy
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff

# ===== 5. LIMIT SCOPE =====
# Không chạy trên tất cả nếu không cần thiết
ansible-playbook site.yml --limit web01
ansible-playbook site.yml --limit 'webservers:!web03'

# ===== 6. AUDIT LOGGING =====
# ansible.cfg
log_path = /var/log/ansible.log
# Kết hợp với log rotation
```

### 2.2 Secrets Management với HashiCorp Vault

```yaml
# Dùng HashiCorp Vault thay Ansible Vault cho enterprise

# Cài hashi_vault lookup plugin
# pip install hvac

# Trong playbook
- name: Get database password
  set_fact:
    db_password: "{{ lookup('hashi_vault', 
      'secret=secret/data/myapp/database:password 
       url=https://vault.company.com:8200 
       auth_method=approle 
       role_id=my-role-id 
       secret_id=my-secret-id') }}"
      
# Hoặc dùng environment variables
# VAULT_ADDR, VAULT_TOKEN

# Ansible collection: community.hashi_vault
- name: Fetch multiple secrets
  community.hashi_vault.hashi_vault_kv2_get:
    path: myapp/database
    url: https://vault.company.com:8200
    auth_method: token
    token: "{{ ansible_env.VAULT_TOKEN }}"
  register: db_secrets
  
- name: Use secret
  template:
    src: config.j2
    dest: /etc/app/config.yml
  vars:
    db_password: "{{ db_secrets.secret.password }}"
```


## 3. Debugging & Troubleshooting

### 3.1 Debug Techniques

```yaml
# ===== DEBUG MODULE =====
- name: Show variable
  debug:
    var: ansible_hostname
    
- name: Show message
  debug:
    msg: "Server IP is {{ ansible_default_ipv4.address }}"
    
- name: Show all vars (development only!)
  debug:
    var: vars
    verbosity: 2    # Chỉ show khi -vv

# ===== VERBOSE LEVELS =====
ansible-playbook site.yml -v      # Basic output
ansible-playbook site.yml -vv     # Module output
ansible-playbook site.yml -vvv    # SSH details
ansible-playbook site.yml -vvvv   # SSH debug

# ===== CHECK MODE (Dry Run) =====
ansible-playbook site.yml --check        # Không thay đổi gì
ansible-playbook site.yml --check --diff # + Hiện diff

# ===== START AT TASK =====
ansible-playbook site.yml --start-at-task="Configure Nginx"

# ===== STEP BY STEP =====
ansible-playbook site.yml --step
# Hỏi trước mỗi task: Perform task? (y/n/c)

# ===== LIST TASKS =====
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --list-hosts
ansible-playbook site.yml --list-tags

# ===== ASSERT - Fail với thông báo rõ ràng =====
- name: Validate disk space
  assert:
    that:
      - ansible_mounts | selectattr('mount', 'eq', '/') | 
        map(attribute='size_available') | first > 5368709120  # 5GB
    fail_msg: "Not enough disk space! Need at least 5GB free on /"
    success_msg: "Disk space OK: {{ (ansible_mounts | selectattr('mount', 'eq', '/') | map(attribute='size_available') | first / 1024 / 1024 / 1024) | round(2) }}GB free"

# ===== PAUSE - Dừng để debug =====
- name: Pause for debugging
  pause:
    prompt: "Press Enter to continue or Ctrl+C to abort"
    
- name: Pause 30 seconds
  pause:
    seconds: 30
    echo: no
```

### 3.2 Common Errors & Fixes

```bash
# ===== ERROR: Permission denied (publickey) =====
# Fix: SSH key chưa được copy đến remote host
ssh-copy-id -i ~/.ssh/ansible_key.pub user@host

# ===== ERROR: sudo: no tty present =====
# Fix: Thêm vào sudoers
echo "ansible ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansible
# Hoặc trong ansible.cfg:
# [ssh_connection]
# pipelining = False  (tắt pipelining)

# ===== ERROR: Missing sudo password =====
ansible-playbook site.yml --ask-become-pass

# ===== ERROR: Module not found =====
# Fix: Collection chưa install
ansible-galaxy collection install community.general

# ===== ERROR: Template not found =====
# Fix: Template path phải relative đến playbook hoặc role
# Đúng: templates/nginx.conf.j2 (trong cùng thư mục với playbook)

# ===== ERROR: Variable is undefined =====
# Debug:
ansible all -m setup | grep variable_name
# Hoặc xem inventory:
ansible-inventory --host hostname

# ===== ERROR: Timeout =====
# Fix: Tăng timeout
# ansible.cfg: timeout = 60
# Hoặc: ansible-playbook site.yml -T 60
```


## 4. Ansible Best Practices Tổng Hợp

### 4.1 Naming Conventions

```yaml
# ===== TASKS =====
# Đặt tên mô tả rõ ràng (verb + noun)
- name: Install Nginx web server           ← Tốt
- name: nginx install                      ← Kém

# Format: "Verb Noun [qualifier]"
- name: Create application user
- name: Configure Nginx with SSL
- name: Start PostgreSQL database service

# ===== VARIABLES =====
# Snake_case cho tất cả variables
app_name: myapp             ← Tốt
appName: myapp              ← Kém (camelCase)

# Prefix theo scope
# nginx_*   : Nginx-related vars
# db_*      : Database vars
# app_*     : Application vars
# vault_*   : Encrypted variables

# ===== FILES =====
# Descriptive tên files
install-packages.yml        ← Tốt
install.yml                 ← OK
stuff.yml                   ← Kém
```

### 4.2 Idempotency Check

```yaml
# Mọi task đều phải idempotent!

# ✅ Idempotent
- name: Create user
  user:
    name: deploy
    state: present
    
- name: Install package
  apt:
    name: nginx
    state: present
    
# ❌ Không idempotent (chạy 2 lần = khác nhau)
- name: Append to config
  shell: echo "config=value" >> /etc/app/config    # Thêm nhiều lần!

# ✅ Fix - Dùng lineinfile
- name: Set config value
  lineinfile:
    path: /etc/app/config
    regexp: '^config='
    line: "config=value"
    
# ❌ Không idempotent
- name: Create backup
  command: cp /etc/app/config /etc/app/config.bak

# ✅ Fix - Check trước
- name: Backup config if not exists
  copy:
    src: /etc/app/config
    dest: /etc/app/config.bak
    remote_src: yes
    force: no    # Không overwrite nếu đã có
```

### 4.3 Testing Strategy

```bash
# ===== TESTING PYRAMID =====

# Level 1: Syntax Check (nhanh nhất)
ansible-playbook site.yml --syntax-check
yamllint .
ansible-lint

# Level 2: Dry Run
ansible-playbook site.yml --check --diff -i inventory/staging

# Level 3: Molecule Tests (local Docker)
molecule test

# Level 4: Integration Test (staging env)
ansible-playbook site.yml -i inventory/staging
ansible-playbook tests/integration.yml -i inventory/staging

# Level 5: Production Deploy (manual approval)
ansible-playbook site.yml -i inventory/production
```


## 5. Cheat Sheet Tổng Hợp

### 5.1 Commands Thường Dùng

```bash
# ============================================
# KIỂM TRA
# ============================================
ansible --version
ansible-inventory --list
ansible-inventory --graph
ansible all -m ping
ansible webservers -m setup -a "filter=ansible_distribution"

# ============================================
# AD-HOC
# ============================================
ansible all -m command -a "uptime"
ansible all -m shell -a "df -h | grep /"
ansible webservers -m apt -a "name=nginx state=present" --become
ansible all -m copy -a "src=file.conf dest=/etc/app/"
ansible all -m service -a "name=nginx state=restarted" --become

# ============================================
# PLAYBOOK
# ============================================
ansible-playbook site.yml                          # Run
ansible-playbook site.yml --check --diff           # Dry run
ansible-playbook site.yml --limit web01           # Specific host
ansible-playbook site.yml --tags deploy            # Specific tag
ansible-playbook site.yml --skip-tags install      # Skip tag
ansible-playbook site.yml --start-at-task "..."   # Start from task
ansible-playbook site.yml -e "var=value"          # Extra vars
ansible-playbook site.yml --ask-vault-pass         # Vault password
ansible-playbook site.yml -v/-vv/-vvv             # Verbosity

# ============================================
# VAULT
# ============================================
ansible-vault create secret.yml
ansible-vault edit secret.yml
ansible-vault view secret.yml
ansible-vault encrypt file.yml
ansible-vault decrypt file.yml
ansible-vault rekey file.yml
ansible-vault encrypt_string 'value' --name var_name

# ============================================
# GALAXY
# ============================================
ansible-galaxy role install rolename
ansible-galaxy role install -r requirements.yml
ansible-galaxy role list
ansible-galaxy collection install namespace.collection
ansible-galaxy role init roles/myrole

# ============================================
# DEBUG
# ============================================
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --list-hosts
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --step
```

### 5.2 Module Quick Reference

```yaml
# FILE MANAGEMENT
- file: path=/dir state=directory/file/absent/link owner=user mode=0755
- copy: src=local dest=remote owner=user mode=0644
- template: src=file.j2 dest=/etc/app/file
- fetch: src=/remote/file dest=./local/
- lineinfile: path=/file regexp='^key=' line='key=value'
- blockinfile: path=/file block='content here'
- replace: path=/file regexp=old replace=new
- unarchive: src=file.tar.gz dest=/opt/ remote_src=yes
- get_url: url=https://... dest=/tmp/file
- stat: path=/file  (register result, check result.stat.exists)

# SYSTEM
- apt: name=pkg state=present/absent/latest update_cache=yes
- yum/dnf: name=pkg state=present
- service: name=nginx state=started/stopped/restarted enabled=yes
- user: name=user groups=group shell=/bin/bash state=present
- group: name=group state=present
- cron: name=job hour=2 minute=0 job='/path/to/script'
- sysctl: name=net.ipv4.ip_forward value=1 reload=yes

# COMMANDS
- command: /usr/bin/program arg1 arg2  (no shell features)
- shell: complex | command > with redirect  (has shell)
- script: /local/script.sh  (runs local script on remote)
- raw: 'raw ssh command'  (no Python needed)

# NETWORK
- uri: url=https://api.com method=POST body_format=json
- wait_for: host=server port=80 timeout=300
- wait_for_connection: timeout=300

# PACKAGES
- pip: name=package virtualenv=/opt/venv
- npm: name=package global=yes
- gem: name=rubygem state=present

# VERSION CONTROL
- git: repo=https://github.com/... dest=/opt/app version=main

# DATABASE
- mysql_db: name=dbname state=present login_user=root
- mysql_user: name=user password=pass priv='db.*:ALL'
- postgresql_db: name=dbname state=present
- postgresql_user: name=user password=pass

# DEBUG
- debug: var=varname / msg="message"
- assert: that="condition" fail_msg="error"
- pause: seconds=30 / prompt="Press Enter"
- fail: msg="Custom failure message"

# INCLUDE
- include_tasks: tasks/file.yml
- import_tasks: tasks/file.yml (static)
- include_vars: vars/file.yml
- include_role: name=rolename
```


## 6. Ansible vs Alternatives

| Tính Năng | Ansible | Puppet | Chef | SaltStack | Terraform |
|-----------|---------|--------|------|-----------|-----------|
| Language | YAML | DSL (Ruby) | Ruby DSL | YAML/Python | HCL |
| Agentless | ✅ | ❌ | ❌ | ❌ (minion) | ✅ |
| Learning Curve | Thấp | Cao | Cao | Trung bình | Trung bình |
| Push/Pull | Push | Pull | Pull | Both | Push |
| Community | Rất lớn | Lớn | Lớn | Trung bình | Rất lớn |
| Dùng Cho | Config mgmt | Config mgmt | Config mgmt | Config mgmt | IaC |
| Cloud Native | Tốt | OK | OK | OK | Tốt nhất |

### Tóm tắt
- **Ansible:** Cấu hình server, deployment, orchestration → Dùng cho CM
- **Terraform:** Tạo/xóa infrastructure (VMs, networks, databases) → Dùng cho IaC
- **Hai bộ bổ sung nhau:** Terraform tạo infrastructure, Ansible cấu hình nó


> **Hoàn thành Ansible Toàn Tập!** Tiếp theo: Terraform, Kubernetes, Azure
