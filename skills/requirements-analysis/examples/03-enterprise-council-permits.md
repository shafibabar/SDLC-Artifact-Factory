# Example 3 — Enterprise: a multi-tenant legacy replacement with conflicting departments, per-tenant migration and regulatory rules (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant; three pilot councils are replacing a fifteen-year-old on-premises permits system, each with its own data and its own cut-over date. Councils are public bodies: records retention and data-protection law apply, and the service must stay up during a council's office hours because applicants have statutory deadlines. At the **enterprise** profile the FRD is **required** and carries the full shell: a typed business-rules catalogue, disfavoured user classes, external interfaces, data requirements, a transition plan per tenant, recorded conflicts, forward-trace columns and a change log.

## Input

> **Impact map (ideate/impact-maps/complete-first-submissions.md, approved):** KR-1.2 "Share of applications valid on first submission, 41% → 70% by 2027-09-30". Selected path: applicant (agent or householder, P-1, P-2) → submits a complete application first time instead of waiting for a "missing documents" letter → OPP-1.1 "I only find out what's missing weeks later" → **SOL-1** document checklist generated from the application type and site; **SOL-2** pre-submission validation of drawings (scale, north point, red line). Blocker: the validation officer (P-3) who re-checks everything by hand → stops re-checking what the system already validated → **SOL-4** a validation report attached to each application. Options: a paid pre-application advice booking (SOL-3); chat help.
>
> **JTBD analysis (approved):** J-1 "get permission to build without delays I could have avoided" (applicant) with JS-1.1 "When I start an application, I want to know every document this site needs, so I don't get a missing-documents letter" and JS-1.2 "When I upload drawings, I want to know straight away if they will be rejected, so I can fix them while the architect is still on the job"; J-3 "decide applications within the statutory period" (council officers) with JS-3.1 "When an application arrives, I want to know what has already been checked, so I only check what needs judgement".
>
> **Stakeholder map:** planning department and building control department of each council. **Documents supplied:** the legacy system's data dictionary and a sample export from pilot council A. **Not heard from:** building control at councils B and C.
>
> **Configured stack:** the plugin defaults (`sdlc-config.json`).

## Working it

- **URs per selected deliverable**: SOL-1 and SOL-2 for applicants, SOL-4 for validation officers. SOL-3 and chat help are options: waiting room.
- **User classes include the disfavoured ones.** Staff of another council (tenant isolation), an applicant viewing someone else's application, and an anonymous member of the public (who may see the public register only). These produce access requirements nobody asked for.
- **A conflict between departments.** Planning wants every checklist item mandatory before submission; building control (at council A) wants submission allowed with items outstanding because some certificates come later. The analyst does not choose: it records the conflict with a recommendation and the user decides.
- **Unheard departments are assumptions.** Building control at B and C were not consulted; their checklist needs are ASM-2 with the question the user should ask, not an invented interview.
- **Regulatory rules are business rules**, catalogued with their source; `nfr-specification` cites them for retention, residency and availability targets. The configured stack is not a constraint.
- **Transition per tenant**: each council has its own migration, parallel run and decommission, and an archive of closed cases under the retention rule.

## Output — `ideate/requirements.md` (abridged to two URs and the enterprise-only parts)

````markdown
---
name: functional-requirements-document
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-12
summary: Requirements for Permitry's complete-first-submission path (SOL-1, SOL-2, SOL-4) across tenant councils, with per-council legacy migration and statutory rules.
profile: enterprise
status: draft
linked-kr: KR-1.2
linked-impact-map: ideate/impact-maps/complete-first-submissions.md
linked-jtbd: ideate/jtbd-analysis.md
traces_to: strategy/okrs.md (KR-1.2); ideate/impact-maps/complete-first-submissions.md (SOL-1, SOL-2, SOL-4); ideate/jtbd-analysis.md (J-1, JS-1.1, JS-1.2, J-3, JS-3.1); ideate/user-personas.md (P-1…P-3); strategy/stakeholder-map.md
---

# Functional Requirements — Permitry

**Translation.** The selected path of the complete-first-submissions map (SOL-1, SOL-2, SOL-4), job stories JS-1.1, JS-1.2 and JS-3.1, and the legacy system's data dictionary become requirements for `nfr-specification`, `epic-definition`, `domain-modeler` and `enterprise-architect`.

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`. Value and penalty are scored 1–9 from the traced source; cost and risk are left for epic sizing.

## Scope and Exclusions

**In scope:** document checklists (SOL-1), drawing pre-validation (SOL-2), a validation report for officers (SOL-4), for the three pilot councils, including their migration off the legacy system.

**Excluded:** decision notices and appeals (later cycle); fee payment changes (the legacy payment interface is kept as-is); pre-application advice booking (option SOL-3).

**Business requirements (cited):** KR-1.2; strategy kernel coherent action CA-2 "make the first submission the last".

## User Classes

| User class | Favoured / disfavoured / ignored | Persona | Champion |
|---|---|---|---|
| Planning agent submitting for clients | favoured | P-1 | design partner: agent at council A's largest practice |
| Householder | favoured | P-2 | the product owner |
| Validation officer (per council) | favoured | P-3 | design partner: council A validation lead |
| Staff of another council | disfavoured | — | the product owner |
| Applicant viewing another applicant's application | disfavoured | — | the product owner |
| Member of the public | disfavoured beyond the public register | — | the product owner |

## User and Functional Requirements

### UR-1: An applicant must be able to see every document their application type and site require before submitting

- **Traces to:** deliverable SOL-1 (selected path, ideate/impact-maps/complete-first-submissions.md) · job J-1 "get permission to build without delays I could have avoided" → job story JS-1.1 · KR-1.2
- **Rationale:** missing documents are the commonest reason a first submission is invalid (legacy export, council A, 2025).

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) | Status | Story | AC | Test |
|---|---|---|---|---|---|---|---|---|---|
| FR-1.1 | The system must generate a document checklist from the application type and the site's designations | For each of the 24 type × designation cases in council A's validation guide, the checklist equals the guide's list | Acceptance test | BR-1, BR-2 | high (value 9, penalty 8) | proposed | — | — | — |
| FR-1.2 | The system must use the checklist rules of the tenant council the site belongs to | A site in council B gets council B's list in all 24 cases; no case shows another council's list | Acceptance test | BR-2, BR-6 | high (value 7, penalty 9) | proposed | — | — | — |

### UR-2: A validation officer must be able to see what the system has already validated on each application

- **Traces to:** deliverable SOL-4 (selected path, blocker branch, ideate/impact-maps/complete-first-submissions.md) · job J-3 "decide applications within the statutory period" → job story JS-3.1 · KR-1.2
- **Rationale:** officers re-check everything by hand; the impact is that they stop re-checking what was validated.

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) | Status | Story | AC | Test |
|---|---|---|---|---|---|---|---|---|---|
| FR-2.1 | The system must attach a validation report to each submitted application listing each check, its result and the rule applied | For 40 seeded applications, every report lists all checks run, each pass/fail matching the seeded defects, with the BR-ID applied | Acceptance test | BR-1, BR-3 | high (value 8, penalty 7) | proposed | — | — | — |
| FR-2.2 | Only officers of the council that owns the application must be able to open its report | Officers of council B are refused council A's reports in all 20 attempts, and each refusal is recorded | Acceptance test | BR-6; QA-2 | high (value 6, penalty 9) | proposed | — | — | — |

<!-- UR-3 (SOL-2, drawing pre-validation, JS-1.2) omitted here for length. -->

## Business Rules

| ID | Rule | Kind | Source | Cited by |
|---|---|---|---|---|
| BR-1 | The documents required for each application type are those in the council's local validation list | fact | Each council's published local validation list | FR-1.1, FR-2.1 |
| BR-2 | A site inside a conservation area also requires a heritage statement | inference | National planning guidance | FR-1.1, FR-1.2 |
| BR-3 | An application is valid only when every required document is present and drawings carry scale, north point and site boundary | constraint | National validation requirements | FR-2.1 |
| BR-4 | Decided case records are kept for 15 years after decision | constraint | Councils' records retention schedule | DR-1, TR-4 |
| BR-5 | Applicant personal data is processed and stored only in the UK | constraint | Data-protection law as applied by the councils' contracts | IF-2, DR-1 |
| BR-6 | Each council's data and configuration belong to that council alone | fact | Tenant contracts | FR-1.2, FR-2.2 |

## Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-1 | Fee payments keep using each council's existing payment provider | Councils' payment contracts |
| CON-2 | Site designations come from each council's own GIS layer | Councils (they own the data) |

## External Interfaces and Data

| ID | Interface or data requirement | Direction / retention | Source |
|---|---|---|---|
| IF-1 | Council GIS: site designations for a site boundary | in | CON-2 |
| IF-2 | Legacy permits system export (per council) | in, during transition only | TR-1 |
| IF-3 | National planning portal: applications submitted there | in | Stakeholder map |
| DR-1 | Application, documents, validation report and decision kept per case | 15 years after decision (BR-4); UK only (BR-5) | BR-4, BR-5 |

## Transition Requirements

| ID | Requirement | Kind | Fit criterion |
|---|---|---|---|
| TR-1 | Each council's open cases migrate from the legacy system with documents | data migration | Per council: case count, document count and checksum totals match the legacy export; zero cases without an applicant |
| TR-2 | Each council runs four weeks in parallel, the legacy system remaining the record | parallel run | Weekly reconciliation shows zero unexplained differences in validity decisions for the last two weeks |
| TR-3 | Each council has a rollback point until the end of its parallel run | cutover and rollback | A rehearsal restores council A to legacy-as-record within one working day |
| TR-4 | Closed legacy cases are archived under BR-4 before the legacy system is switched off | decommission | Archive holds every closed case of the last 15 years; a sample of 50 opens with its documents |
| TR-5 | Validation officers at each council are trained on the validation report | training | Every officer validates three sample applications unaided |

## Quality-Attribute Hand-off (to `nfr-specification`)

| ID | Quality concern | Constrains | Why it matters here |
|---|---|---|---|
| QA-1 | Availability during each council's office hours | All URs | Applicants have statutory deadlines |
| QA-2 | Tenant isolation and access control | FR-1.2, FR-2.2 | BR-6; disfavoured classes |
| QA-3 | Responsiveness of checklist generation on a slow GIS | FR-1.1 | IF-1 is outside our control |
| QA-4 | Data residency and retention, verifiable | DR-1 | BR-4, BR-5 |

## Conflicts

| ID | Requirements | Who wants what | Recommendation | Decision (user, date) |
|---|---|---|---|---|
| CF-1 | Candidate FR-1.3 (submit with items "to follow") vs BR-3 | Planning (all councils): every item mandatory before submission. Building control (council A): allow "to follow" for certificates issued later | A per-tenant, per-document setting; "to follow" items listed on the validation report so officers see them | pending |

## Assumption Log

| ID | Assumption | Requirements that depend on it | Impact if false | How it will be confirmed |
|---|---|---|---|---|
| ASM-1 | Councils' GIS layers expose designations for a boundary | FR-1.1, IF-1 | Checklists miss designations; manual entry needed | Integration spike per council |
| ASM-2 | Building control at councils B and C needs the same "to follow" items as council A | candidate FR-1.3 | CF-1's setting must vary by more than document | The user asks B and C's building control: "Tell me about the last application you validated with a certificate still to come" |

## TBD List

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | CF-1 decision; FR-1.3 is written only once it is made | candidate FR-1.3 | the product owner | Before the Design phase gate |
| TBD-2 | Does the legacy export include superseded document versions? | TR-1 | Council A IT | Before TR-1 is rehearsed |

## Waiting Room

| Item | Reason deferred | Would return if |
|---|---|---|
| Pre-application advice booking (SOL-3) | Option on the map | Validity stays under 55% at the re-plan date |
| Chat help | Option on the map | — |
| Bulk export of all applications for planning agents | A want from P-1's practice; fails the necessity test for KR-1.2 | A later KR on agent productivity |

## Traceability

| Source | Served by |
|---|---|
| SOL-1 (selected path) | UR-1 |
| SOL-2 (selected path) | UR-3 |
| SOL-4 (selected path) | UR-2 |
| JS-1.1 | UR-1 |
| JS-1.2 | UR-3 |
| JS-3.1 | UR-2 |
| KR-1.2 | UR-1, UR-2, UR-3 |

Forward columns (Story, AC, Test) are in the requirement tables and are filled as `user-story-writing`, `acceptance-criteria` and the Quality phase write them.

## Change Log

| Version | Date | Change | Reason | Impact | Decided by |
|---|---|---|---|---|---|
| 1.0.0 | 2026-11-12 | First draft | Ideate, cycle 1 | — | awaiting the user |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| Disfavoured user classes | Tenant isolation and access requirements come from them (Wiegers) |
| Conflict recorded, not resolved | The user decides between departments; candidate FR-1.3 stays on the TBD list, not in the table, until then |
| Unheard councils as an assumption with a past-tense question | No interview was simulated |
| Statutory rules as BR rows | One home; `nfr-specification` cites BR-4 and BR-5 for its targets |
| Configured stack not a constraint | Only limits imposed from outside are constraints |
| Transition per council | Migration, parallel run, rollback, archive and training each have a fit criterion |
| Forward-trace columns from the start | The Quality phase audit reads them |
| Value and penalty scores, labelled provisional | MoSCoW finalises priority later |
