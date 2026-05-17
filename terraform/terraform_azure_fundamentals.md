# ☁️ TERRAFORM DÀNH CHO AZURE - PHẦN 1: FUNDAMENTALS & AZURE PROVIDER

---

## 1. Terraform + Azure – Tổng quan

- **Provider:** `hashicorp/azurerm` – hỗ trợ hầu hết các dịch vụ Azure.
- **Backend:** Đề xuất dùng **Azure Storage Account** để lưu state (remote backend) – an toàn, lock.
- **Authentication:** Service Principal (client_id/secret/tenant) hoặc Managed Identity (trong Azure VM/AKS).
- **Versioning:** Bảo trì provider version (`~> 3.90`) để tránh breaking changes.

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    resource_group_name   = "tfstate-rg"
    storage_account_name  = "tfstatestorage001"
    container_name        = "tfstate"
    key                   = "myapp/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # Authentication via env vars (recommended)
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}
```

## 2. Tạo Service Principal (SP) cho Terraform

```bash
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role "Contributor" \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG> \
  --years 2

# Export env vars (CI secret store có thể dùng)
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

> **Tip:** Đặt các biến này trong Azure DevOps / GitHub Actions secret store, **không** commit vào repo.

## 3. Ví dụ: Deploy Azure Resource Group, VNet, Subnet

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project}-${var.env}"  # rg-myapp-prod
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project}-${var.env}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

variable "project" {default = "myapp"}
variable "env" {default = "prod"}
variable "location" {default = "southeastasia"}
variable "tags" {
  default = {
    Environment = "prod"
    Project     = "myapp"
  }
}
```

## 4. Azure Kubernetes Service (AKS) + ACR Integration

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.project}-${var.env}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.project}-${var.env}"
  kubernetes_version  = "1.29.2"
  sku_tier            = "Standard"

  default_node_pool {
    name       = "system"
    node_count = 3
    vm_size    = "Standard_D4s_v5"
    zones      = [1, 2, 3]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/24"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  addon_profile {
    oms_agent {
      enabled = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
    }
    azure_policy {
      enabled = true
    }
  }

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]  # Allow autoscaling via CLI/Portal
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "myappregistry001"  # must be globally unique
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false
  georeplication_location = ["eastus", "westeurope"]
}

# Grant AKS pull rights from ACR (managed identity)
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
```

## 5. Azure Database for PostgreSQL Flexible Server (Managed)

```hcl
resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "pg-${var.project}-${var.env}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "15"
  administrator_login = "pgadmin"
  administrator_password = random_password.pg.result

  sku_name   = var.env == "prod" ? "GP_Standard_D4s_v3" : "B_Standard_B2s"
  storage_mb = var.env == "prod" ? 131072 : 32768

  backup_retention_days = var.env == "prod" ? 30 : 7
  high_availability {
    mode = var.env == "prod" ? "ZoneRedundant" : "Disabled"
  }
  network {
    delegated_subnet_id = azurerm_subnet.db.id
  }
}

resource "random_password" "pg" {
  length  = 32
  special = true
}

resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  delegations {
    name = "postgresql"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}
```

## 6. Sử dụng Terraform với Azure DevOps Pipelines (CI/CD)

```yaml
# azure-pipelines.yml (Terraform CI/CD)
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: azure-terraform-variables   # chứa ARM_* env vars

steps:
  - task: TerraformInstaller@0
    inputs:
      terraformVersion: '1.6.x'

  - script: |
      terraform init -backend-config="resource_group_name=tfstate-rg" \
        -backend-config="storage_account_name=tfstatestorage001" \
        -backend-config="container_name=tfstate" \
        -backend-config="key=myapp/terraform.tfstate"
    displayName: 'Terraform Init'

  - script: terraform fmt -check
    displayName: 'Check Formatting'

  - script: terraform validate
    displayName: 'Validate'

  - script: terraform plan -out=tfplan
    displayName: 'Plan'

  - task: ManualValidation@0
    inputs:
      notifyUsers: 'devops@company.com'
      instructions: 'Approve Terraform apply?'
    timeoutInMinutes: 1440

  - script: terraform apply -auto-approve tfplan
    displayName: 'Apply'
```

## 7. Best Practices cho Terraform + Azure

| Practice | Reason |
|----------|--------|
| **Remote backend (Azure Storage)** – tránh state冲突, lock‑based. |
| **Service Principal with least‑privilege** – chỉ cấp `Contributor` trên resource group cần dùng. |
| **Lock-down state files** – enable soft‑delete & purge‑protection on storage account. |
| **Use `for_each` & modules** – tái sử dụng VNet, Subnet, NSG, Key Vault. |
| **Run `terraform fmt` & `terraform validate`** trong CI pipeline. |
| **Separate environments** – mỗi env có riêng resource group, backend key. |
| **Tag resources** – giúp cost allocation và governance (`Environment`, `Project`, `Owner`). |
| **Enable Azure Policy & Defender** – tự động audit compliance. |

---

> **Tiếp theo:** Document Ansible Azure integration (playbooks, azure.azcollection, dynamic inventory).
