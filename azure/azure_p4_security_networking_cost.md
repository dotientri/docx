# ☁️ AZURE TOÀN TẬP - PHẦN 4: SECURITY, NETWORKING ADVANCED & COST

---

## 1. Azure Security Center & Defender

### 1.1 Microsoft Defender for Cloud

```bash
# Defender for Cloud = Unified security management + threat protection

# Bật Defender plans
az security pricing create \
  --name VirtualMachines \
  --tier standard             # Free hoặc Standard

az security pricing create --name StorageAccounts --tier standard
az security pricing create --name SqlServers --tier standard
az security pricing create --name Containers --tier standard

# Xem security score
az security secure-score-controls list
az security assessment list --resource-group myapp-rg

# Xem alerts
az security alert list
az security alert list --location southeastasia

# Security policy
az security policy assignment create \
  --name "Azure Security Benchmark" \
  --scope /subscriptions/SUB_ID \
  --policy-definition /providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8
```

### 1.2 Azure Policy

```bash
# Azure Policy = Enforcement rules cho resources

# Xem built-in policies
az policy definition list --query "[?policyType=='BuiltIn'].{name:name, displayName:displayName}" \
  --output table | grep -i "tag\|encryption\|https"

# Assign policy: Require tags
az policy assignment create \
  --name require-environment-tag \
  --display-name "Require Environment tag" \
  --scope /subscriptions/SUB_ID \
  --policy /providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025 \
  --params '{"tagName": {"value": "Environment"}}'

# ===== CUSTOM POLICY =====
cat > require-https.json << 'EOF'
{
  "properties": {
    "displayName": "Require HTTPS on App Service",
    "policyType": "Custom",
    "mode": "All",
    "description": "All App Services must use HTTPS",
    "policyRule": {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Web/sites"
          },
          {
            "field": "Microsoft.Web/sites/httpsOnly",
            "notEquals": true
          }
        ]
      },
      "then": {
        "effect": "Deny"
      }
    }
  }
}
EOF

az policy definition create \
  --name require-app-service-https \
  --display-name "Require HTTPS on App Service" \
  --rules @require-https.json

# Policy Initiative (group of policies)
az policy set-definition create \
  --name company-security-baseline \
  --display-name "Company Security Baseline" \
  --definitions '[
    "/providers/Microsoft.Authorization/policyDefinitions/...",
    "/providers/Microsoft.Authorization/policyDefinitions/..."
  ]'
```

### 1.3 Azure DDoS Protection

```bash
# DDoS Protection Standard = Advanced protection
# Basic: Tự động được bật cho tất cả Azure services
# Standard: L3/L4 + L7, $2,944/month per plan

# Tạo DDoS Protection Plan
az network ddos-protection create \
  --name myapp-ddos \
  --resource-group myapp-rg \
  --location southeastasia

# Gắn vào VNet
az network vnet update \
  --name myapp-vnet \
  --resource-group myapp-rg \
  --ddos-protection-plan myapp-ddos \
  --ddos-protection true
```

### 1.4 Azure Firewall

```bash
# Azure Firewall = Managed, cloud-native network security

# Tạo Firewall (cần subnet tên AzureFirewallSubnet)
az network vnet subnet create \
  --name AzureFirewallSubnet \     # Tên bắt buộc!
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --address-prefix 10.0.255.0/26  # /26 minimum

az network public-ip create \
  --name myapp-fw-pip \
  --resource-group myapp-rg \
  --sku Standard \
  --zone 1 2 3

az network firewall create \
  --name myapp-fw \
  --resource-group myapp-rg \
  --location southeastasia \
  --sku-tier Premium \           # Standard hoặc Premium (IDPS, TLS inspection)
  --threat-intel-mode Alert      # Alert hoặc Deny

az network firewall ip-config create \
  --firewall-name myapp-fw \
  --name fw-config \
  --resource-group myapp-rg \
  --public-ip-address myapp-fw-pip \
  --vnet-name myapp-vnet

# ===== FIREWALL RULES =====
# Application rules (FQDN-based)
az network firewall application-rule create \
  --collection-name allow-web \
  --firewall-name myapp-fw \
  --resource-group myapp-rg \
  --name allow-microsoft \
  --protocols Http=80 Https=443 \
  --source-addresses "10.0.2.0/24" \
  --target-fqdns "*.microsoft.com" "*.azure.com" \
  --action Allow \
  --priority 100

# Network rules (IP-based)
az network firewall network-rule create \
  --collection-name allow-dns \
  --firewall-name myapp-fw \
  --resource-group myapp-rg \
  --name allow-dns \
  --protocols UDP \
  --source-addresses "*" \
  --destination-addresses "8.8.8.8" "1.1.1.1" \
  --destination-ports 53 \
  --action Allow \
  --priority 200

# Route private traffic qua Firewall
az network route-table create \
  --name app-rt \
  --resource-group myapp-rg

FIREWALL_IP=$(az network firewall show \
  --name myapp-fw \
  --resource-group myapp-rg \
  --query "ipConfigurations[0].privateIPAddress" -o tsv)

az network route-table route create \
  --resource-group myapp-rg \
  --route-table-name app-rt \
  --name default-to-fw \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $FIREWALL_IP

az network vnet subnet update \
  --vnet-name myapp-vnet \
  --name app-subnet \
  --resource-group myapp-rg \
  --route-table app-rt
```

---

## 2. Advanced Networking

### 2.1 Private Endpoint & Private Link

```bash
# Private Endpoint = Private IP trong VNet cho Azure service
# Traffic đến Azure service đi qua private network (không qua internet!)

# Private Endpoint cho Storage
az network private-endpoint create \
  --name storage-pe \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --subnet app-subnet \
  --private-connection-resource-id STORAGE_ID \
  --group-id blob \
  --connection-name storage-pe-conn

# Private DNS Zone cho resolution
az network private-dns zone create \
  --resource-group myapp-rg \
  --name "privatelink.blob.core.windows.net"

az network private-dns link vnet create \
  --resource-group myapp-rg \
  --zone-name "privatelink.blob.core.windows.net" \
  --name storage-dns-link \
  --virtual-network myapp-vnet \
  --registration-enabled false

# Auto-create DNS record cho private endpoint
az network private-endpoint dns-zone-group create \
  --endpoint-name storage-pe \
  --resource-group myapp-rg \
  --name storage-dns-group \
  --private-dns-zone "privatelink.blob.core.windows.net" \
  --zone-name blob

# Sau đó: storage account disable public access
az storage account update \
  --name myappstorage001 \
  --resource-group myapp-rg \
  --public-network-access Disabled
```

### 2.2 VNet Peering

```bash
# VNet Peering = Kết nối 2 VNets (cùng region hoặc khác region/subscription)

# Tạo peering từ VNet A → VNet B
az network vnet peering create \
  --name vnet-a-to-b \
  --resource-group myapp-rg \
  --vnet-name vnet-a \
  --remote-vnet VNET_B_ID \
  --allow-vnet-access true \
  --allow-forwarded-traffic true

# Tạo peering ngược lại (VNet B → VNet A)
az network vnet peering create \
  --name vnet-b-to-a \
  --resource-group other-rg \
  --vnet-name vnet-b \
  --remote-vnet VNET_A_ID \
  --allow-vnet-access true

# Hub-spoke topology (common pattern)
# Hub VNet ← Shared services (FW, DNS, VPN)
# Spoke VNets ← Individual app VNets
# Spoke → Hub peering (với UseRemoteGateways)
```

### 2.3 Azure VPN Gateway

```bash
# VPN Gateway = Site-to-Site VPN hoặc Point-to-Site

# Gateway subnet (bắt buộc tên GatewaySubnet)
az network vnet subnet create \
  --name GatewaySubnet \
  --resource-group myapp-rg \
  --vnet-name myapp-vnet \
  --address-prefix 10.0.254.0/27

az network public-ip create \
  --name myapp-vpngw-pip \
  --resource-group myapp-rg \
  --sku Standard \
  --zone 1 2 3

# Site-to-Site VPN (kết nối On-premise)
az network vnet-gateway create \
  --name myapp-vpngw \
  --resource-group myapp-rg \
  --vnet myapp-vnet \
  --public-ip-address myapp-vpngw-pip \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw2AZ \           # VpnGw1 → VpnGw5
  --generation Generation2 \
  --no-wait

# Local Network Gateway (On-premise)
az network local-gateway create \
  --name onprem-lgw \
  --resource-group myapp-rg \
  --gateway-ip-address 203.0.113.1 \   # On-premise public IP
  --local-address-prefixes 192.168.0.0/16 10.100.0.0/16

# VPN Connection
az network vpn-connection create \
  --name azure-to-onprem \
  --resource-group myapp-rg \
  --vnet-gateway1 myapp-vpngw \
  --local-gateway2 onprem-lgw \
  --shared-key "VerySecretPSK123!"
```

### 2.4 Azure ExpressRoute

```
ExpressRoute = Private dedicated connection đến Azure
- Không qua public internet
- Bandwidth: 50Mbps → 100Gbps
- Lower latency, more reliable
- Tốn kém hơn VPN nhưng cho enterprise

Providers: Telstra, SingTel, PCCW, ...

ExpressRoute Circuit → Exchange Provider → Azure
```

---

## 3. Cost Management

### 3.1 Azure Cost Management

```bash
# Xem chi phí
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[].{name:instanceName, cost:pretaxCost, currency:currency}" \
  --output table

# Chi phí theo Resource Group
az consumption usage list \
  --query "[?resourceGroup=='myapp-rg'] | sort_by(@, &pretaxCost)" \
  --output table

# ===== BUDGETS =====
az consumption budget create \
  --budget-name monthly-budget \
  --amount 1000 \
  --category Cost \
  --time-grain Monthly \
  --start-date 2024-01-01 \
  --end-date 2024-12-31 \
  --notification-threshold 80 \
  --notification-contact-emails admin@company.com \
  --notification-contact-roles Owner Contributor

# Alert khi cost > 90%
az consumption budget create \
  --budget-name monthly-alert-90 \
  --amount 1000 \
  --category Cost \
  --time-grain Monthly \
  --notification-threshold 90 \
  --notification-contact-emails finance@company.com
```

### 3.2 Cost Optimization Strategies

```bash
# ===== RESERVED INSTANCES (Save 30-70%) =====
# Cam kết 1-3 năm → Giảm giá đáng kể

# Tính toán: Azure Pricing Calculator
# https://azure.microsoft.com/en-us/pricing/calculator/

# ===== SPOT INSTANCES (Save 60-90%) =====
# Cho non-critical workloads (batch, CI/CD runners)
az vmss create \
  --name spot-vmss \
  --resource-group myapp-rg \
  --image Ubuntu2204 \
  --priority Spot \
  --eviction-policy Delete \
  --max-price -1                # -1 = Pay current spot price

# ===== AUTO-SHUTDOWN =====
az vm auto-shutdown \
  --resource-group myapp-rg \
  --name dev-vm \
  --time 1900 \                 # 7 PM
  --email admin@company.com

# ===== AZURE ADVISOR (Cost recommendations) =====
az advisor recommendation list --category Cost

# ===== TAGGING (Cost allocation) =====
az resource tag \
  --resource-id RESOURCE_ID \
  --tags CostCenter=Engineering Team=Backend Environment=Production

# Xem cost per tag
az consumption usage list \
  --query "[?tags.CostCenter=='Engineering'].{name:instanceName, cost:pretaxCost}"
```

---

## 4. Disaster Recovery

### 4.1 Azure Site Recovery

```bash
# Site Recovery = DR cho VMs (cloud hoặc on-premise)

# Tạo Recovery Services Vault
az backup vault create \
  --name myapp-rsv \
  --resource-group myapp-rg \
  --location southeastasia \
  --redundancy GeoRedundant

# Enable VM backup
az backup protection enable-for-vm \
  --vault-name myapp-rsv \
  --resource-group myapp-rg \
  --vm myapp-vm-1 \
  --policy-name DefaultPolicy

# Trigger backup
az backup protection backup-now \
  --vault-name myapp-rsv \
  --resource-group myapp-rg \
  --container-name IaasVMContainer;iaasvmcontainerv2;myapp-rg;myapp-vm-1 \
  --item-name vm;iaasvmcontainerv2;myapp-rg;myapp-vm-1 \
  --backup-management-type AzureIaasVM

# Restore VM
az backup restore restore-disks \
  --vault-name myapp-rsv \
  --resource-group myapp-rg \
  --container-name CONTAINER_NAME \
  --item-name ITEM_NAME \
  --rp-name RECOVERY_POINT_NAME \
  --storage-account STORAGE_ACCOUNT
```

### 4.2 Geo-Redundancy Pattern

```
RTO/RPO cho các tiers:
- Tier 1 (Critical):   RTO < 1h, RPO < 15m → Active-Active multi-region
- Tier 2 (Important): RTO < 4h, RPO < 1h  → Active-Passive với hot standby
- Tier 3 (Standard):  RTO < 24h, RPO < 4h → Active-Passive với cold standby

Azure cho Tier 1:
- Traffic Manager hoặc Azure Front Door → Global routing
- App Services: Multi-region với geo-replication
- PostgreSQL: Read replicas hoặc geo-failover groups
- Storage: Geo-zone-redundant (GZRS)
- Cosmos DB: Multi-region writes
```

```bash
# Azure Front Door = Global HTTP load balancer + CDN
az afd profile create \
  --profile-name myapp-afd \
  --resource-group myapp-rg \
  --sku Standard_AzureFrontDoor

az afd origin-group create \
  --profile-name myapp-afd \
  --resource-group myapp-rg \
  --origin-group-name myapp-backends \
  --probe-path /health \
  --probe-protocol Https \
  --probe-interval-in-seconds 30

# Primary origin (Southeast Asia)
az afd origin create \
  --profile-name myapp-afd \
  --resource-group myapp-rg \
  --origin-group-name myapp-backends \
  --origin-name sea-origin \
  --host-name app-myapp-prod.azurewebsites.net \
  --origin-host-header app-myapp-prod.azurewebsites.net \
  --priority 1 \
  --weight 1000

# Secondary origin (East Asia - DR)
az afd origin create \
  --profile-name myapp-afd \
  --resource-group myapp-rg \
  --origin-group-name myapp-backends \
  --origin-name ea-origin \
  --host-name app-myapp-dr.azurewebsites.net \
  --origin-host-header app-myapp-dr.azurewebsites.net \
  --priority 2 \         # Lower priority = failover
  --weight 1000
```

---

> **Tiếp theo: Phần 5** - Azure Real-World Scenarios, Best Practices & Cheat Sheet
