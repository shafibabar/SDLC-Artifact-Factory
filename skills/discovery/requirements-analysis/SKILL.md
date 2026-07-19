---
name: requirements-analysis
description: >
  Teaches how to elicit, structure, validate, and document functional requirements
  from a vision, stakeholder inputs, and business goals. Covers elicitation
  techniques, requirement formatting, traceability to business goals, assumption
  logging, and gap analysis. Produces a Functional Requirements Document (FRD)
  that is the authoritative input to the Design phase. Used by the
  requirements-analyst agent during the Ideate phase.
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, functional-requirements, frd, traceability, product-discovery]
---

# Requirements Analysis

## Purpose

Requirements analysis transforms the vision, mission, OKRs, and stakeholder context from the Strategy phase into a structured, traceable set of functional requirements — what the system must do. These requirements constrain and direct the Design and Implement phases.

A requirement that cannot be traced to a business goal, OKR, or user need has no justified place in the product. A requirement that cannot be tested has no place in the backlog.

---

## Requirement Types

| Type | Definition | Example |
|---|---|---|
| **Functional** | What the system must do — behaviours and capabilities | "The system must scan a connected Google Drive and classify all files by sensitivity within 30 minutes" |
| **NFR (Non-Functional)** | How well the system must do it | See `nfr-specification` skill |
| **Business rule** | A constraint imposed by the business or domain | "No file content may be transmitted outside the customer's infrastructure boundary" |
| **Constraint** | A fixed boundary on solution options | "Must deploy on customer-managed Kubernetes clusters" |
| **Assumption** | A condition assumed to be true that, if false, would invalidate one or more requirements | "Assumes customer has network access between worker nodes and their Google Drive tenant" |

Functional requirements analysis owns all five types. NFRs have a dedicated skill.

---

## Elicitation Techniques

Apply in order — do not write requirements from memory or assumptions alone:

| Technique | When to use | Output |
|---|---|---|
| **Problem statement analysis** | First — extract implied requirements from the problem statement and vision | Raw requirements list |
| **OKR decomposition** | Derive requirements from Key Results — each KR implies capabilities the system must have | KR-to-requirement traceability |
| **JTBD analysis** | Extract requirements from job stories — every motivation and outcome implies a capability | Capability requirements |
| **Stakeholder interview (simulated)** | For each "Manage Closely" stakeholder, reason through their needs and pain points | Stakeholder-specific requirements |
| **Competitive analysis review** | Identify capabilities competitors have that your ICP expects as table stakes | Baseline requirements |
| **Assumption surfacing** | For each requirement, ask: "What must be true for this to be valid?" | Assumption log |

---

## Requirement Format

Every requirement must be written using this structure:

```
REQ-[ID]: [Actor] must be able to [action] [object] [qualifier/constraint].

Source:     [OKR KR / stakeholder / user persona / business rule]
Priority:   [Must / Should / Could — from MoSCoW]
Assumption: [What must be true for this requirement to be valid — if any]
Test:       [How will this requirement be verified?]
```

**Example:**
```
REQ-001: The system must scan all files in a connected Google Drive and classify
         each file by sensitivity level within 30 minutes of initial connection.

Source:     OKR KR1 — "80% of trial users reach first value within 30 minutes"
Priority:   Must
Assumption: Customer's Google Drive contains fewer than 500,000 files at initial scan
Test:       Integration test: connect a test Drive with 100,000 files; verify
            classification completes and is visible in UI within 30 minutes.
```

---

## Traceability

Every requirement must trace to at least one of:
- A named OKR Key Result
- A named user persona's stated goal or frustration
- A Job Story (JTBD)
- A stakeholder concern from the stakeholder map
- A business rule or regulatory constraint

Requirements with no traceable source are candidates for removal. Record the gap in the assumption log.

---

## Gap Analysis

After drafting the requirements set, run gap analysis against the strategic artifacts:

| Check | Question |
|---|---|
| OKR coverage | Does at least one requirement support every Key Result? |
| Persona coverage | Does at least one requirement address each primary persona's core job? |
| Constraint coverage | Is every known deployment constraint captured as a constraint-type requirement? |
| Business rule coverage | Are all known business rules (data residency, compliance obligations) captured? |
| Negative space | What has been explicitly NOT included — and is that documented? |

Gaps found during gap analysis become open questions. Log them and resolve with Shafi before the Ideate phase closes.

---

## Step-by-Step Production

1. Read strategy phase artifacts: vision, mission, OKRs, GTM strategy, stakeholder map, competitive analysis.
2. Read user personas and JTBD analysis (produced earlier in this phase).
3. Apply each elicitation technique in order. Capture every raw requirement, no matter how rough.
4. Format each requirement using the standard format above.
5. Assign a unique ID (REQ-001, REQ-002...) and a MoSCoW priority.
6. Trace each requirement to its source.
7. Run gap analysis against all strategic artifacts.
8. Log all unresolved questions and assumptions.
9. Group requirements by functional area (e.g. Data Ingestion, Classification, Compliance Reporting, User Management, Deployment).
10. Produce the FRD in the output format below.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Traceability | Every requirement links to a source | Any requirement with no stated source |
| Testability | Every requirement has a stated test approach | Any requirement that cannot be objectively verified |
| Specificity | Requirements name actors, actions, and measurable qualifiers | Vague requirements ("the system should be fast") |
| Completeness | Gap analysis shows no uncovered OKR KRs | Key Results with no supporting requirements |
| Assumption logging | All assumptions are explicitly documented | Requirements that depend on unstated conditions |
| Negative space | Out-of-scope is explicitly documented | Scope ambiguity that will cause disputes later |

---

## Anti-Patterns

**Solution smuggled into a requirement:** "The system must store classifications in PostgreSQL." Unless it is a genuine constraint imposed from outside (customer mandate, regulatory rule), technology choices belong to the Design phase. Write the capability ("classifications must survive restarts and be queryable within 1 second"), and let architecture decide the means.

**Compound requirement:** "The system must scan Google Drive and S3 and produce a gap report." Three separately verifiable capabilities in one ID means one test result cannot tell you which capability failed. One requirement, one verifiable behaviour — split it.

**Unbounded qualifier:** "classify files quickly", "handle large estates". Every qualifier needs a number and a condition ("within 30 minutes for estates up to 500,000 files") or it belongs in the open questions, not the FRD.

**Memory-sourced requirements:** skipping the elicitation techniques and writing requirements from general knowledge of "what compliance products need." Every requirement invented this way is an untracked assumption; the elicitation order exists precisely to force each requirement through a traceable source.

**Gold-plating by momentum:** keeping a requirement with no traceable source because "it's cheap to build" or "competitors have it." Cheap-to-build is not a source. Either trace it (competitive analysis table-stakes counts as a source) or cut it.

**Assumption laundering:** stating an assumption inside the requirement text ("assuming the customer grants OAuth access, the system must…") instead of the assumption log. Assumptions buried in prose are never revisited when they break.

---

## Output Format

```markdown
---
name: functional-requirements-document
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
okr-cycle: [cycle]
---

# Functional Requirements Document

## Scope Statement
[What is included. What is explicitly excluded.]

## Requirements by Functional Area

### [Area 1 — e.g. Data Ingestion]
| ID | Requirement | Source | Priority | Test Approach |
|---|---|---|---|---|

### [Area 2 — e.g. Classification Engine]
[Repeat]

## Business Rules
[Numbered list of business rules that constrain the solution space]

## Constraints
[Numbered list of fixed constraints on implementation]

## Assumption Log
| ID | Assumption | Impact if false | Owner |
|---|---|---|---|

## Open Questions
| ID | Question | Raised by | Target resolution date |
|---|---|---|---|

## Traceability Matrix
| OKR Key Result | Supporting REQ IDs |
|---|---|
```

See `references/frd-template.md` for a fully worked example.
