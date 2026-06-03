---
markmap:
  title: "Git — Tags, Hooks, Workflows & CI/CD"
  collapse: false
---

# 🔀 GIT TOÀN TẬP - PHẦN 3: TAGS, HOOKS, WORKFLOWS & CI/CD

## Theory
- Tags ký phiên bản, hooks tự động hoá kiểm tra, và CI/CD gắn với VCS để tự động build/test/deploy.

## Practice
- Dùng annotated tags cho releases, pre-commit để enforce lint/tests locally, và tích hợp git triggers vào pipeline.

## 1. Git Tags - Đánh Dấu Phiên Bản

### 1.1 Lightweight vs Annotated Tags

```bash
# ===== LIGHTWEIGHT TAG =====
# Chỉ là pointer đến commit, không có metadata
git tag v1.0.0
git tag v1.0.0 a1b2c3d    # Tag commit cụ thể

# ===== ANNOTATED TAG (khuyến nghị) =====
# Là Git object đầy đủ - có tagger, date, message, checksum
git tag -a v1.0.0 -m "Release version 1.0.0"
git tag -a v1.0.0 a1b2c3d -m "Release 1.0.0 - Payment feature"

# Xem tags
git tag
git tag -l "v1.*"          # Filter pattern
git tag -l --sort=-version:refname  # Sort mới nhất trước

# Xem chi tiết annotated tag
git show v1.0.0

# Push tags lên remote
git push origin v1.0.0
git push origin --tags     # Push tất cả local tags
git push origin refs/tags/v1.0.0  # Explicit

# Xóa tag
git tag -d v1.0.0              # Local
git push origin :refs/tags/v1.0.0  # Remote
git push origin --delete v1.0.0    # Remote (cách mới)
```

### 1.2 Semantic Versioning (SemVer) với Git Tags

Chuẩn phổ biến trong enterprise: **MAJOR.MINOR.PATCH**

```
v1.0.0
│ │ └── PATCH: Bug fixes (backward compatible)
│ └──── MINOR: New features (backward compatible)
└────── MAJOR: Breaking changes

v1.0.0-alpha.1    # Alpha build
v1.0.0-beta.2     # Beta build
v1.0.0-rc.1       # Release Candidate
v1.0.0            # Final release
```

```bash
# Workflow release doanh nghiệp:

# 1. Tạo release branch
git checkout -b release/v1.2.0 develop

# 2. Bump version number
sed -i 's/"version": "1.1.0"/"version": "1.2.0"/' package.json
git commit -am "chore: bump version to 1.2.0"

# 3. QA testing, bug fixes...

# 4. Merge vào main
git checkout main
git merge --no-ff release/v1.2.0

# 5. Tag release
git tag -a v1.2.0 -m "Release v1.2.0

Features:
- Add payment gateway integration
- Improve search performance by 40%
- Add dark mode support

Bug fixes:
- Fix login redirect on mobile
- Fix memory leak in WebSocket handler"

# 6. Push tất cả
git push origin main --follow-tags
```


## 2. Git Hooks - Tự Động Hóa

### 2.1 Hooks Là Gì?

Git Hooks là **scripts tự động chạy** khi xảy ra events Git. Nằm ở `.git/hooks/`.

**Client-side hooks:**

| Hook | Khi Nào Chạy | Dùng Để |
|------|-------------|---------|
| `pre-commit` | Trước khi tạo commit | Lint, test, format |
| `prepare-commit-msg` | Sau khi mở editor | Auto-populate message |
| `commit-msg` | Sau khi nhập message | Validate commit format |
| `post-commit` | Sau khi commit xong | Notifications |
| `pre-push` | Trước khi push | Run full tests |
| `post-merge` | Sau khi merge | npm install |
| `pre-rebase` | Trước khi rebase | Warn về nguy hiểm |

**Server-side hooks (trên remote server):**

| Hook | Khi Nào Chạy | Dùng Để |
|------|-------------|---------|
| `pre-receive` | Trước khi nhận push | Validate tất cả |
| `update` | Mỗi branch trong push | Per-branch rules |
| `post-receive` | Sau khi nhận push | Deploy, notifications |

### 2.2 Tạo Hooks Thực Tế

```bash
# ===== PRE-COMMIT: Tự động lint và format =====
cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
set -e

echo "🔍 Running pre-commit checks..."

# 1. Chạy Python linter
if git diff --cached --name-only | grep -q "\.py$"; then
    echo "  → Running flake8..."
    git diff --cached --name-only | grep "\.py$" | xargs flake8 --max-line-length=100
    
    echo "  → Running black (formatter)..."
    git diff --cached --name-only | grep "\.py$" | xargs black --check
fi

# 2. Chạy JavaScript/TypeScript linter
if git diff --cached --name-only | grep -qE "\.(js|ts|jsx|tsx)$"; then
    echo "  → Running ESLint..."
    npx eslint $(git diff --cached --name-only | grep -E "\.(js|ts|jsx|tsx)$")
fi

# 3. Kiểm tra không commit secrets
echo "  → Checking for secrets..."
if git diff --cached | grep -iE "(password|secret|api_key|token)\s*=\s*['\"][^'\"]+['\"]"; then
    echo "❌ Possible secret found in commit! Remove it first."
    exit 1
fi

# 4. Không cho commit .env files
if git diff --cached --name-only | grep -q "^\.env$"; then
    echo "❌ .env file detected in commit!"
    exit 1
fi

echo "✅ All pre-commit checks passed!"
HOOK

chmod +x .git/hooks/pre-commit
```

```bash
# ===== COMMIT-MSG: Validate Conventional Commits =====
cat > .git/hooks/commit-msg << 'HOOK'
#!/bin/bash

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Conventional Commits pattern
PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,100}"

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Expected format: <type>(<scope>): <description>"
    echo "  Types: feat, fix, docs, style, refactor, test, chore, perf, ci"
    echo ""
    echo "Examples:"
    echo "  feat(auth): add JWT refresh token"
    echo "  fix(login): resolve redirect loop on mobile"
    echo "  docs: update API documentation"
    echo ""
    echo "Your message: $COMMIT_MSG"
    exit 1
fi

echo "✅ Commit message format OK"
HOOK

chmod +x .git/hooks/commit-msg
```

```bash
# ===== PRE-PUSH: Chạy tests trước khi push =====
cat > .git/hooks/pre-push << 'HOOK'
#!/bin/bash
set -e

REMOTE=$1
URL=$2

echo "🚀 Running pre-push checks for remote: $REMOTE"

# Không cho push thẳng vào main/master
CURRENT_BRANCH=$(git symbolic-ref HEAD | sed 's/refs\/heads\///')
PROTECTED_BRANCHES="main master production"

for branch in $PROTECTED_BRANCHES; do
    if [ "$CURRENT_BRANCH" = "$branch" ]; then
        echo "❌ Direct push to '$branch' is not allowed!"
        echo "   Please create a Pull Request instead."
        exit 1
    fi
done

# Chạy full test suite
echo "  → Running tests..."
if command -v pytest &> /dev/null; then
    pytest --tb=short -q
elif command -v npm &> /dev/null; then
    npm test -- --watchAll=false
fi

echo "✅ All pre-push checks passed!"
HOOK

chmod +x .git/hooks/pre-push
```

```bash
# ===== POST-MERGE: Auto-install dependencies =====
cat > .git/hooks/post-merge << 'HOOK'
#!/bin/bash

CHANGED_FILES=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD)

# Nếu package.json thay đổi → npm install
if echo "$CHANGED_FILES" | grep -q "package.json"; then
    echo "📦 package.json changed, running npm install..."
    npm install
fi

# Nếu requirements.txt thay đổi → pip install
if echo "$CHANGED_FILES" | grep -q "requirements.txt"; then
    echo "📦 requirements.txt changed, running pip install..."
    pip install -r requirements.txt
fi

# Nếu có migrations → chạy migrate
if echo "$CHANGED_FILES" | grep -q "migrations/"; then
    echo "🗃️  Database migrations detected, running migrate..."
    python manage.py migrate
fi
HOOK

chmod +x .git/hooks/post-merge
```

### 2.3 Husky - Quản Lý Hooks Chuyên Nghiệp

Hooks trong `.git/hooks/` không được commit. Dùng **Husky** để share hooks trong team:

```bash
# Cài đặt
npm install --save-dev husky

# Khởi tạo
npx husky init

# package.json
{
  "scripts": {
    "prepare": "husky"
  }
}

# Tạo hooks
echo "npm test" > .husky/pre-commit
chmod +x .husky/pre-commit

# Kết hợp với lint-staged (chỉ lint files đã staged)
npm install --save-dev lint-staged

# package.json:
{
  "lint-staged": {
    "*.{js,ts,jsx,tsx}": ["eslint --fix", "prettier --write"],
    "*.py": ["black", "flake8"],
    "*.md": ["prettier --write"]
  }
}

# .husky/pre-commit:
#!/bin/sh
npx lint-staged
```


## 3. Git Aliases - Tăng Tốc Độ Làm Việc

```bash
# Cấu hình aliases quan trọng
git config --global alias.st "status -s"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.ci "commit"

# Log đẹp
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.lol "log --oneline --graph --decorate"

# Log với tác giả
git config --global alias.lg2 "log --format='%C(yellow)%h%Creset %C(blue)%an%Creset %C(green)%ar%Creset %s' --graph"

# Unstage file
git config --global alias.unstage "restore --staged"

# Xem stash đẹp
git config --global alias.sl "stash list"

# Undo commit
git config --global alias.undo "reset --soft HEAD~1"

# Push mới (force với lease)
git config --global alias.pushf "push --force-with-lease"

# Xóa branches đã merge
git config --global alias.prune-branches "!git branch --merged main | grep -v 'main' | xargs git branch -d"

# Dùng:
git st          # git status -s
git lg          # Full graph log
git undo        # Undo last commit
git prune-branches  # Dọn branches
```


## 4. Git trong CI/CD

### 4.1 GitHub Actions với Git

```yaml
# .github/workflows/ci.yml

name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
    tags: ['v*.*.*']    # Trigger khi push version tag
  pull_request:
    branches: [main, develop]

jobs:
  # ===== JOB 1: LINT & TEST =====
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0      # Full history (cần cho semantic release)
          
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: pip install -r requirements.txt
        
      - name: Lint
        run: |
          flake8 .
          black --check .
          
      - name: Test
        run: pytest --cov=. --cov-report=xml
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
  
  # ===== JOB 2: BUILD & PUSH IMAGE =====
  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      # Extract version từ git tag
      - name: Get version
        id: version
        run: |
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            VERSION=${GITHUB_REF#refs/tags/}
          else
            VERSION=dev-$(git rev-parse --short HEAD)
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          
      - name: Build Docker image
        run: |
          docker build \
            --build-arg VERSION=${{ steps.version.outputs.version }} \
            -t myapp:${{ steps.version.outputs.version }} \
            .
            
      - name: Push to registry
        run: |
          docker push myapp:${{ steps.version.outputs.version }}
  
  # ===== JOB 3: DEPLOY =====
  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to production
        env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
        run: |
          echo "$DEPLOY_KEY" > /tmp/deploy_key
          chmod 600 /tmp/deploy_key
          ssh -i /tmp/deploy_key deploy@production.company.com \
            "cd /app && git pull && docker-compose up -d"
```

### 4.2 Semantic Release - Tự Động Versioning

```bash
# Cài đặt
npm install --save-dev semantic-release @semantic-release/git @semantic-release/changelog

# .releaserc.json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.md"
    }],
    "@semantic-release/npm",
    ["@semantic-release/git", {
      "assets": ["package.json", "CHANGELOG.md"],
      "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
    }],
    "@semantic-release/github"
  ]
}

# Dựa vào commit type để quyết định version:
# feat: → MINOR (1.0.0 → 1.1.0)
# fix:  → PATCH (1.0.0 → 1.0.1)
# BREAKING CHANGE: → MAJOR (1.0.0 → 2.0.0)
```

### 4.3 Git Operations Trong CI/CD

```bash
# ===== SHALLOW CLONE (Nhanh hơn cho CI) =====
git clone --depth 1 --single-branch --branch main https://github.com/company/project.git

# ===== SỬ DỤNG GITHUB_TOKEN =====
# GitHub Actions tự có GITHUB_TOKEN
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Commit trong CI
git add .
git commit -m "chore: update generated files [skip ci]"
git push https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/company/project.git

# ===== GIT DESCRIBE (Lấy version từ tags) =====
git describe --tags --always
# v1.2.0-5-ga1b2c3d
# = Tag v1.2.0, 5 commits sau, short hash a1b2c3d

git describe --tags --always --dirty
# v1.2.0-5-ga1b2c3d-dirty  → Có uncommitted changes

# ===== TÍCH HỢP GITOPS =====
# ArgoCD GitOps workflow:
# 1. Developer push code
# 2. CI build image với tag = git short SHA
# 3. CI tự động update image tag trong deployment manifest
# 4. Commit manifest repo
# 5. ArgoCD detect thay đổi → sync Kubernetes cluster

# Script cập nhật manifest trong CI:
COMMIT_SHA=$(git rev-parse --short HEAD)
sed -i "s|image: myapp:.*|image: myapp:${COMMIT_SHA}|g" k8s/deployment.yml
git add k8s/deployment.yml
git commit -m "chore: deploy myapp:${COMMIT_SHA}"
git push origin main
```


## 5. Git Submodules & Subtrees

### 5.1 Submodules

```bash
# Dùng khi: Repo A phụ thuộc vào repo B (external dependency)
# Ví dụ: Monorepo với shared library

# Thêm submodule
git submodule add https://github.com/company/shared-lib.git libs/shared-lib

# → Tạo file .gitmodules:
# [submodule "libs/shared-lib"]
#     path = libs/shared-lib
#     url = https://github.com/company/shared-lib.git

# Clone repo có submodules
git clone --recurse-submodules https://github.com/company/project.git
# Hoặc sau khi clone bình thường:
git submodule init
git submodule update

# Update submodules
git submodule update --remote          # Cập nhật tất cả
git submodule update --remote libs/shared-lib  # Cụ thể 1

# Pull trong submodule
cd libs/shared-lib
git pull origin main
cd ../..
git add libs/shared-lib
git commit -m "chore: update shared-lib to latest"

# Xóa submodule
git submodule deinit -f libs/shared-lib
git rm -rf libs/shared-lib
rm -rf .git/modules/libs/shared-lib
```

### 5.2 Git Subtree (Đơn Giản Hơn Submodules)

```bash
# Thêm repo khác vào thư mục con
git subtree add --prefix libs/shared-lib https://github.com/company/shared-lib.git main --squash

# Pull updates từ external repo
git subtree pull --prefix libs/shared-lib https://github.com/company/shared-lib.git main --squash

# Push changes lên external repo
git subtree push --prefix libs/shared-lib https://github.com/company/shared-lib.git main
```


## 6. Tìm Lỗi Nhanh với git bisect

```bash
# Tình huống: Build pass ở v1.0 nhưng fail ở v2.0
# Bisect: Binary search tìm commit gây ra bug

# Bắt đầu bisect
git bisect start

# Đánh dấu commit hiện tại là bad (có bug)
git bisect bad

# Đánh dấu commit cũ là good (chưa có bug)
git bisect good v1.0.0

# Git tự checkout commit giữa và hỏi bạn:
# Bạn test, sau đó:
git bisect good  # Commit này OK
# Hoặc:
git bisect bad   # Commit này có bug

# Git tiếp tục chia đôi... sau vài lần sẽ tìm ra commit gây bug

# Kết thúc
git bisect reset   # Về branch ban đầu

# ===== AUTO BISECT =====
# Viết script test tự động:
cat > /tmp/test.sh << 'EOF'
#!/bin/bash
# Return 0 = good, non-zero = bad
npm test -- --testNamePattern="payment module"
EOF
chmod +x /tmp/test.sh

git bisect start
git bisect bad HEAD
git bisect good v1.0.0
git bisect run /tmp/test.sh
# → Tự động tìm commit bad!
```


## 7. Git Large File Storage (LFS)

```bash
# Dùng khi track files lớn: videos, datasets, binaries

# Cài đặt
git lfs install

# Track loại file
git lfs track "*.mp4"
git lfs track "*.psd"
git lfs track "datasets/*.csv"

# → Tạo .gitattributes:
# *.mp4 filter=lfs diff=lfs merge=lfs -text
# *.psd filter=lfs diff=lfs merge=lfs -text

# Commit .gitattributes
git add .gitattributes
git commit -m "chore: configure git lfs for media files"

# Từ đây, files lớn được lưu trên LFS server
# Git repo chỉ lưu pointer đến file

# Xem files đang trong LFS
git lfs ls-files

# Pull LFS files
git lfs pull
```
