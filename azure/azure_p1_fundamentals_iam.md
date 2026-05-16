# ☁️ AZURE TOÀN TẬP - PHẦN 1: NỀN TẢNG, IAM & CORE SERVICES

---

## 1. Azure Overview

### 1.1 Azure Là Gì?

Microsoft Azure là nền tảng cloud computing lớn thứ 2 thế giới (sau AWS), cung cấp **200+ services** từ IaaS (VMs, Networking) đến PaaS (App Services, Databases) và SaaS (Office 365, Dynamics).

**Azure mạnh ở:**
- Tích hợp sâu với Microsoft ecosystem (Active Directory, Office 365, Windows)
- Hybrid cloud với Azure Arc, Azure Stack
- .NET và Windows workloads
- Enterprise customers

### 1.2 Azure Global Infrastructure

```
Azure Infrastructure:
├── Geographies (60+): Americas, Europe, Asia Pacific, Middle East, Africa...
│   └── Ví dụ: Asia Pacific, Europe, United States
│
├── Regions (60+): Cluster của datacenters
│   └── Ví dụ: Southeast Asia (Singapore), East Asia (Hong Kong)
│            East US, West US, West Europe, North Europe
│
├── Availability Zones (AZ): 
│   └── ≥ 3 AZs per supported region
│       ≥ 300 miles separation
│       Dedicated power, cooling, networking
│
└── Datacenter: Physical building
```

**Chọn Region quan trọng vì:**
- **Latency:** Gần users → Thấp hơn
- **Data Residency:** Compliance, GDPR
- **Service Availability:** Không phải service nào cũng ở mọi region
- **Pricing:** Giá khác nhau theo region

---

## 2. Azure Identity & Access Management

### 2.1 Azure Active Directory (Azure AD / Entra ID)

```
Azure AD = Dịch vụ Identity và Access Management của Azure

Khác với on-premise Active Directory:
- Cloud-based (không cần domain controllers)
- Hỗ trợ modern auth (OAuth 2.0, OIDC, SAML)
- Multi-factor authentication built-in
- Conditional access policies
```

```bash
# Azure CLI - Cài đặt
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Đăng nhập
az login                              # Browser-based login
az login --use-device-code            # Device code (headless)
az login --service-principal \
  -u CLIENT_ID \
  -p CLIENT_SECRET \
  --tenant TENANT_ID

# Kiểm tra
az account show
az account list
az account set --subscription "Subscription Name"

# Azure AD - Xem users, groups
az ad user list
az ad group list
az ad sp list --all                   # Service Principals
```

### 2.2 Azure RBAC - Role-Based Access Control

```
Azure RBAC = Kiểm soát ai có thể làm gì với resource nào

Concepts:
- Security Principal: User, Group, Service Principal, Managed Identity
- Role Definition: Tập hợp permissions (Actions, NotActions, DataActions)
- Scope: Management Group > Subscription > Resource Group > Resource
- Role Assignment: Gán Role cho Principal tại Scope
```

**Built-in Roles phổ biến:**

| Role | Mô Tả |
|------|-------|
| Owner | Full access + quản lý assignments |
| Contributor | Full access, không thể gán roles |
| Reader | Read-only |
| User Access Administrator | Quản lý access |
| Virtual Machine Contributor | Quản lý VMs |
| Storage Blob Data Contributor | CRUD blobs |
| Key Vault Secrets User | Đọc secrets |
| AcrPull | Pull images từ Container Registry |

```bash
# ===== ROLE ASSIGNMENTS =====

# Xem assignments hiện tại
az role assignment list
az role assignment list --assignee user@company.com

# Gán role
az role assignment create \
  --assignee user@company.com \
  --role "Contributor" \
  --scope "/subscriptions/SUB_ID/resourceGroups/myapp-rg"

# Gán role cho Service Principal
az role assignment create \
  --assignee SERVICE_PRINCIPAL_ID \
  --role "Reader" \
  --scope "/subscriptions/SUB_ID"

# Xóa role assignment
az role assignment delete \
  --assignee user@company.com \
  --role "Contributor" \
  --scope "/subscriptions/SUB_ID/resourceGroups/myapp-rg"

# ===== CUSTOM ROLES =====
cat > custom-role.json << 'EOF'
{
  "Name": "Custom App Deployer",
  "Description": "Can deploy and manage application resources",
  "Actions": [
    "Microsoft.Web/sites/*",
    "Microsoft.ContainerRegistry/registries/pull/read",
    "Microsoft.Kubernetes/connectedClusters/read"
  ],
  "NotActions": [
    "Microsoft.Web/sites/delete"
  ],
  "DataActions": [],
  "AssignableScopes": [
    "/subscriptions/SUB_ID"
  ]
}
EOF

az role definition create --role-definition custom-role.json
```

### 2.3 Service Principals & Managed Identity

```bash
# ===== SERVICE PRINCIPAL (App Registration) =====
# Dùng cho: CI/CD pipelines, automation scripts, external apps

# Tạo Service Principal
az ad sp create-for-rbac \
  --name "myapp-ci-cd" \
  --role Contributor \
  --scopes /subscriptions/SUB_ID/resourceGroups/myapp-rg

# Output:
# {
#   "appId": "xxx",          ← CLIENT_ID
#   "displayName": "myapp-ci-cd",
#   "password": "xxx",       ← CLIENT_SECRET (lưu cẩn thận!)
#   "tenant": "xxx"          ← TENANT_ID
# }

# Xác thực bằng SP
az login --service-principal \
  -u $CLIENT_ID \
  -p $CLIENT_SECRET \
  --tenant $TENANT_ID

# ===== MANAGED IDENTITY (Best Practice cho Azure resources) =====
# Không cần quản lý credentials!
# Azure tự tạo và rotate credentials

# System-assigned Managed Identity (gắn với 1 resource)
az vm identity assign \
  --name myvm \
  --resource-group myapp-rg

# User-assigned Managed Identity (có thể gắn nhiều resources)
az identity create \
  --name myapp-identity \
  --resource-group myapp-rg

# Gán cho VM
az vm identity assign \
  --name myvm \
  --resource-group myapp-rg \
  --identities myapp-identity

# Gán role cho Managed Identity
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name myapp-identity \
  --resource-group myapp-rg \
  --query principalId -o tsv)

az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/SUB_ID/resourceGroups/myapp-rg/providers/Microsoft.KeyVault/vaults/myapp-kv

# Sử dụng trong code (không cần credentials!)
# Python:
# from azure.identity import ManagedIdentityCredential
# credential = ManagedIdentityCredential()
```

---

## 3. Resource Groups - Tổ Chức Resources

```bash
# Resource Group = Container logic cho Azure resources
# Tất cả resources trong cùng lifecycle nên ở cùng RG

# Tạo Resource Group
az group create \
  --name myapp-production-rg \
  --location southeastasia \
  --tags Environment=Production Project=MyApp ManagedBy=Terraform

# Liệt kê
az group list --output table
az group show --name myapp-production-rg

# Xem resources trong RG
az resource list --resource-group myapp-production-rg --output table

# Xóa RG (xóa tất cả resources bên trong!)
az group delete --name myapp-production-rg --yes --no-wait

# ===== NAMING CONVENTION (Microsoft recommended) =====
# {resource-type}-{workload}-{environment}-{region}-{instance}
# rg-myapp-prod-sea-001        ← Resource Group
# vm-myapp-prod-sea-001        ← Virtual Machine
# vnet-myapp-prod-sea-001      ← Virtual Network
# snet-web-prod-sea-001        ← Subnet
# nsg-web-prod-sea-001         ← Network Security Group
# st-myapp-prod-001            ← Storage (no hyphens!)
# kv-myapp-prod-sea-001        ← Key Vault
```

---

## 4. Virtual Machines

### 4.1 Tạo và Quản Lý VMs

```bash
# Tạo VM
az vm create \
  --resource-group myapp-rg \
  --name myapp-vm-1 \
  --image Ubuntu2204 \
  --size Standard_D2s_v5 \       # 2 vCPUs, 8GB RAM
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_ed25519.pub \
  --vnet-name myapp-vnet \
  --subnet app-subnet \
  --nsg myapp-nsg \
  --public-ip-sku Standard \
  --zone 1 \                     # Availability Zone 1
  --tags Environment=Production

# Xem VMs
az vm list --output table
az vm show --name myapp-vm-1 --resource-group myapp-rg

# Start/Stop/Restart
az vm start --name myapp-vm-1 --resource-group myapp-rg
az vm stop --name myapp-vm-1 --resource-group myapp-rg     # Deallocated (không tính phí compute)
az vm restart --name myapp-vm-1 --resource-group myapp-rg

# SSH vào VM
az vm ssh --name myapp-vm-1 --resource-group myapp-rg

# Run command trên VM (không cần SSH)
az vm run-command invoke \
  --resource-group myapp-rg \
  --name myapp-vm-1 \
  --command-id RunShellScript \
  --scripts "apt-get update && apt-get install -y nginx"

# Resize VM
az vm resize \
  --resource-group myapp-rg \
  --name myapp-vm-1 \
  --size Standard_D4s_v5

# Tạo image từ VM (để nhân bản)
az vm deallocate --resource-group myapp-rg --name myapp-vm-1
az vm generalize --resource-group myapp-rg --name myapp-vm-1
az image create \
  --resource-group myapp-rg \
  --name myapp-image-v1 \
  --source myapp-vm-1
```

### 4.2 VM Sizes

```
Azure VM Size Families:

General Purpose:
- Dv5/Dsv5: Balanced CPU/memory (D2s = 2CPU 8GB, D4s = 4CPU 16GB)
- Bv2: Burstable (tiết kiệm chi phí cho variable workloads)

Compute Optimized:
- Fv2: High CPU ratio (4CPU 8GB) - Web servers, batch

Memory Optimized:
- Ev5: High memory ratio (4CPU 32GB) - Databases
- Mv2: Very high memory (208CPU 5.7TB) - SAP HANA

Storage Optimized:
- Lsv3: High disk throughput - Databases, Big Data

GPU:
- NC: NVIDIA Tesla T4 - ML inference
- ND: NVIDIA A100 - ML training
- NV: NVIDIA RTX - Visualization

High Performance Compute:
- HB: AMD EPYC - HPC
```

### 4.3 VM Scale Sets (VMSS)

```bash
# VMSS = Auto-scaling group của VMs

az vmss create \
  --resource-group myapp-rg \
  --name myapp-vmss \
  --image Ubuntu2204 \
  --vm-sku Standard_D2s_v5 \
  --instance-count 3 \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_ed25519.pub \
  --lb myapp-lb \             # Gắn vào Load Balancer
  --upgrade-policy-mode automatic \
  --custom-data cloud-init.yaml

# Autoscale policy
az monitor autoscale create \
  --resource-group myapp-rg \
  --resource myapp-vmss \
  --resource-type Microsoft.Compute/virtualMachineScaleSets \
  --name myapp-autoscale \
  --min-count 2 \
  --max-count 20 \
  --count 3

# Scale rule: Tăng khi CPU > 70%
az monitor autoscale rule create \
  --resource-group myapp-rg \
  --autoscale-name myapp-autoscale \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 2              # Thêm 2 instances

# Scale rule: Giảm khi CPU < 30%
az monitor autoscale rule create \
  --resource-group myapp-rg \
  --autoscale-name myapp-autoscale \
  --condition "Percentage CPU < 30 avg 10m" \
  --scale in 1               # Bỏ 1 instance
```

---

## 5. Azure Networking

### 5.1 Virtual Network (VNet)

```bash
# Tạo VNet
az network vnet create \
  --resource-group myapp-rg \
  --name myapp-vnet \
  --address-prefix 10.0.0.0/16 \
  --location southeastasia

# Tạo Subnets
az network vnet subnet create \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --name web-subnet \
  --address-prefix 10.0.1.0/24

az network vnet subnet create \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --name app-subnet \
  --address-prefix 10.0.2.0/24

az network vnet subnet create \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --name db-subnet \
  --address-prefix 10.0.3.0/24
```

### 5.2 Network Security Groups (NSG)

```bash
# NSG = Firewall cho VNet resources

# Tạo NSG
az network nsg create \
  --resource-group myapp-rg \
  --name web-nsg

# Thêm rules
az network nsg rule create \
  --resource-group myapp-rg \
  --nsg-name web-nsg \
  --name allow-http \
  --priority 100 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-port-ranges 80 443 \
  --access Allow

az network nsg rule create \
  --resource-group myapp-rg \
  --nsg-name web-nsg \
  --name allow-ssh-mgmt \
  --priority 200 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes '10.0.100.0/24' \  # Management network only
  --destination-port-ranges 22 \
  --access Allow

# Gắn NSG vào subnet
az network vnet subnet update \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --name web-subnet \
  --network-security-group web-nsg
```

### 5.3 Azure Load Balancer & Application Gateway

```bash
# ===== AZURE LOAD BALANCER (Layer 4 - TCP/UDP) =====
# Public IP
az network public-ip create \
  --resource-group myapp-rg \
  --name myapp-lb-ip \
  --sku Standard \
  --zone 1 2 3              # Zone redundant

# Load Balancer
az network lb create \
  --resource-group myapp-rg \
  --name myapp-lb \
  --sku Standard \
  --public-ip-address myapp-lb-ip \
  --frontend-ip-name frontend \
  --backend-pool-name backend

# Health probe
az network lb probe create \
  --resource-group myapp-rg \
  --lb-name myapp-lb \
  --name http-probe \
  --protocol Http \
  --port 80 \
  --path /health

# Load balancing rule
az network lb rule create \
  --resource-group myapp-rg \
  --lb-name myapp-lb \
  --name http-rule \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 8080 \
  --frontend-ip-name frontend \
  --backend-pool-name backend \
  --probe-name http-probe

# ===== APPLICATION GATEWAY (Layer 7 - HTTP/HTTPS WAF) =====
az network application-gateway create \
  --resource-group myapp-rg \
  --name myapp-appgw \
  --location southeastasia \
  --vnet-name myapp-vnet \
  --subnet appgw-subnet \
  --public-ip-address myapp-appgw-ip \
  --sku WAF_v2 \             # WAF_v2 = Web Application Firewall
  --capacity 2 \
  --http-settings-port 8080 \
  --http-settings-protocol Http \
  --frontend-port 443 \
  --cert-file cert.pfx \
  --cert-password pass
```

---

## 6. Azure Key Vault

```bash
# Key Vault: Quản lý secrets, certificates, encryption keys

# Tạo Key Vault
az keyvault create \
  --name myapp-kv-prod \
  --resource-group myapp-rg \
  --location southeastasia \
  --sku premium \            # standard hoặc premium (HSM)
  --enable-soft-delete true \
  --soft-delete-retention-days 90 \
  --enable-purge-protection true

# ===== SECRETS =====
# Thêm secret
az keyvault secret set \
  --vault-name myapp-kv-prod \
  --name db-password \
  --value "SuperSecret123!"

# Lấy secret
az keyvault secret show \
  --vault-name myapp-kv-prod \
  --name db-password \
  --query value -o tsv

# List secrets
az keyvault secret list --vault-name myapp-kv-prod

# Delete secret (soft delete)
az keyvault secret delete --vault-name myapp-kv-prod --name db-password

# Recover deleted secret
az keyvault secret recover --vault-name myapp-kv-prod --name db-password

# ===== ACCESS POLICIES =====
# Cho phép managed identity đọc secrets
az keyvault set-policy \
  --name myapp-kv-prod \
  --object-id MANAGED_IDENTITY_PRINCIPAL_ID \
  --secret-permissions get list

# Cho phép developer đọc/viết
az keyvault set-policy \
  --name myapp-kv-prod \
  --upn developer@company.com \
  --secret-permissions get set list delete

# ===== RBAC (Mới hơn Access Policies) =====
az role assignment create \
  --assignee MANAGED_IDENTITY_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/SUB/resourceGroups/RG/providers/Microsoft.KeyVault/vaults/myapp-kv-prod

# ===== CERTIFICATES =====
az keyvault certificate create \
  --vault-name myapp-kv-prod \
  --name app-cert \
  --policy "$(az keyvault certificate get-default-policy)"

# Import certificate
az keyvault certificate import \
  --vault-name myapp-kv-prod \
  --name app-cert \
  --file cert.pfx \
  --password pfx-password

# ===== KEYS =====
az keyvault key create \
  --vault-name myapp-kv-prod \
  --name encryption-key \
  --kty RSA \
  --size 4096

az keyvault key list --vault-name myapp-kv-prod
```

---

> **Tiếp theo: Phần 2** - Azure App Services, Container Services & Databases
