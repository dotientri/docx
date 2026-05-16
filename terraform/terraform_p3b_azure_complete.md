# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 3B: AZURE INFRASTRUCTURE HOÀN CHỈNH

---

## 1. Dự Án Hoàn Chỉnh: 3-Tier Web App trên Azure

### 1.1 Architecture

```
Internet
    │
    ▼
Azure Front Door / Application Gateway (WAF)
    │
    ▼
Azure Kubernetes Service (AKS) - Private Subnet
    │
    ▼
Azure Database for PostgreSQL Flexible Server - DB Subnet
    │
Azure Cache for Redis - Cache Subnet
    │
Azure Blob Storage (static files, backups)
```

### 1.2 Cấu Trúc Project

```
myapp-azure-terraform/
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── modules/
    ├── networking/       # VNet, Subnets, NSG
    ├── aks/              # Azure Kubernetes Service
    ├── acr/              # Azure Container Registry
    ├── postgresql/       # PostgreSQL Flexible Server
    ├── redis/            # Azure Cache for Redis
    ├── keyvault/         # Azure Key Vault
    └── monitoring/       # Log Analytics, Azure Monitor
```

---

## 2. Backend Configuration (Azure Storage)

```hcl
# environments/production/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-myapp-tfstate"
    storage_account_name = "myappprodtfstate"
    container_name       = "tfstate"
    key                  = "production/myapp.tfstate"

    # Dùng Azure AD auth (không cần storage key)
    use_azuread_auth = true
  }
}
```

```bash
# Tạo storage backend trước khi init
RESOURCE_GROUP="rg-myapp-tfstate"
STORAGE_ACCOUNT="myappprodtfstate"
CONTAINER="tfstate"
LOCATION="southeastasia"

az group create --name $RESOURCE_GROUP --location $LOCATION
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

# Bật versioning (backup state)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true
```

---

## 3. Root Module - Gọi Tất Cả Azure Modules

```hcl
# environments/production/main.tf
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
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

# ===== DATA SOURCES =====
data "azurerm_client_config" "current" {}

data "azuread_group" "devops" {
  display_name     = "DevOps-Engineers"
  security_enabled = true
}

# ===== LOCALS =====
locals {
  common_tags = {
    Environment = "production"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Team        = "DevOps"
    CostCenter  = var.cost_center
  }
}

# ===== MODULES =====

module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = "production"
  location             = var.location
  tags                 = local.common_tags
  vnet_cidr            = "10.0.0.0/16"
  aks_subnet_cidr      = "10.0.1.0/24"
  app_subnet_cidr      = "10.0.2.0/24"
  db_subnet_cidr       = "10.0.3.0/24"
  gateway_subnet_cidr  = "10.0.255.0/27"
}

module "keyvault" {
  source = "../../modules/keyvault"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Cấp quyền cho DevOps team
  access_policies = [
    {
      object_id          = data.azuread_group.devops.object_id
      secret_permissions = ["Get", "List", "Set", "Delete"]
      key_permissions    = ["Get", "List", "Create", "Delete"]
      certificate_permissions = ["Get", "List"]
    }
  ]
}

module "acr" {
  source = "../../modules/acr"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags
  sku                 = "Premium"

  # Geo-replication cho DR
  geo_replication_locations = ["East Asia"]
}

module "aks" {
  source = "../../modules/aks"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags

  cluster_name        = "aks-${var.project_name}-production"
  kubernetes_version  = "1.28"
  subnet_id           = module.networking.aks_subnet_id
  acr_id              = module.acr.acr_id

  node_count          = 3
  node_vm_size        = "Standard_D4s_v3"
  min_node_count      = 2
  max_node_count      = 20
}

module "postgresql" {
  source = "../../modules/postgresql"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags
  vnet_id             = module.networking.vnet_id
  subnet_id           = module.networking.db_subnet_id

  db_name             = var.db_name
  admin_username      = var.db_admin_username
  admin_password      = var.db_admin_password  # Từ Key Vault hoặc tfvars (gitignored)
  sku_name            = "GP_Standard_D4s_v3"   # General Purpose
  storage_mb          = 131072                   # 128 GB
  backup_days         = 35

  depends_on = [module.networking]
}

module "redis" {
  source = "../../modules/redis"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags

  capacity            = 2
  family              = "C"
  sku_name            = "Standard"   # Standard = 2 nodes với HA
  enable_non_ssl_port = false
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_name        = var.project_name
  environment         = "production"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = local.common_tags
  aks_cluster_id      = module.aks.cluster_id
  retention_days      = 90
}

# ===== OUTPUTS =====
output "aks_cluster_name"    { value = module.aks.cluster_name }
output "acr_login_server"    { value = module.acr.acr_login_server }
output "postgresql_fqdn"     { value = module.postgresql.server_fqdn; sensitive = true }
output "key_vault_uri"       { value = module.keyvault.vault_uri }
output "log_analytics_id"    { value = module.monitoring.log_analytics_workspace_id }
```

---

## 4. Module Redis

```hcl
# modules/redis/main.tf

variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "resource_group_name" { type = string }
variable "tags"                { type = map(string) }
variable "capacity"            { type = number; default = 1 }
variable "family"              { type = string; default = "C" }
variable "sku_name"            { type = string; default = "Standard" }
variable "enable_non_ssl_port" { type = bool; default = false }

resource "azurerm_redis_cache" "main" {
  name                = "redis-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  enable_non_ssl_port = var.enable_non_ssl_port
  minimum_tls_version = "1.2"

  redis_configuration {
    enable_authentication = true
    maxmemory_reserved    = 50
    maxmemory_delta       = 50
    maxmemory_policy      = "allkeys-lru"
  }

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }

  tags = var.tags
}

output "redis_hostname"         { value = azurerm_redis_cache.main.hostname }
output "redis_ssl_port"         { value = azurerm_redis_cache.main.ssl_port }
output "redis_primary_key"      { value = azurerm_redis_cache.main.primary_access_key; sensitive = true }
output "redis_connection_string"{ value = azurerm_redis_cache.main.primary_connection_string; sensitive = true }
```

---

## 5. Terraform với Azure DevOps CI/CD

```yaml
# azure-pipelines-terraform.yml
trigger:
  branches:
    include: [main, develop]
  paths:
    include: [terraform/**]

variables:
  - group: terraform-azure-credentials
  - name: TF_IN_AUTOMATION
    value: "true"
  - name: TERRAFORM_VERSION
    value: "1.7.0"

stages:
  - stage: Validate
    jobs:
      - job: ValidateTerraform
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TERRAFORM_VERSION)

          - script: |
              terraform fmt -check -recursive terraform/
            displayName: "Terraform Format Check"

          - script: |
              cd terraform/environments/production
              terraform init -backend=false
              terraform validate
            displayName: "Terraform Validate"
            env:
              ARM_CLIENT_ID:       $(ARM_CLIENT_ID)
              ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET)
              ARM_TENANT_ID:       $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)

  - stage: PlanStaging
    dependsOn: Validate
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
    jobs:
      - job: TerraformPlanStaging
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TERRAFORM_VERSION)

          - script: |
              cd terraform/environments/staging
              terraform init
              terraform plan -var-file=terraform.tfvars -out=tfplan -no-color 2>&1 | tee plan_output.txt
            displayName: "Terraform Plan Staging"
            env:
              ARM_CLIENT_ID:       $(ARM_CLIENT_ID_STAGING)
              ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET_STAGING)
              ARM_TENANT_ID:       $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID_STAGING)

          - publish: terraform/environments/staging
            artifact: staging-tfplan

  - stage: ApplyStaging
    dependsOn: PlanStaging
    jobs:
      - deployment: ApplyTerraformStaging
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: staging-tfplan

                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: $(TERRAFORM_VERSION)

                - script: |
                    cd $(Pipeline.Workspace)/staging-tfplan
                    terraform init
                    terraform apply -auto-approve tfplan
                  env:
                    ARM_CLIENT_ID:       $(ARM_CLIENT_ID_STAGING)
                    ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET_STAGING)
                    ARM_TENANT_ID:       $(ARM_TENANT_ID)
                    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID_STAGING)

  - stage: PlanProduction
    dependsOn: ApplyStaging
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: TerraformPlanProduction
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TERRAFORM_VERSION)
          - script: |
              cd terraform/environments/production
              terraform init
              terraform plan -var-file=terraform.tfvars -out=tfplan
            env:
              ARM_CLIENT_ID:       $(ARM_CLIENT_ID_PROD)
              ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET_PROD)
              ARM_TENANT_ID:       $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID_PROD)
          - publish: terraform/environments/production
            artifact: production-tfplan

  - stage: ApplyProduction
    dependsOn: PlanProduction
    jobs:
      - deployment: ApplyTerraformProduction
        environment: production    # Cần approval trong Azure DevOps
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: production-tfplan
                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: $(TERRAFORM_VERSION)
                - script: |
                    cd $(Pipeline.Workspace)/production-tfplan
                    terraform init
                    terraform apply -auto-approve tfplan
                  env:
                    ARM_CLIENT_ID:       $(ARM_CLIENT_ID_PROD)
                    ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET_PROD)
                    ARM_TENANT_ID:       $(ARM_TENANT_ID)
                    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID_PROD)
```

---

> **Xem thêm:** `terraform/terragrunt/` cho DRY IaC, `azure/` cho Azure services chi tiết
