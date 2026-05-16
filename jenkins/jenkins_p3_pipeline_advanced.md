# 🔧 JENKINS TOÀN TẬP - PHẦN 3: PIPELINE NÂNG CAO & MULTIBRANCH

---

## 1. Multibranch Pipeline

### 1.1 Cấu Hình Multibranch

```groovy
// Jenkinsfile - Cấu hình cho Multibranch Pipeline
// Tự động tạo job cho mỗi branch có Jenkinsfile

pipeline {
    agent any

    // Mỗi branch có behavior khác nhau
    stages {
        stage('CI') {
            stages {
                stage('Lint & Test') {
                    steps { sh 'npm run lint && npm test' }
                }
                stage('Build') {
                    steps { sh 'npm run build' }
                }
            }
        }

        // Deploy to staging chỉ từ develop
        stage('Deploy Staging') {
            when {
                anyOf {
                    branch 'develop'
                    branch pattern: 'release/*', comparator: 'GLOB'
                }
            }
            steps { sh 'echo Deploy to staging' }
        }

        // Deploy to prod chỉ từ main/master
        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                input message: 'Deploy to Production?', ok: 'Go!'
                sh 'echo Deploy to production'
            }
        }

        // Feature branches: chỉ CI, không deploy
        stage('PR Preview') {
            when {
                changeRequest target: 'develop'
            }
            steps { sh 'echo Creating PR preview environment' }
        }
    }
}
```

### 1.2 Branch Strategies

```groovy
// Khai báo trong DSL hoặc JCasC
// Chỉ build các branch match pattern
multibranchPipelineJob('myapp') {
    branchSources {
        git {
            id('myapp-git')
            remote('https://github.com/company/myapp.git')
            credentialsId('github-token')
        }
    }

    orphanedItemStrategy {
        discardOldItems {
            daysToKeep(30)
            numToKeep(20)
        }
    }

    triggers {
        periodic(1)   // Scan mỗi 1 phút
    }
}
```

---

## 2. Pipeline Templates (JobDSL)

```groovy
// jobs/seed-job.groovy - Seed Job tạo tất cả jobs tự động

def apps = [
    [name: 'myapp-api',      repo: 'github.com/company/myapp-api',      lang: 'node'],
    [name: 'myapp-frontend', repo: 'github.com/company/myapp-frontend',  lang: 'node'],
    [name: 'myapp-worker',   repo: 'github.com/company/myapp-worker',    lang: 'python'],
    [name: 'myapp-gateway',  repo: 'github.com/company/myapp-gateway',   lang: 'go'],
]

apps.each { app ->
    multibranchPipelineJob(app.name) {
        displayName(app.name)
        description("CI/CD pipeline for ${app.name}")

        branchSources {
            github {
                id("${app.name}-source")
                repository(app.repo.split('/').last())
                repoOwner('company')
                credentialsId('github-app-credentials')
                traits {
                    gitHubBranchDiscovery { strategyId(1) }
                    gitHubPullRequestDiscovery { strategyId(1) }
                    headWildcardFilter {
                        includes('main develop release/* feature/*')
                        excludes('dependabot/*')
                    }
                }
            }
        }

        factory {
            workflowBranchProjectFactory {
                scriptPath('Jenkinsfile')
            }
        }

        orphanedItemStrategy {
            discardOldItems { daysToKeep(30) }
        }
    }
}
```

---

## 3. Advanced Pipeline Patterns

### 3.1 Matrix Build (Test nhiều version)

```groovy
pipeline {
    agent none

    stages {
        stage('Test Matrix') {
            matrix {
                axes {
                    axis {
                        name 'NODE_VERSION'
                        values '18', '20', '21'
                    }
                    axis {
                        name 'OS'
                        values 'linux', 'windows'
                    }
                }

                // Exclude không cần thiết
                excludes {
                    exclude {
                        axis { name 'OS'; values 'windows' }
                        axis { name 'NODE_VERSION'; values '18' }
                    }
                }

                agent {
                    docker { image "node:${NODE_VERSION}-alpine" }
                }

                stages {
                    stage('Test') {
                        steps {
                            sh "node --version && npm test"
                        }
                    }
                }
            }
        }
    }
}
```

### 3.2 Reusable Stages với Functions

```groovy
// Jenkinsfile với helper functions
def runTests(String suiteType) {
    return {
        stage("Test: ${suiteType}") {
            try {
                sh "npm run test:${suiteType}"
            } catch (e) {
                currentBuild.result = 'UNSTABLE'
                throw e
            } finally {
                junit allowEmptyResults: true, testResults: "reports/${suiteType}/*.xml"
            }
        }
    }
}

def buildForEnv(String env, String imageTag) {
    return {
        stage("Build ${env}") {
            sh """
                docker build \
                  --build-arg ENV=${env} \
                  -t myapp:${imageTag}-${env} .
            """
        }
    }
}

pipeline {
    agent any

    stages {
        stage('Tests') {
            parallel {
                stage('Unit')       { steps { script { runTests('unit')() } } }
                stage('Integration'){ steps { script { runTests('integration')() } } }
                stage('E2E')        { steps { script { runTests('e2e')() } } }
            }
        }

        stage('Multi-env Build') {
            parallel {
                stage('Build Staging') {
                    steps { script { buildForEnv('staging', BUILD_NUMBER)() } }
                }
                stage('Build Production') {
                    when { branch 'main' }
                    steps { script { buildForEnv('production', BUILD_NUMBER)() } }
                }
            }
        }
    }
}
```

### 3.3 Checkpoint & Resume

```groovy
pipeline {
    agent any

    stages {
        stage('Long Build') {
            steps {
                sh 'make build'
                
                // Lưu artifacts để dùng tiếp nếu restart
                stash name: 'build-artifacts', includes: 'dist/**'
            }
        }

        stage('Deploy') {
            steps {
                // Lấy lại artifacts từ stage trước
                unstash 'build-artifacts'
                sh 'deploy.sh'
            }
        }
    }
}
```

---

## 4. Blue-Green & Canary Deployment

```groovy
// Blue-Green Deployment Jenkinsfile
pipeline {
    agent any

    environment {
        APP_NAME = 'myapp'
        AKS_RG   = 'rg-myapp-prod'
        AKS_NAME = 'aks-myapp-prod'
    }

    stages {
        stage('Detect Active Color') {
            steps {
                script {
                    withCredentials([azureServicePrincipal('azure-sp')]) {
                        sh "az aks get-credentials --resource-group ${AKS_RG} --name ${AKS_NAME}"
                    }

                    // Xác định màu hiện tại (blue hoặc green)
                    def active = sh(
                        script: "kubectl get service ${APP_NAME} -n production -o jsonpath='{.spec.selector.color}'",
                        returnStdout: true
                    ).trim()

                    env.ACTIVE_COLOR  = active ?: 'blue'
                    env.STANDBY_COLOR = (active == 'blue') ? 'green' : 'blue'
                    echo "Active: ${env.ACTIVE_COLOR}, Standby: ${env.STANDBY_COLOR}"
                }
            }
        }

        stage('Deploy to Standby') {
            steps {
                sh """
                    helm upgrade --install ${APP_NAME}-${env.STANDBY_COLOR} ./helm/${APP_NAME} \
                      -n production \
                      --set color=${env.STANDBY_COLOR} \
                      --set image.tag=${BUILD_NUMBER} \
                      --wait
                """
            }
        }

        stage('Smoke Test Standby') {
            steps {
                // Test standby trực tiếp (qua internal service)
                sh """
                    STANDBY_URL=\$(kubectl get svc ${APP_NAME}-${env.STANDBY_COLOR} \
                      -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

                    curl -f http://\${STANDBY_URL}/health || exit 1
                    echo "Smoke test passed!"
                """
            }
        }

        stage('Switch Traffic') {
            steps {
                input message: "Switch traffic from ${env.ACTIVE_COLOR} to ${env.STANDBY_COLOR}?"

                sh """
                    kubectl patch service ${APP_NAME} -n production \
                      -p '{"spec":{"selector":{"color":"${env.STANDBY_COLOR}"}}}'

                    echo "Traffic switched to ${env.STANDBY_COLOR}!"
                """
            }
        }

        stage('Cleanup Old Deployment') {
            steps {
                sh """
                    # Giữ lại 30 phút để rollback nếu cần
                    sleep 1800

                    helm uninstall ${APP_NAME}-${env.ACTIVE_COLOR} -n production
                """
            }
        }
    }

    post {
        failure {
            // Rollback về màu cũ
            sh """
                kubectl patch service ${APP_NAME} -n production \
                  -p '{"spec":{"selector":{"color":"${env.ACTIVE_COLOR}"}}}'
                echo "Rolled back to ${env.ACTIVE_COLOR}"
            """
        }
    }
}
```

---

## 5. Jenkins Monitoring & Metrics

### 5.1 Prometheus Metrics từ Jenkins

```bash
# Cài plugin: Prometheus metrics plugin
# Expose metrics tại: http://jenkins:8080/prometheus

# Metrics quan trọng:
# jenkins_builds_duration_milliseconds_summary
# jenkins_builds_failed_build_count
# jenkins_executor_count_value
# jenkins_queue_size_value
# jenkins_node_online_value
```

```yaml
# prometheus.yml - scrape Jenkins
scrape_configs:
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
    basic_auth:
      username: 'prometheus-user'
      password: 'token-value'
```

### 5.2 Grafana Dashboard cho Jenkins

```promql
# Build success rate
rate(jenkins_builds_success_build_count[1h]) /
rate(jenkins_builds_count[1h]) * 100

# Average build duration
jenkins_builds_duration_milliseconds_summary_mean / 1000

# Queue size (bao nhiêu jobs đang chờ)
jenkins_queue_size_value

# Active executors
jenkins_executor_in_use_value / jenkins_executor_count_value * 100
```

---

> **Tiếp theo: Phần 4** - Jenkins Security, High Availability & Best Practices
