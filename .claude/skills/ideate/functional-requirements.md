# Skill: ideate/functional-requirements

## Purpose
Produce a structured Functional Requirements Document (FRD) — the authoritative list of what the system must do. Requirements are written as verifiable statements grounded in user goals, not as implementation instructions.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `artifacts/strategy/roadmap.md` — recommended
- `sdlc-config.json` — product_name, compliance_frameworks, sensitive_data_types

## Output
**File:** `artifacts/ideate/requirements/functional.md`
**Registers in manifest:** yes

## Requirements Writing Rules (enforced)
- Every requirement is written as: "The system SHALL {observable behaviour} so that {user/business outcome}."
- No implementation detail in requirements — "The system SHALL encrypt data" not "The system SHALL use AES-256-GCM".
- Requirements are atomic: one SHALL per requirement statement.
- Requirements are verifiable: a tester can confirm the requirement is met or not met.
- Requirements are numbered hierarchically: FR-01, FR-01.1, FR-01.2, FR-02, etc.
- Compliance-driven requirements are explicitly tagged [COMPLIANCE: {framework}].

## Process
1. Read vision, roadmap, and config.
2. Identify functional domains (e.g. Authentication, Data Ingestion, Entity Extraction, Compliance Reporting).
3. For each domain, list all functional requirements.
4. Tag compliance-driven requirements with their framework reference.
5. Check each requirement against the writing rules — rewrite any that violate them.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Functional Requirements Document

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** Functional Requirements Document
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Scope
{One paragraph: what system or product this document covers, what phases of the roadmap are in scope (typically Phase 1 / MVP), and what is explicitly deferred.}

## Functional Domains

### FR-01: {Domain Name — e.g. User Authentication}

| ID | Requirement | Priority | Compliance tag |
|----|-------------|----------|----------------|
| FR-01.1 | The system SHALL authenticate users via OAuth 2.0 so that access is delegated to the customer's existing identity provider. | MUST | |
| FR-01.2 | The system SHALL issue short-lived JSON Web Tokens upon successful authentication so that session exposure is minimised. | MUST | [COMPLIANCE: SOC2-CC6] |
| FR-01.3 | The system SHALL revoke all active sessions for a user upon explicit logout so that unauthorised continued access is prevented. | MUST | |

### FR-02: {Domain Name — e.g. Storage Registration}

| ID | Requirement | Priority | Compliance tag |
|----|-------------|----------|----------------|
| FR-02.1 | The system SHALL allow administrators to register cloud storage locations so that those locations are included in crawl scope. | MUST | |
| FR-02.2 | The system SHALL validate that registered storage credentials have at minimum read-only scope so that the principle of least privilege is enforced. | MUST | [COMPLIANCE: SOC2-CC6] |

### FR-03: {Domain Name}
{continue pattern for all domains}

---

## Requirements Summary

| Priority | Count |
|----------|-------|
| MUST (non-negotiable for MVP) | {n} |
| SHOULD (strong preference, deferrable) | {n} |
| COULD (nice to have) | {n} |
| WON'T (explicitly excluded from this scope) | {n} |

## Compliance Requirements Index

| Requirement ID | Framework | Clause | Requirement summary |
|---------------|-----------|--------|---------------------|
| FR-01.2 | SOC 2 | CC6.1 | Short-lived session tokens |
| {FR-xx.x} | {framework} | {clause} | {summary} |

## Open Questions
{List any requirements that need clarification from stakeholders before they can be finalised.}

| # | Question | Owner | Target resolution date |
|---|----------|-------|----------------------|
| Q1 | {question} | {stakeholder} | {date} |
```

## Quality Checks
Before writing:
- [ ] Every requirement follows the "SHALL ... so that ..." format
- [ ] No implementation detail in any requirement statement
- [ ] All compliance-tagged requirements reference a specific framework clause
- [ ] All requirements are verifiable (a tester can confirm pass/fail)
- [ ] MUST / SHOULD / COULD / WON'T priorities are applied to all requirements
- [ ] No undefined ubiquitous language terms
