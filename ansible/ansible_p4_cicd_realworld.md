# ⚙️ ANSIBLE TOÀN TẬP - PHẦN 4: CI/CD, PRODUCTION & REAL-WORLD SCENARIOS

---

## 1. Cấu Trúc Dự Án Ansible Chuẩn

### 1.1 Directory Structure Best Practice

```
ansible/                              ← Root của Ansible project
├── ansible.cfg                       ← Cấu hình Ansible
├── site.yml                          ← Master playbook
├── requirements.yml                  ← External roles/collections
│
├── inventory/                        ← Inventory files
│   ├── production/
│   │   ├── hosts                     ← Host definitions
│   │   ├── group_vars/
│   │   │   ├── all.yml               ← Vars cho tất cả
│   │   │   ├── webservers.yml
│   │   │   └── databases.yml
│   │   └── host_vars/
│   │       ├── web01.company.com.yml
│   │       └── db01.company.com.yml
│   └── staging/
│       ├── hosts
│       ├── group_vars/
│       └── host_vars/
│
├── playbooks/                        ← Playbooks
│   ├── site.yml
│   ├── webservers.yml
│   ├── databases.yml
│   └── deploy-app.yml
│
├── roles/                            ← Custom roles
│   ├── common/
│   ├── nginx/
│   ├── postgresql/
│   └── myapp/
│
├── vars/                             ← Shared variables
│   ├── common.yml
│   └── vault.yml                    ← Encrypted!
│
├── templates/                        ← Shared templates (nếu không trong role)
├── files/                            ← Shared static files
│
└── scripts/                          ← Helper scripts
    ├── check-syntax.sh
    ├── run-tests.sh
    └── deploy.sh
```

### 1.2 ansible.cfg Hoàn Chỉnh

```ini
# ansible.cfg
[defaults]
# Inventory
inventory = ./inventory/production

# SSH
remote_user = ubuntu
private_key_file = ~/.ssh/ansible_key
host_key_checking = False

# Performance
forks = 20
timeout = 30
poll_interval = 2

# Output
stdout_callback = yaml         # Đẹp hơn default
stderr_callback = yaml

# Logging
log_path = /var/log/ansible.log

# Vault
vault_password_file = ~/.vault_pass

# Roles path
roles_path = ./roles:~/.ansible/roles

# Retry
retry_files_enabled = False    # Tắt .retry files

# Fact caching (tăng performance)
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible-facts
fact_caching_timeout = 86400   # 24 giờ

# Callback plugins
callback_whitelist = timer, profile_tasks

[privilege_escalation]
become = True
become_method = sudo
become_user = root

[ssh_connection]
# Multiplexing (tái dùng SSH connections - nhanh hơn nhiều!)
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30
pipelining = True             # Giảm SSH connections (performance++)
control_path_dir = /tmp/ansible-ssh

[persistent_connection]
connect_timeout = 30
command_timeout = 300
```

---

## 2. Ansible Trong CI/CD

### 2.1 GitHub Actions + Ansible

```yaml
# .github/workflows/deploy.yml
name: Deploy with Ansible

on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]

jobs:
  # ===== JOB 1: Lint & Syntax Check =====
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          cache: pip
          
      - name: Install Ansible & tools
        run: |
          pip install ansible ansible-lint yamllint
          ansible-galaxy install -r requirements.yml
          
      - name: YAML Lint
        run: yamllint .
        
      - name: Ansible Lint
        run: ansible-lint playbooks/site.yml
        
      - name: Syntax Check
        run: |
          ansible-playbook playbooks/site.yml \
            -i inventory/staging \
            --syntax-check
            
  # ===== JOB 2: Deploy to Staging =====
  deploy-staging:
    needs: lint
    runs-on: ubuntu-latest
    environment: staging
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Ansible
        run: pip install ansible boto3
        
      - name: Install Galaxy requirements
        run: ansible-galaxy install -r requirements.yml
        
      - name: Setup SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.ANSIBLE_SSH_PRIVATE_KEY }}" > ~/.ssh/ansible_key
          chmod 600 ~/.ssh/ansible_key
          
      - name: Setup known_hosts
        run: |
          ssh-keyscan -H staging.company.com >> ~/.ssh/known_hosts
          
      - name: Write Vault password
        run: echo "${{ secrets.ANSIBLE_VAULT_PASS }}" > ~/.vault_pass
        
      - name: Run Ansible Playbook
        run: |
          ansible-playbook playbooks/site.yml \
            -i inventory/staging \
            --vault-password-file ~/.vault_pass \
            -e "app_version=${{ github.sha }}" \
            -e "env=staging" \
            -v
        env:
          ANSIBLE_HOST_KEY_CHECKING: False
          
      - name: Post-deployment health check
        run: |
          ansible-playbook playbooks/health-check.yml \
            -i inventory/staging \
            --vault-password-file ~/.vault_pass
            
  # ===== JOB 3: Deploy to Production =====
  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: 
      name: production
      url: https://app.company.com
    if: startsWith(github.ref, 'refs/tags/v')
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Ansible
        run: pip install ansible boto3
        
      - name: Install Galaxy requirements
        run: ansible-galaxy install -r requirements.yml
        
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.PROD_SSH_KEY }}" > ~/.ssh/ansible_key
          chmod 600 ~/.ssh/ansible_key
          
      - name: Write Vault password
        run: echo "${{ secrets.PROD_VAULT_PASS }}" > ~/.vault_pass
        
      - name: Deploy to Production (Rolling)
        run: |
          ansible-playbook playbooks/deploy-rolling.yml \
            -i inventory/production \
            --vault-password-file ~/.vault_pass \
            -e "app_version=${{ github.ref_name }}" \
            -e "env=production"
            
      - name: Notify Slack
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment ${{ job.status }}: ${{ github.ref_name }} to production",
              "attachments": [{
                "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
                "text": "Deployed by ${{ github.actor }}"
              }]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 2.2 GitLab CI + Ansible

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - deploy-staging
  - deploy-production

variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"
  ANSIBLE_FORCE_COLOR: "True"

# Cache Galaxy dependencies
cache:
  paths:
    - ~/.ansible/roles
    - ~/.ansible/collections

.ansible-setup: &ansible-setup
  before_script:
    - pip install ansible ansible-lint
    - ansible-galaxy install -r requirements.yml
    - mkdir -p ~/.ssh
    - echo "$ANSIBLE_SSH_KEY" | base64 -d > ~/.ssh/id_ed25519
    - chmod 600 ~/.ssh/id_ed25519
    - echo "$VAULT_PASSWORD" > ~/.vault_pass

validate:
  stage: validate
  image: python:3.11
  <<: *ansible-setup
  script:
    - yamllint .
    - ansible-lint
    - ansible-playbook playbooks/site.yml -i inventory/staging --syntax-check
  only:
    - merge_requests
    - main

deploy:staging:
  stage: deploy-staging
  image: python:3.11
  <<: *ansible-setup
  environment:
    name: staging
    url: https://staging.company.com
  script:
    - ansible-playbook playbooks/site.yml
        -i inventory/staging
        --vault-password-file ~/.vault_pass
        -e "app_version=$CI_COMMIT_SHA"
  only:
    - main

deploy:production:
  stage: deploy-production
  image: python:3.11
  <<: *ansible-setup
  environment:
    name: production
    url: https://app.company.com
  script:
    - ansible-playbook playbooks/deploy-rolling.yml
        -i inventory/production
        --vault-password-file ~/.vault_pass
        -e "app_version=$CI_COMMIT_TAG"
  when: manual              # Require manual trigger
  only:
    - tags
```

---

## 3. Real-World Scenarios

### 3.1 Scenario: Full LAMP Stack Setup

```yaml
# playbooks/lamp.yml
---
- name: Setup LAMP Stack
  hosts: webservers
  become: yes
  vars_files:
    - ../vars/common.yml
    - ../vars/vault.yml
    
  vars:
    php_version: "8.2"
    mysql_root_password: "{{ vault_mysql_root_password }}"
    app_db_name: myapp
    app_db_user: app
    app_db_password: "{{ vault_app_db_password }}"
    
  tasks:
    # ===== APACHE =====
    - name: Install Apache
      apt:
        name:
          - apache2
          - apache2-utils
        state: present
        update_cache: yes
        
    - name: Enable Apache modules
      apache2_module:
        name: "{{ item }}"
        state: present
      loop:
        - rewrite
        - ssl
        - headers
        - proxy
        - proxy_http
      notify: restart apache
      
    # ===== PHP =====
    - name: Add PHP repository
      apt_repository:
        repo: "ppa:ondrej/php"
        state: present
        
    - name: Install PHP and extensions
      apt:
        name:
          - "php{{ php_version }}"
          - "php{{ php_version }}-cli"
          - "php{{ php_version }}-fpm"
          - "php{{ php_version }}-mysql"
          - "php{{ php_version }}-redis"
          - "php{{ php_version }}-curl"
          - "php{{ php_version }}-gd"
          - "php{{ php_version }}-mbstring"
          - "php{{ php_version }}-xml"
          - "php{{ php_version }}-zip"
        state: present
        
    - name: Configure PHP-FPM
      template:
        src: ../templates/php-fpm-pool.conf.j2
        dest: "/etc/php/{{ php_version }}/fpm/pool.d/www.conf"
      notify: restart php-fpm
      
    # ===== MYSQL =====
    - name: Install MySQL
      apt:
        name:
          - mysql-server
          - python3-pymysql      # Cần cho Ansible mysql modules
        state: present
        
    - name: Start and enable MySQL
      service:
        name: mysql
        state: started
        enabled: yes
        
    - name: Set MySQL root password
      mysql_user:
        name: root
        host: localhost
        password: "{{ mysql_root_password }}"
        login_unix_socket: /var/run/mysqld/mysqld.sock
        state: present
        
    - name: Remove anonymous users
      mysql_user:
        name: ''
        host_all: yes
        state: absent
        login_user: root
        login_password: "{{ mysql_root_password }}"
        
    - name: Remove test database
      mysql_db:
        name: test
        state: absent
        login_user: root
        login_password: "{{ mysql_root_password }}"
        
    - name: Create application database
      mysql_db:
        name: "{{ app_db_name }}"
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"
        
    - name: Create application database user
      mysql_user:
        name: "{{ app_db_user }}"
        password: "{{ app_db_password }}"
        priv: "{{ app_db_name }}.*:ALL"
        host: "{{ item }}"
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"
      loop:
        - localhost
        - "{{ ansible_host }}"
        
    # ===== DEPLOY APP =====
    - name: Clone/update application
      git:
        repo: "https://github.com/company/myapp.git"
        dest: /var/www/myapp
        version: main
        force: yes
        
    - name: Set correct permissions
      file:
        path: /var/www/myapp
        owner: www-data
        group: www-data
        recurse: yes
        
    - name: Install Composer dependencies
      composer:
        command: install
        working_dir: /var/www/myapp
        no_dev: yes
        optimize_autoloader: yes
      become_user: www-data
      
    - name: Copy .env file
      template:
        src: ../templates/.env.j2
        dest: /var/www/myapp/.env
        owner: www-data
        mode: '0600'
        
    - name: Run migrations
      command: php artisan migrate --force
      args:
        chdir: /var/www/myapp
      become_user: www-data
      
    - name: Configure Apache VHost
      template:
        src: ../templates/apache-vhost.conf.j2
        dest: /etc/apache2/sites-available/myapp.conf
      notify: restart apache
      
    - name: Enable site
      command: a2ensite myapp.conf
      notify: restart apache
      
  handlers:
    - name: restart apache
      service:
        name: apache2
        state: restarted
        
    - name: restart php-fpm
      service:
        name: "php{{ php_version }}-fpm"
        state: restarted
```

### 3.2 Scenario: Kubernetes Node Setup

```yaml
# playbooks/k8s-nodes.yml
---
- name: Setup Kubernetes Nodes
  hosts: k8s_nodes
  become: yes
  vars:
    k8s_version: "1.29"
    pod_network_cidr: "10.244.0.0/16"
    
  tasks:
    # ===== PREREQUISITES =====
    - name: Disable swap
      command: swapoff -a
      changed_when: false
      
    - name: Remove swap from fstab
      lineinfile:
        path: /etc/fstab
        regexp: '.*swap.*'
        state: absent
        
    - name: Load kernel modules
      modprobe:
        name: "{{ item }}"
        state: present
      loop:
        - overlay
        - br_netfilter
        
    - name: Make modules persistent
      copy:
        content: |
          overlay
          br_netfilter
        dest: /etc/modules-load.d/k8s.conf
        
    - name: Configure kernel parameters
      sysctl:
        name: "{{ item.key }}"
        value: "{{ item.value }}"
        state: present
        reload: yes
      loop:
        - { key: 'net.bridge.bridge-nf-call-iptables', value: '1' }
        - { key: 'net.bridge.bridge-nf-call-ip6tables', value: '1' }
        - { key: 'net.ipv4.ip_forward', value: '1' }
        
    # ===== CONTAINERD =====
    - name: Add Docker repository
      block:
        - name: Install prerequisites
          apt:
            name:
              - ca-certificates
              - curl
              - gnupg
            state: present
            
        - name: Add Docker GPG key
          apt_key:
            url: https://download.docker.com/linux/ubuntu/gpg
            state: present
            
        - name: Add Docker repository
          apt_repository:
            repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
            state: present
            
    - name: Install containerd
      apt:
        name: containerd.io
        state: present
        update_cache: yes
        
    - name: Configure containerd
      shell: |
        containerd config default | \
        sed 's/SystemdCgroup = false/SystemdCgroup = true/' > \
        /etc/containerd/config.toml
      changed_when: false
      notify: restart containerd
      
    # ===== KUBERNETES =====
    - name: Add Kubernetes GPG key
      apt_key:
        url: "https://pkgs.k8s.io/core:/stable:/v{{ k8s_version }}/deb/Release.key"
        state: present
        
    - name: Add Kubernetes repository
      apt_repository:
        repo: "deb https://pkgs.k8s.io/core:/stable:/v{{ k8s_version }}/deb/ /"
        state: present
        filename: kubernetes
        
    - name: Install Kubernetes components
      apt:
        name:
          - "kubelet={{ k8s_version }}.*"
          - "kubeadm={{ k8s_version }}.*"
          - "kubectl={{ k8s_version }}.*"
        state: present
        update_cache: yes
        
    - name: Hold Kubernetes versions
      dpkg_selections:
        name: "{{ item }}"
        selection: hold
      loop:
        - kubelet
        - kubeadm
        - kubectl
        
    - name: Enable kubelet
      service:
        name: kubelet
        enabled: yes
        
  handlers:
    - name: restart containerd
      service:
        name: containerd
        state: restarted

# Init master
- name: Initialize Kubernetes Master
  hosts: k8s_masters
  become: yes
  vars:
    pod_network_cidr: "10.244.0.0/16"
  tasks:
    - name: Check if already initialized
      stat:
        path: /etc/kubernetes/admin.conf
      register: k8s_conf
      
    - name: Initialize cluster
      command: >
        kubeadm init
          --pod-network-cidr={{ pod_network_cidr }}
          --apiserver-advertise-address={{ ansible_host }}
      when: not k8s_conf.stat.exists
      register: kubeadm_output
      
    - name: Setup kubectl for ubuntu user
      shell: |
        mkdir -p /home/ubuntu/.kube
        cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
        chown ubuntu:ubuntu /home/ubuntu/.kube/config
        
    - name: Install Flannel CNI
      command: kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
      become_user: ubuntu
      when: not k8s_conf.stat.exists
      
    - name: Get join command
      command: kubeadm token create --print-join-command
      register: join_command
      
    - name: Store join command
      set_fact:
        k8s_join_command: "{{ join_command.stdout }}"
        
# Join workers
- name: Join Worker Nodes
  hosts: k8s_workers
  become: yes
  tasks:
    - name: Check if already joined
      stat:
        path: /etc/kubernetes/kubelet.conf
      register: kubelet_conf
      
    - name: Join the cluster
      command: "{{ hostvars[groups['k8s_masters'][0]]['k8s_join_command'] }}"
      when: not kubelet_conf.stat.exists
```

---

## 4. AWX / Ansible Tower - Enterprise GUI

```bash
# AWX = Open source upstream của Ansible Tower
# Cung cấp: Web UI, RBAC, Job scheduling, API, Notifications

# ===== CÀI ĐẶT AWX VỚI KUBERNETES =====
kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/main/deploy/awx-operator.yaml

cat > awx.yml << 'EOF'
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
spec:
  service_type: nodeport
  nodeport_port: 30080
  admin_user: admin
  admin_email: admin@company.com
  postgres_configuration_secret: awx-postgres-configuration
  projects_persistence: true
  projects_storage_size: 10Gi
EOF

kubectl apply -f awx.yml

# ===== AWX CONCEPTS =====
# Organization:  Logical grouping của resources
# Team:          Group of users trong Organization
# Credentials:   SSH keys, passwords, vault passwords
# Project:       Git repo với playbooks
# Inventory:     Hosts (static hoặc dynamic)
# Job Template:  Playbook + Inventory + Credentials
# Schedule:      Tự động chạy Job Template
# Notification:  Slack, email khi job complete/fail
```

---

> **Tiếp theo: Phần 5** - Ansible Performance, Best Practices & Cheat Sheet
