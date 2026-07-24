---
markmap:
    title: "Jenkins — Troubleshooting & Real-World"
    collapse: false
---

# 🔧 JENKINS TOÀN TẬP - PHẦN 5: TROUBLESHOOTING & REAL-WORLD SCENARIOS

## Theory
- Common Jenkins problems include agent availability, disk/memory pressure, plugin conflicts, and misconfigured pipelines.

## Practice
- Use script console for cleanup, enable logging/heap dumps for diagnostics, implement workspace cleanup and monitor agent pools and resource quotas.

## 1. Troubleshooting Thường Gặp

### 1.1 Build Stuck / Hung

```bash
# ===== BUILD KHÔNG CHẠY (stuck in queue) =====

# Kiểm tra tại sao job stuck trong queue
# Jenkins UI → Build Queue → Click "Why?" icon

# Common reasons:
# 1. Không có agent available
kubectl get pods -n jenkins -l jenkins=agent
# Fix: Scale agent pool hoặc chờ agent free

# 2. Build bị lock bởi disableConcurrentBuilds
# Fix: Cancel job cũ

# 3. Agent offline
# Jenkins UI → Manage Jenkins → Manage Nodes

# ===== KILL BUILD STUCK =====
# Qua Script Console
import jenkins.model.*

def job = Jenkins.instance.getItemByFullName("my-pipeline/develop")
def build = job.getBuildByNumber(123)
build.doKill()
println "Build killed!"
```

### 1.2 Out of Disk Space

```bash
# Jenkins tốn nhiều disk vì workspace và build logs

# ===== KIỂM TRA =====
du -sh /var/jenkins_home/workspace/*
du -sh /var/jenkins_home/jobs/*/builds/

# ===== DỌN DẸP NGAY =====
# Script Console
import jenkins.model.*

// Xóa tất cả workspaces
Jenkins.instance.getAllItems(TopLevelItem.class).each { item ->
    if (item instanceof Job) {
        item.builds.each { build ->
            if (!build.isBuilding()) {
                try {
                    build.delete()
                } catch (e) {}
            }
        }
    }
}

// Dọn workspaces
Jenkins.instance.getAllItems(Job.class).each { job ->
    if (job instanceof AbstractProject) {
        job.doDoWipeOutWorkspace()
        println "Wiped workspace: ${job.name}"
    }
}
println "Cleanup done!"

# ===== PIPELINE: Luôn dọn workspace sau build =====
post {
    always {
        cleanWs()
        sh 'docker system prune -f || true'
    }
}
```

### 1.3 Memory Issues (OOM)

```bash
# Jenkins master OOM

# 1. Tăng heap
# JAVA_OPTS=-Xms2g -Xmx6g

# 2. Enable G1GC
# JAVA_OPTS=-XX:+UseG1GC -XX:G1ReservePercent=25

# 3. Thread dump để phân tích
kill -3 $(pgrep -f jenkins.war)
# Hoặc qua API
curl http://admin:token@jenkins:8080/threadDump

# 4. Heap dump
jmap -dump:format=b,file=/tmp/jenkins-heap.hprof $(pgrep -f jenkins.war)
# Phân tích với Eclipse MAT hoặc VisualVM
```

### 1.4 Plugin Conflicts

```bash
# Safe restart sau update plugin
curl -X POST http://admin:token@jenkins:8080/safeRestart

# Downgrade plugin (qua UI: Manage Jenkins → Plugin Manager → Installed)
# Hoặc xóa thủ công
rm /var/jenkins_home/plugins/plugin-name.jpi
rm /var/jenkins_home/plugins/plugin-name.jpi.pinned
# Restart Jenkins

# Check dependency conflicts
# Manage Jenkins → Manage Plugins → Dependencies tab
```


## 2. Groovy Script Console Cheat Sheet

```groovy
// ===== USEFUL SCRIPTS =====

// 1. List tất cả jobs và trạng thái
Jenkins.instance.getAllItems(Job.class).each { job ->
    println "${job.fullName}: ${job.color}"
}

// 2. Tìm builds đang chạy
Jenkins.instance.getAllItems(Job.class).each { job ->
    job.builds.each { build ->
        if (build.isBuilding()) {
            println "Running: ${job.name} #${build.number} - ${build.durationString}"
        }
    }
}

// 3. Export danh sách credentials (chỉ IDs - không lộ secret)
import com.cloudbees.plugins.credentials.*
def creds = CredentialsProvider.lookupCredentials(
    com.cloudbees.plugins.credentials.Credentials.class,
    Jenkins.instance,
    null,
    null
)
creds.each { c ->
    println "ID: ${c.id} | Description: ${c.description} | Type: ${c.class.simpleName}"
}

// 4. Xem system properties
System.getProperties().sort().each { k, v -> println "${k} = ${v}" }

// 5. Restart Jenkins gracefully
Jenkins.instance.safeRestart()

// 6. Xem tất cả environment variables
println "PATH: ${System.getenv('PATH')}"

// 7. Cập nhật job description
def job = Jenkins.instance.getItemByFullName("myapp/main")
job.setDescription("Updated description via script")
job.save()
```


## 3. Real-World Scenarios

### 3.1 CI/CD Pipeline Hoàn Chỉnh (Azure Stack)

```groovy
// Jenkinsfile - Enterprise Pipeline với Azure
@Library('jenkins-shared-library@main') _

pipeline {
    agent {
        kubernetes {
            yaml libraryResource('pod-templates/build-pod.yaml')
            defaultContainer 'node'
        }
    }

    options {
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds(abortPrevious: true)
        ansiColor('xterm')
        timestamps()
    }

    environment {
        APP_NAME    = 'myapp-api'
        REGISTRY    = 'myappregistry.azurecr.io'
        IMAGE_TAG   = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7)}"
        SONAR_URL   = 'https://sonarqube.company.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.GIT_BRANCH}"
                }
            }
        }

        stage('CI') {
            parallel {
                stage('Install & Lint') {
                    steps {
                        sh 'npm ci --prefer-offline'
                        sh 'npm run lint'
                    }
                }
                stage('Security Scan') {
                    steps {
                        dependencyCheck(
                            additionalArguments: '--scan . --format JSON --out reports/',
                            odcInstallation: 'OWASP-DC'
                        )
                    }
                }
            }
        }

        stage('Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'npm run test:unit -- --coverage'
                        junit 'reports/junit.xml'
                        publishHTML([reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Coverage'])
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'npm run test:integration'
                    }
                }
            }
        }

        stage('Code Quality Gate') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=${APP_NAME} \
                          -Dsonar.sources=src \
                          -Dsonar.tests=tests \
                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    '''
                }
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build & Push Image') {
            steps {
                container('kaniko') {
                    withCredentials([file(credentialsId: 'acr-config', variable: 'DOCKER_CONFIG_FILE')]) {
                        sh """
                            mkdir -p /kaniko/.docker
                            cp \${DOCKER_CONFIG_FILE} /kaniko/.docker/config.json

                            /kaniko/executor \
                              --context=dir://\$(pwd) \
                              --dockerfile=Dockerfile \
                              --destination=${REGISTRY}/${APP_NAME}:${IMAGE_TAG} \
                              --destination=${REGISTRY}/${APP_NAME}:latest \
                              --cache=true
                        """
                    }
                }
            }
        }

        stage('Deploy Staging') {
            when { anyOf { branch 'develop'; branch 'main' } }
            steps {
                container('kubectl') {
                    deployToAKS(
                        resourceGroup: 'rg-myapp-staging',
                        aksCluster:    'aks-myapp-staging',
                        namespace:     'staging',
                        imageTag:      env.IMAGE_TAG,
                        environment:   'staging'
                    )
                }
            }
        }

        stage('Smoke Tests Staging') {
            when { anyOf { branch 'develop'; branch 'main' } }
            steps {
                sh 'npm run test:smoke -- --env=staging'
            }
        }

        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                input(
                    message: "Deploy ${env.IMAGE_TAG} to Production?",
                    ok: 'Deploy',
                    submitter: 'DevOps-Engineers,Release-Managers'
                )
                container('kubectl') {
                    deployToAKS(
                        resourceGroup: 'rg-myapp-prod',
                        aksCluster:    'aks-myapp-prod',
                        namespace:     'production',
                        imageTag:      env.IMAGE_TAG,
                        environment:   'production'
                    )
                }
            }
        }
    }

    post {
        always {
            cleanWs()
            dependencyCheckPublisher pattern: 'reports/dependency-check-report.json'
        }
        success {
            notifySlack('SUCCESS', [app: env.APP_NAME, imageTag: env.IMAGE_TAG])
        }
        failure {
            notifySlack('FAILURE', [app: env.APP_NAME, channel: '#alerts-critical'])
            emailext(
                subject: "❌ FAILED: ${currentBuild.fullDisplayName}",
                body: "Build failed. See: ${env.BUILD_URL}",
                to: 'devops@company.com',
                attachLog: true
            )
        }
        unstable {
            notifySlack('UNSTABLE', [app: env.APP_NAME])
        }
    }
}
```

### 3.2 Terraform Pipeline

```groovy
// Jenkinsfile cho Terraform/Terragrunt
pipeline {
    agent { label 'ubuntu' }

    parameters {
        choice(name: 'ACTION',       choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
        choice(name: 'ENVIRONMENT',  choices: ['staging', 'production'],    description: 'Target environment')
        string(name: 'COMPONENT',    defaultValue: 'aks',                   description: 'Component to deploy')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
    }

    stages {
        stage('Validate') {
            steps {
                withCredentials([azureServicePrincipal('azure-sp')]) {
                    sh """
                        export ARM_CLIENT_ID=\${AZURE_CLIENT_ID}
                        export ARM_CLIENT_SECRET=\${AZURE_CLIENT_SECRET}
                        export ARM_TENANT_ID=\${AZURE_TENANT_ID}
                        export ARM_SUBSCRIPTION_ID=\${AZURE_SUBSCRIPTION_ID}

                        cd infrastructure/live/${params.ENVIRONMENT}/${params.COMPONENT}
                        terragrunt init
                        terragrunt validate
                    """
                }
            }
        }

        stage('Plan') {
            steps {
                withCredentials([azureServicePrincipal('azure-sp')]) {
                    sh """
                        export ARM_CLIENT_ID=\${AZURE_CLIENT_ID}
                        ...
                        cd infrastructure/live/${params.ENVIRONMENT}/${params.COMPONENT}
                        terragrunt plan -out=tfplan
                    """
                }
                stash name: 'tfplan', includes: 'infrastructure/**'
            }
        }

        stage('Approve') {
            when {
                expression { params.ACTION in ['apply', 'destroy'] }
            }
            steps {
                input(
                    message: "Run terraform ${params.ACTION} on ${params.ENVIRONMENT}/${params.COMPONENT}?",
                    ok: 'Proceed',
                    submitter: 'DevOps-Engineers'
                )
            }
        }

        stage('Apply/Destroy') {
            when {
                expression { params.ACTION in ['apply', 'destroy'] }
            }
            steps {
                unstash 'tfplan'
                withCredentials([azureServicePrincipal('azure-sp')]) {
                    sh """
                        export ARM_CLIENT_ID=\${AZURE_CLIENT_ID}
                        ...
                        cd infrastructure/live/${params.ENVIRONMENT}/${params.COMPONENT}
                        terragrunt ${params.ACTION} ${params.ACTION == 'apply' ? 'tfplan' : '-auto-approve'}
                    """
                }
            }
        }
    }
}
```


## 4. Tips & Tricks

```groovy
// ===== TIPS QUAN TRỌNG =====

// 1. Luôn dùng --prefer-offline với npm để tăng tốc
sh 'npm ci --prefer-offline'

// 2. Cache Maven dependencies
options {
    maven { globalMavenSettingsConfig('global-maven-settings') }
}

// 3. Skip stage thông minh
stage('Integration Test') {
    when {
        not { changeRequest() }          // Skip khi build từ PR
        not { branch 'dependabot/*' }    // Skip dependabot branches
        expression { currentBuild.result != 'UNSTABLE' }
    }
    steps { /* ... */ }
}

// 4. Retry với backoff
retry(3) {
    sh 'npm publish'
}

// 5. Lock resource (không build song song với job khác)
lock(resource: 'production-deployment') {
    sh 'helm upgrade ...'
}

// 6. Timeout riêng cho từng stage
stage('Slow Test') {
    options { timeout(time: 30, unit: 'MINUTES') }
    steps { sh 'npm run test:e2e' }
}

// 7. Tắt checkout tự động (tự control)
options { skipDefaultCheckout(true) }
stages {
    stage('Checkout') {
        steps {
            checkout([$class: 'GitSCM',
                branches: [[name: '*/main']],
                extensions: [[$class: 'CloneOption', depth: 1, shallow: true]],  // Shallow clone!
                userRemoteConfigs: [[credentialsId: 'github-token', url: 'https://github.com/company/myapp.git']]
            ])
        }
    }
}
```


> **Kết thúc series Jenkins.** Xem thêm các topics liên quan: `k8s/`, `docker/`, `azure/` để hiểu toàn bộ stack.
