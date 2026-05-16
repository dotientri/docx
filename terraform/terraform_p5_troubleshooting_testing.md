# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 5: TROUBLESHOOTING, TESTING & REAL-WORLD

---

## 1. Troubleshooting Common Issues

### 1.1 State Issues

```bash
# ===== VẤN ĐỀ: State Locked =====
# Error: Error acquiring the state lock

# Xem lock info
terraform force-unlock <LOCK-ID>
# Cẩn thận! Chỉ dùng khi chắc không có ai đang apply

# Với Azure Storage backend - break lease trực tiếp
az storage blob lease break \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --blob-name "production/main.tfstate"

# Xem lock status
az storage blob show \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --name "production/main.tfstate" \
  --query "properties.lease"

# ===== VẤN ĐỀ: State Drift =====
# Infrastructure đã bị thay đổi bên ngoài Terraform (manual changes)

# Xem drift
terraform plan -refresh-only

# Accept drift (update state to match actual Azure)
terraform apply -refresh-only

# Overwrite drift (apply Terraform config, undo manual changes)
terraform apply

# ===== VẤN ĐỀ: Resource "bị mất" khỏi state =====
# Resource exists in Azure nhưng không có trong state

# Import lại từ Azure Resource ID
terraform import azurerm_resource_group.main \
  /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod

terraform import azurerm_kubernetes_cluster.main \
  /subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod/providers/Microsoft.ContainerService/managedClusters/aks-myapp-prod

# Bulk import (Terraform 1.5+)
import {
  to = azurerm_resource_group.main
  id = "/subscriptions/<SUB_ID>/resourceGroups/rg-myapp-prod"
}

# ===== VẤN ĐỀ: Corrupt State =====
# Azure Storage Blob Versioning giúp rollback

# Xem versions của state file
az storage blob list \
  --account-name mycompanytfstate \
  --container-name tfstate \
  --prefix "production/main.tfstate" \
  --include v \
  --query "[].{name:name, version:versionId, lastModified:properties.lastModified}" \
  -o table

# Restore previous version
az storage blob copy start \
  --source-account-name mycompanytfstate \
  --source-container tfstate \
  --source-blob "production/main.tfstate" \
  --source-version-id <VERSION_ID> \
  --destination-account-name mycompanytfstate \
  --destination-container tfstate \
  --destination-blob "production/main.tfstate"
```

### 1.2 Provider và Dependency Issues

```bash
# ===== PROVIDER VERSION CONFLICT =====
# Error: Inconsistent dependency lock file

# Xóa và reinit
rm -rf .terraform .terraform.lock.hcl
terraform init

# Update tất cả providers
terraform init -upgrade

# ===== DEPENDENCY CYCLES =====
# Error: Cycle detected

# Xem dependency graph
terraform graph | dot -Tsvg > deps.svg
# Mở deps.svg trong browser để xem cycle

# Giải quyết: Sử dụng depends_on explicit
# hoặc chia module ra thành nhiều phần

# ===== PROVIDER TIMEOUT (Azure API) =====
provider "azurerm" {
  features {}

  # Resource-level timeout
  # Cấu hình trong resource:
}

resource "azurerm_kubernetes_cluster" "main" {
  # AKS mất nhiều thời gian tạo
  timeouts {
    create = "90m"
    update = "60m"
    delete = "60m"
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

# ===== KNOWN AZURE ISSUES =====
# 1. Resource deleted outside Terraform (Azure Portal)
terraform apply
# → Terraform sẽ tạo lại resource

# 2. Azure resource name still reserved (soft delete)
# Key Vault có soft delete → name vẫn bị reserve 90 ngày
# Fix: purge soft deleted Key Vault
az keyvault purge --name kv-myapp-prod --location southeastasia

# 3. Invalid Azure credentials
az account show    # Verify login
az account set --subscription <SUB_ID>
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
terraform plan

# 4. Resource Group không thể xóa (có resources)
# Fix: Xóa resources trước hoặc set prevent_deletion=false
resource "azurerm_resource_group" "main" {
  lifecycle {
    prevent_destroy = false
  }
}
```

### 1.3 Debugging

```bash
# ===== VERBOSE LOGGING =====
TF_LOG=TRACE terraform apply 2>&1 | head -100

# Log levels: TRACE, DEBUG, INFO, WARN, ERROR
TF_LOG=DEBUG terraform plan

# Log to file
TF_LOG=DEBUG TF_LOG_PATH=./terraform-debug.log terraform apply

# ===== TERRAFORM CONSOLE (Interactive REPL) =====
terraform console

# Trong console:
> var.environment
"production"

> local.name_prefix
"myapp-production"

> cidrsubnet("10.0.0.0/16", 8, 5)
"10.0.5.0/24"

> length(var.subnet_ids)
3

> jsondecode(file("config.json"))

# ===== PLAN JSON OUTPUT =====
terraform plan -out=tfplan
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions[] | contains("delete"))'
# → Xem chỉ những gì bị xóa
```

---

## 2. Testing Terraform

### 2.1 Terraform Test (Built-in - v1.6+)

```hcl
# tests/networking.tftest.hcl

# Variables cho test
variables {
  environment  = "test"
  project_name = "myapp-test"
  location     = "Southeast Asia"
  vnet_cidr    = "10.0.0.0/16"
}

# Test 1: VNet được tạo đúng
run "vnet_is_created" {
  command = plan    # plan hoặc apply

  assert {
    condition     = azurerm_virtual_network.main.address_space[0] == var.vnet_cidr
    error_message = "VNet CIDR does not match"
  }

  assert {
    condition     = azurerm_virtual_network.main.location == "southeastasia"
    error_message = "VNet location is incorrect"
  }
}

# Test 2: Resource Group đúng tên
run "resource_group_naming" {
  command = plan

  assert {
    condition     = azurerm_resource_group.main.name == "rg-myapp-test-test"
    error_message = "Resource Group name format incorrect"
  }
}

# Test 3: Tags đúng
run "resources_have_required_tags" {
  assert {
    condition     = contains(keys(azurerm_resource_group.main.tags), "Environment")
    error_message = "Resource Group should have Environment tag"
  }

  assert {
    condition     = azurerm_resource_group.main.tags["Environment"] == var.environment
    error_message = "Environment tag value incorrect"
  }

  assert {
    condition     = contains(keys(azurerm_resource_group.main.tags), "ManagedBy")
    error_message = "Resource Group should have ManagedBy tag"
  }
}
```

```bash
# Chạy tests
terraform test
terraform test -filter tests/networking.tftest.hcl
terraform test -verbose
```

### 2.2 Terratest (Go Testing Framework)

```go
// tests/networking_test.go
package test

import (
    "testing"
    "os"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/azure"
    "github.com/stretchr/testify/assert"
)

func TestNetworkingModule(t *testing.T) {
    t.Parallel()

    subscriptionID := os.Getenv("ARM_SUBSCRIPTION_ID")

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/networking",

        Vars: map[string]interface{}{
            "vnet_cidr":    "10.0.0.0/16",
            "environment":  "test",
            "project_name": "terratest",
            "location":     "Southeast Asia",
        },

        // Retry để handle eventual consistency
        MaxRetries:         3,
        TimeBetweenRetries: 5 * time.Second,
    }

    // Cleanup sau test
    defer terraform.Destroy(t, terraformOptions)

    // Init và Apply
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
    assert.Equal(t, "rg-terratest-test", resourceGroupName)

    vnetId := terraform.Output(t, terraformOptions, "vnet_id")
    assert.NotEmpty(t, vnetId)

    // Validate bằng Azure SDK
    vnet := azure.GetVirtualNetwork(t, resourceGroupName, "vnet-terratest-test", subscriptionID)
    assert.NotNil(t, vnet)
    assert.Equal(t, "10.0.0.0/16", (*vnet.AddressSpace.AddressPrefixes)[0])
}

func TestAKSModule(t *testing.T) {
    t.Parallel()

    subscriptionID := os.Getenv("ARM_SUBSCRIPTION_ID")

    // ... test AKS module
    aksCluster := azure.GetManagedCluster(t, "rg-terratest-test", "aks-terratest-test", subscriptionID)
    assert.NotNil(t, aksCluster)
    assert.Equal(t, "Succeeded", string(*aksCluster.Properties.ProvisioningState))
}
```

```bash
# Chạy Terratest
go test ./... -v -timeout 60m
go test ./tests/... -run TestNetworkingModule -v
```

### 2.3 Validate Policies với OPA

```bash
# ===== OPA (Open Policy Agent) với Terraform =====
# Validate Terraform plan với Azure policies

cat > azure-policy.rego << 'EOF'
package terraform

# Deny Azure VMs không có encryption
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_linux_virtual_machine"
    not resource.change.after.os_disk[_].disk_encryption_set_id
    msg := sprintf("VM %s phải có disk encryption", [resource.address])
}

# Require minimum VM size trong production
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_linux_virtual_machine"
    resource.change.after.tags.Environment == "production"
    resource.change.after.size == "Standard_B1s"
    msg := sprintf("Standard_B1s không được phép trong production: %s", [resource.address])
}

# All Azure resources must have required tags
required_tags := ["Environment", "Project", "ManagedBy"]

deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    tag := required_tags[_]
    not resource.change.after.tags[tag]
    msg := sprintf("Resource %s thiếu tag bắt buộc: %s", [resource.address, tag])
}

# Azure Storage Accounts phải có HTTPS only
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_storage_account"
    resource.change.after.enable_https_traffic_only == false
    msg := sprintf("Storage Account %s phải bật HTTPS only", [resource.address])
}
EOF

# Validate
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
opa eval -d azure-policy.rego -I plan.json "data.terraform.deny"
```

---

## 3. Real-World Patterns

### 3.1 GitOps với Terraform và Azure DevOps

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
      - job: TerraformValidate
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TERRAFORM_VERSION)

          - script: terraform fmt -check -recursive
            displayName: "Format Check"

          - script: |
              terraform init -backend=false
              terraform validate
            workingDirectory: terraform/environments/production
            env:
              ARM_CLIENT_ID:       $(ARM_CLIENT_ID)
              ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET)
              ARM_TENANT_ID:       $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)

  - stage: Plan
    dependsOn: Validate
    jobs:
      - job: TerraformPlan
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TERRAFORM_VERSION)

          - script: |
              terraform init
              terraform plan -out=tfplan -no-color 2>&1 | tee plan_output.txt
            workingDirectory: terraform/environments/production
            env:
              ARM_CLIENT_ID:       $(ARM_CLIENT_ID)
              ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET)
              ARM_TENANT_ID:       $(ARM_TENANT_ID)
              ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)

          - publish: terraform/environments/production
            artifact: tfplan

  - stage: Apply
    dependsOn: Plan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: TerraformApply
        environment: production    # Có approval gate trong Azure DevOps
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: tfplan

                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: $(TERRAFORM_VERSION)

                - script: |
                    terraform init
                    terraform apply -auto-approve tfplan
                  workingDirectory: $(Pipeline.Workspace)/tfplan
                  env:
                    ARM_CLIENT_ID:       $(ARM_CLIENT_ID)
                    ARM_CLIENT_SECRET:   $(ARM_CLIENT_SECRET)
                    ARM_TENANT_ID:       $(ARM_TENANT_ID)
                    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
```

### 3.2 Disaster Recovery Pattern với Azure

```hcl
# DR configuration với Azure Traffic Manager
variable "enable_dr" {
  description = "Enable Disaster Recovery setup"
  type        = bool
  default     = false
}

# Azure Database for PostgreSQL với geo-backup
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-myapp-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = "Southeast Asia"

  administrator_login    = var.db_admin
  administrator_password = var.db_password

  sku_name   = "GP_Standard_D4s_v3"
  version    = "15"
  storage_mb = 131072

  backup_retention_days        = 35
  geo_redundant_backup_enabled = true   # Backup sang region khác

  # High Availability
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
}

# Azure Traffic Manager cho failover
resource "azurerm_traffic_manager_profile" "main" {
  count               = var.enable_dr ? 1 : 0
  name                = "tm-myapp-global"
  resource_group_name = azurerm_resource_group.main.name

  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "myapp-global"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }
}

# Primary endpoint (Southeast Asia)
resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  count              = var.enable_dr ? 1 : 0
  name               = "primary-sea"
  profile_id         = azurerm_traffic_manager_profile.main[0].id
  target_resource_id = azurerm_public_ip.primary.id
  priority           = 1
}

# DR endpoint (East Asia - failover)
resource "azurerm_traffic_manager_azure_endpoint" "dr" {
  count              = var.enable_dr ? 1 : 0
  name               = "dr-ea"
  profile_id         = azurerm_traffic_manager_profile.main[0].id
  target_resource_id = azurerm_public_ip.dr[0].id
  priority           = 2
}
```

---

## 4. Terraform với Azure OpenID Connect (OIDC)

```yaml
# GitHub Actions với OIDC - không cần secrets!
# azure-terraform.yml

name: Terraform Azure

on:
  push:
    branches: [main]
  pull_request:

permissions:
  id-token: write    # Cần cho OIDC
  contents: read
  pull-requests: write

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # OIDC authentication với Azure (không cần client_secret!)
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id:       ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id:       ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/production
        env:
          ARM_USE_OIDC:        true
          ARM_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan 2>&1 | tee plan_output.txt
        working-directory: terraform/environments/production
        env:
          ARM_USE_OIDC:        true
          ARM_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # Post plan output vào PR comment
      - name: Comment Plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/production/plan_output.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${plan.slice(0, 60000)}\n\`\`\``
            });

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/production
        env:
          ARM_USE_OIDC:        true
          ARM_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## 5. Cheat Sheet Cuối

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
terraform destroy -target=module.aks  # Destroy specific

# STATE MANAGEMENT
terraform state list
terraform state show address
terraform state mv old new
terraform state rm address
terraform state pull > backup.tfstate
terraform import address id

# AZURE-SPECIFIC
az login                          # Login Azure
az account set --subscription ID  # Switch subscription
az account show                   # Verify login
az group list -o table            # List resource groups
az resource list -g <RG> -o table # List resources in RG

# DEBUGGING
TF_LOG=DEBUG terraform plan
terraform console                 # REPL
terraform graph | dot -Tsvg > graph.svg

# FORMATTING & VALIDATION
terraform fmt -recursive
terraform validate
terraform fmt -check              # CI check

# WORKSPACES
terraform workspace list
terraform workspace new staging
terraform workspace select prod

# OUTPUTS
terraform output
terraform output -json
terraform output resource_group_name
```

---

> **Hoàn thành Terraform Toàn Tập!** Tiếp theo: Kubernetes (AKS) & Azure DevOps Pipeline
