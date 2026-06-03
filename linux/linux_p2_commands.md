# ---
markmap:
  title: "Linux — Commands & File Handling"
  collapse: false
# ---

# 🐧 LINUX TOÀN TẬP - PHẦN 2: LỆNH CƠ BẢN & XỬ LÝ FILE

## Theory
- Shell commands form the toolkit for inspecting and manipulating files, processes, and system state; mastering them reduces mean time to resolution.

## Practice
- Practice safe file operations (`cp -a`, `rm -i`), use `find` for targeted searches, `head`/`tail` for logs, and `tree` for directory overviews.

## 1. Điều Hướng (Navigation)

```bash
# Xem thư mục hiện tại
pwd
# /home/tripheo

# Di chuyển thư mục
cd /etc/nginx          # Đường dẫn tuyệt đối
cd Documents           # Đường dẫn tương đối
cd ..                  # Lên thư mục cha
cd ~                   # Về home directory
cd -                   # Quay lại thư mục trước đó
cd ~/Documents/project # Kết hợp ~ và đường dẫn

# Liệt kê files
ls                     # Đơn giản
ls -l                  # Long format (permissions, size, date)
ls -la                 # Kể cả hidden files (bắt đầu bằng .)
ls -lh                 # Human-readable size (KB, MB, GB)
ls -lS                 # Sort theo size (lớn nhất trước)
ls -lt                 # Sort theo thời gian (mới nhất trước)
ls -lR                 # Recursive (liệt kê cả subdirectories)
ls -d */               # Chỉ liệt kê directories

# Xem cây thư mục
tree                   # Cài: sudo apt install tree
tree -L 2              # Chỉ 2 cấp sâu
tree -a                # Kể cả hidden files
tree --dirsfirst       # Thư mục hiện trước
```


## 2. Thao Tác File & Thư Mục

### 2.1 Tạo

```bash
# Tạo file trống
touch newfile.txt
touch file1.txt file2.txt file3.txt  # Nhiều file cùng lúc
touch -t 202401151030 file.txt       # Set timestamp cụ thể

# Tạo thư mục
mkdir mydir
mkdir -p a/b/c/d        # Tạo nested directories (không báo lỗi nếu đã có)
mkdir -p project/{src,tests,docs,config}  # Tạo nhiều subdirs cùng lúc
# Kết quả: project/src, project/tests, project/docs, project/config

# Tạo file với nội dung
echo "Hello World" > hello.txt      # Ghi đè
echo "Second line" >> hello.txt     # Append (thêm vào)
cat > config.txt << 'EOF'
[database]
host = localhost
port = 5432
EOF
```

### 2.2 Xem Nội Dung File

```bash
# cat - xem toàn bộ file (dùng cho file nhỏ)
cat file.txt
cat -n file.txt     # Kèm số dòng
cat -A file.txt     # Hiện ký tự đặc biệt ($ ở cuối dòng, ^I = tab)

# less - xem file dài (có thể scroll)
less /var/log/syslog
# Trong less:
# Space / f     → Trang tiếp
# b             → Trang trước
# g             → Về đầu file
# G             → Về cuối file
# /pattern      → Tìm kiếm
# n             → Match tiếp theo
# q             → Thoát

# head - xem N dòng đầu
head file.txt        # Mặc định 10 dòng
head -n 20 file.txt  # 20 dòng đầu
head -c 100 file.txt # 100 bytes đầu

# tail - xem N dòng cuối
tail file.txt        # 10 dòng cuối
tail -n 50 file.txt  # 50 dòng cuối
tail -f /var/log/nginx/access.log  # Follow (real-time)
tail -F file.log     # Follow, tự reconnect nếu file bị rotate

# more - xem file (ít tính năng hơn less)
more file.txt

# wc - đếm
wc -l file.txt      # Đếm số dòng
wc -w file.txt      # Đếm số từ
wc -c file.txt      # Đếm số bytes
wc file.txt         # Cả 3

# Xem file binary
xxd file.bin | head        # Hex dump
od -c file.bin | head      # Octal dump
hexdump -C file.bin | head
```

### 2.3 Copy, Move, Xóa

```bash
# Copy
cp source.txt destination.txt          # Copy file
cp -r source_dir/ destination_dir/    # Copy thư mục (recursive)
cp -p file.txt backup.txt             # Giữ nguyên permissions & timestamps
cp -a source/ dest/                    # Archive mode (giữ tất cả metadata)
cp -u source.txt dest.txt             # Chỉ copy nếu source mới hơn
cp -v source.txt dest.txt             # Verbose (hiện progress)

# Move/Rename
mv oldname.txt newname.txt            # Đổi tên
mv file.txt /tmp/                     # Di chuyển
mv *.log /var/log/archive/           # Di chuyển nhiều file
mv -n source.txt dest.txt            # Không ghi đè nếu dest tồn tại
mv -b source.txt dest.txt            # Backup file đích trước khi ghi đè

# Xóa
rm file.txt                           # Xóa file
rm -f file.txt                        # Force xóa (không hỏi)
rm -r directory/                      # Xóa thư mục recursive
rm -rf directory/                     # Force xóa thư mục (NGUY HIỂM!)
rm -i file.txt                        # Hỏi xác nhận trước khi xóa
rmdir emptydir/                       # Chỉ xóa thư mục RỖNG

# ⚠️ CỰC KỲ NGUY HIỂM - ĐỪNG BAO GIỜ CHẠY:
# rm -rf /           → Xóa toàn bộ hệ thống!
# rm -rf /*          → Tương tự
# rm -rf ~/          → Xóa toàn bộ home directory!
```

### 2.4 Symbolic Links (Symlinks)

```bash
# Tạo symbolic link (shortcut)
ln -s /path/to/original /path/to/symlink

# Ví dụ thực tế:
ln -s /usr/local/bin/python3.11 /usr/local/bin/python3
ln -s /var/www/html/mysite /home/user/mysite
ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp

# Hard link (khác với symlink)
ln original.txt hardlink.txt    # Cùng inode, cùng dữ liệu

# Xem symlink trỏ đến đâu
ls -la /usr/bin/python3
readlink -f /usr/bin/python3   # Theo đến đích cuối cùng
```


## 3. Tìm Kiếm

### 3.1 find - Tìm File Mạnh Mẽ

```bash
# Cú pháp: find [where] [options] [expression]

# Tìm theo tên
find /home -name "*.log"             # Tìm tất cả .log files
find / -name "nginx.conf"            # Tìm từ root
find . -iname "readme*"             # Case-insensitive (-i)

# Tìm theo loại
find /tmp -type f                    # Chỉ files
find /var -type d                    # Chỉ directories
find /dev -type l                    # Chỉ symlinks

# Tìm theo size
find / -size +100M                   # Lớn hơn 100MB
find / -size -1k                     # Nhỏ hơn 1KB
find /var/log -size +10M -size -1G   # Giữa 10MB và 1GB

# Tìm theo thời gian
find /tmp -mtime +7                  # Được sửa hơn 7 ngày trước
find /var/log -atime -1             # Được access trong 24 giờ qua
find . -newer reference.txt          # Mới hơn reference.txt

# Tìm theo permissions
find / -perm 777                     # Permissions chính xác là 777
find / -perm -u+s                    # Files có SUID bit
find / -perm /o+w                    # Files world-writable (nguy hiểm!)

# Tìm theo owner
find /home -user tripheo             # Files thuộc user tripheo
find /tmp -group www-data            # Files thuộc group www-data

# Thực thi lệnh trên kết quả tìm được
find /tmp -name "*.tmp" -delete              # Xóa tất cả .tmp files
find /var/log -name "*.log" -exec ls -lh {} \;  # ls từng file
find . -name "*.py" -exec grep -l "import os" {} \;  # Tìm .py chứa "import os"

# Kết hợp điều kiện
find / -name "*.conf" -type f -user root -perm 644

# Thực tế: Tìm và xóa log cũ hơn 30 ngày
find /var/log/myapp -name "*.log" -mtime +30 -delete
```

### 3.2 grep - Tìm Kiếm Nội Dung

```bash
# Cú pháp: grep [options] pattern [file...]

# Tìm cơ bản
grep "error" /var/log/syslog
grep "ERROR" app.log

# Options quan trọng
grep -i "error" file.txt        # Case-insensitive
grep -r "database" /etc/        # Recursive (tìm trong tất cả files)
grep -l "nginx" /etc/           # Chỉ hiện tên file có chứa pattern
grep -n "ERROR" app.log         # Hiện số dòng
grep -c "ERROR" app.log         # Đếm số dòng match
grep -v "DEBUG" app.log         # Invert (các dòng KHÔNG match)
grep -A 3 "ERROR" app.log       # 3 dòng AFTER match
grep -B 3 "ERROR" app.log       # 3 dòng BEFORE match
grep -C 3 "ERROR" app.log       # 3 dòng context (before + after)
grep -E "error|warning" app.log # Extended regex (| = OR)
grep -w "error" file.txt        # Whole word (không match "errors")
grep -o "ERROR[^:]*" file.txt   # Chỉ hiện phần match, không cả dòng

# Regex với grep
grep "^ERROR" file.txt           # Dòng bắt đầu bằng ERROR
grep "\.log$" file.txt           # Dòng kết thúc bằng .log
grep "[0-9]\{3\}" file.txt       # 3 chữ số liên tiếp
grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" file.txt  # IP address

# Thực tế trong doanh nghiệp
grep -r "password" /etc/ 2>/dev/null          # Tìm password trong config
grep -E "5[0-9]{2}" /var/log/nginx/access.log # HTTP 5xx errors
grep -c "GET /api" /var/log/nginx/access.log  # Đếm API requests
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn
# → Tìm IPs đang brute force SSH
```

### 3.3 locate & which

```bash
# locate - tìm nhanh (dùng database, không scan real-time)
locate nginx.conf       # Tìm ngay lập tức
updatedb                # Cập nhật database (cần chạy sau khi tạo file mới)

# which - tìm lệnh trong PATH
which python3           # /usr/bin/python3
which git               # /usr/bin/git

# whereis - tìm binary, source, man pages
whereis nginx           # nginx: /usr/sbin/nginx /etc/nginx /usr/share/nginx
```


## 4. Xử Lý Văn Bản (Text Processing)

### 4.1 sort & uniq

```bash
# sort - sắp xếp
sort file.txt                # Alphabetical
sort -r file.txt             # Reverse
sort -n numbers.txt          # Numeric sort
sort -k2 data.txt            # Sort theo column 2
sort -t: -k3 -n /etc/passwd  # Sort theo UID (cột 3, phân cách bởi :)
sort -u file.txt             # Unique (xóa duplicates)

# uniq - xử lý duplicates (phải sort trước!)
uniq file.txt                # Xóa consecutive duplicates
uniq -c file.txt             # Đếm occurrences
uniq -d file.txt             # Chỉ hiện duplicates
uniq -u file.txt             # Chỉ hiện unique lines

# Thực tế: Top 10 IPs truy cập nhiều nhất
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
```

### 4.2 cut & paste & join

```bash
# cut - cắt cột/ký tự
cut -d: -f1 /etc/passwd          # Lấy field 1, delimiter là :
cut -d: -f1,3 /etc/passwd        # Lấy field 1 và 3
cut -c1-10 file.txt              # Lấy ký tự 1-10 mỗi dòng
cut -c-5 file.txt                # 5 ký tự đầu

# Ví dụ thực tế: Lấy danh sách usernames
cut -d: -f1 /etc/passwd | head -20

# paste - ghép files theo cột
paste file1.txt file2.txt        # Ghép từng dòng bằng tab
paste -d, file1.txt file2.txt    # Dùng dấu phẩy làm delimiter
```

### 4.3 sed - Stream Editor

```bash
# sed - chỉnh sửa văn bản theo patterns

# Substitution (thay thế)
sed 's/old/new/' file.txt          # Thay thế lần đầu mỗi dòng
sed 's/old/new/g' file.txt         # Thay thế tất cả (global)
sed 's/old/new/gi' file.txt        # Global, case-insensitive
sed 's/old/new/2' file.txt         # Chỉ lần xuất hiện thứ 2
sed -i 's/old/new/g' file.txt      # In-place (sửa trực tiếp file)
sed -i.bak 's/old/new/g' file.txt  # In-place + backup file .bak

# Xóa dòng
sed '5d' file.txt                  # Xóa dòng 5
sed '5,10d' file.txt               # Xóa dòng 5-10
sed '/pattern/d' file.txt          # Xóa dòng chứa pattern
sed '/^$/d' file.txt               # Xóa dòng trống
sed '/^#/d' file.txt               # Xóa comment lines

# In dòng cụ thể
sed -n '5p' file.txt               # In dòng 5
sed -n '5,10p' file.txt            # In dòng 5-10
sed -n '/pattern/p' file.txt       # In dòng chứa pattern

# Chèn/Thêm dòng
sed '3i\New line before 3' file.txt    # Chèn trước dòng 3
sed '3a\New line after 3' file.txt     # Thêm sau dòng 3

# Thực tế: Sửa config file
sed -i 's/^#ServerName.*/ServerName example.com/' /etc/apache2/apache2.conf
sed -i 's/127.0.0.1:6379/redis:6379/g' /app/config.yml
sed -i '/^#/d; /^$/d' config.txt   # Xóa comments và dòng trống
```

### 4.4 awk - Xử Lý Dữ Liệu Có Cấu Trúc

```bash
# awk - ngôn ngữ xử lý văn bản mạnh mẽ nhất

# Cú pháp: awk 'pattern { action }' file

# In cột
awk '{print $1}' file.txt          # Cột 1 (phân cách bởi space)
awk '{print $1, $3}' file.txt      # Cột 1 và 3
awk -F: '{print $1}' /etc/passwd   # Delimiter là :

# Built-in variables
# $0 = cả dòng, $1 $2... = từng field
# NR = số thứ tự dòng, NF = số fields
# FS = field separator, RS = record separator

# Ví dụ
awk '{print NR, $0}' file.txt      # Thêm số dòng
awk 'NR==5' file.txt               # In dòng 5
awk 'NR>=5 && NR<=10' file.txt     # In dòng 5-10
awk '/pattern/' file.txt           # In dòng chứa pattern
awk '!/pattern/' file.txt          # Dòng không chứa pattern

# Tính toán
awk '{sum += $3} END {print sum}' data.txt          # Tổng cột 3
awk '{sum += $3} END {print sum/NR}' data.txt       # Trung bình
awk 'NF > 5' file.txt                               # Dòng có hơn 5 fields

# Thực tế hay dùng:
# Xem top processes theo CPU
ps aux | awk '{print $3, $11}' | sort -rn | head -10

# Tính tổng size files
ls -l | awk '{sum += $5} END {print sum/1024/1024 " MB"}'

# Phân tích nginx access log
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c
# → Đếm HTTP status codes

# Lấy IP của tất cả failed SSH attempts
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn
```


## 5. Pipes & Redirections - Triết Lý Unix

### 5.1 Redirections

```bash
# Standard streams:
# stdin  (0) → Input (mặc định từ keyboard)
# stdout (1) → Output thông thường (mặc định ra terminal)
# stderr (2) → Error output (mặc định ra terminal)

# Redirect stdout sang file
command > file.txt         # Ghi đè (overwrite)
command >> file.txt        # Append (thêm vào cuối)

# Redirect stderr sang file
command 2> error.log       # Lỗi vào file
command 2>> error.log      # Lỗi append vào file

# Redirect cả stdout và stderr
command > output.log 2>&1          # Cả hai vào cùng file
command &> output.log              # Cách viết tắt (bash 4+)
command >> output.log 2>&1         # Append cả hai

# Bỏ output vào /dev/null
command > /dev/null                # Bỏ stdout
command 2> /dev/null               # Bỏ stderr
command > /dev/null 2>&1           # Bỏ tất cả

# Here document (heredoc)
cat << 'EOF' > config.txt
server {
    listen 80;
    server_name example.com;
}
EOF

# Here string
grep "pattern" <<< "string to search in"
```

### 5.2 Pipes (|)

```bash
# Pipe: Output của lệnh trái → Input của lệnh phải
command1 | command2 | command3

# Ví dụ cơ bản
ls -la | grep ".txt"               # Lọc chỉ file .txt
cat file.txt | wc -l               # Đếm số dòng
ps aux | grep nginx                # Tìm nginx processes

# Chuỗi pipes phức tạp
ps aux | grep -v "^USER" | awk '{print $3, $4, $11}' | sort -rn | head -10
# → Top 10 processes theo CPU usage

# Thực tế: Phân tích log
cat /var/log/nginx/access.log \
  | awk '{print $1}' \              # Lấy IP
  | sort \                          # Sắp xếp
  | uniq -c \                       # Đếm occurrences
  | sort -rn \                      # Sort theo count
  | head -20                        # Top 20 IPs

# tee - vừa ghi file vừa in ra terminal
command | tee output.txt            # Ghi file VÀ in terminal
command | tee -a output.txt         # Append
command | tee file1.txt file2.txt   # Ghi nhiều files

# Ví dụ thực tế với tee
./deploy.sh 2>&1 | tee deploy.log  # Vừa xem, vừa lưu log
```

### 5.3 Process Substitution

```bash
# So sánh output của hai lệnh
diff <(ls /dir1) <(ls /dir2)

# Dùng output như file
grep "pattern" <(cat file1.txt file2.txt)
```


## 6. Quản Lý File Nén

```bash
# TAR - Tape Archive (lệnh phổ biến nhất)
# Tạo archive
tar -cvf archive.tar directory/         # Create, verbose, file
tar -czvf archive.tar.gz directory/     # + gzip compression
tar -cjvf archive.tar.bz2 directory/   # + bzip2 compression
tar -cJvf archive.tar.xz directory/    # + xz compression (nhỏ nhất)

# Giải nén
tar -xvf archive.tar                    # Extract, verbose, file
tar -xzvf archive.tar.gz               # Giải nén gz
tar -xjvf archive.tar.bz2              # Giải nén bz2
tar -xJvf archive.tar.xz               # Giải nén xz
tar -xvf archive.tar -C /destination/  # Giải nén vào thư mục cụ thể

# Xem nội dung archive mà không giải nén
tar -tvf archive.tar
tar -tzvf archive.tar.gz

# Giải nén file cụ thể
tar -xvf archive.tar path/to/file.txt

# ZIP
zip -r archive.zip directory/
zip archive.zip file1.txt file2.txt
unzip archive.zip
unzip archive.zip -d /destination/
unzip -l archive.zip                    # Xem nội dung

# GZIP/GUNZIP (chỉ nén file, không tạo archive)
gzip file.txt                           # Tạo file.txt.gz, xóa file.txt
gzip -k file.txt                        # Giữ file gốc (-k = keep)
gzip -d file.txt.gz                     # Giải nén
gunzip file.txt.gz                      # Giải nén
gzip -9 file.txt                        # Nén tối đa (chậm hơn)

# XZ (nén tốt hơn gzip)
xz file.txt                             # Tạo file.txt.xz
xz -d file.txt.xz                       # Giải nén

# Thực tế: Backup và nén
tar -czvf backup-$(date +%Y%m%d).tar.gz /etc/nginx/ /etc/ssl/
```


## 7. Lệnh Hữu Ích Khác

```bash
# Xem thông tin file
file document.pdf        # PDF document, version 1.4
file image.jpg           # JPEG image data
file script.sh           # Bourne-Again shell script

# diff - so sánh files
diff file1.txt file2.txt
diff -u file1.txt file2.txt    # Unified format (dễ đọc hơn)
diff -r dir1/ dir2/            # So sánh thư mục

# md5sum / sha256sum - kiểm tra integrity
md5sum file.txt
sha256sum file.txt
sha256sum -c checksums.sha256  # Verify từ file checksums

# split - chia file lớn
split -b 100M largefile.tar.gz part_   # Chia thành 100MB chunks
cat part_* > restored.tar.gz           # Ghép lại

# Xem disk usage
df -h                    # Disk usage của filesystems
df -h /                  # Chỉ xem /
du -sh /var/log          # Size của thư mục /var/log
du -sh /var/log/*        # Size từng thứ trong /var/log
du -h --max-depth=1 /    # Size mỗi thư mục ở root (1 cấp)
du -sh * | sort -rh | head -10  # Top 10 thứ to nhất

# Xem RAM
free -h                  # RAM usage (human-readable)
free -m                  # Tính bằng MB

# Xem uptime và load
uptime
# 15:30:00 up 42 days, 3:21, 2 users, load average: 0.52, 0.48, 0.45
# Load average: 1 phút, 5 phút, 15 phút
# Load = 1.0 trên 1 CPU core = 100% busy
```
