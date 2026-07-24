# 🚀 JENKINS & AZURE INTEGRATION - PHẦN 2: TÍCH HỢP VỚI AZURE


## 1. Tại sao kết hợp Jenkins với Azure?

| Lợi ích | Jenkins (self‑hosted) | Azure DevOps (native) |
|---------|----------------------|----------------------|
| **Tự do** | ✅ Có thể chạy trên VM, container hoặc **K3s** | ❌ Dịch vụ được quản lý, ít tùy biến
| **Plugin ecosystem** | ✅ >1800 plugins (Azure CLI, Azure VM Agents, Azure Container Registry, …) | ❌ Hạn chế plugin
| **Hybrid / On‑prem** | ✅ Jenkins agents có thể chạy **trên on‑prem**, **Azure VM**, **K3s**, **AKS** | ❌ Chủ yếu cloud‑only
| **Cost** | 💰 Chi phí VM + storage | 💰 Gói miễn phí + paid tiers
| **Scalability** | ✅ Dynamic agents (Azure VM Scale Sets) | ✅ Auto‑scale trong Pipelines

> **Kết luận:** Khi muốn duy trì **pipeline tự do**, tích hợp sâu với Azure services, Jenkins là lựa chọn mạnh mẽ.


## 2. Kiến trúc đề xuất (Jenkins + Azure)

```
Developer → Git (GitHub/Azure Repos) → Webhook → Jenkins Master (run on K3s or Azure VM)
   │
   ├─ Jenkins Agents (Azure VMSS, AKS, K3s Node) –‑> Build & Test
   │
   └─ Azure Service Connections:
       • Azure CLI (az login via Service Principal)
       • Azure Container Registry (ACR) –‑> Docker push
       • Azure Kubernetes Service (AKS) –‑> helm upgrade
       • Azure Key Vault –‑> secrets injection
```

### 2.1 Jenkins Master trên **K3s** (lightweight)

```bash
# 1. Provision a small VM (e.g., Standard_B1s) in Azure
az vm create \
  --resource-group jenkins-rg \
  --name k3s-master \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub

# 2. Cài đặt k3s (quick single‑node)
ssh azureuser@<IP>
curl -sfL https://get.k3s.io | sh -
# K3s runs as systemd service, port 6443 (API server)

# 3. Deploy Jenkins via Helm (official chart) into K3s
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --set controller.servicePort=8080 \
  --set controller.hostNetwork=true \
  --set persistence.enabled=true \
  --set persistence.size=10Gi

# 4. Expose via Ingress (NGINX Ingress Controller)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
    - hosts:
        - jenkins.company.com
      secretName: jenkins-tls
  rules:
    - host: jenkins.company.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
EOF
```

### 2.2 Jenkins Agents trên **Azure VM Scale Set** (dynamic workers)

```bash
# Create a VMSS that will act as Jenkins agents
az vmss create \
  --resource-group jenkins-rg \
  --name jenkins-agents \
  --image Ubuntu2204 \
  --upgrade-policy-mode automatic \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --instance-count 0 \
  --vm-sku Standard_D2s_v5 \
  --custom-data cloud-init-agent.yaml

# cloud‑init-agent.yaml (install Java + JNLP agent)
cat > cloud-init-agent.yaml <<'EOF'
#cloud-config
runcmd:
  - apt-get update && apt-get install -y openjdk-17-jdk curl
  - curl -L https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/remoting/4.13/remoting-4.13.jar -o /opt/agent.jar
  - echo "JENKINS_URL=https://jenkins.company.com" > /opt/agent.env
  - echo "AGENT_SECRET=<secret-from-jenkins>" >> /opt/agent.env
  - echo "AGENT_NAME=$(hostname)" >> /opt/agent.env
  - nohup java -jar /opt/agent.jar -jnlpUrl $JENKINS_URL/computer/$AGENT_NAME/jenkins-agent.jnlp -secret $AGENT_SECRET &
EOF
```

### 2.3 Jenkins Agents trên **AKS** (Kubernetes agents)

```bash
# Enable Kubernetes plugin trong Jenkins UI → Manage Plugins → Kubernetes
# Then configure a Kubernetes Cloud:
#   Kubernetes URL: https://<aks-api-server>
#   Kubernetes Namespace: jenkins-agents
#   Credentials: Kubeconfig secret (stored in Jenkins)
#   Pod Template (Docker image: jenkins/inbound-agent:latest)
```


## 3. Azure Service Connections trong Jenkins

| Service | Plugin | Mô tả |
|--------|--------|------|
| **Azure CLI** | Azure CLI Plugin | `az login` bằng Service Principal, dùng trong pipeline `sh 'az ...'` |
| **Azure Container Registry** | Azure Container Registry Credential Provider | `docker login` tự động, `az acr login` |
| **Azure Kubernetes Service** | Kubernetes CLI Plugin (+ Azure Service Principal) | `kubectl`/`helm` against AKS cluster |
| **Azure Key Vault** | Azure Key Vault Plugin | Truy xuất secrets vào environment variables |
| **Azure Storage** | Azure Storage Plugin | Upload artifact lên Blob Storage |

### 3.1 Tạo Azure Service Principal (SP) cho Jenkins

```bash
az ad sp create-for-rbac \
  --name jenkins-sp \
  --role Contributor \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG> \
  --years 2

# Output will contain:
#   appId (client_id)
#   password (client_secret)
#   tenant
# Store these in Jenkins Credentials → "Microsoft Azure Service Principal"
```


## 4. Pipeline mẫu (Jenkinsfile) – Deploy to Azure AKS & ACR

```groovy
pipeline {
    agent any
    environment {
        // Azure SP credentials stored in Jenkins
        AZURE_SP = credentials('azure-sp')
        // ACR credentials (username/password) – stored as secret text
        ACR_CREDS = credentials('acr-cred')
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    // Login to ACR using the SP (az acr login auto picks up SP)
                    sh "az login --service-principal -u $AZURE_SP_USR -p $AZURE_SP_PSW --tenant $AZURE_SP_TEN"
                    sh "az acr login --name myappregistry"
                    // Build & push (BuildKit cache)
                    sh """
                        DOCKER_BUILDKIT=1 docker build \
                            -t myappregistry.azurecr.io/myapp:${env.BUILD_NUMBER} \
                            .
                        docker push myappregistry.azurecr.io/myapp:${env.BUILD_NUMBER}
                    """
                }
            }
        }
        stage('Deploy to AKS') {
            steps {
                script {
                    // Get AKS credentials (SP has rights on the cluster)
                    sh "az aks get-credentials --resource-group rg-myapp-prod --name aks-myapp-prod --overwrite-existing"
                    // Helm upgrade
                    sh """
                        helm upgrade --install myapp ./helm/myapp \
                          -n production \
                          -f helm/myapp/values-production.yaml \
                          --set image.repository=myappregistry.azurecr.io/myapp \
                          --set image.tag=${env.BUILD_NUMBER} \
                          --wait --timeout 10m
                    """
                }
            }
        }
    }
    post {
        success { slackSend channel: '#deployments', color: 'good', message: "✅ Deploy ${env.BUILD_NUMBER} succeeded" }
        failure { slackSend channel: '#deployments', color: 'danger', message: "❌ Deploy ${env.BUILD_NUMBER} failed" }
    }
}
```


## 5. Best Practices cho Jenkins + Azure

1. **Sử dụng Managed Identity** cho AKS → không cần Service Principal trong pipelines (Azure Workload Identity).
2. **Store secrets** trong **Azure Key Vault**, truy xuất bằng Azure Key Vault Plugin – tránh plaintext trong Jenkins.
3. **Enable Azure Defender for Container Registries** – scanner image khi push.
4. **Scale agents**: dùng Azure VMSS hoặc AKS‑based agents, tự động scale theo queue length (`az vmss scale …`).
5. **Backup Jenkins Home** – dùng Azure Files hoặc Azure Blob with periodic snapshot.
6. **Audit logs** – Azure Monitor + Log Analytics gửi Jenkins audit logs (kèm `az monitor diagnostic-settings`).
7. **Implement Blue‑Green / Canary** deployments via Helm `--set image.tag` và `helm rollback`.


> **Tiếp tục:** Phần 3 sẽ giới thiệu **monitoring** chuyên sâu cho Kubernetes trên Azure (Prometheus, Azure Monitor, Grafana).
