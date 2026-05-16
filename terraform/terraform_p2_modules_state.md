# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 2: MODULES & STATE MANAGEMENT

---

## 1. Terraform Modules

### 1.1 Module Là Gì?

Module = **Collection của Terraform files trong 1 thư mục** — cách đóng gói và tái sử dụng code.

**Mọi Terraform project đều là module** — gọi là "root module".

```
Không có modules (flat structure):
main.tf    # 2000 dòng!

Với modules:
main.tf
modules/
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ec2/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── rds/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### 1.2 Tạo Module - VPC Module

```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}
```

```hcl
# modules/vpc/main.tf

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Tính toán AZs
  azs = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ===== VPC =====
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = var.environment
  }
}

# ===== INTERNET GATEWAY =====
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ===== PUBLIC SUBNETS =====
resource "aws_subnet" "public" {
  count = var.public_subnet_count
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index % length(local.azs)]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "public"
    "kubernetes.io/role/elb" = "1"  # For EKS
  }
}

# ===== PRIVATE SUBNETS =====
resource "aws_subnet" "private" {
  count = var.private_subnet_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.public_subnet_count)
  availability_zone = local.azs[count.index % length(local.azs)]
  
  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "private"
    "kubernetes.io/role/internal-elb" = "1"  # For EKS
  }
}

# ===== PUBLIC ROUTE TABLE =====
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ===== NAT GATEWAY =====
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]
  
  tags = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0
  
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = { Name = "${local.name_prefix}-nat-gw" }
}

# ===== PRIVATE ROUTE TABLE =====
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
  
  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count = var.enable_nat_gateway ? length(aws_subnet.private) : 0
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}
```

### 1.3 Sử Dụng Module

```hcl
# root module - main.tf
module "vpc" {
  source = "./modules/vpc"   # Local module
  # source = "terraform-aws-modules/vpc/aws"  # Registry module
  # source = "git::https://github.com/company/tf-modules.git//vpc?ref=v1.0"  # Git
  # version = "5.0.0"  # Chỉ dùng với registry modules
  
  # Pass variables đến module
  vpc_cidr             = "10.0.0.0/16"
  environment          = var.environment
  project_name         = var.project_name
  public_subnet_count  = 3
  private_subnet_count = 3
  enable_nat_gateway   = var.environment == "production"
}

# Sử dụng outputs từ module
module "ec2" {
  source = "./modules/ec2"
  
  vpc_id     = module.vpc.vpc_id        # Lấy output của vpc module
  subnet_ids = module.vpc.private_subnet_ids
}

module "rds" {
  source = "./modules/rds"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  database_config = var.database_config
  db_password     = var.db_password
}

# Root module outputs
output "application_url" {
  value = "https://${module.ec2.load_balancer_dns}"
}
```

### 1.4 Public Terraform Registry

```hcl
# Dùng community modules (đã được test kỹ)

# ===== VPC Module (rất phổ biến) =====
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"
  
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true     # Tiết kiệm chi phí (non-prod)
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# ===== EKS Module =====
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"
  
  cluster_name    = "my-cluster"
  cluster_version = "1.29"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = 10
      desired_size = 3
      instance_types = ["t3.medium"]
    }
  }
}

# ===== RDS Module =====
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.3.0"
  
  identifier = "myapp-db"
  engine     = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage = 20
  storage_encrypted = true
  
  db_name  = "myapp"
  username = "admin"
  password = var.db_password
  
  vpc_security_group_ids = [module.security_groups.db_sg_id]
  subnet_ids             = module.vpc.private_subnets
  
  backup_retention_period = 7
  skip_final_snapshot     = false
}
```

---

## 2. State Management

### 2.1 Terraform State File

```json
// terraform.tfstate (JSON format, không edit thủ công!)
{
  "version": 4,
  "terraform_version": "1.7.0",
  "serial": 42,
  "lineage": "abc123-...",
  "outputs": {
    "vpc_id": {
      "value": "vpc-0123456789abcdef",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "aws_vpc",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "arn": "arn:aws:ec2:ap-southeast-1:123456789:vpc/vpc-0123456789",
            "cidr_block": "10.0.0.0/16",
            "id": "vpc-0123456789abcdef",
            ...
          }
        }
      ]
    }
  ]
}
```

**State quan trọng vì:**
- Track resources đã tạo (để biết cần update/xóa gì)
- Map config → real resources
- Track metadata (dependencies)
- Lưu sensitive data (credentials output)

### 2.2 Remote State Backend (Production Must-Have)

**Vấn đề với local state:**
- Chỉ 1 người có state → Không thể team work
- Không có backup nếu mất máy
- Không có locking → 2 người apply cùng lúc = disaster

**Giải pháp: Remote Backend**

```hcl
# backend.tf - S3 Backend (AWS)
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "${var.environment}/terraform.tfstate"  # ← Sai! Var không dùng được trong backend
    # Dùng literal string:
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true                          # Encrypt state ở rest
    
    # DynamoDB cho state locking
    dynamodb_table = "terraform-state-lock"
  }
}

# Tạo bucket và DynamoDB trước (thường có separate bootstrap project)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "company-terraform-state"
  
  lifecycle {
    prevent_destroy = true    # Không cho xóa bucket này!
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"    # Versioning để rollback state
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

```hcl
# ===== AZURE BACKEND =====
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "production.terraform.tfstate"
  }
}

# ===== GCS BACKEND (Google Cloud) =====
terraform {
  backend "gcs" {
    bucket = "company-terraform-state"
    prefix = "production"
  }
}

# ===== TERRAFORM CLOUD BACKEND =====
terraform {
  cloud {
    organization = "my-company"
    workspaces {
      name = "myapp-production"
    }
  }
}
```

### 2.3 State Locking

```bash
# Khi terraform apply, nó lock state:
# Nếu có người khác đang apply → Lỗi:
# Error: Error acquiring the state lock
# Lock Info: ID = abc123, Path = s3://..., Created = 2024-01-15T08:00:00Z

# Force unlock (NGUY HIỂM - chỉ khi chắc không có người đang apply)
terraform force-unlock abc123

# Với DynamoDB, lock được lưu vào table
# Tự động release sau khi apply xong (hoặc fail)
```

### 2.4 State Operations

```bash
# ===== XEM STATE =====
terraform state list
# aws_instance.web[0]
# aws_instance.web[1]
# aws_vpc.main
# module.vpc.aws_subnet.public[0]

terraform state show aws_vpc.main
# Hiện tất cả attributes của resource

# ===== IMPORT EXISTING RESOURCE =====
# Tình huống: Có resource tạo thủ công, muốn Terraform quản lý

# 1. Viết resource block trong code
resource "aws_vpc" "legacy" {
  cidr_block = "172.16.0.0/16"
}

# 2. Import vào state
terraform import aws_vpc.legacy vpc-0abc123def456789
# → Bây giờ Terraform quản lý VPC này

# Terraform 1.5+ hỗ trợ import blocks (declarative):
import {
  to = aws_vpc.legacy
  id = "vpc-0abc123def456789"
}

# 3. Chạy plan để xem diff
terraform plan
# → Nếu config match thực tế: No changes needed

# ===== MOVE RESOURCES =====
# Rename resource mà không recreate

# Cách cũ:
terraform state mv aws_instance.old_name aws_instance.new_name

# Terraform 1.1+ moved blocks (declarative):
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

# ===== TAINT & UNTAINT (deprecated) - Dùng replace =====
# Buộc recreate resource:
terraform apply -replace=aws_instance.web[0]

# ===== REFRESH STATE =====
# Sync state với actual infrastructure
terraform refresh     # (deprecated in favor of plan -refresh-only)
terraform plan -refresh-only   # Xem actual vs state
terraform apply -refresh-only  # Update state to match actual
```

---

## 3. Workspaces - Multiple Environments

### 3.1 Terraform Workspaces

```bash
# Workspace = Separate state files cho cùng 1 codebase
# Tốt cho: staging/production với cùng code, config nhỏ
# Không tốt cho: Infrastructure khác nhau nhiều giữa envs

# Default workspace: "default"
terraform workspace list
# * default

terraform workspace new staging
terraform workspace new production

terraform workspace select staging
terraform plan     # Dùng staging state

terraform workspace select production
terraform plan     # Dùng production state
```

```hcl
# Dùng workspace trong code
locals {
  workspace_config = {
    staging = {
      instance_type = "t3.micro"
      instance_count = 1
      enable_deletion_protection = false
    }
    production = {
      instance_type = "t3.large"
      instance_count = 3
      enable_deletion_protection = true
    }
  }
  
  config = local.workspace_config[terraform.workspace]
}

resource "aws_instance" "web" {
  count = local.config.instance_count
  instance_type = local.config.instance_type
  
  tags = {
    Environment = terraform.workspace
  }
}
```

### 3.2 Directory-Based Environments (Thường Dùng Hơn)

```
Cấu trúc directory-based:

environments/
├── staging/
│   ├── main.tf         → module calls
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── backend.tf      → Staging-specific backend
└── production/
    ├── main.tf         → Cùng module calls
    ├── variables.tf
    ├── terraform.tfvars
    └── backend.tf      → Production-specific backend

modules/               → Shared modules
├── vpc/
├── ec2/
└── rds/
```

```bash
# Deploy staging
cd environments/staging
terraform init
terraform plan
terraform apply

# Deploy production
cd environments/production
terraform init
terraform plan
terraform apply
```

---

## 4. Functions & Expressions

### 4.1 Built-in Functions

```hcl
# ===== STRING FUNCTIONS =====
format("Hello, %s!", "World")              # "Hello, World!"
lower("HELLO")                             # "hello"
upper("hello")                             # "HELLO"
trimspace("  hello  ")                     # "hello"
replace("hello world", "world", "terraform")  # "hello terraform"
split(",", "a,b,c")                        # ["a", "b", "c"]
join(",", ["a", "b", "c"])                 # "a,b,c"
substr("hello", 0, 3)                      # "hel"
startswith("hello", "he")                  # true
endswith("hello", "lo")                    # true

# ===== NUMERIC FUNCTIONS =====
max(5, 3, 8, 2)                            # 8
min(5, 3, 8, 2)                            # 2
abs(-5)                                    # 5
ceil(4.2)                                  # 5
floor(4.9)                                 # 4

# ===== COLLECTION FUNCTIONS =====
length([1, 2, 3])                          # 3
concat([1, 2], [3, 4])                    # [1, 2, 3, 4]
flatten([[1, 2], [3, 4]])                 # [1, 2, 3, 4]
toset(["a", "b", "a"])                   # toset(["a", "b"])
sort(["c", "a", "b"])                     # ["a", "b", "c"]
reverse([1, 2, 3])                        # [3, 2, 1]
distinct([1, 2, 2, 3])                    # [1, 2, 3]
compact(["a", "", "b", null, "c"])        # ["a", "b", "c"]
slice(["a", "b", "c", "d"], 1, 3)         # ["b", "c"]
element(["a", "b", "c"], 1)              # "b"
index(["a", "b", "c"], "b")              # 1
contains(["a", "b", "c"], "b")           # true

# Map functions
keys({a = 1, b = 2})                      # ["a", "b"]
values({a = 1, b = 2})                    # [1, 2]
merge({a = 1}, {b = 2}, {c = 3})         # {a=1, b=2, c=3}
lookup({a = 1, b = 2}, "a", "default")   # 1

# ===== IP/CIDR FUNCTIONS =====
cidrsubnet("10.0.0.0/16", 8, 0)          # "10.0.0.0/24"
cidrsubnet("10.0.0.0/16", 8, 1)          # "10.0.1.0/24"
cidrhost("10.0.0.0/24", 5)              # "10.0.0.5"
cidrnetmask("10.0.0.0/24")              # "255.255.255.0"

# ===== ENCODING FUNCTIONS =====
base64encode("Hello World")              # "SGVsbG8gV29ybGQ="
base64decode("SGVsbG8gV29ybGQ=")        # "Hello World"
jsonencode({name = "test"})             # "{\"name\":\"test\"}"
jsondecode("{\"name\":\"test\"}")        # {name = "test"}
yamlencode({name = "test"})
templatefile("config.tpl", {var = "value"})  # Render template file

# ===== TYPE CONVERSION =====
tostring(42)                             # "42"
tonumber("42")                           # 42
tobool("true")                           # true
tolist(["a", "b"])
tomap({a = 1})
toset(["a", "b"])

# ===== FILESYSTEM FUNCTIONS =====
file("path/to/file.txt")                 # Read file content
filebase64("path/to/file")               # Base64 encode file
filemd5("path/to/file")                  # MD5 hash of file
```

### 4.2 For Expressions

```hcl
# ===== FOR EXPRESSIONS =====

# List comprehension
[for s in ["hello", "world"] : upper(s)]
# → ["HELLO", "WORLD"]

# Với condition
[for s in ["hello", "world", "foo"] : upper(s) if length(s) > 4]
# → ["HELLO", "WORLD"]

# Map từ list
{for s in ["alice", "bob"] : s => "user-${s}"}
# → {alice = "user-alice", bob = "user-bob"}

# Flatten nested
[for k, v in {a = [1, 2], b = [3, 4]} : "${k}=${v}"]

# ===== THỰC TẾ =====
# Tạo map từ instances
locals {
  instance_private_ips = {
    for idx, inst in aws_instance.web :
    "web-${idx + 1}" => inst.private_ip
  }
}

output "instances" {
  value = local.instance_private_ips
  # → {web-1 = "10.0.1.10", web-2 = "10.0.1.11"}
}

# Filter subnets
locals {
  private_subnet_ids = [
    for subnet in aws_subnet.this :
    subnet.id
    if !subnet.map_public_ip_on_launch
  ]
}
```

---

## 5. Lifecycle Meta-Arguments

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789"
  instance_type = "t3.micro"
  
  lifecycle {
    # Tạo mới trước khi xóa (zero-downtime replace)
    create_before_destroy = true
    
    # Không cho Terraform xóa resource này
    prevent_destroy = true
    
    # Ignore changes đến những attributes này
    ignore_changes = [
      ami,          # Không update khi AMI thay đổi
      tags,         # Ignore tag changes (external tools might add tags)
    ]
    
    # Custom condition trước khi apply
    precondition {
      condition     = var.instance_type != "t2.micro"
      error_message = "t2.micro không được dùng, quá chậm!"
    }
    
    # Custom condition sau khi create
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance should have a public IP"
    }
  }
  
  # Resource phụ thuộc vào resource khác (explicit dependency)
  depends_on = [
    aws_internet_gateway.main,
    aws_security_group.web,
  ]
}
```

---

> **Tiếp theo: Phần 3** - AWS Infrastructure Complete Example & CI/CD với Terraform
