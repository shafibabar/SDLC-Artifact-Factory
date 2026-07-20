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
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, helm, chart, values-layering, kind, templating, versioning]
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
│   ├── deployment.yaml
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

| Layer | Lives in | Contains | Example |
|---|---|---|---|
| **Base** (`values.yaml` in chart) | The chart | Safe defaults, every key documented | probe paths, port 8080, 2 replicas |
| **Per-environment** | `deploy/clusters/<env>/` | What differs by environment | staging resource sizes, log level, OTLP endpoint |
| **Per-tenant** | `deploy/clusters/tenants/<tenant-id>/` | The *only* place tenants differ | tenant id, ingress host, sizing tier, DB endpoint |

```yaml
# deploy/clusters/tenants/tenant-acme/estate-scanner-values.yaml
tenant:
  id: acme                       # traceability: propagated into labels and env
replicaCount: 3
ingress:
  host: acme.app.example.com
postgres:
  host: estate-scanner-db.tenant-acme.svc.cluster.local
```

The rule that keeps forty tenants upgradeable: **all tenant variation is values; chart version is fleet-uniform** (within the declared skew window). A tenant needing a template change is a chart change for everyone, reviewed once — never a forked chart. Secrets appear in **no** layer — the Vault Agent boundary from `cd-pipeline` holds here too.

---

## The Values Schema Is a Contract

`values.schema.json` makes invalid values a **install-time failure**, not a runtime surprise. Required keys have no defaults precisely so forgetting them fails loudly:

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["image", "resources"],
  "properties": {
    "image": {
      "type": "object",
      "required": ["repository", "digest"],
      "properties": {
        "repository": { "type": "string" },
        "digest": { "type": "string", "pattern": "^sha256:[a-f0-9]{64}$" },
        "tag": { "not": {} }
      }
    },
    "replicaCount": { "type": "integer", "minimum": 1 },
    "resources": {
      "type": "object",
      "required": ["requests", "limits"]
    }
  }
}
```

Note the two enforcement moves: `digest` must match `^sha256:…` (promotion by digest, `ci-pipeline`), and `tag` is *schema-forbidden* (`"not": {}`) — a values file that tries to deploy by mutable tag cannot install.

---

## Templating Rules

Templates render; they do not think:

- **Flow control only** — `if`/`range`/`with` to include or repeat blocks. No computed policy: a template never decides replica counts, derives resource sizes, or infers environment from a name. Decisions live in values, made by humans in reviewed PRs.
- **Helpers own identity** — names, labels, and selector labels are defined once in `_helpers.tpl` and included everywhere. A label typed by hand in a template is a future selector mismatch.
- **Standard labels on every object**, from the helper:

```yaml
{{- define "estate-scanner.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: data-estate-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.tenant }}tenant: {{ .Values.tenant.id }}{{ end }}
{{- end }}
```

- **Required blocks are unconditional.** Probes, resources, and securityContext render in every Deployment — there is no `if .Values.probes.enabled` escape hatch. Their *contents* come from values (validated by the schema); their *presence* is the chart's guarantee, and `kubernetes-manifest` defines what they must contain.

```yaml
# templates/deployment.yaml (extract — full workload standard in kubernetes-manifest)
containers:
  - name: {{ .Chart.Name }}
    image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
    securityContext: {{- toYaml .Values.containerSecurityContext | nindent 10 }}
    resources: {{- toYaml .Values.resources | nindent 10 }}
    livenessProbe:  { httpGet: { path: /healthz,  port: http } }
    readinessProbe: { httpGet: { path: /readyz,   port: http } }
    startupProbe:   { httpGet: { path: /startupz, port: http }, failureThreshold: 30 }
```

---

## Chart Testing — the Platform's Red-Green

Per the agent's TDD row: a chart proves itself by execution before merge. The CI job (part of `ci-pipeline`'s PR gates when `charts/**` changes):

```yaml
- run: helm lint charts/estate-scanner --strict
- run: |
    helm template charts/estate-scanner -f test/values-ci.yaml \
      | kubeconform -strict -summary          # schema-valid Kubernetes objects
- name: Install into kind
  run: |
    kind create cluster --wait 120s
    helm install estate-scanner charts/estate-scanner \
      -f test/values-ci.yaml --wait --timeout 180s
    kubectl rollout status deploy/estate-scanner
- name: Negative test — invalid values must fail
  run: |
    ! helm template charts/estate-scanner --set image.tag=latest   # schema rejects tags
```

Green means: lints clean, renders valid objects, installs and becomes Ready in a real (kind) cluster, and *rejects* what it must reject. The negative test is the red half — a schema nobody has seen fail is untested.

---

## Versioning and Digest Pinning

| Field | Meaning | Changed when |
|---|---|---|
| `Chart.yaml: version` | The chart's own semver | Any template/schema/default change — patch/minor/major by impact |
| `Chart.yaml: appVersion` | The service version the chart defaults to describing | Informational; the *running* version is always the values digest |
| `values: image.digest` | What actually runs | Every promotion (`cd-pipeline`) |

Chart version and image digest move independently: a probe-timing fix bumps the chart across the fleet without touching digests; a service release moves digests without touching the chart. Both are diffs in Git, both reviewed, both revertable.

---

## Worked Example — estate-scanner Chart Skeleton

The estate-scanner service (scans Google Drive/S3 sources, publishes `DocumentDiscovered` events to Redpanda) gets the structure above with these base values:

```yaml
# charts/estate-scanner/values.yaml
replicaCount: 2
image:
  repository: ghcr.io/acme/data-estate/estate-scanner
  # digest: — no default; schema-required, supplied per environment by cd-pipeline
service: { port: 8080 }
containerSecurityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities: { drop: ["ALL"] }
resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { memory: 256Mi }
terminationGracePeriodSeconds: 30      # > the Go server's 25s drain (go-service-skeleton)
podAnnotations:
  linkerd.io/inject: enabled           # Service Mesh mTLS (kubernetes-manifest)
env:
  configMapName: estate-scanner-env    # per-env config (environment-config)
autoscaling: { enabled: false }
```

Per-tenant values add only `tenant.id`, ingress host, replica sizing, and the tenant's PostgreSQL/Redpanda endpoints. The chart installs identically into `tenant-acme` and `tenant-globex` namespaces — physical isolation comes from *where* it installs and which endpoints its values point at, exactly as `multi-tenancy-design` prescribes.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One chart per service | Chart maps 1:1 to a Bounded Context's service | God-chart, or one chart parameterised into two services |
| Schema enforced | `values.schema.json` present; invalid values fail install | Free-form values; typos surface at runtime |
| Digest-only images | Schema requires digest, forbids tag | Tag-based image references installable |
| Layering clean | Base/env/tenant layers; tenant diffs are values-only | Env logic in templates, or forked per-tenant charts |
| Labels via helper | All objects labelled from `_helpers.tpl` | Hand-typed labels; selector drift possible |
| Required blocks | Probes/resources/securityContext unconditional | Any of them omittable via values |
| Tested by execution | lint + kubeconform + kind install + negative test in CI | Chart merged that has never installed anywhere |
| Versioned | Chart semver independent of image digest | Chart mutated without a version bump |

---

## Anti-Patterns

- **The umbrella god-chart** — one chart deploying all services couples every release to every other and makes per-service rollback impossible. Composition happens in the environment repo, not in `dependencies:`.
- **Logic in templates** — `{{ if eq .Release.Namespace "prod" }}replicas: 10{{ end }}` hides a production decision where no reviewer looks. Values decide; templates render.
- **`--set` as configuration** — flags on an install command live in shell history, not Git; GitOps cannot reconcile what it cannot see. Every value is a file in the environment repo.
- **Optional securityContext** — a `.Values.securityContext.enabled` toggle exists only to be turned off under deadline. Presence is non-negotiable; only contents are values.
- **Copy-paste tenant charts** — forking the chart for a tenant "just this once" creates the snowflake fleet `multi-tenancy-design` forbids; that tenant misses every future fix.
- **`latest`/tag references** — reintroduces mutable deploys the whole digest pipeline exists to prevent; the schema forbids it for a reason.
- **Untested schema** — a schema with no failing negative test in CI may be silently accepting everything (`additionalProperties`, wrong nesting). Test the red path.

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
charts/[service]/templates/{_helpers.tpl,deployment,service,serviceaccount,networkpolicy,pdb,hpa}.yaml
charts/[service]/test/values-ci.yaml

## Values Reference
[Table: key → type → required → layer where typically set → description]

## Test Evidence
[CI run: lint, kubeconform, kind install, negative test — link/status]

## Traceability
[Service's Container Diagram element; NFR IDs behind resource/replica defaults]
```
