# 🧠 GIẢI THÍCH BẰNG LỜI - GIT, TERRAFORM, ANSIBLE, AZURE, JENKINS, MONITORING

---

# PHẦN 1: GIT - VERSION CONTROL

---

## 1. Git ra đời để làm gì?

**Vấn đề trước khi có Git:**

Lập trình viên save file như: `project_v1.zip`, `project_v2_final.zip`, `project_v2_final_REAL.zip`, `project_v2_final_REAL_actually_final.zip`...

Khi có team: ai đang sửa file gì? Hai người sửa cùng file → conflict → mất công merge thủ công. Muốn xem code 3 tháng trước trông như thế nào? Không có.

**Git giải quyết:**

- Lưu snapshot của toàn bộ project tại mỗi commit
- Cho phép nhiều người làm việc song song trên branches
- Merge changes với conflict detection tự động
- Complete history - xem code bất kỳ thời điểm nào

---

## 2. Commit là gì thực sự?

Commit không phải là "sự khác biệt so với commit trước" (mặc dù hiển thị như vậy). Commit là **snapshot hoàn chỉnh** của toàn bộ project tại thời điểm đó.

Git dùng SHA-1 hash để identify mỗi commit. Hash được tính từ nội dung files + metadata + parent commit hash. Nếu thay đổi 1 byte bất kỳ → hash hoàn toàn khác → không thể tamper với history mà không bị phát hiện.

**Tại sao commit message quan trọng:**

Commit message là "tại sao" bạn làm thay đổi này. Code cho thấy "cái gì" bạn làm, nhưng không giải thích "tại sao".

6 tháng sau, khi bug phát sinh từ commit này, message tốt: "Fix race condition in payment processor when concurrent requests" giúp team hiểu ngay context. Message tệ: "fix bug" hoặc "update" không giúp ích gì.

---

## 3. Branch - Không phải "copy" của code

Nhiều người nghĩ tạo branch = copy toàn bộ code. Sai.

**Branch = pointer đến một commit.** Chuỗi commits lịch sử được chia sẻ, branch chỉ là "tên" cho commit hiện tại của branch đó.

Tạo branch mới = tạo thêm một pointer. Không copy file nào. Rất nhanh.

Khi bạn commit trên branch `feature/login`:
- `feature/login` pointer tiến về commit mới
- `main` pointer vẫn đứng im ở commit cũ

---

## 4. Merge vs Rebase - Tại sao gây tranh cãi?

**Merge:**

Tạo "merge commit" - commit đặc biệt có 2 parent commits (commit cuối của branch nguồn và branch đích). Lịch sử giữ nguyên, thấy rõ ràng branch nào merge vào khi nào.

Nhược điểm: Nhiều merge commits làm lịch sử "diamond-shaped", khó đọc.

**Rebase:**

"Giả vờ" branch của bạn được tạo từ commit mới nhất của main. K8s sắp xếp lại commits của bạn lên đầu.

Ưu điểm: Lịch sử tuyến tính, sạch đẹp. Nhược điểm: Thay đổi commit history → SHA hash thay đổi → KHÔNG bao giờ rebase branch đã push lên shared remote.

**Nguyên tắc vàng:** Không rebase nhánh đã share với người khác. Vì SHA thay đổi → người khác có commits "cũ" sẽ không còn match history nữa.

---

## 5. Git được thiết kế cho Distributed workflows

Git là **distributed** - mỗi clone là full copy của repository (tất cả history, tất cả branches). Bạn có thể commit, branch, merge hoàn toàn offline.

Khác với SVN (centralized) - phải connect server để commit, branch, view history.

Tại sao quan trọng cho CI/CD: Mỗi CI runner có full copy của repo → không cần network để operate, chỉ cần khi fetch/push.

---

# PHẦN 2: TERRAFORM - INFRASTRUCTURE AS CODE

---

## 1. Tại sao cần "Infrastructure as Code"?

**Trước IaC - "ClickOps":**

Sysadmin vào Azure Portal, click tạo VM, click thêm disk, click configure networking... Mất 2 giờ. Muốn tạo staging environment giống hệt production? Lại click 2 giờ. Nhớ không hết → staging khác production → "works in staging, fails in production".

**IaC giải quyết:**

Code mô tả infrastructure. `terraform apply` = infrastructure xuất hiện. Chạy lại = same result (idempotent). Commit vào Git = track changes, ai thay đổi gì, khi nào, tại sao. PR review trước khi apply = peer review cho infra changes.

---

## 2. Tại sao Terraform thay vì Bash scripts?

**Bash script approach:**

```bash
az vm create --name myvm ...
az vm disk attach ...
az network nsg create ...
```

Vấn đề: Nếu script fail ở bước 3, bạn re-run → bước 1 tạo VM lần nữa → duplicate! Phải handle idempotency thủ công với if statements phức tạp.

**Terraform approach:**

Terraform track "desired state" vs "actual state". Nếu VM đã tồn tại → skip tạo, chỉ xử lý sự khác biệt. Idempotent by design.

---

## 3. State file - "Sổ ghi chép" của Terraform

Terraform cần biết: Những resources nào đã được tạo bởi Terraform (để so sánh với desired state)?

State file = ánh xạ giữa Terraform resource definitions và actual cloud resources. `azurerm_resource_group.main` trong code → `/subscriptions/.../resourceGroups/myapp-rg` trong Azure.

**Tại sao phải remote state cho team?**

Local state file trên laptop của bạn: Teammate không biết resources nào đã được tạo. Nếu cả hai chạy `terraform apply` cùng lúc → conflict, có thể duplicate resources hoặc destroy nhau's changes.

Remote state (Azure Storage Account): State lock khi đang apply (chỉ 1 người apply tại 1 thời điểm). Shared nhưng safe.

---

## 4. Plan trước khi Apply - Tại sao quan trọng?

`terraform plan` cho bạn xem chính xác sẽ có gì xảy ra trước khi thực sự làm. Giống `git diff` nhưng cho infrastructure.

Quan trọng nhất: Nhận ra `-/+` (destroy and recreate). Ví dụ thay đổi VM size → Azure cần terminate VM cũ, tạo VM mới → **downtime**. Bạn biết trước để plan maintenance window.

Trong CI/CD: `terraform plan` để review, human approval, rồi `terraform apply`. Không bao giờ apply tự động mà không có plan review cho production.

---

# PHẦN 3: ANSIBLE - CONFIGURATION MANAGEMENT

---

## 1. Ansible khác Terraform như thế nào?

**Terraform** = "Provision infrastructure" (tạo VMs, networks, databases)

**Ansible** = "Configure servers sau khi đã tồn tại" (install software, configure services, deploy apps)

Cả hai thường dùng cùng nhau:
- Terraform tạo VM
- Ansible SSH vào VM và install + configure everything

---

## 2. Agentless - Tại sao là advantage?

Puppet, Chef (competitors) cần install agent trên mỗi server được quản lý. Agent consume resources, cần update, có thể conflict với phần mềm khác, security attack surface.

Ansible chỉ cần SSH access. Không cần cài gì trên managed servers. Dễ adopt (mọi Linux server đều có SSH), ít vấn đề.

---

## 3. Idempotency - Tại sao phải design theo cách này?

**Idempotent** = chạy 10 lần có kết quả giống chạy 1 lần.

Tại sao cần? Infrastructure drift - servers theo thời gian sẽ khác nhau (ai đó login và thay đổi thủ công, update không đồng nhất). Chạy Ansible playbook định kỳ = đảm bảo mọi servers đều ở đúng trạng thái mong muốn.

Nếu không idempotent: Chạy lần 2 install Nginx lần nữa → có thể conflict, error.

Ansible modules được thiết kế idempotent: `package: name=nginx state=present` = "nginx phải present". Nếu đã có → skip. Nếu chưa có → install. Không bao giờ install 2 lần.

---

# PHẦN 4: AZURE - CLOUD FUNDAMENTALS

---

## 1. Cloud là gì thực sự?

Cloud = servers của người khác mà bạn thuê. Đơn giản vậy thôi.

Nhưng tại sao tốt hơn tự mua servers?

**CapEx vs OpEx:** Mua server = chi phí vốn lớn upfront (CapEx). Cloud = chi phí vận hành theo tháng (OpEx). Startup không cần 10 triệu USD mua servers để launch app.

**Elasticity:** Thêm 100 servers trong 5 phút khi traffic tăng. Xóa khi traffic giảm. Tự mua servers = phải estimate max load, mua đủ, trả tiền 24/7 dù đang idle.

**Managed services:** Không muốn quản lý PostgreSQL server? Dùng Azure Database for PostgreSQL - Microsoft lo patching, backups, HA, replication. Bạn chỉ connect và dùng.

---

## 2. Azure Resource Groups - Tại sao quan trọng?

Resource Group = container logic để group related resources. Không phải network container (resources trong khác RGs vẫn có thể communicate).

**Tại sao group resources?**

- Delete toàn bộ environment: `az group delete --name staging-rg` → xóa tất cả resources trong đó cùng lúc
- RBAC (permissions) ở RG level: "Developer team có Contributor access trên dev-rg, không có access production-rg"
- Cost tracking: Xem bao nhiêu tiền cho staging vs production
- Tags: Apply tags cho toàn bộ resources trong RG

**Best practice:** 1 RG per application per environment. `myapp-prod-rg`, `myapp-staging-rg`, `myapp-dev-rg`.

---

## 3. Managed Identity - Tại sao tốt hơn Service Principal?

**Service Principal (SP):** App credentials (client_id + client_secret) để authenticate với Azure. Client secret = password, phải rotate định kỳ, phải store securely, nếu leak = security incident.

**Managed Identity:** Azure tự quản lý identity cho VM, AKS, App Service... Không có password để leak. Azure tự rotate certificates behind the scenes.

Ứng dụng chạy trên Azure VM với Managed Identity enabled có thể call Azure Key Vault, Azure Storage, etc. mà không cần store bất kỳ credentials nào. Azure xác thực "đây là VM của tôi, nó được phép access resource này".

---

## 4. Azure VNet Networking - Tại sao cần hiểu?

**VNet (Virtual Network)** = mạng private riêng của bạn trong Azure. Isolated từ internet và từ VNets của customers khác.

Resources trong cùng VNet có thể communicate qua private IPs mà không cần internet.

**Subnets trong VNet:**

Bạn chia VNet thành subnets cho các mục đích khác nhau:
- `app-subnet` (10.0.1.0/24): Chứa AKS nodes
- `db-subnet` (10.0.2.0/24): Chứa database servers
- `management-subnet` (10.0.3.0/24): Bastion host, VPN gateway

**Tại sao phải chia subnet?**

Security isolation: NSG (Network Security Group) apply ở subnet level. DB subnet chỉ accept traffic từ app-subnet trên port 5432, block tất cả traffic khác. Dù attacker vào được app subnet, không thể reach DB subnet trực tiếp.

---

# PHẦN 5: JENKINS - CI/CD SERVER

---

## 1. Jenkins là gì và tại sao vẫn phổ biến trong 2024?

Jenkins ra đời 2011, vẫn được dùng rộng rãi dù có GitHub Actions, Azure DevOps mới hơn.

**Lý do:**

*Self-hosted:* Code của bạn không chạy trên servers của GitHub hay Microsoft. Quan trọng với companies có compliance requirements (HIPAA, PCI-DSS, SOC2).

*Flexibility:* Hơn 1800 plugins. Muốn integrate với bất kỳ tool nào? Có plugin hoặc có thể write custom.

*Cost at scale:* GitHub Actions tính tiền theo minutes. Với large orgs chạy hàng nghìn pipeline jobs/ngày, self-hosted Jenkins có thể rẻ hơn nhiều.

*Legacy:* Nhiều enterprise đã invest vào Jenkins infrastructure, không dễ migrate.

---

## 2. Declarative vs Scripted Pipeline

**Scripted Pipeline (cũ hơn):**

Full Groovy code, cực kỳ flexible nhưng phức tạp. Làm được mọi thứ nhưng hard to read, hard to maintain.

**Declarative Pipeline (modern, khuyến cáo):**

Structured format với `pipeline { stages { stage { steps { ... } } } }`. Readable hơn, có built-in error handling, có nhiều directives sẵn (parallel, when, post...).

---

# PHẦN 6: MONITORING & OBSERVABILITY

---

## 1. Monitoring vs Observability - Khác nhau quan trọng

**Monitoring:** Bạn biết trước những gì có thể fail, đặt alerts cho chúng. "Alert khi CPU > 80%". Reactive - phát hiện known unknowns.

**Observability:** Khả năng hiểu internal state của system từ external outputs (metrics, logs, traces). Debug unknown unknowns - vấn đề bạn không anticipate.

"Bạn có thể monitor một system mà không observeable, nhưng bạn không thể understand nó."

---

## 2. Tại sao cần cả 3: Metrics, Logs, Traces?

**Scenario thực tế:**

3 giờ sáng, alert: "P99 latency tăng từ 100ms lên 2000ms"

**Metrics** nói: "Vấn đề bắt đầu lúc 2:47 AM, ảnh hưởng đến service 'payment'. Database query time tăng đột biến."

**Logs** nói: "2:47 AM - nhiều log entries: 'Waiting for database connection (timeout 30s)'. Connection pool exhausted."

**Traces** nói: "Request /api/checkout mất 1.8s. Breakdown: 0.1s auth service, 1.7s payment service. Trong payment service: 1.6s là 'wait for DB connection'."

Kết luận: Database connection pool bị exhausted. Nguyên nhân root: Một query chậm (do missing index sau deployment lúc 2:30 AM) giữ connection lâu → pool cạn → subsequent requests chờ.

Không có đủ cả 3 loại? Sẽ tốn nhiều giờ để debug thay vì vài phút.

---

## 3. Prometheus - Pull vs Push model

**Push model (traditional):** Apps chủ động gửi metrics đến central server. Vấn đề: App cần biết địa chỉ metrics server. Nếu app bị bug và push liên tục → DDoS server.

**Pull model (Prometheus):** Prometheus chủ động đến các targets và "scrape" metrics mỗi 15s. Apps expose `/metrics` endpoint thụ động.

Advantages:
- Dễ biết target nào down (Prometheus thấy target không respond)
- Config scraping tập trung ở Prometheus, không phải trong mỗi app
- Apps không cần biết về monitoring infrastructure

**PromQL - Tại sao phức tạp vậy?**

Metrics là time-series data. Bạn không hỏi "error count là bao nhiêu" mà "error RATE trong 5 phút qua là bao nhiêu". Cần rate(), increase(), histogram_quantile() - mathematical operations trên time series.

---

## 4. SLO, SLI, SLA - Error Budget concept

**Tại sao cần Error Budget?**

Tension cổ điển: Dev muốn deploy thường xuyên (tốc độ). Ops muốn stability (không thay đổi = ít risk).

Error Budget là compromise: Nếu SLO là 99.9% availability, error budget = 0.1% = 43.8 minutes downtime/tháng. Miễn là không vượt budget, thoải mái deploy.

Khi hết budget → stop feature deployments, focus 100% vào reliability.

Đây là principle của SRE (Site Reliability Engineering) của Google, giờ được adopt rộng rãi.

---

# PHẦN 7: PYTHON & GO CHO DEVOPS

---

## Python cho DevOps

**Tại sao Python được ưa thích hơn Bash cho complex scripts?**

- Bash: tốt cho "gọi commands, pipe output, basic logic". Syntax kỳ lạ cho strings, arrays, errors.
- Python: Full programming language. Xử lý JSON/YAML dễ dàng, exception handling rõ ràng, testing framework, type hints, readable.

Khi script > 50 dòng, Python thường là better choice.

**Azure SDK cho Python** = thư viện chính thức để control Azure resources từ Python code. Tạo VMs, manage AKS, read metrics, access Key Vault - mọi thứ Azure portal làm được, bạn làm được từ Python.

## Go cho DevOps

**Tại sao Go được chọn cho infrastructure tools?**

Docker, Kubernetes, Terraform, Prometheus, Grafana, Consul, Vault - tất cả viết bằng Go.

Lý do:
- **Compiled to single binary:** `go build` → 1 file executable, không cần runtime, không cần dependencies. Deploy đơn giản: copy binary là xong.
- **Fast startup:** VM hay container cold start, binary run ngay, không cần JVM warm-up hay Python interpreter init.
- **Goroutines:** Concurrency dễ dàng với goroutines (nhẹ hơn threads rất nhiều). K8s controller chạy hàng nghìn goroutines đồng thời.
- **Static typing:** Catch bugs tại compile time. Refactoring safe hơn.
- **Good standard library:** HTTP, JSON, networking - ít cần external dependencies.

**Khi nào dùng Python vs Go cho DevOps:**

*Python:* Scripts automation, data processing, Azure SDK calls, Ansible playbooks, quick tools.
*Go:* Long-running services, CLI tools cần performance, Kubernetes operators, anything needing high concurrency.
