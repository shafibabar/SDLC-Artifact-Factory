# Secrets Management — Reference Patterns

Self-contained reference for the `secrets-management` skill. Usable without the parent `SKILL.md` in context.

Covers: SOPS + Flux bootstrap setup, Sealed Secrets workflow, Vault policy HCL, Vault Agent sidecar YAML, Go `Secret` type implementation, secret rotation procedures, CI scanning YAML.

---

## Part 1: GitOps Bootstrap Layer

### Why a Bootstrap Layer Is Necessary

In a GitOps model the environment repository is the source of truth for all cluster state. A Flux `Kustomization` or Argo CD `Application` must be able to bootstrap a fresh namespace from a single commit. This includes initial Kubernetes `Secret` resources: Vault Agent's connection address, the Vault Kubernetes auth role name, initial TLS CA certificates.

These secrets cannot be committed to Git as plaintext — anyone with repo read access would have the credentials. The bootstrap layer encrypts Secret manifests so they are safe to commit and version, while remaining decryptable by the in-cluster GitOps agent.

---

### Option A: SOPS + age (Recommended for per-tenant replaceable clusters)

**Why SOPS over Sealed Secrets for this repo:** Per-tenant cluster stamps are replaceable. If a cluster is recreated, SOPS-encrypted manifests remain decryptable as long as the same age private key is available — decryption is independent of any cluster's identity. Sealed Secrets couples decryption to a specific cluster's controller private key, making cluster recreation a manual re-encryption operation for every committed secret.

#### Step 1 — Generate the age key pair

```bash
# Install age: https://github.com/FiloSottile/age
age-keygen -o tenant-prod-age.key
# Output:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
# Private key file: tenant-prod-age.key (keep this secret; back it up offline)
```

#### Step 2 — Store the age private key in the cluster

This is the one step performed out-of-band during cluster bootstrap (before Flux is installed):

```bash
# The private key content is the second line of the key file (starts with AGE-SECRET-KEY-)
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=tenant-prod-age.key
```

#### Step 3 — Configure Flux kustomize-controller to use SOPS

Add a `decryption` stanza to the Flux `Kustomization` that manages the namespace:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenant-alpha-secrets
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: environment-repo
  path: ./tenants/alpha/secrets
  prune: true
  decryption:
    provider: sops
    secretRef:
      name: sops-age     # The Secret created in Step 2
```

The `kustomize-controller` automatically decrypts any SOPS-encrypted files in the kustomization path before applying them.

#### Step 4 — Encrypt a Secret manifest

```bash
# Create the plaintext manifest
cat > vault-bootstrap.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-bootstrap-config
  namespace: tenant-alpha
type: Opaque
stringData:
  vault_addr: "https://vault.internal.example.com:8200"
  vault_role: "tenant-alpha-services"
EOF

# Encrypt with SOPS (only encrypts the stringData values, not metadata)
sops --encrypt \
  --age age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p \
  --encrypted-regex '^(data|stringData)$' \
  vault-bootstrap.yaml > vault-bootstrap.enc.yaml

# Commit vault-bootstrap.enc.yaml; NEVER commit vault-bootstrap.yaml
```

The `--encrypted-regex '^(data|stringData)$'` flag encrypts only the secret values, leaving the Kubernetes metadata (name, namespace, labels) readable in plaintext — important for GitOps tooling that inspects manifests without decrypting them.

#### SOPS `.sops.yaml` Configuration File

Place a `.sops.yaml` at the root of the environment repo to make encryption configuration reproducible:

```yaml
# .sops.yaml
creation_rules:
  # Per-tenant age keys
  - path_regex: tenants/alpha/.*\.yaml$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
  - path_regex: tenants/beta/.*\.yaml$
    age: age1...betakey...
  # Shared infrastructure secrets use a management age key
  - path_regex: infrastructure/.*\.yaml$
    age: age1...mgmtkey...
```

With `.sops.yaml` present, `sops --encrypt` picks the correct key automatically:

```bash
sops --encrypt --in-place tenants/alpha/secrets/vault-bootstrap.yaml
```

#### SOPS age Key Rotation

When rotating the age key:

1. Generate the new key pair: `age-keygen -o tenant-prod-age-v2.key`
2. Re-encrypt all affected manifests: `sops updatekeys tenants/alpha/secrets/*.yaml` (adds the new key)
3. Commit the re-encrypted manifests
4. Update the in-cluster `sops-age` Secret with the new private key
5. Verify Flux reconciles successfully
6. Remove the old public key from `.sops.yaml` and re-encrypt again
7. Delete the old `sops-age` Secret (or remove the old key from it)

---

### Option B: Sealed Secrets (for long-lived, non-replaceable clusters)

Sealed Secrets is appropriate when the cluster has a stable, non-replaceable identity and cluster recreation is a rare, planned event.

#### Install the Sealed Secrets controller

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets-controller sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets-controller
```

#### Encrypt a Secret with kubeseal

```bash
# Fetch the controller's public key
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > pub-sealed-secrets.pem

# Seal a Secret
kubectl create secret generic vault-bootstrap-config \
  --namespace=tenant-alpha \
  --from-literal=vault_addr=https://vault.internal.example.com:8200 \
  --from-literal=vault_role=tenant-alpha-services \
  --dry-run=client -o yaml | \
kubeseal --format=yaml \
  --cert=pub-sealed-secrets.pem \
  > vault-bootstrap-sealed.yaml

# Commit vault-bootstrap-sealed.yaml — the SealedSecret CRD is safe to commit
```

The `SealedSecret` resource is applied by the controller, which decrypts it and creates the corresponding `Secret` in the namespace.

#### Sealed Secrets limitations

- **Cluster dependency:** A `SealedSecret` created against cluster A cannot be decrypted by cluster B's controller. Cluster recreation requires re-sealing every secret.
- **No cross-cluster portability:** Per-tenant stamps that may be recreated, migrated, or cloned should use SOPS instead.
- **Controller key backup:** The controller's private key must be backed up: `kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-controller-key-backup.yaml`. Loss of this key means all SealedSecrets become permanently inaccessible.

---

## Part 2: HashiCorp Vault Configuration

### Vault Policy (Principle of Least Privilege)

Each service has its own Vault policy. The path structure uses the tenant and service name to prevent cross-tenant and cross-service access:

```hcl
# Policy for the classification-service in tenant-alpha
path "secret/data/tenant/alpha/classification-service/*" {
  capabilities = ["read"]
}

path "database/creds/tenant-alpha-classification-service-role" {
  capabilities = ["read"]
}

# Explicit deny for other tenants (belt-and-suspenders; Vault denies by default)
path "secret/data/tenant/+/*" {
  capabilities = []
}
```

```bash
# Apply the policy
vault policy write tenant-alpha-classification-service policy.hcl

# Create the Kubernetes auth role binding the policy to a ServiceAccount
vault write auth/kubernetes/role/tenant-alpha-classification-service \
  bound_service_account_names=classification-service \
  bound_service_account_namespaces=tenant-alpha \
  policies=tenant-alpha-classification-service \
  ttl=1h
```

### Vault Secrets Engines

| Engine | Use case | Example path |
|---|---|---|
| `kv-v2` | Static secrets with versioning and rollback | `secret/data/tenant/alpha/classification-service/api-key` |
| `database` | Dynamic PostgreSQL credentials with auto-expiry | `database/creds/tenant-alpha-classification-service-role` |
| `pki` | Short-lived TLS certificates | `pki/issue/tenant-alpha-services` |
| `transit` | Encrypt-as-a-service (key never leaves Vault) | `transit/encrypt/tenant-alpha-data-key` |

Dynamic database credentials configuration:

```bash
vault write database/config/tenant-alpha-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tenant-alpha-*" \
  connection_url="postgresql://{{username}}:{{password}}@postgres-tenant-alpha:5432/classification_db" \
  username=vault-admin \
  password=<rotation-managed-by-vault>

vault write database/roles/tenant-alpha-classification-service-role \
  db_name=tenant-alpha-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

---

## Part 3: Runtime Injection — Vault Agent Sidecar

### Kubernetes Annotation-Based Injection

The Vault Agent Sidecar is injected via pod annotations. The Vault Agent Injector webhook reads these annotations and adds an init container (for secret pre-population) and a sidecar container (for ongoing renewal):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: classification-service
  namespace: tenant-alpha
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "tenant-alpha-classification-service"
        # Dynamic database credentials
        vault.hashicorp.com/agent-inject-secret-db: "database/creds/tenant-alpha-classification-service-role"
        vault.hashicorp.com/agent-inject-template-db: |
          {{- with secret "database/creds/tenant-alpha-classification-service-role" -}}
          postgresql://{{ .Data.username }}:{{ .Data.password }}@postgres-tenant-alpha:5432/classification_db
          {{- end }}
        # Static API key
        vault.hashicorp.com/agent-inject-secret-drive-api-key: "secret/data/tenant/alpha/classification-service/drive-api-key"
        vault.hashicorp.com/agent-inject-template-drive-api-key: |
          {{- with secret "secret/data/tenant/alpha/classification-service/drive-api-key" -}}
          {{ .Data.data.key }}
          {{- end }}
    spec:
      serviceAccountName: classification-service
      containers:
        - name: classification-service
          env:
            - name: DB_CREDENTIALS_FILE
              value: /vault/secrets/db
            - name: DRIVE_API_KEY_FILE
              value: /vault/secrets/drive-api-key
```

Secrets land at `/vault/secrets/<name>` in the application container. The Vault Agent refreshes these files before the credential TTL expires; the application must watch the file for changes.

---

## Part 4: Go Secret Consumption Patterns

### The Secret Redaction Type

```go
// secret.go
package secrets

import (
    "log/slog"
)

// Secret wraps a string value and ensures it is never accidentally
// serialised into logs, fmt output, or JSON responses.
type Secret string

// String implements fmt.Stringer — covers %s, %v, %q format verbs.
func (Secret) String() string { return "[REDACTED]" }

// GoString implements fmt.GoStringer — covers %#v (Go syntax representation).
func (Secret) GoString() string { return `secrets.Secret("[REDACTED]")` }

// LogValue implements slog.LogValuer — covers structured log fields.
func (Secret) LogValue() slog.Value { return slog.StringValue("[REDACTED]") }

// MarshalJSON prevents the raw value appearing in JSON responses or logs.
func (Secret) MarshalJSON() ([]byte, error) { return []byte(`"[REDACTED]"`), nil }

// Reveal is the single greppable escape hatch for the moment of actual use.
// The name is intentionally uncommon so code search surfaces every call site.
func (s Secret) Reveal() string { return string(s) }
```

Why each method matters:
- `String()` alone does NOT cover `%#v` (uses `GoString()`), slog structured fields (uses `LogValue()`), or JSON marshalling (uses `MarshalJSON()`)
- All four must be implemented; any gap is a secret leak path

### Reading Secrets from Vault Agent Files

```go
// credentials.go
package credentials

import (
    "fmt"
    "os"
    "strings"
    "time"

    "github.com/fsnotify/fsnotify"
    "yourmodule/secrets"
)

// LoadDatabaseURL reads the PostgreSQL connection URL written by the Vault
// Agent sidecar. The file is refreshed by the agent before TTL expiry;
// this function is called at startup and on file-change notification.
func LoadDatabaseURL() (secrets.Secret, error) {
    path := os.Getenv("DB_CREDENTIALS_FILE")
    if path == "" {
        path = "/vault/secrets/db"
    }
    data, err := os.ReadFile(path)
    if err != nil {
        return "", fmt.Errorf("reading database credentials from %s: %w", path, err)
    }
    return secrets.Secret(strings.TrimSpace(string(data))), nil
}

// WatchDatabaseURL calls onChange each time the Vault Agent refreshes the
// credential file. The caller is responsible for reconnecting the database
// pool with the new URL.
func WatchDatabaseURL(path string, onChange func(secrets.Secret)) error {
    if path == "" {
        path = "/vault/secrets/db"
    }
    watcher, err := fsnotify.NewWatcher()
    if err != nil {
        return fmt.Errorf("creating file watcher: %w", err)
    }
    if err := watcher.Add(path); err != nil {
        return fmt.Errorf("watching %s: %w", path, err)
    }
    go func() {
        for {
            select {
            case event, ok := <-watcher.Events:
                if !ok {
                    return
                }
                if event.Has(fsnotify.Write) || event.Has(fsnotify.Create) {
                    if url, err := LoadDatabaseURL(); err == nil {
                        onChange(url)
                    }
                }
            case <-watcher.Errors:
                time.Sleep(5 * time.Second) // back-off on watcher error
            }
        }
    }()
    return nil
}
```

**Rules:**
- Never assign a `Secret` to a package-level `var` — it lives for the process lifetime; Vault Agent refreshes the file, but the stale copy in the variable is what the code keeps using
- Never pass the `Secret.Reveal()` value to `log.Printf` or any logger
- Log only the connection host and database name, never the full URL
- Use `fsnotify` to watch for credential file updates and trigger pool reconnection

---

## Part 5: Secret Scanning CI Configuration

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scanning

on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

jobs:
  trufflehog:
    name: Detect secrets in commits
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0   # Full history needed for accurate diff scanning

      - name: Run TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified
        # --only-verified suppresses detector matches with no cryptographic
        # confirmation of validity, reducing false positives. Remove this flag
        # only if you need sensitivity over specificity.

  gitleaks:
    name: Detect secrets in full history (nightly)
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Response protocol when a secret is detected:**

1. **Rotate immediately** — treat the secret as compromised regardless of whether it was actually accessed
2. **Fail the pipeline** — do not merge; do not deploy
3. **Clean history** — `git filter-repo --path-glob '**' --use-base-name --invert-paths --path <file-containing-secret>` removes the file; for inline secrets, use `git filter-repo --replace-text` with a replacements file
4. **Force-push and notify all collaborators** — history rewrite invalidates all existing clones; team must `git fetch --all && git reset --hard origin/main`
5. **Log the incident** — record in the security incident register: when committed, when detected, what secret type, which service it granted access to, rotation timestamp

---

## Part 6: Secret Rotation Runbook

### Database Credentials (Vault Dynamic Secrets)

Vault dynamic secrets rotate automatically. No manual runbook required for steady-state rotation. The only manual intervention is adjusting TTL or revoking a lease on suspicion of compromise:

```bash
# List active leases for a role
vault list sys/leases/lookup/database/creds/tenant-alpha-classification-service-role

# Revoke a specific lease (on compromise)
vault lease revoke <lease-id>

# Revoke ALL leases for this role (on compromise of the role itself)
vault lease revoke -prefix database/creds/tenant-alpha-classification-service-role
```

After revocation, the Vault Agent detects the expired credential and immediately fetches a new one; the file watcher in the application triggers a pool reconnection.

### JWT Signing Key Rotation (Vault PKI)

```bash
# Issue a new signing key — the old key remains valid for existing token verification
vault write pki/root/rotate/internal \
  common_name=jwt-signing-root \
  ttl=87600h    # 10-year root; leaf keys are 90-day

# The application reads the current signing key from /vault/secrets/jwt-key
# and uses the `kid` header in issued JWTs so verifiers can identify which
# key to use — this enables zero-downtime rotation
```

### External API Key Rotation (Vault KV v2)

```bash
# Step 1: Write the new key to a new version (old version N remains readable)
vault kv put secret/tenant/alpha/classification-service/drive-api-key \
  key=<new-api-key>

# Step 2: Verify the application is using the new key (watch /vault/secrets/drive-api-key)
# Vault Agent picks up the new version within one refresh interval (default: 5 minutes)

# Step 3: Confirm old key is no longer in use; revoke access to version N-1 if needed
vault kv metadata put secret/tenant/alpha/classification-service/drive-api-key \
  max_versions=2    # retain only last 2 versions; older versions auto-deleted
```

### SOPS age Key Rotation

```bash
# Step 1: Generate new key
age-keygen -o tenant-alpha-age-v2.key

# Step 2: Add new public key to .sops.yaml creation_rules for affected paths
# Step 3: Re-encrypt all affected manifests (SOPS adds both keys)
find tenants/alpha -name '*.yaml' -exec sops updatekeys -y {} \;

# Step 4: Commit re-encrypted manifests
git add tenants/alpha && git commit -m "secrets: rotate SOPS age key for tenant-alpha"

# Step 5: Update the in-cluster Secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=tenant-alpha-age-v2.key \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 6: Verify Flux reconciles successfully
flux get kustomizations --watch

# Step 7: Remove old public key from .sops.yaml; re-encrypt without it
sops updatekeys -y tenants/alpha/secrets/*.yaml   # removes old key
git add tenants/alpha && git commit -m "secrets: remove old SOPS age key from tenant-alpha"
```

---

## Decision Reference: Which Tool for Which Problem

| Situation | Solution | Rationale |
|---|---|---|
| Database credentials in running pods | Vault dynamic secrets via Vault Agent sidecar | Auto-expiring, per-pod credentials; zero static credential storage |
| API keys that change infrequently | Vault KV v2 via External Secrets Operator | Synced to Kubernetes Secret; application reads from mounted volume |
| Initial Vault connection info in GitOps environment repo | SOPS + age | Safe to commit; decryption independent of cluster identity |
| Initial secrets in a long-lived, never-recreated cluster | Sealed Secrets | Simpler key management when cluster identity is permanent |
| JWT signing keys | Vault PKI with `kid` header rotation | Zero-downtime rotation via key identifier in token header |
| TLS certificates between services | Linkerd (auto-rotation every 24h) | Service mesh handles mTLS lifecycle without application code |
| Data-at-rest encryption keys | Vault Transit secrets engine | Key never leaves Vault; encrypt/decrypt via API call |
| CI test credentials | Separate Vault policy, non-production Vault cluster | CI credential leak must never be a production incident |
