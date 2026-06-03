---
markmap:
  title: "Git — Internals & Troubleshooting"
  collapse: false
---

# 🔀 GIT TOÀN TẬP - PHẦN 5: ADVANCED INTERNALS, TROUBLESHOOTING & SCENARIOS THỰC TẾ

## Theory
- Git object model (blobs, trees, commits, refs), packfiles và GC ảnh hưởng tới storage và performance.

## Practice
- Thực hành: `git fsck`, `git reflog`, recover commits, inspect packfiles, and use `git gc`/shallow clones for CI optimization.

# 🔀 GIT TOÀN TẬP - PHẦN 5: ADVANCED INTERNALS, TROUBLESHOOTING & SCENARIOS THỰC TẾ


## 1. Git Internals - Đào Sâu Bên Trong

### 1.1 Packfiles - Cách Git Nén Dữ Liệu

```bash
# Ban đầu, Git lưu objects riêng lẻ (loose objects)
ls .git/objects/
# 8a/  b2/  c3/  ...

# Khi repo lớn hoặc khi push, Git tạo packfiles
git gc              # Garbage collect và pack
git gc --aggressive # Pack mạnh hơn (chậm hơn, nhỏ hơn)

# Xem packfiles
ls .git/objects/pack/
# pack-abc123.idx   ← Index file (tìm kiếm nhanh)
# pack-abc123.pack  ← Actual data

# Xem nội dung pack
git verify-pack -v .git/objects/pack/pack-*.idx | head -20
# SHA-1              type  size  delta

# Thống kê kích thước
git count-objects -vH
# count: 15          ← Số loose objects
# size: 32.00 KiB    ← Size loose objects
# in-pack: 1203      ← Objects trong packfile
# packs: 2           ← Số packfiles
# size-pack: 2.50 MiB ← Size packfiles

# Xem objects lớn nhất trong lịch sử
git rev-list --objects --all |
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
  awk '/^blob/ {print substr($0,6)}' |
  sort --numeric-sort --key=2 --reverse |
  head -10 |
  column -ts ' '
```

### 1.2 Plumbing Commands - Lệnh Cấp Thấp

```bash
# ===== HASH-OBJECT: Tạo object từ dữ liệu =====
echo "Hello Git" | git hash-object --stdin
# b7aec520dec0a7516c18eb4c68b64ae1eb9b5a5e

# Tạo và lưu object
echo "Hello Git" | git hash-object --stdin -w
# → Lưu vào .git/objects/

# ===== CAT-FILE: Đọc nội dung object =====
git cat-file -t a1b2c3d   # type (blob, tree, commit, tag)
git cat-file -s a1b2c3d   # size
git cat-file -p a1b2c3d   # pretty-print nội dung

# Xem nội dung commit
git cat-file -p HEAD
# tree f1e2d3c4b5...
# parent b2c3d4e5f6...
# author Tri Pheo <tripheo@company.com> 1705320000 +0700
# committer Tri Pheo <tripheo@company.com> 1705320000 +0700
#
# Add authentication feature

# Xem tree
git cat-file -p HEAD^{tree}
# 100644 blob a1b2c3d README.md
# 040000 tree b2c3d4e src

# ===== LS-TREE: Xem tree =====
git ls-tree HEAD
git ls-tree -r HEAD          # Recursive
git ls-tree HEAD src/        # Chỉ thư mục src

# ===== LS-FILES: Xem staged files =====
git ls-files                 # Files trong index (staged)
git ls-files --others        # Untracked files
git ls-files --deleted       # Deleted files
git ls-files --modified      # Modified files
git ls-files -s              # Kèm mode, SHA, stage number

# ===== UPDATE-INDEX: Thao tác staging area trực tiếp =====
# Assume unchanged (performance trick cho file không cần track)
git update-index --assume-unchanged large-data-file.bin
# Unset:
git update-index --no-assume-unchanged large-data-file.bin

# Skip worktree (khác với assume-unchanged)
git update-index --skip-worktree config/local.yml
```

### 1.3 Reflog - Cơ Chế An Toàn Tối Thượng

```bash
# Reflog ghi lại TẤT CẢ thay đổi của HEAD và mỗi branch
# Tồn tại trong 90 ngày mặc định

git reflog
# a1b2c3d HEAD@{0}: commit: Add payment feature
# b2c3d4e HEAD@{1}: checkout: moving from main to feature/payment
# c3d4e5f HEAD@{2}: reset: moving to HEAD~2
# d4e5f6g HEAD@{3}: commit: Fix login bug

# Reflog cho branch cụ thể
git reflog show main
git reflog show feature/login

# Khôi phục commit bị mất
git reset --hard HEAD@{3}
git checkout -b rescued-branch HEAD@{5}

# Cấu hình retention
git config gc.reflogExpire 180.days        # Giữ 180 ngày
git config gc.reflogExpireUnreachable 30.days

# Xem reflog với thời gian
git reflog --date=iso
```


## 2. Troubleshooting - Xử Lý Vấn Đề Thực Tế

### 2.1 Xử Lý Lỗi Merge Conflict Phức Tạp

```bash
# ===== TÌNH HUỐNG: Conflict trong file binary =====
# Git không thể merge binary files (images, PDFs, etc.)
git merge feature/ui
# CONFLICT (content): Merge conflict in public/logo.png

# Chọn version của mình
git checkout --ours public/logo.png
git add public/logo.png

# Chọn version của branch khác
git checkout --theirs public/logo.png
git add public/logo.png

# ===== TÌNH HUỐNG: Abort merge sau khi mess up =====
git merge --abort

# ===== TÌNH HUỐNG: Conflict sau rebase =====
git rebase main
# CONFLICT in src/auth.py

# Resolve conflict...
vim src/auth.py
git add src/auth.py
git rebase --continue

# Hoặc skip commit này
git rebase --skip

# Hoặc abort toàn bộ
git rebase --abort

# ===== TÌNH HUỐNG: Xem 3-way diff để hiểu rõ conflict =====
# BASE = commit ancestor chung
# OURS = HEAD hiện tại
# THEIRS = branch đang merge/rebase vào

git checkout --conflict=diff3 conflicted-file.py
# <<<<<<< ours
# our version
# ||||||| base
# base (common ancestor) version  ← diff3 mode thêm phần này
# =======
# their version
# >>>>>>> theirs
```

### 2.2 Xử Lý Repository Bị Lỗi

```bash
# ===== CORRUPT OBJECTS =====
git fsck                      # File System Consistency Check
git fsck --unreachable        # Tìm objects không có reference
git fsck --lost-found         # Tìm "lost" commits

# Output:
# Checking object directories: 100%
# error: object file .git/objects/ab/c123... is empty
# error: loose object abc123 (stored in .git/objects/ab/c123) is corrupt

# Sửa corrupt object (nếu có backup/remote)
git fetch origin
git reset --hard origin/main

# ===== DETACHED HEAD =====
cat .git/HEAD
# abc123def456...    ← Không phải "ref: refs/heads/..."

# Giải pháp:
git checkout main
# Hoặc tạo branch từ detached HEAD:
git checkout -b my-work

# ===== KHÔNG THỂ PUSH VÌ NON-FAST-FORWARD =====
git push origin main
# ! [rejected] main -> main (non-fast-forward)
# Remote có commits local chưa có

# Giải pháp đúng:
git pull --rebase origin main    # Lấy về và rebase
git push origin main             # Push lại

# KHÔNG làm:
# git push --force               # Có thể xóa work của người khác!
# → Dùng --force-with-lease nếu bắt buộc:
git push --force-with-lease origin main

# ===== BRANCH BỊ XÓA NHẦM =====
# Tìm hash của branch vừa xóa
git reflog | grep "feature/important"
# abc123 HEAD@{5}: checkout: moving from feature/important to main

# Tạo lại branch
git checkout -b feature/important abc123

# ===== COMMIT VÀO SAI BRANCH =====
# Commit đang ở main, đáng lẽ phải ở feature/new-thing

# 1. Tạo branch mới từ current state
git branch feature/new-thing

# 2. Reset main về trước commit đó
git reset --hard HEAD~1

# 3. Switch sang branch mới
git checkout feature/new-thing
# → Commit giờ đã ở đúng branch!
```

### 2.3 Performance Issues

```bash
# ===== REPO CLONE QUÁ CHẬM =====
# Vấn đề: Có large files trong lịch sử

# 1. Shallow clone (CI/CD)
git clone --depth 1 https://github.com/company/project.git

# 2. Dùng Git LFS
git lfs migrate import --include="*.psd,*.zip,*.mp4" --everything

# 3. Partial clone (Git 2.22+)
git clone --filter=blob:none https://github.com/company/project.git
# → Chỉ download blob khi cần

git clone --filter=tree:0 https://github.com/company/project.git
# → Chỉ download tree khi cần (treeless clone)

# ===== GIT STATUS/ADD QUÁ CHẬM =====
# Vấn đề: Repo quá nhiều files (e.g., node_modules chưa gitignore)

# 1. Dùng Git's built-in FSMonitor
git config core.fsmonitor true          # Built-in (Git 2.37+)
git config core.untrackedCache true     # Cache untracked files

# 2. Kích hoạt Watchman (nhanh hơn)
git config core.fsmonitor "watchman-wait -p . -t 1 -- HEAD@{1}"

# 3. Kiểm tra .gitignore đúng chưa
git check-ignore -v node_modules

# ===== GIT LOG QUÁ CHẬM =====
git log --max-count=100          # Giới hạn số commits
git log --since="1 month ago"    # Giới hạn theo thời gian
```


## 3. Advanced Scenarios Thực Tế

### 3.1 Scenario: Rollback Production Deployment

```bash
# ===== TÌNH HUỐNG =====
# Deploy v2.0 lên production, nhưng có bug nghiêm trọng
# Cần rollback về v1.9 NGAY LẬP TỨC

# Cách 1: Git Revert (an toàn, không rewrite history)
git log --oneline -5
# abc123 feat: deploy v2.0 payment overhaul     ← BUG Ở ĐÂY
# bcd234 fix: minor UI tweaks
# cde345 feat: v1.9 stable
# def456 fix: login bug

git revert abc123
# Tạo commit mới đảo ngược abc123
git push origin main
# → Deploy commit revert này

# Cách 2: Reset + Force Push (nhanh nhưng rewrite history)
git reset --hard cde345      # Về v1.9
git push --force-with-lease origin main
# ⚠️ Nhớ thông báo cho toàn team TRƯỚC KHI làm!

# Cách 3: Deploy tag cũ (production practice tốt nhất)
git checkout v1.9.0
# CI/CD sẽ tự deploy từ tag này

# ===== KUBERNETES ROLLBACK =====
# Nếu dùng k8s, rollback thông qua kubectl
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=3
```

### 3.2 Scenario: Squash Commits Trước Khi Merge PR

```bash
# ===== TÌNH HUỐNG =====
# Branch feature/payment có 15 commits WIP
# Cần gộp thành 3 commits có nghĩa trước khi merge

git log --oneline feature/payment
# abc123 fix test
# bcd234 WIP
# cde345 more WIP
# def456 forgot to add file
# efg567 WIP payment
# fgh678 add payment tests
# ... (15 commits)

# Interactive rebase để squash
git checkout feature/payment
git rebase -i origin/main

# Editor mở:
# pick abc123 fix test
# pick bcd234 WIP
# pick cde345 more WIP
# ...

# Sửa thành:
# pick abc123 feat: implement Stripe payment integration
# squash bcd234 WIP
# squash cde345 more WIP
# squash def456 forgot to add file
# squash efg567 WIP payment
# pick fgh678 test: add payment integration tests
# squash ... (rest of test commits)
# pick xyz890 docs: add payment API documentation

# Kết quả: 3 commits gọn gàng

# Push (cần force vì rewrite history)
git push --force-with-lease origin feature/payment
```

### 3.3 Scenario: Tách Repository Với Lịch Sử Đầy Đủ

```bash
# ===== TÌNH HUỐNG =====
# Monorepo có services/payment-service/
# Muốn tách thành repo riêng, giữ nguyên git history

# Dùng git filter-repo
pip install git-filter-repo

# Clone repo gốc
git clone --mirror https://github.com/company/monorepo.git payment-repo
cd payment-repo

# Chỉ giữ lại thư mục services/payment-service/
git filter-repo --subdirectory-filter services/payment-service/

# Kết quả: Repo mới chỉ có commits liên quan đến payment-service
# Và lịch sử được "rewritten" để paths không có prefix services/payment-service/

# Push lên remote mới
git remote add origin https://github.com/company/payment-service.git
git push origin --all
git push origin --tags
```

### 3.4 Scenario: Git Worktree - Làm Việc Nhiều Branches Đồng Thời

```bash
# ===== VẤN ĐỀ =====
# Đang làm feature/A, cần switch sang hotfix/bug nhưng có uncommitted changes

# Thay vì stash, dùng Git Worktree:
# Mỗi worktree = 1 thư mục làm việc riêng biệt, cùng 1 repo

# Tạo worktree mới cho hotfix
git worktree add ../project-hotfix hotfix/critical-bug
cd ../project-hotfix
# → Đang ở branch hotfix/critical-bug, thư mục khác!

# Fix bug, commit, push
git commit -am "fix: critical payment bug"
git push origin hotfix/critical-bug

# Quay lại feature đang làm dở
cd ../project
# → Vẫn ở feature/A với tất cả changes còn đó!

# Quản lý worktrees
git worktree list
# /home/user/project          abc123 [feature/A]
# /home/user/project-hotfix   bcd234 [hotfix/critical-bug]

git worktree remove ../project-hotfix
git worktree prune     # Dọn metadata

# Dùng trong CI: Build nhiều versions đồng thời
git worktree add /tmp/build-v1 v1.9.0
git worktree add /tmp/build-v2 v2.0.0

cd /tmp/build-v1 && npm run build &
cd /tmp/build-v2 && npm run build &
wait
```

### 3.5 Scenario: Git Grep - Tìm Kiếm Trong Toàn Bộ Lịch Sử

```bash
# Tìm string trong toàn bộ lịch sử Git (tất cả commits)
git grep "password" $(git rev-list --all)

# Tìm trong lịch sử của 1 file
git log -p --all -S "API_KEY" -- src/config.py

# Tìm commit đã introduce 1 dòng code cụ thể
git log -S "def authenticate_user" --diff-filter=A src/auth.py

# Tìm commit đã xóa function
git log -S "def old_payment_method" --diff-filter=D

# Tìm thay đổi trong thư mục theo thời gian
git log --all --stat -- "services/payment/**" | grep -E "^commit|\.py"
```


## 4. Git Configuration Nâng Cao

### 4.1 Conditional Config (Nhiều Profile)

```bash
# ~/.gitconfig - Switch profile theo thư mục
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work

[includeIf "gitdir:~/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/opensource/"]
    path = ~/.gitconfig-opensource

# ~/.gitconfig-work
[user]
    name = Tri Pheo
    email = tripheo@company.com
    signingkey = ABCDEF123456
[commit]
    gpgsign = true

# ~/.gitconfig-personal
[user]
    name = tripheo
    email = personal@gmail.com
[commit]
    gpgsign = false
```

### 4.2 URL Rewriting

```bash
# ~/.gitconfig
[url "git@github.com:"]
    insteadOf = https://github.com/
# → Tất cả clone HTTPS tự chuyển thành SSH

[url "git@gitlab.company.com:"]
    insteadOf = https://gitlab.company.com/
# → Internal GitLab dùng SSH
```

### 4.3 Git Attributes Chi Tiết

```bash
# .gitattributes - Cấu hình per-file

# Line endings
*.bat           text eol=crlf    # Windows line endings
*.sh            text eol=lf      # Unix line endings
*.py            text eol=lf
Makefile        text eol=lf

# Binary files (không diff, không merge)
*.png           binary
*.jpg           binary
*.pdf           binary
*.zip           binary

# Custom diff driver
*.json          diff=json
*.md            diff=markdown

# Không export file này khi dùng git archive
.gitignore      export-ignore
.gitattributes  export-ignore
tests/          export-ignore

# LFS tracking
*.psd           filter=lfs diff=lfs merge=lfs -text

# Linguistics (GitHub language detection)
vendor/**       linguist-vendored
*.min.js        linguist-generated=true
docs/           linguist-documentation
```


## 5. Cheat Sheet Tổng Hợp

### 5.1 Commands Theo Tần Suất Dùng

```bash
# ============================================
# 🔥 HÀNG NGÀY
# ============================================
git status -s
git diff
git diff --staged
git add -p                    # Interactive staging
git commit -m "type: message"
git push origin branch-name
git pull --rebase origin main
git log --oneline -10
git stash / git stash pop

# ============================================
# 📅 HÀNG TUẦN
# ============================================
git branch -a
git checkout -b feature/xxx
git rebase -i HEAD~5          # Clean up commits
git cherry-pick commit-hash
git log --oneline --graph --all
git tag -a v1.x.x -m "Release"

# ============================================
# 🚑 KHI GẶP SỰ CỐ
# ============================================
git reflog                    # Tìm commits "bị mất"
git reset --hard HEAD~1       # Undo commit (chưa push)
git revert HEAD               # Undo commit (đã push)
git bisect start/good/bad     # Tìm commit gây bug
git fsck                      # Check repo integrity
git stash branch recovery     # Recover từ stash
```

### 5.2 Flow Quyết Định Khi Có Vấn Đề

```
Muốn hoàn tác thay đổi?
├── Chưa add (working tree)?
│   └── git restore <file>
├── Đã add (staged)?
│   └── git restore --staged <file>
├── Đã commit, chưa push?
│   ├── Sửa commit cuối? → git commit --amend
│   ├── Undo commit (giữ changes)? → git reset --soft HEAD~1
│   └── Undo commit (bỏ changes)? → git reset --hard HEAD~1
└── Đã push?
    └── git revert HEAD    ← AN TOÀN NHẤT

Commit bị mất?
└── git reflog → tìm hash → git checkout -b recovery <hash>

Merge conflict?
├── Giải quyết thủ công → git add → git commit
├── Bỏ conflict → git merge --abort
└── Dùng version của mình/họ → git checkout --ours/--theirs <file>
```


## 6. Git Trong Môi Trường Doanh Nghiệp

### 6.1 Self-Hosted Git Servers

```bash
# ===== GITEA (Lightweight, Go) =====
# Docker compose setup
version: '3'
services:
  gitea:
    image: gitea/gitea:latest
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=db:5432
    volumes:
      - ./gitea-data:/data
    ports:
      - "3000:3000"
      - "222:22"
    depends_on:
      - db
  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=gitea
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=gitea

# ===== GITLAB CE (Full-featured) =====
# Cài đặt trên Ubuntu
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
sudo EXTERNAL_URL="https://gitlab.company.com" apt install gitlab-ce

# Backup
sudo gitlab-backup create
sudo gitlab-rake gitlab:backup:create

# Restore
sudo gitlab-backup restore BACKUP=timestamp_of_backup
```

### 6.2 Git Governance Policies

```yaml
# Ví dụ: Branch policy cho doanh nghiệp

# main branch:
# - Protected: YES
# - Direct push: NEVER
# - Requires: 2 approvals + CI green + up-to-date
# - Auto-delete head branch after merge: YES

# develop branch:
# - Protected: YES
# - Direct push: Tech leads only
# - Requires: 1 approval + CI green

# release/* branches:
# - Protected: YES
# - Direct push: Release managers only
# - Requires: Tech lead + QA sign-off

# feature/*, bugfix/*, hotfix/*:
# - Not protected
# - Anyone can push
# - Must create PR to merge

# hotfix/* branches:
# - Merge vào main VÀ develop
# - Được phép push nếu on-call engineer
```

### 6.3 Metrics & Monitoring

```bash
# ===== ĐO LƯỜNG TEAM PERFORMANCE =====

# DORA Metrics từ Git:

# 1. Deployment Frequency
git log --oneline --since="30 days ago" origin/main | wc -l
# → Số lần deploy trong 30 ngày

# 2. Lead Time for Changes (time from commit to deploy)
# = Thời gian từ first commit → production deploy

# 3. Change Failure Rate
# = % deploys gây ra rollback/hotfix
git log --oneline origin/main | grep -c "hotfix\|revert"

# 4. Mean Time to Recovery
# = Thời gian trung bình từ khi incident → resolved

# Script lấy PR metrics
gh pr list --state merged --limit 100 --json mergedAt,createdAt,title | \
  jq '[.[] | {
    title: .title,
    lead_time_hours: ((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600
  }]'
```


> **Hoàn thành Git Toàn Tập!** Phần tiếp theo: Network Fundamentals
