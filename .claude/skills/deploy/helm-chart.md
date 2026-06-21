# Skill: deploy/helm-chart

## Purpose
Produce a Helm Chart for one service — the Kubernetes manifest templates and values files that define how the service is deployed across environments. One chart per bounded context service. Environment differences live entirely in `values-{env}.yaml` files.

## Inputs
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/design/platform/observability-design.md` (SLOs → PDB config)
- `artifacts/design/security/security-architecture.md` (mTLS, network policy)
- `artifacts/deploy/iac/{service}/` (ESO secret config)
- **Argument required:** service name

## Output
**File:** `artifacts/deploy/helm/{service-name}/` (directory with chart files)
**Registers in manifest:** yes

## Helm Chart Rules (enforced)
- Image tag is always a variable (`{{ .Values.image.tag }}`) — never hardcoded.
- Secrets are never in values.yaml — use ExternalSecret resources referencing Vault.
- `securityContext` is set on all containers: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`.
- `resources.requests` and `resources.limits` are required on all containers.
- `readinessProbe` and `livenessProbe` are required.
- `PodDisruptionBudget` is required for services with SLOs.
- `NetworkPolicy` default-deny with explicit ingress/egress rules.

## Artifact Template

```yaml
# artifacts/deploy/helm/{service-name}/Chart.yaml
apiVersion: v2
name: {service-name}
description: "{Service Display Name} — {product_name}"
type: application
version: 0.1.0
appVersion: "1.0.0"
```

```yaml
# artifacts/deploy/helm/{service-name}/values.yaml
# Default values — overridden by values-{env}.yaml
# DO NOT put secrets here; use ExternalSecret resources

replicaCount: 2

image:
  repository: ghcr.io/{org}/{product-codename}-{service-name}
  pullPolicy: IfNotPresent
  tag: ""  # Set by CD pipeline via --set image.tag=$SHA

serviceAccount:
  create: true
  annotations: {}  # Add IAM role annotation for cloud providers

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: false  # Internal services; exposed via API Gateway only

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1  # Always keep at least 1 pod running during rolling update

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]

probes:
  readiness:
    path: /api/v1/health/ready
    port: 8080
    initialDelaySeconds: 10
    periodSeconds: 10
  liveness:
    path: /api/v1/health/live
    port: 8080
    initialDelaySeconds: 30
    periodSeconds: 30

env:
  PORT: "8080"
  LOG_LEVEL: "info"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
  # DB_URL and other secrets are injected by ExternalSecret (not here)

nodeSelector: {}
tolerations: []
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values: ["{service-name}"]
          topologyKey: kubernetes.io/hostname
```

```yaml
# artifacts/deploy/helm/{service-name}/values-production.yaml
replicaCount: 3
image:
  tag: ""  # Overwritten by CD pipeline
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
autoscaling:
  minReplicas: 3
  maxReplicas: 20
```

```yaml
# artifacts/deploy/helm/{service-name}/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "{service-name}.fullname" . }}
  labels: {{- include "{service-name}.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: {{- include "{service-name}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels: {{- include "{service-name}.selectorLabels" . | nindent 8 }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: {{ include "{service-name}.serviceAccountName" . }}
      securityContext: {{- toYaml .Values.securityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          envFrom:
            - secretRef:
                name: {{ include "{service-name}.fullname" . }}-secrets
                # Populated by ExternalSecret — not created manually
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: {{ .Values.probes.readiness.port }}
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: {{ .Values.probes.liveness.port }}
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
          resources: {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp  # readOnlyRootFilesystem requires writable /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

```yaml
# artifacts/deploy/helm/{service-name}/templates/external-secret.yaml
# ESO ExternalSecret — pulls from Vault; creates Kubernetes Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "{service-name}.fullname" . }}-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: {{ include "{service-name}.fullname" . }}-secrets
    creationPolicy: Owner
  data:
    - secretKey: DB_URL
      remoteRef:
        key: {product-codename}/{service-name}/database
        property: connection_string
    - secretKey: REDPANDA_BROKERS
      remoteRef:
        key: {product-codename}/platform/redpanda
        property: brokers
```

## Quality Checks
- [ ] Image tag is `{{ .Values.image.tag }}` — not hardcoded
- [ ] No secrets in values.yaml — ExternalSecret template is present
- [ ] securityContext: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`
- [ ] resources.requests and resources.limits are set
- [ ] readinessProbe and livenessProbe are configured
- [ ] PodDisruptionBudget template exists
- [ ] NetworkPolicy template exists (default-deny)
- [ ] podAntiAffinity spreads pods across nodes
- [ ] Prometheus scrape annotations on pod template
