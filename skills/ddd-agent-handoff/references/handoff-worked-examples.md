# DDD Handoff Worked Examples

Seven worked examples of `assets/handoff-record-template.md` in use, illustrating
`references/handoff-protocol.md`'s modes, mode transitions, roster changes, and
resumption handling. Each is a condensed instance of the template — real field
values, not the full boilerplate. Grounded in this repo's first product (Data
Estate Mapping and Compliance Intelligence) where useful for realism, but the
patterns apply to any product. Self-contained — loadable without reading
`SKILL.md` or the other two files first, though it references their concepts by
name.

---

## 1. Successful — X-as-a-Service

**Concern:** Aggregate design for the Data Source Connector Bounded Context,
domain-modeler → backend-engineer.

- `subdomain_classification: supporting` — connectors are necessary and
  product-specific but not the product's differentiator (per
  `subdomain-distillation`'s worked example).
- `interaction_mode: x-as-a-service` — stable artifact, well-understood
  boundary, first thing backend-engineer needed from this pairing but a
  routine kind of handoff.
- **Roster:** domain-modeler (producing), backend-engineer (consuming). No
  changes.
- **Artifacts produced:** `Aggregate: StorageConnection` design doc — DoD met
  (invariants and Domain Events specified).
- **Open questions:** none.
- **Status:** `completed`. **Verdict:** backend-engineer implemented the
  Aggregate as designed with no deviation; no Collaboration needed.

## 2. Successful — Collaboration (PII-sensitive Bounded Context)

**Concern:** Aggregate boundary and invariants for the Personal Data Record
within the Entity Extraction Bounded Context, domain-modeler ↔
security-architect.

- `subdomain_classification: core` — Entity Extraction is this product's
  Core Domain.
- `interaction_mode: collaboration` — both Core Domain and PII sensitivity
  push toward Collaboration per Mode Selection Criteria; neither agent could
  finish this alone (the invariant design depends on the access policy and
  vice versa).
- **Roster:** domain-modeler, security-architect. Joint from the start.
- **Open questions (resolved over two rounds):** "Does the redaction
  invariant live on the Aggregate or the access policy?" → resolved: on the
  Aggregate, enforced before any Domain Event is published (domain-modeler's
  call, since it's Aggregate-internal); security-architect's ABAC policy
  then governs read access to the already-redacted projection.
- **Status:** `completed`, zero unresolved open questions (required for
  Collaboration records to be marked complete).

## 3. Successful — mode escalation mid-session

**Concern:** Read model design for the Compliance Rule Engine's reporting
view, enterprise-architect → data-engineer.

- Started `interaction_mode: x-as-a-service` — the read model looked
  stable, `subdomain_classification: core` but assumed low novelty for this
  pairing.
- data-engineer found ambiguity twice in one week (which fields are
  queryable, how rule-evaluation results version over time) — the second
  instance is the documented trigger per the Mode Transition Protocol.
- **Mode History:** `2026-0X-XX` — x-as-a-service → collaboration —
  "consuming agent found unresolvable ambiguity twice; escalating per
  protocol rather than waiting for a third."
- **Status:** `completed` after the switch — the remaining design happened
  jointly in one session.

## 4. Successful — new agent added mid-session

**Concern:** Storage Connector Aggregate implementation, originally just
domain-modeler + backend-engineer.

- Mid-implementation, backend-engineer discovers a customer's connected
  Google Drive contains EU-resident personal data — a cross-border/PII
  signal that wasn't part of the original scope.
- **Roster Change Protocol applied:** looked up "PII mapping, data
  sovereignty" in `SKILL.md`'s Agent Boundary Matrix → **security-architect**
  owns this. Added to roster.
- **Roster:** domain-modeler (joined at start), backend-engineer (joined at
  start), security-architect (joined mid-session — trigger: "EU personal
  data discovered in a connected source, needs data sovereignty review").
- **Status:** `completed` — security-architect's review became a short
  Collaboration sub-thread within the larger otherwise-X-as-a-Service
  handoff, per `handoff-protocol.md`'s note that joining agents apply Mode
  Selection Criteria to their own piece independently.

## 5. Abandoned/resumed — operational pause mid-Event-Storming

**Concern:** Event Storming session for the Alert & Audit Bounded Context,
domain-modeler.

- Session ended (context limit) with Big Picture Event Storming complete but
  Process Level not started.
- `status: abandoned` at end of session → `resumption_type:
  operational-pause` (nothing about the model was in question, just an
  ordinary session boundary).
- **Artifacts produced:** Big Picture board (Domain Events identified, no
  Aggregates yet) — DoD not yet met for this stage.
- **Open questions:** "Is 'Alert Acknowledged' a Domain Event on this
  Bounded Context or does it belong to a downstream notification context?" —
  left explicitly unresolved for the next session, not guessed at.
- **Resumption notes:** next session should resume at Process Level
  Event Storming directly from the Big Picture board — do not redo Big
  Picture from scratch.

## 6. Abandoned/resumed — operational pause mid-handoff, open question unresolved

**Concern:** Service decomposition for the Compliance Rule Engine,
enterprise-architect → platform-engineer.

- Session ended with `status: blocked` — an open question ("does rule
  evaluation get its own service or stay inside the Compliance Rule Engine
  service?") was unresolved and correctly recorded as blocking, per the
  Conflict Resolution section of `handoff-protocol.md`, rather than
  guessed at by platform-engineer to keep moving.
- `resumption_type: operational-pause` — the question is a real open design
  decision, not evidence the existing model is wrong.
- **Resumption notes:** a fresh session reads this open question first,
  resolves it with domain-modeler if it touches Bounded Context scope (per
  the escalation rule that domain-modeler has final say there), then
  platform-engineer continues.

## 7. Abandoned/resumed — breakthrough-triggered refactor

**Concern:** Aggregate boundary for the Entity Extraction Bounded Context,
mid-implementation with backend-engineer.

- While implementing the `ExtractedEntity` Aggregate, backend-engineer finds
  that relationship consistency across the graph can't actually be enforced
  at the Aggregate boundary as designed — a different Aggregate boundary is
  needed, not a bug fix.
- `status: abandoned`, `resumption_type: breakthrough-triggered-refactor` —
  set explicitly rather than defaulting to operational-pause, because the
  interruption is evidence the model itself is wrong.
- **Resumption notes:** "Do not resume implementation on the current
  Aggregate boundary. Routed back to domain-modeler for boundary revision
  per Evans' Continuous Refactoring Toward Deeper Insight — implementation
  work here is paused, not just interrupted, until the model is revised."
- **Verdict:** the handoff is not "resumed forward" — a new handoff record
  is opened once domain-modeler produces the revised boundary, referencing
  this record as the reason for the change.
