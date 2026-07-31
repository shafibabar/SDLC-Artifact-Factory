# Secrets in GitOps

Self-contained reference for managing Kubernetes secrets in a GitOps environment. Covers Sealed Secrets and SOPS in full detail, with concrete examples, decision criteria, and Flux integration configuration.

---

## The Problem

Git as the single source of truth for desired state creates an unavoidable tension: secrets cannot be stored in Git as plaintext. The two dominant patterns that resolve this tension are **Sealed Secrets** and **SOPS**. Both keep secrets under the same Git review workflow as manifests; they differ in where the decryption key lives.

---

## Full Comparison

| Dimension | Sealed Secrets | SOPS |
|---|---|---|
| **Encryption target** | Entire Kubernetes `Secret` resource | Specific YAML values (other fields remain readable) |
| **Key location** | Private key in the cluster (a controller-managed Kubernetes Secret) | External KMS (AWS KMS, GCP KMS, Azure Key Vault) or a local `age` key |
| **Decryption actor** | In-cluster `sealed-secrets-controller` | Flux `kustomize-controller` (natively) or any process with KMS access |
| **Cluster dependency** | Decryption tied to this cluster's private key — cluster recreation requires key backup/restore | Decryption independent of cluster identity — any cluster with KMS access can decrypt |
| **Key rotation** | Requires re-encrypting all SealedSecrets with the new key, or configuring key sealing | KMS key rotation is transparent to the encrypted files |
| **Multi-cluster** | Each cluster has its own key; a SealedSecret encrypted for tenant-alpha cannot be decrypted by tenant-beta | Same encrypted file can be decrypted by any cluster with the same KMS key or age private key |
| **Tooling** | `kubeseal` CLI; Kubernetes controller | `sops` CLI; no in-cluster controller needed |
| **Flux native** | No — Flux applies the SealedSecret CRD, the controller decrypts it | Yes — `kustomize-controller` decrypts inline before applying |
| **Audit trail** | SealedSecret commit history in Git | Encrypted YAML commit history in Git; KMS access logs |
| **Plaintext visibility** | Never plaintext in Git; only the controller sees plaintext | Plaintext only where the age key or KMS credentials are present |
| **Use when** | Long-lived, non-replaceable clusters; no external KMS available | **Ephemeral / replaceable clusters; per-tenant stamps; external KMS available** |

**Decision for this repo:** use SOPS + age key for per-tenant stamps. Rationale: tenant clusters are replaceable (per-tenant physical isolation means cluster recreation is a normal operational event); Sealed Secrets would require backing up and restoring the in-cluster private key on every cluster recreate, which is operationally fragile. SOPS decouples decryption from cluster identity.

---

## SOPS: Setup and Workflow

### 1. Generate an age Key Pair

```bash
# Install age
brew install age  # macOS
# or
apt-get install age  # Debian/Ubuntu

# Generate a new key pair
age-keygen -o age.agekey
# Output: Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
# The private key (secret!) is in age.agekey

# Store the private key as a Flux Secret in the cluster
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age.agekey
# Delete the local key file after storing — do NOT commit it
rm age.agekey
```

**The age public key** is committed to the repo in `.sops.yaml`. The private key stays exclusively in the cluster as a Kubernetes Secret (which Flux uses for decryption) and in a secure secrets manager (e.g., 1Password, AWS Secrets Manager) for disaster recovery.

---

### 2. Configure .sops.yaml

```yaml
# .sops.yaml at the repo root — commits which keys encrypt which paths
creation_rules:
  - path_regex: clusters/tenant-alpha-prod/.*\.yaml
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
  - path_regex: clusters/tenant-beta-prod/.*\.yaml
    age: age1rp7vn4h8s9k3d1q0w5x6m2t8z4e9f7g1h5j3l9n0p2r4s8u6v3w7y1  # tenant-beta's key
  - path_regex: staging/.*\.yaml
    age: age1staging...
```

**Per-tenant keys:** each tenant cluster has its own age key pair. A secret encrypted for tenant-alpha cannot be decrypted on tenant-beta's cluster. This enforces per-tenant isolation at the secret layer without requiring Sealed Secrets' per-cluster controller.

---

### 3. Encrypt a Secret

```bash
# Create a plaintext Secret manifest
cat > /tmp/db-password.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: platform
type: Opaque
stringData:
  password: supersecret123
  username: app_user
EOF

# Encrypt with SOPS (uses .sops.yaml to find the right key)
sops --encrypt /tmp/db-password.yaml > clusters/tenant-alpha-prod/namespaces/platform/db-credentials.yaml

# Verify the output — only the values are encrypted, the structure is readable:
cat clusters/tenant-alpha-prod/namespaces/platform/db-credentials.yaml
```

Encrypted output looks like:
```yaml
apiVersion: v1
kind: Secret
metadata:
    name: db-credentials
    namespace: platform
    # sops metadata injected here
sops:
    age:
        - recipient: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
          enc: |
              -----BEGIN AGE ENCRYPTED FILE-----
              YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUx...
              -----END AGE ENCRYPTED FILE-----
    lastmodified: "2026-07-31T10:00:00Z"
    mac: ENC[AES256_GCM,data:xyz...,tag:abc...,type:str]
    version: 3.7.3
stringData:
    password: ENC[AES256_GCM,data:Xv3...,tag:Yz9...,type:str]
    username: ENC[AES256_GCM,data:Qw2...,tag:Rs7...,type:str]
```

The structure (metadata, field names) is readable; only the values are encrypted. This is the key SOPS advantage over encrypting the whole file — diffs in Git are meaningful.

---

### 4. Configure Flux kustomize-controller for SOPS

```yaml
# clusters/tenant-alpha-prod/namespaces/platform/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-workloads
  namespace: flux-system
spec:
  interval: 5m
  prune: true
  sourceRef:
    kind: GitRepository
    name: environment-repo
  path: ./clusters/tenant-alpha-prod/namespaces/platform
  decryption:                          # SOPS decryption configuration
    provider: sops
    secretRef:
      name: sops-age                   # The Kubernetes Secret holding age.agekey (created in step 1)
```

With `decryption.provider: sops`, Flux's `kustomize-controller` automatically decrypts any SOPS-encrypted files in the path before applying them. No additional controller is needed.

---

### 5. Updating a Secret

```bash
# Edit in-place — SOPS decrypts, opens in $EDITOR, re-encrypts on save
sops clusters/tenant-alpha-prod/namespaces/platform/db-credentials.yaml

# Commit the re-encrypted file
git add clusters/tenant-alpha-prod/namespaces/platform/db-credentials.yaml
git commit -m "rotate db-credentials password for tenant-alpha"
git push
```

The commit appears in Git history as a change to an encrypted value — auditable ("a rotation happened at this time") without exposing the plaintext.

---

## Sealed Secrets: Setup and Workflow

Use Sealed Secrets for long-lived clusters where cluster-tied encryption is acceptable and no external KMS is available.

### 1. Install the Controller

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
# Or via Helm (preferred for GitOps):
# Add a HelmRelease for sealed-secrets/sealed-secrets to flux-system namespace
```

### 2. Fetch the Cluster's Public Certificate

```bash
kubeseal --fetch-cert \
  --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  > sealed-secrets-public-cert.pem
# Commit sealed-secrets-public-cert.pem — it's public, safe to store in Git
```

### 3. Encrypt a Secret

```bash
# Create a standard Kubernetes Secret
kubectl create secret generic db-credentials \
  --namespace=platform \
  --from-literal=password=supersecret123 \
  --dry-run=client -o yaml > /tmp/db-credentials.yaml

# Encrypt with kubeseal
kubeseal \
  --cert sealed-secrets-public-cert.pem \
  --format yaml \
  < /tmp/db-credentials.yaml \
  > clusters/long-lived-cluster/namespaces/platform/db-credentials.sealed.yaml

# Commit the SealedSecret — it's safe to store in Git
git add clusters/long-lived-cluster/namespaces/platform/db-credentials.sealed.yaml
git commit -m "add db-credentials sealed secret"
```

### 4. Key Rotation

When the Sealed Secrets controller rotates its key (default: every 30 days), it keeps old keys for decryption. Existing SealedSecrets continue to work. To re-encrypt with the new key:

```bash
# Fetch the new public cert
kubeseal --fetch-cert > sealed-secrets-public-cert-new.pem
# Re-run kubeseal on each SealedSecret file
```

**This is the operational burden** that makes Sealed Secrets unsuitable for ephemeral clusters — if the cluster is recreated from scratch, the controller's private key is gone, and all SealedSecrets become unreadable unless the private key was backed up.

---

## Backup and Disaster Recovery

### For SOPS + age:
- Store the age private key in a secure external location (AWS Secrets Manager, 1Password, HashiCorp Vault).
- Recovery: re-create the cluster, restore the `sops-age` Kubernetes Secret from the backup, run `flux bootstrap` — the environment self-heals from Git.
- Because decryption is independent of cluster identity, no re-encryption of committed files is needed.

### For Sealed Secrets:
- Back up the controller's private key:
  ```bash
  kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
  # Store this backup in a secure external location — DO NOT commit it
  ```
- Recovery: create the cluster, apply the key backup before installing the controller, then install the controller — it finds the backed-up key and decryption works.
- Without the backup, all SealedSecrets are permanently unreadable.

---

## Anti-Patterns to Avoid

| Anti-Pattern | Consequence | Correct Approach |
|---|---|---|
| Plaintext secrets in Git | Credentials leaked to everyone with repo access | SOPS or Sealed Secrets — never plaintext |
| Secrets in environment variables in Dockerfile | Secrets in image layers; visible in `docker history` | Inject at runtime via Flux-applied `Secret` |
| Using the same age key for all tenants | Tenant-alpha's secrets readable by anyone with tenant-beta's cluster access | One age key pair per tenant cluster |
| Committing the age private key | Full decryption capability in the repo | Age private key lives only in cluster Secret + external backup |
| Manual `kubectl create secret` without a corresponding Git commit | Drift — the live secret has no Git history; Flux may overwrite or prune it | Always create secrets via SOPS-encrypted files committed to Git |
