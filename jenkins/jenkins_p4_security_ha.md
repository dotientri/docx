---
markmap:
  title: "Jenkins — Security, HA & Best Practices"
  collapse: false
---

# 🔧 JENKINS TOÀN TẬP - PHẦN 4: SECURITY, HA & BEST PRACTICES

## Theory
- Secure Jenkins by enforcing RBAC, secrets management, audit logging, and minimizing attack surface (agents separation).

## Practice
- Integrate Azure AD for auth, use Key Vault for secrets, enable audit trail, and deploy Jenkins in HA mode with persistent storage and backup.

## 1. Jenkins Security

### 1.1 Security Hardening Checklist

```groovy
// Script Console: Manage Jenkins → Script Console
// Tắt các tính năng không an toàn

import jenkins.model.Jenkins
import hudson.security.csrf.DefaultCrumbIssuer

def jenkins = Jenkins.getInstance()

// 1. Bật CSRF protection
jenkins.setCrumbIssuer(new DefaultCrumbIssuer(true))

// 2. Tắt CLI qua Remoting (không cần thiết)
jenkins.getDescriptor("jenkins.CLI").setEnabled(false)

// 3. Tắt agent-to-master access (bảo mật)
jenkins.injector.getInstance(jenkins.security.s2m.AdminWhitelistRule.class)
    .setMasterKillSwitch(false)

jenkins.save()
println "Security hardened!"
```

### 1.2 Azure AD Integration (RBAC)

```yaml
# JCasC - Azure AD Authentication
jenkins:
  securityRealm:
    azureAdSecurityRealm:
      clientId: "${AZURE_CLIENT_ID}"
      clientSecret: "${AZURE_CLIENT_SECRET}"
      tenantId: "${AZURE_TENANT_ID}"
      cachedDurationInMinutes: 60

  authorizationStrategy:
    roleBased:
      roles:
        global:
          # DevOps team: full access
          - name: admin
            permissions:
              - Overall/Administer
            assignments:
              - "DevOps-Engineers-AzureAD-Group"

          # Developers: build và xem log
          - name: developer
            permissions:
              - Overall/Read
              - Job/Build
              - Job/Read
              - Job/Workspace
              - View/Read
              - Run/Replay
            assignments:
              - "Developers-AzureAD-Group"
              - "authenticated"

          # Ops: deploy to production
          - name: operator
            permissions:
              - Overall/Read
              - Job/Read
              - Job/Build
              - Job/Configure
            assignments:
              - "Ops-Team-AzureAD-Group"

        items:
          # Restrict production jobs
          - name: production-deployer
            pattern: ".*/production.*"
            permissions:
              - Job/Build
              - Job/Read
            assignments:
              - "Release-Managers-AzureAD-Group"
```

### 1.3 Secrets Management với Azure Key Vault

```groovy
// Jenkinsfile - Lấy secrets từ Azure Key Vault
pipeline {
    agent any

    stages {
        stage('Use Key Vault Secrets') {
            steps {
                // Plugin: Azure Key Vault Plugin
                withAzureKeyVault(
                    keyVaultURL: 'https://kv-myapp-prod.vault.azure.net',
                    credentialID: 'azure-service-principal',
                    secrets: [
                        [envVariable: 'DB_PASSWORD',     name: 'postgres-password',   secretType: 'Secret'],
                        [envVariable: 'API_KEY',         name: 'external-api-key',    secretType: 'Secret'],
                        [envVariable: 'CERT_PASSWORD',   name: 'ssl-cert-password',   secretType: 'Secret'],
                    ]
                ) {
                    sh '''
                        # Secrets available as env vars (masked trong log)
                        echo "DB_PASSWORD length: ${#DB_PASSWORD}"
                        # Dùng trong deployment
                        kubectl create secret generic app-secrets \
                          --from-literal=db-password="${DB_PASSWORD}" \
                          --from-literal=api-key="${API_KEY}" \
                          -n production --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }
    }
}
```

### 1.4 Audit Logging

```groovy
// Jenkins Audit Trail Plugin
// Ghi lại tất cả actions: login, logout, job start, config change

// Cấu hình output tới file và Azure Monitor
unclassified:
  auditTrailPlugin:
    pattern: ".*"
    loggers:
      - logFile:
          count: 20
          limit: 25
          log: /var/log/jenkins/audit.log
```


## 2. High Availability Jenkins

### 2.1 Jenkins trên Azure với Persistent Storage

```bash
# ===== JENKINS HA TRÊN AZURE AKS =====

# 1. Tạo Azure Disk cho Jenkins home
az disk create \
  --resource-group rg-jenkins \
  --name jenkins-data \
  --size-gb 256 \
  --sku Premium_LRS \
  --zone 1
```

```yaml
# jenkins-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1   # Jenkins KHÔNG thể scale horizontal (active-passive)
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      securityContext:
        fsGroup: 1000
        runAsUser: 1000

      initContainers:
        # Cài plugins trước khi start (idempotent)
        - name: install-plugins
          image: jenkins/jenkins:lts-jdk17
          command: ["jenkins-plugin-cli", "--plugin-file", "/plugins/plugins.txt"]
          volumeMounts:
            - name: plugins-list
              mountPath: /plugins
            - name: jenkins-home
              mountPath: /var/jenkins_home

      containers:
        - name: jenkins
          image: jenkins/jenkins:lts-jdk17
          ports:
            - containerPort: 8080
            - containerPort: 50000
          env:
            - name: JAVA_OPTS
              value: >-
                -Djenkins.install.runSetupWizard=false
                -Xms2g -Xmx4g
                -XX:+UseG1GC
            - name: CASC_JENKINS_CONFIG
              value: /var/jenkins_home/casc_configs
          resources:
            requests:
              cpu: 1000m
              memory: 3Gi
            limits:
              cpu: 4000m
              memory: 8Gi
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
            - name: casc-config
              mountPath: /var/jenkins_home/casc_configs
          livenessProbe:
            httpGet:
              path: /login
              port: 8080
            initialDelaySeconds: 90
            periodSeconds: 30
            failureThreshold: 5
          readinessProbe:
            httpGet:
              path: /login
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10

      volumes:
        - name: jenkins-home
          persistentVolumeClaim:
            claimName: jenkins-pvc
        - name: casc-config
          configMap:
            name: jenkins-casc
        - name: plugins-list
          configMap:
            name: jenkins-plugins

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  storageClassName: managed-premium
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 256Gi
```

### 2.2 Backup Jenkins Home

```bash
#!/bin/bash
# scripts/jenkins-backup.sh
# Chạy hàng ngày để backup Jenkins home

JENKINS_POD=$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
AZURE_CONTAINER="jenkins-backups"
STORAGE_ACCOUNT="myappjenkinsbackup"

echo "=== Jenkins Backup: ${BACKUP_DATE} ==="

# 1. Trigger Jenkins Quiet Down (không nhận build mới)
curl -X POST https://jenkins.company.com/quietDown \
  -u "admin:${JENKINS_TOKEN}"

sleep 30  # Chờ builds hiện tại kết thúc

# 2. Backup JENKINS_HOME (exclude workspace và caches)
kubectl exec -n jenkins "${JENKINS_POD}" -- \
  tar czf /tmp/jenkins-backup.tar.gz \
  --exclude='/var/jenkins_home/workspace' \
  --exclude='/var/jenkins_home/caches' \
  --exclude='/var/jenkins_home/.m2' \
  /var/jenkins_home

# 3. Copy ra local
kubectl cp jenkins/"${JENKINS_POD}":/tmp/jenkins-backup.tar.gz \
  ./jenkins-backup-${BACKUP_DATE}.tar.gz

# 4. Upload lên Azure Blob
az storage blob upload \
  --account-name "${STORAGE_ACCOUNT}" \
  --container-name "${AZURE_CONTAINER}" \
  --name "jenkins-backup-${BACKUP_DATE}.tar.gz" \
  --file "./jenkins-backup-${BACKUP_DATE}.tar.gz" \
  --overwrite

# 5. Xóa local file
rm ./jenkins-backup-${BACKUP_DATE}.tar.gz

# 6. Cancel Quiet Down
curl -X POST https://jenkins.company.com/cancelQuietDown \
  -u "admin:${JENKINS_TOKEN}"

# 7. Dọn dẹp backups cũ hơn 30 ngày
az storage blob list \
  --account-name "${STORAGE_ACCOUNT}" \
  --container-name "${AZURE_CONTAINER}" \
  --query "[?properties.lastModified < '$(date -d '30 days ago' -u +%Y-%m-%dT%H:%M:%SZ)'].name" \
  -o tsv | while read blob; do
    az storage blob delete \
      --account-name "${STORAGE_ACCOUNT}" \
      --container-name "${AZURE_CONTAINER}" \
      --name "${blob}"
  done

echo "=== Backup hoàn thành: jenkins-backup-${BACKUP_DATE}.tar.gz ==="
```


## 3. Performance Tuning

```groovy
// Tối ưu Jenkins Master

// 1. Tăng thread pool
// JAVA_OPTS: -Dhudson.slaves.NodeProvisioner.initialDelay=0
//            -Dhudson.model.Queue.Hibernator.interval=5000

// 2. Tắt usage statistics
jenkins.UsageStatistics.DISABLED = true

// 3. Cleanup builds tự động
import jenkins.model.*
import hudson.model.*

Jenkins.instance.getAllItems(Job.class).each { job ->
    def buildsToKeep = 50
    def builds = job.builds

    if (builds.size() > buildsToKeep) {
        builds[buildsToKeep..-1].each { build ->
            build.delete()
        }
        println "Cleaned ${job.name}: kept ${buildsToKeep} builds"
    }
}
```


## 4. Jenkins Best Practices

### 4.1 Checklist Production

```
SECURITY:
✅ Dùng Azure AD authentication (không dùng local users)
✅ RBAC với roles phân quyền rõ ràng
✅ CSRF protection bật
✅ Secrets trong Azure Key Vault hoặc Credentials Store
✅ Không hardcode credentials trong Jenkinsfile
✅ Agents không có quyền admin trên Master

RELIABILITY:
✅ Jenkins Home trên Azure Premium SSD
✅ Backup hàng ngày lên Azure Blob
✅ Dùng JCasC để config-as-code (khôi phục dễ)
✅ Plugins list trong file (jenkins-plugins.txt)
✅ Monitor Jenkins với Prometheus/Grafana

PERFORMANCE:
✅ Master không chạy builds (numExecutors=0)
✅ Dùng K8s dynamic agents (tự scale)
✅ Cleanup builds và artifacts tự động
✅ Shared Libraries cho code reuse
✅ Parallel stages để giảm build time

CI/CD:
✅ Tất cả pipelines là Declarative (dễ đọc)
✅ Multibranch Pipeline cho tất cả repos
✅ Branch protection: require CI pass trước merge
✅ Approval gate cho production deployments
✅ Rollback plan cho mọi deployment
```

### 4.2 Plugins.txt (Plugin Management)

```text
# jenkins-plugins.txt
# Quản lý plugins as code, commit vào git

# Core
pipeline-model-definition:2.2144.v077a_def05710
workflow-aggregator:596.v8c21c963d92d
git:5.2.1
credentials-binding:677.vd400e5da_c6b_f

# Azure
azure-credentials:253.v887e0f9e898b
azure-cli:1.5.1
azure-container-registry-tasks:1.1.1
kubernetes:4209.v4f58ee944e39

# Build & Test
nodejs:1.6.1
docker-workflow:572.v950f58993843
junit:1231.v4bef5d26c8a_4
htmlpublisher:1.32

# Quality
sonar:2.17.2
jacoco:3.3.5

# Notifications
slack:631.v40deea_40323b
email-ext:2.104

# Security
owasp-dependency-check:5.4.3
role-strategy:689.v731b_c4b_20c47

# Operations
prometheus:2.5.0
audit-trail:373.v4b_36f3391b_e6
build-timeout:1.31
timestamper:1.26
build-discarder:1.05
```
