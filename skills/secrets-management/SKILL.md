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
version: 1.1.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, secrets-management, vault, kubernetes, rotation, go]
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

## HashiCorp Vault as the Secrets Store

Vault is the primary secrets store for all non-certificate secrets. Vault provides:
- **KV v2 secrets engine:** Versioned key-value storage for static secrets
- **Database secrets engine:** Dynamic database credentials generated on demand, auto-revoked after a configurable TTL
- **PKI secrets engine:** Certificate authority for issuing short-lived TLS certificates
- **Transit secrets engine:** Encryption-as-a-service — services send plaintext, Vault returns ciphertext (the key never leaves Vault)
- **Audit log:** All secret accesses logged with identity and timestamp

### Vault Policy (Principle of Least Privilege)

```hcl
# Policy for the classification-service
path "secret/data/tenant/+/classification-service/*" {
  capabilities = ["read"]
}

path "database/creds/classification-service-role" {
  capabilities = ["read"]
}

# No access to other services' secrets
path "secret/data/tenant/+/other-service/*" {
  capabilities = []
}
```

Each service has its own Vault policy. Services cannot read each other's secrets.

---

## Runtime Injection in Kubernetes

Secrets are injected at runtime — never at build time. Two approaches:

### Approach 1: Vault Agent Sidecar

The Vault Agent runs as a sidecar container in the pod. It authenticates to Vault using the pod's Kubernetes ServiceAccount, fetches secrets, writes them to a shared in-memory volume, and refreshes them before they expire.

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "classification-service"
  vault.hashicorp.com/agent-inject-secret-db: "database/creds/classification-service-role"
  vault.hashicorp.com/agent-inject-template-db: |
    {{- with secret "database/creds/classification-service-role" -}}
    postgresql://{{ .Data.username }}:{{ .Data.password }}@postgres:5432/classification_db
    {{- end }}
```

The application reads the secret from the mounted file — never from an environment variable.

### Approach 2: External Secrets Operator

The External Secrets Operator runs as a Kubernetes controller. It syncs secrets from Vault into Kubernetes Secrets (encrypted at rest in etcd). The application consumes the Kubernetes Secret as a mounted volume.

**Recommendation:** Vault Agent Sidecar for dynamic secrets (database credentials). External Secrets Operator for static secrets (API keys) that change infrequently.

---

## Go Pattern: Reading Secrets at Runtime

```go
// Read database credentials from the Vault Agent injected file
func loadDatabaseURL() (string, error) {
    path := os.Getenv("DB_CREDENTIALS_FILE") // path to Vault Agent output file
    if path == "" {
        path = "/vault/secrets/db"
    }
    data, err := os.ReadFile(path)
    if err != nil {
        return "", fmt.Errorf("reading database credentials: %w", err)
    }
    return strings.TrimSpace(string(data)), nil
}

// The URL is read at startup and when the Vault Agent refreshes the file
// The application watches the file for changes using fsnotify
```

**Rules for Go secret consumption:**
- Never assign a secret to a package-level variable — it lives for the process lifetime and defeats rotation: the Vault Agent refreshes the file, but the stale copy in the variable is what the code keeps using
- Never log a secret, even at debug level — and never log the connection URL, which embeds the password
- Secrets should be read from files (Vault Agent output), not environment variables
- Wrap secrets in a redaction type so every formatting and logging path is covered:

```go
type Secret string

func (Secret) String() string       { return "[REDACTED]" } // %s, %v
func (Secret) GoString() string     { return "[REDACTED]" } // %#v
func (s Secret) LogValue() slog.Value { return slog.StringValue("[REDACTED]") } // slog
func (Secret) MarshalJSON() ([]byte, error) { return []byte(`"[REDACTED]"`), nil }

// Reveal is the single, greppable escape hatch for the moment of use
func (s Secret) Reveal() string { return string(s) }
```

`fmt.Stringer` alone is not enough — `%#v`, `slog` structured fields, and JSON marshalling each bypass `String()` unless covered explicitly.

---

## Secret Rotation

| Secret | Rotation mechanism | Zero-downtime rotation |
|---|---|---|
| Database passwords | Vault dynamic secrets — each connection gets unique credentials with TTL | Yes — old credentials valid until TTL expires |
| JWT signing keys | Vault PKI; new key issued; `kid` header enables graceful rotation | Yes — old tokens valid until expiry; new tokens use new key |
| External API keys | Manual rotation via Vault KV v2 versioning; rollback available | Yes — version N and N-1 both readable during transition |
| TLS certificates | Vault PKI auto-rotation or Linkerd auto-rotation | Yes — certificate rotation handled by the service mesh |

**Rotation test:** Rotation must be tested in a non-production environment. A rotation that brings down a production service has failed its design goal.

---

## Secret Scanning in CI

A pre-commit hook and a CI job scan for secrets in every commit:

```yaml
# GitHub Actions job
- name: Secret scanning
  uses: trufflesecurity/trufflehog@main
  with:
    path: ./
    base: ${{ github.event.repository.default_branch }}
    head: HEAD
    extra_args: --only-verified
```

If a secret is detected in a commit:
1. The CI pipeline fails immediately
2. The secret is rotated immediately (treat as compromised)
3. The commit history is cleaned (git filter-repo to remove the secret from history)
4. The incident is logged in the security incident register

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No secrets in source | Secret scanning CI job passes; no secrets in git history | Any secret found in source code or git history |
| Runtime injection only | All secrets injected via Vault Agent or ESO at pod startup | Secrets in environment variables or ConfigMaps |
| Least-privilege Vault policies | Each service's policy follows the Principle of Least Privilege; cannot read other services' secrets | Shared Vault policies; wildcard path access |
| Rotation documented | Every secret type has a rotation period and mechanism | Secrets with no rotation policy |
| Zero-downtime rotation | Rotation mechanism validated in non-production | Rotation not tested; unknown downtime impact |
| Secret redaction in logs | All logging of structs containing secrets redacts the secret field | Secret values appearing in application logs |

---

## Anti-Patterns

- **"Temporary" secrets in code.** A hardcoded test password committed "just to unblock CI" is a real credential in git history forever. There is no temporary tier — the pre-commit scan blocks all of them.
- **Secrets in environment variables.** Env vars leak through `/proc/<pid>/environ`, crash dumps, child processes, debug endpoints, and `kubectl describe pod`. File-mounted injection exists precisely to avoid this surface.
- **Rotating by redeploying.** Treating "rotate the database password" as "schedule a maintenance window" means rotation never happens. If rotation is not zero-downtime, the rotation period silently becomes never.
- **One Vault policy to rule them all.** A shared policy with `secret/data/*` read access turns a single compromised pod into a compromise of every service's secrets. One service, one Kubernetes ServiceAccount, one Vault role, one policy.
- **Same secrets in CI and production.** A CI credential leak (fork PRs, log masking failures) must never be a production incident. CI uses distinct, low-privilege credentials against non-production systems.
- **Deleting the leaked commit and moving on.** Removing a secret from HEAD does not remove it from history, forks, or clones. A committed secret is a compromised secret: rotate first, then clean history with `git filter-repo`.
- **Logging the connection string.** `log.Printf("connecting to %s", dbURL)` at startup ships the password to the log aggregator. Log the host and database name, never the URL.
- **Long-lived static credentials where dynamic ones exist.** Using a static database password from KV v2 when the database secrets engine can issue per-service, auto-expiring credentials. Static is the fallback, not the default.

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

## Vault Policy Definitions
[HCL policy per service]

## Runtime Injection Design
[Vault Agent sidecar config or ESO CRD per service]

## Secret Rotation Runbook
[Step-by-step rotation procedure per secret type]

## CI Secret Scanning
[Tool and configuration used]
```
