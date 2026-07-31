# Orchestration Saga Design — The Persisted Process Manager

Reference for `workflow-orchestration`. Covers the process-manager state-machine model, the three step classes with their compensating transactions, a fully worked DataAsset onboarding Saga, a Go coordinator sketch on `pgx` + Transactional Outbox, and the written rule for when orchestration beats choreography. Grounded in Richardson (*Microservices Patterns*, Ch. 4) and Hohpe's Process Manager pattern, mapped onto this repo's Go + Redpanda + per-tenant-physical-isolation stack.

---

## 1. The orchestrator is a state machine, not a script

An orchestration-based Saga replaces choreography's scattered event reactions with a single **Saga orchestrator** — a persistent state machine that Hohpe named the **Process Manager**. It holds the flow state that choreography smears across participants. It has exactly three jobs and one prohibition:

- **Holds state** — the current step of the flow, per Saga instance, keyed by `correlationId`.
- **Dispatches Commands** — on entering a state, it sends one Command message to the participant that owns that step's local transaction.
- **Consumes replies** — a reply message (success or failure) drives the transition to the next state (or into the compensation path).
- **Prohibition: it does no business work.** It never reads a participant's database, never applies a domain rule, never enforces an invariant. Those live in the participants. An orchestrator that "just checks one thing itself" degrades into a god service that bypasses the very Bounded Context boundaries the Saga exists to respect.

### Why it must be persisted transactionally

The orchestrator's state transition and the message it emits **must be written in one local transaction** — the Transactional Outbox. If the state row committed but the Command message were lost (or vice versa), a crash would strand the Saga: either a state that never advances, or a duplicate Command. Writing both to the same PostgreSQL transaction (business row + outbox row) makes the pair atomic on one node — no 2PC, no distributed transaction. A relay then publishes the outbox row to Redpanda at-least-once, which is why every participant must be an **idempotent consumer** (dedup on message id).

On restart, the coordinator re-reads its persisted state per open Saga and resumes from the last committed state — it does not replay from the beginning.

---

## 2. The state machine, concretely

A Saga definition is: a set of **states**, a **Command dispatched on entry** to each forward state, and a **transition table** keyed by (current state, reply). Model it as data, not a switch statement buried in a handler.

```
STATE           ON success →        ON failure →         DISPATCHES
------------    --------------      ------------------   -------------------------
STARTED         SCANNING            (n/a)                RegisterDataAsset
SCANNING        CLASSIFYING         COMPENSATING_REG     ScanSource
CLASSIFYING     COMPLIANCE_CHECK    COMPENSATING_SCAN    ClassifyDataAsset
COMPLIANCE_CHK  INDEXING            COMPENSATING_CLASS   RunComplianceCheck   (PIVOT)
INDEXING        COMPLETED           INDEXING (retry)     IndexDataAsset       (retriable)
COMPENSATING_*  <prev COMPENSATING> (alert)              <compensating Command>
COMPLETED       —                   —                    —
FAILED          —                   —                    —
```

Everything left of the pivot has a `COMPENSATING_*` failure edge. Everything at or right of the pivot has **no** backward edge — failure there loops on retry, never on compensation.

---

## 3. The three step classes

Every Saga step is exactly one of three classes. Deciding the classification — specifically, **where the pivot sits** — *is* the act of designing the Saga.

### Compensatable
Runs **before** the pivot. Its local transaction commits and is immediately visible, so it cannot be rolled back — it must be **semantically undone** by a **compensating transaction**. Compensations run in **reverse order** of the forward steps. A compensating transaction is itself a normal local transaction (it can fail and be retried); it never "un-commits" — it applies a new, inverse effect (mark cancelled, release a hold, delete a provisional row).

Rule: **a compensatable step whose compensation is not written is an incomplete design.** Fail it in review.

### Pivot
The **point of no return**. Once the pivot's local transaction commits, the Saga is guaranteed to run **forward** to completion and will never compensate. There is **exactly one** pivot per Saga. Everything before it is compensatable; everything after it is retriable. Choosing the pivot is a business decision: it is the last step at which abandoning the whole operation is still acceptable. Place it at the step that authorizes the irreversible external effect, or the step after which partial completion is preferable to total rollback.

A common special case: the **last compensatable step and the pivot coincide**, or the pivot is a read-only "authorize / confirm" step that commits nothing to undo.

### Retriable
Runs **after** the pivot. Because the Saga cannot go backward past the pivot, a retriable step **must eventually succeed** — it is retried (with exponential backoff + jitter), never compensated. Retriable steps must therefore be designed to be safe to attempt repeatedly (idempotent) and to have no failure mode that is truly permanent within the flow's control (or, if they can permanently fail, that failure is handled forward — e.g. queued for manual repair — not by unwinding the Saga).

---

## 4. Worked example — the DataAsset onboarding Saga

A tenant connects a new source (Google Drive / S3). Onboarding a discovered **DataAsset** spans five Bounded Contexts. This is a 5-step, compensation-bearing, visibility-critical flow — squarely past the choreography threshold — so it is orchestrated.

| # | Step (Command) | Owning context | Class | Compensating transaction |
|---|---|---|---|---|
| 1 | `RegisterDataAsset` — create the DataAsset row in `ONBOARDING_PENDING` | Catalog | Compensatable | `MarkDataAssetAbandoned` — set state `ABANDONED`, release the semantic lock |
| 2 | `ScanSource` — fetch bytes/metadata, store a provisional scan record | Ingestion | Compensatable | `DeleteScanArtifacts` — delete the provisional scan record and any fetched blobs |
| 3 | `ClassifyDataAsset` — run PII/sensitivity classification, attach labels | Classification | Compensatable | `RemoveClassificationLabels` — detach the labels written in step 3 |
| 4 | `RunComplianceCheck` — evaluate SOC 2 / retention policy; **authorize** the asset for the estate | Compliance | **Pivot** | *(none — point of no return)* |
| 5 | `IndexDataAsset` — write the asset into the searchable estate Read Model | Search | Retriable | *(none — retried until success)* |

**Reasoning about the pivot.** Steps 1–3 all produce state that is safe to unwind: an abandoned catalog entry, deleted provisional scan bytes, detached labels — none of these have external, irreversible consequences. Step 4, the **compliance authorization**, is the business point of no return: once the asset is authorized into the tenant's governed data estate, downstream compliance reporting and access-control decisions begin to depend on it; unwinding it after the fact would mean retracting a governance fact other systems have already acted on. So compliance check is the **pivot**. Step 5 (indexing) is therefore **retriable** — if the search projection is briefly unavailable, we retry; we never un-authorize a compliant asset just because its index write lagged.

**Failure walk-through.** Suppose classification (step 3) fails. The orchestrator is in `CLASSIFYING`; the failure reply drives it to `COMPENSATING_SCAN`, which dispatches `DeleteScanArtifacts` (undo step 2), then to `COMPENSATING_REG`, which dispatches `MarkDataAssetAbandoned` (undo step 1, releasing the semantic lock). The DataAsset ends `ABANDONED`, no partial state leaks into the estate. Had the failure instead occurred at indexing (step 5, past the pivot), there is **no** compensation edge — the orchestrator loops `INDEXING → INDEXING` on retry with backoff until the search projection accepts the write.

---

## 5. Go coordinator sketch (`pgx` + Transactional Outbox)

Hand-rolled coordinator — the frugal default before reaching for Conductor. State and the emitted Command are written in **one** `pgx.Tx`.

```go
// saga_instance holds one running Saga's persisted state.
//   saga_id (uuid pk) | correlation_id | state (text) | payload (jsonb) | updated_at
// outbox holds messages to relay to Redpanda (published at-least-once).
//   id (uuid pk) | topic | key | payload (jsonb) | created_at | published_at (nullable)

type Reply struct {
	CorrelationID string
	Step          string // which Command this replies to
	OK            bool
}

// Handle advances one Saga instance on a participant reply. The state
// transition AND the next Command's outbox row commit in a single tx, so a
// crash resumes rather than double-sends or loses the flow.
func (c *Coordinator) Handle(ctx context.Context, r Reply) error {
	tx, err := c.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) // no-op after Commit

	var state string
	var payload []byte
	// Row-lock this Saga instance so concurrent replies serialize.
	err = tx.QueryRow(ctx,
		`SELECT state, payload FROM saga_instance
		   WHERE correlation_id = $1 FOR UPDATE`, r.CorrelationID).
		Scan(&state, &payload)
	if err != nil {
		return err
	}

	next, cmd := c.def.Transition(state, r) // pure fn over the transition table
	if _, err = tx.Exec(ctx,
		`UPDATE saga_instance SET state=$1, updated_at=now()
		   WHERE correlation_id=$2`, next.State, r.CorrelationID); err != nil {
		return err
	}
	if cmd != nil { // may be nil at COMPLETED / FAILED
		if _, err = tx.Exec(ctx,
			`INSERT INTO outbox (id, topic, key, payload, created_at)
			   VALUES ($1,$2,$3,$4, now())`,
			uuid.New(), cmd.Topic, r.CorrelationID, cmd.Payload); err != nil {
			return err
		}
	}
	return tx.Commit(ctx) // state + Command become durable together
}
```

The `Transition` function is a pure lookup over the table in §2 — no I/O, easy to unit-test exhaustively (every (state, reply) pair). A separate relay goroutine `SELECT ... WHERE published_at IS NULL`, produces to Redpanda, and stamps `published_at`. Participants consume their Command topic, do the local transaction, and post a reply — each idempotent on the message id (dedup table), because the relay is at-least-once.

---

## 6. The written rule — when orchestration beats choreography

Do not choose by habit. Choreography stays the default; orchestrate only when a trigger fires:

- **Complexity** — 4+ steps, or any branching / looping / parallel fan-out + join. Choreography smears branching logic across participants and makes the implicit event ordering untraceable.
- **Central visibility** — any "where is this business process right now?" requirement. One `SELECT state FROM saga_instance WHERE correlation_id = ?` answers it under orchestration; choreography needs N services' logs correlated.
- **Long-running** — the flow suspends on human approval or an external signal for minutes/hours/days. Choreography has no owner for the suspended state; the orchestrator holds it.
- **Compensation breadth** — the undo must span 4+ services in a defined reverse order. Only a coordinator can sequence reverse-order compensation reliably.

**Frugality gate.** Even when a trigger fires, prefer a **hand-rolled Go coordinator** (this §5 sketch, deployed inside the tenant's Kubernetes namespace / Helm release like everything else — never a shared multi-tenant control plane) for a single complex flow. Justify **Netflix Conductor** only when many orchestrated flows accumulate and central visibility *across* workflows becomes the operational point; then see `conductor-workflow-authoring` for the JSON-DAG authoring model. Either way the orchestrator is tenant-scoped: a Saga never spans tenants under this repo's per-tenant physical isolation.
