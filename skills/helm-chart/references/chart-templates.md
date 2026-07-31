# Helm Chart Reference — Templates, Schema, and Worked Examples

Self-contained reference for the `helm-chart` skill. Usable without the parent SKILL.md in context.
Covers: full `values.schema.json`, `_helpers.tpl`, multi-workload-type template, init container
pattern, CI pipeline YAML, and the estate-scanner worked example.

---

## values.schema.json — Full Annotated Schema

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["image", "resources"],
  "additionalProperties": false,
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "description": "Number of pod replicas. Overridden per environment."
    },
    "workloadType": {
      "type": "string",
      "enum": ["Deployment", "StatefulSet", "DaemonSet", "Rollout"],
      "default": "Deployment",
      "description": "Kubernetes workload controller to render. See kubernetes-workload-patterns for the selection decision."
    },
    "image": {
      "type": "object",
      "required": ["repository", "digest"],
      "additionalProperties": false,
      "properties": {
        "repository": {
          "type": "string",
          "description": "OCI image repository path, e.g. ghcr.io/acme/data-estate/estate-scanner"
        },
        "digest": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$",
          "description": "Immutable image digest. Supplied by cd-pipeline on every promotion."
        },
        "tag": {
          "not": {},
          "description": "Deliberately forbidden. Mutable tag deploys are prevented at schema level."
        }
      }
    },
    "initContainers": {
      "type": "array",
      "default": [],
      "items": {
        "type": "object",
        "required": ["name", "image"],
        "properties": {
          "name":    { "type": "string" },
          "image":   { "type": "string" },
          "command": { "type": "array", "items": { "type": "string" } },
          "env":     { "type": "array" },
          "volumeMounts": { "type": "array" }
        }
      },
      "description": "Optional init containers. Run to completion before the main container starts."
    },
    "service": {
      "type": "object",
      "properties": {
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 },
        "type":  { "type": "string", "enum": ["ClusterIP", "NodePort", "LoadBalancer"], "default": "ClusterIP" }
      }
    },
    "resources": {
      "type": "object",
      "required": ["requests", "limits"],
      "properties": {
        "requests": {
          "type": "object",
          "required": ["cpu", "memory"],
          "properties": {
            "cpu":    { "type": "string" },
            "memory": { "type": "string" }
          }
        },
        "limits": {
          "type": "object",
          "required": ["memory"],
          "properties": {
            "memory": { "type": "string" }
          }
        }
      }
    },
    "containerSecurityContext": {
      "type": "object",
      "properties": {
        "runAsNonRoot":             { "type": "boolean" },
        "readOnlyRootFilesystem":   { "type": "boolean" },
        "allowPrivilegeEscalation": { "type": "boolean" },
        "capabilities": {
          "type": "object",
          "properties": {
            "drop": { "type": "array", "items": { "type": "string" } }
          }
        }
      }
    },
    "autoscaling": {
      "type": "object",
      "properties": {
        "enabled":      { "type": "boolean" },
        "minReplicas":  { "type": "integer", "minimum": 1 },
        "maxReplicas":  { "type": "integer", "minimum": 1 },
        "targetCPUUtilizationPercentage": { "type": "integer", "minimum": 1, "maximum": 100 }
      }
    },
    "terminationGracePeriodSeconds": {
      "type": "integer",
      "minimum": 0,
      "description": "Must be >= the application's drain timeout (go-service-skeleton uses 25s, so set to 30)."
    },
    "podAnnotations": {
      "type": "object",
      "additionalProperties": { "type": "string" }
    },
    "env": {
      "type": "object",
      "properties": {
        "configMapName": { "type": "string" }
      }
    },
    "tenant": {
      "type": "object",
      "properties": {
        "id": { "type": "string" }
      }
    },
    "ingress": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "host":    { "type": "string" }
      }
    },
    "volumeClaimTemplates": {
      "type": "array",
      "description": "StatefulSet PVC templates. Only meaningful when workloadType is StatefulSet.",
      "items": { "type": "object" }
    }
  }
}
```

---

## _helpers.tpl — Full Template

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name — release + chart name, truncated to 63 chars (Kubernetes label limit).
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "chart.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Standard app.kubernetes.io labels — applied to every object.
*/}}
{{- define "chart.labels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: data-estate-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.tenant }}
tenant: {{ .Values.tenant.id }}
{{- end }}
{{- end }}

{{/*
Selector labels — used in matchLabels; must be stable across upgrades.
Never include version here (it changes with every release and would break selectors).
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name — the account the pod runs as.
*/}}
{{- define "chart.serviceAccountName" -}}
{{- include "chart.fullname" . }}
{{- end }}
```

---

## Multi-Workload Template (templates/workload.yaml)

Renders Deployment, StatefulSet, DaemonSet, or Argo Rollout based on `workloadType`.
The pod spec (containers, volumes, security) is identical across branches — only the outer
resource kind and type-specific fields (volumeClaimTemplates, tolerations) differ.

```yaml
{{- $workloadType := .Values.workloadType | default "Deployment" -}}
{{- if eq $workloadType "StatefulSet" }}
apiVersion: apps/v1
kind: StatefulSet
{{- else if eq $workloadType "DaemonSet" }}
apiVersion: apps/v1
kind: DaemonSet
{{- else if eq $workloadType "Rollout" }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
{{- else }}
apiVersion: apps/v1
kind: Deployment
{{- end }}
metadata:
  name: {{ include "chart.fullname" . }}
  labels:
    {{- include "chart.labels" . | nindent 4 }}
spec:
  {{- if not (eq $workloadType "DaemonSet") }}
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "chart.selectorLabels" . | nindent 6 }}
  {{- if eq $workloadType "StatefulSet" }}
  serviceName: {{ include "chart.fullname" . }}-headless
  {{- end }}
  {{- if eq $workloadType "Rollout" }}
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: { duration: 5m }
        - setWeight: 50
        - pause: { duration: 5m }
        - setWeight: 100
  {{- else if not (eq $workloadType "DaemonSet") }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  {{- end }}
  template:
    metadata:
      labels:
        {{- include "chart.selectorLabels" . | nindent 8 }}
      annotations:
        linkerd.io/inject: enabled
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "chart.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      {{- if .Values.initContainers }}
      initContainers:
        {{- toYaml .Values.initContainers | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
          imagePullPolicy: IfNotPresent
          securityContext:
            {{- toYaml .Values.containerSecurityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          envFrom:
            - configMapRef:
                name: {{ .Values.env.configMapName }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            initialDelaySeconds: 3
            periodSeconds: 5
          startupProbe:
            httpGet: { path: /startupz, port: http }
            failureThreshold: 30
            periodSeconds: 5
      {{- if eq $workloadType "DaemonSet" }}
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      {{- end }}
  {{- if eq $workloadType "StatefulSet" }}
  {{- with .Values.volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
```

---

## Init Container — Worked Values Block

```yaml
# charts/estate-scanner/values.yaml — wait-for-db init container example
initContainers:
  - name: wait-for-db
    image: "ghcr.io/acme/busybox@sha256:<digest>"
    command:
      - sh
      - -c
      - |
        echo "Waiting for PostgreSQL at $DB_HOST:5432..."
        until nc -z "$DB_HOST" 5432; do
          echo "not ready, sleeping 2s"
          sleep 2
        done
        echo "PostgreSQL is ready."
    env:
      - name: DB_HOST
        valueFrom:
          configMapKeyRef:
            name: estate-scanner-env
            key: POSTGRES_HOST

# Migration init container (run after DB is ready, before service starts)
# initContainers:
#   - name: migrate
#     image: "ghcr.io/acme/data-estate/estate-scanner-migrate@sha256:<digest>"
#     command: ["./migrate", "up"]
#     env:
#       - name: DATABASE_URL
#         valueFrom:
#           secretKeyRef:
#             name: estate-scanner-db-secret
#             key: DATABASE_URL
```

**Init container placement rule:** initContainers run in declared order before any container in
`containers[]` starts. A pod whose init container exits non-zero restarts the init container (not
the app container). Init containers do not count toward pod readiness.

---

## Worked Example — estate-scanner values.yaml

The estate-scanner service (scans Google Drive/S3, publishes `DocumentDiscovered` events):

```yaml
# charts/estate-scanner/values.yaml
replicaCount: 2
workloadType: Deployment          # stateless microservice — the common case

image:
  repository: ghcr.io/acme/data-estate/estate-scanner
  # digest: — no default; schema-required, supplied per environment by cd-pipeline

service:
  port: 8080
  type: ClusterIP

containerSecurityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi

terminationGracePeriodSeconds: 30  # > Go server's 25s drain (go-service-skeleton)

podAnnotations:
  linkerd.io/inject: enabled        # Service Mesh mTLS (kubernetes-manifest)

env:
  configMapName: estate-scanner-env # per-env config (environment-config)

autoscaling:
  enabled: false

initContainers: []                  # populated per-environment when DB wait is needed

ingress:
  enabled: false
```

Per-tenant values (`deploy/clusters/tenants/tenant-acme/estate-scanner-values.yaml`):

```yaml
tenant:
  id: acme
replicaCount: 3
ingress:
  enabled: true
  host: acme.app.example.com
```

The tenant values file adds only what differs — no template fields, no chart duplication.

---

## StatefulSet Example — Redpanda Broker chart

When `workloadType: StatefulSet` and `volumeClaimTemplates` are provided:

```yaml
# charts/redpanda-broker/values.yaml
workloadType: StatefulSet
replicaCount: 3

volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

The rendered `StatefulSet` includes `spec.serviceName` pointing at the headless service
(ClusterIP: None) so each pod gets a stable DNS entry:
`redpanda-broker-0.redpanda-broker-headless.<namespace>.svc.cluster.local`.

---

## DaemonSet Example — OTel Collector agent

```yaml
# charts/otel-collector/values.yaml
workloadType: DaemonSet
# replicaCount: ignored for DaemonSet — Kubernetes manages one pod per node

image:
  repository: ghcr.io/acme/platform/otel-collector
  # digest: — required

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi
```

The DaemonSet template adds `tolerations` for control-plane nodes automatically — the OTel
Collector must run everywhere. Do not use a `Deployment` with `replicas: 10` for this purpose;
a `Deployment` cannot guarantee one-pod-per-node.

---

## CI Pipeline YAML — Full Annotated

```yaml
# .github/workflows/chart-ci.yaml
name: Helm Chart CI

on:
  pull_request:
    paths:
      - 'charts/**'

jobs:
  chart-ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: |
          helm version
          curl -sSLo kubeconform.tar.gz \
            https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
          tar xf kubeconform.tar.gz && sudo mv kubeconform /usr/local/bin/

      - name: Lint (strict)
        run: helm lint charts/estate-scanner --strict
        # --strict promotes warnings to errors — catches undocumented values keys,
        # missing required metadata, and icon/home URL lint warnings.

      - name: Template + schema validation
        run: |
          helm template estate-scanner charts/estate-scanner \
            -f charts/estate-scanner/test/values-ci.yaml \
            | kubeconform -strict -summary -kubernetes-version 1.29.0
        # kubeconform validates all rendered objects against the Kubernetes 1.29 OpenAPI schema.
        # -strict rejects unknown fields (catches API deprecations before cluster install).

      - name: Create kind cluster
        uses: helm/kind-action@v1
        with:
          cluster_name: chart-test
          wait: 120s

      - name: Install chart into kind
        run: |
          helm install estate-scanner charts/estate-scanner \
            -f charts/estate-scanner/test/values-ci.yaml \
            --wait --timeout 180s
          kubectl rollout status deployment/estate-scanner --timeout=120s

      - name: Negative test — mutable tag must be rejected
        run: |
          ! helm template estate-scanner charts/estate-scanner \
            --set image.tag=latest
        # The schema's "tag": { "not": {} } must cause helm template to exit non-zero.
        # If this step succeeds (helm exits 0), the schema is not enforcing the tag ban.

      - name: Negative test — missing required image.digest must fail
        run: |
          ! helm template estate-scanner charts/estate-scanner \
            --set image.repository=ghcr.io/acme/test
        # image.digest is required with no default — omitting it must fail schema validation.
```

---

## test/values-ci.yaml

Minimal valid values for CI — supplies the schema-required `image.digest` and `resources`:

```yaml
# charts/estate-scanner/test/values-ci.yaml
image:
  repository: ghcr.io/acme/data-estate/estate-scanner
  digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi

env:
  configMapName: estate-scanner-env
```

This file is committed alongside the chart. It is the chart's test fixture — the red-green pair
for every template change. It must supply every schema-required field with a syntactically valid
value even if semantically fake (the digest above is a placeholder — CI does not need a pullable image).
