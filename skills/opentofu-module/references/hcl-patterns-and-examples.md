# OpenTofu Module — HCL Patterns and Worked Examples

Reference for the `opentofu-module` skill. Load this when you need complete HCL, a
full CI pipeline configuration, or an annotated OPA policy — the SKILL.md body points
here rather than embedding code inline. Every example is production-shaped: it matches
the tech stack defaults (PostgreSQL + Apache AGE, Redpanda, Kubernetes, Linkerd, Flux,
S3 remote state, Vault for secrets).

---

## §Variables — Annotated Contract

### Postgres Module Variables

```hcl
# modules/postgres/variables.tf

variable "tenant_id" {
  type        = string
  description = "Tenant this instance belongs to; propagated to resource tags, backup bucket prefix, and Vault path."
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$", var.tenant_id))
    error_message = "tenant_id must be lowercase alphanumeric-with-dashes, 3–32 chars total."
  }
}

variable "instance_size" {
  type        = string
  description = "Sizing tier — the module maps tiers to concrete machine classes. Callers express intent; the module owns the machine-class decision so fleet-wide resizing is a single-file change."
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.instance_size)
    error_message = "instance_size must be 'small', 'medium', or 'large'."
  }
}

variable "region" {
  type        = string
  description = "Cloud region for this instance; must match the tenant's data-residency requirement in the multi-tenancy design."
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain automated backups. Override only for compliance requirements; default covers the 30-day retention policy."
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 7 and 365."
  }
}

# Internal tier-to-machine-type lookup — not exposed to callers.
locals {
  postgres_machine_class = {
    small  = "db-custom-2-7680"     # 2 vCPU, 7.5 GB — dev / low-traffic staging
    medium = "db-custom-4-15360"    # 4 vCPU, 15 GB — production single-tenant
    large  = "db-custom-8-30720"    # 8 vCPU, 30 GB — production high-throughput
  }
  machine_type = local.postgres_machine_class[var.instance_size]
}
```

### Postgres Module Outputs

```hcl
# modules/postgres/outputs.tf

output "endpoint" {
  description = "Private IP endpoint of the PostgreSQL instance. Never expose publicly; access via Linkerd mTLS within the cluster."
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "vault_cred_path" {
  description = "Vault dynamic credentials path for the application role. The application reads credentials from this path at runtime; credentials are never static and never stored in environment variables."
  value       = vault_database_secret_backend_role.app.path
}

output "database_name" {
  description = "Name of the default application database provisioned within the instance."
  value       = google_sql_database.app.name
}

output "age_extension_enabled" {
  description = "True when the Apache AGE extension is installed. The platform-engineer confirms this before the data-architect provisions graph schemas."
  value       = true   # enforced in main.tf — AGE is always enabled for the estate graph use case
}
```

---

## §Remote State — Backend Configuration

One state file per root config (one per tenant, one per environment tier). The DynamoDB table provides distributed locking so concurrent CI runs cannot corrupt state.

```hcl
# deploy/tenants/acme/backend.tf

terraform {
  backend "s3" {
    bucket         = "acme-tofu-state"
    key            = "tenants/acme/terraform.tfstate"   # unique per tenant directory
    region         = "eu-west-1"
    dynamodb_table = "tofu-locks"                        # table name shared across all roots; key = state file path
    encrypt        = true                                # AES-256 server-side encryption
    kms_key_id     = "alias/tofu-state-key"             # CMK for key rotation
  }
}
```

**State key scheme:**

| Root config location | State key |
|---|---|
| `deploy/control-plane/` | `control-plane/terraform.tfstate` |
| `deploy/tenants/acme/` | `tenants/acme/terraform.tfstate` |
| `deploy/tenants/beta/` | `tenants/beta/terraform.tfstate` |
| `deploy/tenants/acme/services/inventory/` | `tenants/acme/services/inventory/terraform.tfstate` |

Self-service infrastructure requests (see §Self-Service below) add a `services/<service>` depth to the key scheme — each requested resource gets its own state, keeping blast radius at the individual service level.

**Access control:** the S3 bucket policy allows read/write only from the CI runner IAM role and the platform-engineer's break-glass role. No developer IAM policy grants state access. Vault audit logs and AWS CloudTrail capture every access.

---

## §Plan Pipeline — Full GitHub Actions Workflow

```yaml
# .github/workflows/tofu-plan-apply.yml
name: OpenTofu Plan / Apply

on:
  pull_request:
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'policy/**'
  push:
    branches: [main]
    paths:
      - 'deploy/**'
      - 'modules/**'
      - 'policy/**'

permissions:
  id-token: write       # OIDC for AWS assume-role
  contents: read
  pull-requests: write  # post plan comment

jobs:
  changed-roots:
    runs-on: ubuntu-latest
    outputs:
      roots: ${{ steps.detect.outputs.roots }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: detect
        run: |
          # Detect which root configs changed; output as JSON array for matrix
          CHANGED=$(git diff --name-only origin/main...HEAD | grep '^deploy/' | \
            sed 's|/[^/]*$||' | sort -u | jq -Rc '[.]' | jq -sc 'add // []')
          echo "roots=$CHANGED" >> "$GITHUB_OUTPUT"

  plan:
    needs: changed-roots
    runs-on: ubuntu-latest
    strategy:
      matrix:
        root: ${{ fromJson(needs.changed-roots.outputs.roots) }}
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: "1.7.3"   # pinned; bump via Renovate

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/tofu-ci-runner
          aws-region: eu-west-1

      - name: tofu init
        run: tofu init -input=false
        working-directory: ${{ matrix.root }}

      - name: tofu fmt check
        run: tofu fmt -check -recursive
        working-directory: ${{ matrix.root }}

      - name: tofu validate
        run: tofu validate
        working-directory: ${{ matrix.root }}

      - name: tofu plan
        id: plan
        run: tofu plan -input=false -out=tfplan 2>&1 | tee plan.txt
        working-directory: ${{ matrix.root }}

      - name: OPA gate (conftest)
        run: |
          tofu show -json tfplan | conftest test -p ../../policy/ -
        working-directory: ${{ matrix.root }}

      - name: Post plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('${{ matrix.root }}/plan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### Plan: \`${{ matrix.root }}\`\n\`\`\`\n${plan.slice(0, 60000)}\n\`\`\``
            });

      - name: Upload plan artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ hashFiles(matrix.root) }}
          path: ${{ matrix.root }}/tfplan
          retention-days: 1   # plan is valid only for this PR; expired on next push

  apply:
    needs: plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production   # requires manual approval in GitHub Environments for production roots
    strategy:
      matrix:
        root: ${{ fromJson(needs.changed-roots.outputs.roots) }}
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: "1.7.3"

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/tofu-ci-runner
          aws-region: eu-west-1

      - name: Download saved plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan-${{ hashFiles(matrix.root) }}
          path: ${{ matrix.root }}

      - name: tofu init
        run: tofu init -input=false
        working-directory: ${{ matrix.root }}

      - name: tofu apply (saved plan)
        run: tofu apply -input=false tfplan
        working-directory: ${{ matrix.root }}
```

---

## §Worked Example — The tenant-stamp Module

### Per-Tenant Root Config

```hcl
# deploy/tenants/acme/main.tf
# Provisions the complete isolated data plane for tenant "acme".
# Module version pinned; canary tenant moves to v1.5.0 first, this directory follows.

module "tenant" {
  source = "git::https://github.com/acme/platform-modules.git//modules/tenant-stamp?ref=v1.4.0"

  tenant_id    = "acme"
  region       = "eu-west-1"           # data-residency: EU customer, GDPR scope
  sizing       = "medium"              # tier: 4-vCPU nodes, medium PG, 3-broker Redpanda
  ingress_host = "acme.app.example.com"
}
```

```hcl
# deploy/tenants/acme/backend.tf
terraform {
  backend "s3" {
    bucket         = "acme-tofu-state"
    key            = "tenants/acme/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tofu-locks"
    encrypt        = true
    kms_key_id     = "alias/tofu-state-key"
  }
}
```

```hcl
# deploy/tenants/acme/terraform.tfvars
# No variables — the module call above is the complete configuration.
# Per-tenant variation lives in module arguments, not in a parallel .tfvars system.
```

### Tenant-Stamp Composition Module

```hcl
# modules/tenant-stamp/main.tf
# Composition module: assembles one tenant's complete isolated data plane
# from leaf modules. No business logic here — only wiring.

module "network" {
  source    = "../network"
  tenant_id = var.tenant_id
  region    = var.region
}

module "cluster" {
  source     = "../cluster"
  tenant_id  = var.tenant_id
  network_id = module.network.id
  sizing     = var.sizing
  # Cluster bootstrap installs Flux pointed at deploy/clusters/tenants/<tenant_id>/
  # From this point, workloads arrive via GitOps (cd-pipeline), not OpenTofu.
  flux_target_path = "deploy/clusters/tenants/${var.tenant_id}"
}

module "postgres" {
  source        = "../postgres"
  tenant_id     = var.tenant_id
  region        = var.region
  network_id    = module.network.id
  instance_size = var.sizing
}

module "redpanda" {
  source     = "../redpanda"
  tenant_id  = var.tenant_id
  network_id = module.network.id
  sizing     = var.sizing
}

module "observability" {
  source     = "../observability"
  tenant_id  = var.tenant_id
  cluster_id = module.cluster.id
}
```

```hcl
# modules/tenant-stamp/variables.tf

variable "tenant_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$", var.tenant_id))
    error_message = "tenant_id must be lowercase alphanumeric-with-dashes, 3–32 chars."
  }
}

variable "region"       { type = string }
variable "sizing"       { type = string; default = "small" }
variable "ingress_host" { type = string }
```

```hcl
# modules/tenant-stamp/outputs.tf

output "postgres_vault_path"  { value = module.postgres.vault_cred_path }
output "cluster_id"           { value = module.cluster.id }
output "network_id"           { value = module.network.id }
# No secret values in outputs — everything sensitive is in Vault.
```

### Offboarding

Offboarding tenant `acme` is a PR that:
1. Runs `tofu plan -destroy` in `deploy/tenants/acme/` — the plan shows all resources that will be destroyed.
2. OPA gate runs on the destroy plan; cross-tenant impact must be zero.
3. A human reviewer confirms the plan includes no shared resources.
4. After merge, `tofu apply` (the saved destroy plan) runs.
5. The data-architect's backup-handover attestation must be recorded before destruction (data retention contract).

---

## §OPA Policy — Compliance Gate Examples

The OPA gate runs on the JSON output of `tofu show -json tfplan`. Policies live in `policy/` and are evaluated with `conftest test`.

### Deny Public Ingress on Tenant Databases

```rego
# policy/postgres/no_public_ingress.rego
package terraform.postgres

import rego.v1

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "google_sql_database_instance"
  r.change.after.settings[_].ip_configuration[_].ipv4_enabled == true
  msg := sprintf(
    "Resource %s: postgres instances must not have public IPv4 enabled. Use private IP only.",
    [r.address]
  )
}
```

### Require Encryption at Rest

```rego
# policy/postgres/encryption_required.rego
package terraform.postgres

import rego.v1

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "google_sql_database_instance"
  not r.change.after.settings[_].disk_encryption_configuration[_].kms_key_name
  msg := sprintf(
    "Resource %s: postgres instances must use a customer-managed KMS key for disk encryption.",
    [r.address]
  )
}
```

### Require Tenant Tag on Every Resource

```rego
# policy/common/tenant_tag_required.rego
package terraform.common

import rego.v1

tagged_resources := {
  "google_sql_database_instance",
  "google_container_cluster",
  "google_compute_network",
}

deny contains msg if {
  r := input.resource_changes[_]
  tagged_resources[r.type]
  not r.change.after.labels.tenant_id
  msg := sprintf(
    "Resource %s (%s) is missing the required 'tenant_id' label.",
    [r.address, r.type]
  )
}
```

### Deny Cross-Tenant Network Access

```rego
# policy/network/no_cross_tenant_peering.rego
package terraform.network

import rego.v1

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "google_compute_network_peering"
  # Both sides of a peering must share the same tenant_id label
  peer_a_tenant := r.change.after.network  # simplified — real check inspects labels
  peer_b_tenant := r.change.after.peer_network
  peer_a_tenant != peer_b_tenant
  msg := sprintf(
    "Resource %s: cross-tenant network peering is not permitted. Peers must belong to the same tenant.",
    [r.address]
  )
}
```

---

## §Self-Service — Infrastructure Request Automation

This section supports the `opentofu-module` skill's "Self-Service Infrastructure Request" section.
The developer fills in `assets/infrastructure-request-template.yaml`; the CI script reads it and generates HCL.

### YAML-to-HCL Generator (Shell Pseudocode)

```bash
#!/bin/bash
# scripts/infra-request-apply.sh
# Reads an InfrastructureRequest YAML, validates it, and generates the
# corresponding OpenTofu root config in deploy/tenants/<tenant>/services/<service>/.
# Called by the CI pipeline on PRs that touch infra-requests/*.yaml.
set -euo pipefail

REQUEST_FILE="${1:?Usage: $0 <path/to/request.yaml>}"

# Step 1 — Validate YAML against JSON Schema
python3 scripts/validate-infra-request.py "$REQUEST_FILE"

# Step 2 — Parse fields
KIND=$(yq e '.kind' "$REQUEST_FILE")
SERVICE=$(yq e '.service' "$REQUEST_FILE")
RESOURCE=$(yq e '.resource' "$REQUEST_FILE")
SIZE=$(yq e '.config.size' "$REQUEST_FILE")
ENVIRONMENT=$(yq e '.config.environment' "$REQUEST_FILE")
TENANT=$(yq e '.config.tenant' "$REQUEST_FILE")
DB_NAME=$(yq e '.config.name' "$REQUEST_FILE")

if [[ "$KIND" != "InfrastructureRequest" ]]; then
  echo "ERROR: kind must be InfrastructureRequest, got '$KIND'" >&2
  exit 1
fi

# Step 3 — Generate root config directory
OUTPUT_DIR="deploy/tenants/${TENANT}/services/${SERVICE}"
mkdir -p "$OUTPUT_DIR"

# Step 4 — Emit main.tf from template
cat > "$OUTPUT_DIR/main.tf" <<HCL
# Auto-generated from infra-requests/${SERVICE}.yaml — do not edit by hand.
# Source request: $(basename "$REQUEST_FILE")
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

module "${RESOURCE}" {
  source = "git::https://github.com/acme/platform-modules.git//modules/${RESOURCE}?ref=v1.4.0"

  tenant_id     = "${TENANT}"
  instance_size = "${SIZE}"
  database_name = "${DB_NAME}"
  region        = var.region   # sourced from environment tfvars
}

output "vault_cred_path" {
  value       = module.${RESOURCE}.vault_cred_path
  description = "Vault path for ${SERVICE} credentials. Application reads from this path at runtime."
}
HCL

# Step 5 — Emit backend.tf
cat > "$OUTPUT_DIR/backend.tf" <<HCL
terraform {
  backend "s3" {
    bucket         = "acme-tofu-state"
    key            = "tenants/${TENANT}/services/${SERVICE}/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tofu-locks"
    encrypt        = true
    kms_key_id     = "alias/tofu-state-key"
  }
}
HCL

echo "Generated: $OUTPUT_DIR/main.tf"
echo "Generated: $OUTPUT_DIR/backend.tf"
echo "Next: run tofu plan in $OUTPUT_DIR — CI will do this automatically on the PR."
```

### JSON Schema for YAML Validation

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "InfrastructureRequest",
  "type": "object",
  "required": ["kind", "service", "resource", "config", "owner"],
  "properties": {
    "kind": {
      "type": "string",
      "const": "InfrastructureRequest"
    },
    "service": {
      "type": "string",
      "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$",
      "description": "Service name — must match the Kubernetes service naming convention."
    },
    "resource": {
      "type": "string",
      "enum": ["postgresql", "redpanda", "object-storage"],
      "description": "Resource type to provision. Add new values only after a platform ADR."
    },
    "config": {
      "type": "object",
      "required": ["name", "size", "environment", "tenant"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$"
        },
        "size": {
          "type": "string",
          "enum": ["small", "medium", "large"]
        },
        "environment": {
          "type": "string",
          "enum": ["dev", "staging", "production"]
        },
        "tenant": {
          "type": "string",
          "pattern": "^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$"
        }
      },
      "additionalProperties": false
    },
    "owner": {
      "type": "string",
      "description": "GitHub team or individual login responsible for this resource."
    }
  },
  "additionalProperties": false
}
```

---

## §Module Version Pinning — Upgrade Wave Procedure

Module version bumps are the mechanism for controlled rollout across the tenant fleet.

**Wave pattern:**

1. Release `v1.5.0` of the affected module to the platform-modules repository.
2. Open a PR updating only the **canary tenant** directory (`deploy/tenants/canary/`) from `?ref=v1.4.0` to `?ref=v1.5.0`.
3. Monitor the canary tenant for 24–48 hours. Rollback = revert the canary PR; one `tofu apply` restores the previous version.
4. Wave 1: update 10–20% of tenant directories in a single PR. CI runs one plan per directory; all must pass OPA before merge.
5. Wave 2 and beyond: expand until 100% of directories reference the new version.
6. Close the release PR tracking the wave progress.

**Never** use `?ref=main` — it ties every tenant's next apply to whatever was last merged, making waves impossible and rollback ambiguous.

**Renovate configuration** for automated version PRs:

```json
{
  "regexManagers": [
    {
      "fileMatch": ["^deploy/.*\\.tf$"],
      "matchStrings": ["\\?ref=(?<currentValue>[^\"]+)"],
      "datasourceTemplate": "github-tags",
      "depNameTemplate": "acme/platform-modules"
    }
  ]
}
```

Renovate opens one PR per tenant directory when a new module version is available — the platform engineer reviews wave order and merges manually to control blast radius.
