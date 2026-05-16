# ☁️ AZURE TOÀN TẬP - PHẦN 5: REAL-WORLD SCENARIOS, BEST PRACTICES & CHEAT SHEET

---

## 1. Real-World: Microservices trên AKS

### 1.1 Architecture

```
Internet → Azure Front Door (WAF, CDN, SSL) 
         → AKS Ingress Controller (NGINX) 
         → Services trong K8s cluster:
           - frontend (Node.js)
           - api-gateway (Go)
           - user-service (Python)
           - order-service (.NET)
           - payment-service (Java)
         → Azure Cache for Redis (session, cache)
         → Azure PostgreSQL (main DB)
         → Azure Service Bus (async messaging)
         → Azure Blob Storage (files, media)
```

### 1.2 Setup Script Tự Động

```bash
#!/bin/bash
# setup-azure-infra.sh - Complete setup script

set -euo pipefail

# Variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-myapp-prod"
LOCATION="southeastasia"
APP_NAME="myapp"
ENVIRONMENT="production"
AKS_CLUSTER="aks-myapp-prod"
ACR_NAME="myappreg"
POSTGRES_SERVER="psql-myapp-prod"
REDIS_CACHE="redis-myapp-prod"
KEY_VAULT="kv-myapp-prod-001"

echo "=== Setting up Azure Infrastructure ==="

# Login và set subscription
az account set --subscription $SUBSCRIPTION_ID

# Resource Group
echo "Creating Resource Group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags Environment=$ENVIRONMENT Project=$APP_NAME

# VNet
echo "Creating VNet..."
az network vnet create \
  --name "vnet-${APP_NAME}-${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.0.0/8

# Subnets
for subnet in "aks-subnet:10.1.0.0/16" "db-subnet:10.2.0.0/24" "pe-subnet:10.3.0.0/24"; do
  name="${subnet%%:*}"
  cidr="${subnet##*:}"
  az network vnet subnet create \
    --name $name \
    --resource-group $RESOURCE_GROUP \
    --vnet-name "vnet-${APP_NAME}-${ENVIRONMENT}" \
    --address-prefix $cidr
done

# ACR
echo "Creating Container Registry..."
az acr create \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku Premium \
  --admin-enabled false

# AKS
echo "Creating AKS Cluster (this takes 5-10 minutes)..."
az aks create \
  --name $AKS_CLUSTER \
  --resource-group $RESOURCE_GROUP \
  --kubernetes-version 1.29.2 \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 20 \
  --network-plugin azure \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --attach-acr $ACR_NAME \
  --enable-addons monitoring \
  --zones 1 2 3 \
  --tier standard

# Key Vault
echo "Creating Key Vault..."
az keyvault create \
  --name $KEY_VAULT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true \
  --soft-delete-retention-days 90 \
  --enable-purge-protection true

# PostgreSQL
echo "Creating PostgreSQL..."
az postgres flexible-server create \
  --name $POSTGRES_SERVER \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user pgadmin \
  --admin-password "$(openssl rand -base64 32)" \  # Random secure password
  --sku-name Standard_D4s_v3 \
  --tier GeneralPurpose \
  --version 15 \
  --high-availability ZoneRedundant \
  --backup-retention 30 \
  --geo-redundant-backup Enabled

# Save password to Key Vault
DB_PASSWORD=$(openssl rand -base64 32)
az postgres flexible-server update \
  --name $POSTGRES_SERVER \
  --resource-group $RESOURCE_GROUP \
  --admin-password $DB_PASSWORD

az keyvault secret set \
  --vault-name $KEY_VAULT \
  --name postgres-password \
  --value $DB_PASSWORD

# Redis
echo "Creating Redis Cache..."
az redis create \
  --name $REDIS_CACHE \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Premium \
  --vm-size P1 \
  --enable-non-ssl-port false

# Get kubectl credentials
az aks get-credentials \
  --name $AKS_CLUSTER \
  --resource-group $RESOURCE_GROUP

echo "=== Infrastructure Setup Complete ==="
echo "AKS: $AKS_CLUSTER"
echo "ACR: ${ACR_NAME}.azurecr.io"
echo "PostgreSQL: ${POSTGRES_SERVER}.postgres.database.azure.com"
echo "Redis: ${REDIS_CACHE}.redis.cache.windows.net"
echo "Key Vault: ${KEY_VAULT}.vault.azure.net"
```

---

## 2. CI/CD End-to-End: GitHub Actions → Azure

```yaml
# .github/workflows/deploy-azure.yml

name: Deploy to Azure

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [staging, production]

permissions:
  id-token: write      # OIDC
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.image.outputs.tag }}
      
    steps:
      - uses: actions/checkout@v4
      
      # OIDC auth với Azure (không cần credentials!)
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          
      - name: Set image tag
        id: image
        run: echo "tag=${{ github.sha }}" >> $GITHUB_OUTPUT
        
      - name: Build and Push to ACR
        run: |
          az acr build \
            --registry myappreg \
            --image myapp:${{ steps.image.outputs.tag }} \
            --image myapp:latest \
            --file Dockerfile \
            .

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    if: github.ref == 'refs/heads/main' || inputs.environment == 'staging'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          
      - name: Get AKS credentials
        run: |
          az aks get-credentials \
            --name aks-myapp-staging \
            --resource-group rg-myapp-staging \
            --overwrite-existing
            
      - name: Deploy to Staging
        run: |
          helm upgrade --install myapp ./helm/myapp \
            -n staging \
            -f helm/myapp/values-staging.yaml \
            --set image.registry=myappreg.azurecr.io \
            --set image.repository=myapp \
            --set image.tag=${{ needs.build.outputs.image_tag }} \
            --wait \
            --timeout 10m

  deploy-production:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    environment: production     # Requires manual approval!
    if: inputs.environment == 'production'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          
      - name: Get AKS credentials
        run: |
          az aks get-credentials \
            --name aks-myapp-prod \
            --resource-group rg-myapp-prod \
            --overwrite-existing
            
      - name: Deploy to Production
        run: |
          helm upgrade --install myapp ./helm/myapp \
            -n production \
            -f helm/myapp/values-production.yaml \
            --set image.registry=myappreg.azurecr.io \
            --set image.repository=myapp \
            --set image.tag=${{ needs.build.outputs.image_tag }} \
            --wait \
            --timeout 15m
            
      - name: Verify deployment
        run: |
          kubectl rollout status deployment/myapp -n production
          kubectl get pods -n production -l app=myapp
```

---

## 3. Azure Best Practices

### 3.1 Security Checklist

```
☐ IAM:
  ☐ Sử dụng Managed Identity thay Service Principal
  ☐ Principle of Least Privilege cho tất cả roles
  ☐ Disable unused Admin accounts
  ☐ MFA bắt buộc cho tất cả users

☐ Network:
  ☐ Tất cả resources trong VNet (không phải public)
  ☐ Private Endpoint cho PaaS services
  ☐ NSG cho mỗi subnet
  ☐ Azure Firewall cho outbound control
  ☐ DDoS Protection Standard cho production

☐ Data:
  ☐ Encryption at rest (service-managed hoặc CMK)
  ☐ Encryption in transit (TLS 1.2+)
  ☐ Key Vault cho tất cả secrets, keys, certificates
  ☐ Soft delete và purge protection trên Key Vault
  ☐ Geo-redundant storage cho production data

☐ Monitoring:
  ☐ Azure Monitor + Log Analytics
  ☐ Security Center alerts bật
  ☐ Defender for Cloud Plans bật
  ☐ Activity log retention ≥ 90 days
  ☐ Budget alerts

☐ Compliance:
  ☐ Azure Policy assignments
  ☐ Resource tagging enforced
  ☐ Backup policy enforced
  ☐ Regular access reviews
```

### 3.2 Well-Architected Framework

```
5 Pillars của Azure Well-Architected Framework:

1. RELIABILITY (Độ tin cậy)
   - Availability Zones cho production
   - Multi-region cho critical apps
   - Auto-scaling
   - Health probes và circuit breakers
   - Backup và restore tested

2. SECURITY (Bảo mật)
   - Zero Trust Network
   - Managed Identity everywhere
   - Key Vault cho secrets
   - Microsoft Defender for Cloud
   - Regular patching

3. COST OPTIMIZATION (Tối ưu chi phí)
   - Reserved Instances cho stable workloads
   - Spot Instances cho batch
   - Auto-scaling (không over-provision)
   - Resource tagging cho cost allocation
   - Azure Advisor recommendations

4. OPERATIONAL EXCELLENCE (Vận hành tốt)
   - Infrastructure as Code (Bicep/Terraform)
   - CI/CD pipelines
   - Monitoring và alerting
   - Runbooks cho common operations
   - Chaos Engineering

5. PERFORMANCE EFFICIENCY (Hiệu suất)
   - Right-sizing (không dùng VM quá lớn)
   - Caching (Redis, CDN)
   - Content Delivery Network
   - Database indexing và tuning
   - Performance testing
```

---

## 4. Azure CLI Cheat Sheet

```bash
# ===== AUTHENTICATION =====
az login
az login --service-principal -u CLIENT_ID -p SECRET --tenant TENANT_ID
az account list
az account set --subscription "Name or ID"
az account show

# ===== RESOURCE GROUPS =====
az group create --name NAME --location LOCATION
az group list --output table
az group show --name NAME
az group delete --name NAME --yes

# ===== VMs =====
az vm list --output table
az vm create --resource-group RG --name NAME --image Ubuntu2204 --size SIZE
az vm start/stop/restart --resource-group RG --name NAME
az vm ssh --resource-group RG --name NAME
az vm run-command invoke --resource-group RG --name NAME \
  --command-id RunShellScript --scripts "echo hello"

# ===== APP SERVICE =====
az webapp list --output table
az webapp create --resource-group RG --plan PLAN --name NAME --runtime RUNTIME
az webapp deploy --resource-group RG --name NAME --src-path app.zip
az webapp config appsettings set --resource-group RG --name NAME \
  --settings KEY=VALUE
az webapp log tail --resource-group RG --name NAME
az webapp deployment slot create --resource-group RG --name NAME --slot staging
az webapp deployment slot swap --resource-group RG --name NAME \
  --slot staging --target-slot production

# ===== AKS =====
az aks list --output table
az aks create --resource-group RG --name NAME --node-count 3
az aks get-credentials --resource-group RG --name NAME
az aks scale --resource-group RG --name NAME --node-count 5
az aks upgrade --resource-group RG --name NAME --kubernetes-version VERSION
az aks nodepool list --resource-group RG --cluster-name NAME

# ===== ACR =====
az acr list --output table
az acr create --resource-group RG --name NAME --sku Basic
az acr login --name NAME
az acr build --registry NAME --image IMAGE:TAG .
az acr repository list --name NAME
az acr repository show-tags --name NAME --repository REPO

# ===== KEY VAULT =====
az keyvault list --output table
az keyvault create --name NAME --resource-group RG --location LOCATION
az keyvault secret set --vault-name NAME --name KEY --value VALUE
az keyvault secret show --vault-name NAME --name KEY --query value -o tsv
az keyvault secret list --vault-name NAME

# ===== DATABASES =====
az postgres flexible-server list --output table
az postgres flexible-server create --resource-group RG --name NAME
az postgres flexible-server connect --resource-group RG --name NAME \
  --admin-user USER --admin-password PASS --database-name DB

# ===== NETWORKING =====
az network vnet list --output table
az network vnet create --resource-group RG --name NAME --address-prefix CIDR
az network vnet subnet create --resource-group RG --vnet-name VNET \
  --name NAME --address-prefix CIDR
az network nsg create --resource-group RG --name NAME
az network nsg rule create --resource-group RG --nsg-name NSG \
  --name NAME --priority PRIORITY --direction Inbound --protocol TCP \
  --destination-port-ranges PORT --access Allow

# ===== MONITORING =====
az monitor metrics list --resource RESOURCE_ID --metric "Percentage CPU"
az monitor alert list --resource-group RG
az monitor log-analytics workspace list --output table
az monitor diagnostic-settings create --name NAME --resource RESOURCE_ID \
  --workspace WORKSPACE_ID --logs '[{category:AuditLogs,enabled:true}]'

# ===== COST =====
az consumption usage list --start-date DATE --end-date DATE
az consumption budget list
az advisor recommendation list --category Cost

# ===== USEFUL TIPS =====
# Output formats
az command --output table/json/yaml/tsv/none

# JMESPath queries
az vm list --query "[].{Name:name, RG:resourceGroup, Size:hardwareProfile.vmSize}"

# Format output
az account list --query "[].{Name:name, ID:id}" --output table

# Interactive
az interactive

# Update CLI
az upgrade

# Help
az vm --help
az vm create --help
```

---

## 5. Azure vs AWS vs GCP

| Service | Azure | AWS | GCP |
|---------|-------|-----|-----|
| Compute | Virtual Machines | EC2 | Compute Engine |
| K8s | AKS | EKS | GKE |
| Serverless | Azure Functions | Lambda | Cloud Functions |
| Container | ACI | Fargate | Cloud Run |
| Registry | ACR | ECR | Artifact Registry |
| Object Storage | Blob Storage | S3 | Cloud Storage |
| CDN | Azure CDN/Front Door | CloudFront | Cloud CDN |
| DNS | Azure DNS | Route 53 | Cloud DNS |
| LB | Application Gateway | ALB | Cloud Load Balancing |
| SQL DB | Azure SQL | RDS | Cloud SQL |
| NoSQL | Cosmos DB | DynamoDB | Firestore |
| Cache | Azure Cache for Redis | ElastiCache | Memorystore |
| Message Queue | Service Bus | SQS/SNS | Pub/Sub |
| Identity | Azure AD | IAM | Cloud IAM |
| Secrets | Key Vault | Secrets Manager | Secret Manager |
| CI/CD | Azure DevOps | CodePipeline | Cloud Build |
| Monitoring | Azure Monitor | CloudWatch | Cloud Monitoring |
| IaC | Bicep/Terraform | CloudFormation/Terraform | Deployment Manager |

**Chọn Azure khi:**
- Microsoft/Windows ecosystem (Office 365, Active Directory)
- Hybrid cloud với on-premise
- .NET/SQL Server workloads
- Enterprise compliance requirements
- Microsoft partnership/licenses

**Chọn AWS khi:**
- Largest ecosystem và service selection
- Khởi đầu cloud journey
- Global scale workloads
- Community và third-party support lớn nhất

**Chọn GCP khi:**
- Data analytics và ML/AI (BigQuery, Vertex AI)
- Kubernetes (GKE là K8s thành thục nhất)
- Workloads cần Google's network infrastructure
- Open source friendly

---

> **Hoàn thành Azure Toàn Tập! Toàn bộ knowledge base DevOps đã hoàn thiện!**

## 🎉 Tổng Kết Toàn Bộ Knowledge Base

```
Đã hoàn thiện:
✅ Linux    (5 phần) - Fundamentals → Advanced Administration
✅ Docker   (5 phần) - Containers, Compose, Production
✅ Git      (5 phần) - Workflows, CI/CD, Best Practices
✅ Network  (5 phần) - Protocols, Security, K8s Networking
✅ Ansible  (5 phần) - Automation, Roles, CI/CD Integration
✅ Terraform (5 phần) - IaC, Modules, AWS Complete
✅ Kubernetes (5 phần) - Architecture, Production, Helm, ArgoCD
✅ Azure    (5 phần) - Cloud Services, DevOps, Security
```
