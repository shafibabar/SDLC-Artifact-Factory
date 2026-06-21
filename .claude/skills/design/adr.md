# Skill: design/adr

## Purpose
Produce an Architecture Decision Record (ADR) — a lightweight, durable record of one significant architectural decision: the context, the options considered, the decision made, and the consequences. ADRs are the institutional memory of architectural choices.

## Inputs
- `sdlc-config.json`
- `artifacts/design/bounded-contexts.md` (if decision is BC-related)
- **Arguments required:** decision title (e.g. `use-redpanda-over-kafka`, `physical-multi-tenancy-model`)

## Output
**File:** `artifacts/design/adrs/ADR-{NNN}-{slug}.md` (auto-numbered, e.g. `ADR-001-use-redpanda-over-kafka.md`)
**Registers in manifest:** yes

## ADR Rules (enforced)
- One decision per ADR — never bundle two unrelated decisions.
- Status progresses: `Proposed` → `Accepted` | `Rejected` | `Superseded by ADR-{NNN}`.
- Superseded ADRs are kept permanently — they explain why we were somewhere before we moved on.
- Consequences section must include both positive AND negative consequences — no decision is cost-free.
- Every technology choice, architectural pattern, or cross-cutting constraint that affects more than one team or bounded context warrants an ADR.
- Decisions about third-party tools that are difficult to reverse must have an ADR.

## When to Write an ADR
- Choosing a database engine, message broker, or framework
- Choosing a tenancy model (single-tenant / logical / physical)
- Cross-BC architectural patterns (Transactional Outbox, CQRS, Saga vs Process Manager)
- Security architecture decisions (mTLS, Zero Trust, ABAC)
- Deployment model decisions (k3s vs managed K8s, cloud provider selection)
- API design decisions (REST vs gRPC, versioning strategy)
- Data residency and sovereignty commitments

## Artifact Template

```markdown
# ADR-{NNN}: {Decision Title}

**Date:** {date}
**Status:** Proposed | Accepted | Rejected | Superseded by ADR-{NNN}
**Deciders:** {names or roles who made this decision}
**Affected contexts:** {list of bounded contexts or "Platform-wide"}

---

## Context

{Describe the situation that requires a decision. What problem are we solving? What forces (technical, business, compliance, team) are in play? Why is a decision needed now?}

**Example:**
The product must handle sensitive customer data across multiple tenants. Early design assumed logical multi-tenancy (shared infrastructure, row-level security) but compliance requirements (GDPR, SOC2 Type II) and customer contracts require guarantees of data isolation that logical tenancy cannot provide with confidence. A decision on the tenancy model is required before the infrastructure layer can be designed.

---

## Decision Drivers

- {Driver 1} — e.g. "SOC2 Type II audit requires demonstrable tenant isolation"
- {Driver 2} — e.g. "Customer contracts include data residency commitments"
- {Driver 3} — e.g. "Team has strong PostgreSQL expertise; minimal Cassandra experience"
- {Driver 4} — e.g. "Budget constraint: infra cost must stay under $X/month at initial scale"

---

## Options Considered

### Option 1: {Option Name}
{Describe the option.}

**Pros:**
- {pro 1}
- {pro 2}

**Cons:**
- {con 1}
- {con 2}

---

### Option 2: {Option Name}
{Describe the option.}

**Pros:**
- {pro 1}

**Cons:**
- {con 1}

---

### Option 3: {Option Name} *(chosen)*
{Describe the option.}

**Pros:**
- {pro 1}
- {pro 2}

**Cons:**
- {con 1}

---

## Decision

**We will {chosen option}.**

{One paragraph explaining the rationale for choosing this option over the alternatives. Reference the decision drivers.}

---

## Consequences

### Positive
- {positive consequence 1}
- {positive consequence 2}

### Negative
- {negative consequence 1 — e.g. "Higher infra cost per tenant due to dedicated databases"}
- {negative consequence 2 — e.g. "Operational complexity: more clusters to manage"}

### Risks
- {risk 1 and mitigation}
- {risk 2 and mitigation}

### Follow-on decisions required
- {ADR needed next} — e.g. "Kubernetes cluster provisioning strategy (single cluster with namespaces vs. separate clusters per tier)"
- {Design artifact to update} — e.g. "Update bounded-contexts.md with per-tenant deployment topology"

---

## Alternatives Rejected

| Option | Rejected because |
|--------|----------------|
| {Option 1} | {reason} |
| {Option 2} | {reason} |

---

## References
- {Link to relevant requirement} — e.g. `artifacts/ideate/requirements/nfrs.md#NFR-SEC-01`
- {Link to compliance framework} — e.g. GDPR Article 25 (data protection by design)
- {External reference} — e.g. [Transactional Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html)
```

## ADR Index Maintenance
After writing a new ADR, append a row to `artifacts/design/adrs/INDEX.md`:

```markdown
| ADR | Title | Status | Date | Affected |
|-----|-------|--------|------|---------|
| ADR-001 | Use Redpanda over Apache Kafka | Accepted | {date} | Platform-wide |
| ADR-002 | Physical multi-tenancy model | Accepted | {date} | Platform-wide |
```

## Quality Checks
- [ ] One decision per ADR
- [ ] Status is set (Proposed / Accepted)
- [ ] Consequences include BOTH positive and negative
- [ ] At least 2 options considered (not a rubber-stamp of a foregone conclusion)
- [ ] Rejected options table is populated
- [ ] Follow-on decisions or artifacts identified
- [ ] ADR-INDEX.md updated
