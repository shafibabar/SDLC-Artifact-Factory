# Example 3 — Enterprise: Timeout Budgets, Per-Region Partners, an Orchestrated Payout

Self-contained. **Kinsend** sends money across borders: a sender pays in, Kinsend converts, and a payout partner in the receiver's country pays out. **Enterprise** profile, four deployables: `transfers`, `pricing` (FX quotes), `compliance` (sanctions screening), `payouts`. External systems: a sanctions-list provider, an FX rate provider, and payout partners per corridor (region). Multi-tenancy design: single tenant, one deployment per region. Default stack.

## Input

> **User:** "Make the payout flow choreographed: each service reacts to events, and if the partner payout fails we just expect everything to roll back. Payouts can call the partner bank directly inside its event consumer and hold the offset until the bank answers. And the payout partners want to send us their full customer record on every status callback, with every field required, so we have everything."

## Working it

- **Payout flow** (screen, quote lock, debit, partner payout, notify) has five ordered steps, some of which must be undone when a later one fails. Orchestration with a coordinator in `transfers`; the design of the coordinator goes to `workflow-orchestration` (D047-3). Declined: choreography with "everything rolls back" (async, choreographed and atomic: Ford's Horror Story).
- **Full customer record, every field required, on partner callbacks:** declined. That is **stamp coupling** (Ford): every partner would be tied to fields Kinsend never reads, and a change to any of them breaks every corridor. The callback contract carries only what Payouts uses (payout id, partner reference, status, status time, failure reason), is read by a tolerant reader that ignores the rest, and is loose; a Consumer-Driven Contract per partner pins those fields.
- **Partner call inside the consumer:** declined. The consumer records the payout instruction idempotently (deduplicating on the event id) and commits; the partner call is its own step with a timeout, an idempotency key and a failed state, so consumer lag never grows behind a slow bank.
- **Quote chain** (gateway → transfers → pricing → FX provider) gets a timeout budget.

## Output: `artifacts/kinsend/design/architecture/integration-design.md`

````markdown
---
name: integration-design
product: kinsend
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-09-03
summary: Kinsend's integrations: an orchestrated, compensating payout flow, partner calls out of consumer critical paths with keyed retries, and a timeout budget on the quote chain.
traces-to: [design/context-map.md, design/architecture/container-diagram.md, ideate/nfr-specification.md, design/architecture/orchestration-design.md]
---

# Integration Design for Kinsend

**Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner
**Question it answers:** for every integration, how does it talk, what does it promise, and what happens when the other side is slow or down?

- **Profile:** enterprise

## Integration Inventory

| From | To | Shape | Consistency | Protocol | Contract strictness | Contract test | Resilience |
|---|---|---|---|---|---|---|---|
| Transfers | Pricing (lock quote) | request/response (sync) | eventual (quote expires) | gRPC | strict (Protobuf) | Consumer-Driven Contract plus breaking-change check on the proto | timeout (budget), retry (idempotent: quote request id), breaker, bulkhead, fallback |
| Pricing | FX Rate Provider | request/response (sync) | eventual | HTTPS/JSON | loose (tolerant reader) | recorded-response test, API version pinned | timeout (budget), retry (read), breaker, bulkhead, fallback |
| Compliance | Sanctions List Provider | request/response (sync) | eventual | HTTPS/JSON | loose (tolerant reader) | recorded-response test | timeout, retry (read), breaker, bulkhead, fallback |
| Transfers | `payout-requested` topic | event (async) | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | Transactional Outbox |
| Payouts | `payout-requested` topic | event (async) | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | idempotent consumer, retry, DLQ |
| Payout Partner | Payouts (status callback) | event (async, inbound callback, at-least-once) | eventual | HTTPS/JSON, signed | loose (tolerant reader: payout id, partner reference, status, status time, failure reason) | Consumer-Driven Contract per partner | timeout (2 s ack), idempotent by partner event id, forward-only states; risk-accepted: no breaker, we are the receiver |
| Payouts | Payout Partner (per corridor) | request/response (sync) | eventual (partner confirms later) | HTTPS/JSON | loose (tolerant reader) | Consumer-Driven Contract per partner | timeout, retry (idempotency key = payout id), breaker and bulkhead per partner, fallback |
| Payouts | `payout-completed` / `payout-failed` topics | event (async) | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | Transactional Outbox |

## Synchronous Integrations

### Transfers → Pricing

- **Why sync:** the sender sees the locked rate before confirming
- **Timeout:** 1.2 s; part of the quote budget: FX attempt 300 ms, Pricing envelope 300 + 100 + 300 = 700 ms, Pricing budget 800 ms, Transfers → Pricing 1.2 s, user request 1.5 s
- **Retry:** 1 retry with jitter; idempotent by quote request id
- **Circuit breaker:** 5 consecutive failures in 10 s; reset 5 s
- **Bulkhead:** own channel pool, 50 concurrent
- **Fallback:** "rates unavailable, try again shortly"; never a stale rate for a locked quote

### Pricing → FX Rate Provider

- **Why sync:** a quote needs the current rate
- **Timeout:** 300 ms per attempt (inside the quote budget)
- **Retry:** 1 retry with jitter (a read)
- **Circuit breaker:** 50% of at least 20 calls in 30 s; reset 30 s
- **Bulkhead:** own client, 30 concurrent
- **Fallback:** the last rate under 60 seconds old, marked stale, for indicative quotes only; locked quotes refuse

### Compliance → Sanctions List Provider

- **Why sync:** a transfer can't proceed unscreened
- **Timeout:** 2 s per attempt
- **Retry:** 2 retries with jitter (a read)
- **Circuit breaker:** 50% of at least 10 calls in 60 s; reset 60 s
- **Bulkhead:** own client, 20 concurrent
- **Fallback:** the transfer is held for manual screening; never passed unscreened

### Payouts → Payout Partner

- **Why sync:** the partner accepts or refuses the payout instruction
- **Timeout:** 5 s per attempt
- **Retry:** 3 retries, 1 s ×2 with jitter, always with the payout id as idempotency key; a final unknown outcome is reconciled against the partner's status endpoint
- **Circuit breaker:** one per partner: 50% of at least 10 calls in 60 s; reset 120 s
- **Bulkhead:** own client per partner, 10 concurrent
- **Fallback:** the payout is held as "partner unavailable" and the orchestrator decides (wait, or reroute to a second partner in the corridor)

## Asynchronous Integrations

| Topic | Publisher (mechanism) | Consumers (group) | Idempotency | Retry and DLQ |
|---|---|---|---|---|
| `payout-requested` | Transfers (Transactional Outbox) | Payouts (`payouts.instructions`) | payout id | 1 s, 5 s, 30 s, 2 m; then `payouts.instructions.dlq` |
| `payout-completed`, `payout-failed` | Payouts (Transactional Outbox) | Transfers (`transfers.saga`) | payout id | 1 s, 5 s, 30 s; then `transfers.saga.dlq` |

The Payouts consumer only records the instruction (deduplicating on the event id) and commits; the partner call runs as a separate step, never holding the consumer's offset. A payout the partner can't accept after the retries and the reroute decision ends in the `failed` state, published as `payout-failed` and visible on the operations dashboard for re-drive; it is never dropped.

## Coordination

- **Payout flow (screen, lock quote, debit, partner payout, notify):** communication: async · consistency: eventual · coordination: orchestrated by the transfer coordinator (parallel saga). Not atomic: the requested "everything rolls back" choreography would be the horror story. The steps, their compensations and the coordinator are designed in `orchestration-design.md` (`workflow-orchestration`); this artifact records the integrations each step uses.

## Anti-Corruption Layers

| Foreign system or context | Domain port | Adapter | What is translated |
|---|---|---|---|
| Payout partners | `PayoutPartner` (instruct, query status) | one adapter per partner | each partner's fields, status codes and reference formats to payout states |
| FX Rate Provider | `RateSource` | FX adapter | currency pairs, timestamps |
| Sanctions List Provider | `SanctionsScreen` | sanctions adapter | match scores and list names to clear / hold / block |

## Cross-Context Reads

| Reader | Data owned by | Option | Why not the others |
|---|---|---|---|
| Transfers | Compliance (screening result) | API composition | must be fresh for each transfer; volume is per transfer, not per read |
| Transfers | Payouts (payout status for the app) | event replication | read often; lag of seconds is fine |

## Consumer-Driven Contract Plan

| Consumer | Provider | Contract | Where the test runs | Gate |
|---|---|---|---|---|
| Transfers | Pricing | `LockQuote` request and response fields | Pricing build | breaking-change and contract check fail the build |
| Payouts | each partner | instruction and status fields | partner sandbox pipeline | contract replay before each partner release |

## Related ADRs

- ADR-014: Orchestrated payout saga with compensations
- ADR-015: Partner calls outside consumer critical paths

## Open Questions

- Second partner per corridor for rerouting: the product owner to confirm which corridors have one
````

## Why this is right

- The choreographed "everything rolls back" was replaced by an orchestrated, compensating flow, handed to workflow-orchestration.
- The partner call left the consumer's critical path and carries an idempotency key.
- The quote chain has a budget where each caller's deadline exceeds its downstream's envelope.
- Breakers and bulkheads are per downstream, per partner.
- `validate-integration-design.sh` exits clean on the artifact.
