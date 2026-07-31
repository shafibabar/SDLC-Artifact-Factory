---
name: secrets-management
description: >
  Teaches how to design a secrets management strategy — covering the types of
  secrets that must be managed, the never-do-this anti-patterns (secrets in code,
  env vars, config files), runtime injection patterns for Kubernetes, HashiCorp
  Vault as the primary secrets store, secret rotation policy, and Go patterns for
  consuming secrets at runtime without ever storing them. Used by the
  security-architect agent during Design and the security-engineer agent during
  Implement.
version: 1.2.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, secrets-management, vault, kubernetes, rotation, go, gitops, sops, sealed-secrets]
related: [gitops-practice, kubernetes-manifest, cd-pipeline]
---

# Secrets Management

## Purpose

A secret is any value that provides access to a protected resource: database passwords, API keys, JWT signing keys, TLS certificates, service account credentials, encryption keys. If a secret is compromised, the protected resource is compromised.

Secrets management defines where secrets live, who can access them, how they get into running applications, and how they are rotated. The goal is zero secrets at rest in any place a developer or engineer can read them — source code, configuration files, Docker images, environment variables, or CI/CD logs.

---

## The Non-Negotiable Rules

These are not best practices — they are absolute requirements. Violations are security defects that must be remediated before deployment:

1. **No secrets in source code.** Ever. Including test secrets, example secrets, and "temporary" secrets. Use pre-commit hooks to detect and block secret patterns.
2. **No secrets in Docker images.** Images are distributed and may be stored in registries that are not access-controlled to the same level as the secrets themselves.
3. **No secrets in environment variables set at build time.** Build-time env vars are logged in CI, stored in build artefacts, and visible to anyone with CI access.
4. **No secrets in Kubernetes ConfigMaps.** ConfigMaps are not encrypted at rest by default and are readable by anyone with `kubectl get configmap` access.
5. **No secrets in CI/CD logs.** Secrets injected into CI pipelines for testing must be masked in logs and must not be the same secrets used in production.

---

## Secret Types and Storage

| Secret type | Storage | Rotation trigger |
|---|---|---|
| Database passwords | Vault (dynamic secrets — generated per request) | Auto-rotated by Vault after each lease |
| JWT signing keys (private) | Vault (PKI secrets engine) | Every 90 days |
| TLS certificates (Linkerd mTLS) | Linkerd control plane (auto-rotated) | Every 24 hours (Linkerd default) |
| External API credentials (Google Drive, S3) | Vault (KV v2) | Every 90 days or on suspected compromise |
| Encryption keys (data at rest) | Cloud KMS or Vault Transit secrets engine | Annually |
| Service account tokens (Kubernetes) | Kubernetes-managed (projected ServiceAccount tokens) | Every hour (Kubernetes default) |

---

## Two-Layer Secrets Architecture

Secrets flow through two complementary, non-competing layers. Each solves a distinct problem:

| Layer | Problem solved | Mechanism | When active |
|---|---|---|---|
| **Bootstrap / GitOps layer** | Secrets cannot be committed to Git as plaintext; the environment repo must contain everything needed to bootstrap a namespace, including initial Kubernetes Secrets | SOPS or Sealed Secrets encrypts Secret manifests; only the authorised controller can decrypt | Cluster bootstrap, namespace provisioning, Vault Agent setup |
| **Runtime layer** | Running pods need short-lived, auto-rotating credentials; injection must be zero-touch after bootstrap | Vault Agent sidecar fetches dynamic credentials from Vault and writes them to an in-memory volume | Every pod start and on credential TTL refresh |

The runtime layer depends on the bootstrap layer: Vault Agent cannot contact Vault without its own Vault address and initial token, both of which arrive via the bootstrap layer.

---

## GitOps Bootstrap Layer: SOPS vs Sealed Secrets

The environment repository must contain encrypted Secret manifests. Two tools provide this. Criteria for choosing:

| Criterion | SOPS + age | Sealed Secrets |
|---|---|---|
| Decryption dependency | External key provider (age private key, AWS KMS, GCP KMS) — independent of any cluster | In-cluster controller's private key — tied to one specific cluster |
| Cluster replaceable? | Yes — re-bootstrap by importing the same age key | No — replacing the cluster requires re-sealing every secret against the new controller's public key |
| Flux native support | Yes — `kustomize-controller` decrypts SOPS-encrypted fields natively | Via ESO or manual Helm hook; not natively built into Flux reconciliation |
| Migration / multi-cluster | Straightforward — same SOPS key works across all clusters sharing that key | Complex — each cluster has its own controller key; cross-cluster secrets must be re-encrypted |
| Per-tenant isolation | Separate age key per tenant — tenant cannot decrypt another tenant's secrets | Separate controller per cluster — isolation is cluster-scoped |

**Decision for this repo:** Use SOPS + age for all per-tenant cluster stamps. Per-tenant clusters are replaceable stamps; tying decryption to cluster identity creates a key migration problem on cluster recreation. Vault Agent remains the runtime layer.

**How SOPS bootstrap works:**

1. Generate an age key pair: `age-keygen -o age.key`
2. Store the age private key as a Kubernetes Secret in the cluster (the one manual step; done out-of-band during cluster bootstrap)
3. Configure Flux `kustomize-controller` to use the age key for SOPS decryption
4. Encrypt Secret manifests with `sops --encrypt --age <public-key> secret.yaml > secret.enc.yaml`
5. Commit `secret.enc.yaml` to the environment repo; Flux decrypts at apply time

**Sealed Secrets** is the alternative when the cluster is long-lived and non-replaceable: `kubeseal` encrypts a Kubernetes Secret against the in-cluster controller's public key, producing a `SealedSecret` CRD that only that cluster's controller can decrypt. The encrypted manifest is safe to commit; the risk is that cluster recreation or migration requires re-sealing every secret.

Full SOPS configuration examples, Flux `kustomize-controller` SOPS setup, and a Sealed Secrets workflow are in `references/gitops-secrets-patterns.md`.

---

## Runtime Layer: HashiCorp Vault and Vault Agent

Vault is the primary secrets store for all non-certificate runtime secrets. It provides:
- **KV v2 secrets engine:** Versioned key-value storage for static secrets (API keys, config values)
- **Database secrets engine:** Dynamic database credentials generated on demand, auto-revoked after configurable TTL
- **PKI secrets engine:** Certificate authority for issuing short-lived TLS certificates
- **Transit secrets engine:** Encryption-as-a-service — services send plaintext, Vault returns ciphertext
- **Audit log:** All secret accesses logged with identity and timestamp

Each service has its own Vault policy following the Principle of Least Privilege. Services cannot read each other's secrets.

**Vault Agent Sidecar** authenticates to Vault using the pod's Kubernetes ServiceAccount, fetches secrets, writes them to a shared in-memory volume, and refreshes them before TTL expires. The application reads the secret from the mounted file — never from an environment variable.

**External Secrets Operator** syncs secrets from Vault into Kubernetes Secrets (encrypted at rest in etcd). Use for static secrets (API keys) that change infrequently; use Vault Agent Sidecar for dynamic secrets (database credentials).

Full Vault policy HCL, Vault Agent sidecar YAML annotations, and ESO CRD examples are in `references/gitops-secrets-patterns.md`.

---

## Go Pattern: Reading Secrets at Runtime

Rules for Go secret consumption:
- Never assign a secret to a package-level variable — it lives for the process lifetime and defeats rotation
- Never log a secret, even at debug level — and never log the connection URL, which embeds the password
- Read secrets from files (Vault Agent output), not environment variables
- Wrap secrets in a redaction type that covers `String()`, `GoString()`, `slog.LogValue()`, and `MarshalJSON()` — `fmt.Stringer` alone does not cover `%#v`, structured log fields, or JSON marshalling
- `Reveal()` is the single, greppable escape hatch for the moment of use

Full `Secret` type implementation and `loadDatabaseURL` pattern are in `references/gitops-secrets-patterns.md`.

---

## Secret Rotation

| Secret | Rotation mechanism | Zero-downtime |
|---|---|---|
| Database passwords | Vault dynamic secrets — each connection gets unique credentials with TTL | Yes |
| JWT signing keys | Vault PKI; `kid` header enables graceful rotation | Yes |
| External API keys | Vault KV v2 versioning; rollback to version N-1 available | Yes |
| TLS certificates | Vault PKI auto-rotation or Linkerd auto-rotation | Yes |
| SOPS age key | Re-encrypt all secrets with new age key; rotate the in-cluster Secret holding the private key | Yes, if re-encryption completes before old key is removed |

**Rotation test:** Every rotation mechanism must be validated in a non-production environment. Rotation that causes downtime has failed its design goal.

---

## Secret Scanning in CI

Run TruffleHog on every commit with `--only-verified` to avoid false positives. If a secret is detected:
1. The CI pipeline fails immediately
2. The secret is rotated immediately (treat as compromised)
3. The commit history is cleaned with `git filter-repo`
4. The incident is logged in the security incident register

Full CI job YAML is in `references/gitops-secrets-patterns.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No secrets in source | Secret scanning CI job passes; no secrets in git history | Any secret found in source code or git history |
| Runtime injection only | All runtime secrets injected via Vault Agent or ESO at pod startup | Secrets in environment variables or ConfigMaps |
| Bootstrap layer present | GitOps environment repo contains only SOPS-encrypted Secret manifests; no plaintext Secrets committed | Plaintext Kubernetes Secrets in the environment repo |
| Least-privilege Vault policies | Each service policy follows Principle of Least Privilege; cannot read other services' secrets | Shared policies; wildcard path access |
| Rotation documented | Every secret type has a rotation period and mechanism | Secrets with no rotation policy |
| Zero-downtime rotation | Rotation mechanism validated in non-production | Rotation not tested; unknown downtime impact |
| Secret redaction in logs | All logging of structs containing secrets redacts the secret field | Secret values appearing in application logs |

---

## Anti-Patterns

- **"Temporary" secrets in code.** A hardcoded test password committed "just to unblock CI" is a real credential in git history forever.
- **Secrets in environment variables.** Env vars leak through `/proc/<pid>/environ`, crash dumps, child processes, debug endpoints, and `kubectl describe pod`.
- **Plaintext Secrets in the environment repo.** A GitOps repo with plaintext Kubernetes Secret manifests is a secret store with no access control — anyone who can read the repo can read all credentials.
- **Sealed Secrets on replaceable clusters.** Tying decryption to a cluster's private key makes cluster recreation a manual re-encryption operation for every secret. Use SOPS for ephemeral or replaceable clusters.
- **SOPS age key without backup.** The age private key stored in the cluster is the sole decryption capability. Losing it means all bootstrapped secrets become permanently inaccessible. Back up the key to a secure offline location before first use.
- **Rotating by redeploying.** If rotation requires a maintenance window, it will never happen on the prescribed schedule.
- **One Vault policy to rule them all.** A shared policy with `secret/data/*` read access turns a single compromised pod into a full secrets compromise.
- **Same secrets in CI and production.** A CI credential leak must never be a production incident.
- **Logging the connection string.** `log.Printf("connecting to %s", dbURL)` ships the password to the log aggregator.
- **Long-lived static credentials where dynamic ones exist.** Use Vault dynamic secrets for databases; static KV v2 is the fallback, not the default.

---

## Output Format

```markdown
---
name: secrets-management-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Secrets Management Design

## Secret Inventory
| Secret | Type | Storage | Access policy | Rotation period | Rotation mechanism |
|---|---|---|---|---|---|

## GitOps Bootstrap Layer
[SOPS + age key setup; encrypted Secret manifests in environment repo]

## Vault Policy Definitions
[HCL policy per service]

## Runtime Injection Design
[Vault Agent sidecar config or ESO CRD per service]

## Secret Rotation Runbook
[Step-by-step rotation procedure per secret type]

## CI Secret Scanning
[Tool and configuration used]
```
