# ☁️ AZURE TOÀN TẬP - PHẦN 2: APP SERVICES, CONTAINERS & DATABASES

---

## 1. Azure App Service - PaaS Web Hosting

### 1.1 App Service Là Gì?

```
App Service = Managed platform để host web apps
- Không cần quản lý server, OS, runtime
- Tự động scaling, load balancing
- Tích hợp CI/CD
- SSL/TLS tự động

Hỗ trợ: .NET, Node.js, Python, Java, PHP, Ruby, Go, Docker
```

### 1.2 App Service Plan

```bash
# App Service Plan = Infrastructure underlying App Services
# Pricing Tiers:
# Free (F1):     1 GB, shared, 60 min/day CPU
# Shared (D1):   1 GB, shared
# Basic (B1-B3): Dedicated, manual scale
# Standard (S1-S3): Auto-scale, staging slots, backup
# Premium (P0v3-P3v3): Enhanced performance, VNet integration
# Isolated (I1v2-I6v2): Dedicated VNet, highest isolation

# Tạo App Service Plan
az appservice plan create \
  --name myapp-asp \
  --resource-group myapp-rg \
  --sku P1v3 \
  --is-linux \                # Linux plan (Windows cũng có)
  --number-of-workers 2 \
  --location southeastasia

# Liệt kê plans
az appservice plan list --output table

# Scale out (thêm instances)
az appservice plan update \
  --name myapp-asp \
  --resource-group myapp-rg \
  --number-of-workers 5

# Scale up (change SKU)
az appservice plan update \
  --name myapp-asp \
  --resource-group myapp-rg \
  --sku P2v3
```

### 1.3 Web App

```bash
# Tạo Web App
az webapp create \
  --name myapp-web \
  --resource-group myapp-rg \
  --plan myapp-asp \
  --runtime "NODE:20-lts"      # Hoặc PYTHON:3.11, DOTNETCORE:8.0, JAVA:17

# Các runtimes phổ biến:
az webapp list-runtimes --os-type linux

# ===== DEPLOY =====

# Deploy từ Git
az webapp deployment source config \
  --name myapp-web \
  --resource-group myapp-rg \
  --repo-url https://github.com/company/myapp.git \
  --branch main \
  --manual-integration

# Deploy từ local zip
zip -r app.zip . -x ".git/*" "node_modules/*"
az webapp deploy \
  --name myapp-web \
  --resource-group myapp-rg \
  --src-path app.zip

# Deploy Docker container
az webapp create \
  --name myapp-container \
  --resource-group myapp-rg \
  --plan myapp-asp \
  --deployment-container-image-name myregistry.azurecr.io/myapp:v1.0

# ===== CẤUHÌNH =====

# App settings (environment variables)
az webapp config appsettings set \
  --name myapp-web \
  --resource-group myapp-rg \
  --settings \
    DATABASE_URL="postgresql://..." \
    REDIS_URL="redis://..." \
    NODE_ENV="production"

# Đọc từ Key Vault (reference)
az webapp config appsettings set \
  --name myapp-web \
  --resource-group myapp-rg \
  --settings \
    DB_PASSWORD="@Microsoft.KeyVault(SecretUri=https://myapp-kv.vault.azure.net/secrets/db-password/)"

# Connection strings
az webapp config connection-string set \
  --name myapp-web \
  --resource-group myapp-rg \
  --connection-string-type PostgreSQL \
  --settings DefaultConnection="Server=myserver.postgres.database.azure.com;..."

# ===== CUSTOM DOMAIN & SSL =====
az webapp config hostname add \
  --hostname app.company.com \
  --webapp-name myapp-web \
  --resource-group myapp-rg

# Managed certificate (free!)
az webapp config ssl create \
  --hostname app.company.com \
  --name myapp-web \
  --resource-group myapp-rg

# Bind SSL
az webapp config ssl bind \
  --ssl-type SNI \
  --certificate-thumbprint THUMBPRINT \
  --name myapp-web \
  --resource-group myapp-rg

# Force HTTPS
az webapp update \
  --name myapp-web \
  --resource-group myapp-rg \
  --https-only true
```

### 1.4 Deployment Slots - Zero-Downtime Deploy

```bash
# Deployment Slots = Staging environments (Standard+ plans)
# Tính năng key: Swap slots (instant, zero-downtime)

# Tạo staging slot
az webapp deployment slot create \
  --name myapp-web \
  --resource-group myapp-rg \
  --slot staging

# Deploy vào staging
az webapp deploy \
  --name myapp-web \
  --resource-group myapp-rg \
  --slot staging \
  --src-path app.zip

# Test staging: https://myapp-web-staging.azurewebsites.net

# Swap staging → production (instant!)
az webapp deployment slot swap \
  --name myapp-web \
  --resource-group myapp-rg \
  --slot staging \
  --target-slot production

# Rollback: Swap lại
az webapp deployment slot swap \
  --name myapp-web \
  --resource-group myapp-rg \
  --slot production \
  --target-slot staging

# Auto-swap: Tự động swap sau CI/CD
az webapp deployment slot auto-swap \
  --name myapp-web \
  --resource-group myapp-rg \
  --slot staging \
  --auto-swap-slot production
```

### 1.5 Auto-scaling App Service

```bash
# Autoscale với App Service (Standard+)
az monitor autoscale create \
  --resource-group myapp-rg \
  --resource myapp-asp \
  --resource-type Microsoft.Web/serverFarms \
  --name myapp-autoscale \
  --min-count 2 \
  --max-count 20 \
  --count 2

# CPU-based scale out
az monitor autoscale rule create \
  --resource-group myapp-rg \
  --autoscale-name myapp-autoscale \
  --condition "CpuPercentage > 70 avg 5m" \
  --scale out 3

# Schedule-based (business hours)
az monitor autoscale profile create \
  --resource-group myapp-rg \
  --autoscale-name myapp-autoscale \
  --name "Business Hours" \
  --timezone "SE Asia Standard Time" \
  --start "0 8 * * 1-5" \    # 8 AM weekdays
  --end "0 18 * * 1-5" \     # 6 PM weekdays
  --count 5 \
  --min-count 3 \
  --max-count 20
```

---

## 2. Azure Container Services

### 2.1 Azure Container Registry (ACR)

```bash
# ACR = Private Docker registry trên Azure

# Tạo ACR
az acr create \
  --name myappregistry \        # Globally unique
  --resource-group myapp-rg \
  --sku Premium \              # Basic, Standard, Premium (geo-replication)
  --admin-enabled false \      # Dùng service principal/managed identity thay admin
  --location southeastasia

# Login
az acr login --name myappregistry

# Build và push image
az acr build \
  --registry myappregistry \
  --image myapp:v1.0 \
  --image myapp:latest \
  .                           # Build context (Dockerfile trong ./.)

# Hoặc local build + push
docker build -t myappregistry.azurecr.io/myapp:v1.0 .
docker push myappregistry.azurecr.io/myapp:v1.0

# Xem images
az acr repository list --name myappregistry
az acr repository show-tags --name myappregistry --repository myapp

# Grant pull access
az role assignment create \
  --assignee SERVICE_PRINCIPAL_ID \
  --role AcrPull \
  --scope $(az acr show --name myappregistry --query id -o tsv)

# Geo-replication (Premium tier)
az acr replication create \
  --name myappregistry \
  --resource-group myapp-rg \
  --location eastasia

# Vulnerability scanning
az acr check-health --name myappregistry
az security alert list          # Security Center alerts

# Purge old images
az acr run \
  --registry myappregistry \
  --cmd "acr purge --filter 'myapp:.*' --ago 30d --keep 5 --dry-run" \
  /dev/null
```

### 2.2 Azure Container Instances (ACI)

```bash
# ACI = Serverless containers (nhanh, không cần manage K8s/VMs)
# Dùng cho: Batch jobs, event processing, dev/test, quick deployments

# Chạy container
az container create \
  --resource-group myapp-rg \
  --name myapp-job \
  --image myappregistry.azurecr.io/myapp:v1.0 \
  --registry-login-server myappregistry.azurecr.io \
  --registry-username SP_ID \
  --registry-password SP_SECRET \
  --cpu 2 \
  --memory 4 \
  --restart-policy OnFailure \   # Always, OnFailure, Never
  --environment-variables \
    APP_ENV=production \
    LOG_LEVEL=info \
  --secure-environment-variables \
    DB_PASSWORD=secret \
  --os-type Linux \
  --location southeastasia

# Xem logs
az container logs --name myapp-job --resource-group myapp-rg
az container logs --name myapp-job --resource-group myapp-rg --follow

# Xem status
az container show --name myapp-job --resource-group myapp-rg

# Exec vào container
az container exec \
  --name myapp-job \
  --resource-group myapp-rg \
  --exec-command "/bin/bash"

# ===== MULTI-CONTAINER (YAML) =====
cat > aci-group.yaml << 'EOF'
apiVersion: '2021-07-01'
location: southeastasia
name: myapp-group
properties:
  containers:
    - name: myapp
      properties:
        image: myappregistry.azurecr.io/myapp:v1.0
        resources:
          requests:
            cpu: 1
            memoryInGB: 2
        ports:
          - port: 8080
        environmentVariables:
          - name: APP_ENV
            value: production
          - name: DB_PASSWORD
            secureValue: secret
            
    - name: nginx
      properties:
        image: nginx:alpine
        resources:
          requests:
            cpu: 0.5
            memoryInGB: 0.5
        ports:
          - port: 80
          
  imageRegistryCredentials:
    - server: myappregistry.azurecr.io
      username: SP_ID
      password: SP_SECRET
      
  ipAddress:
    type: Public
    ports:
      - port: 80
        protocol: TCP
        
  osType: Linux
  restartPolicy: OnFailure
EOF

az container create --resource-group myapp-rg --file aci-group.yaml
```

### 2.3 Azure Kubernetes Service (AKS)

```bash
# AKS = Managed Kubernetes trên Azure
# Microsoft quản lý control plane (free!), bạn quản lý worker nodes

# ===== TẠO AKS CLUSTER =====
az aks create \
  --resource-group myapp-rg \
  --name myapp-aks \
  --kubernetes-version 1.29.2 \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --node-osdisk-size 128 \
  --vnet-subnet-id /subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/myapp-vnet/subnets/aks-subnet \
  --enable-managed-identity \
  --assign-identity IDENTITY_ID \          # User-assigned managed identity
  --enable-workload-identity \             # Workload Identity (thay Pod Identity)
  --enable-oidc-issuer \
  --enable-azure-rbac \                    # Azure RBAC cho K8s
  --attach-acr myappregistry \             # Tự động gán AcrPull role
  --network-plugin azure \                 # Azure CNI (thay Kubenet)
  --network-plugin-mode overlay \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 20 \
  --enable-addons monitoring,azure-policy \
  --workspace-resource-id LOG_ANALYTICS_ID \
  --zones 1 2 3 \                          # Zone redundant
  --tier standard \                        # free, standard, premium
  --generate-ssh-keys

# ===== NODE POOLS =====
# Default node pool (system pool - chạy system Pods)
# Thêm user node pool cho app workloads

az aks nodepool add \
  --resource-group myapp-rg \
  --cluster-name myapp-aks \
  --name userpool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 20 \
  --node-taints app=true:NoSchedule \     # Taint để tách system/app Pods
  --zones 1 2 3 \
  --mode User

# GPU node pool
az aks nodepool add \
  --resource-group myapp-rg \
  --cluster-name myapp-aks \
  --name gpupool \
  --node-count 1 \
  --node-vm-size Standard_NC4as_T4_v3 \  # NVIDIA T4 GPU
  --node-taints sku=gpu:NoSchedule

# ===== KUBECTL ACCESS =====
az aks get-credentials \
  --resource-group myapp-rg \
  --name myapp-aks \
  --overwrite-existing

kubectl get nodes
kubectl get pods --all-namespaces

# ===== UPGRADE =====
# Xem available upgrades
az aks get-upgrades --resource-group myapp-rg --name myapp-aks

# Upgrade cluster
az aks upgrade \
  --resource-group myapp-rg \
  --name myapp-aks \
  --kubernetes-version 1.30.0 \
  --yes

# Upgrade node pool only
az aks nodepool upgrade \
  --resource-group myapp-rg \
  --cluster-name myapp-aks \
  --name userpool \
  --kubernetes-version 1.30.0

# ===== AKS với AZURE WORKLOAD IDENTITY =====
# Workload Identity cho phép Pods dùng Managed Identity
# Thay thế pod-identity (deprecated)

# Tạo managed identity cho app
az identity create --name myapp-wi --resource-group myapp-rg

CLIENT_ID=$(az identity show --name myapp-wi --resource-group myapp-rg --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show --name myapp-wi --resource-group myapp-rg --query principalId -o tsv)

# Grant Key Vault access
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope KEY_VAULT_ID

# Tạo federated credential
OIDC_ISSUER=$(az aks show --name myapp-aks --resource-group myapp-rg --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --name myapp-federated \
  --identity-name myapp-wi \
  --resource-group myapp-rg \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:production:myapp \  # K8s ServiceAccount
  --audiences api://AzureADTokenExchange

# K8s Service Account annotated với managed identity
kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: production
  annotations:
    azure.workload.identity/client-id: "$CLIENT_ID"
  labels:
    azure.workload.identity/use: "true"
EOF

# Pod với workload identity
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  namespace: production
  labels:
    azure.workload.identity/use: "true"  # Enable workload identity
spec:
  serviceAccountName: myapp
  containers:
    - name: myapp
      image: myappregistry.azurecr.io/myapp:v1.0
      # Pod tự động nhận token để authenticate với Azure
      # Code dùng: DefaultAzureCredential() - sẽ tự tìm token
EOF
```

---

## 3. Azure Database Services

### 3.1 Azure Database for PostgreSQL

```bash
# Flexible Server (recommended) - Full control, HA, PITR
az postgres flexible-server create \
  --name myapp-postgres \
  --resource-group myapp-rg \
  --location southeastasia \
  --admin-user pgadmin \
  --admin-password "SuperSecret123!" \
  --sku-name Standard_D4s_v3 \     # 4 vCPUs, 16GB RAM
  --tier GeneralPurpose \
  --storage-size 128 \             # GB
  --version 15 \
  --high-availability ZoneRedundant \   # HA với standby
  --zone 1 \
  --standby-zone 2 \
  --geo-redundant-backup Enabled \
  --backup-retention 30 \
  --vnet myapp-vnet \
  --subnet db-subnet \
  --private-dns-zone myapp.postgres.database.azure.com

# Tạo database
az postgres flexible-server db create \
  --server-name myapp-postgres \
  --resource-group myapp-rg \
  --database-name myapp

# Cấu hình
az postgres flexible-server parameter set \
  --server-name myapp-postgres \
  --resource-group myapp-rg \
  --name shared_buffers \
  --value 4096  # 4GB (mỗi unit = 1MB)

az postgres flexible-server parameter set \
  --name log_min_duration_statement \
  --server-name myapp-postgres \
  --resource-group myapp-rg \
  --value 1000  # Log queries > 1 second

# Firewall (chỉ dùng nếu không có VNet integration)
az postgres flexible-server firewall-rule create \
  --name AllowAppServer \
  --resource-group myapp-rg \
  --server-name myapp-postgres \
  --start-ip-address 10.0.2.0 \
  --end-ip-address 10.0.2.255

# Connect
psql -h myapp-postgres.postgres.database.azure.com \
  -U pgadmin \
  -d myapp \
  --sslmode=require

# Point-in-time restore
az postgres flexible-server restore \
  --resource-group myapp-rg \
  --name myapp-postgres-restored \
  --source-server myapp-postgres \
  --restore-time "2024-01-15T08:00:00Z"
```

### 3.2 Azure SQL Database

```bash
# Azure SQL Database = Managed SQL Server (PaaS)

# SQL Server (logical server)
az sql server create \
  --name myapp-sql-server \
  --resource-group myapp-rg \
  --location southeastasia \
  --admin-user sqladmin \
  --admin-password "SqlSecret123!" \
  --enable-public-network false      # Private endpoint only

# Database
az sql db create \
  --resource-group myapp-rg \
  --server myapp-sql-server \
  --name myapp-db \
  --service-objective S3 \           # DTU model
  # --compute-model Serverless \     # Hoặc serverless (auto-pause!)
  # --edition GeneralPurpose \       # vCore model
  # --family Gen5 \
  # --capacity 4 \
  --backup-storage-redundancy Geo \
  --zone-redundant true

# Tiered pricing:
# DTU model: Basic, Standard (S0-S12), Premium (P1-P15)
# vCore model: General Purpose, Business Critical, Hyperscale
# Serverless: Auto-scale + auto-pause (tiết kiệm cho dev)

# Firewall rules
az sql server firewall-rule create \
  --resource-group myapp-rg \
  --server myapp-sql-server \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0          # 0.0.0.0-0.0.0.0 = Allow Azure services

# Active Geo-Replication (read replicas)
az sql db replica create \
  --resource-group myapp-rg \
  --server myapp-sql-server \
  --name myapp-db \
  --partner-server myapp-sql-dr \   # DR server
  --partner-resource-group dr-rg
```

### 3.3 Azure Cosmos DB

```bash
# Cosmos DB = Globally distributed, multi-model NoSQL
# APIs: SQL, MongoDB, Cassandra, Gremlin, Table

az cosmosdb create \
  --name myapp-cosmos \
  --resource-group myapp-rg \
  --locations regionName=southeastasia failoverPriority=0 \
  --locations regionName=eastasia failoverPriority=1 \   # Geo-replication
  --default-consistency-level Session \
  --kind GlobalDocumentDB \          # SQL API
  --enable-automatic-failover true \
  --enable-multiple-write-locations false

# Database và container
az cosmosdb sql database create \
  --account-name myapp-cosmos \
  --resource-group myapp-rg \
  --name myapp-db

az cosmosdb sql container create \
  --account-name myapp-cosmos \
  --resource-group myapp-rg \
  --database-name myapp-db \
  --name users \
  --partition-key-path "/userId" \   # Partition key quan trọng!
  --throughput 400                   # RU/s (Request Units)

# Autoscale throughput
az cosmosdb sql container throughput migrate \
  --account-name myapp-cosmos \
  --resource-group myapp-rg \
  --database-name myapp-db \
  --name users \
  --throughput-type autoscale

# MongoDB API example
az cosmosdb create \
  --name myapp-cosmos-mongo \
  --resource-group myapp-rg \
  --kind MongoDB \
  --capabilities EnableMongo \
  --server-version 6.0
```

### 3.4 Azure Cache for Redis

```bash
az redis create \
  --name myapp-redis \
  --resource-group myapp-rg \
  --location southeastasia \
  --sku Premium \              # Basic, Standard, Premium
  --vm-size P1 \               # Cache: 6GB
  --enable-non-ssl-port false \
  --minimum-tls-version 1.2 \
  --subnet-id SUBNET_ID \      # VNet integration (Premium)
  --replicas-per-master 1 \    # Replica (Premium)
  --zones 1 2                  # Zone redundant

# Connection string
az redis list-keys --name myapp-redis --resource-group myapp-rg

# Xem stats
az redis show --name myapp-redis --resource-group myapp-rg
```

---

## 4. Azure Storage

```bash
# Storage Account = Container cho Blobs, Files, Queues, Tables

az storage account create \
  --name myappstorage001 \     # 3-24 chars, lowercase, globally unique
  --resource-group myapp-rg \
  --location southeastasia \
  --sku Standard_LRS \         # LRS, ZRS, GRS, GZRS
  --kind StorageV2 \
  --enable-hierarchical-namespace false \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --https-only true \
  --default-action Deny \      # Deny public access
  --bypass AzureServices

# Blob container
az storage container create \
  --name uploads \
  --account-name myappstorage001 \
  --auth-mode login

# Upload file
az storage blob upload \
  --account-name myappstorage001 \
  --container-name uploads \
  --name myfile.pdf \
  --file ./myfile.pdf

# Generate SAS token (time-limited access)
az storage blob generate-sas \
  --account-name myappstorage001 \
  --container-name uploads \
  --name myfile.pdf \
  --permissions r \
  --expiry "2024-12-31T00:00:00Z" \
  --output tsv

# Static website hosting
az storage blob service-properties update \
  --account-name myappstorage001 \
  --static-website \
  --index-document index.html \
  --404-document error.html

# Lifecycle policy (auto-archive/delete)
az storage account management-policy create \
  --account-name myappstorage001 \
  --resource-group myapp-rg \
  --policy '{
    "rules": [{
      "name": "archiveRule",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["archive/"]
        },
        "actions": {
          "baseBlob": {
            "tierToCool": {"daysAfterModificationGreaterThan": 30},
            "tierToArchive": {"daysAfterModificationGreaterThan": 90},
            "delete": {"daysAfterModificationGreaterThan": 365}
          }
        }
      }
    }]
  }'
```

---

> **Tiếp theo: Phần 3** - Azure DevOps, Monitoring & Infrastructure as Code
