# Schema Registry Reference

This file is self-contained. It covers:
1. Why a schema registry is required
2. Apicurio Registry — this platform's choice and its setup
3. Schema registration flow (how a schema goes from code to the registry)
4. Compatibility mode configuration
5. Go client pattern for schema registration and validation
6. Flux GitOps reconciliation of schema CRDs

---

## Why a Schema Registry Is Required

An event schema is a published contract. Once a consumer reads events of a
given type, the producer cannot change the wire format unilaterally — the
consumer will break silently or loudly depending on whether it validates. A
schema registry:

1. **Is the single source of truth** for the wire contract of every event type.
2. **Enforces compatibility rules** before a new schema version is accepted —
   a producer that tries to register a breaking change is rejected at registration
   time, in CI, before the code ever reaches production.
3. **Allows consumers to validate** incoming events against the registered schema
   at startup or at processing time, rather than relying on the producer to get
   the format right.

Without a registry, compatibility discipline depends entirely on code review.
Code review is not a mechanical gate; the registry is.

---

## Apicurio Registry — Platform Choice

This platform uses **Apicurio Registry** (Apache 2.0, Red Hat open source) as
the schema registry, deployed as a Kubernetes workload in the `platform`
namespace.

**Why Apicurio over Confluent Schema Registry:**
- Apache 2.0 license — no usage restrictions or licensing costs
- Supports JSON Schema, Avro, and Protobuf in a single registry (this platform
  uses JSON Schema; the door is open to Avro per-topic without a registry swap)
- REST API is compatible with Confluent's API — most client libraries work
  with both registries; switching is a configuration change, not a code change
- Native OpenAPI artifact storage for REST contract types alongside event schemas

**Deployment:**

```yaml
# platform/helm/apicurio/values.yaml
apicurio-registry:
  image:
    tag: "2.5.0.Final"
  env:
    QUARKUS_DATASOURCE_DB_KIND: "postgresql"
    QUARKUS_DATASOURCE_USERNAME: "apicurio"
    QUARKUS_DATASOURCE_JDBC_URL: "jdbc:postgresql://apicurio-db:5432/registry"
  replicas: 2
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

Internal endpoint: `http://apicurio-registry.platform.svc.cluster.local:8080`

---

## Schema Registration Flow

A schema is registered **before the first producer deploy that emits that event
type**. Registration is part of the CI pipeline, not a post-deploy operational
task.

### Subjects and Groups

Apicurio uses `groups` and `artifactId` to organise schemas:
- **Group:** `events` — all Domain and Integration Event schemas share this
  group.
- **ArtifactId:** the event type string, e.g.
  `com.sdlc-factory.data-asset-management.data-asset.classified`
- **Version:** tracked internally by Apicurio; the producer never manages the
  version number directly.

### Registration in CI

```yaml
# .github/workflows/schema-check.yml
- name: Register and validate event schemas
  env:
    APICURIO_URL: ${{ secrets.APICURIO_REGISTRY_URL }}
  run: |
    for schema in $(git diff --name-only origin/main HEAD | grep '^schemas/events/.*\.json$'); do
      artifact_id=$(basename "$schema" .json)
      # Attempt registration — registry rejects incompatible schemas
      curl -sf -X POST \
        "${APICURIO_URL}/apis/registry/v2/groups/events/artifacts" \
        -H "X-Registry-ArtifactId: ${artifact_id}" \
        -H "X-Registry-IfExists: UPDATE" \
        -H "Content-Type: application/json" \
        --data-binary "@${schema}" || {
          echo "Schema registration failed for $artifact_id — check compatibility"
          exit 1
        }
    done
```

`X-Registry-IfExists: UPDATE` tells Apicurio to create the artifact on first
registration and add a new version on subsequent registrations. If the new
version violates the compatibility rule for the subject, Apicurio returns
`HTTP 409 Conflict` and the pipeline fails.

---

## Compatibility Mode Configuration

Every event subject is registered with `BACKWARD` compatibility mode as the
default. BACKWARD means: a consumer running the *new* schema can read events
encoded with the *old* schema.

Under BACKWARD + JSON Schema:
- Adding an optional field is backward compatible (old events simply lack the
  field; the new schema marks it optional).
- Removing a field is **not** backward compatible: old events carry the field;
  if the new schema sets `additionalProperties: false`, the old event fails
  validation.
- Renaming is not backward compatible.

**Set compatibility mode on subject creation:**

```bash
# Set BACKWARD mode on a new subject (idempotent; run in the same pipeline job
# as schema registration)
curl -sf -X PUT \
  "${APICURIO_URL}/apis/registry/v2/groups/events/artifacts/\
com.sdlc-factory.data-asset-management.data-asset.classified/rules/COMPATIBILITY" \
  -H "Content-Type: application/json" \
  -d '{"type":"COMPATIBILITY","config":"BACKWARD"}'
```

**Compatibility mode reference:**

| Mode | A new consumer can read old events | An old consumer can read new events |
|---|---|---|
| BACKWARD (default) | Yes | Not guaranteed |
| FORWARD | Not guaranteed | Yes |
| FULL | Yes | Yes |
| NONE | — | — (never use on published events) |

Choose FORWARD when producers are deployed before consumers (producers emit the
new format while consumers still expect the old one). Choose FULL for events
shared across many independent consumers with no controlled deployment order.

---

## Go Client Pattern

The Go event publisher validates the event's data payload against the registry
schema before writing to the outbox. This check runs in the same transaction
as the Aggregate save — if validation fails, the entire operation rolls back.

```go
package registry

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
)

// Validator fetches the registered schema and validates a JSON payload.
type Validator struct {
    baseURL    string
    httpClient *http.Client
}

func NewValidator(baseURL string) *Validator {
    return &Validator{baseURL: baseURL, httpClient: &http.Client{}}
}

// Validate checks payload against the latest registered schema for artifactID.
// Returns nil if the payload is valid; an error describing the violation otherwise.
func (v *Validator) Validate(artifactID string, payload json.RawMessage) error {
    url := fmt.Sprintf(
        "%s/apis/registry/v2/groups/events/artifacts/%s/test",
        v.baseURL, artifactID,
    )
    resp, err := v.httpClient.Post(url, "application/json", bytes.NewReader(payload))
    if err != nil {
        return fmt.Errorf("registry validation request failed: %w", err)
    }
    defer resp.Body.Close()
    if resp.StatusCode == http.StatusOK {
        return nil
    }
    if resp.StatusCode == http.StatusConflict {
        return fmt.Errorf("payload violates registered schema for %s", artifactID)
    }
    return fmt.Errorf("registry validation returned unexpected status %d", resp.StatusCode)
}
```

The `/test` endpoint on Apicurio performs schema validation without storing the
artifact — it returns `200 OK` if the payload is valid against the latest
registered version, `409 Conflict` if not.

**Integration in the application service:**

```go
func (svc *ClassificationService) Classify(ctx context.Context, cmd ClassifyCmd) error {
    // ... load aggregate, run domain method ...

    evt := newDataAssetClassifiedEvent(asset)
    payload, _ := json.Marshal(evt.Data)

    const artifactID = "com.sdlc-factory.data-asset-management.data-asset.classified"
    if err := svc.schemaValidator.Validate(artifactID, payload); err != nil {
        return fmt.Errorf("event schema violation: %w", err)
    }

    return svc.repo.Save(ctx, asset, []cloudevents.Event{evt})
}
```

---

## Flux GitOps Reconciliation

Schema files live in the environment repository under `schemas/events/`. Flux
reconciles them to Apicurio via a `Kustomization` that runs the registration
job after each push to the environment repo.

```yaml
# environment-repo/flux/schemas/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: event-schemas
  namespace: flux-system
spec:
  interval: 5m
  path: ./schemas/events
  prune: false   # Never prune: a schema in the registry is permanent history
  sourceRef:
    kind: GitRepository
    name: environment-repo
  postBuild:
    substitute:
      APICURIO_URL: "http://apicurio-registry.platform.svc.cluster.local:8080"
```

The `postBuild` step runs a `Job` that iterates over every JSON file in
`schemas/events/` and calls the registration API. `prune: false` is critical:
Flux must never delete a registered schema even if the corresponding file is
removed from the environment repo — registered schemas are permanent historical
records.

**Schema file naming convention:**

```
schemas/events/
  com.sdlc-factory.data-asset-management.data-asset.classified.json
  com.sdlc-factory.data-asset-management.storage-source.activated.json
  com.sdlc-factory.compliance-intelligence.compliance-gap.detected.json
```

The file name is the event type string verbatim, with `.json` extension. This
makes the CI diff check (`git diff --name-only ... | grep '^schemas/events/'`)
directly yield the artifact ID with a single `basename` call.
