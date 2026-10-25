# Example 3 — Enterprise: a cross-context "onboard a council" epic split by outcome, transition epics per tenant (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant; three pilot councils (A, B, C) are replacing a fifteen-year-old on-premises permits system, each with its own data, rules and cut-over date. Records retention, UK data residency and office-hours availability apply. At the **enterprise** profile the epic list is **required** and carries: epics grouped by impact map and roadmap Theme, value and penalty scores, transition epics per tenant, a cross-context flag table and a forward-trace column.

## Input

> **User:** "Add an epic 'Onboard a council': tenant setup, single sign-on, their checklist rules, the GIS connection and migrating their cases. Split it into a Tenant Service epic, a Rules Engine epic, a GIS Adapter epic and a Migration Service epic so each team owns one."
>
> **Impact map (ideate/impact-maps/complete-first-submissions.md, approved):** KR-1.2 "Share of applications valid on first submission, 41% → 70% by 2027-09-30". Selected path: applicant → submits a complete application first time → OPP-1.1 → **SOL-1** document checklist from application type and site; **SOL-2** pre-submission drawing validation. Blocker: validation officer → stops re-checking what the system validated → **SOL-4** validation report. Options: SOL-3 paid pre-application advice; chat help.
>
> **Roadmap (strategy/roadmap.md):** Theme "I only find out what's missing weeks later" (Now), serving KR-1.2.
>
> **JTBD analysis:** J-1 "get permission to build without delays I could have avoided" with JS-1.1 (know every document this site needs) and JS-1.2 (know straight away if drawings will be rejected); J-3 "decide applications within the statutory period" with JS-3.1 (know what has already been checked).
>
> **FRD (ideate/requirements.md):** UR-1 (SOL-1; FR-1.1 checklist from type and designations, value 9 / penalty 8; FR-1.2 the site's own council's rules, 7 / 9); UR-2 (SOL-4; FR-2.1 validation report, 8 / 7; FR-2.2 only the owning council's officers open it, 6 / 9); UR-3 (SOL-2, drawing pre-validation). BR-1 to BR-7 (BR-4 15-year retention, BR-5 UK only, BR-6 each council's data is its own). TR-1 migrate open cases, TR-2 four-week parallel run, TR-3 rollback point, TR-4 archive closed cases, TR-5 officer training, all per council. CF-1 (submit with items "to follow") pending; ASM-1 councils' GIS layers expose designations.
>
> **NFR specification:** architecture hand-off rated (H, H): NFR-REL-03 (GIS failure must not block submission), NFR-SEC-01 (no cross-council disclosure), NFR-PERF-02 (one council's migration must not slow the others); NFR-FLEX-01 (3 → 40 councils) rated (M, H).

## Working it

- **"Onboard a council" is the everything epic, and it crosses at least four Bounded Contexts** (Tenancy and Identity, Validation Rules, Case Records, the council's GIS). Its "done" is "the council is live", which cannot fail informatively.
- **The proposed split is a per-service split.** A Tenant Service, Rules Engine, GIS Adapter and Migration Service epic each deliver nothing an applicant or officer can observe, and none has a hypothesis that could fail. It is the layer-cake split at service scale, and it would hide from the domain-modeler exactly the coupling it needs to see. Team ownership is a Design decision that follows the Bounded Contexts, not the reverse.
- **Split by outcome instead.** What does each user class get? Applicants get their council's checklist (already EPIC-1: FR-1.2 is there); staff and applicants see only their council's work (EPIC-4); each council's open cases continue without loss (EPIC-5A/B/C, **one per council**, because each has its own data, cut-over date and rollback point). The GIS connection is part of EPIC-1's outcome, with a spike. Single sign-on is a story under EPIC-4.
- **What still crosses is flagged, not hidden.** Tenant isolation must hold in every context; migration reads a legacy system. Both go to the domain-modeler as questions.
- **A transition epic traces to TR-n** and to the deliverables whose go-live at that council it enables.
- **CF-1 is not decided**, so no story for "submit with items to follow" is listed; EPIC-1 notes it.
- **Value and penalty from the FRD**, labelled provisional. MoSCoW finalises.

## Output — `ideate/epics.md` (abridged: EPIC-1, EPIC-4 and EPIC-5A in full)

````markdown
---
name: epic-list
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-14
summary: Permitry epics for complete first submissions (SOL-1, SOL-2, SOL-4), tenant isolation and a migration epic per pilot council, with cross-context flags for the domain-modeler.
profile: enterprise
status: draft
linked-kr: KR-1.2
linked-impact-map: ideate/impact-maps/complete-first-submissions.md
linked-jtbd: ideate/jtbd-analysis.md
linked-requirements: ideate/requirements.md
traces_to: strategy/okrs.md (KR-1.2); strategy/roadmap.md (Theme "I only find out what's missing weeks later"); ideate/impact-maps/complete-first-submissions.md (SOL-1, SOL-2, SOL-4); ideate/jtbd-analysis.md (J-1, JS-1.1, JS-1.2, J-3, JS-3.1); ideate/requirements.md (UR-1–UR-3, TR-1–TR-4)
---

# Epic List — Permitry

**Translation.** The complete-first-submissions map's selected path, the FRD's user requirements and the per-council transition requirements become six epic shapes for `user-story-writing`, `story-mapping`, the domain-modeler and `enterprise-architect`. The proposed "Onboard a council" epic is split by outcome, not by service.

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`. Value and penalty are 1–9, carried from the FRD. Sizes are structural (S = 3–4 stories, M = 5–7, L = 8–10).

## Impact map: complete-first-submissions (KR-1.2) · Theme: "I only find out what's missing weeks later"

| ID | Epic (outcome) | Deliverable / TR | Job story | URs / TRs | Bounded Context | Priority (provisional) | Size | Stories |
|---|---|---|---|---|---|---|---|---|
| EPIC-1 | Applicants know every document their site needs before submitting | SOL-1 | JS-1.1 | UR-1 (FR-1.1, FR-1.2) | Validation Rules (flagged) | value 9, penalty 9 | M +spike | — |
| EPIC-2 | Applicants fix drawing problems while the architect is still on the job | SOL-2 | JS-1.2 | UR-3 | Submission | value 8, penalty 6 | M | — |
| EPIC-3 | Validation officers check only what needs judgement | SOL-4 | JS-3.1 | UR-2 (FR-2.1) | Validation | value 8, penalty 7 | S | — |
| EPIC-4 | Each council's staff and applicants see only that council's work | SOL-1, SOL-4 (all councils) | JS-3.1 | UR-2 (FR-2.2) | Tenancy and Identity (flagged) | value 6, penalty 9 | M | — |

## Per-council transition (TR-1–TR-4)

| ID | Epic (outcome) | Deliverable / TR | Job story | URs / TRs | Bounded Context | Priority (provisional) | Size | Stories |
|---|---|---|---|---|---|---|---|---|
| EPIC-5A | Council A's open cases continue in Permitry without loss | TR-1–TR-4 (council A); enables SOL-1, SOL-2, SOL-4 at A | JS-3.1 | TR-1–TR-4 | Case Records (flagged) | value 7, penalty 9 | S | — |
| EPIC-5B | Council B's open cases continue in Permitry without loss | TR-1–TR-4 (council B) | JS-3.1 | TR-1–TR-4 | Case Records (flagged) | value 7, penalty 9 | S | — |
| EPIC-5C | Council C's open cases continue in Permitry without loss | TR-1–TR-4 (council C) | JS-3.1 | TR-1–TR-4 | Case Records (flagged) | value 7, penalty 9 | S | — |

The Stories column is the forward trace, filled by `user-story-writing`.

## Epics

### EPIC-1: Applicants know every document their site needs before submitting

As a result of this epic, an applicant will be able to see, before submitting, every document their application type and site require under their own council's validation list.

**Hypothesis:** If applicants get a checklist built from their application type and site, we believe they will submit complete applications first time instead of waiting for a "missing documents" letter, shown by first-submission validity rate per council, which moves KR-1.2.

**Traces to:** deliverable SOL-1 (selected path, ideate/impact-maps/complete-first-submissions.md) · job J-1 "get permission to build without delays I could have avoided" → job story JS-1.1 · UR-1 (FR-1.1, FR-1.2) · KR-1.2
**Personas:** P-1 planning agent, P-2 householder (primary); P-3 validation officer
**Bounded Context (candidate):** Validation Rules

**Risks:** value — assumed (missing documents are the commonest invalidity reason in council A's 2025 export; whether a checklist changes behaviour is untested: the tree's T-n before Design) · usability — assumed (householders understand designation-driven items; the user runs a five-person walkthrough) · feasibility — assumed (ASM-1: each council's GIS exposes designations; integration spike per council; NFR-REL-03 rated H) · viability — low (councils already publish the lists, BR-1)

**Epic acceptance criteria:**
- [ ] The checklist for a site equals the owning council's local validation list for that application type and designation (BR-1, BR-2). *Example: a householder extension inside a council B conservation area lists council B's documents plus a heritage statement.*
- [ ] A site is always checked against the council it belongs to, never another (BR-6). *Example: a site on the A/B boundary whose red line falls in B gets B's list.*
- [ ] When a council's GIS does not answer, the applicant still gets a checklist and can submit, with designations marked "to be confirmed" (NFR-REL-03). *Example: council C's GIS times out; the list shows "conservation area: to be confirmed by the officer".*

**Story titles:**
1. Spike: what each pilot council's GIS returns for a site boundary (ASM-1)
2. Applicant sees the checklist for their application type
3. Checklist adds the items the site's designations require
4. Checklist follows the site's own council's rules (FR-1.2)
5. Applicant ticks off documents as they upload them
6. Applicant still gets a checklist when the council's GIS is down

Not listed: submitting with items "to follow" (candidate FR-1.3), until the user decides CF-1.

**Size:** M +spike
**Priority (provisional):** value 9, penalty 9

---

### EPIC-4: Each council's staff and applicants see only that council's work

As a result of this epic, each council's officers, and each applicant, will be able to see only the applications, reports and documents they are entitled to, and the public only the public register.

**Hypothesis:** If council data is visibly separated and refused attempts are shown to each council's admins, we believe pilot councils will move their live cases onto the shared platform instead of keeping a parallel record "to be safe", shown by share of each pilot's new applications received only in Permitry after its parallel run, which moves KR-1.2 (no applications in Permitry, no first-submission gains).

**Traces to:** deliverables SOL-1 and SOL-4 at every council (selected path) · job J-3 "decide applications within the statutory period" → job story JS-3.1 · UR-2 (FR-2.2) · BR-6 · NFR-SEC-01 · KR-1.2
**Personas:** P-3 validation officer (primary); P-1, P-2 applicants; disfavoured classes: another council's staff, another applicant, the public
**Bounded Context (candidate):** Tenancy and Identity

**Risks:** value — assumed (councils trust the separation enough to drop the parallel record; the user asks council A's information governance lead) · usability — low (sign-in with the council's own accounts) · feasibility — assumed (NFR-SEC-01 rated H; TP-2 and TP-3 open with `enterprise-architect`) · viability — assumed (a cross-council leak ends the contract, BR-6; tenancy model cost with NFR-FLEX-01, 3 → 40 councils)

**Epic acceptance criteria:**
- [ ] An officer opens only applications and reports of their own council. *Example: an officer of council B is refused council A's report for 24 Mill Lane, and the refusal is recorded.*
- [ ] An applicant opens only their own applications. *Example: an agent who changes the case number in the address bar sees "not found", not another client's drawings.*
- [ ] Each council's admins see refused cross-council attempts against their data. *Example: council A's admin sees council B's refused request with time and account.*
- [ ] Staff sign in with their own council's accounts. *Example: council C's officers sign in with council C's directory; a council A account cannot sign in to C.*

**Story titles:**
1. Officers sign in with their own council's accounts
2. Officers see only their own council's applications and reports (FR-2.2)
3. Applicants see only their own applications
4. The public sees only the public register
5. Council admins see refused cross-council attempts

**Size:** M
**Priority (provisional):** value 6, penalty 9

---

### EPIC-5A: Council A's open cases continue in Permitry without loss

As a result of this epic, council A's officers will be able to keep working every open case in Permitry from cut-over, with closed cases archived and a way back until the parallel run ends.

**Hypothesis:** If council A's open cases arrive complete and reconcile during the parallel run, we believe council A's officers will make Permitry their record at cut-over instead of extending the legacy system, shown by zero unexplained reconciliation differences in the last two parallel weeks, which lets SOL-1, SOL-2 and SOL-4 move KR-1.2 at council A.

**Traces to:** TR-1–TR-4 (council A) · enables deliverables SOL-1, SOL-2, SOL-4 at council A · job J-3 → job story JS-3.1 · BR-4, BR-5 · NFR-PERF-02 · KR-1.2
**Personas:** P-3 validation officer at council A (primary)
**Bounded Context (candidate):** Case Records

**Risks:** value — low (the legacy system is being switched off) · usability — low (officers see the same cases) · feasibility — assumed (TBD-2: does the export carry superseded document versions?; NFR-PERF-02: council A's 100,000-case import must not slow B and C) · viability — assumed (retention BR-4 and residency BR-5 must hold in the archive; confirmed with council A's records manager)

**Epic acceptance criteria:**
- [ ] Every open case arrives with its documents. *Example: council A's export of 3,412 open cases and 41,880 documents matches Permitry's counts and checksum totals.*
- [ ] Differences during the four-week parallel run are visible and explained. *Example: week 3 shows two validity decisions that differ; both are traced to a rule changed on the legacy side.*
- [ ] Council A can return to the legacy system as record until the parallel run ends. *Example: the rehearsal restores legacy-as-record within one working day.*
- [ ] Closed cases from the last 15 years are archived in the UK before switch-off (BR-4, BR-5). *Example: 50 sampled closed cases each open with their documents.*

**Story titles:**
1. Council A's open cases and documents arrive in Permitry (TR-1)
2. Officers see a weekly reconciliation against the legacy system (TR-2)
3. Council A can roll back to legacy-as-record until the run ends (TR-3)
4. Council A's closed cases are archived before switch-off (TR-4)

**Size:** S
**Priority (provisional):** value 7, penalty 9

EPIC-5B and EPIC-5C have the same shape with each council's own counts, dates and rollback point.

## Coverage

| Source | Epic |
|---|---|
| SOL-1 (selected path) | EPIC-1; EPIC-4 (isolation) |
| SOL-2 (selected path) | EPIC-2 |
| SOL-4 (selected path) | EPIC-3; EPIC-4 (isolation) |
| UR-1 (FR-1.1, FR-1.2) | EPIC-1 |
| UR-2 FR-2.1 / FR-2.2 | EPIC-3 / EPIC-4 |
| UR-3 | EPIC-2 |
| TR-1–TR-4 per council | EPIC-5A, EPIC-5B, EPIC-5C |
| TR-5 officer training | Not epics |

## Not Epics

| Item | Why not an epic | Where it goes |
|---|---|---|
| "Onboard a council" as proposed | Everything epic across four contexts | Split by outcome into EPIC-1 (rules, GIS), EPIC-4 (tenancy, sign-in), EPIC-5A/B/C (migration) |
| Tenant Service / Rules Engine / GIS Adapter / Migration Service epics | Per-service split; no user outcome | Service and team boundaries are decided in Design from the Bounded Contexts |
| TR-5 officer training | Procedure | Each council's go-live checklist |
| SOL-3 pre-application advice; chat help | Option branches | Stay on the impact map |
| Candidate FR-1.3 "to follow" items | CF-1 undecided | TBD-1; added to EPIC-1 once the user decides |

## Cross-Context Flags (for the domain-modeler)

| Epic | Contexts involved | Why it still crosses after the outcome split | Question for the domain-modeler |
|---|---|---|---|
| EPIC-4 | Tenancy and Identity; every context holding council data | Tenant ownership (BR-6) must be enforced wherever council data lives | Is the tenant a concept every context owns, or does Tenancy publish it to the others? Where is it enforced (TP-2, TP-3)? |
| EPIC-1 | Validation Rules; each council's GIS (IF-1) | Designations come from systems the councils own | Does Validation Rules need an Anti-Corruption Layer over each council's GIS? |
| EPIC-5A/B/C | Case Records; the legacy permits system (IF-2) | Legacy data model differs per council | Anti-Corruption Layer for the import, retired with the legacy system? |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| "Onboard a council" split by outcome | The everything epic across four contexts cannot fail informatively |
| Per-service split refused | Service epics carry no user outcome; they would hide the coupling from the domain-modeler |
| One transition epic per council | Each council has its own data, cut-over date and rollback point |
| Transition epics trace to TR-n and the deliverables they enable | They are not on the map, but the selected path cannot reach those councils without them |
| One UR split across two epics, by FR, in the coverage table | FR-2.2 serves isolation, FR-2.1 serves officers' checking; each outcome can fail on its own |
| Cross-context table always present | The domain-modeler decides contexts; the analyst only flags them |
| Value and penalty, labelled provisional | Carried from the FRD; MoSCoW finalises |
