# 🔀 GIT TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

---

## 1. Git Là Gì? Tại Sao Phải Dùng Git?

### 1.1 Lịch Sử Ra Đời

Git được **Linus Torvalds** tạo ra năm **2005** — cùng người tạo ra Linux kernel — vì lý do:

- Trước đó Linux dùng **BitKeeper** (proprietary) để quản lý source code
- BitKeeper thu hồi license miễn phí → Cần phải tự làm một tool mới
- Linus build Git chỉ trong **10 ngày** với mục tiêu rõ ràng: tốc độ, distributed, integrity

### 1.2 Version Control Là Gì?

**Version Control System (VCS)** là hệ thống theo dõi thay đổi trong codebase theo thời gian.

**Không có VCS:**
```
project_v1.zip
project_v1_final.zip
project_v1_final_REAL.zip
project_v2_newfeature.zip
project_v2_backup_before_deploy.zip
```
→ Chaos, không biết ai thay đổi gì, khi nào, tại sao

**Với Git:**
```
commit a1b2c3d - Add user authentication (Alice, 2024-01-15)
commit b2c3d4e - Fix login bug on mobile (Bob, 2024-01-16)
commit c3d4e5f - Deploy hotfix for SQL injection (Alice, 2024-01-17)
```
→ Lịch sử đầy đủ, ai làm gì, tại sao, rollback bất cứ lúc nào

### 1.3 Các Loại VCS

| Loại | Ví Dụ | Đặc Điểm |
|------|-------|-----------|
| Local VCS | RCS | Chỉ lưu local, không share được |
| Centralized VCS | SVN, CVS | Server trung tâm, mất server = mất tất cả |
| Distributed VCS | **Git**, Mercurial | Mỗi người clone = 1 bản sao đầy đủ |

**Git là Distributed:** Mỗi developer có full copy của toàn bộ repository history → Không cần mạng để làm việc, không có single point of failure.

---

## 2. Kiến Trúc Nội Bộ Git

### 2.1 Git Object Model - Trái Tim Của Git

Git không lưu files theo kiểu "diff/patch" như SVN. Git lưu **snapshots** — ảnh chụp toàn bộ trạng thái tại mỗi thời điểm.

Tất cả dữ liệu Git lưu dưới dạng **Objects** trong thư mục `.git/objects/`. Có 4 loại object:

#### 1. Blob (Binary Large OBject)
- Lưu nội dung file
- Không có tên, không có metadata
- Hash SHA-1 của nội dung

```
# Nội dung file: "Hello World\n"
# SHA-1: 8ab686eafeb1f44702738c8b0f24f2567c36da6d
# Lưu ở: .git/objects/8a/b686eafeb1f44702738c8b0f24f2567c36da6d
```

#### 2. Tree
- Tương đương directory
- Chứa danh sách blobs và trees con
- Mỗi entry: permissions + type + hash + name

```
100644 blob a1b2c3d  README.md
100644 blob d4e5f6g  main.py
040000 tree h7i8j9k  src/
```

#### 3. Commit
- Trỏ đến một Tree (root của project snapshot)
- Chứa: author, committer, timestamp, message, parent commit hash

```
tree   f1e2d3c4b5a6...
parent a1b2c3d4e5f6...  ← Hash của commit trước (parent)
author Alice <alice@example.com> 1705320000 +0700
committer Alice <alice@example.com> 1705320000 +0700

Add user authentication feature
```

#### 4. Tag
- Named pointer đến một commit cụ thể
- Annotated tag có metadata (tagger, date, message)

### 2.2 Content-Addressable Storage

Git dùng **SHA-1 hash** của nội dung làm "địa chỉ" lưu trữ:

```bash
# Xem hash của một chuỗi string
echo -n "Hello World" | git hash-object --stdin
# → 557db03de997c86a4a028e1ebd3a1ceb225be238

# Tất cả objects đều như vậy:
# - Nếu 2 files có nội dung giống nhau → cùng hash → chỉ lưu 1 lần
# - Nếu 1 byte thay đổi → hash hoàn toàn khác → 2 object riêng
```

**Ý nghĩa quan trọng:**
- Git **tự động deduplicate** files giống nhau (tiết kiệm disk)
- Không thể thay đổi lịch sử mà không thay đổi hash (integrity đảm bảo)
- Distributed safe: mọi người verify được tính toàn vẹn

### 2.3 Cấu Trúc Thư Mục .git/

```
.git/
├── HEAD              # Pointer đến branch hiện tại
├── config            # Config của repository
├── description       # Mô tả repo (dùng cho GitWeb)
├── index             # Staging area (binary file)
├── COMMIT_EDITMSG    # Message của commit cuối
├── MERGE_HEAD        # Tồn tại khi đang merge
├── MERGE_MSG         # Message merge
├── objects/          # Tất cả objects (blobs, trees, commits, tags)
│   ├── 8a/
│   │   └── b686eafeb1f44702738c8b0f24f2567c36da6d
│   ├── pack/         # Packed objects (nén để tiết kiệm)
│   └── info/
├── refs/
│   ├── heads/        # Local branches
│   │   ├── main
│   │   └── feature/auth
│   ├── remotes/      # Remote tracking branches
│   │   └── origin/
│   │       ├── main
│   │       └── develop
│   └── tags/         # Tags
│       └── v1.0.0
└── hooks/            # Scripts tự động chạy khi có events
    ├── pre-commit.sample
    ├── post-commit.sample
    └── pre-push.sample
```

### 2.4 Ba Khu Vực Làm Việc Của Git

Đây là khái niệm **QUAN TRỌNG NHẤT** cần hiểu:

```
┌─────────────────┐    git add     ┌─────────────────┐   git commit  ┌─────────────────┐
│  Working Tree   │ ─────────────► │  Staging Area   │ ────────────► │   Repository    │
│                 │                │    (Index)      │               │  (.git/objects) │
│  File thực tế  │ ◄───────────── │                 │               │                 │
│  trên disk     │   git checkout  │  Files đã mark  │               │  Commit history │
│                 │   git restore  │  sẵn sàng commit│               │  (permanent)    │
└─────────────────┘                └─────────────────┘               └─────────────────┘
```

**Working Tree:** Thư mục project thực tế - nơi bạn edit files
**Staging Area (Index):** Khu vực "chờ" - bạn chọn thủ công thay đổi nào sẽ vào commit tiếp theo
**Repository:** Database Git chứa toàn bộ lịch sử

```bash
# Ví dụ minh họa 3 khu vực:

# 1. Tạo file mới - chỉ tồn tại ở Working Tree
echo "Feature X" > feature.txt

# 2. Thêm vào Staging Area
git add feature.txt
# → file.txt giờ "staged" - sẵn sàng commit

# 3. Commit vào Repository
git commit -m "Add feature X"
# → Tạo commit object trong .git/objects/

# Nếu modify feature.txt sau commit:
echo "More changes" >> feature.txt
# Working Tree: đã thay đổi
# Staging Area: vẫn là bản đã commit
# Repository: vẫn là bản đã commit
```

---

## 3. Cài Đặt & Cấu Hình Git

### 3.1 Cài Đặt

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install git -y

# CentOS/RHEL/Rocky
sudo yum install git -y
# Hoặc (RHEL 8+)
sudo dnf install git -y

# macOS
brew install git

# Kiểm tra version
git --version
# git version 2.43.0
```

### 3.2 Cấu Hình Git (git config)

Git có **3 cấp config**:

| Cấp | File | Phạm Vi |
|-----|------|---------|
| `--system` | `/etc/gitconfig` | Toàn bộ hệ thống |
| `--global` | `~/.gitconfig` | Tất cả repos của user |
| `--local` | `.git/config` | Chỉ repo hiện tại |

**Local override Global override System.**

```bash
# ===== CẤU HÌNH BẮT BUỘC =====
git config --global user.name "Tri Pheo"
git config --global user.email "tripheo@company.com"

# ===== CẤU HÌNH QUAN TRỌNG =====
# Default branch name (Git 2.28+)
git config --global init.defaultBranch main

# Editor (dùng khi viết commit message)
git config --global core.editor "vim"
git config --global core.editor "code --wait"  # VS Code
git config --global core.editor "nano"

# Line endings (QUAN TRỌNG khi làm việc cross-platform)
# Linux/Mac:
git config --global core.autocrlf input
# Windows:
git config --global core.autocrlf true

# Merge tool
git config --global merge.tool vimdiff

# Diff tool
git config --global diff.tool vimdiff

# ===== CẤU HÌNH THỰC TẾ DOANH NGHIỆP =====
# Rebase thay vì merge khi pull
git config --global pull.rebase true

# Push chỉ current branch
git config --global push.default current

# Colorize output
git config --global color.ui auto

# Pager (xem log dễ hơn)
git config --global core.pager "less -FX"

# Loại trừ files global (không cần .gitignore trong mỗi project)
git config --global core.excludesfile ~/.gitignore_global

# ===== XEM CẤU HÌNH =====
git config --list                    # Tất cả config
git config --list --show-origin      # Kèm file nguồn
git config --global --list           # Chỉ global
git config user.name                 # Xem 1 giá trị

# ===== FILE ~/.gitconfig =====
cat ~/.gitconfig
# [user]
#     name = Tri Pheo
#     email = tripheo@company.com
# [core]
#     editor = vim
#     autocrlf = input
# [pull]
#     rebase = true
```

### 3.3 .gitignore - Loại Trừ Files Không Cần Track

```bash
# Tạo file .gitignore trong root của project
cat > .gitignore << 'EOF'
# === Thư mục dependencies ===
node_modules/
vendor/
__pycache__/
*.pyc
*.pyo
.venv/
venv/
env/

# === Build artifacts ===
dist/
build/
*.o
*.so
*.exe
*.dll
target/          # Java/Rust

# === IDE files ===
.idea/           # JetBrains
.vscode/         # VS Code
*.swp            # Vim swap
*.swo
.DS_Store        # macOS

# === Environment & Secrets ===
.env
.env.local
.env.*.local
*.key
*.pem
secrets.yml
config/secrets.yml

# === Logs ===
*.log
logs/

# === Database ===
*.sqlite
*.db

# === Test coverage ===
coverage/
.coverage
htmlcov/

# === Terraform ===
*.tfstate
*.tfstate.backup
.terraform/
EOF

# Xem những gì đang bị ignore
git check-ignore -v filename.txt

# Có thể dùng negation (!) để un-ignore
echo "!important.log" >> .gitignore

# Global .gitignore (cho tất cả projects)
cat > ~/.gitignore_global << 'EOF'
.DS_Store
Thumbs.db
*.swp
.idea/
EOF
git config --global core.excludesfile ~/.gitignore_global
```

---

## 4. Luồng Làm Việc Cơ Bản

### 4.1 Khởi Tạo Repository

```bash
# ===== Tạo repo mới =====
mkdir my-project
cd my-project
git init
# Initialized empty Git repository in /path/to/my-project/.git/

# Xem cấu trúc .git mới tạo
ls -la .git/

# ===== Clone repo có sẵn =====
# HTTPS
git clone https://github.com/company/project.git

# SSH (khuyến nghị cho production)
git clone git@github.com:company/project.git

# Clone vào thư mục cụ thể
git clone https://github.com/company/project.git my-local-name

# Clone chỉ 1 branch
git clone -b develop --single-branch https://github.com/company/project.git

# Shallow clone (chỉ lấy N commits gần nhất - tiết kiệm bandwidth)
git clone --depth 10 https://github.com/company/project.git
# → Dùng trong CI/CD để clone nhanh hơn
```

### 4.2 Vòng Lặp Hàng Ngày

```bash
# Quy trình chuẩn trong doanh nghiệp:

# 1. Lấy code mới nhất từ remote
git pull --rebase origin main

# 2. Tạo branch cho feature/fix
git checkout -b feature/user-authentication

# 3. Làm việc... edit files...
vim src/auth.py

# 4. Xem trạng thái
git status

# 5. Xem thay đổi chi tiết
git diff

# 6. Stage thay đổi
git add src/auth.py
git add .          # Tất cả thay đổi (cẩn thận!)
git add -p         # Interactive - chọn từng phần (hunks)

# 7. Commit
git commit -m "Add JWT authentication for user login

- Implement JWT token generation
- Add middleware for token validation  
- Add refresh token logic
- Write unit tests for auth module

Closes #123"

# 8. Push lên remote
git push origin feature/user-authentication

# 9. Tạo Pull Request trên GitHub/GitLab

# 10. Sau khi merge PR, dọn dẹp
git checkout main
git pull --rebase origin main
git branch -d feature/user-authentication
```

### 4.3 git status - Hiểu Trạng Thái File

```bash
git status

# Output giải thích:
# On branch main
# Your branch is up to date with 'origin/main'.
#
# Changes to be committed:           ← Files trong Staging Area
#   (use "git restore --staged <file>..." to unstage)
#         new file:   src/auth.py
#         modified:   README.md
#
# Changes not staged for commit:     ← Files thay đổi nhưng chưa staged
#   (use "git add <file>..." to update what will be committed)
#   (use "git restore <file>..." to discard changes in working directory)
#         modified:   src/main.py
#
# Untracked files:                   ← Files chưa được track bởi Git
#   (use "git add <file>..." to include in what will be committed)
#         logs/debug.log
#         .env

# Xem status ngắn gọn
git status -s
# M  README.md        ← Modified, staged (M ở cột trái)
#  M src/main.py      ← Modified, not staged (M ở cột phải)
# A  src/auth.py      ← Added (new file)
# ?? logs/debug.log   ← Untracked
```

### 4.4 git add - Chi Tiết

```bash
# Add file cụ thể
git add file.txt

# Add tất cả
git add .                  # Tất cả trong thư mục hiện tại
git add -A                 # Tất cả trong toàn repo (cả deletes)

# Interactive mode - chọn từng hunk
git add -p
# Hỏi từng thay đổi:
# y = yes (stage hunk này)
# n = no (bỏ qua hunk này)
# s = split (chia nhỏ hơn)
# e = edit (edit thủ công)
# q = quit

# Thực tế: Bạn edit 1 file nhưng chỉ muốn commit 1 phần
# git add -p giúp bạn commit selective
```

### 4.5 git commit - Viết Commit Message Tốt

```bash
# Commit với message ngắn
git commit -m "Fix login redirect bug"

# Commit với message dài (mở editor)
git commit

# Commit tất cả files đã tracked (skip staging)
git commit -am "Quick fix"
# Lưu ý: không add untracked files

# Sửa commit cuối (chưa push)
git commit --amend -m "Fix login redirect bug on mobile"
git commit --amend --no-edit  # Giữ nguyên message, chỉ thêm file

# ===== FORMAT COMMIT MESSAGE CHUẨN =====
# Conventional Commits (chuẩn phổ biến nhất trong enterprise):

# <type>(<scope>): <short description>
#
# <body>
#
# <footer>

# Types:
# feat:     Tính năng mới
# fix:      Sửa lỗi
# docs:     Chỉ thay đổi docs
# style:    Format, không thay đổi logic
# refactor: Refactor code
# test:     Thêm tests
# chore:    Build process, tooling
# perf:     Cải thiện performance
# ci:       CI/CD changes

# Ví dụ thực tế:
git commit -m "feat(auth): implement JWT refresh token

- Add /api/auth/refresh endpoint
- Store refresh token in HttpOnly cookie
- Implement automatic token rotation
- Add integration tests for token flow

Closes #234
Breaking-Change: Token format changed from v1 to v2"
```

---

## 5. Hiểu Về Branches

### 5.1 Branch Là Gì?

Branch trong Git chỉ là **một file text chứa hash của commit** — cực kỳ nhẹ (chỉ 41 bytes)!

```bash
cat .git/refs/heads/main
# a1b2c3d4e5f6789abc123def456789012345678

# Branch là pointer → commit
# Commit trỏ đến parent commit → tạo thành chain (lịch sử)
```

```
main: ──► C3 ──► C2 ──► C1
                         ▲
                    Initial commit

# Sau khi tạo branch:
git checkout -b feature/login

feature/login: ──► C3 ──► C2 ──► C1
main:          ──► C3 ──► C2 ──► C1
# Cả hai cùng trỏ đến C3 ban đầu

# Commit trên feature branch:
feature/login: ──► C5 ──► C4 ──► C3 ──► C2 ──► C1
main:          ──────────────────► C3 ──► C2 ──► C1
# Diverge!
```

### 5.2 HEAD - Con Trỏ Vị Trí Hiện Tại

```bash
cat .git/HEAD
# ref: refs/heads/main       ← Đang ở branch main

# Sau khi checkout khác:
git checkout feature/login
cat .git/HEAD
# ref: refs/heads/feature/login

# Detached HEAD state (khi checkout đến commit hash):
git checkout a1b2c3d
cat .git/HEAD
# a1b2c3d4e5f6789...         ← Trỏ thẳng đến commit, không qua branch
```

### 5.3 Tạo & Quản Lý Branches

```bash
# Xem branches
git branch              # Local branches
git branch -r           # Remote branches
git branch -a           # Tất cả
git branch -v           # Kèm commit cuối
git branch --merged     # Branches đã merge vào current
git branch --no-merged  # Branches chưa merge

# Tạo branch
git branch feature/search       # Tạo nhưng không switch
git checkout -b feature/search  # Tạo VÀ switch (cách cũ)
git switch -c feature/search    # Tạo VÀ switch (cách mới, Git 2.23+)

# Switch branch
git checkout main
git switch main         # Cách mới

# Xóa branch
git branch -d feature/search    # Xóa (an toàn - từ chối nếu chưa merge)
git branch -D feature/search    # Force xóa (kể cả chưa merge)
git push origin --delete feature/search  # Xóa trên remote

# Rename branch
git branch -m old-name new-name      # Đổi tên branch hiện tại (hoặc chỉ định)
git branch -M main                   # Rename thành main (force)

# Track remote branch
git branch -u origin/develop develop  # Set upstream
```

---

## 6. Branching Strategy Trong Doanh Nghiệp

### 6.1 GitFlow (Traditional)

```
main ─────────────────────────────────────────────── v1.0 ── v1.1 ──►
       ↕ merge                                          ↑
develop ──────────────────────────────────────────────────────────────►
           ↗         ↘merge               ↗
feature/A ────────────              feature/B ──────────
                          ↗ bugfix
hotfix/critical ─────────
```

```
Branches:
- main:     Chỉ production-ready code
- develop:  Integration branch, nơi features gặp nhau
- feature/: Mỗi feature 1 branch
- release/: Chuẩn bị release (QA, bugfix nhỏ)
- hotfix/:  Vá lỗi khẩn cấp trên production
```

### 6.2 GitHub Flow (Đơn Giản Hơn)

```
main ──────────────────────────────────────────────►
           ↗ merge PR        ↗ merge PR
feature/X ─────────   feature/Y ───────
```

**Quy tắc:**
1. Mọi thứ trên `main` deploy được
2. Tạo branch từ main để làm việc
3. Commit thường xuyên, push lên remote
4. Tạo Pull Request khi cần review
5. Merge sau khi review và CI pass
6. Deploy ngay sau khi merge vào main

### 6.3 Trunk-Based Development (TBD - Google, Netflix dùng)

```
main (trunk) ──────────────────────────────────────►
     │  ↖ merge nhanh (< 1 ngày)
     └── feature/short-lived ──►
```

- Tất cả dev commit thẳng vào `main` hoặc branch cực ngắn (< 1 ngày)
- Dùng **Feature Flags** để ẩn tính năng chưa xong
- Yêu cầu CI/CD rất mạnh
- Giảm merge conflict tối đa

---

> **Tiếp theo: Phần 2** - Remote Repositories, Merging, Rebasing & Conflict Resolution
