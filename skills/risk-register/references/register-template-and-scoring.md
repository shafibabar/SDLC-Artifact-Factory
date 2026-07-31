# Risk Register — Template, Scoring Scales, and Worked Entries

Reference material for the `risk-register` skill. Load this when writing or scoring a
risk entry, or when standing up the register artifact for a new product. Self-contained:
the calibrated Likelihood/Impact scales, the full severity matrix, the artifact template,
and worked entries for this repo's running product all live here.

---

## 1. Likelihood scale (calibrated)

Likelihood is the chance the risk materializes **within the product's current horizon** —
not "ever," but within the phases still ahead before the risk's review cadence next fires.
Anchoring likelihood to a horizon keeps it honest: almost anything is "possible eventually,"
so a bare `High` with no horizon is meaningless.

| Level | Meaning | Rough anchor |
|---|---|---|
| `Low` | Unlikely within the current horizon; would need an uncommon combination of conditions | Under ~15% — "we'd be surprised" |
| `Medium` | Plausible within the current horizon; a realistic path to it exists | ~15–50% — "could go either way" |
| `High` | Likely within the current horizon unless actively mitigated | Over ~50% — "expect it if we do nothing" |

The percentage anchors are calibration aids, not a demand for false precision. State the
level, and let the description carry the reasoning (what conditions trigger it).

## 2. Impact scale (calibrated)

Impact is the consequence **if** the risk materializes, assessed against the product's goals,
not the team's convenience. For this compliance-oriented product, weigh compliance and
data-integrity consequences heavily — an undetected PII gap is `High` impact even if rare.

| Level | Meaning | Examples in this product |
|---|---|---|
| `Low` | Recoverable with local effort; no external-facing consequence | A background job needs a re-run; a non-critical alert is delayed |
| `Medium` | Notable rework or a degraded experience; contained, no compliance breach | A Read Model rebuild; a Grafana dashboard gap; slower graph queries |
| `High` | Compliance breach, data-integrity loss, cross-tenant exposure, or a costly re-design | Under-classified PII; a tenant-isolation breach; a schema forced to change post-GA |

## 3. Severity matrix (Likelihood × Impact)

Severity is derived — never assigned by hand independently of the two axes.

| | Impact: Low | Impact: Medium | Impact: High |
|---|---|---|---|
| **Likelihood: High** | Medium | High | Critical |
| **Likelihood: Medium** | Low | Medium | High |
| **Likelihood: Low** | Low | Low | Medium |

Severity drives review cadence, not just optics:

| Severity | Review cadence | Design investment (see `references/risk-driven-design.md`) |
|---|---|---|
| `Critical` | Every phase gate; flagged in every phase-gate report | Deliberate mitigation + ADR; treat as architecturally significant |
| `High` | Every phase gate | Deliberate mitigation; ADR if it shapes an architecture decision |
| `Medium` | At least once per phase | Proportional mitigation; ADR optional |
| `Low` | Product-level retrospectives | Watch it; do not over-engineer |

## 4. Register artifact template

One register per product, stored at `artifacts/[product]/governance/risk-register.md`,
appended to continuously. The whole file's frontmatter `version` increments only on
structural changes (e.g. a new category added) — not per-risk like an ADR chain.

```markdown
---
name: risk-register-<product-slug>
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: <YYYY-MM-DD>
---

# Risk Register — <Product Name>

## Active Risks

| Risk ID | Description | Category | Likelihood | Impact | Severity | Owner | Mitigation Strategy | Status | Phase Identified | Review Cadence |
|---|---|---|---|---|---|---|---|---|---|---|
| RISK-001 | ... | ... | ... | ... | ... | ... | ... | open | ... | ... |

## Mitigated / Accepted / Closed Risks

<!-- Same table shape, for risks past open. Kept for the record — never deleted. -->

| Risk ID | Description | Category | Likelihood | Impact | Severity | Owner | Mitigation Strategy | Status | Phase Identified | Review Cadence |
|---|---|---|---|---|---|---|---|---|---|---|
| RISK-004 | ... | ... | ... | ... | ... | ... | ... | mitigated | ... | ... |
```

## 5. Worked entries — Data Estate Mapping & Compliance Intelligence

Four calibrated entries for the running product. Each shows the derivation
(Likelihood × Impact → Severity) and a concrete, named mitigation — not "keep an eye on it."

### RISK-001 — Under-classified PII in low-quality documents

- **Category:** `compliance` (secondary: `data`)
- **Description:** Entity extraction may misclassify or miss PII in low-quality scanned
  PDFs, causing a `DataAsset`'s `SensitivityLevel` to be under-classified and a compliance
  gap to go undetected.
- **Likelihood:** Medium — scanned/low-quality documents are common in real estates.
- **Impact:** High — an undetected PII gap is a compliance breach.
- **Severity:** Medium × High → **High**.
- **Owner:** `data-engineer`
- **Mitigation:** Confidence-threshold routing to a human-review queue; extraction quality
  test suite with adversarial low-quality fixtures; monitored across Data → Quality →
  Customer Validation.
- **Status:** `open` · **Phase identified:** Data · **Review cadence:** every phase gate.

### RISK-002 — Tenant-isolation boundary breach

- **Category:** `compliance` (secondary: `security`)
- **Description:** The physical multi-tenancy boundary could be breached by a misconfigured
  deployment, exposing one customer's data estate to another.
- **Likelihood:** Low — physical isolation makes this uncommon, needs a misconfiguration.
- **Impact:** High — cross-tenant data exposure is a top-severity compliance breach.
- **Severity:** Low × High → **Medium** (but escalate on any near-miss).
- **Owner:** `security-architect`
- **Mitigation:** Per-deployment tenant-isolation verification via automated OpenTofu policy
  checks; SOC 2 CC6 control mapped and tested; see `multi-tenancy-design`.
- **Status:** `open` · **Phase identified:** Design · **Review cadence:** every phase gate.

### RISK-003 — Graph query degradation at scale

- **Category:** `technical`
- **Description:** Apache AGE graph queries may degrade under the relationship volume of a
  large customer's full data estate, slowing compliance-rule evaluation past acceptable SLOs.
- **Likelihood:** Medium — large estates are an expected GA target.
- **Impact:** Medium — degraded (not broken) evaluation; recoverable.
- **Severity:** Medium × Medium → **Medium**.
- **Owner:** `platform-engineer`
- **Mitigation:** Load testing against synthetic large-estate graphs before GA; a Neo4j
  Community fallback path documented as an ADR-backed escape hatch.
- **Status:** `open` · **Phase identified:** Quality · **Review cadence:** once per phase.

### RISK-004 — Duplicate/delayed events during rolling deploy

- **Category:** `technical` (operational)
- **Description:** Redpanda consumer-group rebalancing during a rolling deploy could cause a
  burst of duplicate or delayed Domain Events, affecting alert timeliness for compliance
  findings.
- **Likelihood:** Medium · **Impact:** Low → **Severity:** Low.
- **Owner:** `backend-engineer`
- **Mitigation:** Idempotent consumers keyed on `eventId` (per ADR-002); alerting on
  consumer lag; documented in the Transactional Outbox relay runbook.
- **Status:** `mitigated` — moved out of Active Risks, kept for the record.
- **Phase identified:** Implement · **Review cadence:** product retrospectives.

---

## 6. Scoring checklist (before you commit an entry)

1. Is this a **standing exposure**, not a one-time question? (Apply the SKILL body's test.)
2. Both axes assigned a reasoned Low/Medium/High, each anchored to the horizon?
3. Severity **derived** from the matrix above, not hand-picked?
4. A named owner (agent role or "Shafi") who can act on it?
5. Mitigation names a **specific** action/control/monitor, not a sentiment?
6. Searched the register for an existing entry covering the same exposure?
7. Review cadence set to match the severity's row in §3?
