---
markmap:
	title: "Terraform — Azure Complete (redirect)"
	collapse: false
---

# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 3: AZURE INFRASTRUCTURE HOÀN CHỈNH

## Theory
- This document centralizes a full Azure 3-tier architecture and shows how Terraform modules compose a production-grade infra with state, monitoring, and CI/CD.

## Practice
- Use remote state with locking, split environment configs under `environments/`, and drive deployments from CI with `terraform plan` + approvals.

> **📌 Tài liệu này đã được chuyển sang Azure.**
>
> Xem nội dung đầy đủ tại:
> **`terraform_p3b_azure_complete.md`** — AKS, ACR, PostgreSQL, Redis, Key Vault, Azure DevOps CI/CD


Nội dung bao gồm trong `terraform_p3b_azure_complete.md`:

1. **3-Tier Azure Architecture** — VNet, Subnets, NSG, Application Gateway
2. **Azure Kubernetes Service (AKS)** — Cluster, Node Pools, OIDC, Workload Identity
3. **Azure Container Registry (ACR)** — với geo-replication, Private Endpoint
4. **Azure Database for PostgreSQL** — Flexible Server, HA, Geo-backup
5. **Azure Cache for Redis** — Persistence, TLS
6. **Azure Key Vault** — Secrets, Certificates, Access Policies
7. **Azure Monitor & Log Analytics** — Diagnostic Settings, Alerts
8. **Azure DevOps CI/CD Pipeline** — Terraform Plan/Apply với approvals


> Tiếp tục: Phần 4 - Best Practices & Security
