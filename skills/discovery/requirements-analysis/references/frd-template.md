---
name: functional-requirements-document
product: Data Estate Mapping and Compliance Intelligence
version: 1.0.0
phase: ideate
created: 2026-07-19
owner: requirements-analyst
okr-cycle: Q3 2026
---

# Functional Requirements Document

## Scope Statement

**Included:** connecting Google Drive and AWS S3 storage sources; scanning and classifying data assets by sensitivity level (Public / Internal / Confidential / Restricted); extracting entities from PDF, DOCX, and XLSX files; building the cross-source relationship graph; SOC 2 (CC6, CC7, A1) gap reporting; tenant deployment inside customer infrastructure.

**Explicitly excluded:** enforcement actions (blocking, quarantine, deletion); SharePoint and other connectors; GDPR/ISO 27001 mapping; email and endpoint scanning; any processing of customer data outside the customer's infrastructure boundary.

## Requirements by Functional Area

### Area 1 — Source Connection

| ID | Requirement | Source | Priority | Test Approach |
|---|---|---|---|---|
| REQ-001 | The Compliance Officer must be able to connect a Google Drive tenant via OAuth in a guided flow, without IT assistance, in under 5 minutes | JS-001; Persona: Maya Chen (adoption barrier) | Must | Usability test: 3 design-partner compliance officers complete connection unaided; timer ≤ 5 min |
| REQ-002 | The IT/DevOps Lead must be able to connect an AWS S3 bucket using read-only scoped credentials | JS-004; Business rule BR-2 | Must | Integration test: connection succeeds with read-only policy; fails closed with write-scoped credentials rejected and explained |
| REQ-003 | The system must show connection health per storage source and allow re-authentication of an expired credential without data loss | Stakeholder: IT/DevOps Lead | Should | Integration test: expire a token; verify degraded-state indicator and successful re-auth preserving scan history |

### Area 2 — Scanning and Classification

| ID | Requirement | Source | Priority | Test Approach |
|---|---|---|---|---|
| REQ-010 | The system must scan all files in a connected source and classify each data asset by sensitivity level (Public / Internal / Confidential / Restricted) within 30 minutes of initial connection, for estates up to 500,000 files | OKR KR1.2 | Must | Performance test: 100,000-file test Drive; classification complete and visible in UI ≤ 30 min |
| REQ-011 | The system must extract named entities (people, organisations, identifiers) from PDF, DOCX, and XLSX file contents | Vision: entity-level intelligence | Must | Accuracy test against a labelled design-partner corpus; precision/recall thresholds per NFR |
| REQ-012 | The system must record, for every classification, the rule or signal that produced it, viewable by the Compliance Officer | Persona: Maya Chen ("evidence, not folklore") | Must | Functional test: every classified asset exposes an explanation; no asset shows "classified" without a stated reason |
| REQ-013 | The system must re-scan sources on a configurable schedule and classify newly discovered assets within one scheduled cycle | JS-005 (continuous monitoring) | Should | Integration test: add files between cycles; verify next cycle classifies them |

### Area 3 — Relationship Graph

| ID | Requirement | Source | Priority | Test Approach |
|---|---|---|---|---|
| REQ-020 | The system must link extracted entities across storage sources into one queryable relationship graph | Vision: cross-source graph (differentiator) | Must | Integration test: same entity seeded in a Drive DOCX and an S3 PDF; graph query returns both assets linked to one entity node |
| REQ-021 | The Compliance Officer must be able to query "every data asset containing entity X" and receive results across all connected sources | JS-003 (audit evidence) | Should | Functional test: query returns complete, source-attributed asset list for a known entity |

### Area 4 — Compliance Reporting

| ID | Requirement | Source | Priority | Test Approach |
|---|---|---|---|---|
| REQ-030 | The system must map discovered data assets to SOC 2 controls CC6, CC7, and A1 and present gaps prioritised by severity | OKR KR (Q4): SOC 2 audit support | Must | Functional test: seeded estate with known control violations produces the expected gap list in severity order |
| REQ-031 | The Compliance Officer must be able to export the gap report with per-gap evidence in a format acceptable to a SOC 2 auditor | Stakeholder: external auditor (beneficiary) | Should | Review test: export validated by a practising SOC 2 auditor at Stage 1 |
| REQ-032 | The gap report must show an empty state (not an error) when a scan finds no gaps | Example map US-009 | Should | Functional test: zero-gap estate renders the empty state with explanatory copy |

## Business Rules

1. **BR-1:** No file content may be transmitted outside the customer's infrastructure boundary — metadata and derived classifications only may appear in any event stream.
2. **BR-2:** All storage source credentials must be read-only; the system must never hold write permission on customer data.
3. **BR-3:** Every data asset must carry exactly one sensitivity level at any time; reclassification must be recorded with prior value, new value, timestamp, and cause.
4. **BR-4:** Compliance gap findings must be reproducible: the same estate state and rule set must always yield the same findings.

## Constraints

1. **CON-1:** Must deploy on customer-managed Kubernetes clusters via Helm chart.
2. **CON-2:** Physical tenant isolation — one deployment per customer; no shared data plane.
3. **CON-3:** Backend in Go (`net/http` + chi); PostgreSQL primary store; Apache AGE for the relationship graph; Redpanda for events — per `sdlc-config.json` defaults.
4. **CON-4:** No paid third-party APIs without explicit approval (frugality constraint).

## Assumption Log

| ID | Assumption | Impact if false | Owner |
|---|---|---|---|
| ASM-1 | Customer Google Drive estates at initial scan contain fewer than 500,000 files | REQ-010's 30-minute target requires re-scoping or staged scanning | requirements-analyst |
| ASM-2 | Customers can grant a Google Workspace OAuth app with domain-wide read scopes | Onboarding requires an admin-consent path; TTFV target at risk | requirements-analyst |
| ASM-3 | Design partners' documents are predominantly English-language | Entity extraction accuracy targets (REQ-011) may not hold; language support becomes scope | requirements-analyst |
| ASM-4 | A read-only S3 policy is acceptable to customer security teams without custom IAM review | Onboarding friction for S3; REQ-002 timing degrades | requirements-analyst |

## Open Questions

| ID | Question | Raised by | Target resolution date |
|---|---|---|---|
| OQ-1 | Are compliance gaps from prior scans shown in the report, or only the latest scan's findings? | Example mapping (US-009, red card Q1) | Before Design phase gate |
| OQ-2 | What is the maximum single-file size the extraction pipeline must handle (XLSX with 1M rows)? | requirements-analyst | Before Design phase gate |
| OQ-3 | Does "evidence export" require immutable/tamper-evident output for auditor acceptance? | Stakeholder map (auditor) | Stage 1 auditor review |

## Traceability Matrix

| OKR Key Result | Supporting REQ IDs |
|---|---|
| KR1.1 — 80% of trial users discover first compliance gap ≤ 30 min | REQ-001, REQ-002, REQ-010, REQ-030 |
| KR1.2 — Median connection-to-classification ≤ 30 min (estates ≤ 100k files) | REQ-001, REQ-010 |
| KR1.3 — Design-partner deployments completed without support contact | REQ-001, REQ-003, CON-1 |
| KR (Q4) — 5 paying customers with SOC 2 audit support delivered | REQ-030, REQ-031, REQ-020 |
