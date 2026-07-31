---
name: helm-chart
description: >
  Teaches the one-chart-per-service Helm Chart standard — chart structure,
  values layering (base, per-environment, per-tenant), the required
  values.schema.json contract, templating rules that keep logic out of
  templates, standard app.kubernetes.io labels via helpers, mandatory
  probe/resource/securityContext blocks, chart testing with helm lint and a
  kind install in CI, and chart versioning with image digest pinning. Used by
  the platform-engineer during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, helm, chart, values-layering, kind, templating, versioning, workload-type, init-container]
related: [kubernetes-workload-patterns, kubernetes-manifest, cd-pipeline, multi-tenancy-design]
---

# Helm Chart

## Purpose

The Helm Chart is the delivery unit for a service: everything Kubernetes needs to run one Bounded Context's service, parameterised so the *same chart version* deploys to dev, staging, and every tenant's namespace with only values changing. One chart per service — never a god-chart deploying the whole platform, never a chart shared between services "because they look similar." Charts are consumed by the CD reconciler (`cd-pipeline` renders them via Flux `HelmRelease`), and what their templates are allowed to render is governed by `kubernetes-manifest`.

A chart is code: it has a schema, tests, and a version. A chart that only ever worked by hand-tuned `--set` flags is a defect.

---

## One Chart Per Service — Structure

```
charts/estate-scanner/
├── Chart.yaml                  # name, version, appVersion
├── values.yaml                 # base layer: safe defaults, full documentation
├── values.schema.json          # the contract — install fails on invalid values
├── templates/
│   ├── _helpers.tpl            # names, labels, selector labels — the only place they're defined
│   ├── workload.yaml           # renders Deployment, StatefulSet, DaemonSet, or Rollout
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── networkpolicy.yaml
│   ├── pdb.yaml
│   ├── hpa.yaml                # rendered only if autoscaling.enabled
│   └── NOTES.txt
└── README.md                   # values reference, PM-readable
```

Environment and tenant values live **outside** the chart, in the environment repo (`cd-pipeline`'s layout) — the chart is environment-agnostic by construction.

---

## Values Layering

Three layers, merged in order (later wins), mirroring the fleet model from `multi-tenancy-design`:

| Layer | Lives in | Contains |
|---|---|---|
| **Base** (`values.yaml` in chart) | The chart | Safe defaults, every key documented |
| **Per-environment** | `deploy/clusters/<env>/` | What differs by environment (resource sizes, endpoints) |
| **Per-tenant** | `deploy/clusters/tenants/<tenant-id>/` | The *only* place tenants differ (tenant id, ingress host, DB endpoint) |

The rule that keeps forty tenants upgradeable: **all tenant variation is values; chart version is fleet-uniform** within the declared skew window. Secrets appear in **no** layer — the Vault Agent boundary from `cd-pipeline` holds here too.

---

## The Values Schema Is a Contract

`values.schema.json` makes invalid values an **install-time failure**, not a runtime surprise. Two enforcement moves are non-negotiable: `image.digest` must match `^sha256:[a-f0-9]{64}$`, and `image.tag` is schema-forbidden (`"not": {}`) — a values file deploying by mutable tag cannot install.

Required keys have no defaults precisely so forgetting them fails loudly. See `references/chart-templates.md` for the full annotated schema.

---

## Templating Rules

Templates render; they do not think:

- **Flow control only** — `if`/`range`/`with` to include or repeat blocks. No computed policy: a template never decides replica counts, derives resource sizes, or infers environment from a name.
- **Helpers own identity** — names, labels, and selector labels are defined once in `_helpers.tpl` and included everywhere. A label typed by hand in a template is a future selector mismatch.
- **Standard `app.kubernetes.io/*` labels** on every object, emitted from the helper: `name`, `instance`, `version`, `part-of`, `managed-by`, and (when set) `tenant`.
- **Required blocks are unconditional.** Probes, resources, and securityContext render in every workload — there is no `if .Values.probes.enabled` escape hatch. Their *contents* come from values; their *presence* is the chart's guarantee.

See `references/chart-templates.md` for the full `_helpers.tpl`, a complete deployment template with all required blocks, and the multi-workload type template.

---

## Workload Type Selection

A chart's workload template renders a specific Kubernetes controller. The workload type is set by `workloadType` in `values.yaml` (default: `Deployment`). The `platform-engineer` sets this value per service; the decision of *which* type to use belongs to `kubernetes-workload-patterns`.

| `workloadType` value | Kubernetes resource | Use when |
|---|---|---|
| `Deployment` (default) | `apps/v1 Deployment` | Stateless services — the common case for all microservices |
| `StatefulSet` | `apps/v1 StatefulSet` | Services with stable storage or network identity (databases, Redpanda brokers) |
| `DaemonSet` | `apps/v1 DaemonSet` | Node-scoped agents — OTel Collector, Fluent Bit; one pod per node guaranteed |
| `Rollout` | `argoproj.io/v1alpha1 Rollout` | Progressive-delivery services (canary or blue-green via Argo Rollouts) |

The template uses `if`/`else if` branches to render the correct resource kind:

```yaml
{{- if eq .Values.workloadType "StatefulSet" }}
apiVersion: apps/v1
kind: StatefulSet
{{- else if eq .Values.workloadType "DaemonSet" }}
apiVersion: apps/v1
kind: DaemonSet
{{- else if eq .Values.workloadType "Rollout" }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
{{- else }}
apiVersion: apps/v1
kind: Deployment
{{- end }}
```

`helm-chart` owns the *mechanism* (the template branch and the `workloadType` values key). `kubernetes-workload-patterns` owns the *decision* (which branch to choose for a given service). See `references/chart-templates.md` for the full multi-workload template including `StatefulSet` `volumeClaimTemplates` and `DaemonSet` tolerations.

---

## Init Container Support

Init containers run to completion before any app container starts. The chart supports an optional `initContainers[]` block in `values.yaml`. When populated, it renders under `spec.initContainers` in the pod spec.

```yaml
# values.yaml — empty by default; populate when the service needs per-pod setup
initContainers: []
```

Template rendering (in the pod spec):

```yaml
{{- if .Values.initContainers }}
initContainers:
  {{- toYaml .Values.initContainers | nindent 2 }}
{{- end }}
```

Common init container uses: waiting for a database or dependency health endpoint to respond, pulling a secret from Vault into a shared `emptyDir` volume, running schema migrations before the service starts. The decision of *when* an init container is the right mechanism vs. an entrypoint script is in `kubernetes-workload-patterns` (the Init Container pattern from Ibryam & Huß).

See `references/chart-templates.md` for a worked init container values block and the full pod spec template with initContainers placement.

---

## Chart Testing — the Platform's Red-Green

Per the agent's TDD row: a chart proves itself by execution before merge. The CI job (part of `ci-pipeline`'s PR gates when `charts/**` changes) runs four steps in order:

1. `helm lint charts/<service> --strict` — clean lint
2. `helm template ... | kubeconform -strict` — schema-valid Kubernetes objects
3. `helm install ... --wait` into `kind` — installs and becomes Ready in a real cluster
4. Negative test: `! helm template ... --set image.tag=latest` — schema rejects mutable tags

Green means all four pass. The negative test is the red half — a schema nobody has seen fail is untested. See `references/chart-templates.md` for the full annotated CI YAML.

---

## Versioning and Digest Pinning

| Field | Meaning | Changed when |
|---|---|---|
| `Chart.yaml: version` | The chart's own semver | Any template/schema/default change — patch/minor/major by impact |
| `Chart.yaml: appVersion` | The service version the chart defaults to describing | Informational; the *running* version is always the values digest |
| `values: image.digest` | What actually runs | Every promotion (`cd-pipeline`) |

Chart version and image digest move independently: a probe-timing fix bumps the chart across the fleet without touching digests; a service release moves digests without touching the chart.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One chart per service | Chart maps 1:1 to a Bounded Context's service | God-chart, or one chart shared between services |
| Schema enforced | `values.schema.json` present; invalid values fail install | Free-form values; typos surface at runtime |
| Digest-only images | Schema requires digest, forbids tag | Tag-based image references installable |
| Layering clean | Base/env/tenant layers; tenant diffs are values-only | Env logic in templates, or forked per-tenant charts |
| Labels via helper | All objects labelled from `_helpers.tpl` | Hand-typed labels; selector drift possible |
| Required blocks | Probes/resources/securityContext unconditional | Any omittable via values |
| Workload type supported | `workloadType` value selects Deployment/StatefulSet/DaemonSet/Rollout | Chart always renders Deployment regardless of service shape |
| Init containers optional | `initContainers: []` default; renders when populated | Init container logic hard-coded in Dockerfile entrypoint |
| Tested by execution | lint + kubeconform + kind install + negative test in CI | Chart merged that has never installed anywhere |
| Versioned | Chart semver independent of image digest | Chart mutated without a version bump |

---

## Anti-Patterns

- **The umbrella god-chart** — one chart deploying all services couples every release to every other. Composition happens in the environment repo, not in `dependencies:`.
- **Logic in templates** — `{{ if eq .Release.Namespace "prod" }}replicas: 10{{ end }}` hides a production decision where no reviewer looks. Values decide; templates render.
- **`--set` as configuration** — flags on an install command live in shell history, not Git; GitOps cannot reconcile what it cannot see.
- **Optional securityContext** — a `.Values.securityContext.enabled` toggle exists only to be turned off under deadline. Presence is non-negotiable; only contents are values.
- **Hardcoded `Deployment` when a `DaemonSet` is needed** — deploying an OTel Collector as a `Deployment` with high replica count does not guarantee one-per-node; use `workloadType: DaemonSet`.
- **Init logic in entrypoint scripts** — shell loops polling for database readiness in the main container's entrypoint couple the app image to infrastructure knowledge; move to `initContainers`.
- **Copy-paste tenant charts** — forking the chart for a tenant creates the snowflake fleet `multi-tenancy-design` forbids.
- **`latest`/tag references** — reintroduces mutable deploys the whole digest pipeline exists to prevent; the schema forbids it for a reason.
- **Untested schema** — a schema with no failing negative test in CI may be silently accepting everything. Test the red path.

---

## Output Format

Produces the chart and its test fixtures:

```markdown
---
name: helm-chart-[service]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Helm Chart — [service]

## Files
charts/[service]/Chart.yaml
charts/[service]/values.yaml
charts/[service]/values.schema.json
charts/[service]/templates/{_helpers.tpl,workload,service,serviceaccount,networkpolicy,pdb,hpa}.yaml
charts/[service]/test/values-ci.yaml

## Values Reference
[Table: key → type → required → layer where typically set → description]
[Include: workloadType, initContainers]

## Test Evidence
[CI run: lint, kubeconform, kind install, negative test — link/status]

## Traceability
[Service's Container Diagram element; NFR IDs behind resource/replica defaults]
```
