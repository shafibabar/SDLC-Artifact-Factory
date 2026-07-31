# Environment Config — Reference Material

Worked example, quality criteria, anti-patterns, and output template.
Loaded when the body of `environment-config/SKILL.md` points here.

---

## Worked Example — tenant-acme Values for estate-scanner

Everything tenant-specific for one service, in one reviewable file — and *only* legitimate difference classes appear:

```yaml
# clusters/tenant-acme/namespaces/tenant-acme/estate-scanner-helmrelease.yaml
# Flux HelmRelease — per-service delivery unit for tenant-acme
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: estate-scanner
  namespace: tenant-acme
spec:
  chart:
    spec:
      chart: estate-scanner
      version: ">=1.0.0"
      sourceRef:
        kind: HelmRepository
        name: sdlc-factory-charts
  values:
    tenant:
      id: acme                                      # identity — labels, metrics, alert routing
    replicaCount: 3                                 # replicas — acme's volume tier
    resources:
      requests: { cpu: 250m, memory: 256Mi }        # sizing — above the chart's base defaults
      limits:   { memory: 512Mi }
    ingress:
      host: acme.app.example.com                    # endpoint — tenant's own ingress host
    postgres:
      host: estate-scanner-db.tenant-acme.svc.cluster.local  # endpoint — physically isolated DB
    redpanda:
      brokers: redpanda.tenant-acme.svc.cluster.local:9092   # endpoint — tenant's own broker
    flags:
      extractor.v2.enabled: false                   # flag — not yet in acme's wave (feature-flag-design)
    env:
      LOG_LEVEL: info
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector.tenant-acme:4317
    # image.digest is set fleet-wide by the promotion PR — not per-tenant
```

No image digest override beyond the promotion pointer, no template fork, no secret. The Vault Agent annotation and the chart version are fleet-uniform; `tenant-globex`'s file differs from this one only in the same five legitimate difference classes. Diffing two tenants' directories *is* the tenant comparison report — PM-readable by construction.

---

## Environment-Repo Layout — Full Tree Example

This tree shows a two-service, two-tenant deployment at the moment of a staging soak:

```
clusters/
  dev/
    namespaces/
      dev/
        estate-scanner-helmrelease.yaml    # auto-promoted from green main
        data-ingestor-helmrelease.yaml
  staging/
    namespaces/
      staging/
        estate-scanner-helmrelease.yaml    # awaiting promotion PR review
        data-ingestor-helmrelease.yaml
  tenant-acme/
    namespaces/
      tenant-acme/
        estate-scanner-helmrelease.yaml    # at digest that staging soaked
        data-ingestor-helmrelease.yaml
  tenant-globex/
    namespaces/
      tenant-globex/
        estate-scanner-helmrelease.yaml
        data-ingestor-helmrelease.yaml
```

Each `HelmRelease` file contains the chart version and the `image.digest` field that the promotion invariance check asserts is identical across the fleet. The GitOps agent (Flux) watches its assigned path; no CI push step is required. Adding `tenant-bravo` is adding `clusters/tenant-bravo/` and committing — the reconciler picks it up within its polling interval.

---

## Local Development — `local-values.yaml` Shape

The `local-values.yaml` file overrides production defaults for the kind cluster. Only the five legitimate difference classes appear:

```yaml
# values/local-values.yaml — loaded by make local-up via helm upgrade -f
replicaCount: 1                                   # replicas — one is enough locally
resources:
  requests: { cpu: 100m, memory: 128Mi }          # sizing — laptop constraints
  limits:   { memory: 256Mi }
ingress:
  host: estate-scanner.local                      # endpoint — kind cluster local DNS
postgres:
  host: postgres.default.svc.cluster.local        # endpoint — in-cluster postgres for dev
redpanda:
  brokers: redpanda.default.svc.cluster.local:9092
env:
  LOG_LEVEL: debug
  OTEL_EXPORTER_OTLP_ENDPOINT: ""                 # flag — tracing disabled locally
flags:
  extractor.v2.enabled: true                      # flag — all flags on locally for coverage
```

There is no `image.digest` field in `local-values.yaml` — `kind load docker-image` bypasses image pull entirely; the locally-built image is referenced by name in the chart's default values.

---

## `make local-up` — Reference Implementation

The `Makefile` target that constitutes the golden path:

```makefile
# Makefile — local development golden path
SERVICE   := estate-scanner
CLUSTER   := $(SERVICE)-local
IMAGE     := $(SERVICE):local
CHART_DIR := ./charts/$(SERVICE)
VALUES    := values/local-values.yaml

.PHONY: local-up local-down

local-up:
	# 1. Boot kind cluster
	kind create cluster --name $(CLUSTER) 2>/dev/null || true
	# 2. Build the image locally
	docker build -t $(IMAGE) .
	# 3. Load image into kind — no registry round-trip
	kind load docker-image $(IMAGE) --name $(CLUSTER)
	# 4. Install chart with local values
	helm upgrade --install $(SERVICE) $(CHART_DIR) \
	  --kube-context kind-$(CLUSTER) \
	  -f $(VALUES) \
	  --set image.repository=$(SERVICE) --set image.tag=local \
	  --wait --timeout 120s
	@echo "Local environment ready. kubectl --context kind-$(CLUSTER) get pods"

local-down:
	kind delete cluster --name $(CLUSTER)
```

A new engineer runs `make local-up` from the service root on day one. No platform engineer is required. No documentation beyond the README's "Getting Started" one-liner is needed — this is the TVP test for the local golden path.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Environment set | kind-local / dev / staging / tenant stamps, each with a stated purpose | Ad-hoc environments; "test2" nobody can explain |
| Parity | Same chart version + same digest fleet-wide (within skew window) | Per-environment builds, forked charts, env-conditional code |
| Difference classes | Every env/tenant diff is sizing, replicas, endpoints, flags, or identity | Behavioural differences hidden in values; env checks in code |
| Configuration as Code | Every setting reaches clusters via the environment repo | `kubectl edit`, `--set` flags, console changes |
| Taxonomy applied | Each setting filed build/deploy/runtime with the decision table | Everything a live flag; or flags requiring redeploys |
| Secret split | Zero credentials in any values layer; Vault Agent only | Passwords in ConfigMaps or values files |
| Invariance checked | Digest-parity script gates every production promotion PR | Parity asserted in prose, unverified |
| Rebuildability | dev reproducible from Git alone, demonstrated | Environments that exist only as accumulated state |
| Identical provisioning | dev and staging provisioned by same OpenTofu + Helm pipeline as production | Any hand-built environment in dev or staging |
| Golden path | New engineer runs `make local-up` and has a working environment in minutes | Local setup requiring a setup guide, manual steps, or platform-engineer assistance |
| Directory layout | Environment repo follows `clusters/<name>/namespaces/<ns>/` convention | Flat structure; environment as CI variables; no tree-to-cluster mapping |
| Projected volumes | Multi-source mounts use projected volumes; one `volumeMount` entry per pod | Separate volumeMount per ConfigMap, Secret, and token; unbounded RBAC grants |

---

## Anti-Patterns

- **The environment if-statement** — `if os.Getenv("ENV") == "prod"` means production runs code no other environment ever executed. The binary is environment-blind; only its inputs vary.
- **Staging as a museum** — staging pinned to an old chart "because the demo works" no longer rehearses anything. Staging tracks the promotion path or it is dead weight.
- **Config in two homes** — half the settings in values, half in a ConfigMap someone edits by hand. One home: the environment repo. The reconciler owns cluster writes.
- **The snowflake tenant** — "acme needed one small template tweak" forks the fleet; that tenant now misses every future fix. Tenant needs are values; template changes are fleet changes (`multi-tenancy-design`).
- **Per-tenant staging fleets** — testing forty staging environments to prove one chart. Parity means one staging suffices; the canary tenant wave (`cd-pipeline`) is the production-side safety net.
- **Secrets promoted through Git "temporarily"** — Git never forgets; one committed credential is a rotation, a history rewrite, and an incident. The Vault boundary is absolute.
- **Unverified parity** — a policy without the invariance check decays the first time someone hotfixes a tenant directly. Checks, not intentions.
- **Hand-built dev or staging** — a developer who `kubectl apply`'d the dev environment "to save time" has untested the provisioning path. The next time the provisioning path runs is in a staging or production stamp — first real test, highest blast radius.
- **docker-compose for local development** — a docker-compose environment and a Kubernetes pod have different networking, scheduling, health-check, and secret-injection semantics; a service that works in docker-compose and breaks in kind has not been tested against its actual runtime.

---

## Output Format

Produces the environment configuration record for a product:

```markdown
---
name: environment-config-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Environment Configuration — [product]

## Environment Set
| Environment | Purpose | Sizing tier | Promotion trigger |

## Golden Path
[`make local-up` target path; what it boots, installs, and loads]
[How long it takes on a developer laptop from scratch]

## Values Layout
clusters/{dev,staging}/namespaces/{dev,staging}/…
clusters/tenants/[tenant-id]/namespaces/[tenant-id]/…
[Per service: which HelmRelease or Kustomization file; which values keys are set at which layer]

## Provisioning Process
[OpenTofu module(s) used; Helm chart version; Flux CRD type (HelmRelease or Kustomization)]
[CI job that auto-promotes to dev; PR gate for staging; PR gate + wave for production]

## Difference Register
| Setting | Class (sizing/replicas/endpoints/flags/identity) | dev | staging | prod default |

## Configuration Taxonomy Decisions
| Setting | Kind (build/deploy/runtime) | Rationale |

## Projected Volume Configuration
[Volume name; projected sources (ConfigMap + Secret + serviceAccountToken); mountPath]

## Invariance Gate
[Path to the promotion-parity check script; CI job that runs it on production promotion PRs]

## Traceability
[multi-tenancy-design stamp model; NFR IDs behind sizing tiers; feature-flag-design references]
```
