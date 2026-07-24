# 🚀 BỘ CÂU HỎI PHỎNG VẤN DEVOPS THỰC TẾ (PHẦN 1: LINUX, BASH, GIT, NETWORK)
*Mức độ: Intern, Fresher, Junior*

Tài liệu này tổng hợp các câu hỏi phỏng vấn chi tiết, đi sâu vào thực tế vận hành thay vì chỉ lý thuyết suông.

---

## 🐧 PHẦN 1: LINUX & HỆ ĐIỀU HÀNH (Câu 1 - 20)

**1. Trình bày chi tiết quá trình boot của một hệ thống Linux từ lúc nhấn nút nguồn đến khi màn hình login hiện ra.**
* **Trả lời:** Quá trình gồm các bước: BIOS/UEFI (Hardware check) -> MBR/GPT (Tìm bootloader) -> GRUB (Load kernel) -> Kernel (Khởi tạo hardware, mount Root FS tạm thời qua initramfs) -> systemd/init (PID 1, khởi động các services theo targets) -> Login prompt.
* **Thực tế:** Nếu server không lên, thường kẹt ở GRUB (mất bootloader) hoặc Kernel panic (thiếu driver storage/file system lỗi). 

**2. Điểm khác biệt giữa Soft Link (Symlink) và Hard Link?**
* **Trả lời:** Hard link trỏ trực tiếp vào cùng một Inode với file gốc (chỉ áp dụng cho file, cùng partition). Xóa file gốc, hard link vẫn giữ được data. Soft link trỏ tới đường dẫn của file gốc (áp dụng được cho cả thư mục, khác partition). Xóa file gốc, soft link bị "gãy" (dangling link).
* **Thực tế:** Soft link dùng cực nhiều trong cấu hình Nginx (link từ `sites-available` sang `sites-enabled`) hoặc quản lý version của phần mềm (trỏ `/usr/bin/python` sang `python3.9`).

**3. Làm sao để tìm một file lớn hơn 1GB, tạo trong 7 ngày qua và kết thúc bằng `.log`?**
* **Trả lời:** Dùng lệnh: `find /path -type f -name "*.log" -size +1G -mtime -7`.
* **Thực tế:** Câu hỏi này test kỹ năng dọn dẹp ổ cứng khi server bị alert Disk Full.

**4. Giải thích quyền `755` và `644`. Khi nào dùng cái nào?**
* **Trả lời:** `755` (rwxr-xr-x): Owner có full quyền, Group/Others được đọc và thực thi. Thường dùng cho Thư mục (cần quyền x để `cd` vào) hoặc Scripts (cần quyền x để chạy). `644` (rw-r--r--): Owner đọc/ghi, Group/Others chỉ đọc. Thường dùng cho các file cấu hình (như nginx.conf, sshd_config) hoặc file text bình thường.

**5. Sticky bit, SUID, SGID là gì?**
* **Trả lời:** SUID: Thực thi file với quyền của người sở hữu file (VD: lệnh `passwd` cần quyền root). SGID: Thực thi file với quyền của group sở hữu, hoặc nếu set trên thư mục, các file tạo ra sẽ kế thừa group của thư mục đó. Sticky bit: Set trên thư mục (như `/tmp`), chỉ owner của file mới có quyền xóa file đó.

**6. Server báo "No space left on device" nhưng khi gõ `df -h` vẫn thấy trống 50%. Lỗi do đâu?**
* **Trả lời:** Hệ thống đã hết Inodes. Mỗi file/thư mục cần 1 inode để lưu metadata. Dù dung lượng đĩa còn, nhưng số lượng file quá nhiều (thường là file session, log vụn, thư mục cache) sẽ làm cạn kiệt inode. Cách kiểm tra: `df -i`.

**7. Một process đang chạy, làm sao biết nó đang mở những file nào?**
* **Trả lời:** Dùng `lsof -p <PID>`. Lệnh này cực kỳ hữu ích để check xem app có đang giữ file log cũ khiến dung lượng không giảm dù file đã bị xóa (deleted state).

**8. Bạn lỡ tay xóa nhầm file log đang được ghi bởi ứng dụng. Bạn làm gì để khôi phục?**
* **Trả lời:** Nếu ứng dụng (PID) chưa bị restart, file vẫn còn trong bộ nhớ (với trạng thái deleted). Dùng `lsof | grep deleted` tìm PID và File Descriptor (FD). Sau đó copy lại file từ proc: `cp /proc/<PID>/fd/<FD> /path/to/recover.log`.

**9. Sự khác biệt giữa `kill -15` (SIGTERM) và `kill -9` (SIGKILL)?**
* **Trả lời:** SIGTERM yêu cầu ứng dụng dừng lại, cho phép nó chạy các hàm dọn điểm (đóng database connection, flush log) -> Graceful shutdown. SIGKILL ép hệ điều hành ngắt process ngay lập tức, có thể gây lỗi dữ liệu. Luôn dùng SIGTERM trước, SIGKILL là lựa chọn cuối cùng.

**10. Load Average trong lệnh `uptime` hoặc `top` ý nghĩa là gì? Giá trị bao nhiêu là cao?**
* **Trả lời:** Load Average (1m, 5m, 15m) thể hiện số lượng process đang dùng CPU hoặc chờ CPU/Disk I/O. Giá trị "cao" phụ thuộc vào số lượng Core CPU. Nếu máy có 4 Core, Load Average = 4 nghĩa là hệ thống đang chạy full tải 100% không có độ trễ. Load = 8 nghĩa là đang quá tải gấp đôi.

**11. Zombie Process là gì? Làm sao để kill nó?**
* **Trả lời:** Zombie là process con đã chạy xong nhưng process cha chưa gọi lệnh `wait()` để đọc trạng thái kết thúc, khiến nó vẫn giữ 1 entry trong Process Table. Không thể dùng `kill -9` với zombie. Cách xử lý: Kill process cha, systemd (PID 1) sẽ nhận nuôi và dọn dẹp nó.

**12. Giải thích swap space. Có nên tắt swap trên Kubernetes nodes không? Tại sao?**
* **Trả lời:** Swap là vùng không gian trên đĩa cứng dùng như RAM ảo khi RAM thật đầy. Kubernetes (trước v1.22) bắt buộc tắt swap (`swapoff -a`) vì Scheduler của K8s dựa trên tính toán tài nguyên chính xác (RAM limits), nếu dùng swap, K8s không thể biết chính chính xác Pod nào bị OOM để giới hạn hiệu năng.

**13. Cronjob chạy script không ra kết quả, nhưng chạy tay thì thành công. Lý do phổ biến nhất?**
* **Trả lời:** Khác biệt về biến môi trường (Environment Variables). Cron chạy với shell hạn chế, thường không có biến `$PATH` đầy đủ như user bình thường. Khắc phục: Khai báo đường dẫn tuyệt đối cho các lệnh trong script (VD: `/usr/bin/curl` thay vì `curl`) hoặc load `.bash_profile` trong cron.

**14. Lệnh `nice` và `renice` làm gì?**
* **Trả lời:** Dùng để set độ ưu tiên (Priority - PR) cho process tranh giành CPU. Thang điểm từ -20 (ưu tiên cao nhất, cần quyền root) đến 19 (ưu tiên thấp nhất). `nice` dùng khi khởi chạy lệnh mới, `renice` dùng cho process đang chạy.

**15. Bạn sẽ dùng lệnh gì để xem băng thông mạng (Network I/O) theo thời gian thực trên Linux?**
* **Trả lời:** Các tool như `iftop` (xem traffic theo IP), `nethogs` (xem traffic theo từng Process), hoặc `sar -n DEV 1`.

**16. Systemd unit file khác gì với init script cũ (SysVinit)?**
* **Trả lời:** Systemd khởi động các service song song (parallel), quản lý phụ thuộc (dependencies) qua `Requires/After`, tự động restart khi crash (`Restart=always`), chuẩn hóa log qua `journalctl`, thay vì dùng các bash script tuần tự chậm chạp như SysV.

**17. Làm sao để xem 50 dòng cuối của file log và liên tục cập nhật khi có log mới?**
* **Trả lời:** `tail -n 50 -f /var/log/syslog`

**18. Câu lệnh grep nào để tìm tất cả các IP có trong một file access.log?**
* **Trả lời:** `grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" access.log`. Nếu được hỏi lệnh lấy IP và đếm số lượng truy cập: `awk '{print $1}' access.log | sort | uniq -c | sort -nr`.

**19. Sự khác biệt giữa `sudo` và `su -`?**
* **Trả lời:** `sudo` chạy 1 lệnh với quyền root (hoặc user khác) nhưng giữ lại biến môi trường hiện tại, yêu cầu pass của user. `su -` (Substitute user) chuyển hẳn sang shell của root, load lại toàn bộ environment của root, yêu cầu pass của root.

**20. Chẩn đoán khi SSH vào server bị chậm (mất khoảng 10-20 giây để ra prompt)?**
* **Trả lời:** Thường do SSH Server cố gắng thực hiện Reverse DNS lookup cho IP client kết nối tới. Khắc phục: Vào `/etc/ssh/sshd_config`, cấu hình `UseDNS no` và khởi động lại sshd.

---

## ⌨️ PHẦN 2: BASH SCRIPTING & TỰ ĐỘNG HÓA (Câu 21 - 35)

**21. Trong bash script, `set -e`, `set -u`, `set -o pipefail` có ý nghĩa gì?**
* **Trả lời:** Đây là "bùa hộ mệnh" (strict mode) của shell script.
  - `set -e`: Dừng script ngay nếu một lệnh fail (exit code khác 0).
  - `set -u`: Báo lỗi và dừng nếu dùng biến chưa được khai báo.
  - `set -o pipefail`: Trong chuỗi pipe (vd `cmd1 | cmd2`), nếu `cmd1` fail nhưng `cmd2` thành công, exit code chung vẫn bị đánh fail (tránh giấu lỗi).

**22. Sự khác biệt giữa `$*` và `$@` trong Bash?**
* **Trả lời:** Cả hai đều đại diện cho các tham số truyền vào script. Tuy nhiên, khi được bọc trong nháy kép `"$@"` sẽ tách từng tham số thành các string riêng biệt, còn `"$*"` sẽ gộp tất cả thành 1 string duy nhất (cách nhau bởi kí tự đầu của IFS, thường là dấu cách). Thực tế luôn ưu tiên `"$@"` khi duyệt vòng lặp `for`.

**23. Lệnh `awk` hoạt động như thế nào? Dùng awk để in ra cột thứ 2 của file `/etc/passwd`.**
* **Trả lời:** `awk` xử lý văn bản theo từng dòng (record) và chia nhỏ thành các cột (field). Trong `/etc/passwd`, dấu phân cách là `:`. Lệnh: `awk -F':' '{print $2}' /etc/passwd`.

**24. Làm sao để chạy một script ở chế độ nền (background) mà khi tắt terminal nó không bị dừng?**
* **Trả lời:** Dùng lệnh `nohup ./script.sh &`. (Nohup chặn tín hiệu SIGHUP khi terminal đóng). Có thể dùng các tool như `tmux` hoặc `screen`.

**25. Redirection `2>&1` trong lệnh `command > output.log 2>&1` nghĩa là gì?**
* **Trả lời:** Nó chuyển hướng Error Output (File Descriptor 2) về cùng chỗ với Standard Output (File Descriptor 1). Có nghĩa là cả kết quả in ra bình thường và lỗi của lệnh đều được ghi chung vào file `output.log`.

**26. Viết script kiểm tra dịch vụ Nginx có chạy không, nếu không thì tự khởi động lại?**
* **Trả lời:**
```bash
if ! systemctl is-active --quiet nginx; then
  systemctl restart nginx
  echo "Nginx was down, restarted at $(date)" >> /var/log/nginx_restart.log
fi
```

**27. Bạn muốn đọc từng dòng của một file text trong Bash script, cú pháp an toàn nhất là gì?**
* **Trả lời:** 
```bash
while IFS= read -r line; do
  echo "$line"
done < input.txt
```
(Giải thích: `IFS=` ngăn bash xóa space thừa ở đầu/cuối, `-r` ngăn việc escape ký tự `\` sai lệch).

**28. `exit 0` và `exit 1` khác nhau chỗ nào trong bash?**
* **Trả lời:** `exit 0` biểu thị script chạy thành công không có lỗi. Exit code khác 0 (1, 2, 127...) biểu thị có lỗi. CI/CD pipeline (như Jenkins, GitLab CI) dựa vào mã này để quyết định đánh xanh (Pass) hay đỏ (Fail) cho Job.

**29. Sự khác nhau giữa lệnh `exec` và gọi tên command bình thường trong script?**
* **Trả lời:** Khi gọi lệnh bình thường, bash shell sẽ tạo một sub-process để chạy. Khi dùng `exec <command>`, command đó sẽ ghi đè lên bash process hiện tại, chạy cùng PID, và khi command xong thì shell cũng đóng luôn. (Rất hay dùng trong ENTRYPOINT của Docker container để pass signals trực tiếp cho app).

**30. Dấu backticks \`cmd\` và `$(cmd)` khác nhau gì?**
* **Trả lời:** Cả hai dùng để gán output của lệnh vào biến (Command Substitution). Tuy nhiên `$(cmd)` là cú pháp hiện đại, dễ đọc, và hỗ trợ lồng nhau dễ dàng (vd: `$(cmd1 $(cmd2))`), backticks dễ gây nhầm lẫn với nháy đơn và rất khó để lồng nhau.

**31. `dev/null` là gì?**
* **Trả lời:** Là một black hole (hố đen) của hệ điều hành. Mọi dữ liệu ghi vào đây đều bị xóa bỏ. Dùng để ẩn output không cần thiết. Vd: `ls /root 2> /dev/null` (giấu dòng báo lỗi permission denied).

**32. Làm sao để set giá trị mặc định cho biến nếu biến đó chưa được truyền vào?**
* **Trả lời:** Dùng `${VAR:-default_value}`. VD: `ENV=${APP_ENV:-production}`.

**33. Nếu cần parse dữ liệu JSON trong Bash script, bạn dùng tool gì?**
* **Trả lời:** Dùng `jq`. VD lấy value từ key `name`: `echo '{"name":"DevOps"}' | jq -r '.name'`.

**34. Lệnh `trap` dùng để làm gì trong Bash script?**
* **Trả lời:** Bắt các tín hiệu (như Ctrl+C, EXIT, ERR) để chạy hàm dọn dẹp (cleanup). VD khi script tạo file tạm, nếu user nhấn Ctrl+C, trap sẽ giúp xóa file tạm trước khi thoát hẳn.

**35. Cú pháp `[ -z "$VAR" ]` và `[ -n "$VAR" ]` kiểm tra điều kiện gì?**
* **Trả lời:** `-z` kiểm tra chuỗi có độ dài bằng 0 (Zero/Rỗng). `-n` kiểm tra chuỗi có chứa dữ liệu (Non-zero).

---

## 🌐 PHẦN 3: NETWORKING (Câu 36 - 50)

**36. Phân biệt mô hình OSI 7 lớp và TCP/IP 4 lớp. Web app hoạt động ở lớp nào?**
* **Trả lời:** OSI (Physical, Data Link, Network, Transport, Session, Presentation, Application). TCP/IP (Network Access, Internet, Transport, Application). Web App (HTTP/HTTPS) hoạt động ở tầng cao nhất: Lớp Application. 

**37. Trình bày quá trình bắt tay 3 bước (3-way handshake) của TCP?**
* **Trả lời:** Client gửi gói SYN (Synchronize) -> Server nhận và trả lời bằng SYN-ACK -> Client nhận và xác nhận lại bằng gói ACK (Acknowledge). Sau đó kết nối thiết lập và bắt đầu truyền data.

**38. Sự khác biệt cốt lõi giữa TCP và UDP. Khi nào dùng UDP?**
* **Trả lời:** TCP: Tin cậy, có connection, đảm bảo gửi đúng thứ tự, có cơ chế truyền lại nếu mất gói -> Chậm hơn. Phù hợp web, email, file transfer. UDP: Không cần connection (fire and forget), gửi đi không cần biết bên kia nhận được chưa -> Rất nhanh, nhẹ. Phù hợp stream video, game online, DNS query, VoIP.

**39. Nếu gõ "google.com" vào trình duyệt, luồng DNS phân giải ra sao?**
* **Trả lời:** Trình duyệt check cache local (hosts file, browser cache) -> Hỏi DNS Resolver của nhà mạng (ISP) -> Resolver hỏi Root Servers (.) -> Root chỉ xuống TLD Servers (.com) -> TLD chỉ xuống Authoritative Servers của Google -> Server trả về IP của google.com cho Resolver để đưa lại cho trình duyệt và cache.

**40. Làm sao để kiểm tra một port (vd 5432 của Postgres) có đang mở chặn bởi Firewall hay không từ máy client?**
* **Trả lời:** Dùng `telnet IP 5432` hoặc `nc -zv IP 5432`. Lệnh `ping` không có tác dụng kiểm tra port vì ping dùng giao thức ICMP, không phải TCP/UDP.

**41. CIDR là gì? Subnet `10.0.0.0/24` có bao nhiêu IP sử dụng được?**
* **Trả lời:** CIDR (Classless Inter-Domain Routing) là chuẩn phân bổ địa chỉ IP. /24 nghĩa là 24 bit mạng, còn lại 8 bit host. Tổng số IP = $2^8 = 256$. Trừ 1 IP Network (10.0.0.0) và 1 IP Broadcast (10.0.0.255) -> Còn 254 IPs sử dụng được.

**42. NAT (Network Address Translation) hoạt động như thế nào?**
* **Trả lời:** NAT dịch đổi địa chỉ IP nội bộ (Private IP - vd 192.168.x.x) sang 1 địa chỉ IP Public duy nhất của Router/Modem để giao tiếp với Internet, giải quyết vấn đề cạn kiệt IPv4. Router sẽ nhớ Source Port để map các gói tin trả về đúng thiết bị nội bộ (gọi là PAT).

**43. Lệnh `netstat -tlnp` hoặc `ss -tlnp` dùng để làm gì?**
* **Trả lời:** Liệt kê tất cả các dịch vụ (processes) đang Listening trên các cổng TCP (t), không hiển thị IP dưới dạng tên miền (n), kèm theo PID và tên chương trình (p).

**44. Phân biệt `iptables` rules: INPUT, FORWARD, OUTPUT?**
* **Trả lời:** 
  - INPUT: Traffic có đích đến là chính server này.
  - OUTPUT: Traffic xuất phát từ chính server này đi ra ngoài.
  - FORWARD: Traffic mượn đường server này để đi qua một mạng khác (dùng khi server đóng vai trò là Router, VPN, Docker network proxy).

**45. VPC (Virtual Private Cloud) trên Cloud là gì? Các thành phần cơ bản?**
* **Trả lời:** Là một mạng nội bộ ảo độc lập trên Cloud. Thành phần cơ bản gồm: Subnets (chia nhỏ mạng theo Zone, public/private), Route Tables (bảng định tuyến traffic), Internet Gateway (để private network ra được Internet), NAT Gateway (cho private subnet tải packages), Security Groups/NACL (tường lửa).

**46. Ứng dụng báo lỗi "Connection Refused" và "Connection Timed Out" khác nhau chỗ nào?**
* **Trả lời:** 
  - `Connection Refused`: Gói tin đã đi tới đích, nhưng server đích báo lại (qua cờ RST) rằng không có dịch vụ nào đang nghe ở Port đó (vd App bị sập nhưng Server vẫn sống).
  - `Connection Timed Out`: Gói tin rơi vào hư vô (không ai reply), thường do Firewall/Security Group chặn Drop gói tin, hoặc sai IP/Routing.

**47. Bạn sẽ dùng gì để bắt gói tin (packet sniffer) đang chạy qua server?**
* **Trả lời:** Lệnh `tcpdump`. Vd: `tcpdump -i eth0 port 80` để bắt các gói HTTP.

**48. Cấu hình DNS Record type A và CNAME khác nhau thế nào?**
* **Trả lời:** A record trỏ Domain/Subdomain trực tiếp về 1 địa chỉ IPv4 cụ thể (vd: 1.2.3.4). CNAME (Canonical Name) trỏ Domain về 1 Domain khác (alias). Lưu ý: Không thể trỏ CNAME cho root domain (vd `company.com`), chỉ trỏ được cho subdomain (`www.company.com`).

**49. BGP (Border Gateway Protocol) là gì?**
* **Trả lời:** Là giao thức định tuyến trụ cột của Internet. Thay vì tìm đường đi ngắn nhất như OSPF trong mạng nội bộ, BGP kết nối các AS (Autonomous Systems - Các nhà cung cấp mạng) và quyết định lộ trình đi qua các nhà mạng dựa trên rule, policy (hợp đồng thương mại).

**50. Trong K8s, Container Network Interface (CNI) giải quyết bài toán gì?**
* **Trả lời:** CNI (Calico, Flannel, Cilium) giúp các Pods cấp IP và giao tiếp với nhau qua nhiều Node khác nhau mà không cần NAT (tạo thành một mạng Overlay phẳng). Nó cũng quản lý Network Policies (firewall rules giữa các Pods).

---

## 🌳 PHẦN 4: GIT & VERSION CONTROL (Câu 51 - 65)

**51. Giải thích sự khác biệt cơ bản giữa `git merge` và `git rebase`?**
* **Trả lời:** 
  - `Merge`: Tạo một commit gộp (merge commit), giữ nguyên lịch sử commit tách biệt của 2 nhánh. Phù hợp khi merge từ branch con về branch chính (main/master).
  - `Rebase`: "Bứng" gốc của nhánh hiện tại, đắp lên đỉnh của nhánh kia, viết lại lịch sử commit thành một đường thẳng tắp, không tạo merge commit. Rất sạch sẽ, nhưng nguy hiểm nếu rebase trên nhánh public có nhiều người cùng làm.

**52. Lỡ commit chứa password lên Git, cách xóa hoàn toàn khỏi lịch sử?**
* **Trả lời:** Nếu chỉ mới commit chưa push, có thể dùng `git reset HEAD~1`. Nếu đã push, phải dùng `git filter-branch` hoặc tool `BFG Repo-Cleaner` để viết lại toàn bộ lịch sử các commit chứa file đó, sau đó `git push --force`. Đổi password đó ngay lập tức vì nguyên tắc an toàn.

**53. Lệnh `git reset --soft`, `--mixed`, và `--hard` khác nhau chỗ nào?**
* **Trả lời:** 
  - `--soft`: Lùi commit history, nhưng giữ nguyên code đã sửa nằm ở trạng thái Staged (sẵn sàng commit lại).
  - `--mixed` (mặc định): Lùi history, giữ nguyên code đã sửa ở trạng thái Unstaged (phải `git add` lại).
  - `--hard`: Lùi history, XÓA SẠCH mọi thay đổi code về y hệt thời điểm của commit mục tiêu. (Cực kì cẩn thận).

**54. `git fetch` khác gì với `git pull`?**
* **Trả lời:** `git fetch` chỉ tải các metadata (commits mới, branches mới) từ remote repo về máy local để bạn xem (lưu vào `.git`), nhưng KHÔNG cập nhật (merge) vào working directory. `git pull` = `git fetch` + `git merge`.

**55. Cherry-pick là gì? Khi nào dùng?**
* **Trả lời:** Bốc chính xác 1 (hoặc nhiều) commit từ một nhánh khác và áp dụng nó sang nhánh hiện tại. Dùng khi bạn đang ở nhánh Release, phát hiện 1 bug nhỏ đã được fix bằng 1 commit ở nhánh Dev, thay vì merge toàn bộ Dev vào Release, bạn chỉ cherry-pick đúng commit fix bug đó.

**56. File `.gitignore` hoạt động thế nào? Nếu lỡ add file rồi mới thêm vào `.gitignore` thì sao?**
* **Trả lời:** `.gitignore` nói cho git biết bỏ qua không theo dõi (untracked) những file nào (vd node_modules, build/). Nếu đã lỡ track, phải xóa khỏi cache trước bằng lệnh `git rm -r --cached <file>`, sau đó `.gitignore` mới có tác dụng.

**57. Git stash dùng để làm gì?**
* **Trả lời:** Khi đang code dở tính năng nhưng có việc gấp phải switch nhánh (vd fix hotbug), nếu chưa code xong chưa muốn commit, dùng `git stash` để cất tạm code vào một ngăn kéo. Sửa bug xong quay lại nhánh cũ, gõ `git stash pop` để lôi code dở ra làm tiếp.

**58. Giải thích GitFlow Workflow?**
* **Trả lời:** Mô hình rẽ nhánh gồm 2 nhánh chính chạy song song vô tận là `main` (chứa code Production ready) và `develop` (chứa code next release). Các nhánh phụ: `feature/` (tạo từ develop, code tính năng xong merge về develop), `release/` (tạo từ develop để chuẩn bị deploy, test lỗi), và `hotfix/` (tạo từ main để vá lỗi khẩn cấp, merge lại về cả main và develop).

**59. Tại sao nói `git push --force` là tội ác? Khi nào được phép dùng?**
* **Trả lời:** `--force` sẽ đè bẹp lịch sử commit trên server bằng lịch sử ở máy local. Nếu người khác đã pull code từ server về, họ sẽ bị lỗi conflict nặng nề khi push lại. Chỉ được dùng `--force` trên nhánh CÁ NHÂN (feature branch) mà không có ai khác đang làm chung, hoặc sau khi dùng interactive rebase để dọn dẹp commit. Có thể cân nhắc dùng `--force-with-lease` sẽ an toàn hơn (nếu có người push code mới lên nó sẽ chặn).

**60. Squash commit là gì? Lợi ích?**
* **Trả lời:** Gom nhiều commit lắt nhắt, vô nghĩa (vd: "fix typo", "add log", "fix log") thành một commit duy nhất rõ ràng ("feat: implement payment API") trước khi merge vào nhánh chính. Lợi ích là giúp log history sạch sẽ, dễ review, dễ revert. Có thể làm qua Github UI (Squash and Merge) hoặc dùng `git rebase -i`.

**61. Làm sao để tìm xem dòng code gây ra bug được viết bởi ai, vào lúc nào?**
* **Trả lời:** Dùng lệnh `git blame <file_name>`. Kỹ năng sinh tồn cơ bản của dev. Bấm blame trên Github/Gitlab cũng được.

**62. `HEAD` trong git là gì? Trạng thái "Detached HEAD" là gì?**
* **Trả lời:** `HEAD` là một con trỏ trỏ tới commit mới nhất của nhánh ĐANG CHECKOUT. "Detached HEAD" xảy ra khi bạn checkout trực tiếp về 1 commit cụ thể (vd `git checkout abc1234`) thay vì checkout 1 nhánh. Lúc này HEAD không trỏ vào tên nhánh nào cả. Nếu commit ở trạng thái này sẽ bị mất nếu chuyển nhánh khác.

**63. Điểm khác biệt giữa centralized VC (SVN) và distributed VC (Git)?**
* **Trả lời:** SVN có một server trung tâm chứa toàn bộ lịch sử, client chỉ giữ phiên bản hiện tại. Mất mạng là hết commit. Git là phân tán (distributed), mỗi máy client đều clone về TOÀN BỘ lịch sử repo (bao gồm mọi branches/commits). Developer có thể làm việc và commit offline, có thể khôi phục toàn bộ project nếu remote server bị sập.

**64. Git Submodule là gì?**
* **Trả lời:** Cho phép nhúng một Git repository khác vào bên trong repository của bạn như là một thư mục con. Thường dùng khi repo của bạn cần tham chiếu tới code của 1 project library dùng chung của công ty.

**65. `git bisect` là gì và tại sao DevOps/Dev nên biết?**
* **Trả lời:** Là công cụ tìm kiếm nhị phân (binary search) siêu mạnh mẽ để dò tìm xem đích xác cái commit nào đã đưa một con bug vào hệ thống. Bạn chỉ cần chỉ ra 1 commit lúc code còn chạy tốt (Good), và commit hiện tại bị lỗi (Bad). Git sẽ tự động checkout các commit ở giữa để bạn test cho đến khi khoanh vùng được commit gây lỗi.

---
*(Xem tiếp phần 2 ở file kế tiếp)*
