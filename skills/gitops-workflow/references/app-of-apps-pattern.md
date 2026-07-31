# App of Apps Pattern

Self-contained reference for implementing the App of Apps pattern with Flux. Covers the pattern's purpose, step-by-step implementation, and how to bootstrap a new tenant environment from a single CRD commit.

---

## Purpose

The App of Apps pattern addresses the bootstrap problem in GitOps: if each service's reconciliation CRD must be manually created in the cluster, adding a service or a new environment still requires imperative cluster operations. The App of Apps inverts this — a single **root CRD** (a Flux `Kustomization` or an Argo CD `Application`) points to a directory whose contents are the child CRDs for every service. The root CRD is the environment; everything else flows from it.

**When to use it:** any environment with more than two services. Below two services, a flat list of `HelmRelease` CRDs in the cluster's `flux-system` bootstrap Kustomization is sufficient. Above two services, the App of Apps root provides a single Git commit as the environment's lifecycle operator.

---

## Conceptual Model

```
Git commit: "add reporting service to tenant-gamma"
     ↓
clusters/tenant-gamma-prod/namespaces/platform/reporting.helmrelease.yaml  (new file)
     ↓
Root Kustomization (already running in the cluster) reconciles its source path
     ↓
Discovers the new HelmRelease file
     ↓
Applies HelmRelease to the cluster
     ↓
Helm controller installs the chart
     ↓
Service is running
```

No human touches the cluster. The root Kustomization continuously watches its source path; any new file is a new resource.

---

## Step-by-Step Implementation with Flux

### Step 1: Bootstrap Flux on the Cluster

Flux bootstrap installs the Flux controllers and creates the `flux-system` namespace and the root GitRepository + root Kustomization. This is the one-time imperative operation that seeds the system.

```bash
# Prerequisites: kubectl context pointing to tenant-gamma-prod
flux bootstrap github \
  --owner=org \
  --repository=environment-repo \
  --branch=main \
  --path=clusters/tenant-gamma-prod \
  --personal=false \
  --token-auth  # Or --ssh-key-algorithm=ecdsa for SSH
```

This command:
1. Creates a GitHub deploy key (read-only) on the environment repo.
2. Creates the `flux-system` namespace in the cluster.
3. Installs Flux controllers via a Helm chart.
4. Creates a `GitRepository` CRD pointing at the environment repo.
5. Creates a `Kustomization` CRD pointing at `clusters/tenant-gamma-prod/flux-system/`.
6. Commits the generated manifests (`gotk-components.yaml`, `gotk-sync.yaml`) to the environment repo under `clusters/tenant-gamma-prod/flux-system/`.

After bootstrap, the cluster is in a self-managing state: Flux watches its own configuration directory in Git and reconciles itself.

---

### Step 2: Define the Root Kustomization (App of Apps Root)

The root Kustomization created by bootstrap watches `clusters/tenant-gamma-prod/flux-system/`. Create an additional Kustomization that watches the namespace directories — this is the App of Apps root.

```yaml
# clusters/tenant-gamma-prod/flux-system/platform-apps.yaml
# (This file is picked up by the bootstrap Kustomization watching flux-system/)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-apps
  namespace: flux-system
spec:
  interval: 5m
  retryInterval: 2m
  timeout: 5m
  prune: true
  force: true
  sourceRef:
    kind: GitRepository
    name: flux-system   # The GitRepository created by bootstrap
  path: ./clusters/tenant-gamma-prod/namespaces/platform
  dependsOn:
    - name: flux-system  # Wait for Flux itself to be healthy before reconciling apps
```

**`prune: true` is mandatory.** Without it, deleting a file from Git does not delete the resource from the cluster — the pattern's core "delete = Git operation" property only holds with pruning enabled.

---

### Step 3: Create the Namespace and Service HelmReleases

```yaml
# clusters/tenant-gamma-prod/namespaces/platform/kustomization.yaml
# Kustomize config that tells kustomize-controller which files to include
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - api-gateway.helmrelease.yaml
  - data-ingestor.helmrelease.yaml
```

```yaml
# clusters/tenant-gamma-prod/namespaces/platform/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: platform
  labels:
    tenant: gamma
    environment: production
```

```yaml
# clusters/tenant-gamma-prod/namespaces/platform/api-gateway.helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: api-gateway
  namespace: platform
spec:
  interval: 10m
  chart:
    spec:
      chart: api-gateway
      version: "1.5.2"
      sourceRef:
        kind: HelmRepository
        name: internal-charts
        namespace: flux-system
  values:
    replicaCount: 2
    image:
      tag: "v1.5.2"
    ingress:
      host: api.tenant-gamma.example.com
    config:
      tenantId: gamma
      databaseUrl: "postgresql://db.tenant-gamma.internal:5432/appdb"
```

---

### Step 4: Bootstrap a New Tenant Environment From a Single Commit

Once the pattern is established, creating a new tenant environment is a single PR:

```bash
# Copy an existing tenant's directory as a starting point
cp -r clusters/tenant-alpha-prod clusters/tenant-gamma-prod

# Update cluster-specific values
# 1. gotk-sync.yaml: cluster name label, path reference
# 2. Each HelmRelease: tenant-specific host, tenantId, databaseUrl
# 3. SOPS-encrypted secrets: re-encrypt with tenant-gamma's age public key

# Stage and commit
git add clusters/tenant-gamma-prod/
git commit -m "feat: add tenant-gamma production environment

Stamps the full platform stack for tenant gamma:
- api-gateway, data-ingestor, reporting services
- monitoring namespace with prometheus + grafana
- SOPS-encrypted secrets (tenant-gamma age key)

Closes #521"

git push
# Open PR → merge
```

After `flux bootstrap` is run for the new cluster (one-time operation), everything else is self-seeding from Git.

---

### Step 5: Tearing Down an Environment

```bash
# Remove the cluster directory
rm -rf clusters/tenant-gamma-prod/namespaces/

# Commit the removal
git add clusters/tenant-gamma-prod/
git commit -m "feat: decommission tenant-gamma environment"
git push
# Open PR → merge
```

On next reconcile, Flux sees the namespace directory is empty (or missing). With `prune: true`, it deletes all the child CRDs, which triggers their controllers to delete the Helm releases and namespace. The environment is gone as a Git operation.

**Important:** run `flux uninstall` or delete the cluster to remove the Flux controllers themselves. The above only removes the application workloads, not the GitOps machinery.

---

## Adding a New Service to All Environments

To add a new service `payments` to every tenant environment:

```bash
# Add HelmRelease to each cluster's namespace directory
for cluster in clusters/*/namespaces/platform; do
  cat > "${cluster}/payments.helmrelease.yaml" <<EOF
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: payments
  namespace: platform
spec:
  interval: 10m
  chart:
    spec:
      chart: payments
      version: "0.1.0"
      sourceRef:
        kind: HelmRepository
        name: internal-charts
        namespace: flux-system
  values:
    image:
      tag: "v0.1.0"
EOF
  # Add to kustomization.yaml resources list
  # (sed or yq to append - payments.helmrelease.yaml)
done

git add clusters/
git commit -m "feat: add payments service to all environments"
git push
```

Each cluster's Flux reconciles independently and installs the service on its own schedule. Rollout is not simultaneous (each cluster polls at its own interval), which provides a natural wave progression — dev picks it up first, then staging, then each production tenant.

---

## Argo CD Equivalent

For teams using Argo CD, the equivalent pattern uses nested `Application` CRDs:

```yaml
# Root Application (the "app of apps")
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tenant-gamma-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/environment-repo
    targetRevision: main
    path: clusters/tenant-gamma-prod/apps   # Directory of child Application CRDs
  destination:
    server: https://kubernetes.tenant-gamma.example.com
    namespace: argocd
  syncPolicy:
    automated:
      prune: true       # Delete child Applications removed from Git
      selfHeal: true    # Revert manual edits (drift-as-incident enforcement)
    syncOptions:
      - CreateNamespace=true
```

Child `Application` CRDs in `clusters/tenant-gamma-prod/apps/` each point to their service's Helm chart or manifests repository. The UI shows each child Application's sync status independently — this is the multi-team visibility advantage Argo CD provides over Flux.

---

## Pattern Decision Table

| Situation | Recommendation |
|---|---|
| 1–2 services, single cluster | Flat HelmRelease list; no App of Apps needed |
| 3+ services, single cluster | App of Apps root Kustomization |
| Multiple tenant clusters | App of Apps per cluster, plus a management-plane root (optional) |
| Non-SRE teams need deploy visibility | Argo CD with Application CRDs and web UI |
| SRE-only, ephemeral clusters, SOPS secrets | Flux with Kustomization as the App of Apps root |
| Mixed Helm + raw manifests in one environment | Flux (composable: Kustomization and HelmRelease can coexist under the same root) |
