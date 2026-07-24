---
markmap:
	title: "DevOps Concepts — Git, Terraform, Ansible, Azure, Jenkins, Monitoring"
	collapse: false
---

# 🧠 GIẢI THÍCH BẰNG LỜI - GIT, TERRAFORM, ANSIBLE, AZURE, JENKINS, MONITORING

## Theory
- Tập trung giải thích khái niệm cốt lõi: version control, IaC, config management, cloud, CI/CD, observability.
- So sánh công cụ để hiểu role từng công cụ trong pipeline.

## Practice
- Đưa ví dụ thực tế: lệnh Git phổ biến, terraform plan/apply flow, playbook Ansible mẫu, CI pipeline sketch, và ví dụ observability (metrics/logs/traces).

## PHẦN 1: GIT - VERSION CONTROL

### 1.1 Git Ra Đời Để Làm Gì?
#### Vấn Đề Trước Git
- `project_v1.zip`, `project_v2_final.zip`, `project_v2_final_REAL.zip`...
- Hai người sửa cùng file → conflict → merge thủ công
- Muốn xem code 3 tháng trước? → Không có

#### Git Giải Quyết
- Snapshot toàn bộ project tại mỗi commit
- Nhiều người làm việc song song trên branches
- Merge changes với conflict detection tự động
- Complete history — xem code bất kỳ thời điểm nào

### 1.2 Commit Là Gì Thực Sự?
- **Snapshot hoàn chỉnh** (không phải diff)
- SHA-1 hash = tính từ nội dung + metadata + parent
- Thay đổi 1 byte → hash khác → **không tamper được history**

#### Commit Message Quan Trọng
- Code = "cái gì", Message = **"tại sao"**
- ✅ "Fix race condition in payment processor"
- ❌ "fix bug" hoặc "update"

### 1.3 Branch - Không Phải Copy
- **Branch = pointer** đến 1 commit
- Tạo branch = tạo pointer, **không copy file nào**, rất nhanh
- Commit trên `feature/login` → pointer tiến, `main` đứng im

### 1.4 Merge vs Rebase
#### Merge
- Tạo "merge commit" có 2 parents
- Lịch sử rõ ràng nhưng "diamond-shaped"

#### Rebase
- Sắp xếp lại commits lên đầu main
- Lịch sử tuyến tính, sạch đẹp
- ⚠️ **KHÔNG rebase branch đã push** (SHA thay đổi)

### 1.5 Git = Distributed
- Mỗi clone = **full copy** (history, branches)
- Commit, branch, merge hoàn toàn **offline**
- CI runner có full repo → không cần network

## PHẦN 2: TERRAFORM - INFRASTRUCTURE AS CODE

### 2.1 Tại Sao Cần IaC?
#### Trước IaC - "ClickOps"
- Vào Azure Portal click tạo VM, disk, network → 2 giờ
- Staging giống production? Click lại 2 giờ → nhớ không hết → **khác nhau**

#### IaC Giải Quyết
- Code mô tả infrastructure
- `terraform apply` = infrastructure xuất hiện
- **Idempotent** — chạy lại = same result
- Commit Git = track changes, PR review

### 2.2 Terraform vs Bash Scripts
#### Bash
```bash
az vm create --name myvm ...
```
- Fail bước 3 → re-run → **duplicate** bước 1!

#### Terraform
- Track **desired state vs actual state**
- VM đã tồn tại → skip, chỉ xử lý sự khác biệt
- **Idempotent by design**

### 2.3 State File - "Sổ Ghi Chép"
- Ánh xạ: code resource → actual cloud resource
- **Remote state** (Azure Storage): State lock, shared nhưng safe
- Local state → teammate không biết → conflict, duplicate

### 2.4 Plan Trước Apply
- `terraform plan` = xem chính xác sẽ xảy ra gì
- Nhận ra `-/+` (destroy & recreate) = **downtime**
- Production: plan → human approval → apply

## PHẦN 3: ANSIBLE - CONFIGURATION MANAGEMENT

### 3.1 Ansible Khác Terraform
- **Terraform** = Provision infrastructure (tạo VMs, networks)
- **Ansible** = Configure servers (install software, deploy apps)
- Thường dùng cùng nhau: Terraform tạo VM → Ansible configure

### 3.2 Agentless - Tại Sao Là Advantage?
- Puppet/Chef cần **install agent** trên mỗi server
- Agent tốn resources, cần update, security attack surface
- Ansible chỉ cần **SSH** — mọi Linux đều có

### 3.3 Idempotency
- Chạy 10 lần = kết quả giống 1 lần
- `package: name=nginx state=present` → đã có thì **skip**
- Chạy định kỳ = đảm bảo servers **đúng trạng thái**

## PHẦN 4: AZURE - CLOUD FUNDAMENTALS

### 4.1 Cloud Là Gì?
- **Servers của người khác mà bạn thuê**

#### CapEx vs OpEx
- Mua server = chi phí vốn lớn (CapEx)
- Cloud = chi phí theo tháng (OpEx)

#### Elasticity
- Thêm 100 servers trong 5 phút, xóa khi không cần

#### Managed Services
- Azure Database for PostgreSQL: Microsoft lo patching, HA, replication

### 4.2 Resource Groups
- Container logic group related resources
- Delete environment: `az group delete --name staging-rg` → xóa tất cả
- **RBAC** ở RG level: Dev có access dev-rg, không production-rg
- Best practice: 1 RG per app per environment

### 4.3 Managed Identity vs Service Principal
#### Service Principal
- client_id + client_secret = **password** phải rotate, store, có thể leak

#### Managed Identity ⭐
- Azure **tự quản lý** identity
- Không password, tự rotate certificates
- VM/AKS access Key Vault, Storage **không cần credentials**

### 4.4 VNet Networking
#### VNet = Mạng Private
- Isolated từ internet và VNets khác

#### Subnets - Phân Chia Mạng
- `app-subnet` (10.0.1.0/24): AKS nodes
- `db-subnet` (10.0.2.0/24): Database servers

#### Tại Sao Chia Subnet?
- NSG ở subnet level: DB subnet **chỉ accept** từ app-subnet port 5432
- Attacker vào app subnet → **không reach** DB subnet

## PHẦN 5: JENKINS - CI/CD SERVER

### 5.1 Tại Sao Jenkins Vẫn Phổ Biến?
#### Self-hosted
- Code không chạy trên servers GitHub/Microsoft
- Compliance: HIPAA, PCI-DSS, SOC2

#### Flexibility
- 1800+ plugins, integrate mọi tool

#### Cost At Scale
- GitHub Actions tính theo minutes → large orgs self-hosted rẻ hơn

#### Legacy
- Enterprise đã invest, không dễ migrate

### 5.2 Declarative vs Scripted Pipeline
#### Scripted (Cũ)
- Full Groovy code, cực flexible nhưng **hard to read/maintain**

#### Declarative (Modern) ⭐
- Structured: `pipeline { stages { stage { steps { } } } }`
- Readable, built-in error handling

## PHẦN 6: MONITORING & OBSERVABILITY

### 6.1 Monitoring vs Observability
#### Monitoring
- Biết trước gì có thể fail → đặt alerts
- **Reactive** — phát hiện known unknowns

#### Observability
- Hiểu internal state từ external outputs
- Debug **unknown unknowns** — vấn đề không anticipate

### 6.2 Tại Sao Cần Cả 3: Metrics, Logs, Traces?
#### Scenario
- 3AM alert: "P99 latency 100ms → 2000ms"

#### Metrics Nói
- "Vấn đề lúc 2:47 AM, service payment, DB query time tăng"

#### Logs Nói
- "Connection pool exhausted, waiting 30s timeout"

#### Traces Nói
- "Request /api/checkout: 1.8s. Payment service: 1.6s wait DB connection"

#### Kết Luận
- Missing index sau deployment 2:30 AM → query chậm → pool cạn
- Không đủ 3 loại → **vài giờ** debug thay vì vài phút

### 6.3 Prometheus - Pull vs Push
#### Push Model (Traditional)
- App chủ động gửi metrics → app cần biết server address

#### Pull Model (Prometheus) ⭐
- Prometheus **chủ động scrape** targets mỗi 15s
- Target down → Prometheus biết ngay
- Apps chỉ expose `/metrics` thụ động

### 6.4 SLO, SLI, SLA - Error Budget
#### Error Budget Concept
- SLO 99.9% → budget = 0.1% = **43.8 phút/tháng**
- Chưa hết budget → thoải mái deploy
- Hết budget → **stop features**, focus reliability
- Google SRE principle

## PHẦN 7: PYTHON & GO CHO DEVOPS

### 7.1 Python Cho DevOps
#### Khi Nào Dùng Python?
- Script > 50 dòng
- JSON/YAML processing
- Azure SDK calls, automation, quick tools

#### Tại Sao Hơn Bash?
- Exception handling rõ ràng
- Testing framework
- Type hints, readable

### 7.2 Go Cho DevOps
#### Tại Sao Infra Tools Dùng Go?
- Docker, K8s, Terraform, Prometheus — **tất cả viết bằng Go**

#### Lý Do
- **Single binary**: `go build` → 1 file, không cần runtime
- **Fast startup**: Không JVM warm-up
- **Goroutines**: Concurrency nhẹ hơn threads
- **Static typing**: Catch bugs compile time

### 7.3 Python vs Go
| Tiêu Chí | Python | Go |
|----------|--------|-----|
| Dùng cho | Scripts, automation | Long-running services, CLI tools |
| Deploy | Cần runtime | Single binary |
| Performance | Chậm hơn | Nhanh hơn |
| Concurrency | Threading/asyncio | Goroutines (nhẹ) |
