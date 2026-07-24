# ---
markmap:
  title: "Terragrunt — Azure Complete"
  collapse: false
# ---

# 🌿 TERRAGRUNT TOÀN TẬP - PHẦN 2: AZURE INFRASTRUCTURE HOÀN CHỈNH

## Theory
- Terragrunt helps enforce DRY patterns and manage remote state across environments, simplifying module reuse for Azure infrastructure.

## Practice
- Keep shared logic in root `terragrunt.hcl`, use `remote_state` generation for consistent backends, and use `dependency` blocks to wire module outputs.

## 1. Terraform Modules Cho Azure

### 1.1 Module Networking (VNet, Subnets, NSG)

```hcl
# modules/networking/main.tf

variable "project_name" { type = string }
variable "environment"  { type = string }
variable "location"     { type = string }
variable "tags"         { type = map(string); default = {} }

variable "vnet_cidr"          { type = string; default = "10.0.0.0/16" }
variable "aks_subnet_cidr"    { type = string; default = "10.0.1.0/24" }
variable "app_subnet_cidr"    { type = string; default = "10.0.2.0/24" }
variable "db_subnet_cidr"     { type = string; default = "10.0.3.0/24" }
variable "gateway_subnet_cidr"{ type = string; default = "10.0.255.0/27" }

# ===== RESOURCE GROUP =====
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ===== VIRTUAL NETWORK =====
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Enable DDoS protection cho production
  # ddos_protection_plan {
  #   id     = azurerm_network_ddos_protection_plan.main.id
  #   enable = true
  # }
  
  tags = var.tags
}

# ===== SUBNETS =====
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
  
  # Cho AKS network policy
  private_endpoint_network_policies_enabled     = true
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.app_subnet_cidr]
  
  # Service Endpoints cho Azure services
  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.KeyVault"
  ]
  
  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.db_subnet_cidr]
  
  service_endpoints = ["Microsoft.Sql"]
  
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Tên bắt buộc cho VPN Gateway
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# ===== NETWORK SECURITY GROUPS =====
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-${var.environment}"
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

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ===== OUTPUTS =====
output "resource_group_name"    { value = azurerm_resource_group.main.name }
output "resource_group_location"{ value = azurerm_resource_group.main.location }
output "vnet_id"               { value = azurerm_virtual_network.main.id }
output "vnet_name"             { value = azurerm_virtual_network.main.name }
output "aks_subnet_id"         { value = azurerm_subnet.aks.id }
output "app_subnet_id"         { value = azurerm_subnet.app.id }
output "db_subnet_id"          { value = azurerm_subnet.db.id }
```

### 1.2 Module AKS (Azure Kubernetes Service)

```hcl
# modules/aks/main.tf

variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "tags"                { type = map(string) }
variable "resource_group_name" { type = string }
variable "subnet_id"           { type = string }
variable "acr_id"              { type = string }

variable "cluster_name"        { type = string }
variable "kubernetes_version"  { type = string; default = "1.28" }
variable "node_count"          { type = number; default = 2 }
variable "node_vm_size"        { type = string; default = "Standard_D2s_v3" }
variable "min_node_count"      { type = number; default = 1 }
variable "max_node_count"      { type = number; default = 10 }

# ===== LOG ANALYTICS =====
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "production" ? 90 : 30
  tags                = var.tags
}

# ===== AKS CLUSTER =====
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  
  # Node Resource Group (nodes, LBs, disks sẽ vào đây)
  node_resource_group = "rg-${var.project_name}-${var.environment}-aks-nodes"
  
  # ===== DEFAULT NODE POOL =====
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = var.subnet_id
    
    # Auto-scaling
    enable_auto_scaling = true
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    
    # OS Disk
    os_disk_size_gb     = 128
    os_disk_type        = "Ephemeral"   # Nhanh hơn, tiết kiệm chi phí
    
    # Spot Instances cho dev/staging
    # priority        = "Spot"
    # eviction_policy = "Delete"
    # spot_max_price  = -1
    
    # Node labels
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }
    
    zones = ["1", "2", "3"]  # Availability Zones
    
    upgrade_settings {
      max_surge = "33%"
    }
  }
  
  # ===== IDENTITY =====
  identity {
    type = "SystemAssigned"
  }
  
  # ===== NETWORK =====
  network_profile {
    network_plugin    = "azure"          # Azure CNI (không phải kubenet)
    network_policy    = "calico"         # Network policies
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
    outbound_type     = "loadBalancer"
    load_balancer_sku = "standard"
  }
  
  # ===== ADD-ONS =====
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }
  
  azure_policy_enabled = true
  
  http_application_routing_enabled = false  # Dùng ingress controller riêng
  
  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
  
  # ===== MONITORING =====
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }
  
  # ===== AUTO UPGRADE =====
  automatic_channel_upgrade = var.environment == "production" ? "stable" : "rapid"
  
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+07:00"
  }
  
  # ===== SECURITY =====
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }
  
  local_account_disabled = true  # Disable local admin (force AAD auth)
  
  tags = var.tags
}

# ===== USER NODE POOL (cho workloads) =====
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_vm_size
  node_count            = var.node_count
  vnet_subnet_id        = var.subnet_id
  
  enable_auto_scaling = true
  min_count           = var.min_node_count
  max_count           = var.max_node_count
  
  node_labels = {
    "nodepool-type" = "user"
  }
  
  node_taints = []  # Không taint → user workloads chạy được
  
  zones = ["1", "2", "3"]
  
  tags = var.tags
}

# ===== ACR PULL PERMISSION =====
# Cho phép AKS pull images từ ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
}

# ===== OUTPUTS =====
output "cluster_id"            { value = azurerm_kubernetes_cluster.main.id }
output "cluster_name"          { value = azurerm_kubernetes_cluster.main.name }
output "kube_config"           { value = azurerm_kubernetes_cluster.main.kube_config_raw; sensitive = true }
output "host"                  { value = azurerm_kubernetes_cluster.main.kube_config.0.host; sensitive = true }
output "client_certificate"    { value = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate; sensitive = true }
output "oidc_issuer_url"       { value = azurerm_kubernetes_cluster.main.oidc_issuer_url }
output "identity_principal_id" { value = azurerm_kubernetes_cluster.main.identity[0].principal_id }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.aks.id }
```

### 1.3 Module ACR (Azure Container Registry)

```hcl
# modules/acr/main.tf

variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "tags"                { type = map(string) }
variable "resource_group_name" { type = string }
variable "sku"                 { type = string; default = "Standard" }
variable "geo_replication_locations" {
  type    = list(string)
  default = []
}

resource "azurerm_container_registry" "main" {
  # ACR name: lowercase alphanumeric, 5-50 chars
  name                = "${var.project_name}${var.environment}acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false  # Dùng RBAC thay vì admin credentials
  
  # Geo-replication cho production (Premium SKU)
  dynamic "georeplications" {
    for_each = var.geo_replication_locations
    content {
      location                  = georeplications.value
      zone_redundancy_enabled   = true
      regional_endpoint_enabled = true
      tags                      = var.tags
    }
  }
  
  # Content trust (image signing) - Premium only
  # trust_policy {
  #   enabled = true
  # }
  
  # Vulnerability scanning
  # quarantine_policy_enabled = true
  
  # Retention policy (auto-delete old images)
  retention_policy {
    days    = var.environment == "production" ? 90 : 30
    enabled = true
  }
  
  network_rule_set {
    default_action = "Allow"
    # Restrict để cho phép chỉ từ VNet
    # ip_rule {
    #   action   = "Allow"
    #   ip_range = "0.0.0.0/0"
    # }
  }
  
  tags = var.tags
}

output "acr_id"           { value = azurerm_container_registry.main.id }
output "acr_name"         { value = azurerm_container_registry.main.name }
output "acr_login_server" { value = azurerm_container_registry.main.login_server }
```

### 1.4 Module PostgreSQL Flexible Server

```hcl
# modules/postgresql/main.tf

variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "tags"                { type = map(string) }
variable "resource_group_name" { type = string }
variable "subnet_id"           { type = string }
variable "private_dns_zone_id" { type = string }

variable "db_name"       { type = string }
variable "admin_username"{ type = string; default = "psqladmin" }
variable "admin_password"{ type = string; sensitive = true }
variable "sku_name"      { type = string; default = "B_Standard_B1ms" }
variable "storage_mb"    { type = number; default = 32768 }
variable "backup_days"   { type = number; default = 7 }

# ===== PRIVATE DNS ZONE =====
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project_name}-${var.environment}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdnslink-postgres-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id  # Cần VNet ID
  tags                  = var.tags
}

# ===== POSTGRESQL FLEXIBLE SERVER =====
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  
  sku_name   = var.sku_name
  version    = "15"
  storage_mb = var.storage_mb
  
  # Network: Private Access
  delegated_subnet_id           = var.subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  
  backup_retention_days        = var.backup_days
  geo_redundant_backup_enabled = var.environment == "production"
  
  # High Availability
  dynamic "high_availability" {
    for_each = var.environment == "production" ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }
  
  maintenance_window {
    day_of_week  = 0   # Sunday
    start_hour   = 2
    start_minute = 0
  }
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
  
  tags = var.tags
}

# ===== DATABASE =====
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ===== CONFIGURATIONS =====
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "pg_qs_track_utility" {
  name      = "pg_qs.track_utility"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

output "server_fqdn"   { value = azurerm_postgresql_flexible_server.main.fqdn }
output "server_name"   { value = azurerm_postgresql_flexible_server.main.name }
output "database_name" { value = azurerm_postgresql_flexible_server_database.main.name }
```


## 2. Cấu Hình Hoàn Chỉnh Live Environment

### 2.1 live/staging/aks/terragrunt.hcl

```hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

dependency "networking" {
  config_path = "../networking"
  mock_outputs = {
    resource_group_name     = "rg-myapp-staging"
    resource_group_location = "southeastasia"
    vnet_id                 = "/subscriptions/xxx/resourceGroups/rg-myapp-staging/providers/Microsoft.Network/virtualNetworks/vnet-myapp-staging"
    aks_subnet_id           = "/subscriptions/xxx/resourceGroups/rg-myapp-staging/providers/Microsoft.Network/virtualNetworks/vnet-myapp-staging/subnets/snet-aks"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "acr" {
  config_path = "../acr"
  mock_outputs = {
    acr_id           = "/subscriptions/xxx/resourceGroups/rg-myapp-staging/providers/Microsoft.ContainerRegistry/registries/myappstaging"
    acr_login_server = "myappstaging.azurecr.io"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../modules//aks"
}

inputs = {
  resource_group_name = dependency.networking.outputs.resource_group_name
  location            = dependency.networking.outputs.resource_group_location
  subnet_id           = dependency.networking.outputs.aks_subnet_id
  acr_id              = dependency.acr.outputs.acr_id
  
  cluster_name        = "aks-myapp-${local.env.environment}"
  kubernetes_version  = local.env.aks_k8s_version
  node_count          = local.env.aks_node_count
  node_vm_size        = local.env.aks_node_vm_size
  min_node_count      = 1
  max_node_count      = 5
}
```


## 3. Best Practices & Tips

### 3.1 Terragrunt DRY Patterns

```hcl
# Sử dụng read_terragrunt_config để tái dùng config
locals {
  # Pattern: đọc config từ nhiều level
  root_config    = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  env_config     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_config = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  
  # Merge tất cả
  merged = merge(
    local.root_config.locals,
    local.env_config.locals,
    local.account_config.locals
  )
}

# Tạo naming convention function
locals {
  name_prefix = "${local.merged.project}-${local.merged.environment}"
  
  common_tags = {
    Project     = local.merged.project
    Environment = local.merged.environment
    ManagedBy   = "Terragrunt"
    CostCenter  = local.merged.cost_center
  }
}
```

### 3.2 Xử Lý Secrets Với Azure Key Vault

```hcl
# Trong terragrunt.hcl - đọc secret từ Key Vault
locals {
  # Sử dụng sops hoặc Azure CLI để đọc secrets
  db_password = run_cmd("az", "keyvault", "secret", "show",
    "--vault-name", "kv-myapp-${local.environment}",
    "--name", "postgres-admin-password",
    "--query", "value",
    "-o", "tsv"
  )
}

inputs = {
  admin_password = local.db_password
}
```

### 3.3 Terraform Locks Với Azure

```bash
# Terraform dùng Azure Storage Blob Lease làm state lock
# Khi apply đang chạy → blob bị lock

# Nếu pipeline bị kill giữa chừng → lock còn
# Giải phóng lock thủ công:

# 1. Tìm lock ID
terragrunt force-unlock <LOCK_ID>

# Hoặc xóa lease trực tiếp qua Azure CLI
az storage blob lease break \
  --account-name myappstagingtfstate \
  --container-name tfstate \
  --blob-name aks/staging.tfstate
```
