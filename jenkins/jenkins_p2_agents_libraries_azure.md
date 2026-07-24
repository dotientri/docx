---
markmap:
  title: "Jenkins — Agents, Shared Libraries & Azure"
  collapse: false
---

# 🔧 JENKINS TOÀN TẬP - PHẦN 2: AGENTS, SHARED LIBRARIES & AZURE

## Theory
- Agents (static/dynamic) execute builds; shared libraries promote DRY pipelines; Azure integrations enable resource provisioning and artifact storage.

## Practice
- Use Kubernetes dynamic agents for isolation, implement shared libraries for common pipeline steps, and integrate with Azure DevOps/ACR/AKS via service principals or managed identities.

## 1. Jenkins Agents

### 1.1 Kiến Trúc Master-Agent

```
Jenkins Master (Controller)
    ├── Lưu jobs, configs, plugins
    ├── Schedule builds
    └── Điều phối agents

Jenkins Agents (Workers)
    ├── Chạy build thực tế
    ├── Kết nối Master qua JNLP (port 50000) hoặc SSH
    └── Có thể là: VM, Docker container, K8s Pod, Azure VM
```

### 1.2 Agent Trên Kubernetes (Khuyến Nghị)

```groovy
// Jenkinsfile - Dynamic K8s Agent
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  serviceAccountName: jenkins-agent
  containers:
    # Container chính để chạy steps
    - name: jnlp
      image: jenkins/inbound-agent:latest
      resources:
        requests: { cpu: "200m", memory: "256Mi" }
        limits:   { cpu: "500m", memory: "512Mi" }

    # Node.js build
    - name: node
      image: node:20-alpine
      command: ["sleep", "infinity"]
      resources:
        requests: { cpu: "500m", memory: "512Mi" }
        limits:   { cpu: "2000m", memory: "2Gi" }

    # Docker build (dùng kaniko - không cần privileged)
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ["sleep", "infinity"]
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker

    # kubectl / helm
    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["sleep", "infinity"]

  volumes:
    - name: docker-config
      secret:
        secretName: acr-credentials   # ACR pull secret
'''
            defaultContainer 'node'
        }
    }

    stages {
        stage('Build') {
            steps {
                container('node') {
                    sh 'npm ci && npm run build'
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                container('kaniko') {
                    sh '''
                        /kaniko/executor \
                          --context=dir://$(pwd) \
                          --dockerfile=Dockerfile \
                          --destination=myappregistry.azurecr.io/myapp:${BUILD_NUMBER} \
                          --cache=true \
                          --cache-ttl=24h
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig-staging', variable: 'KUBECONFIG')]) {
                        sh '''
                            helm upgrade --install myapp ./helm/myapp \
                              -n staging \
                              --set image.tag=${BUILD_NUMBER} \
                              --wait
                        '''
                    }
                }
            }
        }
    }
}
```

### 1.3 Azure VM Agents (Dynamic Provisioning)

```groovy
// Jenkins Plugin: Azure VM Agents
// Cấu hình trong: Manage Jenkins → Cloud → Add Cloud → Azure VM Agents

// Hoặc cấu hình bằng JCasC (Jenkins Configuration as Code)
```

```yaml
# jenkins-casc.yaml (Jenkins Configuration as Code)
jenkins:
  clouds:
    - azureVMAgents:
        azureCredentialsId: "azure-service-principal"
        resourceGroup: "rg-jenkins-agents"
        maxVirtualMachinesLimit: 10
        vmTemplates:
          - templateName: "ubuntu-agent"
            labels: "ubuntu linux"
            location: "Southeast Asia"
            virtualMachineSize: "Standard_D2s_v3"
            storageAccountNameReferenceType: "new"
            diskType: "managed"
            imageReference:
              publisher: "Canonical"
              offer: "UbuntuServer"
              sku: "22.04-LTS"
              version: "latest"
            osType: "Linux"
            agentLaunchMethod: "SSH"
            credentialsId: "jenkins-ssh-key"
            initScript: |
              sudo apt-get update
              sudo apt-get install -y openjdk-17-jre docker.io git
              sudo usermod -aG docker azureuser
            idleTerminationMinutes: 30
            retentionStrategy:
              azureVMCloudRetentionStrategy:
                idleTerminationMinutes: 30
```


## 2. Shared Libraries

### 2.1 Cấu Trúc Shared Library

```
jenkins-shared-library/           ← Git repository riêng
├── vars/                         ← Global functions (dùng trực tiếp trong Jenkinsfile)
│   ├── buildDockerImage.groovy
│   ├── deployToAzure.groovy
│   ├── notifySlack.groovy
│   └── runTests.groovy
├── src/                          ← Classes (OOP, phức tạp hơn)
│   └── com/company/
│       ├── Azure.groovy
│       ├── Docker.groovy
│       └── Utils.groovy
└── resources/                    ← Static files (scripts, templates)
    ├── scripts/
    │   └── init-agent.sh
    └── templates/
        └── sonar-project.properties
```

### 2.2 Viết Global Vars

```groovy
// vars/buildDockerImage.groovy
def call(Map config = [:]) {
    def registry   = config.registry   ?: 'myappregistry.azurecr.io'
    def imageName  = config.imageName  ?: error("imageName is required")
    def imageTag   = config.imageTag   ?: env.BUILD_NUMBER
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def context    = config.context    ?: '.'

    def fullImage = "${registry}/${imageName}:${imageTag}"

    echo "Building Docker image: ${fullImage}"

    // Login to ACR
    withCredentials([azureServicePrincipal('azure-service-principal')]) {
        sh """
            az login --service-principal \
              -u \${AZURE_CLIENT_ID} \
              -p \${AZURE_CLIENT_SECRET} \
              --tenant \${AZURE_TENANT_ID}
            az acr login --name ${registry.split('\\.')[0]}
        """
    }

    // Build
    sh """
        DOCKER_BUILDKIT=1 docker build \
          --cache-from ${fullImage}:cache \
          --build-arg BUILDKIT_INLINE_CACHE=1 \
          --build-arg BUILD_NUMBER=${imageTag} \
          -t ${fullImage} \
          -t ${fullImage}:latest \
          -t ${fullImage}:cache \
          -f ${dockerfile} \
          ${context}
    """

    // Push
    sh """
        docker push ${fullImage}
        docker push ${fullImage}:latest
        docker push ${fullImage}:cache
    """

    // Return image name cho stages sau
    return fullImage
}
```

```groovy
// vars/deployToAKS.groovy
def call(Map config = [:]) {
    def resourceGroup = config.resourceGroup ?: error("resourceGroup required")
    def aksCluster    = config.aksCluster    ?: error("aksCluster required")
    def namespace     = config.namespace     ?: 'default'
    def helmChart     = config.helmChart     ?: './helm/myapp'
    def imageTag      = config.imageTag      ?: error("imageTag required")
    def environment   = config.environment   ?: 'staging'

    withCredentials([azureServicePrincipal('azure-service-principal')]) {
        sh """
            az login --service-principal \
              -u \${AZURE_CLIENT_ID} -p \${AZURE_CLIENT_SECRET} \
              --tenant \${AZURE_TENANT_ID}

            az aks get-credentials \
              --resource-group ${resourceGroup} \
              --name ${aksCluster} \
              --overwrite-existing

            helm upgrade --install myapp ${helmChart} \
              -n ${namespace} \
              -f ${helmChart}/values-${environment}.yaml \
              --set image.tag=${imageTag} \
              --wait \
              --timeout 10m \
              --atomic
        """
    }
}
```

```groovy
// vars/notifySlack.groovy
def call(String status, Map config = [:]) {
    def channel = config.channel ?: '#deployments'
    def color   = status == 'SUCCESS' ? 'good' : 'danger'
    def icon    = status == 'SUCCESS' ? '✅' : '❌'
    def app     = config.app ?: env.JOB_NAME

    slackSend(
        channel: channel,
        color: color,
        message: """
            ${icon} *${app}* - ${status}
            • Branch: `${env.GIT_BRANCH}`
            • Build:  <${env.BUILD_URL}|#${env.BUILD_NUMBER}>
            • Commit: `${env.GIT_COMMIT?.take(7)}`
        """.stripIndent().trim()
    )
}
```

### 2.3 Sử Dụng Shared Library

```groovy
// Jenkinsfile - dùng shared library
@Library('jenkins-shared-library@main') _

pipeline {
    agent any

    environment {
        APP_NAME     = 'myapp-api'
        REGISTRY     = 'myappregistry.azurecr.io'
        IMAGE_TAG    = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7)}"
    }

    stages {
        stage('Build & Push Image') {
            steps {
                script {
                    env.FULL_IMAGE = buildDockerImage(
                        registry:  env.REGISTRY,
                        imageName: env.APP_NAME,
                        imageTag:  env.IMAGE_TAG
                    )
                }
            }
        }

        stage('Deploy to Staging') {
            when { branch 'develop' }
            steps {
                deployToAKS(
                    resourceGroup: 'rg-myapp-staging',
                    aksCluster:    'aks-myapp-staging',
                    namespace:     'staging',
                    helmChart:     './helm/myapp',
                    imageTag:      env.IMAGE_TAG,
                    environment:   'staging'
                )
            }
        }

        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                input message: "Deploy ${env.IMAGE_TAG} to Production?", ok: 'Deploy Now'

                deployToAKS(
                    resourceGroup: 'rg-myapp-prod',
                    aksCluster:    'aks-myapp-prod',
                    namespace:     'production',
                    helmChart:     './helm/myapp',
                    imageTag:      env.IMAGE_TAG,
                    environment:   'production'
                )
            }
        }
    }

    post {
        success { notifySlack('SUCCESS', [app: env.APP_NAME]) }
        failure { notifySlack('FAILURE', [app: env.APP_NAME, channel: '#alerts']) }
    }
}
```


## 3. Jenkins Configuration as Code (JCasC)

```yaml
# jenkins.yaml
jenkins:
  systemMessage: "Jenkins - DevOps CI/CD Platform"
  numExecutors: 0   # Master không chạy build

  securityRealm:
    azureAdSecurityRealm:
      clientId: "${AZURE_CLIENT_ID}"
      clientSecret: "${AZURE_CLIENT_SECRET}"
      tenantId: "${AZURE_TENANT_ID}"

  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: admin
            permissions: [Overall/Administer]
            assignments: ["DevOps-Team"]
          - name: developer
            permissions:
              - Job/Build
              - Job/Read
              - Job/Workspace
            assignments: ["Developers"]
          - name: readonly
            permissions: [Overall/Read, Job/Read]
            assignments: ["authenticated"]

  globalNodeProperties:
    - envVars:
        env:
          - key: AZURE_REGISTRY
            value: "myappregistry.azurecr.io"
          - key: DEFAULT_REGION
            value: "southeastasia"

credentials:
  system:
    domainCredentials:
      - credentials:
          - azureServicePrincipal:
              id: azure-service-principal
              description: "Azure SP for deployments"
              subscriptionId: "${AZURE_SUBSCRIPTION_ID}"
              clientId: "${AZURE_CLIENT_ID}"
              clientSecret: "${AZURE_CLIENT_SECRET}"
              tenant: "${AZURE_TENANT_ID}"

          - string:
              id: sonarqube-token
              description: SonarQube token
              secret: "${SONAR_TOKEN}"

          - usernamePassword:
              id: database-credentials
              username: dbadmin
              password: "${DB_PASSWORD}"
              description: Database credentials

unclassified:
  location:
    url: "https://jenkins.company.com"
    adminAddress: "devops@company.com"

  slackNotifier:
    teamDomain: company
    tokenCredentialId: slack-token
    botUser: true

  sonarGlobalConfiguration:
    installations:
      - name: SonarQube
        serverUrl: "https://sonarqube.company.com"
        credentialsId: sonarqube-token

tool:
  git:
    installations:
      - name: git
        home: /usr/bin/git
  nodejs:
    installations:
      - name: Node20
        id: Node20
        version: 20.11.0
```
