# 🔀 GIT TOÀN TẬP - PHẦN 4: GITHUB/GITLAB, CODE REVIEW & ENTERPRISE PATTERNS

---

## 1. GitHub vs GitLab vs Bitbucket

### 1.1 So Sánh Tổng Quan

| Tính Năng | GitHub | GitLab | Bitbucket |
|-----------|--------|--------|-----------|
| Hosting | Cloud / Self-hosted | Cloud / Self-hosted | Cloud / Server |
| CI/CD | GitHub Actions | GitLab CI | Bitbucket Pipelines |
| Code Review | Pull Requests | Merge Requests | Pull Requests |
| Issues | GitHub Issues | GitLab Issues | Jira tích hợp |
| Container Registry | ✓ | ✓ | ✓ |
| Kubernetes Integration | ✓ | ✓ (tốt hơn) | ✓ |
| Free Private Repos | ✓ (unlimited) | ✓ (unlimited) | ✓ (5 users) |
| Phổ Biến | Ở đâu cũng có | Enterprise nhiều hơn | Atlassian ecosystem |

---

## 2. Pull Request / Merge Request Workflow

### 2.1 Quy Trình PR Chuẩn Trong Doanh Nghiệp

```
Developer                 Git Platform              Reviewer/Lead
     │                         │                         │
     │─── push feature/xxx ───►│                         │
     │─── create PR ──────────►│                         │
     │                         │──── notify reviewers ──►│
     │                         │                         │─── review code
     │                         │◄─── comment/changes ───│
     │◄─── review feedback ───│                         │
     │                         │                         │
     │─── address comments ──►│                         │
     │─── push new commits ──►│                         │
     │                         │──── notify reviewers ──►│
     │                         │                         │─── approve ✅
     │                         │◄─── approve ───────────│
     │                         │                         │
     │                         │──── CI/CD passes ──────►│
     │                         │──── auto merge ────────►│
     │                         │─── deploy to staging ──►│
```

### 2.2 Tạo PR Hiệu Quả

**PR Description Template:**

```markdown
## 📋 Mô Tả

[Mô tả ngắn gọn thay đổi này làm gì và tại sao]

## 🎯 Loại Thay Đổi

- [ ] Bug fix (non-breaking change, fix an issue)
- [x] New feature (non-breaking change, adds functionality)
- [ ] Breaking change (fix or feature that causes existing functionality to not work)
- [ ] Documentation update

## 🔗 Liên Kết

Closes #123
Related to #456

## 🧪 Cách Test

1. Go to `/login` page
2. Enter invalid credentials
3. Verify error message appears
4. Enter valid credentials
5. Verify redirect to dashboard

## ✅ Checklist

- [x] Code follows our style guidelines
- [x] Self-reviewed the code
- [x] Added tests
- [x] Tests pass locally
- [x] Updated documentation
- [ ] Updated CHANGELOG

## 📸 Screenshots (nếu có UI changes)

Before: [screenshot]
After: [screenshot]
```

### 2.3 Code Review - Best Practices

```bash
# ===== REVIEWER: Review hiệu quả =====

# 1. Checkout PR để test local
git fetch origin pull/123/head:pr-123
git checkout pr-123

# Hoặc với GitHub CLI
gh pr checkout 123

# 2. Xem tất cả thay đổi của PR
git diff main...pr-123
git diff main...pr-123 --stat        # Tổng quan
git diff main...pr-123 -- src/auth.py  # File cụ thể

# 3. Chạy tests
npm test
pytest

# ===== QUY TẮC REVIEW =====
# Reviewer nên comment về:
# - Logic errors / bugs
# - Security issues
# - Performance problems
# - Missing tests
# - Code style (nhưng để tools làm thay nếu có thể)
# - Architecture concerns

# Reviewer KHÔNG nên:
# - Nitpick về style (có linter cho việc này)
# - Request changes không liên quan đến PR scope
# - Comment mà không giải thích lý do
```

### 2.4 GitHub CLI - Quản Lý PR Từ Terminal

```bash
# Cài đặt GitHub CLI
sudo apt install gh

# Đăng nhập
gh auth login

# Tạo PR
gh pr create --title "feat(auth): add JWT refresh token" \
             --body "Implements refresh token mechanism..." \
             --base main \
             --head feature/auth-refresh

# Tạo PR với template
gh pr create --template .github/pull_request_template.md

# Xem PRs
gh pr list
gh pr list --state open --assignee @me
gh pr view 123

# Review PR
gh pr review 123 --approve
gh pr review 123 --request-changes --body "Please add error handling"
gh pr review 123 --comment --body "LGTM overall, minor comment below"

# Checkout PR
gh pr checkout 123

# Merge PR
gh pr merge 123 --squash --delete-branch

# Xem status CI
gh pr checks 123

# ===== Tự Động Hoá =====
# Tạo PR và set reviewers, labels, milestone
gh pr create \
  --title "fix: payment calculation bug" \
  --body-file .github/pr_body.md \
  --reviewer alice,bob \
  --label "bug,priority:high" \
  --milestone "v2.1.0" \
  --assignee @me
```

---

## 3. Branch Protection Rules

### 3.1 Cấu Hình Trên GitHub (Settings → Branches)

```yaml
# Protected branch rules cho 'main':

Require a pull request before merging:
  ✓ Require approvals: 2
  ✓ Dismiss stale reviews when new commits pushed
  ✓ Require review from code owners

Require status checks to pass:
  ✓ Require branches to be up to date
  Required checks:
    - ci/test
    - ci/lint  
    - ci/security-scan
    - sonarcloud/quality-gate

Restrict pushes:
  ✓ Restrict who can push to matching branches
  ✓ Block force pushes
  ✓ Do not allow deletions
```

### 3.2 CODEOWNERS File

```bash
# .github/CODEOWNERS
# Định nghĩa ai phải review code của từng khu vực

# Default owner
*                   @company/backend-team

# Frontend
*.tsx               @alice @frontend-team
*.css               @alice @frontend-team
src/components/     @alice @bob

# Infrastructure
*.yml               @devops-team
Dockerfile          @devops-team
k8s/                @devops-team
terraform/          @devops-team

# Security-sensitive
src/auth/           @security-team @alice
src/payments/       @security-team @finance-team
.env.example        @security-team

# Documentation
docs/               @tech-writers
*.md                @tech-writers
```

---

## 4. GitHub Actions - Nâng Cao

### 4.1 Workflow Matrix - Test Nhiều Môi Trường

```yaml
# .github/workflows/test-matrix.yml
name: Test Matrix

on: [push, pull_request]

jobs:
  test:
    strategy:
      fail-fast: false    # Không cancel job khác khi 1 fail
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: ['3.9', '3.10', '3.11', '3.12']
        exclude:
          - os: windows-latest
            python-version: '3.9'
            
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}
          
      - name: Run tests
        run: pytest
```

### 4.2 Reusable Workflows

```yaml
# .github/workflows/reusable-deploy.yml
# Workflow có thể được gọi từ workflow khác
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
    secrets:
      DEPLOY_KEY:
        required: true
      REGISTRY_PASSWORD:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    
    steps:
      - name: Deploy to ${{ inputs.environment }}
        run: |
          ssh -i <(echo "${{ secrets.DEPLOY_KEY }}") \
            deploy@${{ inputs.environment }}.company.com \
            "docker pull myapp:${{ inputs.image-tag }} && \
             docker-compose up -d"
```

```yaml
# .github/workflows/cd.yml
# Gọi workflow trên
name: CD

on:
  push:
    tags: ['v*']

jobs:
  deploy-staging:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      image-tag: ${{ github.sha }}
    secrets:
      DEPLOY_KEY: ${{ secrets.STAGING_DEPLOY_KEY }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
      
  deploy-production:
    needs: deploy-staging
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      image-tag: ${{ github.ref_name }}
    secrets:
      DEPLOY_KEY: ${{ secrets.PROD_DEPLOY_KEY }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```

### 4.3 Environments & Deployment Protection

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.company.com
      # GitHub sẽ yêu cầu manual approval trước khi chạy job này
      # Cấu hình ở Settings → Environments → production → Protection rules
      
    steps:
      - name: Deploy
        run: echo "Deploying to production..."
```

---

## 5. GitLab CI/CD - So Sánh Với GitHub Actions

### 5.1 GitLab CI Cơ Bản

```yaml
# .gitlab-ci.yml

stages:
  - test
  - build
  - deploy

variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# ===== STAGE 1: TEST =====
test:unit:
  stage: test
  image: python:3.11
  services:
    - postgres:15         # Start PostgreSQL container
    - redis:7
  variables:
    DATABASE_URL: "postgresql://postgres:postgres@postgres:5432/testdb"
  before_script:
    - pip install -r requirements.txt
  script:
    - pytest --cov=. --cov-report=xml
  coverage: '/TOTAL.+ ([0-9]{1,3}%)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

test:lint:
  stage: test
  image: python:3.11
  script:
    - pip install flake8 black
    - flake8 .
    - black --check .

# ===== STAGE 2: BUILD =====
build:image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE .
    - docker push $DOCKER_IMAGE
  only:
    - main
    - tags

# ===== STAGE 3: DEPLOY =====
deploy:staging:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://staging.company.com
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_IMAGE -n staging
    - kubectl rollout status deployment/myapp -n staging
  only:
    - main
    
deploy:production:
  stage: deploy
  environment:
    name: production
    url: https://app.company.com
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_IMAGE -n production
  when: manual          # Yêu cầu manual trigger
  only:
    - tags
```

### 5.2 GitLab CI Nâng Cao

```yaml
# Template reuse với anchors YAML
.base_deploy: &base_deploy
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - envsubst < k8s/deployment.yml | kubectl apply -f -
    - kubectl rollout status deployment/myapp -n $NAMESPACE

deploy:staging:
  <<: *base_deploy
  environment: staging
  variables:
    NAMESPACE: staging
    KUBE_CONTEXT: my-cluster/staging
  only:
    - main

deploy:prod:
  <<: *base_deploy
  environment: production
  variables:
    NAMESPACE: production
    KUBE_CONTEXT: my-cluster/production
  when: manual
  only:
    - tags

# Dynamic child pipelines
generate-pipeline:
  stage: test
  script:
    - python generate_pipeline.py > generated-pipeline.yml
  artifacts:
    paths:
      - generated-pipeline.yml

trigger-pipeline:
  trigger:
    include:
      - artifact: generated-pipeline.yml
        job: generate-pipeline
```

---

## 6. Monorepo Strategies

### 6.1 Monorepo Là Gì?

Monorepo = Nhiều projects/services trong 1 Git repository.

```
company-monorepo/
├── services/
│   ├── api/              # Backend API
│   ├── frontend/         # React app
│   ├── auth-service/     # Auth microservice
│   └── payment-service/  # Payment microservice
├── libs/
│   ├── shared-types/     # Shared TypeScript types
│   ├── ui-components/    # Shared UI components
│   └── utils/            # Shared utilities
├── tools/
│   ├── scripts/
│   └── generators/
└── docs/
```

### 6.2 Tools Quản Lý Monorepo

```bash
# ===== NX (JavaScript/TypeScript) =====
npx create-nx-workspace@latest company-repo

# Thêm apps/libs
nx g @nx/next:app frontend
nx g @nx/node:app api
nx g @nx/js:library shared-utils

# Chỉ chạy tasks bị ảnh hưởng bởi thay đổi
nx affected:test
nx affected:build
nx affected:lint

# Dependency graph
nx graph

# ===== TURBOREPO (Vercel) =====
npx create-turbo@latest

# turbo.json
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],   # Build phụ thuộc trước
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": []
    },
    "lint": {
      "outputs": []
    }
  }
}

# Chỉ build/test những gì thay đổi (cache-aware)
turbo run build --filter=[HEAD^1]
turbo run test --filter=./services/api
```

### 6.3 Selective CI với Path Filters

```yaml
# GitHub Actions - Chỉ chạy khi thay đổi trong service đó
name: API Service CI

on:
  push:
    paths:
      - 'services/api/**'
      - 'libs/shared-utils/**'
      - '.github/workflows/api-ci.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/api
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: npm test
```

---

## 7. Git Security Best Practices

### 7.1 Không Bao Giờ Commit Secrets

```bash
# ===== PHÁ T HIỆN SECRETS ĐÃ COMMIT =====

# Dùng gitleaks (phổ biến nhất, không phụ thuộc AWS)
gitleaks detect --source . --verbose
gitleaks detect --source . --report-path gitleaks-report.json

# Dùng truffleHog
trufflehog git https://github.com/company/project.git

# Dùng gitleaks
gitleaks detect --source . --verbose

# ===== XÓA SECRETS ĐÃ COMMIT =====
# CẢNH BÁO: Rewrite history, phải force push, mọi người phải reclone!

# Dùng git-filter-repo (tool mới hơn BFG)
pip install git-filter-repo

# Xóa file chứa secret khỏi toàn bộ lịch sử
git filter-repo --path secrets.env --invert-paths

# Xóa string cụ thể
git filter-repo --replace-text <(echo "AKIAIOSFODNN7EXAMPLE==>REMOVED_API_KEY")

# Dùng BFG Repo Cleaner (nhanh hơn)
bfg --delete-files secrets.env
bfg --replace-text passwords.txt

# Sau khi clean:
git push origin --force --all
git push origin --force --tags

# ĐẶC BIỆT QUAN TRỌNG:
# 1. Revoke tất cả secrets đã lộ NGAY LẬP TỨC
# 2. History rewrite không đủ nếu đã bị cache ở đâu đó
```

### 7.2 Signing Commits

```bash
# Ký commits với GPG key để xác minh danh tính

# Tạo GPG key
gpg --full-generate-key
# Chọn: RSA and RSA, 4096 bits, không expire

# Lấy key ID
gpg --list-secret-keys --keyid-format LONG
# /home/user/.gnupg/pubring.kbx
# sec   rsa4096/ABC123DEF456 2024-01-15 [SC]

# Cấu hình Git dùng GPG key
git config --global user.signingkey ABC123DEF456
git config --global commit.gpgsign true    # Tự động sign
git config --global tag.gpgSign true       # Sign tags

# Upload public key lên GitHub
gpg --armor --export ABC123DEF456
# Copy output vào GitHub → Settings → SSH and GPG keys

# Verify signature
git log --show-signature
git verify-commit HEAD
git verify-tag v1.0.0

# Ký một commit cụ thể (nếu không auto-sign)
git commit -S -m "feat: add authentication"
```

### 7.3 Audit & Compliance

```bash
# Xem ai đã thay đổi dòng code cụ thể
git blame src/auth.py
git blame -L 10,20 src/auth.py    # Chỉ dòng 10-20

# Xem lịch sử thay đổi của function/method
git log -p -S "def authenticate" src/auth.py

# Tạo audit log
git log --format="%H %ae %aI %s" --all > audit.log

# Xem tất cả thay đổi của 1 file theo thời gian
git log --all --follow -p src/payment.py

# Tìm commit đã xóa file
git log --all --full-history -- deleted-file.py
```

---

> **Tiếp theo: Phần 5** - Git Advanced: Internals, Performance, Troubleshooting & Real-World Scenarios
