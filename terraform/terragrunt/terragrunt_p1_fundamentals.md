# 🌿 TERRAGRUNT TOÀN TẬP - PHẦN 1: NỀN TẢNG & CẤU TRÚC


## 1. Terragrunt Là Gì?

### 1.1 Vấn Đề Khi Dùng Terraform Thuần

```
VẤN ĐỀ VỚI TERRAFORM THUẦN:

environments/
├── staging/
│   ├── main.tf           ← Copy-paste từ production
│   ├── variables.tf      ← Copy-paste
│   ├── backend.tf        ← Copy-paste (chỉ đổi key)
│   └── providers.tf      ← Copy-paste
└── production/
    ├── main.tf           ← 95% giống staging
    ├── variables.tf      ← 95% giống staging
    ├── backend.tf        ← 95% giống staging
    └── providers.tf      ← 95% giống staging

Khi cần update provider version → sửa ở TẤT CẢ thư mục!
```

#### Terragrunt giải quyết
- **DRY (Don't Repeat Yourself)**: Cấu hình 1 lần, dùng nhiều nơi
- **Remote state management**: Tự động tạo/quản lý backend
- **Dependencies**: Quản lý phụ thuộc giữa các module
- **Multi-environment**: Staging/Production dễ dàng
- **Multi-account/subscription**: Azure multi-subscription

### 1.2 So Sánh Terraform vs Terragrunt

| | Terraform | Terragrunt |
|--|-----------|-----------|
| DRY | Không (copy-paste) | Có (inherit config) |
| Backend config | Lặp lại ở mỗi env | Kế thừa từ root |
| Dependencies | Manual (terraform_remote_state) | Automatic (dependency block) |
| Run all | Manual | `terragrunt run-all` |
| Hooks | Không | before/after hooks |
| Azure Integration | Có | Có (qua Terraform) |


## 2. Cài Đặt

### 2.1 Cài Terragrunt

```bash
# ===== LINUX (Ubuntu/Debian) =====

# Cách 1: Download binary trực tiếp
TERRAGRUNT_VERSION="0.55.0"
wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
terragrunt --version

# Cách 2: Qua ASDF (recommended - quản lý nhiều version)
asdf plugin add terragrunt
asdf install terragrunt 0.55.0
asdf global terragrunt 0.55.0

# Cách 3: Brew (nếu có linuxbrew)
brew install terragrunt

# ===== AZURE CLOUD SHELL =====
# Azure Cloud Shell đã có sẵn Terraform, nhưng không có Terragrunt
# Cài như Linux ở trên

# Kiểm tra cài đặt
terragrunt --version
terraform --version
az --version
```

### 2.2 Cấu Trúc Thư Mục Cơ Bản

```
infrastructure/
├── terragrunt.hcl          ← ROOT config (dùng chung)
│
├── modules/                 ← Terraform modules thuần
│   ├── networking/
│   ├── aks/                 ← Azure Kubernetes Service
│   ├── acr/                 ← Azure Container Registry
│   ├── storage/
│   └── postgresql/
│
└── live/                    ← Môi trường thực tế
    ├── _global/             ← Global resources (DNS, certs...)
    │   └── terragrunt.hcl
    │
    ├── staging/
    │   ├── env.hcl          ← Env-specific variables
    │   ├── networking/
    │   │   └── terragrunt.hcl
    │   ├── aks/
    │   │   └── terragrunt.hcl
    │   └── acr/
    │       └── terragrunt.hcl
    │
    └── production/
        ├── env.hcl
        ├── networking/
        │   └── terragrunt.hcl
        ├── aks/
        │   └── terragrunt.hcl
        └── acr/
            └── terragrunt.hcl
```


## 3. Cú Pháp Terragrunt

### 3.1 Root terragrunt.hcl

```hcl
# infrastructure/terragrunt.hcl
# File này được kế thừa bởi TẤT CẢ terragrunt.hcl con

# ===== LOCALS =====
locals {
  # Parse đường dẫn để lấy environment và component
  # Ví dụ: live/staging/aks → env=staging, component=aks
  path_parts  = split("/", path_relative_to_include())
  environment = local.path_parts[1]   # staging hoặc production
  component   = local.path_parts[2]   # networking, aks, acr...
  
  # Load env-specific config
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Common values
  project_name       = "myapp"
  azure_location     = local.env_vars.locals.azure_location
  subscription_id    = local.env_vars.locals.subscription_id
  
  # Azure Storage Account cho Terraform state
  # Format: <project><env>tfstate (lowercase, max 24 chars)
  tf_state_resource_group  = "rg-${local.project_name}-tfstate"
  tf_state_storage_account = "${local.project_name}${local.environment}tfstate"
  tf_state_container       = "tfstate"
}

# ===== REMOTE STATE (Azure Storage) =====
remote_state {
  backend = "azurerm"
  
  # Tự động tạo Storage Account nếu chưa có
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  
  config = {
    resource_group_name  = local.tf_state_resource_group
    storage_account_name = local.tf_state_storage_account
    container_name       = local.tf_state_container
    
    # Key format: <component>/<environment>.tfstate
    # Ví dụ: aks/staging.tfstate
    key = "${local.component}/${local.environment}.tfstate"
    
    # Subscription cho state storage
    subscription_id = local.subscription_id
  }
}

# ===== GENERATE PROVIDER =====
# Tự động generate providers.tf cho mỗi module
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<EOF
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
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  
  subscription_id = "${local.subscription_id}"
}
EOF
}

# ===== GLOBAL INPUTS =====
# Inputs này được merge vào TẤT CẢ modules con
inputs = {
  project_name = local.project_name
  environment  = local.environment
  location     = local.azure_location
  
  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Team        = "DevOps"
  }
}
```

### 3.2 Environment Config (env.hcl)

```hcl
# infrastructure/live/staging/env.hcl
locals {
  environment      = "staging"
  azure_location   = "Southeast Asia"      # Azure region
  subscription_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  
  # Networking
  vnet_cidr          = "10.1.0.0/16"
  aks_subnet_cidr    = "10.1.1.0/24"
  app_subnet_cidr    = "10.1.2.0/24"
  db_subnet_cidr     = "10.1.3.0/24"
  
  # AKS
  aks_node_count     = 2
  aks_node_vm_size   = "Standard_D2s_v3"
  aks_k8s_version    = "1.28"
  
  # Database
  db_sku             = "B_Gen5_1"          # Basic tier for staging
  db_storage_mb      = 5120
}
```

```hcl
# infrastructure/live/production/env.hcl
locals {
  environment      = "production"
  azure_location   = "Southeast Asia"
  subscription_id  = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"  # Separate subscription!
  
  # Networking
  vnet_cidr          = "10.0.0.0/16"
  aks_subnet_cidr    = "10.0.1.0/24"
  app_subnet_cidr    = "10.0.2.0/24"
  db_subnet_cidr     = "10.0.3.0/24"
  
  # AKS
  aks_node_count     = 3
  aks_node_vm_size   = "Standard_D4s_v3"  # Bigger VMs
  aks_k8s_version    = "1.28"
  
  # Database
  db_sku             = "GP_Gen5_4"         # General Purpose for production
  db_storage_mb      = 51200
}
```

### 3.3 Module terragrunt.hcl

```hcl
# infrastructure/live/staging/networking/terragrunt.hcl

# Kế thừa từ root (tìm terragrunt.hcl ở thư mục cha)
include "root" {
  path = find_in_parent_folders()
}

# Load env variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

# Trỏ đến Terraform module
terraform {
  source = "../../../../modules//networking"
  
  # Hooks: chạy script trước/sau terraform
  before_hook "validate_az_login" {
    commands = ["apply", "plan"]
    execute  = ["bash", "-c", "az account show > /dev/null || (echo 'Not logged in to Azure!' && exit 1)"]
  }
  
  after_hook "notify_slack" {
    commands     = ["apply"]
    execute      = ["bash", "${get_repo_root()}/scripts/notify-slack.sh", "networking", local.env.environment]
    run_on_error = false
  }
}

# Inputs specific cho networking module
inputs = {
  vnet_name       = "vnet-${local.env.environment}"
  vnet_cidr       = local.env.vnet_cidr
  aks_subnet_cidr = local.env.aks_subnet_cidr
  app_subnet_cidr = local.env.app_subnet_cidr
  db_subnet_cidr  = local.env.db_subnet_cidr
}
```


## 4. Dependencies Giữa Modules

### 4.1 Khai Báo Dependencies

```hcl
# infrastructure/live/staging/aks/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

# ===== DEPENDENCIES =====
# AKS cần networking phải được deploy trước
dependency "networking" {
  config_path = "../networking"
  
  # Giá trị mock khi chạy plan (tránh lỗi vì networking chưa exist)
  mock_outputs = {
    vnet_id                = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/xxx"
    aks_subnet_id          = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/xxx/subnets/aks"
    resource_group_name    = "rg-myapp-staging"
    resource_group_location = "southeastasia"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "acr" {
  config_path = "../acr"
  
  mock_outputs = {
    acr_id       = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.ContainerRegistry/registries/xxx"
    acr_login_server = "myappstaging.azurecr.io"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules//aks"
}

inputs = {
  # Từ networking module
  resource_group_name = dependency.networking.outputs.resource_group_name
  location            = dependency.networking.outputs.resource_group_location
  vnet_id             = dependency.networking.outputs.vnet_id
  subnet_id           = dependency.networking.outputs.aks_subnet_id
  
  # Từ acr module
  acr_id              = dependency.acr.outputs.acr_id
  
  # Từ env.hcl
  node_count          = local.env.aks_node_count
  node_vm_size        = local.env.aks_node_vm_size
  kubernetes_version  = local.env.aks_k8s_version
  
  cluster_name        = "aks-myapp-${local.env.environment}"
}
```

### 4.2 Dependency Graph

```bash
# Xem dependency graph
terragrunt graph-dependencies

# Output (dot format):
# digraph {
#   "networking" ;
#   "acr" ;
#   "aks" -> "networking" ;
#   "aks" -> "acr" ;
#   "postgresql" -> "networking" ;
# }

# Visualize với graphviz
terragrunt graph-dependencies | dot -Tpng > dependency-graph.png
```


## 5. Run-All Commands

### 5.1 Các Lệnh Terragrunt Quan Trọng

```bash
# ===== LỆNH CƠ BẢN =====

# Init tất cả modules trong một lần
cd infrastructure/live/staging
terragrunt run-all init

# Plan tất cả
terragrunt run-all plan

# Apply tất cả (theo thứ tự dependency)
terragrunt run-all apply

# Destroy tất cả (reverse dependency order)
terragrunt run-all destroy

# ===== FILTER THEO THƯ MỤC =====

# Apply chỉ networking và các dependencies của nó
terragrunt run-all apply --terragrunt-include-dir="./networking"

# Exclude một số module
terragrunt run-all apply \
  --terragrunt-exclude-dir="./acr" \
  --terragrunt-exclude-dir="./monitoring"

# ===== CỜ HỮU ÍCH =====

# Auto-approve (dùng trong CI/CD)
terragrunt run-all apply --terragrunt-non-interactive

# Tắt màu (cho log)
terragrunt run-all plan --terragrunt-no-color

# Ignore dependency errors
terragrunt run-all apply --terragrunt-ignore-dependency-errors

# Chạy 1 module bình thường
cd infrastructure/live/staging/networking
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output
```

### 5.2 Output Commands

```bash
# Xem output của một module
cd infrastructure/live/staging/networking
terragrunt output

# Output dạng JSON
terragrunt output -json

# Output cụ thể
terragrunt output vnet_id

# Xem state
terragrunt state list
terragrunt state show azurerm_virtual_network.main
```


## 6. Quản Lý Azure State Backend

### 6.1 Tạo Storage Account cho State

```bash
#!/bin/bash
# scripts/init-azure-backend.sh
# Chạy lần đầu để tạo Storage Account cho Terraform state

set -euo pipefail

ENVIRONMENT=${1:-"staging"}
PROJECT_NAME="myapp"
LOCATION="southeastasia"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Resource names
RG_NAME="rg-${PROJECT_NAME}-tfstate"
SA_NAME="${PROJECT_NAME}${ENVIRONMENT}tfstate"    # lowercase, max 24 chars
CONTAINER_NAME="tfstate"

echo "=== Tạo Azure Backend cho Terraform State ==="
echo "Environment:  ${ENVIRONMENT}"
echo "Storage:      ${SA_NAME}"
echo ""

# 1. Tạo Resource Group
echo "1. Tạo Resource Group..."
az group create \
  --name "${RG_NAME}" \
  --location "${LOCATION}" \
  --tags Project="${PROJECT_NAME}" ManagedBy="Terragrunt"

# 2. Tạo Storage Account
echo "2. Tạo Storage Account..."
az storage account create \
  --name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true \
  --tags Project="${PROJECT_NAME}" Environment="${ENVIRONMENT}"

# 3. Bật versioning (khôi phục state nếu bị xóa nhầm)
echo "3. Bật Blob Versioning..."
az storage account blob-service-properties update \
  --account-name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30

# 4. Tạo Container
echo "4. Tạo Container..."
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${SA_NAME}" \
  --auth-mode login

# 5. Bật soft delete cho container
az storage container-rm update \
  --storage-account "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --name "${CONTAINER_NAME}" \
  --enable-container-delete-retention true \
  --container-delete-retention-days 14

echo ""
echo "=== HOÀN THÀNH ==="
echo "Storage Account: ${SA_NAME}"
echo "Container:       ${CONTAINER_NAME}"
echo "Resource Group:  ${RG_NAME}"
echo ""
echo "Cấu hình trong root terragrunt.hcl:"
cat << EOF
remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "${RG_NAME}"
    storage_account_name = "${SA_NAME}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "\${local.component}/\${local.environment}.tfstate"
  }
}
EOF
```

### 6.2 Phân Quyền Azure RBAC cho Terraform

```bash
# Service Principal cho Terragrunt/Terraform
# Đây là account mà Terragrunt sẽ dùng để tạo resources

# 1. Tạo Service Principal
SP_NAME="sp-terragrunt-${ENVIRONMENT}"
SP=$(az ad sp create-for-rbac \
  --name "${SP_NAME}" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --output json)

CLIENT_ID=$(echo $SP | jq -r '.appId')
CLIENT_SECRET=$(echo $SP | jq -r '.password')
TENANT_ID=$(echo $SP | jq -r '.tenant')

echo "CLIENT_ID:     ${CLIENT_ID}"
echo "CLIENT_SECRET: ${CLIENT_SECRET}"  # Lưu an toàn!
echo "TENANT_ID:     ${TENANT_ID}"

# 2. Phân quyền thêm cho Storage (để manage state)
az role assignment create \
  --assignee "${CLIENT_ID}" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"

# 3. Export environment variables cho Terraform
export ARM_CLIENT_ID="${CLIENT_ID}"
export ARM_CLIENT_SECRET="${CLIENT_SECRET}"
export ARM_TENANT_ID="${TENANT_ID}"
export ARM_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"

# Hoặc lưu vào .env file (đừng commit!)
cat > .env.${ENVIRONMENT} << EOF
export ARM_CLIENT_ID="${CLIENT_ID}"
export ARM_CLIENT_SECRET="${CLIENT_SECRET}"
export ARM_TENANT_ID="${TENANT_ID}"
export ARM_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
EOF

echo "Lưu file .env.${ENVIRONMENT} vào Azure Key Vault hoặc CI/CD secrets!"
```


## 7. Terragrunt với CI/CD (Azure DevOps)

```yaml
# azure-pipelines-terragrunt.yml

trigger:
  branches:
    include: [main, develop]
  paths:
    include: [infrastructure/live/**]

variables:
  - group: terragrunt-azure-credentials   # Variable group trong Azure DevOps
  - name: TF_IN_AUTOMATION
    value: "true"
  - name: TERRAGRUNT_VERSION
    value: "0.55.0"

stages:
  - stage: Plan
    displayName: "Terragrunt Plan"
    jobs:
      - job: PlanStaging
        displayName: "Plan Staging"
        pool:
          vmImage: ubuntu-latest
        
        steps:
          - checkout: self
          
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: "1.7.0"
          
          - script: |
              wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v$(TERRAGRUNT_VERSION)/terragrunt_linux_amd64
              chmod +x terragrunt_linux_amd64
              sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
              terragrunt --version
            displayName: "Install Terragrunt"
          
          - script: |
              export ARM_CLIENT_ID=$(ARM_CLIENT_ID)
              export ARM_CLIENT_SECRET=$(ARM_CLIENT_SECRET)
              export ARM_TENANT_ID=$(ARM_TENANT_ID)
              export ARM_SUBSCRIPTION_ID=$(ARM_SUBSCRIPTION_ID)
              
              cd infrastructure/live/staging
              terragrunt run-all plan \
                --terragrunt-non-interactive \
                --terragrunt-no-color \
                -out=tfplan 2>&1 | tee plan_output.txt
            displayName: "Terragrunt Plan Staging"
            env:
              ARM_CLIENT_ID: $(ARM_CLIENT_ID)
              ARM_CLIENT_SECRET: $(ARM_CLIENT_SECRET)
              ARM_TENANT_ID: $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
          
          - publish: infrastructure/live/staging
            artifact: staging-plan
  
  - stage: ApplyStaging
    displayName: "Apply Staging"
    dependsOn: Plan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
    jobs:
      - deployment: DeployStaging
        displayName: "Deploy to Staging"
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: staging-plan
                
                - script: |
                    cd infrastructure/live/staging
                    terragrunt run-all apply \
                      --terragrunt-non-interactive \
                      --terragrunt-no-color
                  displayName: "Terragrunt Apply Staging"
                  env:
                    ARM_CLIENT_ID: $(ARM_CLIENT_ID)
                    ARM_CLIENT_SECRET: $(ARM_CLIENT_SECRET)
                    ARM_TENANT_ID: $(ARM_TENANT_ID)
                    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
  
  - stage: ApplyProduction
    displayName: "Apply Production"
    dependsOn: ApplyStaging
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployProduction
        displayName: "Deploy to Production"
        environment: production    # Có approval gate trong Azure DevOps
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    cd infrastructure/live/production
                    terragrunt run-all apply \
                      --terragrunt-non-interactive \
                      --terragrunt-no-color
                  displayName: "Terragrunt Apply Production"
                  env:
                    ARM_CLIENT_ID: $(ARM_CLIENT_ID_PROD)
                    ARM_CLIENT_SECRET: $(ARM_CLIENT_SECRET_PROD)
                    ARM_TENANT_ID: $(ARM_TENANT_ID)
                    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID_PROD)
```
