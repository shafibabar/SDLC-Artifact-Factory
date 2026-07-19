---
name: integration-design
description: >
  Teaches how to design service integrations — covering synchronous (HTTP/gRPC)
  and asynchronous (event-driven) integration patterns, when to use each, the
  Circuit Breaker and Retry/Backoff patterns for resilient sync calls, Consumer-
  Driven Contract testing for all integrations, and how the Anti-Corruption Layer
  isolates the domain model from external service models. Used by the enterprise-
  architect agent when designing how services communicate, after the Context Map
  is complete.
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, integration, circuit-breaker, retry, consumer-driven-contracts, acl]
---

# Integration Design

## Purpose

Integration design defines how services communicate — which communication style (synchronous or asynchronous) is appropriate for each interaction, how failures are handled, and how the domain model is protected from external service models.

Every integration is a dependency. Undesigned integrations become implicit coupling. This skill makes every integration explicit, deliberate, and resilient by design.

---

## Synchronous vs Asynchronous Integration

The fundamental choice for every service-to-service interaction:

| Dimension | Synchronous (HTTP/gRPC) | Asynchronous (Events/Messages) |
|---|---|---|
| **Coupling** | Temporal — caller must wait for response; both must be available | Decoupled — caller continues; consumer processes at its own pace |
| **Latency** | Low — immediate response | Higher — processing lag before consumer reacts |
| **Failure propagation** | Cascades — downstream failure causes upstream failure | Isolated — downstream failure doesn't block upstream |
| **Data consistency** | Strong — response confirms outcome | Eventual — state propagates asynchronously |
| **Use for** | Queries (need data now), time-sensitive Commands, user-facing requests | Domain Events, notifications, background processing, cross-context state propagation |

**Default rule:** Use asynchronous (events) for cross-Bounded-Context communication. Use synchronous only when a response is required in the current request's flow.

---

## Synchronous Integration Patterns

### HTTP (REST)

Use for: cross-context queries where the caller needs data before proceeding; user-facing read requests through the API Gateway.

**Pattern:**
```
Service A  ──HTTP GET──▶  Service B API
           ◀──200 JSON──
```

**Resilience requirements for every HTTP call to another service:**
1. **Timeout** — every HTTP call has an explicit timeout. No call blocks indefinitely.
2. **Retry with Backoff** — transient failures (503, 504) are retried with exponential backoff and jitter.
3. **Circuit Breaker** — after N consecutive failures, the circuit opens. Calls fail fast (no waiting for timeout) until the circuit resets.
4. **Bulkhead** — HTTP clients to different services use separate connection pools. One slow downstream doesn't exhaust the connection pool for all others.
5. **Retry only what is safe to repeat** — GETs are always retryable; mutating calls are retried only when they carry an `Idempotency-Key`. Retrying a non-idempotent POST turns one timeout into a duplicate side effect.
6. **Deadline propagation** — the incoming request's deadline flows down through `context.Context`. Each caller's timeout must exceed its downstream's full retry envelope (all attempts plus backoff), or the caller gives up while the downstream is still working — and then retries on top of it.

### Retry and Backoff

```go
type RetryConfig struct {
    MaxAttempts     int
    InitialDelay    time.Duration
    MaxDelay        time.Duration
    Multiplier      float64
    JitterFactor    float64
}

// Default: 3 attempts, 100ms initial, 5s max, 2x multiplier, 20% jitter
var DefaultRetry = RetryConfig{
    MaxAttempts:  3,
    InitialDelay: 100 * time.Millisecond,
    MaxDelay:     5 * time.Second,
    Multiplier:   2.0,
    JitterFactor: 0.2,
}
```

Jitter is mandatory — without jitter, all callers retry simultaneously after a failure, causing a thundering herd that overwhelms the recovering service.

### Circuit Breaker

States: `Closed` (normal operation) → `Open` (failing fast) → `Half-Open` (testing recovery).

```
Closed: requests pass through
  │ N failures in window
  ▼
Open: requests fail immediately (no call to downstream)
  │ timeout elapsed
  ▼
Half-Open: one request allowed through
  │ success → Closed
  │ failure → Open
```

Use the `sony/gobreaker` library or equivalent. Configure per downstream service: different services have different failure thresholds.

---

## Asynchronous Integration Patterns

### Event-Driven (Redpanda)

Use for: Domain Event publication, cross-context state propagation, background processing, and any interaction that does not require a response in the current request flow.

**Producer pattern:**
```
Aggregate emits event
     ↓
Event written to outbox_events (same transaction as aggregate update)
     ↓
Outbox Relay reads and publishes to Redpanda topic
```

**Consumer pattern:**
```
Redpanda topic: [bounded-context].[event-name]
     ↓
Consumer Group: [service].[consumer-group-name]
     ↓
Message deserialized
     ↓
Idempotency check (has this eventId been processed?)
     ↓
Event handler processes
     ↓
Dead Letter Queue if processing fails after max retries
```

**Consumer group design:**
- Each consumer service has its own consumer group — independent offset management
- Consumer groups enable replay: reset the offset to replay all events from the beginning
- Never share a consumer group between two different services

### Retry Policy for Consumers

```
Attempt 1: immediate
Attempt 2: delay 1s
Attempt 3: delay 5s
Attempt 4: delay 30s
Attempt 5: delay 2m
→ DLQ after 5 failures
```

---

## Anti-Corruption Layer for External Systems

Every integration with an external system (Google Drive, AWS S3, any third-party API) uses an Anti-Corruption Layer (ACL):

```
External API            ACL Package                    Domain
┌──────────┐    ┌─────────────────────────┐    ┌──────────────┐
│ Google   │    │ adapters/googledrive/   │    │              │
│ Drive    │───▶│   client.go             │───▶│  Domain      │
│ API      │    │   translator.go         │    │  Interfaces  │
│          │◀───│                         │◀───│              │
└──────────┘    └─────────────────────────┘    └──────────────┘
```

`client.go` — calls the external API using the external API's types and conventions.
`translator.go` — converts external types to domain types (and vice versa for writes).

The domain never imports from `client.go`. It depends only on the domain port interface, which the ACL implements. This means:
- The external API can change its model without touching the domain
- The ACL can be tested independently (stub the external API, test the translation)
- The domain can be tested without any external API dependency

---

## Consumer-Driven Contract Testing

Every integration — sync or async — requires Consumer-Driven Contract tests:

| Integration type | Contract mechanism |
|---|---|
| HTTP (REST) | Pact or HTTP-level contract tests: Consumer writes expected request/response; Provider runs the contract in CI |
| Event-driven | Event schema validation: Consumer declares the event fields it reads; Publisher validates it still emits those fields |

**Rule:** A service's deployment pipeline cannot succeed if any Consumer's contract test fails. The Supplier owns the obligation to its Consumers.

---

## Integration Inventory

The enterprise-architect maintains an Integration Inventory for each product — a complete list of every service-to-service dependency:

| From Service | To Service | Style | Protocol | Contract | Resilience pattern |
|---|---|---|---|---|---|
| API Gateway | Classification Service | Sync | HTTP/JSON | Consumer-Driven Contract | Retry + Circuit Breaker |
| Storage Integration | Redpanda | Async | Kafka protocol | Schema validation | At-least-once + DLQ |
| Classification Service | Graph Service | Async | Kafka protocol | Schema validation | At-least-once + DLQ |
| Storage Integration | Google Drive API | Sync (external) | HTTP/JSON | ACL | Retry + Circuit Breaker |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Style declared | Every integration states sync or async and the justification | Integrations with no documented style |
| Resilience designed | Every sync call has timeout + Retry and Backoff + Circuit Breaker | HTTP calls with no timeout or retry |
| ACL for external systems | Every external system integration uses ACL | External API types in domain layer |
| Consumer-Driven Contracts | Every integration has a defined contract test plan | Verbal-only integration agreements |
| DLQ defined | Every Redpanda consumer has a DLQ topic | Events silently dropped on consumer failure |
| Idempotent consumers | All async consumers are designed to be idempotent | Consumers that cannot handle duplicate events |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Sync by default** — HTTP calls for cross-context flows because "it's easier to reason about" | Availability multiplies down the call chain; every downstream incident becomes a platform incident | Asynchronous Domain Events are the default across Bounded Contexts; sync is the justified exception |
| **Retry without jitter or budget** — aggressive synchronized retries against a struggling service | The retry storm finishes off the recovering downstream (thundering herd) | Exponential backoff with jitter, capped attempts, and Circuit Breaker in front |
| **Retrying non-idempotent calls** — re-sending a mutating request after a timeout | A timeout is an *unknown* outcome; the retry duplicates the side effect | Mutating calls carry an `Idempotency-Key`, or are not retried automatically |
| **One shared Circuit Breaker (or none)** — a global breaker across all downstreams | One failing dependency opens the circuit for healthy ones; or without a breaker, threads pile up on timeouts | One Circuit Breaker and one connection pool (Bulkhead) per downstream service |
| **Synchronous call inside an event consumer's critical path** — consumer blocks on a third-party API per event | Broker lag balloons behind the slowest external dependency; redeliveries amplify the load | Do external calls behind their own resilience stack, and consider splitting into a separate step with its own topic |
| **Request/reply over the broker** — publishing an "event" and waiting for a response event | Recreates temporal coupling with worse latency and no backpressure semantics | If a response is needed in-flow, use HTTP/gRPC with resilience patterns; events are fire-and-forget facts |
| **Contract by observation** — consumers coupling to whatever the provider currently returns | The provider cannot change anything safely; every deploy is a gamble | Consumer-Driven Contract tests in the provider's CI, gating deployment |
| **ACL bypass "just this once"** — calling the vendor SDK directly from a handler | The vendor model leaks into the domain; the exception becomes the norm within weeks | All external calls go through the ACL's `client.go`/`translator.go`; the domain sees only ports |

---

## Output Format

```markdown
---
name: integration-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Integration Design

## Integration Inventory
| From | To | Style | Protocol | Contract | Resilience |
|---|---|---|---|---|---|

## Synchronous Integration Details
[Per-integration: timeout, retry config, Circuit Breaker config]

## Asynchronous Integration Details
[Per-topic: producer, consumer groups, retry policy, DLQ]

## Anti-Corruption Layers
| External System | ACL location | Domain port interface | Translation notes |
|---|---|---|---|

## Consumer-Driven Contract Plan
| Consumer | Provider | Contract type | Test location | CI gate |
|---|---|---|---|---|

## Related ADRs
[ADR IDs for integration decisions]
```
