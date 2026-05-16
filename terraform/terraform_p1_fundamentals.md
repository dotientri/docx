# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 1: NỀN TẢNG & KIẾN TRÚC

---

## 1. Terraform Là Gì?

### 1.1 Infrastructure as Code (IaC)

**IaC** = Quản lý và cung cấp infrastructure thông qua code thay vì quy trình thủ công.

**Trước IaC:**
```
1. Vào AWS Console (click, click, click)
2. Tạo VPC... cấu hình subnets... 
3. Tạo Security Groups...
4. Launch EC2 instances...
5. Cấu hình Load Balancer...
→ 2 giờ sau: Done (và không ai biết mình đã làm gì chính xác)

Tuần sau: Dựng môi trường staging → Làm lại từ đầu!
Khi có lỗi: Không biết config khác ở đâu!
```

**Với Terraform:**
```hcl
# main.tf - Mô tả infrastructure bằng code
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  vpc_id        = aws_vpc.main.id
}
```

```bash
terraform apply  # 30 giây → Infrastructure sẵn sàng
# Muốn replicate cho staging:
terraform workspace new staging && terraform apply
```

### 1.2 Tại Sao Terraform?

| Tính Năng | Terraform | CloudFormation | Pulumi | ARM Templates |
|-----------|-----------|----------------|--------|---------------|
| Language | HCL | JSON/YAML | Python/TypeScript | JSON |
| Multi-cloud | ✅ Tất cả clouds | ❌ AWS only | ✅ | ❌ Azure only |
| State management | Local/Remote | AWS manages | Local/Remote | Azure manages |
| Community | Rất lớn | Lớn | Nhỏ hơn | Nhỏ |
| Import existing | ✅ | Khó | ✅ | ❌ |

**Terraform nổi bật vì:**
- **Multi-cloud:** 1 tool cho AWS, Azure, GCP, Kubernetes, GitHub, Cloudflare...
- **Declarative:** Mô tả trạng thái cuối, không phải các bước
- **Plan trước:** `terraform plan` xem những gì sẽ thay đổi trước khi apply
- **State:** Track trạng thái thực tế của infrastructure
- **Modules:** Package và tái sử dụng patterns

---

## 2. Kiến Trúc Terraform

### 2.1 Terraform Architecture

```
┌───────────────────────────────────────────────────────┐
│                   Terraform CLI                        │
│                                                        │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐  │
│  │  Config  │  │  State   │  │     Providers      │  │
│  │  Files   │  │  File    │  │  (AWS, Azure, GCP) │  │
│  │  (.tf)   │  │(.tfstate)│  │                    │  │
│  └──────────┘  └──────────┘  └────────────────────┘  │
│                                                        │
└───────────────────────────────────────────────────────┘
                          │
              ┌───────────┼────────────┐
              ▼           ▼            ▼
          AWS API    Azure API     GCP API
          (EC2, etc) (VM, etc)   (GKE, etc)
```

### 2.2 Core Concepts

**Provider:**
- Plugin kết nối Terraform với infrastructure platform
- `aws`, `azurerm`, `google`, `kubernetes`, `github`, `cloudflare`...
- Provider quản lý authentication và API calls

**Resource:**
- Đơn vị infrastructure (EC2 instance, S3 bucket, DNS record...)
- Được tạo/quản lý bởi provider

**Data Source:**
- Query thông tin đã tồn tại (không tạo mới)
- Ví dụ: Tìm AMI mới nhất, lấy thông tin VPC sẵn có

**State:**
- File JSON ghi lại trạng thái hiện tại của infrastructure
- Terraform dùng state để biết cần thay đổi gì
- CỰC KỲ QUAN TRỌNG - mất state = không biết gì về infrastructure

**Plan:**
- Terraform đọc config + state → Tính toán difference
- Hiện những gì sẽ được thêm/thay đổi/xóa
- Chưa apply gì cả

**Apply:**
- Thực thi plan
- Gọi API của provider để tạo/sửa/xóa resources

---

## 3. Cài Đặt Terraform

### 3.1 Cài Đặt

```bash
# ===== UBUNTU/DEBIAN =====
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform

# ===== CENTOS/RHEL =====
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install terraform

# ===== macOS =====
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# ===== Kiểm tra =====
terraform version
# Terraform v1.7.0

# ===== TFENV (Version Manager - Khuyến nghị) =====
# Giống pyenv nhưng cho Terraform
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="~/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

tfenv install 1.7.0
tfenv use 1.7.0
tfenv list
```

### 3.2 Cấu Hình AWS Provider

```bash
# ===== SETUP AWS CREDENTIALS =====

# Cách 1: AWS CLI
aws configure
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI...
# Default region: ap-southeast-1
# Default output format: json

# Cách 2: Environment variables (cho CI/CD)
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI..."
export AWS_DEFAULT_REGION="ap-southeast-1"

# Cách 3: IAM Roles (trên EC2/ECS - BEST PRACTICE, không cần keys!)
# → Terraform tự động lấy credentials từ instance metadata

# Cách 4: AWS Profiles (~/.aws/credentials)
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[production]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

# Dùng profile:
export AWS_PROFILE=production
```

---

## 4. Cú Pháp HCL - HashiCorp Configuration Language

### 4.1 Cơ Bản

```hcl
# main.tf

# ===== PROVIDER CONFIGURATION =====
terraform {
  required_version = ">= 1.5.0"          # Yêu cầu Terraform version
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"                  # ~> = compatible: >= 5.0, < 6.0
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Remote state backend
  backend "s3" {
    bucket  = "my-terraform-state"
    key     = "production/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = "production"
  
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# ===== RESOURCES =====
# Syntax: resource "<provider>_<type>" "<local_name>" { }
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id            # Reference other resource
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
}

# ===== DATA SOURCES =====
# Query existing resources (read-only, không tạo mới)
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===== OUTPUTS =====
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}
```

### 4.2 Variables

```hcl
# variables.tf
variable "environment" {
  description = "Deployment environment (staging/production)"
  type        = string
  default     = "staging"
  
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Must be staging or production"
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 2
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "List of IPs allowed to SSH"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    storage_gb     = number
    multi_az       = bool
  })
  default = {
    engine         = "postgres"
    engine_version = "15.4"
    instance_class = "db.t3.micro"
    storage_gb     = 20
    multi_az       = false
  }
}

# Sensitive variable (không hiện trong logs)
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```

```bash
# Cung cấp variable values:

# Cách 1: terraform.tfvars (auto-loaded)
cat terraform.tfvars
environment    = "production"
project_name   = "myapp"
instance_count = 5
db_password    = "SuperSecret123!"

# Cách 2: *.auto.tfvars (auto-loaded)
cat production.auto.tfvars
environment = "production"

# Cách 3: -var flag
terraform apply -var="environment=staging" -var="instance_count=2"

# Cách 4: -var-file flag
terraform apply -var-file="staging.tfvars"

# Cách 5: Environment variables (TF_VAR_ prefix)
export TF_VAR_environment="production"
export TF_VAR_db_password="SuperSecret123!"
terraform apply
```

### 4.3 Locals

```hcl
# Tính toán giá trị một lần, dùng nhiều nơi
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  })
  
  # Name prefix
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Tính toán phức tạp
  instance_count = var.environment == "production" ? 3 : 1
  
  # Conditional logic
  is_production = var.environment == "production"
  
  # Database name từ project name
  db_name = replace(var.project_name, "-", "_")
}

resource "aws_instance" "web" {
  count = local.instance_count
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
  })
}
```

---

## 5. Vòng Lặp Và Meta-Arguments

### 5.1 count - Tạo Nhiều Resources

```hcl
# Tạo 3 EC2 instances
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  tags = {
    Name = "web-${count.index + 1}"  # web-1, web-2, web-3
  }
}

# Reference: aws_instance.web[0], aws_instance.web[1], aws_instance.web[2]
# All instances: aws_instance.web[*]

output "web_ips" {
  value = aws_instance.web[*].private_ip
}
```

### 5.2 for_each - Tạo Resources Từ Map/Set

```hcl
# Tốt hơn count khi resource có tên riêng
variable "subnets" {
  default = {
    public-1  = "10.0.1.0/24"
    public-2  = "10.0.2.0/24"
    private-1 = "10.0.10.0/24"
    private-2 = "10.0.11.0/24"
  }
}

resource "aws_subnet" "this" {
  for_each = var.subnets
  
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value    # each.key = "public-1", each.value = "10.0.1.0/24"
  
  tags = {
    Name = "${var.project_name}-${each.key}"
    Type = startswith(each.key, "public") ? "public" : "private"
  }
}

# Reference: aws_subnet.this["public-1"], aws_subnet.this["private-1"]

# For_each với set of strings
resource "aws_iam_group" "developers" {
  for_each = toset(["backend", "frontend", "devops"])
  name     = each.value
}
```

### 5.3 Dynamic Blocks

```hcl
variable "ingress_rules" {
  default = [
    { port = 80,  protocol = "tcp", cidr = ["0.0.0.0/0"] },
    { port = 443, protocol = "tcp", cidr = ["0.0.0.0/0"] },
    { port = 22,  protocol = "tcp", cidr = ["10.0.0.0/8"] },
  ]
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id
  
  # Dynamic block thay vì viết lặp nhiều ingress blocks
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr
    }
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 6. Terraform Commands - Vòng Đời

```bash
# ===== KHỞI TẠO =====
terraform init
# → Download providers
# → Setup backend
# → Download modules
# Phải chạy sau khi tạo mới hoặc thêm providers

terraform init -upgrade    # Upgrade providers

# ===== XEM TRƯỚC =====
terraform plan
# → Xem những gì sẽ thay đổi (+ add, ~ change, - destroy)
# → Không thay đổi gì cả

terraform plan -out=tfplan         # Lưu plan vào file
terraform plan -destroy             # Plan để destroy tất cả

# ===== APPLY =====
terraform apply                     # Sẽ hỏi "yes"
terraform apply -auto-approve       # Không hỏi (dùng trong CI/CD)
terraform apply tfplan              # Apply từ saved plan (no changes)

# ===== XÓA =====
terraform destroy                   # Xóa tất cả resources
terraform destroy -auto-approve
terraform destroy -target=aws_instance.web[0]  # Chỉ xóa 1 resource

# ===== KIỂM TRA =====
terraform validate    # Validate cú pháp và cấu hình
terraform fmt         # Format code chuẩn (auto-format)
terraform fmt -check  # Check format (không sửa, dùng trong CI)
terraform fmt -diff   # Hiện diff
terraform fmt -recursive  # Recursive tất cả files

# ===== STATE =====
terraform show                      # Xem state hiện tại
terraform state list                # List resources trong state
terraform state show aws_vpc.main   # Chi tiết 1 resource
terraform state mv old_name new_name  # Rename resource trong state
terraform state rm aws_instance.web[0]  # Remove từ state (không xóa thực tế)
terraform state pull                # Download state
terraform state push                # Upload state
terraform import aws_vpc.main vpc-12345  # Import existing resource

# ===== WORKSPACE =====
terraform workspace list
terraform workspace new staging
terraform workspace select production
terraform workspace show           # Current workspace
terraform workspace delete staging

# ===== OUTPUT =====
terraform output                   # Xem tất cả outputs
terraform output vpc_id            # Xem output cụ thể
terraform output -json             # JSON format
```

---

> **Tiếp theo: Phần 2** - Modules, State Management & Remote Backend
