---
markmap:
  title: "Azure — DevOps, Monitoring & IaC (Bicep/Terraform)"
  collapse: false
---

# ☁️ AZURE TOÀN TẬP - PHẦN 3: AZURE DEVOPS, MONITORING & BICEP/TERRAFORM

## Theory
- Azure DevOps provides CI/CD, artifact and pipeline management; IaC via Bicep/Terraform for reproducible infra.
- Monitoring best practices: metrics, logs, alerts, and instrumentation (Azure Monitor, Log Analytics).

## Practice
- Build pipelines with lint/test/build/deploy stages; store secrets in Azure Key Vault and link to pipelines.
- Define infra in Bicep or Terraform, use IaC pipelines to plan/apply with approvals and drift detection.

## 1. Azure DevOps - CI/CD Platform

### 1.1 Azure DevOps Overview

```
Azure DevOps = Bộ tools DevOps của Microsoft:

┌─────────────────────────────────────────────┐
│               Azure DevOps                  │
├─────────────────────────────────────────────┤
│  Azure Repos       - Git repositories       │
│  Azure Pipelines   - CI/CD pipelines        │
│  Azure Boards      - Agile project mgmt     │
│  Azure Test Plans  - Test management        │
│  Azure Artifacts   - Package management     │
└─────────────────────────────────────────────┘

Free tier: 5 users, unlimited public repos, 1800 CI/CD minutes/month
```

### 1.2 Azure Pipelines - CI/CD

```yaml
# azure-pipelines.yml - YAML pipeline

trigger:
  branches:
    include:
      - main
      - release/*
  paths:
    exclude:
      - docs/**
      - '*.md'

pr:
  branches:
    include:
      - main
  autoCancel: true

variables:
  - group: production-variables      # Variable group từ Library
  - name: imageRepository
    value: 'myapp'
  - name: containerRegistry
    value: 'myappregistry.azurecr.io'
  - name: dockerfilePath
    value: '$(Build.SourcesDirectory)/Dockerfile'
  - name: tag
    value: '$(Build.BuildId)'

stages:
  # ===== STAGE 1: BUILD & TEST =====
  - stage: BuildAndTest
    displayName: 'Build and Test'
    jobs:
      - job: Build
        displayName: 'Build Application'
        pool:
          vmImage: 'ubuntu-latest'
          
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '20.x'
            displayName: 'Install Node.js'
            
          - script: npm ci
            displayName: 'Install dependencies'
            
          - script: npm run lint
            displayName: 'Run linter'
            
          - script: npm test -- --coverage
            displayName: 'Run unit tests'
            
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: 'coverage/junit.xml'
            condition: always()
            
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: 'Cobertura'
              summaryFileLocation: 'coverage/cobertura-coverage.xml'
              
          - task: Docker@2
            displayName: 'Build Docker image'
            inputs:
              command: buildAndPush
              containerRegistry: 'myapp-acr-connection'    # Service connection
              repository: '$(imageRepository)'
              dockerfile: '$(dockerfilePath)'
              tags: |
                $(tag)
                latest
                
          - task: AzureContainerRegistry@0
            displayName: 'Scan for vulnerabilities'
            inputs:
              azureSubscriptionEndpoint: 'azure-subscription'
              acrName: 'myappregistry'
              repository: '$(imageRepository)'
              tag: '$(tag)'
              
          - task: PublishPipelineArtifact@1
            inputs:
              targetPath: '$(Pipeline.Workspace)'
              artifact: 'drop'
              publishLocation: 'pipeline'

  # ===== STAGE 2: DEPLOY TO STAGING =====
  - stage: DeployStaging
    displayName: 'Deploy to Staging'
    dependsOn: BuildAndTest
    condition: succeeded()
    
    jobs:
      - deployment: DeployToStaging
        displayName: 'Deploy to Staging'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'staging'           # Environment với approvals
        
        strategy:
          runOnce:
            deploy:
              steps:
                - task: HelmDeploy@0
                  displayName: 'Helm upgrade'
                  inputs:
                    connectionType: 'Azure Resource Manager'
                    azureSubscription: 'azure-subscription'
                    azureResourceGroup: 'myapp-rg'
                    kubernetesCluster: 'myapp-aks'
                    command: 'upgrade'
                    chartType: 'FilePath'
                    chartPath: '$(Pipeline.Workspace)/drop/helm/myapp'
                    releaseName: 'myapp'
                    namespace: 'staging'
                    overrideFiles: |
                      helm/myapp/values-staging.yaml
                    overrides: |
                      image.tag=$(tag)
                    install: true
                    waitForExecution: true
                    arguments: '--timeout 10m'

  # ===== STAGE 3: INTEGRATION TESTS =====
  - stage: IntegrationTests
    displayName: 'Integration Tests'
    dependsOn: DeployStaging
    
    jobs:
      - job: RunTests
        steps:
          - script: |
              npm run test:integration
            env:
              API_URL: 'https://staging.company.com'

  # ===== STAGE 4: DEPLOY TO PRODUCTION =====
  - stage: DeployProduction
    displayName: 'Deploy to Production'
    dependsOn: IntegrationTests
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    
    jobs:
      - deployment: DeployToProd
        displayName: 'Deploy to Production'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'production'        # Requires manual approval!
        
        strategy:
          runOnce:
            deploy:
              steps:
                - task: HelmDeploy@0
                  inputs:
                    # ... production helm deployment
                    namespace: 'production'
                    overrideFiles: |
                      helm/myapp/values-production.yaml
```

### 1.3 Pipeline Templates - Reuse

```yaml
# templates/build-docker.yml
parameters:
  - name: imageRepository
    type: string
  - name: containerRegistry
    type: string
  - name: dockerfilePath
    type: string
    default: 'Dockerfile'
  - name: tag
    type: string
    default: '$(Build.BuildId)'

steps:
  - task: Docker@2
    displayName: 'Build and Push Docker image'
    inputs:
      command: buildAndPush
      containerRegistry: ${{ parameters.containerRegistry }}
      repository: ${{ parameters.imageRepository }}
      dockerfile: ${{ parameters.dockerfilePath }}
      tags: |
        ${{ parameters.tag }}
        latest

# Dùng template
# azure-pipelines.yml
steps:
  - template: templates/build-docker.yml
    parameters:
      imageRepository: myapp
      containerRegistry: myapp-acr-connection
      tag: $(Build.BuildId)
```

### 1.4 Variable Groups & Secrets

```bash
# Tạo variable group qua CLI
az devops variable-group create \
  --name production-variables \
  --variables \
    AZURE_SUBSCRIPTION_ID=xxx \
    RESOURCE_GROUP=myapp-rg

# Thêm secret variable (không hiện trong logs)
az devops variable-group variable create \
  --group-id GROUP_ID \
  --name DB_PASSWORD \
  --value "SuperSecret" \
  --secret true

# Variable group từ Key Vault (link secrets tự động)
# Trong Azure DevOps UI: Library → Variable Groups → Link Azure Key Vault secrets
```


## 2. Azure Monitor - Monitoring & Observability

### 2.1 Log Analytics Workspace

```bash
# Log Analytics Workspace = Centralized log aggregation
# Dùng KQL (Kusto Query Language) để query

# Tạo workspace
az monitor log-analytics workspace create \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --location southeastasia \
  --sku PerGB2018 \            # Pay per GB
  --retention-time 90          # 90 ngày retention

# Lấy workspace ID và key
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group myapp-rg \
  --workspace-name myapp-logs \
  --query primarySharedKey -o tsv)

# Connect AKS logs
az aks enable-addons \
  --addons monitoring \
  --name myapp-aks \
  --resource-group myapp-rg \
  --workspace-resource-id LOG_ANALYTICS_ID
```

### 2.2 KQL Queries

```kql
// ===== CONTAINER LOGS =====
// Xem logs từ AKS pod
ContainerLogV2
| where PodName startswith "myapp-"
| where TimeGenerated > ago(1h)
| project TimeGenerated, PodName, LogMessage
| order by TimeGenerated desc
| limit 100

// Error rate
ContainerLogV2
| where TimeGenerated > ago(24h)
| where LogMessage contains "ERROR"
| summarize ErrorCount = count() by bin(TimeGenerated, 1h), PodName
| render timechart

// ===== APPLICATION INSIGHTS =====
// Top failed requests
requests
| where timestamp > ago(24h)
| where success == false
| summarize count() by name, resultCode
| order by count_ desc

// P99 latency
requests
| where timestamp > ago(1h)
| summarize percentile(duration, 99) by bin(timestamp, 5m), name
| render timechart

// ===== AZURE ACTIVITY LOGS =====
// Ai đã xóa resource?
AzureActivity
| where OperationName contains "delete"
| where ActivityStatus == "Succeeded"
| project TimeGenerated, Caller, OperationName, ResourceGroup, Resource
| order by TimeGenerated desc

// Failed operations
AzureActivity
| where ActivityStatus == "Failed"
| where TimeGenerated > ago(7d)
| summarize count() by OperationName, ResourceGroup
| order by count_ desc
```

### 2.3 Alerts

```bash
# ===== METRIC ALERT =====
# Alert khi CPU > 80% trên App Service

az monitor metrics alert create \
  --name "high-cpu-alert" \
  --resource-group myapp-rg \
  --scopes /subscriptions/SUB/resourceGroups/myapp-rg/providers/Microsoft.Web/serverfarms/myapp-asp \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/SUB/resourceGroups/myapp-rg/providers/microsoft.insights/actionGroups/myapp-alerts \
  --severity 2 \
  --description "App Service CPU > 80%"

# ===== LOG ALERT =====
# Alert khi error count > threshold

az monitor scheduled-query create \
  --name "error-rate-alert" \
  --resource-group myapp-rg \
  --scopes LOG_ANALYTICS_ID \
  --condition "count > 10" \
  --condition-query "ContainerLogV2 | where LogMessage contains 'ERROR' | summarize count()" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 1 \
  --action-groups myapp-alerts

# ===== ACTION GROUP (Alert notifications) =====
az monitor action-group create \
  --name myapp-alerts \
  --resource-group myapp-rg \
  --short-name myapp \
  --action email myapp-team admin@company.com \
  --action webhook myapp-slack https://hooks.slack.com/services/XXX
```

### 2.4 Application Insights

```bash
# Application Insights = APM cho applications

az monitor app-insights component create \
  --app myapp-insights \
  --location southeastasia \
  --resource-group myapp-rg \
  --application-type web \
  --workspace LOG_ANALYTICS_ID

INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app myapp-insights \
  --resource-group myapp-rg \
  --query instrumentationKey -o tsv)

# Node.js integration
# npm install @azure/monitor-opentelemetry-exporter
```

```javascript
// app.js
const { useAzureMonitor } = require("@azure/monitor-opentelemetry");

useAzureMonitor({
  azureMonitorExporterOptions: {
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  },
});

// Tự động track:
// - HTTP requests (incoming và outgoing)
// - Dependencies (DB, Redis, external APIs)
// - Exceptions
// - Custom events và metrics
```


## 3. Infrastructure as Code trên Azure

### 3.1 Azure Bicep

```bicep
// main.bicep - Azure's native IaC language (thay ARM templates)

// Parameters
param location string = resourceGroup().location
param environment string = 'production'
param appName string

// Variables
var namePrefix = '${appName}-${environment}'
var tags = {
  Environment: environment
  Project: appName
  ManagedBy: 'Bicep'
}

// ===== VIRTUAL NETWORK =====
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'db-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'postgres-delegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

// ===== APP SERVICE PLAN =====
resource asp 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-${namePrefix}'
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: environment == 'production' ? 'P2v3' : 'B1'
    capacity: environment == 'production' ? 3 : 1
  }
  properties: {
    reserved: true   // Linux
  }
}

// ===== WEB APP =====
resource webapp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-${namePrefix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'   // Managed Identity
  }
  properties: {
    serverFarmId: asp.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: environment
        }
        {
          name: 'DB_HOST'
          value: postgres.properties.fullyQualifiedDomainName
        }
        // Dùng Key Vault reference cho secrets
        {
          name: 'DB_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/db-password/)'
        }
      ]
    }
  }
}

// ===== KEY VAULT =====
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${namePrefix}-001'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true   // Dùng RBAC thay Access Policies
  }
}

// Grant Web App access to Key Vault
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webapp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'    // Key Vault Secrets User role ID
    )
    principalId: webapp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ===== POSTGRESQL =====
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: 'psql-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: environment == 'production' ? 'Standard_D4s_v3' : 'Standard_B2s'
    tier: environment == 'production' ? 'GeneralPurpose' : 'Burstable'
  }
  properties: {
    administratorLogin: 'pgadmin'
    administratorLoginPassword: 'TempPass123!'  // Change this!
    version: '15'
    storage: {
      storageSizeGB: environment == 'production' ? 128 : 32
    }
    backup: {
      backupRetentionDays: environment == 'production' ? 30 : 7
      geoRedundantBackup: environment == 'production' ? 'Enabled' : 'Disabled'
    }
    highAvailability: {
      mode: environment == 'production' ? 'ZoneRedundant' : 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: vnet.properties.subnets[2].id
    }
  }
}

// ===== OUTPUTS =====
output webAppUrl string = 'https://${webapp.properties.defaultHostName}'
output postgresHost string = postgres.properties.fullyQualifiedDomainName
output keyVaultUri string = keyVault.properties.vaultUri
output webAppPrincipalId string = webapp.identity.principalId
```

```bash
# Bicep commands
# Cài Bicep CLI
az bicep install

# Validate
az bicep build --file main.bicep          # Compile to ARM JSON
az deployment group validate \
  --resource-group myapp-rg \
  --template-file main.bicep \
  --parameters appName=myapp environment=production

# Deploy
az deployment group create \
  --resource-group myapp-rg \
  --template-file main.bicep \
  --parameters appName=myapp environment=production \
  --name deployment-$(date +%Y%m%d-%H%M%S)

# What-if (like terraform plan)
az deployment group what-if \
  --resource-group myapp-rg \
  --template-file main.bicep \
  --parameters appName=myapp environment=production
```

### 3.2 Terraform trên Azure

```hcl
# main.tf - Terraform cho Azure

terraform {
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
  
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatecompany001"
    container_name       = "tfstate"
    key                  = "production/myapp.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  
  # Authenticate với Managed Identity trong CI/CD (Azure DevOps + Service Connection)
  # Hoặc qua environment variables:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}

# Data
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# App Service
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.environment == "production" ? "P2v3" : "B1"
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  
  identity {
    type = "SystemAssigned"
  }
  
  site_config {
    application_stack {
      node_version = "20-lts"
    }
    http2_enabled    = true
    minimum_tls_version = "1.2"
  }
  
  app_settings = {
    "NODE_ENV"    = var.environment
    "DB_HOST"     = azurerm_postgresql_flexible_server.main.fqdn
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_password.id})"
  }
  
  tags = local.common_tags
}

# Grant Web App access to Key Vault
resource "azurerm_role_assignment" "webapp_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# PostgreSQL
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${local.name_prefix}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  administrator_login    = "pgadmin"
  administrator_password = var.db_password
  
  storage_mb = var.environment == "production" ? 131072 : 32768  # 128GB : 32GB
  
  sku_name = var.environment == "production" ? "GP_Standard_D4s_v3" : "B_Standard_B2s"
  
  high_availability {
    mode = var.environment == "production" ? "ZoneRedundant" : "Disabled"
  }
  
  backup_retention_days = var.environment == "production" ? 30 : 7
  
  tags = local.common_tags
  
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [administrator_password]
  }
}
```
