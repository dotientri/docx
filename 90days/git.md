# 6. Quản lý phiên bản với Git

## Ngày 35 & 36: Tổng quan & Kiến trúc Git
### Quản lý phiên bản (VCS) là gì?
#### Mục đích
Theo dõi lịch sử dự án, ghi lại ai đã làm gì, vào lúc nào.
#### Lợi ích
Single Source of Truth: Nguồn mã nguồn duy nhất, thống nhất cho toàn bộ team.
Branching & Merging: Phát triển song song nhiều tính năng, hợp nhất an toàn.
CI/CD Integration: Nền tảng cốt lõi để kết nối với các công cụ tự động hóa.
Rollback: Quay ngược lịch sử về phiên bản ổn định khi gặp lỗi hệ thống.

### Kiến trúc Version Control

#### Tập trung (Centralized - SVN)
Thao tác trực tiếp trên server trung tâm.
#### Phân tán (Distributed - Git)
Mỗi kỹ sư sở hữu một bản sao toàn bộ lịch sử (full repository history) trên máy local. Tốc độ cao, làm việc offline, bảo mật tốt.

## Ngày 37: Lệnh cốt lõi & Quy chuẩn Commit
### Khởi tạo & Cấu hình
`git init`: Tạo mới repo.
`git clone <url>`: Sao chép repo từ remote về máy.
`git config --global user.name` / `user.email`: Thiết lập danh tính người dùng.

### Quản lý thay đổi (Staging & Commit)
`git add .`: Đưa toàn bộ thay đổi vào Staging Area (vùng đệm).
`git status`: Kiểm tra trạng thái tệp (Untracked, Staged, Modified).
`git log`: Xem lịch sử commit.
`git commit -m "message"`: Lưu snapshot thay đổi vĩnh viễn vào lịch sử.

### Quy chuẩn viết Commit Message (Conventional Commits)
#### 1. Các loại thay đổi (Type)
feat: Thêm một tính năng mới.
fix: Sửa một lỗi (bug).
docs: Chỉ thay đổi tài liệu (README, comments).
style: Không ảnh hưởng logic code (khoảng trắng, format).
refactor: Đổi cấu trúc code, không thêm tính năng hay sửa lỗi.
perf: Cải thiện hiệu năng.
test: Thêm hoặc sửa test.
chore: Cập nhật công cụ build, CI/CD, thư viện.
#### 2. Phạm vi (Scope)
backend: Thay đổi liên quan đến API, xử lý logic.
frontend: Thay đổi liên quan đến giao diện người dùng.
k8s: Thay đổi file manifest Kubernetes hoặc đường ống CI/CD.
db: Thay đổi liên quan đến cơ sở dữ liệu, migrations.
#### 3. Mô tả (Description)
Viết bằng tiếng Anh hoặc tiếng Việt (cần thống nhất trong team).
Bắt đầu bằng chữ thường, dùng thì hiện tại, mệnh lệnh cách.
Không kết thúc bằng dấu chấm.

### Tương tác Remote (Server)
`git remote add origin <url>`: Gán đường dẫn server.
`git push -u origin <branch>`: Đẩy code từ local lên server.
`git pull`: Lấy code từ server về và merge tự động.
`git fetch`: Lấy dữ liệu từ server (chưa merge).

## Ngày 38: Staging, Changing & Best Practices
### Quy trình chuẩn (Workflow)

Untracked: Tệp mới tạo, chưa được Git theo dõi.
Staged: Tệp được đưa vào vùng đệm bằng lệnh git add.
Committed: Tệp đã lưu vào snapshot lịch sử bằng lệnh git commit.

### Tệp bỏ qua (.gitignore)
Mục đích: Loại bỏ tệp rác, file build, hoặc file chứa bí mật.
Tại sao: Tránh rò rỉ dữ liệu nhạy cảm và giữ repo sạch sẽ.

### Mẹo thao tác
`git status -s`: Hiển thị trạng thái rút gọn.
`git mv <old> <new>`: Đổi tên file.
`git rm --cached <file>`: Xóa file khỏi Git tracking nhưng giữ lại tệp vật lý trên máy.

## Ngày 39: Xem, Unstaging, Loại bỏ & Khôi phục
### Kiểm tra thay đổi
`git diff --staged`: Xem sự khác biệt giữa Staging Area và commit gần nhất.
`git show <commit_id>`: Xem chi tiết nội dung thay đổi.

### Hoàn tác & Khôi phục
`git restore --staged <file>`: Rút file khỏi Staging.
`git restore <file>`: Hủy bỏ thay đổi tại file, khôi phục về trạng thái commit cuối.
`git clean -fd`: Xóa bỏ các file lạ (untracked).

### Merge vs Rebase

#### Merge (git merge)
Tạo Merge Commit, giữ nguyên lịch sử nhánh cũ. Phù hợp khi muốn bảo tồn bối cảnh.
#### Rebase (git rebase)
Viết lại lịch sử, dời nhánh lên ngọn của nhánh chính. Tạo ra lịch sử tuyến tính sạch đẹp. Tuyệt đối không Rebase trên nhánh công cộng.

## Ngày 40: Mạng xã hội mã nguồn
### Các nền tảng
GitHub: Phổ biến nhất, cộng đồng lớn, mạnh về Actions.
GitLab: Mạnh về CI/CD tích hợp, thích hợp tự host.
BitBucket: Tích hợp sâu với hệ sinh thái Atlassian (Jira).

### Tính năng chủ chốt
Issues: Quản lý bug, feature requests.
Pull Request (PR): Đề xuất thay đổi và Review code trước khi Merge.
Actions: Tự động hóa CI/CD, chạy test, build app tự động.
Wiki / Projects: Tài liệu dự án và bảng Kanban quản lý task.

## Ngày 41: Open Source Workflow

### Quy trình 5 bước đóng góp
1. Fork: Sao chép dự án về repo cá nhân.
2. Clone: Tải bản Fork về máy cục bộ.
3. Edit / Test: Chỉnh sửa code, fix bug.
4. Push: Đẩy thay đổi ngược lên bản Fork.
5. Pull Request (PR): Gửi đề xuất sang dự án gốc chờ Review và Merge.

## Các Mô hình Git Workflow (Quy trình làm việc)
### 1. Git Flow (Quy trình chặt chẽ, tiêu chuẩn doanh nghiệp)


[Image of Git Flow branching model]

#### Nhánh chính (Main Branches)
main (hoặc master): Chứa mã nguồn ổn định, luôn trong trạng thái sẵn sàng triển khai (Production). Luôn đi kèm Tag phiên bản (vd: v1.0.0).
develop: Nhánh tích hợp chính. Chứa mã nguồn đang phát triển cho bản phát hành tiếp theo.
#### Nhánh hỗ trợ (Supporting Branches)
feature/*: Tạo ra từ nhánh develop. Dùng để phát triển tính năng mới. Làm xong sẽ merge ngược lại vào develop.
release/*: Tạo ra từ develop khi chuẩn bị phát hành. Dùng để test cuối cùng và sửa bug nhỏ. Sau đó merge vào cả main và develop.
hotfix/*: Tạo ra trực tiếp từ main. Dùng để sửa gấp lỗi nghiêm trọng trên Production. Sửa xong merge ngay vào main và develop.

### 2. GitHub Flow (Quy trình tối giản, linh hoạt)

#### Đặc điểm
Chỉ có một nhánh chính duy nhất là nhánh main (luôn có thể deploy). Rất phù hợp cho quy trình CI/CD và triển khai liên tục (Continuous Deployment).
#### Vòng đời phát triển
Bước 1: Tạo nhánh mới từ main (vd: feature/login).
Bước 2: Commit thay đổi cục bộ và Push lên remote.
Bước 3: Mở Pull Request (PR) để team thảo luận và Review code.
Bước 4: Cập nhật code theo góp ý (nếu có).
Bước 5: Merge vào nhánh main và Deploy ngay lập tức.

### 3. Trunk-Based Development (Quy trình CI/CD hiện đại)

#### Đặc điểm
Mọi lập trình viên đều push code trực tiếp vào nhánh main (Trunk) nhiều lần trong ngày.
Rất ít hoặc không sử dụng nhánh feature sống thọ (long-lived branches).
Sử dụng Feature Flags (Cờ tính năng) để ẩn các tính năng chưa hoàn thiện trên Production.
Phù hợp với các team DevOps có hệ thống Test tự động (Automated Testing) cực kỳ tốt để đảm bảo nhánh main không bao giờ bị lỗi.

## Thuật ngữ cốt lõi
Repository (Repo): Nơi lưu trữ mã nguồn cùng lịch sử commit.
Commit: Snapshot lưu trữ thay đổi với message mô tả.
Branch: Nhánh phát triển độc lập.
Merge: Hợp nhất thay đổi từ nhánh này vào nhánh khác.
Rebase: Viết lại lịch sử commit để có lịch sử tuyến tính.
Pull Request: Cơ chế peer-review trước khi hợp nhất.
Staging Area (Index): Vùng tạm chứa thay đổi trước khi commit.
HEAD: Con trỏ hiện tại tới commit đang checkout.
Tag: Đánh dấu commit quan trọng (bản release).
Fork: Sao chép repo công khai vào tài khoản cá nhân.
Remote: Server lưu trữ mã nguồn.