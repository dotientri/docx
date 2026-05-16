# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 2: MODULES & STATE MANAGEMENT

---

## 1. Terraform Modules

### 1.1 Module Là Gì?

Module = **Collection của Terraform files trong 1 thư mục** — cách đóng gói và tái sử dụng code.

**Mọi Terraform project đều là module** — gọi là "root module".

```
Không có modules (flat structure):
main.tf    # 2000 dòng!

Với modules:
main.tf
modules/
├── networking/     ← VNet, Subnets, NSG
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── aks/            ← Azure Kubernetes Service
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── postgresql/     ← Azure DB for PostgreSQL
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### 1.2 Tạo Module - Networking Module

```hcl
# modules/networking/variables.tf
variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/networking/main.tf

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  public_subnets = {
    for i in range(var.public_subnet_count) :
    "snet-public-${i + 1}" => cidrsubnet(var.vnet_cidr, 8, i)
  }

  private_subnets = {
    for i in range(var.private_subnet_count) :
    "snet-private-${i + 1}" => cidrsubnet(var.vnet_cidr, 8, i + 10)
  }
}

# ===== RESOURCE GROUP =====
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = var.tags
}

# ===== VIRTUAL NETWORK =====
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# ===== PUBLIC SUBNETS =====
resource "azurerm_subnet" "public" {
  for_each = local.public_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]

  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

# ===== PRIVATE SUBNETS =====
resource "azurerm_subnet" "private" {
  for_each = local.private_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]

  service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
}

# ===== NSG PUBLIC =====
resource "azurerm_network_security_group" "public" {
  name                = "nsg-public-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "public" {
  for_each = azurerm_subnet.public

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.public.id
}

# ===== NSG PRIVATE =====
resource "azurerm_network_security_group" "private" {
  name                = "nsg-private-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyInternetInBound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "private" {
  for_each = azurerm_subnet.private

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.private.id
}
```

```hcl
# modules/networking/outputs.tf
output "resource_group_name"     { value = azurerm_resource_group.main.name }
output "resource_group_location" { value = azurerm_resource_group.main.location }
output "vnet_id"                 { value = azurerm_virtual_network.main.id }
output "vnet_name"               { value = azurerm_virtual_network.main.name }
output "public_subnet_ids"       { value = [for s in azurerm_subnet.public : s.id] }
output "private_subnet_ids"      { value = [for s in azurerm_subnet.private : s.id] }
output "public_subnet_map"       { value = { for k, s in azurerm_subnet.public : k => s.id } }
output "private_subnet_map"      { value = { for k, s in azurerm_subnet.private : k => s.id } }
```

### 1.3 Gọi Module Từ Root

```hcl
# environments/staging/main.tf

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "myapptfstate"
    container_name       = "tfstate"
    key                  = "staging/main.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ===== GỌI NETWORKING MODULE =====
module "networking" {
  source = "../../modules/networking"

  project_name         = "myapp"
  environment          = "staging"
  location             = "Southeast Asia"
  vnet_cidr            = "10.0.0.0/16"
  public_subnet_count  = 2
  private_subnet_count = 2
  tags = {
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

# ===== GỌI AKS MODULE =====
module "aks" {
  source = "../../modules/aks"

  project_name        = "myapp"
  environment         = "staging"
  resource_group_name = module.networking.resource_group_name
  location            = module.networking.resource_group_location
  subnet_id           = module.networking.private_subnet_ids[0]
  acr_id              = module.acr.acr_id

  node_count    = 2
  node_vm_size  = "Standard_D2s_v3"
  k8s_version   = "1.28"
}

module "acr" {
  source = "../../modules/acr"

  project_name        = "myapp"
  environment         = "staging"
  resource_group_name = module.networking.resource_group_name
  location            = module.networking.resource_group_location
  sku                 = "Standard"
}

# ===== OUTPUTS =====
output "resource_group"  { value = module.networking.resource_group_name }
output "vnet_id"         { value = module.networking.vnet_id }
output "aks_name"        { value = module.aks.cluster_name }
output "acr_server"      { value = module.acr.acr_login_server }
```

### 1.4 Module Sources

```hcl
# Các cách chỉ định source

# 1. Local path
module "networking" {
  source = "./modules/networking"
}

module "networking_relative" {
  source = "../../modules/networking"   # Relative path
}

# 2. Terraform Registry (Public)
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "7.5.0"
}

# 3. Git repository
module "networking" {
  source = "git::https://github.com/company/terraform-modules.git//networking?ref=v1.2.0"
}

# 4. Azure DevOps Git
module "networking" {
  source = "git::https://company@dev.azure.com/company/project/_git/terraform-modules//networking?ref=v1.0.0"
}

# 5. Terraform Registry Private
module "aks" {
  source  = "app.terraform.io/my-org/aks/azurerm"
  version = "~> 2.0"
}
```

---

## 2. State Management

### 2.1 Remote State trên Azure Storage

```bash
# ===== TẠO AZURE STORAGE BACKEND =====

RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="mycompanytfstate"   # Lowercase, 3-24 chars
CONTAINER="tfstate"
LOCATION="southeastasia"

# 1. Tạo Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Tạo Storage Account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# 3. Bật Blob Versioning (backup state nếu bị xóa nhầm)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30

# 4. Tạo Container
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

# 5. Phân quyền cho Service Principal / Managed Identity
SP_OBJECT_ID=$(az ad sp show --id $CLIENT_ID --query id -o tsv)
STORAGE_ID=$(az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --query id -o tsv)

az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STORAGE_ID
```

```hcl
# Backend configuration trong Terraform
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "mycompanytfstate"
    container_name       = "tfstate"
    key                  = "production/main.tfstate"

    # Dùng Azure AD auth (không cần storage key)
    use_azuread_auth = true

    # Hoặc dùng storage account key:
    # access_key = var.storage_account_key
  }
}

# Hoặc backend config trong file riêng (backend.hcl)
# terraform init -backend-config=backend.hcl
```

```hcl
# backend.hcl (gitignored - chứa sensitive values)
resource_group_name  = "rg-terraform-state"
storage_account_name = "mycompanytfstate"
container_name       = "tfstate"
key                  = "production/main.tfstate"
use_azuread_auth     = true
```

### 2.2 State Commands

```bash
# ===== XEM STATE =====
terraform state list
# azurerm_resource_group.main
# azurerm_virtual_network.main
# module.networking.azurerm_subnet.public["snet-public-1"]
# module.aks.azurerm_kubernetes_cluster.main

# Xem chi tiết một resource
terraform state show azurerm_resource_group.main
terraform state show 'module.networking.azurerm_subnet.public["snet-public-1"]'

# ===== SỬA STATE =====
# Rename resource (refactoring)
terraform state mv \
  azurerm_resource_group.old_name \
  azurerm_resource_group.new_name

# Rename module
terraform state mv \
  module.vpc \
  module.networking

# ===== IMPORT EXISTING AZURE RESOURCES =====
# Import Azure Resource Group đã có
terraform import azurerm_resource_group.main \
  /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod

# Import Azure VNet
terraform import azurerm_virtual_network.main \
  /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod/providers/Microsoft.Network/virtualNetworks/vnet-myapp-prod

# Import AKS cluster
terraform import azurerm_kubernetes_cluster.main \
  /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod/providers/Microsoft.ContainerService/managedClusters/aks-myapp-prod

# Terraform 1.5+ Import Block (declarative)
import {
  to = azurerm_resource_group.main
  id = "/subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod"
}

# Tạo config tự động từ import
terraform plan -generate-config-out=generated.tf

# ===== XÓA KHỎI STATE (không xóa actual resource) =====
terraform state rm azurerm_linux_virtual_machine.old_vm

# ===== BACKUP & RESTORE =====
# Backup state
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Restore state
terraform state push backup-20240101.tfstate

# Rollback qua Azure Storage versioning
az storage blob list \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --prefix "production/main.tfstate" \
  --include v
```

### 2.3 State Locking

```bash
# Azure Storage dùng Blob Lease mechanism để lock state
# Khi terraform apply đang chạy → blob bị lease (lock)

# Nếu apply bị kill giữa chừng, lock vẫn còn
# Giải phóng lock:

# Cách 1: Terraform force-unlock
terraform force-unlock <LOCK_ID>

# Cách 2: Az CLI - break lease trực tiếp
az storage blob lease break \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --blob-name "production/main.tfstate"

# Xem lock info
az storage blob show \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --name "production/main.tfstate" \
  --query "properties.lease"
```

### 2.4 Cross-State References

```hcl
# Đọc output từ state của team khác (networking team)
data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "mycompanytfstate"
    container_name       = "tfstate"
    key                  = "production/networking.tfstate"
    use_azuread_auth     = true
  }
}

# Dùng output từ networking team
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-myapp-prod"
  resource_group_name = data.terraform_remote_state.networking.outputs.resource_group_name
  location            = data.terraform_remote_state.networking.outputs.resource_group_location

  default_node_pool {
    vnet_subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]
  }
}
```

---

## 3. Workspaces

```bash
# Workspaces = cách tách state cho nhiều environments
# Nhưng thường dùng thư mục riêng (environments/) tốt hơn

terraform workspace list
# * default
#   staging
#   production

terraform workspace new staging
terraform workspace select production
terraform workspace show    # → production
terraform workspace delete staging

# Trong code:
resource "azurerm_resource_group" "main" {
  name = "rg-myapp-${terraform.workspace}"
  # staging  → rg-myapp-staging
  # production → rg-myapp-production
}

locals {
  vm_count = terraform.workspace == "production" ? 3 : 1
  vm_size  = terraform.workspace == "production" ? "Standard_D4s_v3" : "Standard_B2s"
}
```

---

## 4. Terragrunt - DRY Terraform

```hcl
# Terragrunt = Wrapper cho Terraform, giải quyết code duplication
# Cấu trúc với Terragrunt:
# live/
# ├── terragrunt.hcl              ← Root config (Azure backend)
# ├── staging/
# │   ├── env.hcl
# │   ├── networking/
# │   │   └── terragrunt.hcl
# │   ├── aks/
# │   │   └── terragrunt.hcl
# │   └── postgresql/
# │       └── terragrunt.hcl
# └── production/
#     ├── env.hcl
#     ├── networking/
#     └── ...

# Root terragrunt.hcl
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "mycompanytfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {}
}
EOF
}
```

```bash
# Terragrunt commands
terragrunt plan
terragrunt apply

# Run all modules trong folder
cd live/staging
terragrunt run-all plan
terragrunt run-all apply --terragrunt-non-interactive

# Chỉ affected modules
terragrunt run-all plan --terragrunt-include-dir ./networking
```

---

## 5. Cheat Sheet

```bash
# ===== WORKFLOW =====
terraform init              # Initialize
terraform fmt               # Format code
terraform validate          # Validate syntax
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy all

# ===== STATE =====
terraform state list                                    # List resources
terraform state show azurerm_resource_group.main       # Show resource details
terraform state mv old new                             # Rename resource
terraform state rm resource.name                       # Remove from state
terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/rg-name  # Import

# ===== DEBUGGING =====
TF_LOG=DEBUG terraform plan            # Debug logging
TF_LOG_PATH=debug.log terraform plan   # Log to file

# ===== USEFUL COMMANDS =====
terraform output                       # Show outputs
terraform output -json | jq .         # JSON format
terraform console                      # Interactive REPL
terraform graph | dot -Tsvg > graph.svg  # Dependency graph

# ===== TIPS =====
# Target specific resource
terraform plan -target=module.networking
terraform apply -target=azurerm_kubernetes_cluster.main

# Replace (force recreate)
terraform apply -replace=azurerm_linux_virtual_machine.web[0]

# Skip confirmation
terraform apply -auto-approve

# Show plan in JSON
terraform plan -out=tfplan
terraform show -json tfplan | jq .
```

---

> **Tiếp theo: Phần 3** - Terraform Azure Infrastructure hoàn chỉnh (AKS, ACR, PostgreSQL, Redis)
