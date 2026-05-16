# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 4: BEST PRACTICES, SECURITY & PATTERNS

---

## 1. Terraform Best Practices

### 1.1 Code Organization

```
# ===== CẤU TRÚC FILE CHUẨN TRONG MỖI MODULE/ROOT =====
.
├── main.tf           ← Resources chính
├── variables.tf      ← Input variables
├── outputs.tf        ← Output values
├── locals.tf         ← Local values (tách riêng nếu phức tạp)
├── data.tf           ← Data sources
├── versions.tf       ← Required providers và versions
├── backend.tf        ← Backend configuration
└── README.md         ← Documentation

# Đừng đặt tất cả vào 1 file main.tf khổng lồ
# Tách theo logical groups:
├── vpc.tf
├── ec2.tf
├── rds.tf
├── iam.tf
└── monitoring.tf
```

### 1.2 Naming Conventions

```hcl
# ===== RESOURCE NAMING =====
# Format: {project}-{environment}-{resource}-{qualifier}

resource "aws_s3_bucket" "app_assets" {      # snake_case
  bucket = "myapp-prod-assets-${random_id.suffix.hex}"
}

# Không dùng:
resource "aws_s3_Bucket" "AppAssets" { }     # PascalCase
resource "aws_s3_bucket" "s3-bucket-1" { }  # Hyphens (không thống nhất)

# ===== VARIABLE NAMING =====
variable "environment" { }         # singular
variable "subnet_ids" { }          # plural cho lists
variable "enable_monitoring" { }   # boolean với enable_/is_/has_

# ===== OUTPUT NAMING =====
output "vpc_id" { }
output "public_subnet_ids" { }

# ===== MODULE SOURCE =====
module "vpc" {                     # lowercase, snake_case
  source = "./modules/vpc"
}
```

### 1.3 Version Pinning

```hcl
# versions.tf
terraform {
  required_version = ">= 1.7.0, < 2.0.0"   # Tránh breaking changes
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"    # ~> = pessimistic constraint
      # ~> 5.30 = >= 5.30, < 6.0
      # ~> 5.30.1 = >= 5.30.1, < 5.31.0
    }
  }
}
```

### 1.4 Tagging Strategy

```hcl
# locals.tf - Common tags cho tất cả resources
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    GitRepo     = "https://github.com/company/infra"
    GitCommit   = var.git_commit_hash   # Biết infra được tạo từ commit nào
    Owner       = var.team_name
    CostCenter  = var.cost_center
    CreatedAt   = timestamp()
  }
}

# Dùng trong provider default tags (tự động apply cho tất cả resources)
provider "aws" {
  default_tags {
    tags = local.common_tags
  }
}

# Resource có thể thêm tags riêng
resource "aws_vpc" "main" {
  tags = {
    Name = "main-vpc"    # Provider sẽ merge với common_tags
  }
}
```

---

## 2. Security Best Practices

### 2.1 Sensitive Data

```hcl
# ===== ĐỪNG BAO GIỜ HARDCODE SECRETS =====
# Sai:
resource "aws_db_instance" "main" {
  password = "SuperSecret123!"    # ← Commit lên git!
}

# Đúng - Dùng biến sensitive:
variable "db_password" {
  type      = string
  sensitive = true   # Không hiện trong logs/plan output
}

resource "aws_db_instance" "main" {
  password = var.db_password
}

# ===== SECRETS SOURCES =====

# 1. Environment variables
# TF_VAR_db_password="SecretPass" terraform apply

# 2. AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "myapp/prod/db-credentials"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}

resource "aws_db_instance" "main" {
  username = local.db_creds.username
  password = local.db_creds.password
}

# 3. HashiCorp Vault
data "vault_generic_secret" "db" {
  path = "secret/myapp/prod/db"
}

# 4. Terraform Cloud - Sensitive variables

# ===== ENCRYPT STATE =====
terraform {
  backend "s3" {
    bucket  = "terraform-state"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true    # AES-256 encryption
    kms_key_id = "arn:aws:kms:us-east-1:123:key/abc123"
  }
}

# ===== STATE KHÔNG NÊN CHỨA SECRETS =====
# Nếu cần output password, mark sensitive:
output "db_password" {
  value     = var.db_password
  sensitive = true    # Không hiện khi terraform output
}
# → Vẫn lưu trong state file! Encrypt state là bắt buộc
```

### 2.2 IAM Best Practices

```hcl
# ===== PRINCIPLE OF LEAST PRIVILEGE =====

# IAM Role cho Terraform (trong CI/CD)
data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]  # OIDC from GitHub Actions
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:company/infra:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name               = "terraform-ci"
  assume_role_policy = data.aws_iam_policy_document.terraform_assume_role.json
}

# Chỉ cấp quyền cần thiết
data "aws_iam_policy_document" "terraform_ci_policy" {
  # VPC permissions
  statement {
    actions   = ["ec2:Describe*", "ec2:Create*", "ec2:Delete*", "ec2:Modify*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-southeast-1"]  # Chỉ region này
    }
  }
  
  # RDS permissions - chỉ specific resources
  statement {
    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:Describe*"
    ]
    resources = [
      "arn:aws:rds:ap-southeast-1:*:db:myapp-*"  # Chỉ myapp-* instances
    ]
  }
  
  # S3 - chỉ specific buckets
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::myapp-*",
      "arn:aws:s3:::myapp-*/*"
    ]
  }
}
```

### 2.3 Security Scanning

```bash
# ===== CHECKOV - Security scanner for Terraform =====
pip install checkov

checkov -d .                    # Scan thư mục hiện tại
checkov -f main.tf              # Scan file cụ thể
checkov -d . --framework terraform

# Output:
# Check: CKV_AWS_8: "Ensure EBS volume is encrypted"
# PASSED for resource: aws_ebs_volume.data
# FAILED for resource: aws_ebs_volume.temp

checkov -d . --quiet            # Chỉ show failures
checkov -d . --skip-check CKV_AWS_8  # Skip specific check

# ===== TFSEC - Security scanner =====
brew install tfsec
tfsec .
tfsec . --minimum-severity MEDIUM

# ===== TERRASCAN =====
brew install terrascan
terrascan scan -t aws -i terraform

# ===== INFRACOST - Cost estimation =====
brew install infracost
infracost configure set api_key YOUR_KEY
infracost breakdown --path . --terraform-var-file=terraform.tfvars
# → Estimate monthly cost của changes
```

---

## 3. Advanced Patterns

### 3.1 Conditional Resources

```hcl
variable "enable_bastion" {
  type    = bool
  default = false
}

variable "environment" {
  type    = string
}

# Tạo conditional resource
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0    # 0 hoặc 1
  
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"
  subnet_id     = aws_subnet.public[0].id
}

# Reference conditional resource
output "bastion_ip" {
  value = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

# Environment-based resources
resource "aws_cloudwatch_log_group" "app" {
  name              = "/myapp/${var.environment}"
  retention_in_days = var.environment == "production" ? 90 : 7
}
```

### 3.2 Data Source Patterns

```hcl
# ===== LẤY THÔNG TIN TỪ EXISTING INFRASTRUCTURE =====

# Cross-account data
data "aws_vpc" "shared" {
  provider = aws.shared_services   # Different provider/account
  id       = "vpc-shared12345"
}

# Find latest AMI
data "aws_ami" "app" {
  most_recent = true
  owners      = [var.aws_account_id]  # Our own AMIs
  
  filter {
    name   = "name"
    values = ["myapp-*"]
  }
  
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
}

# Get secret from AWS Secrets Manager
data "aws_secretsmanager_secret" "db" {
  name = "/myapp/${var.environment}/database"
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_secretsmanager_secret.db.id
}

locals {
  db_secret = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}

# Remote state data source (cross-team)
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "company-terraform-state"
    key    = "networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]
}
```

### 3.3 Multi-Region và Multi-Account

```hcl
# providers.tf
provider "aws" {
  alias  = "primary"
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "dr"      # Disaster Recovery
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "shared"
  region = "ap-southeast-1"
  assume_role {
    role_arn = "arn:aws:iam::SHARED_ACCOUNT:role/TerraformCrossAccount"
  }
}

# S3 bucket với replication cross-region
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "myapp-data-primary"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.dr
  bucket   = "myapp-data-replica"
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  role     = aws_iam_role.replication.arn
  
  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# Module với provider alias
module "vpc_dr" {
  source = "./modules/vpc"
  
  providers = {
    aws = aws.dr    # Pass DR provider vào module
  }
  
  environment  = "dr"
  vpc_cidr     = "10.1.0.0/16"
  project_name = var.project_name
}
```

---

## 4. Terragrunt - DRY Terraform

```hcl
# Terragrunt = Wrapper cho Terraform, giải quyết code duplication

# Cấu trúc với Terragrunt:
# live/
# ├── terragrunt.hcl              ← Root config
# ├── staging/
# │   ├── terragrunt.hcl
# │   ├── vpc/
# │   │   └── terragrunt.hcl
# │   ├── ec2/
# │   │   └── terragrunt.hcl
# │   └── rds/
# │       └── terragrunt.hcl
# └── production/
#     ├── terragrunt.hcl
#     ├── vpc/
#     │   └── terragrunt.hcl
#     └── ...

# Root terragrunt.hcl
# live/terragrunt.hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "company-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }
}
EOF
}

# Environment config
# live/staging/terragrunt.hcl
locals {
  environment = "staging"
}

inputs = {
  environment  = local.environment
  project_name = "myapp"
}

# VPC module config
# live/staging/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//vpc"
}

inputs = {
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_count = 2
  enable_nat_gateway  = false    # Staging: Save cost
}

# EC2 depends on VPC
# live/staging/ec2/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//ec2"
}

dependency "vpc" {
  config_path = "../vpc"   # ← Auto get outputs từ VPC module!
}

inputs = {
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
```

```bash
# Terragrunt commands
terragrunt plan
terragrunt apply

# Run all modules trong folder
terragrunt run-all plan
terragrunt run-all apply

# Chỉ affected modules
terragrunt run-all plan --terragrunt-modules-that-include ./staging/vpc
```

---

## 5. Cheat Sheet

```bash
# ===== WORKFLOW =====
terraform init              # Initialize
terraform fmt               # Format code
terraform validate          # Validate syntax
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy all

# ===== STATE =====
terraform state list                    # List resources
terraform state show aws_vpc.main      # Show resource details
terraform state mv old new             # Rename resource
terraform state rm resource.name       # Remove from state
terraform import aws_vpc.main vpc-xxx  # Import existing

# ===== DEBUGGING =====
TF_LOG=DEBUG terraform plan            # Debug logging
TF_LOG_PATH=debug.log terraform plan   # Log to file

# ===== USEFUL COMMANDS =====
terraform output                       # Show outputs
terraform output -json | jq .         # JSON format
terraform console                      # Interactive REPL
terraform graph | dot -Tsvg > graph.svg  # Dependency graph

# ===== TIPS =====
# Target specific resource
terraform plan -target=module.vpc
terraform apply -target=aws_instance.web[0]

# Replace (force recreate)
terraform apply -replace=aws_instance.web[0]

# Skip confirmation
terraform apply -auto-approve

# Show plan in JSON
terraform plan -out=tfplan
terraform show -json tfplan | jq .
```

---

> **Tiếp theo: Phần 5** - Troubleshooting, Patterns & Real-World Terraform
