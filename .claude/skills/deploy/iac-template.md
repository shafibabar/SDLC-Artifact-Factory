# Skill: deploy/iac-template

## Purpose
Produce an OpenTofu (Infrastructure as Code) template for one service or infrastructure component — the complete, version-controlled definition of the cloud and Kubernetes resources required. Covers all three deployment targets: managed Kubernetes (cloud), k3s (hosted tenant), and kind (local dev).

## Inputs
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/design/platform/multi-tenancy-design.md`
- `artifacts/design/security/secrets-management.md`
- `sdlc-config.json` (deployment_targets, cloud_provider)
- **Argument required:** component name (e.g. `postgresql-cluster`, `kubernetes-namespace`, `redpanda`)

## Output
**File:** `artifacts/deploy/iac/{component}/` (directory with .tf files)
**Registers in manifest:** yes

## IaC Rules (enforced)
- All resources are declared in code — no console-created infrastructure.
- Remote state is configured (S3 or GCS with DynamoDB/GCS locking).
- Provider versions are pinned.
- No hardcoded credentials — IAM roles, workload identity, or secrets manager references.
- Sensitive outputs are marked `sensitive = true`.
- Resources are tagged with: product, environment, bounded-context, managed-by=opentofu.

## Artifact Template

```hcl
# artifacts/deploy/iac/postgresql-cluster/main.tf
# OpenTofu — PostgreSQL Cluster for {service-name}
# Target: AWS EKS (cloud) | k3s (hosted) | kind (local)
# Version: 1.0

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }

  backend "s3" {
    bucket         = "{product-codename}-tofu-state"
    key            = "{component}/{var.environment}/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "{product-codename}-tofu-state-lock"
    encrypt        = true
  }
}

# ── Variables ──────────────────────────────────────────────────────────────

variable "environment" {
  type        = string
  description = "Deployment environment: dev | staging | production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production"
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "tenant_id" {
  type        = string
  description = "Tenant identifier — one PostgreSQL cluster per tenant"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"  # Per-tenant: right-sized; scale per tenant SLA
}

# ── PostgreSQL (AWS RDS with pgx-compatible pg_tde for encryption at rest) ──

resource "aws_db_subnet_group" "tenant" {
  name       = "{product-codename}-${var.tenant_id}-${var.environment}"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Product         = "{product-codename}"
    Environment     = var.environment
    TenantID        = var.tenant_id
    BoundedContext  = "platform"
    ManagedBy       = "opentofu"
  }
}

resource "aws_db_instance" "tenant" {
  identifier              = "{product-codename}-${var.tenant_id}-${var.environment}"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  max_allocated_storage   = 200  # Auto-scaling storage
  db_subnet_group_name    = aws_db_subnet_group.tenant.name
  vpc_security_group_ids  = [aws_security_group.postgres.id]
  
  # Encryption at rest
  storage_encrypted = true
  kms_key_id        = aws_kms_key.tenant_db.arn
  
  # Credentials via Secrets Manager (not inline)
  manage_master_user_password = true  # AWS rotates and stores in Secrets Manager
  
  # Backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  # Deletion protection
  deletion_protection      = var.environment == "production"
  skip_final_snapshot      = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "{product-codename}-${var.tenant_id}-final" : null
  
  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled = true
  
  tags = {
    Product        = "{product-codename}"
    Environment    = var.environment
    TenantID       = var.tenant_id
    ManagedBy      = "opentofu"
    DataClassification = "C3"
  }
}

# ── KMS Key for tenant DB encryption ──

resource "aws_kms_key" "tenant_db" {
  description             = "{product-codename} tenant ${var.tenant_id} DB key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Product    = "{product-codename}"
    TenantID   = var.tenant_id
    ManagedBy  = "opentofu"
  }
}

# ── Outputs ──

output "db_endpoint" {
  value     = aws_db_instance.tenant.endpoint
  sensitive = true
  description = "PostgreSQL endpoint — stored in Vault, not exposed directly"
}

output "db_secret_arn" {
  value     = aws_db_instance.tenant.master_user_secret[0].secret_arn
  sensitive = true
  description = "Secrets Manager ARN for DB credentials — referenced by ESO"
}
```

**Variables file (`variables.tfvars.example`):**
```hcl
# Copy to variables.tfvars; DO NOT commit variables.tfvars to git
# Secrets are read from Vault/AWS SM, not set here
environment = "staging"
aws_region  = "eu-west-1"
tenant_id   = "acme-corp"
```

## Quality Checks
- [ ] Provider versions are pinned (`~>` constraint, not `>=`)
- [ ] Remote state backend is configured with locking
- [ ] No hardcoded credentials — `manage_master_user_password = true` or equivalent
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] All resources tagged with product, environment, tenant_id, managed-by
- [ ] Deletion protection enabled for production
- [ ] KMS key rotation enabled
- [ ] Example variables file excludes secrets
