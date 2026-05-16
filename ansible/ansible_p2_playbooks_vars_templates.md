# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 2: PLAYBOOKS, VARIABLES & TEMPLATES

---

## 1. Playbook - Cấu Trúc Đầy Đủ

### 1.1 Anatomy of a Playbook

```yaml
# site.yml - Full playbook example

---  # YAML document start (tùy chọn)

# ===== PLAY 1: Configure webservers =====
- name: Configure web servers            # Mô tả play
  hosts: webservers                      # Target hosts
  become: yes                            # Use sudo
  become_user: root                      # Become this user
  gather_facts: yes                      # Collect facts (default: yes)
  any_errors_fatal: false                # Dừng tất cả nếu 1 host lỗi?
  max_fail_percentage: 20                # Cho phép tối đa 20% hosts lỗi
  serial: 2                              # Xử lý 2 hosts cùng lúc (rolling)
  
  # Variables scope: play level
  vars:
    app_name: myapp
    app_port: 8080
    nginx_version: "1.25.0"
    
  # Load variables từ file
  vars_files:
    - vars/common.yml
    - vars/webserver.yml
    
  # Chạy trước tasks
  pre_tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      tags: always
      
  # Main tasks
  tasks:
    - name: Install Nginx
      apt:
        name: nginx={{ nginx_version }}
        state: present
      tags:
        - install
        - nginx
        
    - name: Configure Nginx
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
        backup: yes           # Backup file cũ trước khi replace
        validate: /usr/sbin/nginx -t -c %s  # Validate trước khi deploy
      notify: restart nginx   # Trigger handler
      tags:
        - configure
        - nginx
        
    - name: Ensure web directory exists
      file:
        path: /var/www/{{ app_name }}
        state: directory
        owner: www-data
        group: www-data
        mode: '0755'
        
    - name: Deploy application
      git:
        repo: "https://github.com/company/{{ app_name }}.git"
        dest: /var/www/{{ app_name }}
        version: "{{ app_version | default('main') }}"
        force: yes
      notify: reload application
      
  # Handlers: Chỉ chạy khi được notify (và chỉ 1 lần dù notify nhiều lần)
  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
        
    - name: reload nginx
      service:
        name: nginx
        state: reloaded
        
    - name: reload application
      shell: systemctl reload {{ app_name }}

  # Chạy sau tasks (dù task fail)
  post_tasks:
    - name: Verify nginx is running
      uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
      retries: 5
      delay: 2

# ===== PLAY 2: Configure databases =====
- name: Configure databases
  hosts: databases
  become: yes
  
  roles:
    - role: postgresql
      vars:
        pg_version: 15
        pg_max_connections: 200
        pg_shared_buffers: "2GB"
```

### 1.2 Tags - Chạy Phần Cụ Thể

```bash
# Tags cho phép chạy/bỏ qua tasks cụ thể

# Xem tất cả tags
ansible-playbook site.yml --list-tags

# Chỉ chạy tasks với tag "nginx"
ansible-playbook site.yml --tags nginx

# Chạy nhiều tags
ansible-playbook site.yml --tags "nginx,deploy"

# Skip tags
ansible-playbook site.yml --skip-tags deploy

# Special tags:
# always: Luôn chạy (dù có --tags gì)
# never: Chỉ chạy khi explicitly --tags never
# tagged: Chỉ chạy tasks có tag
# untagged: Chỉ chạy tasks không có tag
# all: Chạy tất cả (default)
```

---

## 2. Variables - Hệ Thống Biến

### 2.1 Variable Precedence (Quan Trọng!)

Ansible có **22 cấp precedence**. Cấp cao hơn = override cấp thấp hơn:

```
Thấp nhất → Cao nhất:
1. Command line values (ansible-playbook --extra-vars)
   (Cao nhất! Override tất cả)
   
...giữa...

15. Play vars_files
16. Play vars
17. Task vars (task level "vars:")
18. set_facts / registered vars
19. Role defaults (lowest role priority)
20. Inventory host vars
21. Playbook host_vars/*
22. Inventory group vars
...
(Thấp nhất)
```

**Thực tế cần nhớ:**
```
extra-vars > host_vars > group_vars > role defaults
```

### 2.2 Các Loại Variables

```yaml
# ===== 1. PLAYBOOK VARS =====
- name: Play level vars
  hosts: webservers
  vars:
    app_port: 8080
    debug_mode: false
    allowed_ips:
      - 10.0.0.0/8
      - 192.168.0.0/16
    database:
      host: db.company.com
      port: 5432
      name: myapp

# ===== 2. VARS_FILES =====
  vars_files:
    - vars/main.yml
    - "vars/{{ ansible_os_family }}.yml"  # Dynamic file name!

# vars/main.yml:
app_name: myapp
app_version: "2.1.0"
nginx_config:
  worker_processes: auto
  worker_connections: 1024
  
# ===== 3. INVENTORY VARS =====
# inventory/group_vars/all.yml  ← Apply cho tất cả hosts
ntp_server: ntp.company.com
timezone: Asia/Ho_Chi_Minh
log_level: info

# inventory/group_vars/webservers.yml  ← Chỉ webservers group
http_port: 80
https_port: 443
ssl_certificate: /etc/ssl/certs/company.pem

# inventory/group_vars/databases.yml  ← Chỉ databases group
pg_version: 15
pg_data_dir: /var/lib/postgresql/15/main

# inventory/host_vars/web01.yml  ← Chỉ host web01
nginx_worker_processes: 8      # Override group var
primary_node: true

# ===== 4. EXTRA VARS (Command Line) =====
ansible-playbook site.yml -e "app_version=2.2.0 debug_mode=true"
ansible-playbook site.yml -e "@override.yml"    # Từ file
```

### 2.3 Variable Types & Usage

```yaml
# String
app_name: "myapp"

# Number
port: 8080
timeout: 30

# Boolean
debug_mode: false     # false/true, no/yes, off/on

# List
packages:
  - nginx
  - postgresql
  - redis
# Inline: packages: [nginx, postgresql, redis]

# Dictionary
database:
  host: localhost
  port: 5432
  name: myapp
  credentials:
    username: app
    password: "{{ vault_db_password }}"  # Từ Ansible Vault

# ===== DÙNG VARIABLES TRONG TASKS =====
tasks:
  - name: Start {{ app_name }} on port {{ port }}
    service:
      name: "{{ app_name }}"
      state: started
      
  - name: Install packages
    apt:
      name: "{{ packages }}"    # Pass list trực tiếp!
      state: present
      
  - name: Connect to database
    shell: |
      psql -h {{ database.host }} \
           -p {{ database.port }} \
           -d {{ database.name }} \
           -U {{ database.credentials.username }}
           
  # Default value với | default()
  - name: Deploy
    shell: deploy.sh {{ target_env | default('staging') }}
    
  # Conditional với variables
  - name: Enable debug logging
    lineinfile:
      path: /etc/app/config.yml
      line: "debug: true"
    when: debug_mode | bool
```

### 2.4 set_fact & register

```yaml
# register - Lưu output của task vào variable
- name: Check disk space
  command: df -h /
  register: disk_info          # Lưu output vào disk_info

- name: Show disk info
  debug:
    var: disk_info.stdout      # disk_info.stdout, .stderr, .rc, .stdout_lines

- name: Check if low disk space
  debug:
    msg: "WARNING: Low disk space!"
  when: disk_info.rc == 0 and "85%" in disk_info.stdout

# ===== THỰC TẾ: Lấy version installed =====
- name: Get Nginx version
  command: nginx -v
  register: nginx_version_output
  changed_when: false          # Đánh dấu không phải "change"

- name: Show nginx version
  debug:
    msg: "Nginx version: {{ nginx_version_output.stderr }}"
    
# set_fact - Tạo variable động trong playbook
- name: Get current timestamp
  set_fact:
    deploy_timestamp: "{{ ansible_date_time.iso8601 }}"
    backup_dir: "/backup/{{ ansible_hostname }}/{{ ansible_date_time.date }}"
    
- name: Create backup directory
  file:
    path: "{{ backup_dir }}"
    state: directory
    
# Tính toán với variables
- name: Calculate memory limit (50% of total RAM)
  set_fact:
    max_memory_mb: "{{ (ansible_memtotal_mb * 0.5) | int }}"

- name: Configure app memory
  lineinfile:
    path: /etc/app/config.yml
    regexp: '^max_memory:'
    line: "max_memory: {{ max_memory_mb }}m"
```

---

## 3. Jinja2 Templates

### 3.1 Template Cơ Bản

```bash
# Templates được lưu trong thư mục templates/ với extension .j2
# Sử dụng Jinja2 templating engine
```

```jinja2
{# templates/nginx.conf.j2 - Dấu {# #} là comment trong Jinja2 #}

# Nginx Configuration
# Generated by Ansible on {{ ansible_date_time.date }}
# Host: {{ ansible_hostname }}

user www-data;
worker_processes {{ nginx_worker_processes | default('auto') }};
worker_rlimit_nofile 65535;

error_log /var/log/nginx/error.log {{ log_level | default('warn') }};
pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections | default(1024) }};
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout {{ keepalive_timeout | default(65) }};
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    # Rate limiting (nếu được cấu hình)
    {% if nginx_rate_limit is defined %}
    limit_req_zone $binary_remote_addr zone=api:{{ nginx_rate_limit.zone_size | default('10m') }} 
        rate={{ nginx_rate_limit.rate }};
    {% endif %}
    
    # Upstream backends
    {% if backend_servers is defined %}
    upstream {{ app_name }}_backend {
        {% for server in backend_servers %}
        server {{ server.host }}:{{ server.port }} weight={{ server.weight | default(1) }};
        {% endfor %}
        
        keepalive 32;
    }
    {% endif %}
    
    # Virtual hosts
    {% for vhost in virtual_hosts %}
    server {
        listen {{ http_port | default(80) }};
        {% if https_enabled | default(false) %}
        listen {{ https_port | default(443) }} ssl http2;
        ssl_certificate {{ vhost.ssl_cert }};
        ssl_certificate_key {{ vhost.ssl_key }};
        {% endif %}
        
        server_name {{ vhost.domains | join(' ') }};
        
        {% if vhost.redirect_http | default(false) and https_enabled %}
        # Redirect HTTP → HTTPS
        if ($scheme != "https") {
            return 301 https://$host$request_uri;
        }
        {% endif %}
        
        root {{ vhost.root | default('/var/www/' + vhost.name) }};
        
        location / {
            {% if backend_servers is defined %}
            proxy_pass http://{{ app_name }}_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            {% else %}
            try_files $uri $uri/ /index.html;
            {% endif %}
        }
        
        {% if vhost.health_check | default(false) %}
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        {% endif %}
    }
    {% endfor %}
}
```

### 3.2 Jinja2 Syntax Chi Tiết

```jinja2
{# VARIABLES #}
{{ variable }}
{{ variable | default("fallback") }}
{{ nested.variable.value }}
{{ list[0] }}                  {# First element #}
{{ dict.key }}

{# FILTERS - Transform variables #}
{{ name | upper }}             {# UPPERCASE #}
{{ name | lower }}             {# lowercase #}
{{ name | capitalize }}        {# Capitalize #}
{{ text | replace('old', 'new') }}
{{ list | join(', ') }}        {# Join list #}
{{ number | int }}             {# To integer #}
{{ number | float }}           {# To float #}
{{ text | length }}            {# Length #}
{{ value | bool }}             {# To boolean #}
{{ items | sort }}             {# Sort list #}
{{ items | unique }}           {# Remove duplicates #}
{{ dict | dict2items }}        {# Dict to list of {key, value} #}
{{ size_bytes | filesizeformat }}  {# 1.2 GB #}
{{ text | b64encode }}         {# Base64 encode #}
{{ encoded | b64decode }}      {# Base64 decode #}
{{ text | sha256 }}            {# SHA256 hash #}
{{ ip | ipaddr('network') }}   {# Network address #}

{# CONDITIONALS #}
{% if condition %}
  content if true
{% elif other_condition %}
  content if other true
{% else %}
  content if false
{% endif %}

{# LOOPS #}
{% for item in list %}
  Line {{ loop.index }}: {{ item }}   {# loop.index = 1,2,3... #}
  {# loop.index0 = 0,1,2... #}
  {# loop.first = True on first #}
  {# loop.last = True on last #}
  {# loop.length = total count #}
{% endfor %}

{# Loop với condition #}
{% for server in backend_servers if server.active %}
  server {{ server.ip }}:{{ server.port }};
{% endfor %}

{# MACROS (reusable template snippets) #}
{% macro server_block(name, port, weight=1) %}
server {{ name }}:{{ port }} weight={{ weight }};
{% endmacro %}

{{ server_block('web01', 8080) }}
{{ server_block('web02', 8080, weight=2) }}

{# INCLUDE other templates #}
{% include 'snippets/ssl.conf.j2' %}

{# WHITESPACE CONTROL #}
{%- for item in list -%}   {# - strip whitespace #}
{{ item }}
{%- endfor -%}
```

### 3.3 Templates Thực Tế

```jinja2
{# templates/prometheus.yml.j2 #}
global:
  scrape_interval: {{ prometheus_scrape_interval | default('15s') }}
  evaluation_interval: 15s
  
alerting:
  alertmanagers:
    {% for am in alertmanager_hosts %}
    - static_configs:
        - targets:
          - {{ am.host }}:{{ am.port | default(9093) }}
    {% endfor %}

rule_files:
  {% for rule_file in prometheus_rule_files | default([]) %}
  - {{ rule_file }}
  {% endfor %}

scrape_configs:
  # Node exporters
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        {% for host in groups['all'] %}
        - '{{ hostvars[host]['ansible_host'] | default(host) }}:9100'
        {% endfor %}
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+)(:\d+)?'
        target_label: instance
        replacement: '$1'

  # Application metrics
  {% for app in monitored_applications | default([]) %}
  - job_name: '{{ app.name }}'
    metrics_path: {{ app.metrics_path | default('/metrics') }}
    static_configs:
      - targets:
        {% for target in app.targets %}
        - '{{ target }}'
        {% endfor %}
  {% endfor %}
```

```jinja2
{# templates/postgresql.conf.j2 #}
# PostgreSQL Configuration
# Generated by Ansible - DO NOT EDIT MANUALLY

# Connection Settings
listen_addresses = '{{ pg_listen_addresses | default("localhost") }}'
port = {{ pg_port | default(5432) }}
max_connections = {{ pg_max_connections | default(100) }}

# Memory Settings
shared_buffers = {{ pg_shared_buffers | default("128MB") }}
work_mem = {{ pg_work_mem | default("4MB") }}
maintenance_work_mem = {{ pg_maintenance_work_mem | default("64MB") }}
effective_cache_size = {{ pg_effective_cache_size | default("4GB") }}

{# Calculate based on total RAM if not specified #}
{% if pg_shared_buffers is not defined %}
{# 25% of total RAM #}
shared_buffers = {{ (ansible_memtotal_mb * 0.25) | int }}MB
{% endif %}

# WAL Settings
wal_level = {{ pg_wal_level | default('replica') }}
{% if pg_replication_enabled | default(false) %}
max_wal_senders = {{ pg_max_wal_senders | default(3) }}
wal_keep_size = {{ pg_wal_keep_size | default('1GB') }}
{% endif %}

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 1GB
log_min_duration_statement = {{ pg_slow_query_threshold | default(1000) }}  # ms
log_checkpoints = on
log_connections = {{ 'on' if pg_log_connections | default(false) else 'off' }}
log_disconnections = off

# Autovacuum
autovacuum = on
autovacuum_max_workers = {{ pg_autovacuum_workers | default(3) }}
autovacuum_naptime = 1min
```

---

## 4. Conditionals & Loops

### 4.1 when - Điều Kiện

```yaml
tasks:
  # ===== So sánh đơn giản =====
  - name: Install nginx on Debian
    apt:
      name: nginx
    when: ansible_os_family == "Debian"
    
  - name: Install nginx on RedHat
    yum:
      name: nginx
    when: ansible_os_family == "RedHat"
    
  # ===== Toán tử =====
  # ==, !=, <, >, <=, >=
  # and, or, not
  # in (kiểm tra list membership)
  
  - name: Configure for high-memory servers
    template:
      src: nginx-highperf.conf.j2
      dest: /etc/nginx/nginx.conf
    when:
      - ansible_memtotal_mb >= 8192     # AND condition
      - ansible_processor_cores >= 4
      
  - name: Deploy in non-production
    shell: ./deploy-test.sh
    when: environment == "staging" or environment == "dev"
    
  # ===== Kiểm tra variable tồn tại =====
  - name: Configure optional feature
    template:
      src: feature.conf.j2
      dest: /etc/app/feature.conf
    when: feature_config is defined
    
  - name: Skip if already done
    shell: ./setup.sh
    when: setup_complete is not defined or not setup_complete
    
  # ===== Kiểm tra kết quả task trước =====
  - name: Check if service exists
    command: systemctl status myapp
    register: myapp_status
    failed_when: false          # Đừng fail kể cả khi lệnh lỗi
    changed_when: false
    
  - name: Install app if not running
    include_tasks: install-app.yml
    when: myapp_status.rc != 0
    
  # ===== Kiểm tra file/directory =====
  - name: Check if config exists
    stat:
      path: /etc/app/config.yml
    register: config_file
    
  - name: Create default config
    template:
      src: config.yml.j2
      dest: /etc/app/config.yml
    when: not config_file.stat.exists
    
  # ===== Kiểm tra theo group =====
  - name: Apply web-specific config
    template:
      src: web.conf.j2
      dest: /etc/app/web.conf
    when: "'webservers' in group_names"
    
  # ===== Kiểm tra version =====
  - name: Use new API (requires Python 3.8+)
    shell: ./use-new-api.py
    when: ansible_python_version is version('3.8', '>=')
```

### 4.2 loop - Vòng Lặp

```yaml
tasks:
  # ===== LOOP ĐƠN GIẢN =====
  - name: Install packages
    apt:
      name: "{{ item }}"
      state: present
    loop:
      - nginx
      - postgresql
      - redis
      - certbot
      
  # Hoặc pass cả list
  - name: Install packages (better way)
    apt:
      name: "{{ packages_list }}"    # Tốt hơn! Một task install tất cả
      state: present
      
  # ===== LOOP VỚI DICTIONARY =====
  - name: Create users
    user:
      name: "{{ item.name }}"
      groups: "{{ item.groups }}"
      shell: "{{ item.shell | default('/bin/bash') }}"
      state: present
    loop:
      - name: alice
        groups: sudo,developers
      - name: bob
        groups: developers
        shell: /bin/zsh
      - name: ci-runner
        groups: docker
        shell: /usr/sbin/nologin
        
  # ===== LOOP VỚI DICT (dict2items) =====
  vars:
    virtual_hosts:
      api: api.company.com
      web: www.company.com
      admin: admin.company.com
      
  tasks:
    - name: Create vhost configs
      template:
        src: vhost.conf.j2
        dest: "/etc/nginx/sites-available/{{ item.key }}"
      loop: "{{ virtual_hosts | dict2items }}"
      # item.key = "api", item.value = "api.company.com"
      
  # ===== LOOP VỚI INDEX =====
  - name: Create numbered backups
    copy:
      src: "file{{ item }}.txt"
      dest: "/backup/file{{ item }}-{{ ansible_date_time.date }}.txt"
    loop: "{{ range(1, 6) | list }}"
    # item = 1, 2, 3, 4, 5
    
  # ===== NESTED LOOPS =====
  - name: Grant database access
    mysql_user:
      name: "{{ item[0] }}"
      priv: "{{ item[1] }}.*:ALL"
      state: present
    loop: "{{ ['alice', 'bob'] | product(['db1', 'db2']) | list }}"
    # Combinations: (alice, db1), (alice, db2), (bob, db1), (bob, db2)
    
  # ===== LOOP_CONTROL =====
  - name: Deploy to servers (với label đẹp hơn)
    shell: deploy.sh {{ item.host }}
    loop:
      - { host: web01, env: prod }
      - { host: web02, env: prod }
    loop_control:
      label: "{{ item.host }}"     # Thay vì print cả dict
      pause: 2                     # Chờ 2s giữa iterations
      
  # ===== UNTIL LOOP (retry) =====
  - name: Wait for service to start
    uri:
      url: http://localhost:8080/health
      status_code: 200
    register: health_check
    until: health_check.status == 200
    retries: 10                    # Thử tối đa 10 lần
    delay: 5                       # Chờ 5s giữa lần thử
```

---

## 5. Error Handling

```yaml
tasks:
  # ===== IGNORE ERRORS =====
  - name: Try to stop old service (may not exist)
    service:
      name: old-app
      state: stopped
    ignore_errors: yes             # Tiếp tục dù fail
    
  # ===== FAIL CONDITIONS =====
  - name: Check disk space
    command: df -h /
    register: df_output
    failed_when:
      - df_output.rc != 0
      - "'100%' in df_output.stdout"  # Fail nếu disk 100%
      
  # ===== CHANGED CONDITIONS =====
  - name: Run idempotent script
    command: ./check-and-configure.sh
    register: script_result
    changed_when: "'Configuration updated' in script_result.stdout"
    # Chỉ mark "changed" nếu script output có string này
    
  # ===== BLOCK/RESCUE/ALWAYS =====
  - block:
      - name: Download package
        get_url:
          url: https://releases.company.com/app-v{{ version }}.tar.gz
          dest: /tmp/app.tar.gz
          
      - name: Extract package
        unarchive:
          src: /tmp/app.tar.gz
          dest: /opt/app/
          remote_src: yes
          
      - name: Start application
        service:
          name: myapp
          state: started
          
    rescue:
      # Chạy khi block fail
      - name: Notify team of failure
        uri:
          url: https://hooks.slack.com/services/XXX/YYY/ZZZ
          method: POST
          body_format: json
          body:
            text: "Deployment FAILED on {{ inventory_hostname }}"
            
      - name: Rollback to previous version
        shell: /opt/app/scripts/rollback.sh
        
    always:
      # Luôn chạy dù success hay fail
      - name: Clean up temp files
        file:
          path: /tmp/app.tar.gz
          state: absent
          
      - name: Record deployment attempt
        lineinfile:
          path: /var/log/deployments.log
          line: "{{ ansible_date_time.iso8601 }} - Deploy {{ version }} - {{ 'SUCCESS' if not ansible_failed | default(false) else 'FAILED' }}"
          create: yes
```

---

## 6. Include & Import - Code Reuse

```yaml
# ===== IMPORT (static, parse at playbook load time) =====
- name: Main playbook
  hosts: webservers
  tasks:
    - import_tasks: tasks/install.yml    # Luôn import
    - import_tasks: tasks/configure.yml
    
# ===== INCLUDE (dynamic, parse at runtime) =====
  tasks:
    - include_tasks: "tasks/{{ ansible_os_family }}.yml"  # Dynamic!
    
    - include_tasks: tasks/optional.yml
      when: feature_enabled | bool
      
# ===== INCLUDE PLAYBOOK =====
- import_playbook: playbooks/common.yml
- import_playbook: playbooks/webservers.yml
- import_playbook: playbooks/databases.yml

# ===== INCLUDE VARIABLES =====
  vars_files:
    - vars/common.yml
    
  tasks:
    - include_vars: "vars/{{ env }}.yml"          # Dynamic!
    - include_vars:
        file: vars/secrets.yml
        name: secrets                               # Namespace variables
```

---

> **Tiếp theo: Phần 3** - Roles, Galaxy & Advanced Patterns
