# Performance Budgets for the Data-Estate-Mapping Product

Full standard referenced from `SKILL.md`'s "Performance Budgets for the Data-Estate-Mapping
Product" section. Self-contained — reads without the parent body already in context. Covers how
this skill's in-process, per-operation benchmark budgets are derived from `slo-definition`'s
system-level SLOs rather than invented, why they are deliberately tighter and narrower in scope
than the SLOs they derive from, and how `multi-tenancy-design`'s physical-isolation model shapes
the allocation budget specifically.

---

## This Skill's Budget Is a Build-Time Proxy, Not the System SLO

`slo-definition` sets the ClassifyDataAsset command API's Latency SLI at **requests completing
under 800ms**, measured end-to-end at the ingress — real network hop, real Linkerd mTLS handshake,
the full middleware chain, a real Postgres round-trip, and the handler's own business logic, all
included. `go-load-test` verifies that 800ms SLO holds under real, sustained traffic against the
fully deployed system — that is system-level, shift-right validation, and it is `go-load-test`'s
territory, not this skill's.

This skill's tracked benchmark (`h.Handle(ctx, cmd)`, called directly against the assembled
command-handler struct, per `references/benchmark-and-regression-gate-standard.md`'s worked
example) never crosses a real network boundary inside the timed loop — `go-performance-optimization`'s
determinism rule forbids exactly that. It measures only the handler's own in-process object graph:
command validation, Domain Primitive construction, business-rule evaluation, and the repository
call through its interface (against a fast, deterministic fixture double, not a real Postgres
connection). **The budget below is therefore a build-time proxy that catches a regression in the
handler's own logic on every merge — narrower in scope than the 800ms SLO, and complementary to,
never a substitute for, `go-load-test`'s real-traffic measurement of the actual system p99.**

---

## Budget 1: In-Process Handler-Logic Time

**Target: p99-equivalent ≤ 5ms per `ClassifyDataAssetHandler.Handle()` invocation**, tracked via
the `benchstat`-gated benchmark.

Derivation: the 800ms end-to-end SLO has to cover network transit, the Linkerd mTLS handshake, the
full middleware chain (authentication, tracing, tenant resolution), a real Postgres round-trip for
the classification write, and outbox-row insertion — none of which this in-process benchmark
measures. A 5ms ceiling on the handler's own logic leaves the overwhelming majority of the 800ms
budget for exactly those I/O-bound, network-bound stages that only show up under
`go-load-test`'s real-traffic measurement — while still being tight enough, in absolute terms, to
catch the kind of regression this gate exists for: an accidentally-introduced O(n²) validation
loop, a synchronous call that should have been deferred to the outbox, or a newly nested business
rule evaluated once per entity instead of once per batch. A regression that pushes handler-logic
time from low microseconds into several milliseconds is invisible to a human "it feels fine"
smoke-check and is exactly what the CI gate is for.

| Stage of the 800ms SLO | Approximate share | Verified by |
|---|---|---|
| Network transit + Linkerd mTLS handshake + ingress | Remaining headroom after the rows below | `go-load-test` (system-level, real traffic) |
| Middleware chain (auth, tracing, tenant resolution) | Remaining headroom | `go-load-test` |
| Real Postgres round-trip (classification write + outbox insert) | Remaining headroom | `go-load-test`, `go-integration-test` (correctness) |
| **Handler business logic** (this skill's tracked benchmark) | **≤ 5ms ceiling** | **This skill's CI-gated benchmark** |

The "remaining headroom" rows are deliberately not assigned fixed millisecond budgets here — that
allocation is `slo-definition`'s and `go-load-test`'s call to make against real measured system
behavior, not something this skill should invent numbers for. This skill owns exactly one row: the
in-process handler-logic ceiling, tracked on every merge.

---

## Budget 2: Per-Request Allocation Budget

**Target: ≤ 32 allocations / ≤ 4KB per `ClassifyDataAssetHandler.Handle()` invocation**, tracked
via `b.ReportAllocs()` in the same gated benchmark, excluding any driver-internal buffer
allocations a real database driver would perform (out of scope here precisely because the tracked
benchmark uses a fixture double, not a real `pgx` connection, per Budget 1 above).

### Why This Number, Grounded in This Product's Actual Isolation Model

`multi-tenancy-design` establishes this product on **Model 3: Physical Isolation** — separate
database instances per tenant, not a shared database with a `tenant_id` filter column. This matters
directly for the allocation budget: **there is no per-row tenant-filtering cost on this stack**
(the isolation is paid once, at connection-pool/schema-selection time, not per query) — the
allocation-heavy "check `tenant_id` on every row" pattern a shared-tenancy (Model 1) system would
carry on every request simply does not exist here. What the handler *does* pay, per request, is
**tenant-context enrichment for audit traceability**: `multi-tenancy-design` states explicitly that
even under physical isolation, `tenant_id` is still carried on Domain Events and structured logs
"not for filtering — for traceability and audit." Concretely, that means every `Handle()`
invocation constructs:

- One `TenantID` Domain Primitive (`access-control-model`'s `NewTenantID`, wrapping a parsed
  `uuid.UUID`) — a small, bounded, self-validating construction, not a query.
- One or more `Permission` Domain Primitives for the authorization check.
- One outbound Domain Event envelope (`DataAssetClassified`), carrying the `tenant_id` field for
  audit traceability, JSON-marshaled for the outbox insert.
- Whatever the business-rule evaluation itself allocates — bounded by the command's own payload
  size, not by tenant count or data-estate size.

None of this is unbounded or data-volume-dependent — it is a small, fixed-shape object graph per
request. **32 allocations / 4KB is a generous ceiling for that fixed shape**, tight enough that a
regression (a newly introduced `fmt.Sprintf` on a hot path, a slice grown by bare `append` instead
of preallocated, an unnecessary interface-boxing conversion — all named explicitly in
`go-performance-optimization`'s memory-optimization standard) shows up as a clear, gated
`allocs/op` delta rather than disappearing into a loose budget nobody would ever trip.

---

## Budget 3: Outbox Drain Batch — Tracked, Not a Fixed Number

`go-event-publisher`'s relay drains up to a configurable `r.batch` unpublished rows per tick. This
skill tracks `time/op` **per batch**, scaling with whatever `r.batch` the product's config sets —
no fixed millisecond target is stated here, because the batch size itself is a per-product
override (`sdlc-config-management`'s pattern), and a fixed absolute target would either be trivially
loose for a small batch or unachievable for a large one. What is gated is the **delta**: a
regression shows up as a `benchstat`-significant increase in per-batch `time/op` (or `allocs/op`,
since `records`/`ids` are preallocated to `r.batch` per `go-event-publisher`'s standard) at whatever
batch size the tracked benchmark's table exercises — the same relative-regression discipline every
other tracked operation in this file uses, applied to an operation whose absolute size is
intentionally configurable rather than fixed.

---

## Budget Review Cadence

These budgets are reviewed on the same cadence `slo-definition`'s SLO document already undergoes —
they derive from that document's SLOs, so a review that changes the 800ms latency SLO or the
tenant-isolation model necessarily triggers a re-derivation here, not an independent review
schedule invented for this file alone. A product that needs a tighter handler-logic ceiling (a
bounded context handling higher-sensitivity classification logic, for instance) overrides it via
`sdlc-config-management`'s established pattern — the same mechanism `mutation_test_cadence` and
`COVER_MIN` already use — rather than this file being edited per-product.
