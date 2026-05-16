# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 3: ROLES, GALAXY & ADVANCED PATTERNS

---

## 1. Roles - Tái Sử Dụng Code

### 1.1 Cấu Trúc Role

Role là cách tổ chức Ansible code theo cấu trúc chuẩn, cho phép reuse và share.

```
roles/
└── nginx/                          ← Role name
    ├── tasks/
    │   ├── main.yml               ← Tasks chính (auto-loaded)
    │   ├── install.yml            ← Tasks phụ (include từ main.yml)
    │   └── configure.yml
    ├── handlers/
    │   └── main.yml               ← Handlers (auto-loaded)
    ├── templates/
    │   ├── nginx.conf.j2
    │   └── vhost.conf.j2
    ├── files/
    │   ├── nginx.key              ← Static files (không template)
    │   └── dhparam.pem
    ├── vars/
    │   └── main.yml               ← Variables (high priority)
    ├── defaults/
    │   └── main.yml               ← Default variables (lowest priority)
    ├── meta/
    │   └── main.yml               ← Role dependencies, metadata
    ├── library/                   ← Custom modules
    ├── module_utils/              ← Custom module utils
    └── README.md
```

### 1.2 Tạo Role Đầy Đủ: Nginx Role

```bash
# Khởi tạo role structure
ansible-galaxy role init roles/nginx
```

```yaml
# roles/nginx/defaults/main.yml
# Default variables - Dễ override từ playbook/inventory
---
nginx_version: "1.25"
nginx_user: www-data
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
nginx_client_max_body_size: 10m
nginx_gzip_enabled: true
nginx_log_format: combined
nginx_log_level: warn

nginx_http_port: 80
nginx_https_port: 443

nginx_ssl_protocols: "TLSv1.2 TLSv1.3"
nginx_ssl_ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"

nginx_sites: []
nginx_upstreams: []
```

```yaml
# roles/nginx/vars/main.yml
# Variables không nên override (internal)
---
nginx_package_name: nginx
nginx_service_name: nginx
nginx_config_dir: /etc/nginx
nginx_log_dir: /var/log/nginx
nginx_pid_file: /run/nginx.pid
```

```yaml
# roles/nginx/tasks/main.yml
---
- name: Include OS-specific tasks
  include_tasks: "{{ ansible_os_family | lower }}.yml"

- name: Configure Nginx
  include_tasks: configure.yml

- name: Enable sites
  include_tasks: sites.yml
  when: nginx_sites | length > 0
  
- name: Ensure Nginx is running
  service:
    name: "{{ nginx_service_name }}"
    state: started
    enabled: yes
```

```yaml
# roles/nginx/tasks/debian.yml
---
- name: Install Nginx (Debian/Ubuntu)
  apt:
    name: "{{ nginx_package_name }}={{ nginx_version }}*"
    state: present
    update_cache: yes
  notify: restart nginx
  
- name: Remove default nginx site
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: reload nginx
```

```yaml
# roles/nginx/tasks/configure.yml
---
- name: Create nginx config
  template:
    src: nginx.conf.j2
    dest: "{{ nginx_config_dir }}/nginx.conf"
    owner: root
    group: root
    mode: '0644'
    validate: /usr/sbin/nginx -t -c %s
  notify: reload nginx

- name: Create log directory
  file:
    path: "{{ nginx_log_dir }}"
    state: directory
    owner: "{{ nginx_user }}"
    group: adm
    mode: '0755'

- name: Configure logrotate for nginx
  template:
    src: logrotate.j2
    dest: /etc/logrotate.d/nginx
```

```yaml
# roles/nginx/tasks/sites.yml
---
- name: Create sites-available directory
  file:
    path: "{{ nginx_config_dir }}/sites-available"
    state: directory

- name: Create sites-enabled directory
  file:
    path: "{{ nginx_config_dir }}/sites-enabled"
    state: directory

- name: Configure virtual hosts
  template:
    src: vhost.conf.j2
    dest: "{{ nginx_config_dir }}/sites-available/{{ item.name }}.conf"
    validate: /usr/sbin/nginx -t -c %s
  loop: "{{ nginx_sites }}"
  notify: reload nginx

- name: Enable virtual hosts
  file:
    src: "{{ nginx_config_dir }}/sites-available/{{ item.name }}.conf"
    dest: "{{ nginx_config_dir }}/sites-enabled/{{ item.name }}.conf"
    state: link
  loop: "{{ nginx_sites }}"
  when: item.enabled | default(true)
  notify: reload nginx
```

```yaml
# roles/nginx/handlers/main.yml
---
- name: restart nginx
  service:
    name: "{{ nginx_service_name }}"
    state: restarted

- name: reload nginx
  service:
    name: "{{ nginx_service_name }}"
    state: reloaded
    
- name: test nginx config
  command: /usr/sbin/nginx -t
  register: nginx_test
  changed_when: false
  failed_when: nginx_test.rc != 0
```

```yaml
# roles/nginx/meta/main.yml
---
galaxy_info:
  author: tripheo
  description: Nginx web server role
  company: Company Name
  license: MIT
  min_ansible_version: "2.9"
  
  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - focal
    - name: EL
      versions:
        - 8
        - 9
        
  galaxy_tags:
    - web
    - nginx
    - proxy
    
# Dependencies - Install these roles first
dependencies:
  - role: common              # Chạy 'common' role trước
  - role: ssl-certificates    # Chạy 'ssl-certificates' trước
    when: nginx_https_enabled | default(false)
```

### 1.3 Sử Dụng Role Trong Playbook

```yaml
# site.yml
---
- name: Configure web servers
  hosts: webservers
  become: yes
  
  roles:
    # Simple usage
    - common
    - nginx
    
    # With variables
    - role: nginx
      vars:
        nginx_worker_processes: 8
        nginx_worker_connections: 4096
        nginx_sites:
          - name: api
            domains: [api.company.com]
            upstream: api_backend
            ssl_cert: /etc/ssl/api.pem
            ssl_key: /etc/ssl/api.key
          - name: web
            domains: [www.company.com, company.com]
            root: /var/www/web
        nginx_upstreams:
          - name: api_backend
            servers:
              - host: 10.0.1.10
                port: 8080
              - host: 10.0.1.11
                port: 8080
                
    # Conditional role
    - role: certbot
      when: ssl_provider == "letsencrypt"
      
    - role: monitoring-agent
      tags: monitoring
```

---

## 2. Ansible Galaxy - Community Roles

### 2.1 Dùng Galaxy Roles

```bash
# Tìm kiếm roles
ansible-galaxy role search nginx
ansible-galaxy role search nginx --author geerlingguy

# Xem info về role
ansible-galaxy role info geerlingguy.nginx

# Cài đặt role
ansible-galaxy role install geerlingguy.nginx
ansible-galaxy role install geerlingguy.nginx,v1.9.1    # Specific version

# Cài từ requirements file (BEST PRACTICE)
cat > requirements.yml << 'EOF'
---
roles:
  - name: geerlingguy.nginx
    version: 3.1.0
  - name: geerlingguy.postgresql
    version: 3.3.0
  - name: geerlingguy.redis
    version: 6.0.0
  - src: https://github.com/company/ansible-role-custom.git
    scm: git
    version: main
    name: company.custom

collections:
  - name: community.general
    version: ">=7.0.0"
  - name: community.postgresql
    version: 3.0.0
  - name: amazon.aws
    version: 7.0.0
EOF

ansible-galaxy install -r requirements.yml
ansible-galaxy collection install -r requirements.yml

# Xem installed roles
ansible-galaxy role list

# Xóa role
ansible-galaxy role remove geerlingguy.nginx
```

### 2.2 Collections

```bash
# Ansible Collections = Bundle của modules, roles, plugins

# Cấu trúc collection:
# namespace/
# └── collection_name/
#     ├── docs/
#     ├── galaxy.yml
#     ├── plugins/
#     │   ├── modules/
#     │   ├── filter/
#     │   └── callback/
#     └── roles/

# Cài collection
ansible-galaxy collection install community.docker
ansible-galaxy collection install kubernetes.core

# Dùng module từ collection
- name: Start container
  community.docker.docker_container:
    name: myapp
    image: myapp:latest
    state: started
    
# Hoặc dùng FQCN (Fully Qualified Collection Name)
- name: Deploy to k8s
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: apps/v1
      kind: Deployment
      ...
```

---

## 3. Ansible Vault - Bảo Mật Secrets

### 3.1 Vault Cơ Bản

```bash
# Ansible Vault mã hóa files với AES-256

# Tạo encrypted file
ansible-vault create secrets.yml
# → Mở editor, nhập password, viết content

# Encrypt file có sẵn
ansible-vault encrypt vars/passwords.yml

# Xem encrypted file
ansible-vault view secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Decrypt file
ansible-vault decrypt vars/passwords.yml

# Đổi password
ansible-vault rekey secrets.yml

# ===== ENCRYPT INLINE VALUES =====
ansible-vault encrypt_string 'mysecretpassword' --name db_password
# !vault |
#   $ANSIBLE_VAULT;1.1;AES256
#   63343838363265...

# Dùng trong vars file:
# vars/secrets.yml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  63343838363265336131313133306331...
```

### 3.2 Chạy Playbook Với Vault

```bash
# Prompt nhập password
ansible-playbook site.yml --ask-vault-pass

# Dùng password file (cho CI/CD)
echo "mysecretvaultpassword" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook site.yml --vault-password-file ~/.vault_pass

# Cấu hình trong ansible.cfg
# vault_password_file = ~/.vault_pass

# Multiple vault passwords (khác nhau cho staging/prod)
ansible-vault encrypt_string 'prodpassword' --vault-id prod@prompt
ansible-vault encrypt_string 'stagingpass' --vault-id staging@prompt

ansible-playbook site.yml \
  --vault-id prod@~/.vault_pass_prod \
  --vault-id staging@~/.vault_pass_staging
```

### 3.3 Best Practices Vault

```bash
# ===== CẤU TRÚC SECRETS =====
# vars/
# ├── main.yml           ← Non-secret variables
# └── vault.yml          ← Encrypted secrets only

# vars/main.yml:
db_host: db.company.com
db_port: 5432
db_name: myapp
db_username: app
db_password: "{{ vault_db_password }}"   ← Prefix 'vault_'
api_key: "{{ vault_api_key }}"

# vars/vault.yml (encrypted!):
vault_db_password: "SuperSecretPassword123!"
vault_api_key: "sk-1234567890abcdef"

# ===== GIT HOOKS để tránh commit unencrypted secrets =====
cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
# Check if vault files are encrypted
for file in $(git diff --cached --name-only | grep "vault"); do
    if ! grep -q '$ANSIBLE_VAULT' "$file"; then
        echo "ERROR: $file is not encrypted! Run: ansible-vault encrypt $file"
        exit 1
    fi
done
HOOK
chmod +x .git/hooks/pre-commit
```

---

## 4. Advanced Ansible Patterns

### 4.1 Rolling Updates (Không Downtime Deploy)

```yaml
# site.yml - Rolling deployment với zero downtime
- name: Rolling deployment
  hosts: webservers
  serial: "25%"              # Cập nhật 25% servers cùng lúc (rolling)
  max_fail_percentage: 0     # Dừng nếu bất kỳ server nào fail
  
  pre_tasks:
    # Lấy server ra khỏi load balancer
    - name: Remove from load balancer
      uri:
        url: "http://lb.company.com/api/servers/{{ inventory_hostname }}/disable"
        method: POST
      delegate_to: localhost
      
    # Chờ connections hiện tại kết thúc
    - name: Wait for connections to drain
      pause:
        seconds: 30
        
  tasks:
    - name: Stop application
      service:
        name: myapp
        state: stopped
        
    - name: Deploy new version
      unarchive:
        src: "builds/myapp-{{ new_version }}.tar.gz"
        dest: /opt/myapp/
        remote_src: no
        
    - name: Run database migrations
      command: /opt/myapp/bin/migrate
      run_once: true          # Chỉ chạy trên 1 server!
      delegate_to: "{{ groups['webservers'][0] }}"
      
    - name: Start application
      service:
        name: myapp
        state: started
        
    - name: Health check
      uri:
        url: "http://localhost:8080/health"
        status_code: 200
      retries: 10
      delay: 5
      
  post_tasks:
    # Đưa server vào load balancer trở lại
    - name: Add back to load balancer
      uri:
        url: "http://lb.company.com/api/servers/{{ inventory_hostname }}/enable"
        method: POST
      delegate_to: localhost
```

### 4.2 Delegate - Chạy Task Trên Host Khác

```yaml
tasks:
  # Chạy task trên control node (local)
  - name: Generate config locally
    template:
      src: config.j2
      dest: /tmp/config.yml
    delegate_to: localhost
    
  # Chạy trên 1 host cụ thể
  - name: Update DNS record
    shell: |
      curl -X PUT "https://api.cloudflare.com/client/v4/zones/.../dns_records/..." \
        -H "Authorization: Bearer {{ cloudflare_token }}" \
        -d '{"content": "{{ ansible_host }}"}'
    delegate_to: dns-manager.company.com
    run_once: true             # Chỉ 1 lần cho cả group
    
  # Fetch file từ remote
  - name: Get SSL cert from cert server
    fetch:
      src: /etc/ssl/company.pem
      dest: /tmp/certs/
    delegate_to: cert-server.company.com
    run_once: true
    
  # Wait for host on another host
  - name: Wait for database to be ready
    wait_for:
      host: "{{ hostvars['db01']['ansible_host'] }}"
      port: 5432
      timeout: 300
    delegate_to: localhost
```

### 4.3 Strategy Plugins

```yaml
# ===== LINEAR (Mặc định) =====
# Tất cả hosts chạy task 1 xong → chuyển sang task 2
- hosts: webservers
  strategy: linear   # Host 1 task 1, Host 2 task 1 → Host 1 task 2, Host 2 task 2

# ===== FREE =====
# Mỗi host chạy hết speed, không cần đợi host khác
- hosts: webservers
  strategy: free     # Nhanh hơn, nhưng không kiểm soát thứ tự

# ===== HOST_PINNED =====
# 1 host xong hoàn toàn mới đến host tiếp theo
- hosts: webservers
  strategy: host_pinned   # Tuần tự hoàn toàn

# ===== DEBUG STRATEGY =====
- hosts: webservers
  strategy: debug    # Interactive debugger sau mỗi task
```

### 4.4 Custom Modules

```python
# library/check_service_health.py
#!/usr/bin/env python3

from ansible.module_utils.basic import AnsibleModule
import requests
import json

def main():
    module = AnsibleModule(
        argument_spec=dict(
            url=dict(type='str', required=True),
            timeout=dict(type='int', default=10),
            expected_status=dict(type='int', default=200),
            check_body=dict(type='str', default=None),
        ),
        supports_check_mode=True
    )
    
    url = module.params['url']
    timeout = module.params['timeout']
    expected_status = module.params['expected_status']
    check_body = module.params['check_body']
    
    if module.check_mode:
        module.exit_json(changed=False, msg="Check mode - would check: " + url)
    
    try:
        response = requests.get(url, timeout=timeout)
        
        result = {
            'url': url,
            'status_code': response.status_code,
            'response_time_ms': response.elapsed.total_seconds() * 1000,
        }
        
        if response.status_code != expected_status:
            module.fail_json(
                msg=f"Expected status {expected_status}, got {response.status_code}",
                **result
            )
            
        if check_body and check_body not in response.text:
            module.fail_json(
                msg=f"Expected '{check_body}' in response body",
                **result
            )
            
        module.exit_json(changed=False, healthy=True, **result)
        
    except requests.exceptions.Timeout:
        module.fail_json(msg=f"Request timed out after {timeout} seconds", url=url)
    except Exception as e:
        module.fail_json(msg=str(e), url=url)

if __name__ == '__main__':
    main()
```

```yaml
# Dùng custom module trong playbook
- name: Check API health
  check_service_health:
    url: "https://api.company.com/health"
    timeout: 5
    expected_status: 200
    check_body: '"status": "healthy"'
  register: health
  
- name: Show health status
  debug:
    msg: "API responded in {{ health.response_time_ms }}ms"
```

---

## 5. Callback Plugins & Notifications

```yaml
# ansible.cfg
[defaults]
callback_whitelist = timer, profile_tasks, slack

# Kết quả mỗi task kèm timing
# stdout_callback = yaml   (đẹp hơn mặc định)
```

```python
# callback_plugins/slack_notify.py
# Gửi Slack notification khi playbook hoàn thành

from ansible.plugins.callback import CallbackBase
import urllib.request
import json

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'slack_notify'
    
    def v2_playbook_on_stats(self, stats):
        hosts = sorted(stats.processed.keys())
        summary = []
        
        for h in hosts:
            s = stats.summarize(h)
            if s['failures'] > 0 or s['unreachable'] > 0:
                status = "❌ FAILED"
            else:
                status = "✅ OK"
            summary.append(f"{h}: {status} | changed={s['changed']} failed={s['failures']}")
            
        message = {
            "text": f"Ansible playbook completed:\n" + "\n".join(summary)
        }
        
        webhook_url = "https://hooks.slack.com/services/XXX/YYY/ZZZ"
        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(message).encode(),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
```

---

## 6. Testing Ansible Roles với Molecule

### 6.1 Molecule Setup

```bash
# Cài đặt
pip install molecule molecule-docker

# Khởi tạo trong role
cd roles/nginx
molecule init scenario default --driver-name docker

# Cấu trúc tạo ra:
# molecule/
# └── default/
#     ├── molecule.yml   ← Cấu hình test
#     ├── converge.yml   ← Playbook chạy role
#     ├── verify.yml     ← Verify sau khi chạy
#     └── prepare.yml    ← Chuẩn bị môi trường
```

```yaml
# molecule/default/molecule.yml
---
dependency:
  name: galaxy
  
driver:
  name: docker
  
platforms:
  - name: ubuntu2204
    image: "ubuntu:22.04"
    pre_build_image: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    command: "/lib/systemd/systemd"
    
  - name: centos9
    image: "quay.io/centos/centos:stream9"
    pre_build_image: true

provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
    verify: verify.yml
    
verifier:
  name: ansible
  
lint: |
  set -e
  yamllint .
  ansible-lint
```

```yaml
# molecule/default/converge.yml
---
- name: Converge
  hosts: all
  become: yes
  
  vars:
    nginx_sites:
      - name: test
        domains: [localhost]
        root: /var/www/html
        
  roles:
    - role: nginx
```

```yaml
# molecule/default/verify.yml
---
- name: Verify
  hosts: all
  become: yes
  
  tasks:
    - name: Check nginx is installed
      command: nginx -v
      register: nginx_version
      changed_when: false
      
    - name: Verify nginx version output
      assert:
        that:
          - nginx_version.rc == 0
          
    - name: Check nginx service is running
      service_facts:
      
    - name: Assert nginx is running
      assert:
        that:
          - "'nginx' in services"
          - "services['nginx'].state == 'running'"
          - "services['nginx'].status == 'enabled'"
          
    - name: Check port 80 is listening
      wait_for:
        port: 80
        timeout: 5
        
    - name: Check nginx responds
      uri:
        url: http://localhost/
        status_code: [200, 301, 302, 404]  # Any is OK
```

```bash
# Chạy tests
cd roles/nginx
molecule test           # Full test cycle (create → converge → verify → destroy)
molecule create         # Chỉ tạo containers
molecule converge       # Chỉ chạy playbook
molecule verify         # Chỉ verify
molecule login          # SSH vào test container
molecule destroy        # Xóa containers

# Lint
molecule lint
ansible-lint site.yml
yamllint .
```

---

> **Tiếp theo: Phần 4** - Ansible trong CI/CD, Production Patterns & Real-world Scenarios
