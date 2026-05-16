# 🏗️ TERRAFORM TOÀN TẬP - PHẦN 3: AWS INFRASTRUCTURE HOÀN CHỈNH

---

## 1. Dự Án Hoàn Chỉnh: 3-Tier Web Application

### 1.1 Architecture

```
Internet
    │
    ▼
Application Load Balancer (Public)
    │
    ▼
Auto Scaling Group - Web/API Servers (Private Subnet)
    │
    ▼
RDS PostgreSQL Multi-AZ (Private Subnet)
    │
ElastiCache Redis (Private Subnet)
```

### 1.2 Cấu Trúc Project

```
myapp-terraform/
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── modules/
    ├── networking/          # VPC, Subnets, IGW, NAT
    ├── security-groups/     # All SGs
    ├── alb/                 # Application Load Balancer
    ├── asg/                 # Auto Scaling Group
    ├── rds/                 # RDS PostgreSQL
    └── elasticache/         # Redis
```

### 1.3 Security Groups Module

```hcl
# modules/security-groups/main.tf

variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }

# ===== ALB Security Group =====
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.project_name}-${var.environment}-alb-sg" }
}

# ===== Application Security Group =====
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id
  
  # Traffic từ ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }
  
  # SSH từ bastion host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.project_name}-${var.environment}-app-sg" }
}

# ===== Database Security Group =====
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for database"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from app servers"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.project_name}-${var.environment}-db-sg" }
}

# ===== Redis Security Group =====
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Redis from app servers"
  }
  
  tags = { Name = "${var.project_name}-${var.environment}-redis-sg" }
}

# ===== Bastion Security Group =====
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH from authorized IPs"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.project_name}-${var.environment}-bastion-sg" }
}

output "alb_sg_id"    { value = aws_security_group.alb.id }
output "app_sg_id"    { value = aws_security_group.app.id }
output "db_sg_id"     { value = aws_security_group.db.id }
output "redis_sg_id"  { value = aws_security_group.redis.id }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
```

### 1.4 ALB Module

```hcl
# modules/alb/main.tf

variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "certificate_arn" { type = string }
variable "health_check_path" { type = string; default = "/health" }

# ===== ALB =====
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = true    # Production safety
  enable_http2               = true
  
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = var.name_prefix
    enabled = true
  }
  
  tags = { Name = "${var.name_prefix}-alb" }
}

# ===== S3 BUCKET FOR LOGS =====
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.name_prefix}-alb-logs-${random_id.suffix.hex}"
}

resource "random_id" "suffix" { byte_length = 4 }

# ===== TARGET GROUP =====
resource "aws_lb_target_group" "app" {
  name     = "${var.name_prefix}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }
  
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }
}

# ===== LISTENERS =====
# HTTP → HTTPS Redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_dns_name"       { value = aws_lb.main.dns_name }
output "alb_arn"            { value = aws_lb.main.arn }
output "target_group_arn"   { value = aws_lb_target_group.app.arn }
output "https_listener_arn" { value = aws_lb_listener.https.arn }
```

### 1.5 Auto Scaling Group Module

```hcl
# modules/asg/main.tf

variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_group_arn" { type = string }
variable "instance_type" { type = string; default = "t3.micro" }
variable "min_size" { type = number; default = 1 }
variable "max_size" { type = number; default = 10 }
variable "desired_capacity" { type = number; default = 2 }
variable "ami_id" { type = string }
variable "key_name" { type = string }
variable "user_data" { type = string; default = "" }
variable "iam_instance_profile" { type = string; default = "" }

# ===== LAUNCH TEMPLATE =====
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  vpc_security_group_ids = var.security_group_ids
  
  user_data = base64encode(var.user_data)
  
  iam_instance_profile {
    name = var.iam_instance_profile
  }
  
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }
  
  monitoring {
    enabled = true  # CloudWatch detailed monitoring
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 (security!)
    http_put_response_hop_limit = 1
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name_prefix}-app" }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# ===== AUTO SCALING GROUP =====
resource "aws_autoscaling_group" "app" {
  name                = "${var.name_prefix}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  # Instance refresh (rolling update)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }
  
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app"
    propagate_at_launch = true
  }
}

# ===== SCALING POLICIES =====
# Scale out khi CPU > 70%
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name_prefix}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# Scale in khi CPU < 30%
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name_prefix}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 600
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.name_prefix}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  
  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}
```

### 1.6 RDS Module

```hcl
# modules/rds/main.tf

variable "name_prefix" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string; sensitive = true }
variable "instance_class" { type = string; default = "db.t3.micro" }
variable "allocated_storage" { type = number; default = 20 }
variable "multi_az" { type = bool; default = false }
variable "backup_retention_days" { type = number; default = 7 }

# ===== SUBNET GROUP =====
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  
  tags = { Name = "${var.name_prefix}-db-subnet-group" }
}

# ===== PARAMETER GROUP =====
resource "aws_db_parameter_group" "postgres15" {
  name   = "${var.name_prefix}-pg15"
  family = "postgres15"
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1 second
  }
  
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }
}

# ===== RDS INSTANCE =====
resource "aws_db_instance" "main" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class
  
  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2  # Auto scaling
  storage_type          = "gp3"
  storage_encrypted     = true
  iops                  = var.allocated_storage >= 400 ? 3000 : null
  
  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  
  # High Availability
  multi_az = var.multi_az
  
  # Backup
  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  
  # Performance
  parameter_group_name = aws_db_parameter_group.postgres15.name
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  monitoring_interval = 60  # Enhanced monitoring
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  # Protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.name_prefix}-final-snapshot"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password]  # Managed outside Terraform
  }
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

output "endpoint" { value = aws_db_instance.main.endpoint }
output "address"  { value = aws_db_instance.main.address }
output "port"     { value = aws_db_instance.main.port }
output "db_name"  { value = aws_db_instance.main.db_name }
```

### 1.7 Root Module - Tất Cả Gọi Lại

```hcl
# environments/production/main.tf

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/myapp.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "production"
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# ===== DATA =====
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ===== MODULES =====
module "networking" {
  source = "../../modules/networking"
  
  project_name        = var.project_name
  environment         = "production"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_count  = 3
  private_subnet_count = 3
  enable_nat_gateway  = true
}

module "security_groups" {
  source = "../../modules/security-groups"
  
  vpc_id            = module.networking.vpc_id
  vpc_cidr          = module.networking.vpc_cidr
  project_name      = var.project_name
  environment       = "production"
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "alb" {
  source = "../../modules/alb"
  
  name_prefix        = "${var.project_name}-prod"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
  certificate_arn    = var.ssl_certificate_arn
  health_check_path  = "/health"
}

module "asg" {
  source = "../../modules/asg"
  
  name_prefix         = "${var.project_name}-prod"
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  security_group_ids  = [module.security_groups.app_sg_id]
  target_group_arn    = module.alb.target_group_arn
  instance_type       = "t3.medium"
  min_size            = 2
  max_size            = 20
  desired_capacity    = 4
  ami_id              = data.aws_ami.ubuntu.id
  key_name            = var.key_name
  
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Install app
    apt-get update -y
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    
    # Login ECR
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${var.ecr_registry}
    
    # Start app
    docker pull ${var.ecr_registry}/${var.project_name}:${var.app_version}
    docker run -d \
      -p 8080:8080 \
      -e DB_HOST=${module.rds.address} \
      -e DB_NAME=${var.db_name} \
      -e REDIS_HOST=${module.elasticache.redis_endpoint} \
      --restart unless-stopped \
      ${var.ecr_registry}/${var.project_name}:${var.app_version}
  EOF
}

module "rds" {
  source = "../../modules/rds"
  
  name_prefix           = "${var.project_name}-prod"
  private_subnet_ids    = module.networking.private_subnet_ids
  security_group_ids    = [module.security_groups.db_sg_id]
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  instance_class        = "db.t3.small"
  allocated_storage     = 100
  multi_az              = true    # Production: Multi-AZ!
  backup_retention_days = 30
}

# ===== OUTPUTS =====
output "application_url" {
  value       = "https://${module.alb.alb_dns_name}"
  description = "Application URL"
}

output "database_endpoint" {
  value       = module.rds.endpoint
  sensitive   = true
  description = "RDS endpoint"
}
```

---

## 4. Terraform trong CI/CD

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

permissions:
  id-token: write    # Cho OIDC với AWS
  contents: read
  pull-requests: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      # OIDC authentication với AWS (không cần secrets!)
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActions-Terraform
          aws-region: ap-southeast-1
          
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
          
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform/environments/production
        
      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/production
        
      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform/environments/production
        
      # Plan trên PR
      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -no-color -input=false \
            -var-file=terraform.tfvars \
            -out=tfplan 2>&1 | tee plan_output.txt
        working-directory: terraform/environments/production
        
      # Post plan vào PR comment
      - name: Comment Plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/production/plan_output.txt', 'utf8');
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${plan}\n\`\`\``
            });
            
      # Apply chỉ khi push vào main (sau merge PR)
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/production

# ===== ATLANTIS (Alternative - GitOps cho Terraform) =====
# Atlantis tự động plan/apply Terraform từ PRs
# - PR opened → atlantis plan
# - Comment "atlantis apply" → apply
# - Merge PR → optional auto-apply
```

---

> **Tiếp theo: Phần 4** - Terraform với Azure, GCP & Multi-Cloud
