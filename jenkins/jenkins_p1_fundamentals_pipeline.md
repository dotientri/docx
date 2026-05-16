# 🔧 JENKINS TOÀN TẬP - PHẦN 1: NỀN TẢNG, CÀI ĐẶT & PIPELINE CƠ BẢN

---

## 1. Jenkins Là Gì?

### 1.1 Vị Trí của Jenkins trong CI/CD

```
CI/CD Pipeline Flow:
Developer → Git Push → Jenkins → Build → Test → Deploy

Jenkins = Open source automation server
- Trigger: Git push, schedule, manual
- Execute: Build, Test, Security scan, Deploy
- Notify: Slack, Email, Teams
```

**Tại sao Jenkins?**
- **Open source:** Miễn phí, không vendor lock-in
- **Plugin ecosystem:** 1800+ plugins (Azure, AWS, Docker, K8s...)
- **Self-hosted:** Chạy on-premise hoặc cloud
- **Mature:** Hơn 15 năm, cộng đồng lớn
- **Flexible:** Hỗ trợ mọi ngôn ngữ, tool, platform

**Jenkins vs GitHub Actions vs Azure DevOps:**

| | Jenkins | GitHub Actions | Azure DevOps |
|--|---------|---------------|--------------|
| Hosting | Self-hosted | Cloud (GitHub) | Cloud (Microsoft) |
| Cost | Server cost | Free tier + paid | Free tier + paid |
| Flexibility | Rất cao | Cao | Cao |
| Azure Integration | Plugins | Actions | Native |
| Learning Curve | Cao | Thấp | Trung bình |
| Plugin Ecosystem | Rất lớn | Lớn | Tốt |

---

## 2. Cài Đặt Jenkins

### 2.1 Trên Ubuntu/Debian (On-premise hoặc Azure VM)

```bash
# ===== CÀI JENKINS TRÊN UBUNTU 22.04 =====

# 1. Cài Java (Jenkins yêu cầu Java 11+)
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version

# 2. Thêm Jenkins repo
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# 3. Cài Jenkins
sudo apt update
sudo apt install -y jenkins

# 4. Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins

# 5. Lấy initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# 6. Truy cập UI: http://<server-ip>:8080

# ===== CẤU HÌNH FIREWALL (nếu dùng ufw) =====
sudo ufw allow 8080/tcp
sudo ufw allow 50000/tcp  # Cho Jenkins agents

# ===== REVERSE PROXY VỚI NGINX =====
sudo apt install -y nginx

cat > /etc/nginx/sites-available/jenkins << 'EOF'
upstream jenkins {
    keepalive 32;
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name jenkins.company.com;
    
    # Redirect HTTP → HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name jenkins.company.com;
    
    ssl_certificate     /etc/ssl/certs/jenkins.crt;
    ssl_certificate_key /etc/ssl/private/jenkins.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    
    # Jenkins headers
    ignore_invalid_headers off;
    
    location / {
        proxy_pass         http://jenkins;
        proxy_redirect     default;
        proxy_http_version 1.1;
        
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Connection        "";
        
        proxy_max_temp_file_size 0;
        proxy_connect_timeout    150;
        proxy_send_timeout       100;
        proxy_read_timeout       100;
        
        proxy_buffering          off;
        proxy_request_buffering  off;
        proxy_set_header         Authorization "";
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 2.2 Chạy Jenkins bằng Docker (Recommended cho Dev)

```bash
# Docker Compose cho Jenkins
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins
    restart: unless-stopped
    
    ports:
      - "8080:8080"       # Web UI
      - "50000:50000"     # Agent port
      
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock  # Docker trong Docker
      - /usr/bin/docker:/usr/bin/docker
      
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false  # Skip setup wizard
      - JENKINS_OPTS=--httpPort=8080
      
    user: root  # Cần để mount Docker socket

  # Jenkins Agent (optional)
  agent:
    image: jenkins/inbound-agent
    environment:
      - JENKINS_URL=http://jenkins:8080
      - JENKINS_AGENT_NAME=docker-agent
      - JENKINS_SECRET=${AGENT_SECRET}  # Lấy từ Jenkins UI
    depends_on:
      - jenkins

volumes:
  jenkins_home:
EOF

docker-compose up -d

# Lấy initial password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2.3 Jenkins trên Azure VM

```bash
# Azure VM cho Jenkins Master
az vm create \
  --resource-group jenkins-rg \
  --name jenkins-master \
  --image Ubuntu2204 \
  --size Standard_D4s_v5 \      # 4 vCPU, 16GB RAM
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_ed25519.pub \
  --public-ip-sku Standard \
  --nsg jenkins-nsg

# Open ports
az vm open-port --resource-group jenkins-rg --name jenkins-master --port 8080
az vm open-port --resource-group jenkins-rg --name jenkins-master --port 50000

# SSH vào VM và cài Jenkins
az vm ssh --resource-group jenkins-rg --name jenkins-master
# Sau đó chạy script cài đặt ở trên

# Attach managed disk cho Jenkins home (production)
az disk create \
  --resource-group jenkins-rg \
  --name jenkins-data-disk \
  --size-gb 256 \
  --sku Premium_LRS

az vm disk attach \
  --resource-group jenkins-rg \
  --vm-name jenkins-master \
  --disk jenkins-data-disk

# Format và mount disk
ssh azureuser@JENKINS_IP
sudo fdisk /dev/sdc  # n, p, 1, enter, enter, w
sudo mkfs.ext4 /dev/sdc1
sudo mkdir -p /var/lib/jenkins
echo '/dev/sdc1 /var/lib/jenkins ext4 defaults 0 2' | sudo tee -a /etc/fstab
sudo mount -a
sudo chown jenkins:jenkins /var/lib/jenkins
```

---

## 3. Jenkins Plugins Quan Trọng

### 3.1 Plugins Cần Cài

```
Qua Jenkins UI: Manage Jenkins → Plugin Manager

CORE:
✅ Pipeline                    - Declarative pipelines
✅ Blue Ocean                  - Modern UI
✅ Git                         - Git integration
✅ Credentials Binding         - Secrets management

AZURE:
✅ Azure Credentials           - Azure SP/MI auth
✅ Azure CLI                   - Run az commands
✅ Azure Container Registry    - ACR integration
✅ Azure VM Agents             - Dynamic Azure agents
✅ Kubernetes CLI              - kubectl trong pipeline

BUILD:
✅ Docker Pipeline             - Docker build/push
✅ NodeJS                      - Node.js builds
✅ Maven Integration           - Java builds
✅ MSBuild                     - .NET builds

TESTING:
✅ JUnit                       - Test reports
✅ Cobertura                   - Code coverage
✅ SonarQube Scanner           - Code quality

NOTIFICATION:
✅ Slack Notification          - Slack alerts
✅ Email Extension             - Email alerts
✅ Microsoft Teams Notification - Teams alerts

SECURITY:
✅ OWASP Dependency Check      - Vulnerability scan
✅ Credentials Plugin          - Secrets store
```

---

## 4. Jenkinsfile - Pipeline as Code

### 4.1 Declarative Pipeline (Khuyến Nghị)

```groovy
// Jenkinsfile - Declarative Pipeline

pipeline {
    // Chạy trên bất kỳ available agent
    agent any
    
    // Hoặc Docker agent
    // agent {
    //     docker {
    //         image 'node:20-alpine'
    //         args '-v /tmp:/tmp'
    //     }
    // }
    
    // ===== TRIGGERS =====
    triggers {
        // Webhook từ GitHub/Azure DevOps (preferred)
        // Hoặc poll SCM
        pollSCM('H/5 * * * *')    // Check mỗi 5 phút
        
        // Cron schedule
        cron('0 2 * * *')         // 2 AM daily
    }
    
    // ===== OPTIONS =====
    options {
        timeout(time: 30, unit: 'MINUTES')    // Global timeout
        buildDiscarder(logRotator(
            numToKeepStr: '10',               // Giữ 10 builds gần nhất
            artifactNumToKeepStr: '5'         // Giữ 5 artifact builds
        ))
        disableConcurrentBuilds()             // Không chạy song song
        ansiColor('xterm')                    // Màu trong console
        timestamps()                          // Timestamp mỗi log line
    }
    
    // ===== ENVIRONMENT VARIABLES =====
    environment {
        // Static vars
        APP_NAME         = 'myapp'
        DOCKER_REGISTRY  = 'myappregistry.azurecr.io'
        IMAGE_NAME       = "${DOCKER_REGISTRY}/${APP_NAME}"
        IMAGE_TAG        = "${env.BUILD_NUMBER}-${env.GIT_COMMIT[0..7]}"
        
        // Từ Jenkins Credentials Store
        AZURE_CREDENTIALS     = credentials('azure-service-principal')
        ACR_CREDENTIALS       = credentials('acr-credentials')
        SONAR_TOKEN          = credentials('sonarqube-token')
    }
    
    // ===== PARAMETERS =====
    parameters {
        string(
            name: 'TARGET_ENV',
            defaultValue: 'staging',
            description: 'Deployment target: staging or production'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip unit tests'
        )
        choice(
            name: 'LOG_LEVEL',
            choices: ['info', 'debug', 'warn'],
            description: 'Application log level'
        )
    }
    
    // ===== STAGES =====
    stages {
        // ----- STAGE 1: Checkout -----
        stage('Checkout') {
            steps {
                checkout scm
                
                script {
                    // Set build display name
                    currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.GIT_BRANCH}"
                    currentBuild.description = "Commit: ${env.GIT_COMMIT[0..7]}"
                }
            }
        }
        
        // ----- STAGE 2: Install Dependencies -----
        stage('Install') {
            agent {
                docker {
                    image 'node:20-alpine'
                    reuseNode true
                }
            }
            steps {
                sh 'npm ci --prefer-offline'
                
                // Cache node_modules
                stash includes: 'node_modules/**', name: 'node-modules'
            }
        }
        
        // ----- STAGE 3: Tests (Parallel) -----
        stage('Tests') {
            when {
                expression { !params.SKIP_TESTS }
            }
            
            parallel {
                stage('Unit Tests') {
                    agent { docker { image 'node:20-alpine' } }
                    steps {
                        unstash 'node-modules'
                        
                        sh '''
                            npm run test:unit \
                                --coverage \
                                --reporters=default \
                                --reporters=jest-junit
                        '''
                        
                        junit 'coverage/junit.xml'
                        
                        publishHTML(target: [
                            allowMissing: false,
                            alwaysLinkToLastBuild: true,
                            keepAll: true,
                            reportDir: 'coverage/lcov-report',
                            reportFiles: 'index.html',
                            reportName: 'Code Coverage Report'
                        ])
                    }
                }
                
                stage('Lint') {
                    agent { docker { image 'node:20-alpine' } }
                    steps {
                        unstash 'node-modules'
                        sh 'npm run lint -- --format checkstyle > lint-results.xml || true'
                        recordIssues(tools: [checkStyle(pattern: 'lint-results.xml')])
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        // OWASP Dependency Check
                        dependencyCheck(
                            additionalArguments: '--scan . --format JSON --out dependency-check-report',
                            odcInstallation: 'OWASP-DC'
                        )
                        dependencyCheckPublisher pattern: 'dependency-check-report/dependency-check-report.json'
                    }
                }
            }
        }
        
        // ----- STAGE 4: SonarQube Analysis -----
        stage('Code Quality') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.sources=src \
                            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                            -Dsonar.junit.reportPaths=coverage/junit.xml
                    '''
                }
                
                // Quality Gate check (wait 5 minutes max)
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        // ----- STAGE 5: Build Docker Image -----
        stage('Build Image') {
            steps {
                script {
                    // Login to Azure Container Registry
                    sh """
                        az login --service-principal \
                            -u ${AZURE_CREDENTIALS_CLIENT_ID} \
                            -p ${AZURE_CREDENTIALS_CLIENT_SECRET} \
                            --tenant ${AZURE_CREDENTIALS_TENANT_ID}
                        
                        az acr login --name myappregistry
                    """
                    
                    // Build với BuildKit
                    sh """
                        DOCKER_BUILDKIT=1 docker build \
                            --cache-from ${IMAGE_NAME}:cache \
                            --build-arg BUILDKIT_INLINE_CACHE=1 \
                            --build-arg APP_VERSION=${IMAGE_TAG} \
                            --build-arg BUILD_DATE=\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                            --build-arg VCS_REF=${env.GIT_COMMIT} \
                            -t ${IMAGE_NAME}:${IMAGE_TAG} \
                            -t ${IMAGE_NAME}:latest \
                            -t ${IMAGE_NAME}:cache \
                            .
                    """
                    
                    // Push
                    sh """
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        docker push ${IMAGE_NAME}:cache
                    """
                    
                    // Save image tag cho stages sau
                    env.FINAL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        
        // ----- STAGE 6: Deploy to Staging -----
        stage('Deploy Staging') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            
            steps {
                script {
                    // Lấy AKS credentials
                    sh """
                        az aks get-credentials \
                            --resource-group rg-myapp-staging \
                            --name aks-myapp-staging \
                            --overwrite-existing
                        
                        helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
                            -n staging \
                            -f helm/${APP_NAME}/values-staging.yaml \
                            --set image.repository=${DOCKER_REGISTRY}/${APP_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --wait \
                            --timeout 10m
                    """
                }
            }
        }
        
        // ----- STAGE 7: Integration Tests -----
        stage('Integration Tests') {
            when {
                branch 'main'
            }
            
            steps {
                sh '''
                    npm run test:integration \
                        --env API_URL=https://staging.company.com
                '''
            }
        }
        
        // ----- STAGE 8: Deploy to Production (với approval) -----
        stage('Deploy Production') {
            when {
                allOf {
                    branch 'main'
                    expression { params.TARGET_ENV == 'production' }
                }
            }
            
            steps {
                // Manual approval (timeout 24 giờ)
                input(
                    message: "Deploy ${IMAGE_TAG} to Production?",
                    ok: 'Deploy',
                    submitter: 'devops-team,release-manager',
                    parameters: [
                        text(
                            name: 'RELEASE_NOTES',
                            description: 'Release notes for this deployment'
                        )
                    ]
                )
                
                script {
                    sh """
                        az aks get-credentials \
                            --resource-group rg-myapp-prod \
                            --name aks-myapp-prod \
                            --overwrite-existing
                        
                        helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
                            -n production \
                            -f helm/${APP_NAME}/values-production.yaml \
                            --set image.repository=${DOCKER_REGISTRY}/${APP_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --wait \
                            --timeout 15m
                    """
                }
            }
        }
    }
    
    // ===== POST ACTIONS =====
    post {
        always {
            // Cleanup Docker images
            sh 'docker image prune -f || true'
            
            // Archive artifacts
            archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs()
        }
        
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: """
                    ✅ *${APP_NAME}* deployed successfully!
                    • Branch: `${env.GIT_BRANCH}`
                    • Image: `${IMAGE_TAG}`
                    • Build: <${env.BUILD_URL}|#${env.BUILD_NUMBER}>
                """.stripIndent()
            )
        }
        
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: """
                    ❌ *${APP_NAME}* build FAILED!
                    • Branch: `${env.GIT_BRANCH}`
                    • Stage: `${env.STAGE_NAME}`
                    • Build: <${env.BUILD_URL}|#${env.BUILD_NUMBER}>
                    • Logs: <${env.BUILD_URL}console|View Logs>
                """.stripIndent()
            )
            
            emailext(
                subject: "FAILED: ${currentBuild.fullDisplayName}",
                body: """
                    Build ${currentBuild.number} failed!
                    
                    Branch: ${env.GIT_BRANCH}
                    Commit: ${env.GIT_COMMIT}
                    
                    See: ${env.BUILD_URL}
                """,
                to: 'devops@company.com',
                attachLog: true
            )
        }
        
        unstable {
            slackSend(
                channel: '#ci-alerts',
                color: 'warning',
                message: "⚠️ *${APP_NAME}* build UNSTABLE - Tests failed!"
            )
        }
    }
}
```

---

## 5. Jenkins Credentials Management

### 5.1 Lưu Credentials An Toàn

```groovy
// Credentials trong Jenkinsfile

pipeline {
    agent any
    
    environment {
        // Username/Password
        DB_CREDS = credentials('database-credentials')
        // → DB_CREDS_USR = username
        // → DB_CREDS_PSW = password
        
        // Secret text
        API_KEY = credentials('external-api-key')
        
        // Azure Service Principal
        AZURE_SP = credentials('azure-service-principal')
        // → AZURE_SP_CLIENT_ID
        // → AZURE_SP_CLIENT_SECRET
        // → AZURE_SP_TENANT_ID
        // → AZURE_SP_SUBSCRIPTION_ID
        
        // SSH Key
        SSH_KEY = credentials('deploy-ssh-key')
        
        // Certificate
        SSL_CERT = credentials('ssl-certificate')
    }
    
    stages {
        stage('Use Credentials') {
            steps {
                // Method 1: withCredentials block
                withCredentials([
                    string(credentialsId: 'my-secret', variable: 'MY_SECRET'),
                    usernamePassword(
                        credentialsId: 'my-creds',
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'PASSWORD'
                    ),
                    azureServicePrincipal(
                        credentialsId: 'azure-sp',
                        subscriptionIdVariable: 'AZURE_SUBSCRIPTION_ID',
                        clientIdVariable: 'AZURE_CLIENT_ID',
                        clientSecretVariable: 'AZURE_CLIENT_SECRET',
                        tenantIdVariable: 'AZURE_TENANT_ID'
                    )
                ]) {
                    sh '''
                        az login --service-principal \
                            -u $AZURE_CLIENT_ID \
                            -p $AZURE_CLIENT_SECRET \
                            --tenant $AZURE_TENANT_ID
                    '''
                }
                
                // Method 2: SSH agent
                sshagent(['deploy-ssh-key']) {
                    sh 'ssh -o StrictHostKeyChecking=no user@server "uptime"'
                }
                
                // Method 3: File credential
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh 'kubectl get pods --kubeconfig=$KUBECONFIG'
                }
            }
        }
    }
}
```

### 5.2 Thêm Credentials qua CLI (Groovy Script)

```groovy
// Chạy trong Jenkins Script Console: Manage Jenkins → Script Console

import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret

def jenkins = Jenkins.getInstance()
def credentialsStore = jenkins.getExtensionList(
    'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
)[0].getStore()

// Thêm Secret Text
def secretCred = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    'my-api-key',          // ID
    'My API Key',           // Description
    Secret.fromString('super-secret-value')
)
credentialsStore.addCredentials(Domain.global(), secretCred)

// Thêm Username/Password
def userPassCred = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    'database-credentials',
    'Database Credentials',
    'dbuser',
    'dbpassword'
)
credentialsStore.addCredentials(Domain.global(), userPassCred)

jenkins.save()
println "Credentials added successfully!"
```

---

> **Tiếp theo: Phần 2** - Jenkins Agents, Shared Libraries & Azure Integration
