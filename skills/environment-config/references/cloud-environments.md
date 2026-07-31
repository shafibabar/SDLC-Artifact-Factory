# Environment Config — Multi-Cloud Environment Targets

Per-cloud provisioning detail for AWS, Azure, and GCP. Loaded when the
"Identical Provisioning Process" section of `environment-config/SKILL.md`
points here. This reference does **not** change what the skill teaches —
Environment Parity, Configuration as Code, the config/secret split, and the
"same automated OpenTofu + Helm process" rule all still hold. It only records
*which values change* when the same process targets a different cloud.

---

## The Cloud-Agnostic Rule

The platform is cloud-agnostic by design; a product deployment targets AWS,
Azure, or GCP. Every one of those targets is provisioned by the **same
automated OpenTofu + Helm process** — the local `kind` golden path, dev,
staging, and every tenant production stamp all run identical charts at
identical image digests regardless of cloud. There is no per-cloud pipeline,
no per-cloud chart fork, and no `if cloud == "aws"` in any service. The cloud
is not a code path; it is a set of values and OpenTofu provider configuration.

Only five things legitimately differ per cloud, and all five live in provider
config or values — never in service code:

| Concern | AWS | Azure | GCP |
|---|---|---|---|
| OpenTofu provider | `provider "aws"` (`region`) | `provider "azurerm"` (`features {}`) | `provider "google"` (`project`, `region`) |
| Remote-state backend | `backend "s3"` (bucket + lock) | `backend "azurerm"` (storage account container) | `backend "gcs"` (bucket) |
| Managed Kubernetes | EKS — `aws_eks_cluster` + `aws_eks_node_group` | AKS — `azurerm_kubernetes_cluster` | GKE — `google_container_cluster` + `google_container_node_pool` |
| Managed Postgres | RDS — `aws_db_instance` (`engine = "postgres"`) | `azurerm_postgresql_flexible_server` | `google_sql_database_instance` (`database_version = "POSTGRES_16"`) |
| Secret backend / KMS | AWS Secrets Manager + KMS | Azure Key Vault | Google Secret Manager + Cloud KMS |

Each row is a value substitution, not a rewrite. The Helm chart, the image
digest, the Flux `HelmRelease`, the promotion-invariance gate, and the
projected-volume secret pattern are byte-for-byte identical across all three.
Per-tenant **physical** isolation holds on every cloud: each tenant stamp gets
its own managed-Kubernetes cluster (or dedicated node pool), its own managed
Postgres instance, and its own secret backend scope.

---

## What Stays in Values, Not Code

The per-cloud differences reach the cluster the same way every other legitimate
difference does — through the environment repo's values, filed as **deploy-time**
configuration under the same taxonomy the body defines:

| Value key | Class | Per-cloud content |
|---|---|---|
| `postgres.host` | endpoint | RDS endpoint / Flexible Server FQDN / Cloud SQL private IP |
| `ingress.host` | endpoint | tenant host behind the cloud's managed load balancer |
| `redpanda.brokers` | endpoint | in-cluster brokers (self-hosted, cloud-agnostic) |
| cluster sizing tier | sizing | node-pool machine type per cloud SKU catalog |
| `tenant.id`, region label | identity | routing/label only, never behaviour |

A service reading `postgres.host` cannot tell whether it points at RDS, Flexible
Server, or Cloud SQL — and must not care. That indifference is what makes the
chart portable: the cloud is resolved at OpenTofu-apply time and handed to the
pod as an endpoint string, exactly like any other environment difference.

---

## Workload Identity — No Long-Lived Cloud Keys

Every cloud offers a keyless identity binding so a pod's Kubernetes
`ServiceAccount` authenticates to cloud APIs without a static credential in a
secret. Using it is mandatory — a long-lived cloud access key in a values file
or ConfigMap is the same class of violation as a DB password in Git.

| Cloud | Mechanism | Binding |
|---|---|---|
| AWS | IRSA (IAM Roles for Service Accounts) | cluster OIDC provider → IAM role trust policy → annotated `ServiceAccount` |
| Azure | Microsoft Entra Workload Identity | federated identity credential on a managed identity → annotated `ServiceAccount` |
| GCP | GKE Workload Identity | KSA ↔ GSA binding via `iam.workloadIdentityUser` |

The same annotated-`ServiceAccount` shape the projected-volume pattern already
mounts (`serviceAccountToken` source) is what these bindings key off — the
chart's `ServiceAccount` template is cloud-uniform; only the annotation values
differ, and those come from OpenTofu outputs into values.

---

## Cloud Secret Backends Relative to the Vault + SOPS Story

The repo's secret story does **not** get replaced per cloud. HashiCorp **Vault**
remains the in-cluster secret-delivery mechanism on every target: the Vault
Agent sidecar injects credentials into the projected volume exactly as the body
describes, so the config/secret split rule is identical AWS-to-Azure-to-GCP. The
cloud-native secret manager is *not* a second home for application secrets — it
plays two supporting roles only:

1. **Vault auto-unseal / KMS.** Vault's unseal key is protected by the cloud KMS
   — AWS KMS, Azure Key Vault, or Cloud KMS via the `awskms` / `azurekeyvault` /
   `gcpckms` seal stanza. The cloud provides the root of trust; Vault still owns
   secret issuance and rotation.
2. **SOPS encryption key for Git-committed bootstrap secrets.** The small set of
   bootstrap values that must live in Git (e.g. the Vault-unseal bootstrap, a
   Flux deploy key) are encrypted with **SOPS** using the cloud KMS key as the
   SOPS master key (`sops --kms` / `--azure-kv` / `--gcp-kms`). Ciphertext in
   Git, plaintext never — the "could this appear in a public repo without an
   incident?" test still returns *yes* because only the ciphertext is committed.

So the mapping is: **Vault = runtime secret delivery (cloud-uniform); cloud
secret manager / KMS = the encryption root that backs Vault auto-unseal and SOPS
at rest.** Google Secret Manager, AWS Secrets Manager, and Azure Key Vault may
also hold cloud-plane secrets the provider itself needs (e.g. a managed-Postgres
admin password OpenTofu generates), but application pods still receive their
secrets through the one Vault Agent path — never a direct cloud-SDK read that
would fork the secret-injection pattern per cloud.

---

## Provisioning Order — Identical Shape per Cloud

The OpenTofu root module runs the same phased apply on every cloud; only the
resource types in each phase differ (per the table above):

1. **Networking + state** — VPC/VNet, subnets, the remote-state backend bucket/container.
2. **Managed Kubernetes** — EKS / AKS / GKE cluster plus its node pool(s), one per tenant stamp for physical isolation.
3. **Managed Postgres** — one RDS / Flexible Server / Cloud SQL instance per tenant, private-networked to that tenant's cluster.
4. **Identity + secrets** — OIDC/workload-identity wiring, Vault auto-unseal KMS key, SOPS KMS key.
5. **Helm delivery** — Flux reconciles the same `HelmRelease` charts that dev and staging soaked.

Phases 1–4 are the only cloud-aware code, and they are OpenTofu provider
configuration, not service code. Phase 5 is cloud-blind. A new cloud target is
added by writing a provider variant of phases 1–4 — not by touching a single
chart, service binary, or the promotion-invariance gate.
