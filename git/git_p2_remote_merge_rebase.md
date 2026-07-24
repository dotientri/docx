# 🔀 GIT TOÀN TẬP - PHẦN 2: REMOTE, MERGE, REBASE & CONFLICT


---
markmap:
    title: "Git — Remote, Merge, Rebase & Workflow"
    collapse: false
---

# GIT: REMOTE, MERGE, REBASE & WORKFLOW

## Theory
 - Remote workflows (origin, upstream), merge commits vs rebase, and branching strategies (Git Flow, trunk-based) determine collaboration model.

## Practice
 - Thực hành: fetch/pull, push, resolving merge conflicts, rebase interactive, and preserving history for code review.

## 1. Remote Repositories

### 1.1 Remote Là Gì?

Remote là **bản sao của repository trên server khác** (GitHub, GitLab, Bitbucket, self-hosted). Remote cho phép:
- Backup code
- Collaboration (nhiều người cùng làm)
- CI/CD integration
- Deployment

```bash
# Xem danh sách remotes
git remote
# origin

git remote -v
# origin  git@github.com:company/project.git (fetch)
# origin  git@github.com:company/project.git (push)

# Thêm remote
git remote add origin git@github.com:company/project.git
git remote add upstream git@github.com:original/project.git  # Forked repo

# Đổi tên remote
git remote rename origin github

# Xóa remote
git remote remove upstream

# Đổi URL remote
git remote set-url origin git@github.com:company/new-project.git

# Xem chi tiết remote
git remote show origin
```

### 1.2 SSH vs HTTPS

#### HTTPS
```bash
git clone https://github.com/company/project.git
# Cần username + password/token mỗi lần
# Dùng credential cache:
git config --global credential.helper cache        # Cache 15 phút
git config --global credential.helper store        # Lưu vĩnh viễn (kém bảo mật)
git config --global credential.helper 'cache --timeout=3600'  # Cache 1 giờ
```

## SSH (khuyến nghị cho production)
```bash
# 1. Tạo SSH key pair
ssh-keygen -t ed25519 -C "tripheo@company.com"
# → Tạo ~/.ssh/id_ed25519 (private key - KHÔNG SHARE)
# → Tạo ~/.ssh/id_ed25519.pub (public key - upload lên GitHub)

# 2. Copy public key
cat ~/.ssh/id_ed25519.pub
# Paste vào GitHub → Settings → SSH Keys

# 3. Test kết nối
ssh -T git@github.com
# Hi tripheo! You've successfully authenticated...

# 4. Clone với SSH
git clone git@github.com:company/project.git

# ===== NHIỀU SSH KEYS (nhiều tài khoản) =====
# ~/.ssh/config
cat > ~/.ssh/config << 'EOF'
# Tài khoản công ty
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work

# Tài khoản cá nhân
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
EOF

# Dùng:
git clone git@github-work:company/project.git
git clone git@github-personal:myusername/myproject.git
```

### 1.3 Fetch, Pull, Push

```bash
# ===== GIT FETCH =====
# Lấy data từ remote nhưng KHÔNG merge vào working tree
git fetch origin
git fetch --all          # Fetch tất cả remotes
git fetch origin main    # Chỉ fetch branch main

# Sau khi fetch, xem những gì thay đổi
git log origin/main ^main --oneline
# → Commits trên remote chưa có local

git diff main origin/main
# → Thay đổi giữa local main và remote main

# ===== GIT PULL =====
# = git fetch + git merge (hoặc git fetch + git rebase)
git pull
git pull origin main
git pull --rebase origin main  # Dùng rebase thay vì merge (sạch hơn)

# Pull với fast-forward only (từ chối nếu cần merge commit)
git pull --ff-only

# ===== GIT PUSH =====
git push origin main
git push                       # Nếu đã set upstream

# Push và set upstream (lần đầu push branch mới)
git push -u origin feature/login
# -u = --set-upstream

# Force push (NGUY HIỂM - chỉ dùng khi cần)
git push --force
git push --force-with-lease    # Safer: từ chối nếu remote đã có commits mới
# --force-with-lease là chuẩn dùng trong team

# Push tất cả branches
git push --all origin

# Push tags
git push origin v1.0.0
git push origin --tags         # Push tất cả tags
```

### 1.4 Remote Tracking Branches

```bash
# Remote tracking branches là local copies của remote branches
# Format: origin/branchname

git branch -r
# origin/main
# origin/develop
# origin/feature/payment

# Chúng KHÔNG tự động update - cần fetch để sync
git fetch origin

# Xem ai đang ở đâu
git log --oneline --decorate
# a1b2c3d (HEAD -> main, origin/main) Latest commit
# b2c3d4e Previous commit

# Create local branch từ remote tracking branch
git checkout -b develop origin/develop
git switch -c develop origin/develop  # Cách mới
```


## 2. Merging - Kết Hợp Branches

### 2.1 Fast-Forward Merge

Khi không có divergence (branch đích không có commits mới hơn source):

```
Before:
main:    A ─── B
                └── feature: C ─── D

After fast-forward merge:
main:    A ─── B ─── C ─── D
                           HEAD
```

```bash
git checkout main
git merge feature/login
# Updating a1b2c3d..d4e5f6g
# Fast-forward
#  src/login.py | 50 ++++++++++++
# 1 file changed, 50 insertions(+)
```

### 2.2 Three-Way Merge (Merge Commit)

Khi cả hai branches đều có commits mới:

```
Before:
main:    A ─── B ─── C
          └── feature: D ─── E

After 3-way merge:
main:    A ─── B ─── C ─── M (merge commit)
          └── feature: D ─── E ───┘
```

```bash
git checkout main
git merge feature/payment
# Merge made by the 'ort' strategy.
# → Tạo merge commit M với 2 parents: C và E
```

### 2.3 Merge Options

```bash
# No fast-forward - luôn tạo merge commit (dễ track lịch sử)
git merge --no-ff feature/login
git merge --no-ff -m "Merge feature/login: JWT authentication" feature/login

# Squash merge - gộp tất cả commits của branch thành 1
git merge --squash feature/wip-stuff
git commit -m "Add experimental feature"
# → Không tạo merge commit, không link branch history

# Abort merge (nếu có conflict chưa giải quyết)
git merge --abort
```

### 2.4 Conflict Resolution

Conflict xảy ra khi **cùng một vùng code** bị sửa ở cả hai branches:

```bash
git merge feature/payment
# CONFLICT (content): Merge conflict in src/checkout.py
# Automatic merge failed; fix conflicts and then commit the result.

# Xem files có conflict
git status
# both modified:   src/checkout.py

# Mở file conflict
cat src/checkout.py
```

```python
<<<<<<< HEAD (current change - bên mình)
def process_payment(amount):
    return stripe.charge(amount, currency="USD")
=======
def process_payment(amount, currency="VND"):
    return paypal.charge(amount, currency=currency)
>>>>>>> feature/payment (incoming change - bên kia)
```

```bash
# Giải quyết: Sửa file thủ công
vim src/checkout.py
# Quyết định giữ cái nào, hoặc kết hợp cả hai:

# Sau khi edit:
# def process_payment(amount, currency="USD"):
#     if settings.PAYMENT_PROVIDER == "stripe":
#         return stripe.charge(amount, currency=currency)
#     else:
#         return paypal.charge(amount, currency=currency)

# Stage file đã resolve
git add src/checkout.py

# Hoàn thành merge
git commit
# → Mở editor để viết merge commit message

# ===== DÙNG MERGE TOOL =====
git mergetool
# Mở vimdiff hoặc tool đã cấu hình

# Sau khi resolve:
git mergetool --tool=vimdiff src/checkout.py

# ===== DÙNG VS CODE =====
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
git mergetool
```


## 3. Rebasing - Viết Lại Lịch Sử

### 3.1 Rebase Là Gì?

Rebase = "**di chuyển** base của branch đến một commit khác"

```
Before rebase:
main:    A ─── B ─── C
          └── feature: D ─── E

After: git rebase main (trên branch feature)
main:    A ─── B ─── C
                       └── feature: D' ─── E'
# D và E được "replay" lại trên đỉnh C
# Tạo commits mới D' và E' (hash mới, nội dung giống)
```

### 3.2 Rebase vs Merge

```bash
# ===== MERGE - Giữ nguyên lịch sử =====
git checkout main
git merge feature/login

# Log sau merge:
git log --oneline --graph
# *   f1e2d3c Merge branch 'feature/login'
# |\
# | * d4e5f6g Add logout functionality
# | * c3d4e5f Add login form
# * b2c3d4e Update README
# * a1b2c3d Initial commit

# ===== REBASE - Lịch sử tuyến tính =====
git checkout feature/login
git rebase main
git checkout main
git merge feature/login  # Fast-forward

git log --oneline --graph
# * d4e5f6g Add logout functionality
# * c3d4e5f Add login form
# * b2c3d4e Update README
# * a1b2c3d Initial commit
# → Clean, linear history!
```

**Khi nào dùng Merge vs Rebase:**

| Tình huống | Nên Dùng |
|-----------|----------|
| Merge feature vào main | Merge --no-ff |
| Update feature branch với main mới nhất | Rebase |
| Public/shared branch | Merge (KHÔNG rebase) |
| Local branch chưa push | Rebase thoải mái |
| Muốn linear history | Rebase |
| Muốn track feature explicitly | Merge |

### 3.3 Interactive Rebase - Viết Lại Lịch Sử

**Interactive rebase** cho phép edit, squash, reorder, drop commits.

```bash
# Rebase 5 commits gần nhất
git rebase -i HEAD~5

# Mở editor hiển thị:
# pick a1b2c3d Fix typo in login form
# pick b2c3d4e Add login validation
# pick c3d4e5f WIP - auth in progress
# pick d4e5f6g Fix auth bug
# pick e5f6g7h Add tests for auth

# Lệnh có thể dùng:
# pick (p)   = Giữ nguyên commit
# reword (r) = Giữ commit, sửa message
# edit (e)   = Dừng lại để sửa commit
# squash (s) = Gộp vào commit trên (giữ messages)
# fixup (f)  = Gộp vào commit trên (bỏ message của commit này)
# drop (d)   = Xóa commit

# Ví dụ - gộp 5 commits thành 1 commit gọn:
# pick a1b2c3d Fix typo in login form
# squash b2c3d4e Add login validation
# squash c3d4e5f WIP - auth in progress
# squash d4e5f6g Fix auth bug
# squash e5f6g7h Add tests for auth

# → Tạo 1 commit duy nhất với combined message

# Ví dụ - đổi thứ tự:
# pick e5f6g7h Add tests for auth    ← Di lên đầu
# pick a1b2c3d Fix typo in login form
# pick b2c3d4e Add login validation

# ===== THỰC TẾ: Dọn dẹp branch trước khi tạo PR =====
git checkout feature/auth
git rebase -i origin/main
# Gộp các WIP commits, sửa messages để PR sạch đẹp
```

### 3.4 Rebase --onto

Di chuyển branch sang base khác:

```bash
# Tình huống: feature/payment được tạo từ feature/auth
# Nhưng giờ muốn base nó vào main thay vì feature/auth

git rebase --onto main feature/auth feature/payment
# Di chuyển commits của feature/payment (sau feature/auth) sang main
```


## 4. Cherry-Pick - Lấy Commit Cụ Thể

```bash
# Lấy 1 commit cụ thể từ branch khác
git cherry-pick a1b2c3d

# Lấy nhiều commits
git cherry-pick a1b2c3d b2c3d4e c3d4e5f

# Lấy range
git cherry-pick a1b2c3d..e5f6g7h

# Cherry-pick nhưng không commit ngay
git cherry-pick -n a1b2c3d

# ===== THỰC TẾ: Hotfix trên nhiều branches =====
# Bug được fix trên develop:
git checkout develop
git commit -m "fix: Critical SQL injection in user search"
# Commit hash: abc123

# Apply fix lên main (production) và release/v2.0:
git checkout main
git cherry-pick abc123

git checkout release/v2.0
git cherry-pick abc123
```


## 5. Xem Lịch Sử - git log

### 5.1 Các Cách Xem Log

```bash
# Cơ bản
git log
git log --oneline           # 1 commit 1 dòng
git log --oneline --graph   # Kèm ASCII graph
git log --oneline --graph --all  # Tất cả branches

# Lọc theo tác giả
git log --author="Tri Pheo"
git log --author="Alice\|Bob"  # Nhiều tác giả

# Lọc theo thời gian
git log --since="2024-01-01"
git log --until="2024-12-31"
git log --since="1 week ago"
git log --since="yesterday"

# Lọc theo message
git log --grep="authentication"    # Message chứa "authentication"
git log --grep="fix" -i            # Case-insensitive

# Lọc theo file
git log -- src/auth.py             # Chỉ commits liên quan đến file này

# Lọc theo nội dung thay đổi (pickaxe)
git log -S "password_hash"         # Commits thêm/xóa string này
git log -G "password.*hash"        # Commits khớp regex này

# Xem file đã thay đổi
git log --stat                     # Tổng quan files thay đổi
git log --name-only                # Chỉ tên files
git log --name-status              # Tên files + A/M/D

# Format tùy chỉnh
git log --format="%h %an %ad %s" --date=short
# a1b2c3d Alice 2024-01-15 Add authentication

# Đẹp hơn - alias thường dùng
git log --oneline --graph --decorate --all
```

### 5.2 git diff - Xem Thay Đổi Chi Tiết

```bash
# Working tree vs Staging Area
git diff

# Staging Area vs Repository (commit cuối)
git diff --staged
git diff --cached           # Tương tự

# Working tree vs commit cuối
git diff HEAD

# So sánh 2 commits
git diff a1b2c3d b2c3d4e

# So sánh 2 branches
git diff main feature/login

# Chỉ tên files thay đổi
git diff --name-only main feature/login

# Thống kê số dòng thay đổi
git diff --stat main feature/login

# So sánh file cụ thể
git diff HEAD src/auth.py

# Xem thay đổi của 1 commit cụ thể
git show a1b2c3d
git show a1b2c3d:src/auth.py  # Xem file ở commit cụ thể
git show HEAD~3:package.json  # File 3 commits trước
```


## 6. Undoing Changes - Hoàn Tác

### 6.1 Các Tình Huống Hoàn Tác

```bash
# ===== CHƯA STAGED (Working Tree) =====
# Hoàn tác thay đổi 1 file
git restore src/auth.py         # Git 2.23+
git checkout -- src/auth.py     # Cách cũ

# Hoàn tác tất cả changes
git restore .
git checkout -- .

# ===== ĐÃ STAGED (Staging Area) =====
# Unstage file (giữ nguyên changes ở working tree)
git restore --staged src/auth.py
git reset HEAD src/auth.py      # Cách cũ

# ===== ĐÃ COMMIT (chưa push) =====
# Sửa commit cuối
git commit --amend

# Xóa commit cuối, giữ changes (staged)
git reset --soft HEAD~1

# Xóa commit cuối, giữ changes (unstaged)
git reset --mixed HEAD~1    # Mặc định khi không có flag

# Xóa commit cuối, XÓA LUÔN CHANGES (nguy hiểm!)
git reset --hard HEAD~1

# Xóa N commits
git reset --soft HEAD~3     # 3 commits
git reset --hard HEAD~3     # 3 commits + xóa changes

# ===== ĐÃ PUSH (an toàn - không rewrite history) =====
# Tạo commit mới "đảo ngược" commit cũ
git revert a1b2c3d
git revert HEAD             # Revert commit cuối
git revert HEAD~3..HEAD     # Revert 3 commits gần nhất

# Revert nhưng không commit ngay
git revert -n a1b2c3d
```

### 6.2 git reset Chi Tiết

```
                    HEAD
                      │
Working  Staging   Commit
  Tree    Area    History
  
  --soft:          ←─┤           (chỉ di chuyển HEAD)
 --mixed:      ←───┤             (mặc định, unstage files)  
  --hard:  ←──────┤              (mất tất cả changes)
```

### 6.3 git reflog - Cứu Nguy Khi Lỡ Reset

```bash
# reflog ghi lại TẤT CẢ di chuyển của HEAD
git reflog
# a1b2c3d HEAD@{0}: commit: Add authentication
# b2c3d4e HEAD@{1}: commit: Fix login bug
# c3d4e5f HEAD@{2}: reset: moving to HEAD~2  ← Reset về đây
# d4e5f6g HEAD@{3}: commit: Add login form    ← Commit "bị mất"

# Khôi phục commit "bị mất" sau reset --hard
git reset --hard HEAD@{3}
# Hoặc:
git checkout -b recover-branch d4e5f6g
```


## 7. Stashing - Lưu Tạm Thay Đổi

```bash
# Tình huống: Đang làm dở feature, sếp bảo fix gấp bug khác

# Lưu tạm changes
git stash
git stash push -m "WIP: payment feature, half done"

# Lưu kể cả untracked files
git stash -u
# Lưu kể cả ignored files
git stash -a

# Xem danh sách stashes
git stash list
# stash@{0}: On feature/payment: WIP: payment feature, half done
# stash@{1}: On main: Quick experiment

# Apply stash gần nhất (giữ stash)
git stash apply

# Apply và xóa stash
git stash pop

# Apply stash cụ thể
git stash apply stash@{1}
git stash pop stash@{1}

# Xem nội dung stash
git stash show -p stash@{0}

# Xóa stash
git stash drop stash@{0}
git stash clear             # Xóa tất cả

# Tạo branch từ stash
git stash branch feature/payment stash@{0}
```
