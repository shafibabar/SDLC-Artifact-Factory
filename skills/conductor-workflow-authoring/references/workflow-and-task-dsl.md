# Workflow and Task DSL — Worked DataAsset Onboarding Flow

A complete, grounded Conductor authoring example for this repo's data-estate /
compliance product. The flow onboards a newly-discovered **DataAsset** (a file
in Google Drive, S3, or a parsed PDF/DOCX/XLSX): it registers the asset, runs
classification and PII scanning **in parallel**, branches on the classification
result, invokes a shared enrichment **sub-workflow**, waits for a compliance
officer's approval when the asset is sensitive, and finally publishes the asset
to the catalog. Compensation is a dedicated `failureWorkflow`.

All JSON below is Conductor's stable public metadata model. Names are this
example's; task types and policy fields are Conductor's own.

---

## 1. Task Definitions (policy — registered once)

Task definitions carry retry/timeout policy and are registered independently of
any workflow via `POST /api/metadata/taskdefs` (the body is a JSON **array**).

```json
[
  {
    "name": "register_data_asset",
    "description": "Persist the DataAsset row in the owning context (pgx).",
    "retryCount": 3,
    "retryLogic": "EXPONENTIAL_BACKOFF",
    "retryDelaySeconds": 5,
    "timeoutSeconds": 60,
    "responseTimeoutSeconds": 30,
    "timeoutPolicy": "TIME_OUT_WF",
    "ownerEmail": "backend-engineer@example.com"
  },
  {
    "name": "classify_data_asset",
    "description": "Classify the asset (public/internal/confidential/restricted).",
    "retryCount": 2,
    "retryLogic": "FIXED",
    "retryDelaySeconds": 10,
    "timeoutSeconds": 120,
    "responseTimeoutSeconds": 45,
    "timeoutPolicy": "RETRY"
  },
  {
    "name": "scan_pii",
    "description": "Scan the asset content for PII / regulated data.",
    "retryCount": 2,
    "retryLogic": "EXPONENTIAL_BACKOFF",
    "retryDelaySeconds": 10,
    "timeoutSeconds": 300,
    "responseTimeoutSeconds": 60,
    "timeoutPolicy": "RETRY"
  },
  {
    "name": "publish_to_catalog",
    "description": "Retriable post-pivot step — must eventually succeed.",
    "retryCount": 10,
    "retryLogic": "EXPONENTIAL_BACKOFF",
    "retryDelaySeconds": 15,
    "timeoutSeconds": 90,
    "responseTimeoutSeconds": 45,
    "timeoutPolicy": "RETRY"
  },
  {
    "name": "deregister_data_asset",
    "description": "Compensating undo for register_data_asset.",
    "retryCount": 5,
    "retryLogic": "FIXED",
    "retryDelaySeconds": 10,
    "timeoutSeconds": 60,
    "responseTimeoutSeconds": 30,
    "timeoutPolicy": "RETRY"
  }
]
```

`responseTimeoutSeconds` is the heartbeat budget: if a worker holds the task
that long without calling back, Conductor re-queues it for another poller —
which is exactly why every worker must be idempotent on `taskId`.

---

## 2. Workflow Definition (the DAG)

Registered via `POST /api/metadata/workflow`. Step classes, from
`event-driven-patterns`: `register` is **compensatable**, `publish_to_catalog`
is the **pivot** (once the asset is in the catalog the flow runs forward), so
everything after the pivot is **retriable** and everything before it needs a
compensating undo in the `failureWorkflow`.

```json
{
  "name": "data_asset_onboarding",
  "description": "Onboard a discovered DataAsset into the compliance catalog.",
  "version": 1,
  "schemaVersion": 2,
  "inputParameters": ["assetId", "tenantId", "source"],
  "failureWorkflow": "data_asset_onboarding_compensation",
  "outputParameters": {
    "catalogId": "${publish_ref.output.catalogId}",
    "classification": "${classify_ref.output.level}"
  },
  "tasks": [
    {
      "name": "register_data_asset",
      "taskReferenceName": "register_ref",
      "type": "SIMPLE",
      "inputParameters": {
        "assetId": "${workflow.input.assetId}",
        "tenantId": "${workflow.input.tenantId}",
        "source": "${workflow.input.source}"
      }
    },
    {
      "name": "fanout_analysis",
      "taskReferenceName": "fanout_ref",
      "type": "FORK_JOIN",
      "forkTasks": [
        [
          {
            "name": "classify_data_asset",
            "taskReferenceName": "classify_ref",
            "type": "SIMPLE",
            "inputParameters": { "assetId": "${workflow.input.assetId}" }
          }
        ],
        [
          {
            "name": "scan_pii",
            "taskReferenceName": "scan_ref",
            "type": "SIMPLE",
            "inputParameters": { "assetId": "${workflow.input.assetId}" }
          }
        ]
      ]
    },
    {
      "name": "analysis_join",
      "taskReferenceName": "join_ref",
      "type": "JOIN",
      "joinOn": ["classify_ref", "scan_ref"]
    },
    {
      "name": "route_on_sensitivity",
      "taskReferenceName": "route_ref",
      "type": "SWITCH",
      "evaluatorType": "value-param",
      "expression": "sensitivity",
      "inputParameters": { "sensitivity": "${classify_ref.output.level}" },
      "decisionCases": {
        "restricted": [
          {
            "name": "await_officer_approval",
            "taskReferenceName": "approval_ref",
            "type": "WAIT",
            "inputParameters": { "duration": "72h" }
          }
        ]
      },
      "defaultCase": []
    },
    {
      "name": "enrich_metadata",
      "taskReferenceName": "enrich_ref",
      "type": "SUB_WORKFLOW",
      "subWorkflowParam": {
        "name": "data_asset_enrichment",
        "version": 1
      },
      "inputParameters": {
        "assetId": "${workflow.input.assetId}",
        "piiFindings": "${scan_ref.output.findings}"
      }
    },
    {
      "name": "publish_to_catalog",
      "taskReferenceName": "publish_ref",
      "type": "SIMPLE",
      "inputParameters": {
        "assetId": "${workflow.input.assetId}",
        "classification": "${classify_ref.output.level}"
      }
    }
  ]
}
```

### DAG walkthrough

1. **`register_ref` (SIMPLE, compensatable)** — writes the DataAsset row. Its
   undo is `deregister_data_asset` in the compensation workflow.
2. **`fanout_ref` (FORK_JOIN)** — classification and PII scan run in parallel
   because neither depends on the other; **`join_ref` (JOIN)** with
   `joinOn: [classify_ref, scan_ref]` is the barrier that waits for both.
3. **`route_ref` (SWITCH)** — `value-param` evaluator on `${classify_ref.output.level}`;
   only the `restricted` case inserts the human-approval WAIT. `defaultCase: []`
   means non-restricted assets skip approval entirely.
4. **`approval_ref` (WAIT)** — blocks up to `72h` for the compliance officer;
   Conductor completes it on an external signal (`POST /api/tasks/{taskId}`) or
   when the duration elapses.
5. **`enrich_ref` (SUB_WORKFLOW)** — composes the reusable `data_asset_enrichment`
   child workflow; its own tasks are hidden behind one node here.
6. **`publish_ref` (SIMPLE, pivot)** — the point of no return; retriable, high
   `retryCount`, never compensated.

---

## 3. The failureWorkflow — Compensation as JSON

When `data_asset_onboarding` fails anywhere before the pivot, Conductor launches
`data_asset_onboarding_compensation` with the failed workflow's input. It runs
the undo tasks for whatever compensatable steps had committed, **in reverse
order**. Because only `register_ref` is compensatable in this flow, the
compensation is a single undo — but the pattern generalizes to one undo task per
compensatable step, reversed.

```json
{
  "name": "data_asset_onboarding_compensation",
  "description": "Reverse compensatable steps of a failed onboarding Saga.",
  "version": 1,
  "schemaVersion": 2,
  "inputParameters": ["assetId", "tenantId"],
  "tasks": [
    {
      "name": "deregister_data_asset",
      "taskReferenceName": "deregister_ref",
      "type": "SIMPLE",
      "inputParameters": {
        "assetId": "${workflow.input.assetId}",
        "tenantId": "${workflow.input.tenantId}"
      }
    }
  ]
}
```

The compensation is itself a reviewable artifact: a PM reading these two JSON
documents can see both what the flow does and exactly what it undoes on failure,
without reading a line of Go. That reviewability is the reason compensation lives
in a `failureWorkflow` and never in a worker's catch block.

---

## 4. Registering the Definitions (run via the Bash tool)

Task definitions first (they must exist before a workflow references them), then
the workflows. `$CONDUCTOR` is the tenant-scoped Conductor server inside the
tenant's Kubernetes namespace.

```bash
# 1. Register task definitions (array body)
curl -sf -X POST "$CONDUCTOR/api/metadata/taskdefs" \
  -H 'Content-Type: application/json' \
  --data @taskdefs.json

# 2. Register the main workflow, then the compensation workflow
curl -sf -X POST "$CONDUCTOR/api/metadata/workflow" \
  -H 'Content-Type: application/json' \
  --data @data_asset_onboarding.json

curl -sf -X POST "$CONDUCTOR/api/metadata/workflow" \
  -H 'Content-Type: application/json' \
  --data @data_asset_onboarding_compensation.json

# 3. Start a run
curl -sf -X POST "$CONDUCTOR/api/workflow/data_asset_onboarding" \
  -H 'Content-Type: application/json' \
  -d '{"assetId":"asset-9f2","tenantId":"tenant-acme","source":"gdrive"}'
```

Registering a `POST /api/metadata/workflow` for a `name` that already exists at
that `version` overwrites it; bump `version` for an incompatible DAG change so
in-flight runs finish on the definition they started under. Validate a DAG
before wiring workers by registering it and starting one run with a synthetic
input — Conductor rejects a workflow that references an unregistered task name
or a `joinOn` reference that no forked branch produces.
