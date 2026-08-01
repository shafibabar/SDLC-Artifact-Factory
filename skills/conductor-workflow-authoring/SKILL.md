---
name: conductor-workflow-authoring
description: >
  Teaches the backend-engineer to author Netflix Conductor workflows — the
  workflow-as-JSON-DAG model, the task-type taxonomy (SIMPLE, FORK_JOIN/JOIN,
  DECISION/SWITCH, SUB_WORKFLOW, WAIT, HTTP) and which one fits each Saga step
  class (compensatable/pivot/retriable), external task workers written as Go
  services that poll and post results (business logic stays in the service,
  flow state stays in Conductor), and retry/timeout/failureWorkflow policy so
  compensation and resilience are reviewable JSON instead of buried code. Also
  covers idempotent task workers keyed on taskId, input/output wiring between
  tasks, and running workers alongside chi HTTP services under per-tenant
  isolation. Full worked workflow + task-definition JSON for a DataAsset
  onboarding flow (FORK_JOIN, DECISION, SUB_WORKFLOW, failureWorkflow
  compensation) in references/workflow-and-task-dsl.md; the complete Go
  external-worker skeleton (poll, execute, update, error, idempotency, health,
  metrics) in references/go-task-workers.md. Used during Implement once
  workflow-orchestration selected a central orchestrator over choreography.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, conductor, workflow, orchestration, task-worker, go]
produces: conductor-workflow-definition
domain: backend
status: stable
related: [workflow-orchestration, go-service-skeleton, event-driven-patterns, integration-design]
tools: [Bash]
---

# Conductor Workflow Authoring

## Purpose

When `workflow-orchestration` has decided this flow warrants a central orchestrator — the deliberate exception to this repo's choreography+Saga default, invoked for complex, branching, long-running, visibility-critical flows — Netflix Conductor is the open-source engine that holds the flow state. This skill is the *authoring target*: how to express an orchestration Saga as a Conductor workflow definition (a JSON DAG), how to map each Saga step to a task type, how to keep business logic in Go services while Conductor holds only flow state, and how to make retry, timeout, and compensation reviewable JSON rather than buried code.

This skill is authoring depth, not selection. The choice to orchestrate at all — and whether a hand-rolled Go persisted-state-machine coordinator is cheaper than pulling in Conductor — belongs to `workflow-orchestration` and `event-driven-patterns`. Arrive here only once that decision is made.

---

## The Workflow-as-JSON-DAG Model

A Conductor **workflow definition** is a named, versioned JSON document: a `name`, a `version` (integer), an `inputParameters` list, a `tasks` array (the DAG), and an `outputParameters` map. Each entry in `tasks` is a **task instance** — `name` (the registered task definition), `taskReferenceName` (unique within this workflow, how other tasks refer to its output), `type`, and `inputParameters` wiring values in from the workflow input or from an earlier task's output via `${ref.output.field}` / `${workflow.input.field}` expressions.

Two documents, two registration calls: **task definitions** (`POST /api/metadata/taskdefs`) carry the per-task policy — retry, timeout, rate limits — and are registered once; **workflow definitions** (`POST /api/metadata/workflow`) carry the DAG and reference tasks by name. Start a run with `POST /api/workflow/{name}` and an input body. The DAG, not code, is the artifact Shafi reviews: it shows the whole flow, its branches, and its failure path on one screen.

The workflow definition is a versioned artifact — bump `version` for an incompatible change so in-flight runs finish on the definition they started under. Full worked definition: `references/workflow-and-task-dsl.md`.

---

## Task-Type Taxonomy — When Each Fits a Saga Step

| Task type | What it does | Fits which Saga step |
|---|---|---|
| **SIMPLE** | Work performed by an external task worker that polls, executes, and posts the result. | Any step whose logic lives in one of your Go services — the default step. |
| **FORK_JOIN** + **JOIN** | Static parallel fan-out; `JOIN` is the barrier that waits on the forked branches. | Independent steps that can run concurrently (e.g. classify + scan a DataAsset at once). |
| **FORK_JOIN_DYNAMIC** | Fan-out over a runtime-sized list. | Fan-out whose width is data-dependent (one branch per discovered file). |
| **DECISION** / **SWITCH** | Branch on an evaluated expression; `SWITCH` (value/javascript evaluators) is the current form, `DECISION` the legacy alias. | A pivot or routing choice — run this branch vs. that one on a classification result. |
| **SUB_WORKFLOW** | Invoke a child workflow definition as one task. | A reusable sub-Saga (a compensation flow, a shared enrichment sequence). |
| **WAIT** | Block until an external signal (`SIGNAL`) or a duration/timestamp. | An async human-approval or external-event step — the point the Saga pauses. |
| **HTTP** | Call a REST endpoint inline from the Conductor server; no worker needed. | A thin call to an external/third-party API with no business logic of your own. |

Prefer **SIMPLE + a Go worker** over **HTTP** whenever the step carries any of your own logic, error handling, or idempotency — HTTP is only for a stateless inline call. Map the Saga's **pivot** step to the task after which no `failureWorkflow` compensation is wired; **retriable** steps (post-pivot) get generous `retryCount`; **compensatable** steps (pre-pivot) each need an undo task in the compensation `failureWorkflow`.

---

## The External-Worker Split — Logic in the Service, Flow in Conductor

A **SIMPLE** task is executed by an **external task worker**: a loop inside (or alongside) your Go chi service that polls Conductor for work of a given task type, runs the domain logic, and posts the result back. The division is strict and is the whole point of using Conductor:

- **In Conductor:** the DAG, the current state of each run, retry/timeout counters, branch decisions, the failure path. Nothing domain-specific.
- **In your Go service:** all business logic, all database writes (via `pgx`), all validation, all calls to Redpanda or other services. The worker is a thin adapter over the same domain functions your chi handlers call.

A worker is not a separate microservice — it runs in the same process as the owning bounded context's chi service, sharing its pool, config, telemetry, and per-tenant deployment (one Conductor + workers per tenant Kubernetes namespace, never a shared control plane spanning tenants). Full Go worker skeleton — poll loop, execute, `updateTask`, error reporting, graceful shutdown alongside `http.Server`: `references/go-task-workers.md`.

---

## Idempotent Task Workers

Conductor redelivers: a task can be polled again after a `responseTimeoutSeconds` lapse, a worker crash, or a retry. Redpanda redelivers too. Every worker **must be idempotent**, keyed on the Conductor **`taskId`** (unique per task instance) — persist a processed-key row (or dedup on `taskId` in the write's `ON CONFLICT`) so re-execution is a no-op that re-posts the prior result rather than doing the work twice. Do not key idempotency on the workflow input alone — two legitimate retries share it. Worked idempotency pattern: `references/go-task-workers.md`.

---

## Retry, Timeout, and Compensation as Reviewable JSON

These live in the **task definition** and the **workflow definition**, never in worker code:

- **`retryCount`** — how many times Conductor re-attempts a failed task before it fails for good.
- **`retryLogic`** — `FIXED` or `EXPONENTIAL_BACKOFF` (with `retryDelaySeconds` as the base).
- **`timeoutSeconds`** — max wall time for the task from schedule to completion; **`responseTimeoutSeconds`** — max time a worker may hold a task without heartbeating before it is re-queued.
- **`timeoutPolicy`** — `RETRY`, `TIME_OUT_WF` (fail the whole workflow), or `ALERT_ONLY`.
- **`failureWorkflow`** — on the *workflow* definition: the name of a compensation workflow Conductor launches when this workflow fails. This is where **Saga compensation becomes an explicit, reviewable artifact** — the compensation workflow runs the undo tasks (reverse order) for whatever compensatable steps had committed. A Saga with compensatable steps and no `failureWorkflow` is an incomplete design — fail it in review.

Model compensation as its own workflow (invoked via `failureWorkflow`, or composed as a `SUB_WORKFLOW`), not as try/catch inside a worker — that keeps "what happens on failure" on the same reviewable page as the happy path. Full compensation example: `references/workflow-and-task-dsl.md`.

---

## Authoring Procedure

1. Confirm with `workflow-orchestration` that orchestration (not choreography) and Conductor (not a hand-rolled Go coordinator) are the chosen approach for this flow.
2. Classify every Saga step (compensatable / pivot / retriable) — this is `event-driven-patterns`' discipline, done before any JSON.
3. Map each step to a task type using the taxonomy table; pick FORK_JOIN only for genuinely independent steps.
4. Write the task definitions (policy) and the workflow definition (DAG) as JSON; wire inputs/outputs with `${...}` expressions.
5. Write the `failureWorkflow` compensation workflow — one undo task per compensatable step, reverse order.
6. Implement each SIMPLE task's Go worker over the existing domain functions; make it idempotent on `taskId`.
7. Register definitions (`metadata/taskdefs`, `metadata/workflow`) and validate the DAG with the repo's Conductor client before wiring workers — see `references/workflow-and-task-dsl.md` for the `curl`/CLI registration calls run via the Bash tool.

---

## Quality Criteria

- Every SIMPLE task has an owning Go worker; every worker is idempotent on `taskId`.
- No business logic in HTTP tasks or in the workflow JSON — only flow and wiring.
- Every compensatable step has a matching undo task in the `failureWorkflow`; a pivot is identified.
- Retry/timeout/`timeoutPolicy` set per task definition — no unbounded task, no silent infinite retry.
- Workflow definition is versioned; the DAG is readable top-to-bottom by a non-programmer.
- Conductor and its workers deploy inside the tenant boundary, never as a shared cross-tenant control plane.

---

## References

- `references/workflow-and-task-dsl.md` — worked DataAsset-onboarding workflow + task-definition JSON using FORK_JOIN/JOIN, SWITCH, SUB_WORKFLOW, WAIT; input/output wiring; the `failureWorkflow` compensation workflow; and the registration `curl` calls.
- `references/go-task-workers.md` — the Go external task worker: poll loop, execute, `updateTask`/`updateTaskByRefName`, error reporting, `taskId` idempotency, health/metrics endpoints, and running workers alongside a chi `http.Server` with shared graceful shutdown.
