# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

---

## 1. Terraform Là Gì?

### 1.1 Infrastructure as Code (IaC)

**IaC** = Quản lý và cung cấp infrastructure thông qua code thay vì quy trình thủ công.

**Trước IaC:**
```
1. Vào Azure Portal (click, click, click)
2. Tạo Resource Group... cấu hình VNet...
3. Tạo Network Security Groups...
4. Tạo Azure VMs...
5. Cấu hình Load Balancer...
→ 2 giờ sau: Done (và không ai biết mình đã làm gì chính xác)

Tuần sau: Dựng môi trường staging → Làm lại từ đầu!
Khi có lỗi: Không biết config khác ở đâu!
```

**Với Terraform:**
```hcl
# main.tf - Mô tả infrastructure bằng code
resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-prod"
  location = "Southeast Asia"
}

resource "azurerm_linux_virtual_machine" "web" {
  count               = 3
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
}
```

```bash
terraform apply  # 30 giây → Infrastructure sẵn sàng
# Muốn replicate cho staging:
terraform workspace new staging && terraform apply
```

### 1.2 Tại Sao Terraform?

| Tính Năng | Terraform | ARM Templates | Bicep | Pulumi |
|-----------|-----------|---------------|-------|--------|
| Language | HCL | JSON | Bicep DSL | Python/TypeScript |
| Multi-cloud | ✅ Tất cả clouds | ❌ Azure only | ❌ Azure only | ✅ |
| State management | Local/Remote | Azure manages | Azure manages | Local/Remote |
| Community | Rất lớn | Lớn | Lớn | Nhỏ hơn |
| Import existing | ✅ | Khó | ✅ | ✅ |

**Terraform nổi bật vì:**
- **Multi-cloud:** 1 tool cho Azure, AWS, GCP, Kubernetes, GitHub, Cloudflare...
- **Declarative:** Mô tả trạng thái cuối, không phải các bước
- **Plan trước:** `terraform plan` xem những gì sẽ thay đổi trước khi apply
- **State:** Track trạng thái thực tế của infrastructure
- **Modules:** Package và tái sử dụng patterns

---

## 2. Kiến Trúc Terraform

### 2.1 Terraform Architecture

```
┌───────────────────────────────────────────────────────┐
│                   Terraform CLI                        │
│                                                        │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐  │
│  │  Config  │  │  State   │  │     Providers      │  │
│  │  Files   │  │  File    │  │ (azurerm, google)  │  │
│  │  (.tf)   │  │(.tfstate)│  │                    │  │
│  └──────────┘  └──────────┘  └────────────────────┘  │
│                                                        │
└───────────────────────────────────────────────────────┘
                          │
              ┌───────────┼────────────┐
              ▼           ▼            ▼
         Azure API    GCP API      K8s API
         (ARM REST)  (GKE, etc)  (kubectl)
```

### 2.2 Core Concepts

**Provider:**
- Plugin kết nối Terraform với infrastructure platform
- `azurerm`, `azuread`, `google`, `kubernetes`, `github`, `cloudflare`...
- Provider quản lý authentication và API calls

**Resource:**
- Đơn vị infrastructure (Azure VM, Azure Blob, DNS record...)
- Được tạo/quản lý bởi provider

**Data Source:**
- Query thông tin đã tồn tại (không tạo mới)
- Ví dụ: Tìm Azure image mới nhất, lấy thông tin VNet sẵn có

**State:**
- File JSON ghi lại trạng thái hiện tại của infrastructure
- Terraform dùng state để biết cần thay đổi gì
- CỰC KỲ QUAN TRỌNG - mất state = không biết gì về infrastructure

**Plan:**
- Terraform đọc config + state → Tính toán difference
- Hiện những gì sẽ được thêm/thay đổi/xóa
- Chưa apply gì cả

**Apply:**
- Thực thi plan
- Gọi Azure Resource Manager API để tạo/sửa/xóa resources

---

## 3. Cài Đặt Terraform

### 3.1 Cài Đặt

```bash
# ===== UBUNTU/DEBIAN =====
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform

# ===== CENTOS/RHEL =====
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install terraform

# ===== macOS =====
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# ===== Kiểm tra =====
terraform version
# Terraform v1.7.0

# ===== TFENV (Version Manager - Khuyến nghị) =====
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="~/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

tfenv install 1.7.0
tfenv use 1.7.0
tfenv list
```

### 3.2 Cấu Hình Azure Provider

```bash
# ===== SETUP AZURE CREDENTIALS =====

# Cách 1: Azure CLI (local development)
az login
az account show
az account set --subscription "My Subscription Name"

# Cách 2: Service Principal (CI/CD - BEST PRACTICE)
# Tạo Service Principal
az ad sp create-for-rbac \
  --name "sp-terraform-myapp" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>

# Output:
# {
#   "appId":       "CLIENT_ID",
#   "password":    "CLIENT_SECRET",
#   "tenant":      "TENANT_ID"
# }

# Export environment variables cho Terraform
export ARM_CLIENT_ID="<CLIENT_ID>"
export ARM_CLIENT_SECRET="<CLIENT_SECRET>"
export ARM_TENANT_ID="<TENANT_ID>"
export ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"

# Cách 3: Managed Identity (trên Azure VM/AKS - không cần secrets!)
# → Terraform tự động lấy credentials từ instance metadata
# export ARM_USE_MSI=true

# Cách 4: Azure DevOps Service Connection
# → Cấu hình trong Azure DevOps pipeline, tự động inject
```

---

## 4. Cú Pháp HCL - HashiCorp Configuration Language

### 4.1 Cơ Bản

```hcl
# main.tf

# ===== PROVIDER CONFIGURATION =====
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"   # ~> = compatible: >= 3.90, < 4.0
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state backend (Azure Storage)
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "myapptfstate"
    container_name       = "tfstate"
    key                  = "production/terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# ===== RESOURCES =====
# Syntax: resource "<provider>_<type>" "<local_name>" { }
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name  # Reference other resource

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "public" {
  count                = 2
  name                 = "snet-public-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.${count.index}.0/24"]
}

# ===== DATA SOURCES =====
# Query existing resources (read-only, không tạo mới)
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# Lấy thông tin Azure AD group sẵn có
data "azuread_group" "devops" {
  display_name     = "DevOps-Engineers"
  security_enabled = true
}

# ===== OUTPUTS =====
output "resource_group_name" {
  description = "Resource Group Name"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Public subnet IDs"
  value       = azurerm_subnet.public[*].id
}
```

### 4.2 Variables

```hcl
# variables.tf
variable "environment" {
  description = "Deployment environment (staging/production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Must be staging or production"
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "Southeast Asia"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_count" {
  description = "Number of VMs"
  type        = number
  default     = 2
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "List of IPs allowed to SSH"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    sku_name   = string
    storage_mb = number
    version    = string
    backup_days = number
  })
  default = {
    sku_name    = "B_Standard_B1ms"
    storage_mb  = 32768
    version     = "15"
    backup_days = 7
  }
}

# Sensitive variable (không hiện trong logs)
variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}
```

```bash
# Cung cấp variable values:

# Cách 1: terraform.tfvars (auto-loaded)
cat terraform.tfvars
environment     = "production"
project_name    = "myapp"
vm_count        = 5
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
db_password     = "SuperSecret123!"

# Cách 2: *.auto.tfvars (auto-loaded)
cat production.auto.tfvars
environment = "production"
location    = "Southeast Asia"

# Cách 3: -var flag
terraform apply -var="environment=staging" -var="vm_count=2"

# Cách 4: -var-file flag
terraform apply -var-file="staging.tfvars"

# Cách 5: Environment variables (TF_VAR_ prefix)
export TF_VAR_environment="production"
export TF_VAR_db_password="SuperSecret123!"
terraform apply
```

### 4.3 Locals

```hcl
# Tính toán giá trị một lần, dùng nhiều nơi
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Location    = var.location
  })

  # Name prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # Tính toán phức tạp
  vm_count = var.environment == "production" ? 3 : 1

  # Conditional logic
  is_production = var.environment == "production"

  # Database name từ project name
  db_name = replace(var.project_name, "-", "_")
}

resource "azurerm_linux_virtual_machine" "web" {
  count               = local.vm_count
  name                = "${local.name_prefix}-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
  })
}
```

---

## 5. Vòng Lặp Và Meta-Arguments

### 5.1 count - Tạo Nhiều Resources

```hcl
# Tạo 3 Azure VMs
resource "azurerm_linux_virtual_machine" "web" {
  count               = 3
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"

  tags = {
    Name = "web-${count.index + 1}"   # web-1, web-2, web-3
  }
}

# Reference: azurerm_linux_virtual_machine.web[0], [1], [2]
# All VMs: azurerm_linux_virtual_machine.web[*]

output "vm_private_ips" {
  value = azurerm_linux_virtual_machine.web[*].private_ip_address
}
```

### 5.2 for_each - Tạo Resources Từ Map/Set

```hcl
# Tốt hơn count khi resource có tên riêng
variable "subnets" {
  default = {
    "snet-public-1"  = "10.0.1.0/24"
    "snet-public-2"  = "10.0.2.0/24"
    "snet-private-1" = "10.0.10.0/24"
    "snet-private-2" = "10.0.11.0/24"
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key      # "snet-public-1"
  address_prefixes     = [each.value]  # ["10.0.1.0/24"]
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
}

# Reference: azurerm_subnet.this["snet-public-1"]

# For_each với set of strings
resource "azurerm_resource_group" "teams" {
  for_each = toset(["backend", "frontend", "devops"])
  name     = "rg-${each.value}"
  location = var.location
}
```

### 5.3 Dynamic Blocks

```hcl
variable "security_rules" {
  default = [
    { name = "allow-http",  priority = 100, port = 80,  access = "Allow" },
    { name = "allow-https", priority = 110, port = 443, access = "Allow" },
    { name = "allow-ssh",   priority = 120, port = 22,  access = "Allow" },
  ]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Dynamic block thay vì viết lặp nhiều security_rule blocks
  dynamic "security_rule" {
    for_each = var.security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value.port)
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
```

---

## 6. Terraform Commands - Vòng Đời

```bash
# ===== KHỞI TẠO =====
terraform init
# → Download providers (azurerm, azuread...)
# → Setup backend (Azure Storage)
# → Download modules
# Phải chạy sau khi tạo mới hoặc thêm providers

terraform init -upgrade    # Upgrade providers

# ===== XEM TRƯỚC =====
terraform plan
# → Xem những gì sẽ thay đổi (+ add, ~ change, - destroy)
# → Không thay đổi gì cả

terraform plan -out=tfplan         # Lưu plan vào file
terraform plan -destroy            # Plan để destroy tất cả

# ===== APPLY =====
terraform apply                    # Sẽ hỏi "yes"
terraform apply -auto-approve      # Không hỏi (dùng trong CI/CD)
terraform apply tfplan             # Apply từ saved plan (no changes)

# ===== XÓA =====
terraform destroy                  # Xóa tất cả resources
terraform destroy -auto-approve
terraform destroy -target=azurerm_linux_virtual_machine.web[0]

# ===== KIỂM TRA =====
terraform validate    # Validate cú pháp và cấu hình
terraform fmt         # Format code chuẩn (auto-format)
terraform fmt -check  # Check format (không sửa, dùng trong CI)
terraform fmt -diff   # Hiện diff
terraform fmt -recursive  # Recursive tất cả files

# ===== STATE =====
terraform show                                    # Xem state hiện tại
terraform state list                              # List resources trong state
terraform state show azurerm_resource_group.main  # Chi tiết 1 resource
terraform state mv old_name new_name             # Rename resource trong state
terraform state rm azurerm_linux_virtual_machine.web[0]  # Remove từ state
terraform state pull                             # Download state
terraform state push                             # Upload state
terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/rg-myapp  # Import

# ===== WORKSPACE =====
terraform workspace list
terraform workspace new staging
terraform workspace select production
terraform workspace show           # Current workspace
terraform workspace delete staging

# ===== OUTPUT =====
terraform output                   # Xem tất cả outputs
terraform output vnet_id           # Xem output cụ thể
terraform output -json             # JSON format
```

---

> **Tiếp theo: Phần 2** - Modules, State Management & Remote Backend (Azure Storage)
