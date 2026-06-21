# Skill: design/secrets-management

## Purpose
Produce the Secrets Management Design — the specification for how all credentials, keys, tokens, and other secrets are stored, accessed, rotated, and audited. Implements the principle that secrets never appear in source code, environment variables, or config files.

## Inputs
- `artifacts/design/security/security-architecture.md`
- `sdlc-config.json`
- `artifacts/design/bounded-contexts.md`

## Output
**File:** `artifacts/design/security/secrets-management.md`
**Registers in manifest:** yes

## Secrets Management Rules (enforced)
- Secrets are NEVER stored in: source code, `.env` files, Kubernetes ConfigMaps, container images, CI/CD environment variables (plaintext), or log files.
- Every secret has an owner (which service uses it) and a rotation schedule.
- Secret rotation must be zero-downtime — services must support graceful key rotation without restart.
- Secret references (not values) are what flows through the system.
- Secrets scanning runs in CI on every commit and every PR — the pipeline fails on any secret detected.

## Artifact Template

```markdown
# Secrets Management Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Secrets Management Design
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Secret Inventory

| Secret | Owner service | Where stored | Rotation | Access method |
|--------|-------------|-------------|---------|--------------|
| Storage platform credentials (Google Drive, S3, etc.) | File Domain Service (at scan time) | Customer-operated Secrets Manager | On customer demand | SDK with read-only IAM role |
| PostgreSQL connection string (each service) | Each bounded context service | Kubernetes External Secrets (synced from Vault/AWS SM) | 90 days | Env var injected by Kubernetes (value, not reference) |
| Redpanda SASL credentials | Each service with Redpanda access | Kubernetes External Secrets | 90 days | Env var injected by Kubernetes |
| JWT RS256 private signing key | Identity Domain Service | Kubernetes Secret (sealed) | 180 days | File mount; loaded at startup |
| JWT RS256 public key | API Gateway, all services (for validation) | Kubernetes ConfigMap (public key — not secret) | With private key rotation | File mount |
| Field-level encryption keys (per-tenant C4) | Entity Domain Service | Customer-operated Secrets Manager | On-demand (key rotation API) | SDK at encryption/decryption time |
| Worker Node mTLS client certificate | Worker Node | Customer-operated Secrets Manager | 90 days | SDK at startup |
| Elasticsearch API key | Services that write to ES | Kubernetes External Secrets | 90 days | Env var injected |
| Alerting webhook URLs (Slack, PagerDuty) | Alert Domain Service | Kubernetes External Secrets | On channel change | Env var injected |
| Grafana admin password | Observability stack | Kubernetes Secret (sealed) | 180 days | Helm values (sealed) |

---

## Secrets Manager Strategy

### Customer-Operated Secrets (default)
All customer-specific secrets (storage credentials, field-level encryption keys, Worker Node certificates) are stored in the **customer's own Secrets Manager**:

- AWS environments: AWS Secrets Manager
- Google Cloud: Google Secret Manager
- Azure: Azure Key Vault
- Self-hosted: HashiCorp Vault (recommended)

The product never has write access to the customer's Secrets Manager. It reads secrets via a read-only IAM role or service account granted by the customer during onboarding.

### Product Infrastructure Secrets
Secrets for product infrastructure components (database passwords, Redpanda credentials, internal service keys) are managed via **Kubernetes External Secrets Operator** (ESO) + HashiCorp Vault (product-operated per tenant):

```
ESO → Vault → Kubernetes Secret → Pod (env var or file mount)
```

---

## Kubernetes Secrets Handling

**Rule:** Raw Kubernetes Secrets (`kind: Secret`) are not used directly in manifests committed to git.

All secrets in git are:
- **Sealed Secrets** (`SealedSecret` — Bitnami) — asymmetrically encrypted; safe to commit; only the cluster's controller can decrypt
- **External Secrets** (`ExternalSecret` — ESO) — references Vault/AWS SM; the secret value is never in git

```yaml
# Example: ExternalSecret for PostgreSQL password
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: file-domain-db-password
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-product-store
    kind: SecretStore
  target:
    name: file-domain-db-secret
  data:
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: product/{tenant}/file-domain/db
        property: password
```

---

## Rotation Procedures

### Zero-Downtime Database Password Rotation
1. New password written to Vault
2. ESO detects change (refresh interval 1h, or triggered manually)
3. Kubernetes Secret updated
4. Service picks up new value at next connection pool cycle (without restart, using `pgx` pool with credential reload)
5. Old password remains valid for 15 minutes (dual-active window) then revoked

### JWT Signing Key Rotation
1. New RS256 key pair generated
2. New private key stored in Kubernetes Secret (Sealed)
3. New public key published to JWKS endpoint
4. Identity Domain Service starts issuing tokens with new key (`kid` header indicates key version)
5. API Gateway validates against JWKS — accepts both old and new key during overlap window (24 hours)
6. Old key removed from JWKS after overlap window; old tokens expire naturally

### Field-Level Encryption Key Rotation (C4 data)
1. New encryption key generated and stored in customer's Secrets Manager
2. Rotation job reads entities encrypted with old key
3. Decrypts with old key; re-encrypts with new key
4. Writes new ciphertext to database
5. Old key marked as retired; removed after 7 days (allowing any in-flight reads to complete)
6. Full rotation audit log entry generated

---

## Secrets Scanning in CI

**Tool:** `gitleaks` (open-source)

```yaml
# .github/workflows/secrets-scan.yml
- name: Secret scan
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Scanning runs on:
- Every push to every branch
- Every PR (required check — PR cannot merge if secrets detected)

**Allowlist:** Known safe strings (test fixtures, example values) are added to `.gitleaks.toml` with justification.

**Build fails immediately** on any detected secret — there is no warning-only mode for secrets.
```

## Quality Checks
- [ ] Every secret in the system has an entry in the inventory
- [ ] No secret is stored in environment variables in plaintext (all use Kubernetes Secrets or ESO)
- [ ] Every secret has a rotation schedule and a zero-downtime rotation procedure
- [ ] Customer-operated secrets (storage credentials, encryption keys) are clearly separated from product-operated secrets
- [ ] Secrets scanning is in CI pipeline and is a hard gate (not advisory)
- [ ] JWT key rotation maintains a JWKS overlap window
