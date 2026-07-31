# OpenTofu Module — Multi-Cloud Provider Reference

Reference for the `opentofu-module` skill. Load this when a product deployment targets a
specific cloud (AWS, Azure, or GCP) and you need the provider block, the remote-state
backend, the managed-Kubernetes and managed-Postgres resource shapes, and the
credential/workload-identity handling for that cloud.

The platform is **cloud-agnostic by design**: the leaf-module interface (its `variables.tf`
and `outputs.tf`) stays identical across clouds, and only the *implementation* — the
provider and its resources — is swapped. The default local environment is `kind`; product
deployments target one of the three managed clouds below. Everything here is stable,
well-established public IaC (OpenTofu/Terraform provider blocks and the long-standing
resource/argument names) — do not substitute newer or invented argument names.

---

## §Agnostic Module vs Cloud-Specific Module — The Boundary

The rule is **keep the interface stable, swap the implementation**:

- The **interface** is a module's public contract — the variable set (`tenant_id`, `region`,
  `instance_size`, `network_id`, …) and the output set (`endpoint`, `vault_cred_path`,
  `database_name`). Every cloud-specific implementation of a concern honours the *same*
  contract, so `tenant-stamp` and self-service generation never change when the target cloud
  changes.
- The **implementation** is the provider block plus the cloud's concrete resources. A
  `modules/postgres/gcp/`, `modules/postgres/aws/`, `modules/postgres/azure/` each satisfy the
  identical `variables.tf`/`outputs.tf` contract but instantiate Cloud SQL, RDS, or Flexible
  Server respectively.

```hcl
# The composition selects a cloud implementation; the contract is unchanged.
module "postgres" {
  source        = "../postgres/${var.cloud}"   # gcp | aws | azure
  tenant_id     = var.tenant_id
  region        = var.region
  instance_size = var.sizing
}
```

A caller never learns which cloud it is on from the module interface. If a variable or output
has to change to move a module between clouds, the boundary has leaked — push the cloud
detail down into the implementation and keep the contract stable. Cloud-specific values
(machine classes, SKU tiers) live in the module's internal `locals`, exactly as the
tier-to-machine-type lookup already does.

---

## §Provider Blocks (per cloud)

```hcl
# GCP
provider "google" {
  project = var.project_id
  region  = var.region
}

# AWS
provider "aws" {
  region = var.region
}

# Azure
provider "azurerm" {
  features {}
}
```

Providers are pinned in each module's `versions.tf` under `required_providers` (`hashicorp/google`,
`hashicorp/aws`, `hashicorp/azurerm`) with a version constraint — never floating — mirroring the
module-ref pinning discipline in the skill body.

---

## §Remote-State Backend (per cloud)

One state file per root config on every cloud; only the backend block changes.

```hcl
# GCP — GCS bucket. GCS provides native state locking, so no separate lock table.
terraform {
  backend "gcs" {
    bucket = "acme-tofu-state"
    prefix = "tenants/acme"          # object path within the bucket
  }
}

# AWS — S3 for storage + a DynamoDB table for the distributed lock.
terraform {
  backend "s3" {
    bucket         = "acme-tofu-state"
    key            = "tenants/acme/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tofu-locks"
    encrypt        = true
  }
}

# Azure — a blob in a storage-account container; the lock is a blob lease.
terraform {
  backend "azurerm" {
    resource_group_name  = "tofu-state-rg"
    storage_account_name = "acmetofustate"
    container_name       = "tfstate"
    key                  = "tenants/acme/terraform.tfstate"
  }
}
```

| Cloud | Storage | Locking |
|---|---|---|
| GCP | GCS bucket (`gcs` backend) | Native object locking — no extra resource |
| AWS | S3 bucket (`s3` backend) | DynamoDB table (`dynamodb_table`) |
| Azure | Storage-account blob (`azurerm` backend) | Blob lease — native, no extra resource |

State is sensitive on every cloud: encrypt at rest, restrict the bucket/container to the CI
role and the break-glass role, never commit it to Git.

---

## §Managed Kubernetes (per cloud)

Each `modules/cluster/<cloud>` provisions a managed control plane plus a node pool and honours
the same `cluster_id`/`kubeconfig`-shaped outputs.

| Cloud | Managed service | Cluster resource | Node pool resource |
|---|---|---|---|
| GCP | GKE | `google_container_cluster` | `google_container_node_pool` |
| AWS | EKS | `aws_eks_cluster` | `aws_eks_node_group` |
| Azure | AKS | `azurerm_kubernetes_cluster` | `azurerm_kubernetes_cluster_node_pool` |

After the cluster exists, Linkerd + Flux bootstrap is identical across clouds (the GitOps path,
`cd-pipeline`, delivers workloads — OpenTofu only provisions the platform).

---

## §Managed PostgreSQL (per cloud)

Each `modules/postgres/<cloud>` exposes the same `endpoint` / `vault_cred_path` / `database_name`
outputs and the same `instance_size` tier variable.

| Cloud | Managed service | Primary resource |
|---|---|---|
| GCP | Cloud SQL for PostgreSQL | `google_sql_database_instance` (+ `google_sql_database`) |
| AWS | RDS for PostgreSQL (or Aurora PostgreSQL) | `aws_db_instance` (or `aws_rds_cluster`) |
| Azure | Azure Database for PostgreSQL — Flexible Server | `azurerm_postgresql_flexible_server` |

Private networking only (no public endpoint), encryption at rest with a customer-managed key,
and Apache AGE where the estate-graph use case requires it — the OPA gate enforces these
regardless of cloud.

---

## §Provider Credentials & Workload Identity

No long-lived cloud keys anywhere — CI authenticates via short-lived, federated identity, and
pods obtain cloud permissions through the cluster's workload-identity mechanism rather than
mounted static credentials.

| Cloud | CI authentication | Pod → cloud identity |
|---|---|---|
| GCP | Workload Identity Federation (GitHub OIDC → service account) | GKE Workload Identity (KSA ↔ GCP service account) |
| AWS | OIDC `AssumeRoleWithWebIdentity` (`id-token: write` in the workflow) | IRSA — IAM Roles for Service Accounts via the cluster OIDC provider |
| Azure | Workload Identity Federation (GitHub OIDC → app registration) | Microsoft Entra Workload Identity (federated managed identity) |

The AWS OIDC assume-role step already appears in the plan/apply pipeline
(`hcl-patterns-and-examples.md` §Plan Pipeline); the GCP and Azure equivalents replace only that
one credential-configuration step. Dynamic application credentials still land in Vault on every
cloud; module outputs carry Vault *paths*, never secret values.
