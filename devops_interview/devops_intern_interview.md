---
markmap:
  title: "DevOps Intern Interview Guide"
  collapse: false
---

# 🎯 DEVOPS INTERN INTERVIEW GUIDE

## Theory
- Các chủ đề cốt lõi: version control, CI/CD, containers, orchestration, IaC, cloud, monitoring, security, automation.

## Practice
- Thực hành: templates câu trả lời, ví dụ pipelines, Dockerfile sample, Terraform backend snippet, và scripts kiểm thử nhanh.

## 1. Core Concepts

| Domain | Key Topics | Typical Interview Questions |
|--------|------------|-----------------------------|
| **Version Control** | Git basics, branching strategies, merge vs rebase, PR workflow | *Explain `git rebase` vs `git merge`.* |
| **CI/CD** | Pipelines, triggers, artifact handling, rollbacks, blue‑green / canary deployments | *Describe a typical CI/CD pipeline for a microservices app.* |
| **Containers** | Dockerfile anatomy, image layers, multi‑stage builds, container registries, runtime flags | *Why use a multi‑stage Dockerfile?* |
| **Orchestration** | Kubernetes fundamentals (Pods, Deployments, Services, Ingress, ConfigMaps, Secrets), Helm, Kustomize, K3s vs AKS, node scheduling, RBAC | *How does a `Deployment` ensure zero‑downtime updates?* |
| **Infrastructure as Code** | Terraform, Azure ARM/Bicep, Ansible, state management, modules, remote back‑ends | *Explain Terraform workspaces and why they’re useful.* |
| **Cloud Platforms** | Azure core services (VM, VNet, NSG, AKS, ACR, Key Vault, Monitor), IAM, networking, cost management | *What is a Managed Identity and how does it differ from a Service Principal?* |
| **Monitoring & Observability** | Azure Monitor, Log Analytics, Prometheus, Grafana, Application Insights, alerting, tracing (OpenTelemetry) | *How would you monitor a distributed microservice on AKS?* |
| **Security** | Secrets management, image scanning (Trivy, Defender), network policies, PodSecurityPolicies, least‑privilege IAM | *How to secure secrets in a CI pipeline?* |
| **Scripting / Automation** | Bash, PowerShell, Python/Go for tooling, CLI usage (az, kubectl, docker) | *Write a script to list all pods in `CrashLoopBackOff` state.* |
| **Testing** | Unit, integration, end‑to‑end, contract testing, test containers, CI test reporting | *What is the difference between unit and integration tests in a pipeline?* |
| **Troubleshooting** | Log analysis, `kubectl exec`, `kubectl debug`, `kubectl top`, network diagnostics, Helm rollback, diffing manifests | *Debug a failing Helm upgrade.* |


## 2. Frequently Asked Practical Tasks

1. **Create a GitHub Action that builds a Docker image and pushes to Azure Container Registry**
2. **Write a Terraform module that provisions an AKS cluster with Log Analytics enabled**
3. **Create a Helm chart for a simple Node.js app with configurable replica count**
4. **Implement a Bash script that monitors CPU usage on a Linux VM and sends an alert to Slack**
5. **Show how to use Azure Key Vault to inject secrets into a Kubernetes pod**
6. **Configure a Prometheus alert for pod restarts > 3 in 5 min**
7. **Explain how to migrate a legacy VM‑based app to a container‑first architecture**


## 3. Soft‑Skills & Culture Fit

- **Collaboration** – Working with developers, security, SREs.
- **Problem‑Solving** – Diagnose production incidents, root‑cause analysis.
- **Continuous Learning** – Staying up‑to‑date with cloud‑native tools.
- **Automation Mindset** – “Never manually do something that can be scripted.”


## 4. Quick Cheat‑Sheet

```bash
# Git shortcuts
git switch -c feature/xyz   # create & switch
git pull --rebase origin main

# Docker multi‑stage example
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

FROM alpine:latest
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]

# Terraform remote backend (Azure Storage)
terraform {
  backend "azurerm" {
    resource_group_name   = "tfstate-rg"
    storage_account_name  = "tfstatestorage001"
    container_name        = "tfstate"
    key                   = "devops/interview.tfstate"
  }
}

# Kubectl common one‑liners
kubectl get pods -A | grep CrashLoopBackOff
kubectl exec -it $POD -- sh
kubectl top nodes
```


> **Tip:** Tailor your answers with real‑world examples from the projects you’ve built (e.g., the Jenkins‑Azure integration you just documented).
