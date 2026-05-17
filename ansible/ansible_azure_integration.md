# 🛠️ ANSIBLE DÀNH CHO AZURE - PHẦN 1: CÀI ĐẶT, AZURE AZCOLLECTION, PLAYBOOKS

---

## 1. Tại sao dùng Ansible với Azure?

| Lợi ích | Mô tả |
|---------|------|
| **Agentless** | Không cần cài đặt daemon trên VM – chỉ cần SSH/WinRM. |
| **Azure.azcollection** | Hơn 150 modules (VM, AKS, ACR, Key Vault, Resource Groups…). |
| **Dynamic Inventory** | Tự động phát hiện resources trong subscription.
| **Idempotent** | Playbook có thể chạy lại mà không tạo duplicate. |
| **IaC + Configuration Management** | Tạo infra (VM, networking) + cấu hình (install packages, deploy apps). |

---

## 2. Cài đặt Ansible + Azure Collection

```bash
# 1. Cài Ansible (Python 3.11+) – dùng pip trong virtualenv
python3 -m venv ~/venv/ansible-azure
source ~/venv/ansible-azure/bin/activate
pip install --upgrade pip
pip install ansible==9.5.0   # LTS version

# 2. Cài Azure collection
ansible-galaxy collection install azure.azcollection

# 3. Cài Azure SDK (bắt buộc cho dynamic inventory)
pip install "azure-mgmt-resource>=23.0.0" "azure-identity>=1.13.0"
```

### 2.1 Kiểm tra installation
```bash
ansible --version
ansible-galaxy collection list | grep azure.azcollection
```

---

## 3. Authentication – Service Principal (SP)

### 3.1 Tạo SP (một lần duy nhất)
```bash
az ad sp create-for-rbac \
  --name "ansible-sp" \
  --role Contributor \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG> \
  --years 5

# Output:
# {
#   "appId": "<client_id>",
#   "password": "<client_secret>",
#   "tenant": "<tenant_id>",
#   "subscriptionId": "<sub_id>"
# }
```

### 3.2 Lưu credentials trong **Ansible Vault** (đảm bảo an toàn)
```bash
ansible-vault create group_vars/all/vault.yml
# Nội dung mẫu:
# azure_client_id: <client_id>
# azure_secret: <client_secret>
# azure_tenant: <tenant_id>
# azure_subscription_id: <sub_id>
```

> **Tip:** Đặt file `vault.yml` vào `.gitignore` và chỉ chia sẻ password vault với các thành viên.

---

## 4. Dynamic Inventory – Azure Resource Manager (azure_rm)

### 4.1 inventory.yml (định nghĩa nguồn)
```yaml
plugin: azure_rm
include_vm_resource_groups:
  - myapp-rg
auth_source: env   # Sử dụng env vars hoặc Ansible Vault
# Nếu dùng vault, khai báo trong vars:
#   client_id: "{{ azure_client_id }}"
#   secret: "{{ azure_secret }}"
#   tenant: "{{ azure_tenant }}"
#   subscription_id: "{{ azure_subscription_id }}"
```

### 4.2 Chạy inventory test
```bash
ansible-inventory -i inventory.yml --graph
# Kết quả sẽ hiển thị các host theo tag, location, resource group
```

---

## 5. Playbook mẫu – Provision Azure VM + Install Docker

```yaml
---
- name: Provision Ubuntu VM & install Docker
  hosts: localhost
  connection: local
  gather_facts: false
  vars_files:
    - group_vars/all/vault.yml   # Load SP secrets
  vars:
    vm_name: myapp-vm-01
    resource_group: myapp-rg
    location: southeastasia
    admin_user: azureuser
    ssh_public_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
  tasks:
    - name: Create VM (Azure)
      azure_rm_virtualmachine:
        resource_group: "{{ resource_group }}"
        name: "{{ vm_name }}"
        admin_username: "{{ admin_user }}"
        ssh_public_keys:
          - path: /home/{{ admin_user }}/.ssh/authorized_keys
            key_data: "{{ ssh_public_key }}"
        image:
          offer: UbuntuServer
          publisher: Canonical
          sku: 22_04-lts-gen2
          version: latest
        size: Standard_B2s
        location: "{{ location }}"
        state: present
        tags:
          Environment: prod
          Project: myapp

    - name: Wait for SSH to become reachable
      wait_for:
        host: "{{ vm_name }}.{{ location }}.cloudapp.azure.com"
        port: 22
        timeout: 300
        state: started

    - name: Add new VM to inventory (dynamic host)
      add_host:
        name: "{{ vm_name }}"
        groups: azure_vms
        ansible_user: "{{ admin_user }}"
        ansible_ssh_private_key_file: "~/.ssh/id_rsa"

- name: Configure Docker on provisioned VM
  hosts: azure_vms
  become: true
  tasks:
    - name: Install Docker prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present
        update_cache: true

    - name: Add Docker’s official GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Set up Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present
        update_cache: true

    - name: Install Docker Engine
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: true
```

---

## 6. Playbook – Deploy Azure Kubernetes Service (AKS) & Helm Release

```yaml
---
- name: Create AKS Cluster
  hosts: localhost
  connection: local
  gather_facts: false
  vars_files:
    - group_vars/all/vault.yml
  vars:
    aks_name: aks-myapp-prod
    resource_group: myapp-rg
    location: southeastasia
    kubernetes_version: "1.29.2"
    node_vm_size: Standard_D4s_v5
    node_count: 3
    addon_monitoring: true
    log_analytics_workspace: myapp-logs
  tasks:
    - name: Ensure Log Analytics workspace exists (required for monitoring addon)
      azure_rm_loganalyticsworkspace:
        resource_group: "{{ resource_group }}"
        name: "{{ log_analytics_workspace }}"
        location: "{{ location }}"
        sku: PerGB2018
        retention_in_days: 90
        state: present
      register: law

    - name: Create AKS Cluster
      azure_rm_aks:
        name: "{{ aks_name }}"
        resource_group: "{{ resource_group }}"
        dns_prefix: "{{ aks_name }}"
        kubernetes_version: "{{ kubernetes_version }}"
        location: "{{ location }}"
        agent_pool_profiles:
          - name: systempool
            count: "{{ node_count }}"
            vm_size: "{{ node_vm_size }}"
            mode: System
            os_type: Linux
            os_disk_size_gb: 128
            vnet_subnet_id: "{{ lookup('azure_rm_subnet', resource_group=resource_group, name='aks-subnet', virtual_network_name='vnet-myapp-prod').id }}"
        linux_profile:
          admin_username: azureuser
          ssh_key: "{{ lookup('file','~/.ssh/id_rsa.pub') }}"
        network_profile:
          network_plugin: azure
          network_policy: calico
        addon_profiles:
          omsagent:
            enabled: true
            log_analytics_workspace_resource_id: "{{ law.id }}"
        role_based_access_control:
          enabled: true
          azure_active_directory:
            managed: true
        enable_rbac: true
        state: present
      register: aks

    - name: Get AKS credentials (kubeconfig)
      command: >
        az aks get-credentials --resource-group {{ resource_group }} \
        --name {{ aks_name }} --overwrite-existing
      environment:
        AZURE_CLIENT_ID: "{{ azure_client_id }}"
        AZURE_CLIENT_SECRET: "{{ azure_secret }}"
        AZURE_TENANT_ID: "{{ azure_tenant }}"
        AZURE_SUBSCRIPTION_ID: "{{ azure_subscription_id }}"

    - name: Deploy Helm chart (myapp) to AKS
      community.kubernetes.helm:
        name: myapp
        chart_ref: ./helm/myapp
        release_namespace: production
        values:
          image:
            repository: myappregistry.azurecr.io/myapp
            tag: "{{ lookup('env','BUILD_NUMBER') | default('latest') }}"
          replicaCount: 3
        wait: true
        timeout: 600
```

### 6.1 Dependencies
- `community.kubernetes` collection (`ansible-galaxy collection install community.kubernetes`).
- Helm CLI installed on control node (`brew install helm` hoặc apt).

---

## 7. Playbook – Pull secret từ Azure Key Vault & Deploy to K3s

```yaml
---
- name: Retrieve secrets from Azure Key Vault
  hosts: localhost
  connection: local
  gather_facts: false
  vars_files:
    - group_vars/all/vault.yml
  vars:
    key_vault_name: kv-myapp-prod-001
    secret_names:
      - db_password
      - api_key
  tasks:
    - name: Get secret values
      azure_keyvault_secret:
        vault_uri: "https://{{ key_vault_name }}.vault.azure.net/"
        secret_name: "{{ item }}"
      loop: "{{ secret_names }}"
      register: kv_secrets

    - name: Set facts for later use
      set_fact:
        db_password: "{{ kv_secrets.results[0].value }}"
        api_key: "{{ kv_secrets.results[1].value }}"

- name: Deploy application to K3s (lightweight cluster)
  hosts: k3s_master
  become: true
  vars:
    kubeconfig_path: /etc/rancher/k3s/k3s.yaml
  tasks:
    - name: Create namespace
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: production

    - name: Deploy secret from KV values
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Secret
          metadata:
            name: myapp-secret
            namespace: production
          type: Opaque
          data:
            DB_PASSWORD: "{{ db_password | b64encode }}"
            API_KEY: "{{ api_key | b64encode }}"

    - name: Deploy application (helm chart) to K3s
      community.kubernetes.helm:
        name: myapp
        chart_ref: ./helm/myapp
        release_namespace: production
        values:
          image:
            repository: myregistry.local/myapp
            tag: "{{ lookup('env','BUILD_NUMBER') | default('latest') }}"
          envFrom:
            - secretRef:
                name: myapp-secret
        kubeconfig: "{{ kubeconfig_path }}"
        wait: true
        timeout: 300
```

**Lưu ý:** K3s thường chạy trong môi trường on‑prem hoặc edge device. Đảm bảo `k3s_master` được định danh trong inventory (địa chỉ IP hoặc DNS).

---

## 8. Ansible Vault & CI/CD Integration

| CI System | How to use Vault secret |
|----------|------------------------|
| Azure DevOps | Use **Azure Key Vault task** → inject as variables, then run `ansible-playbook` with `--vault-password-file`.
| GitHub Actions | Store vault password as **secret**, run `ansible-vault decrypt` trước khi chạy playbook.
| Jenkins | `withCredentials([string(credentialsId: 'vault-pass', variable: 'VAULT_PASS')]) { sh 'ansible-playbook site.yml --vault-password-file <(echo $VAULT_PASS)' }`

---

## 9. Best Practices cho Ansible + Azure
1. **Use AzureRM modules** (they are idempotent & Azure‑native). Avoid raw `az` CLI calls inside playbooks.
2. **Separate inventory per environment** – e.g., `inventory-prod.yml`, `inventory-dev.yml`.
3. **Store SP credentials in Ansible Vault** – never commit plaintext.
4. **Enable Azure Policy & Defender** – resources created by Ansible will be audited automatically.
5. **Leverage `azure_rm_resourcegroup`** for grouping – delete whole RG with a single task.
6. **Use `check_mode`** (`--check`) for dry‑run before actual changes.
7. **Integrate with Terraform** – Terraform tạo infra (VNet, AKS) → Ansible cấu hình (install apps, deploy Helm).
8. **Tag resources** – giúp cost allocation, monitoring, RBAC.

---

> **Tiếp theo:** Tài liệu K3s vs AKS sẽ được cập nhật trong phần Kubernetes để đưa ra lựa chọn chi tiết và các hướng dẫn triển khai.
