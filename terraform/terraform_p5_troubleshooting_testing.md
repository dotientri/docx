# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 5: TROUBLESHOOTING, TESTING & REAL-WORLD

---

## 1. Troubleshooting Common Issues

### 1.1 State Issues

```bash
# ===== VẤN ĐỀ: State Locked =====
# Error: Error acquiring the state lock

# Xem lock info
terraform force-unlock <LOCK-ID>
# Cẩn thận! Chỉ dùng khi chắc không có ai đang apply

# Với DynamoDB backend - xem lock trực tiếp
aws dynamodb scan --table-name terraform-state-lock
# Xóa lock thủ công nếu bị kẹt
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "bucket/key.tfstate"}}'

# ===== VẤN ĐỀ: State Drift =====
# Infrastructure đã bị thay đổi bên ngoài Terraform

# Xem drift
terraform plan -refresh-only

# Accept drift (update state to match actual)
terraform apply -refresh-only

# Overwrite drift (apply Terraform config)
terraform apply

# ===== VẤN ĐỀ: Resource "bị mất" khỏi state =====
# Resource exists in AWS nhưng không có trong state

# Import lại
terraform import aws_instance.web i-0123456789abcdef

# Bulk import (Terraform 1.5+)
import {
  to = aws_instance.web
  id = "i-0123456789abcdef"
}

# ===== VẤN ĐỀ: Corrupt State =====
# S3 versioning giúp rollback

aws s3api list-object-versions \
  --bucket terraform-state-bucket \
  --prefix production/terraform.tfstate

# Restore previous version
aws s3api copy-object \
  --bucket terraform-state-bucket \
  --copy-source terraform-state-bucket/production/terraform.tfstate?versionId=VERSION_ID \
  --key production/terraform.tfstate
```

### 1.2 Provider và Dependency Issues

```bash
# ===== PROVIDER VERSION CONFLICT =====
# Error: Inconsistent dependency lock file

# Xóa và reinit
rm -rf .terraform .terraform.lock.hcl
terraform init

# Update tất cả providers
terraform init -upgrade

# ===== DEPENDENCY CYCLES =====
# Error: Cycle detected

# Xem dependency graph
terraform graph | grep -v "^\s*}" | dot -Tsvg > deps.svg
# Mở deps.svg trong browser để xem cycle

# Giải quyết: Sử dụng depends_on explicit
# hoặc chia module ra thành nhiều phần

# ===== PROVIDER TIMEOUT =====
# Tăng timeout trong provider
provider "aws" {
  # Retry configuration
  retry_mode         = "standard"
  max_retries        = 10
  http_proxy         = null
  
  # Token duration
  assume_role {
    role_arn     = "arn:aws:iam::..."
    duration_seconds = 3600
  }
}

# Resource-level timeout
resource "aws_db_instance" "main" {
  timeouts {
    create = "60m"
    update = "80m"
    delete = "60m"
  }
}

# ===== KNOWN ISSUES =====
# 1. Resource deleted outside Terraform
terraform apply
# → Terraform sẽ tạo lại resource

# 2. Attribute changed outside Terraform
terraform plan
# → Hiện diff, apply để fix

# 3. Invalid provider credentials
export AWS_PROFILE=correct-profile
aws sts get-caller-identity    # Verify credentials
terraform plan
```

### 1.3 Debugging

```bash
# ===== VERBOSE LOGGING =====
TF_LOG=TRACE terraform apply 2>&1 | head -100

# Log levels: TRACE, DEBUG, INFO, WARN, ERROR
TF_LOG=DEBUG terraform plan

# Log to file
TF_LOG=DEBUG TF_LOG_PATH=./terraform-debug.log terraform apply

# ===== TERRAFORM CONSOLE (Interactive REPL) =====
terraform console

# Trong console:
> var.environment
"production"

> local.name_prefix
"myapp-production"

> cidrsubnet("10.0.0.0/16", 8, 5)
"10.0.5.0/24"

> length(var.subnet_ids)
3

> jsondecode(file("config.json"))

# ===== PLAN JSON OUTPUT =====
terraform plan -out=tfplan -json 2>&1 | tee plan.json
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions[] | contains("delete"))'
# → Xem chỉ những gì bị xóa
```

---

## 2. Testing Terraform

### 2.1 Terraform Test (Built-in - v1.6+)

```hcl
# tests/vpc.tftest.hcl

# Variables cho test
variables {
  environment  = "test"
  project_name = "myapp-test"
  vpc_cidr     = "10.0.0.0/16"
}

# Test 1: VPC được tạo đúng
run "vpc_is_created" {
  command = plan    # plan hoặc apply
  
  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR does not match"
  }
  
  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled"
  }
}

# Test 2: Subnets trong đúng AZs
run "subnets_in_multiple_azs" {
  command = apply
  
  assert {
    condition = length(distinct([
      for subnet in aws_subnet.public : subnet.availability_zone
    ])) >= 2
    error_message = "Should have subnets in at least 2 AZs"
  }
}

# Test 3: Tags đúng
run "resources_have_required_tags" {
  assert {
    condition     = contains(keys(aws_vpc.main.tags), "Environment")
    error_message = "VPC should have Environment tag"
  }
  
  assert {
    condition     = aws_vpc.main.tags["Environment"] == var.environment
    error_message = "Environment tag value incorrect"
  }
}
```

```bash
# Chạy tests
terraform test
terraform test -filter tests/vpc.tftest.hcl
terraform test -verbose
```

### 2.2 Terratest (Go Testing Framework)

```go
// tests/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
    t.Parallel()
    
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        
        Vars: map[string]interface{}{
            "vpc_cidr":     "10.0.0.0/16",
            "environment":  "test",
            "project_name": "terratest",
        },
        
        // Retry để handle eventual consistency
        MaxRetries:         3,
        TimeBetweenRetries: 5 * time.Second,
    }
    
    // Cleanup sau test
    defer terraform.Destroy(t, terraformOptions)
    
    // Init và Apply
    terraform.InitAndApply(t, terraformOptions)
    
    // Validate outputs
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
    
    publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
    assert.Equal(t, 2, len(publicSubnetIds))
    
    // Validate bằng AWS SDK
    sess, _ := session.NewSession(&aws.Config{Region: aws.String("ap-southeast-1")})
    ec2Svc := ec2.New(sess)
    
    vpc, err := ec2Svc.DescribeVpcs(&ec2.DescribeVpcsInput{
        VpcIds: []*string{aws.String(vpcId)},
    })
    
    assert.NoError(t, err)
    assert.Equal(t, "10.0.0.0/16", *vpc.Vpcs[0].CidrBlock)
    assert.True(t, *vpc.Vpcs[0].EnableDnsHostnames)
}

func TestALBModule(t *testing.T) {
    // Test ALB module...
}
```

```bash
# Chạy Terratest
go test ./... -v -timeout 30m
go test ./tests/... -run TestVPCModule -v
```

### 2.3 Validate Policies

```bash
# ===== OPA (Open Policy Agent) với Terraform =====
# Validate Terraform plan với policies

# policy.rego
cat > policy.rego << 'EOF'
package terraform

# Deny EC2 instances không có encrypted storage
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    not resource.change.after.ebs_optimized
    msg := sprintf("Instance %s should be EBS optimized", [resource.address])
}

# Require minimum instance size trong production
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    resource.change.after.tags.Environment == "production"
    resource.change.after.instance_type == "t2.micro"
    msg := sprintf("t2.micro not allowed in production: %s", [resource.address])
}

# All resources must have required tags
required_tags := ["Environment", "Project", "ManagedBy"]

deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    tag := required_tags[_]
    not resource.change.after.tags[tag]
    msg := sprintf("Resource %s missing required tag: %s", [resource.address, tag])
}
EOF

# Validate
terraform show -json tfplan > plan.json
opa eval -d policy.rego -I plan.json "data.terraform.deny"
```

---

## 3. Real-World Patterns

### 3.1 GitOps với Terraform

```yaml
# Atlantis configuration
# atlantis.yaml
version: 3
automerge: false
delete_source_branch_on_merge: true

projects:
  - name: myapp-staging
    dir: environments/staging
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars", "../modules/**/*.tf"]
      enabled: true
    apply_requirements:
      - approved    # Require PR approval before apply
      
  - name: myapp-production
    dir: environments/production
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars", "../modules/**/*.tf"]
      enabled: true
    apply_requirements:
      - approved
      - mergeable   # PR must be mergeable
```

```
GitOps Workflow:
1. Developer tạo PR thay đổi Terraform code
2. Atlantis tự động chạy terraform plan
3. Plan output được comment vào PR
4. Reviewer approve PR
5. Developer comment "atlantis apply"
6. Atlantis apply, output vào PR comment
7. Merge PR
```

### 3.2 Disaster Recovery Pattern

```hcl
# DR configuration
variable "enable_dr" {
  description = "Enable Disaster Recovery setup"
  type        = bool
  default     = false
}

# RDS Read Replica cho DR
resource "aws_db_instance" "replica" {
  count = var.enable_dr ? 1 : 0
  
  provider = aws.dr_region
  
  identifier             = "${var.project_name}-dr-replica"
  replicate_source_db    = aws_db_instance.main.arn
  instance_class         = var.db_instance_class
  
  # DR replica settings
  auto_minor_version_upgrade  = false
  backup_retention_period     = 0    # Read replicas can't have backups
  skip_final_snapshot         = true
  
  tags = { Role = "DR-Replica" }
}

# Route53 health check cho failover
resource "aws_route53_health_check" "primary" {
  fqdn              = aws_lb.primary.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain}"
  type    = "A"
  
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  health_check_id = aws_route53_health_check.primary.id
  set_identifier  = "primary"
  
  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_failover" {
  count = var.enable_dr ? 1 : 0
  
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain}"
  type    = "A"
  
  failover_routing_policy {
    type = "SECONDARY"
  }
  
  set_identifier = "dr"
  
  alias {
    name                   = aws_lb.dr[0].dns_name
    zone_id                = aws_lb.dr[0].zone_id
    evaluate_target_health = true
  }
}
```

---

## 4. Terraform Cloud & Enterprise

```hcl
# Terraform Cloud - Managed service từ HashiCorp

terraform {
  cloud {
    organization = "my-company"
    
    workspaces {
      # Option 1: Single workspace
      name = "myapp-production"
      
      # Option 2: Workspace theo tags
      # tags = ["myapp", "production"]
    }
  }
}
```

**Terraform Cloud Features:**
- Remote state management (no S3 needed)
- Remote plan/apply (không cần local execution)
- Policy as Code (Sentinel)
- Team management & RBAC
- Cost estimation
- Audit logs
- SSO integration

```
# Sentinel Policy (Terraform Cloud Enterprise)
# policy.sentinel

import "tfplan/v2" as tfplan

# All S3 buckets must have encryption
main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_s3_bucket" or
    rc.change.after.server_side_encryption_configuration is not null
  }
}
```

---

## 5. Comparison: Terraform vs OpenTofu

```bash
# OpenTofu = Open source fork của Terraform
# Sau khi HashiCorp đổi license sang BSL (Business Source License) tháng 8/2023
# OpenTofu vẫn dùng MPL 2.0 (open source thực sự)

# Điểm giống nhau:
# - Hầu hết syntax HCL giống nhau
# - Tương thích với hầu hết providers
# - Commands giống nhau

# Điểm khác nhau:
# - OpenTofu: Open governance, CNCF project
# - Terraform: HashiCorp controlled

# Cài OpenTofu
brew install opentofu
tofu version

# Migrate từ Terraform sang OpenTofu
# 1. Backup state
# 2. Cài OpenTofu
# 3. Chạy: tofu init
# Hầu hết code tương thích hoàn toàn
```

---

## 6. Cheat Sheet Cuối

```bash
# INIT & SETUP
terraform init                    # Initialize
terraform init -upgrade           # Upgrade providers
terraform init -backend-config=backend.hcl  # External backend config

# PLAN & APPLY
terraform plan                    # Preview
terraform plan -out=tfplan        # Save plan
terraform plan -destroy           # Plan to destroy
terraform apply                   # Apply (with confirm)
terraform apply -auto-approve     # No confirm
terraform apply tfplan            # Apply saved plan
terraform apply -target=resource  # Target specific resource
terraform apply -replace=resource # Force recreate

# DESTROY
terraform destroy                 # Destroy all
terraform destroy -target=module.rds  # Destroy specific

# STATE MANAGEMENT
terraform state list
terraform state show address
terraform state mv old new
terraform state rm address
terraform state pull > backup.tfstate
terraform import address id

# DEBUGGING
TF_LOG=DEBUG terraform plan
terraform console                 # REPL
terraform graph | dot -Tsvg > graph.svg

# FORMATTING & VALIDATION
terraform fmt -recursive
terraform validate
terraform fmt -check              # CI check (exit 1 if unformatted)

# WORKSPACES
terraform workspace list
terraform workspace new staging
terraform workspace select prod
terraform workspace show

# OUTPUTS
terraform output
terraform output -json
terraform output vpc_id
```

---

> **Hoàn thành Terraform Toàn Tập!** Tiếp theo: Kubernetes & Azure
