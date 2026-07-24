# ---
markmap:
  title: "Terraform — Best Practices & Security"
  collapse: false
# ---

# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 4: BEST PRACTICES, SECURITY & PATTERNS

## Theory
- Best practices include modularization, version pinning, secure secrets handling, and least-privilege RBAC for automation accounts.

## Practice
- Enforce naming/tagging standards, use sensitive variables or Key Vault for secrets, pin providers, and implement custom RBAC roles for CI/CD service principals.

## 1. Terraform Best Practices

### 1.1 Code Organization

```
# ===== CẤU TRÚC FILE CHUẨN TRONG MỖI MODULE/ROOT =====
.
├── main.tf           ← Resources chính
├── variables.tf      ← Input variables
├── outputs.tf        ← Output values
├── locals.tf         ← Local values (tách riêng nếu phức tạp)
├── data.tf           ← Data sources
├── versions.tf       ← Required providers và versions
├── backend.tf        ← Backend configuration
└── README.md         ← Documentation

# Đừng đặt tất cả vào 1 file main.tf khổng lồ
# Tách theo logical groups:
├── networking.tf     ← VNet, Subnets, NSG
├── compute.tf        ← VMs, Scale Sets
├── database.tf       ← PostgreSQL, Redis
├── rbac.tf           ← Azure AD, Role Assignments
└── monitoring.tf     ← Log Analytics, Azure Monitor
```

### 1.2 Naming Conventions

```hcl
# ===== RESOURCE NAMING =====
# Format: {project}-{environment}-{resource}-{qualifier}

resource "azurerm_storage_account" "app_assets" {    # snake_case
  name                = "myappprodassetsdata"         # lowercase, no hyphens (Azure limitation)
  resource_group_name = azurerm_resource_group.main.name
}

# Không dùng:
resource "azurerm_Storage_Account" "AppAssets" { }   # PascalCase
resource "azurerm_storage_account" "storage-1" { }   # Hyphens

# ===== VARIABLE NAMING =====
variable "environment" { }           # singular
variable "subnet_ids" { }            # plural cho lists
variable "enable_monitoring" { }     # boolean với enable_/is_/has_
variable "location" { }              # Azure region

# ===== OUTPUT NAMING =====
output "resource_group_name" { }
output "public_subnet_ids" { }
output "aks_cluster_name" { }

# ===== MODULE SOURCE =====
module "networking" {                # lowercase, snake_case
  source = "./modules/networking"
}
```

### 1.3 Version Pinning

```hcl
# versions.tf
terraform {
  required_version = ">= 1.7.0, < 2.0.0"   # Tránh breaking changes

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"    # ~> = pessimistic constraint
      # ~> 3.90 = >= 3.90, < 4.0
      # ~> 3.90.1 = >= 3.90.1, < 3.91.0
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}
```

### 1.4 Tagging Strategy

```hcl
# locals.tf - Common tags cho tất cả resources
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    GitRepo     = "https://github.com/company/infra"
    GitCommit   = var.git_commit_hash
    Owner       = var.team_name
    CostCenter  = var.cost_center
    Location    = var.location
  }
}

# Azure provider default_tags không có như AWS
# Dùng resource group tags + individual resource tags

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  # ... config ...
  tags = merge(local.common_tags, {
    Component = "networking"
  })
}

# Azure Policy để enforce tagging (bắt buộc các team phải có tags)
resource "azurerm_resource_group_policy_assignment" "require_tags" {
  name                 = "require-tags"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"

  parameters = jsonencode({
    tagName = { value = "Environment" }
  })
}
```


## 2. Security Best Practices

### 2.1 Sensitive Data

```hcl
# ===== ĐỪNG BAO GIỜ HARDCODE SECRETS =====
# Sai:
resource "azurerm_postgresql_flexible_server" "main" {
  administrator_password = "SuperSecret123!"    # ← Commit lên git!
}

# Đúng - Dùng biến sensitive:
variable "db_password" {
  type      = string
  sensitive = true   # Không hiện trong logs/plan output
}

resource "azurerm_postgresql_flexible_server" "main" {
  administrator_password = var.db_password
}

# ===== SECRETS SOURCES =====

# 1. Environment variables
# TF_VAR_db_password="SecretPass" terraform apply

# 2. Azure Key Vault (BEST PRACTICE)
data "azurerm_key_vault" "secrets" {
  name                = "kv-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "postgres-admin-password"
  key_vault_id = data.azurerm_key_vault.secrets.id
}

resource "azurerm_postgresql_flexible_server" "main" {
  administrator_password = data.azurerm_key_vault_secret.db_password.value
}

# 3. Azure DevOps Variable Groups (CI/CD secrets)
# → Cấu hình trong Azure DevOps, inject vào pipeline

# ===== ENCRYPT STATE =====
# Azure Storage mã hóa tự động với Microsoft-managed keys
# Dùng Customer-managed keys (CMK) cho compliance yêu cầu:
resource "azurerm_storage_account" "tfstate" {
  name                     = "mycompanytfstate"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # CMK encryption
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.tfstate.id
    user_assigned_identity_id = azurerm_user_assigned_identity.tfstate.id
  }
}

# ===== STATE KHÔNG NÊN CHỨA SECRETS =====
output "db_password" {
  value     = var.db_password
  sensitive = true    # Không hiện khi terraform output
}
# → Vẫn lưu trong state file! Encrypt state là bắt buộc
```

### 2.2 Azure RBAC Best Practices

```hcl
# ===== PRINCIPLE OF LEAST PRIVILEGE =====

# Service Principal cho Terraform CI/CD
# Chỉ cấp quyền cần thiết, không phải Contributor toàn bộ subscription

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# Custom role cho Terraform (chỉ cấp quyền cần thiết)
resource "azurerm_role_definition" "terraform_deployer" {
  name        = "Terraform Deployer - MyApp"
  scope       = data.azurerm_subscription.current.id
  description = "Custom role for Terraform CI/CD pipelines"

  permissions {
    actions = [
      # Resource Group
      "Microsoft.Resources/resourceGroups/*",
      "Microsoft.Resources/deployments/*",

      # Networking
      "Microsoft.Network/*",

      # Compute
      "Microsoft.Compute/*",

      # AKS
      "Microsoft.ContainerService/*",

      # ACR
      "Microsoft.ContainerRegistry/*",

      # Storage (cho state)
      "Microsoft.Storage/*",

      # Key Vault
      "Microsoft.KeyVault/*",

      # Monitor
      "Microsoft.OperationalInsights/*",
      "Microsoft.Insights/*",

      # Authorization (cho role assignments)
      "Microsoft.Authorization/roleAssignments/*",
    ]
    not_actions = [
      # Không cho xóa subscription
      "Microsoft.Resources/subscriptions/delete",
    ]
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

resource "azurerm_role_assignment" "terraform_ci" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.terraform_deployer.role_definition_resource_id
  principal_id       = var.terraform_sp_object_id
}

# Workload Identity cho Azure DevOps (không cần secrets!)
resource "azurerm_federated_identity_credential" "azure_devops" {
  name                = "azure-devops-federation"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.terraform.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://vstoken.dev.azure.com/<ORG_ID>"
  subject             = "sc://<ORG_NAME>/<PROJECT_NAME>/<SERVICE_CONNECTION_NAME>"
}
```

### 2.3 Security Scanning

```bash
# ===== CHECKOV - Security scanner for Terraform =====
pip install checkov

checkov -d .                    # Scan thư mục hiện tại
checkov -f main.tf              # Scan file cụ thể
checkov -d . --framework terraform

# Output:
# Check: CKV_AZURE_35: "Ensure Azure Storage Account has Secure transfer required"
# PASSED for resource: azurerm_storage_account.tfstate
# FAILED for resource: azurerm_storage_account.temp

checkov -d . --quiet            # Chỉ show failures
checkov -d . --skip-check CKV_AZURE_35  # Skip specific check

# ===== TFSEC - Security scanner =====
brew install tfsec
tfsec .
tfsec . --minimum-severity MEDIUM

# ===== TERRASCAN =====
brew install terrascan
terrascan scan -t azure -i terraform

# ===== INFRACOST - Cost estimation =====
brew install infracost
infracost configure set api_key YOUR_KEY
infracost breakdown --path . --terraform-var-file=terraform.tfvars
# → Estimate monthly cost của Azure resources
```


## 3. Advanced Patterns

### 3.1 Conditional Resources

```hcl
variable "enable_bastion" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

# Azure Bastion (conditional)
resource "azurerm_bastion_host" "main" {
  count = var.enable_bastion ? 1 : 0

  name                = "bastion-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                 = "config"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

output "bastion_dns" {
  value = var.enable_bastion ? azurerm_bastion_host.main[0].dns_name : null
}

# Environment-based resources
resource "azurerm_monitor_diagnostic_setting" "app" {
  name               = "diag-${var.environment}"
  target_resource_id = azurerm_kubernetes_cluster.main.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
    enabled  = true
    retention_policy {
      enabled = true
      days    = var.environment == "production" ? 90 : 7
    }
  }
}
```

### 3.2 Data Source Patterns

```hcl
# ===== LẤY THÔNG TIN TỪ EXISTING AZURE INFRASTRUCTURE =====

# Lấy thông tin subscription hiện tại
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Lấy Azure AD Group
data "azuread_group" "devops" {
  display_name     = "DevOps-Engineers"
  security_enabled = true
}

# Tìm existing Key Vault
data "azurerm_key_vault" "shared" {
  name                = "kv-company-shared"
  resource_group_name = "rg-shared-services"
}

# Lấy secret từ Key Vault
data "azurerm_key_vault_secret" "db_password" {
  name         = "postgres-admin-password"
  key_vault_id = data.azurerm_key_vault.shared.id
}

# Tìm existing VNet (cross-team)
data "azurerm_virtual_network" "shared" {
  name                = "vnet-company-hub"
  resource_group_name = "rg-networking-hub"
}

# Remote state data source (cross-team)
data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "mycompanytfstate"
    container_name       = "tfstate"
    key                  = "networking/terraform.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_kubernetes_cluster" "main" {
  # Dùng VNet từ networking team
  default_node_pool {
    vnet_subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]
  }
}
```

### 3.3 Multi-Region và Multi-Subscription Azure

```hcl
# providers.tf - Azure Multi-region, Multi-subscription
provider "azurerm" {
  alias           = "primary"
  subscription_id = var.primary_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "dr"        # Disaster Recovery region
  subscription_id = var.primary_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "shared"    # Shared services subscription
  subscription_id = var.shared_subscription_id
  features {}
}

# Storage Account với geo-replication (primary region)
resource "azurerm_storage_account" "primary" {
  provider             = azurerm.primary
  name                 = "myappdataprimary"
  resource_group_name  = azurerm_resource_group.primary.name
  location             = "Southeast Asia"
  account_tier         = "Standard"
  account_replication_type = "GRS"  # Geo-Redundant Storage
}

# ACR với geo-replication
resource "azurerm_container_registry" "main" {
  provider            = azurerm.primary
  name                = "myappregistry"
  resource_group_name = azurerm_resource_group.primary.name
  location            = "Southeast Asia"
  sku                 = "Premium"

  georeplications {
    location                  = "East Asia"     # DR region
    zone_redundancy_enabled   = true
    regional_endpoint_enabled = true
  }
}

# Module với provider alias
module "aks_dr" {
  source = "./modules/aks"

  providers = {
    azurerm = azurerm.dr   # Pass DR provider vào module
  }

  environment  = "dr"
  location     = "East Asia"
  project_name = var.project_name
}
```


## 4. Cheat Sheet

```bash
# INIT & SETUP
terraform init                    # Initialize
terraform init -upgrade           # Upgrade providers
terraform init -backend-config=backend.hcl  # External backend config

# PLAN & APPLY
terraform plan                    # Preview
terraform plan -out=tfplan        # Save plan
terraform plan -destroy           # Plan to destroy
terraform apply                   # Apply (with confirm)
terraform apply -auto-approve     # No confirm
terraform apply tfplan            # Apply saved plan
terraform apply -target=resource  # Target specific resource
terraform apply -replace=resource # Force recreate

# DESTROY
terraform destroy                 # Destroy all
terraform destroy -target=module.postgresql  # Destroy specific

# STATE MANAGEMENT
terraform state list
terraform state show address
terraform state mv old new
terraform state rm address
terraform state pull > backup.tfstate
terraform import address id

# DEBUGGING
TF_LOG=DEBUG terraform plan
terraform console                 # REPL
terraform graph | dot -Tsvg > graph.svg

# FORMATTING & VALIDATION
terraform fmt -recursive
terraform validate
terraform fmt -check              # CI check (exit 1 if unformatted)

# WORKSPACES
terraform workspace list
terraform workspace new staging
terraform workspace select prod
terraform workspace show

# OUTPUTS
terraform output
terraform output -json
terraform output resource_group_name
```
