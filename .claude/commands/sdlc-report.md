# Command: /sdlc-report

## Purpose
Generate a structured summary report of the product run — what was produced, what decisions were made, what the current phase state is, and what actions are needed next. The `sdlc-report` is the PM-facing view of the factory's output. Used for sprint reviews, stakeholder updates, and audit evidence packages.

## Usage
```
/sdlc-report                             # Full product run report
/sdlc-report --phase {name}              # Report for a specific phase
/sdlc-report --type {type}               # Report type (see below)
/sdlc-report --since {date}              # Changes since a date
```

## Report Types
| Type | Description |
|------|-------------|
| `progress` | Default — phase progress, artifact counts, DoD status, next steps |
| `compliance` | Compliance posture across all frameworks — for audit or board |
| `risk` | Open threats, compliance gaps, security findings — risk register view |
| `decisions` | All ADRs, their status and rationale — architecture decision log |
| `quality` | Test coverage, security gate, compliance gate — quality posture |
| `full` | All of the above in one document |

## Execution

### `/sdlc-report` (progress — default)

```
Read: sdlc-manifest.json
Read: sdlc-config.json
Read: artifacts/ directory structure

Output:
════════════════════════════════════════════════════════════════
Product Run Report — {product_name}
Generated: {date}
════════════════════════════════════════════════════════════════

## Overview
Product:   {product_name} ({sdlc-config.product_codename})
Started:   {manifest.started_at}
Phase:     {current_phase} ({phase_number}/8)
Status:    {IN PROGRESS | COMPLETE}

## Phase Progress

Phase 1: Strategy     ████████████ COMPLETE  8 artifacts  0 gaps
Phase 2: Ideate       ████████████ COMPLETE  24 artifacts 1 gap (acknowledged)
Phase 3: Design       ████████████ COMPLETE  30 artifacts 0 gaps
Phase 4: Implement    ████████████ COMPLETE  15 artifacts 2 gaps (acknowledged)
Phase 5: Data     ◄── ████████░░░░ IN PROG   5/7 artifacts
Phase 6: Quality      ░░░░░░░░░░░░ PENDING
Phase 7: Deploy       ░░░░░░░░░░░░ PENDING
Phase 8: Validate     ░░░░░░░░░░░░ PENDING

## Artifacts Produced
Total: {N} artifacts across {N} phases

By phase:
  Strategy:   8 artifacts
  Ideate:     24 artifacts
  Design:     30 artifacts
  Implement:  15 artifacts
  Data:       5 artifacts (2 remaining)
  
## Current Phase Status (Data)
Completed: data-model-spec (3 entities), analytics-requirements, dashboard-spec, data-pipeline-design, data-quality-rules
Remaining: reporting-spec, data-storytelling

DoD: 5/7 required artifacts complete
Next: /sdlc-artifact data/reporting-spec compliance-posture-summary

## Acknowledged Gaps
Phase 2 — Ideate:
  • MoSCoW prioritisation not produced (acknowledged 2026-06-18)
Phase 4 — Implement:
  • BDD feature files not generated for 2 stories (acknowledged 2026-06-19)
  • Service scaffold for audit-domain pending (acknowledged 2026-06-19)

## Next Actions
1. Generate remaining Data phase artifacts:
   /sdlc-artifact data/reporting-spec compliance-posture-summary
   /sdlc-artifact data/data-storytelling board-executive
2. Advance to Quality phase:
   /sdlc-next
3. Generate Quality phase artifacts (11 skills available):
   /sdlc-phase 6 to see full skill list
════════════════════════════════════════════════════════════════
```

---

### `/sdlc-report --type decisions`

```
Architecture Decision Log — {product_name}
────────────────────────────────────────────

ADR-001  Use PostgreSQL for ACID Store              Accepted   2026-06-10
ADR-002  Use Redpanda for Event Streaming           Accepted   2026-06-10
ADR-003  Hexagonal Architecture Pattern             Accepted   2026-06-11
ADR-004  Physical Multi-Tenancy (per-tenant cluster) Accepted  2026-06-12
ADR-005  JWT + mTLS for Authentication              Accepted   2026-06-12
ADR-006  Transactional Outbox for Event Publishing  Accepted   2026-06-13
ADR-007  ABAC for Authorisation                     Accepted   2026-06-14
ADR-008  Apache AGE for Graph (Data Lineage)        Accepted   2026-06-14
ADR-009  OpenTofu + Helm for IaC                    Accepted   2026-06-15

Rejected alternatives on record: 3 (MySQL, RabbitMQ, ORM-based persistence)
Open decisions (no ADR): 0

Full ADR details: artifacts/design/adrs/
```

---

### `/sdlc-report --type risk`

```
Risk Register — {product_name}
────────────────────────────────────────────

Open Threats (from threat model):
  T-D-04  DoS       API Gateway       HIGH    14 days  Mitigation: rate limiting [IN DESIGN]
  T-I-06  InfoDisc  Worker Node link  MEDIUM   3 days  Mitigation: mTLS [IMPLEMENTED]

Compliance Gaps:
  GDPR Art.20  Data Portability  HIGH  Not implemented  Target: Validate phase

Security Gate:
  Last run: {date}  Result: CONDITIONAL
  Open finding: trivy MEDIUM in base image (tracking #142)

Overall risk posture: MEDIUM
```

### Step: Write report artifact

**File:** `artifacts/core/reports/sdlc-report-{type}-{YYYY-MM-DD}.md`
**Registers in manifest:** yes
