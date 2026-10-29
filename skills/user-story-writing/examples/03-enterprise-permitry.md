# Example 3 — Enterprise: an "RBAC module" request turned into access stories for disfavoured user classes, a per-tenant split rejected, a spike for an unknown external system, a gap declined, and the forward trace (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant; three pilot councils (A, B, C) are replacing a fifteen-year-old on-premises permits system. Records retention, UK data residency and data-protection law apply. At the **enterprise** profile the backlog carries value and penalty scores, stories for disfavoured user classes, rule and interface splits, spikes for unknown external systems, per-tenant transition stories, cited regulatory rules and NFRs, and the forward trace back into the epic list and the FRD.

## Input

> **Epic list (ideate/epics.md, approved):** EPIC-1 "Applicants know every document their site needs before submitting" (SOL-1; JS-1.1; UR-1 FR-1.1, FR-1.2; value 9, penalty 9; M +spike), titles: spike on what each pilot council's GIS returns (ASM-1); checklist for the application type; items the site's designations add; the site's own council's rules (FR-1.2); tick off documents on upload; checklist when the GIS is down. EPIC-4 "Each council's staff and applicants see only that council's work" (SOL-1, SOL-4; JS-3.1; UR-2 FR-2.2; BR-6; NFR-SEC-01; value 6, penalty 9), titles: officers sign in with their own council's accounts; officers see only their own council's applications and reports; applicants see only their own applications; the public sees only the public register; council admins see refused cross-council attempts. EPIC-5A/B/C per-council transition (TR-1 to TR-4). The epic list's Stories column is empty: the forward trace.
>
> **FRD (ideate/requirements.md, approved):** UR-1: FR-1.1 checklist from type and designations (9/8); FR-1.2 the site's own council's checklist rules (7/9). UR-2: FR-2.1 validation report (8/7); FR-2.2 only the owning council's officers open its report (6/9). BR-1 each council's local validation list; BR-6 each council's data is its own. User classes: favoured P-1 planning agent, P-2 householder, P-3 validation officer; **disfavoured**: another council's staff, an applicant viewing another's application, the public beyond the register. QA-2 tenant isolation (NFR-SEC-01); NFR-REL-03 a GIS failure must not block submission.
>
> **The user:** "For EPIC-4 just write one story: 'As an admin, I want a multi-tenant RBAC module so that security is handled.' And for EPIC-1, write the checklist-rules story three times, one per council, so each council can sign off its own."
>
> **Later, from the story map:** "Gap? No selected-path deliverable covers application fees. Does council A take fees outside Permitry in Release 1?" **The user:** "Yes, fees stay on the council's existing payment page for now."

## Working it

- **"RBAC module" is a solution and a task.** "An admin" is no persona, "RBAC module" names the implementation, and "security is handled" names no change for anyone. The FRD already says where access stories come from: its **disfavoured user classes**. Split by **Interfaces / user class** (SPIDR): sign-in, officers, applicants and the public each get a story, plus the admins who must see refused attempts. The admin has no persona, so a **user role** from role brainstorming stands in ("council administrator") until `user-persona` adds one.
- **A story reveals a missing FR.** No FR covers "an applicant opens only their own applications" (the FRD names the disfavoured class but FR-2.2 covers officers only). The story is written, and FR-2.3 is proposed to the FRD as a change request for the user to approve; it is not invented silently.
- **One story per council is a bad split.** The checklist rule (FR-1.2, BR-1) behaves identically for every council: only each council's list differs, which is data each council supplies. Three copies would differ only by name. One story (US-13) with a seed example across two councils; each council confirms its list in UAT. Per-council stories *are* right in EPIC-5A/B/C, where each council's data, cut-over date and rollback point differ.
- **A spike for the unknown external system.** Nobody can say what each council's GIS returns for a site boundary (ASM-1). US-10 is a spike with one question and a decision-note output; US-12 waits on it.
- **Rules and NFRs cited, never restated.** BR-6 and NFR-SEC-01 on every isolation story; NFR-REL-03 on the GIS fallback.
- **The fees gap is declined and recorded.** The user confirmed a manual step outside Permitry; the map shows it as a named manual cell. Nothing is written.
- **Forward trace proposed, not edited in.** The epic list's Stories column and the FRD's Story column are both approved artifacts; the fill is proposed with the backlog, and editing them reopens their approval.

## Output — `ideate/user-stories.md` (abridged: EPIC-1 and EPIC-4 in full)

````markdown
---
name: user-story-backlog
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-16
summary: Permitry stories for complete first submissions and tenant isolation (EPIC-1, EPIC-4 shown), with value and penalty, a GIS spike, cited BR-6 and NFR-SEC-01, and the forward trace to epics and FRD.
profile: enterprise
status: draft
linked-kr: KR-1.2
linked-epics: ideate/epics.md
linked-requirements: ideate/requirements.md
linked-jtbd: ideate/jtbd-analysis.md
traces_to: strategy/okrs.md (KR-1.2); ideate/epics.md (EPIC-1, EPIC-4); ideate/requirements.md (UR-1, UR-2; FR-1.1, FR-1.2, FR-2.2; BR-1, BR-6); ideate/jtbd-analysis.md (J-1, JS-1.1, J-3, JS-3.1); ideate/nfr-specification.md (NFR-SEC-01, NFR-REL-03)
---

# User Story Backlog — Permitry

**Translation.** The story titles of EPIC-1 to EPIC-7, with the FRs of UR-1 to UR-3, the disfavoured user classes and TR-1 to TR-4 per council, become stories for `example-mapping`, `acceptance-criteria`, `story-mapping` and the test-strategist.

Priorities in this document are **provisional** (value and penalty, 1–9); `moscow-prioritization` finalises them per release.

## Backlog Summary

| ID | Story | Epic | Persona / role | UR / FR | Job story | Priority (provisional) |
|---|---|---|---|---|---|---|
| US-10 | Spike: what each pilot council's GIS returns for a site boundary | EPIC-1 | — | — | — | value 9, penalty 9 |
| US-11 | Applicant sees the checklist for their application type | EPIC-1 | P-1, P-2 | UR-1 (FR-1.1) | JS-1.1 | value 9, penalty 9 |
| US-12 | Checklist adds the items the site's designations require | EPIC-1 | P-2 | UR-1 (FR-1.1) | JS-1.1 | value 9, penalty 8 |
| US-13 | Checklist follows the site's own council's rules | EPIC-1 | P-1 | UR-1 (FR-1.2) | JS-1.1 | value 7, penalty 9 |
| US-14 | Applicant ticks off documents as they upload them | EPIC-1 | P-2 | UR-1 (FR-1.1) | JS-1.1 | value 5, penalty 4 |
| US-15 | Applicant still gets a checklist when the council's GIS is down | EPIC-1 | P-2 | UR-1 (FR-1.1) | JS-1.1 | value 6, penalty 8 |
| US-40 | Officers sign in with their own council's accounts | EPIC-4 | P-3 | UR-2 (FR-2.2) | JS-3.1 | value 6, penalty 9 |
| US-41 | Officers see only their own council's applications and reports | EPIC-4 | P-3 | UR-2 (FR-2.2) | JS-3.1 | value 6, penalty 9 |
| US-42 | Applicants see only their own applications | EPIC-4 | P-1 | UR-2 (FR-2.3 proposed) | JS-3.1 | value 6, penalty 9 |
| US-43 | The public sees only the public register | EPIC-4 | member of the public (role) | UR-2 | JS-3.1 | value 4, penalty 6 |
| US-44 | Council admins see refused cross-council attempts | EPIC-4 | council administrator (role) | UR-2 (FR-2.2) | JS-3.1 | value 5, penalty 7 |

EPIC-2, EPIC-3, EPIC-5A/B/C, EPIC-6 and EPIC-7 (US-20–US-23, US-30–US-32, US-50–US-61, US-70–US-71, US-80–US-82) have the same shape and are omitted here.

## Stories

### EPIC-1: Applicants know every document their site needs before submitting

#### US-10: Spike: what each pilot council's GIS returns for a site boundary
- Question: for a red-line site boundary, does each of councils A, B and C's GIS return conservation area, listed building and flood zone designations, and in what form? (ASM-1)
- Output: a one-page decision note per council: designations available, how they are queried, and what is missing.
- Unblocks: US-12, US-15 · Traces to: EPIC-1
- Priority (provisional): value 9, penalty 9

#### US-11: Applicant sees the checklist for their application type
As a planning agent (P-1) or householder (P-2), I want to see every document my application type needs before I start uploading, so that I don't submit something the council will send back weeks later.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-1.2
- Rules: BR-1 (the council's local validation list)
- Priority (provisional): value 9, penalty 9
- Seed example: a householder extension at council A lists the 6 documents on council A's 2026 validation list, with no designation items yet.
- Acceptance criteria: ideate/acceptance-criteria/US-11.md (from the example map)

#### US-12: Checklist adds the items the site's designations require
As a householder (P-2), I want the checklist to add what my site's designations require, so that I learn about the heritage statement before submitting, not after.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-1.2
- Rules: BR-1
- Priority (provisional): value 9, penalty 8
- Seed example: 12 Abbey Row sits in council B's conservation area; its extension checklist adds a heritage statement to council B's list.
- Acceptance criteria: ideate/acceptance-criteria/US-12.md (from the example map)
- Notes: waits on US-10 (spike).

#### US-13: Checklist follows the site's own council's rules
As a planning agent (P-1) working across council boundaries, I want each site's checklist to follow the council the site belongs to, so that I never prepare documents for the wrong council's list.
- Traces to: EPIC-1 · UR-1 (FR-1.2) · J-1 → JS-1.1 · KR-1.2
- Rules: BR-1, BR-6
- Priority (provisional): value 7, penalty 9
- Seed example: the agent prepares 3 Mill Lane (council A) and 24 Mill Lane, whose red line falls in council B; the first gets council A's list, the second council B's.
- Acceptance criteria: ideate/acceptance-criteria/US-13.md (from the example map)
- Notes: one story for all councils (rule split by mechanism, not by tenant); each council's own list is data it supplies and confirms in UAT.

#### US-14: Applicant ticks off documents as they upload them
As a householder (P-2), I want each checklist item ticked as I upload its document, so that I can see what is still missing before I submit.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-1.2
- Rules: none
- Priority (provisional): value 5, penalty 4
- Seed example: of 7 items, the householder uploads the site plan and elevations; 2 are ticked and 5 are shown as still needed.
- Acceptance criteria: ideate/acceptance-criteria/US-14.md (from the example map)

#### US-15: Applicant still gets a checklist when the council's GIS is down
As a householder (P-2), I want a checklist and the chance to submit even when the council's map service is not answering, so that an outage does not cost me my slot in the statutory period.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-1.2
- Rules: BR-1 · NFR-REL-03
- Priority (provisional): value 6, penalty 8
- Seed example: council C's GIS times out; the checklist shows the application-type items and "conservation area: to be confirmed by the officer", and the householder can submit.
- Acceptance criteria: ideate/acceptance-criteria/US-15.md (from the example map)
- Notes: Paths split (SPIDR) of US-12; waits on US-10.

### EPIC-4: Each council's staff and applicants see only that council's work

#### US-40: Officers sign in with their own council's accounts
As a validation officer (P-3), I want to sign in with my council's own account, so that I don't manage another password and leavers lose access when the council removes them.
- Traces to: EPIC-4 · UR-2 (FR-2.2) · J-3 → JS-3.1 · KR-1.2
- Rules: BR-6 · NFR-SEC-01
- Priority (provisional): value 6, penalty 9
- Seed example: council C's officers sign in with council C's directory; a council A account is refused at council C's sign-in.
- Acceptance criteria: ideate/acceptance-criteria/US-40.md (from the example map)

#### US-41: Officers see only their own council's applications and reports
As a validation officer (P-3), I want to see only my own council's applications and validation reports, so that I can trust nothing I open belongs to another council.
- Traces to: EPIC-4 · UR-2 (FR-2.2) · J-3 → JS-3.1 · KR-1.2
- Rules: BR-6 · NFR-SEC-01
- Priority (provisional): value 6, penalty 9
- Seed example: an officer of council B opens the report for 24 Mill Lane, which council A owns, and is refused; the refusal is recorded.
- Acceptance criteria: ideate/acceptance-criteria/US-41.md (from the example map)

#### US-42: Applicants see only their own applications
As a planning agent (P-1), I want to open only the applications I submitted, so that my clients' drawings are never visible to another applicant.
- Traces to: EPIC-4 · UR-2 (FR-2.3 proposed) · J-3 → JS-3.1 · KR-1.2
- Rules: BR-6 · NFR-SEC-01
- Priority (provisional): value 6, penalty 9
- Seed example: the agent changes the case number in the address from 4471 to 4472, another practice's application, and sees "not found", not the drawings.
- Acceptance criteria: ideate/acceptance-criteria/US-42.md (from the example map)
- Notes: from the disfavoured class "an applicant viewing another's application"; no FR covers it, so FR-2.3 is proposed to the FRD as a change request.

#### US-43: The public sees only the public register
As a member of the public (user role), I want to see the public register of applications and nothing else, so that I can comment on a neighbour's plans without seeing anyone's personal details.
- Traces to: EPIC-4 · UR-2 · J-3 → JS-3.1 · KR-1.2
- Rules: BR-6 · NFR-SEC-01
- Priority (provisional): value 4, penalty 6
- Seed example: a visitor searches "Mill Lane" and sees two register entries with address, proposal and status, and no applicant names, phone numbers or drawings marked private.
- Acceptance criteria: ideate/acceptance-criteria/US-43.md (from the example map)

#### US-44: Council admins see refused cross-council attempts
As a council administrator (user role), I want to see every refused attempt by another council's staff to open our data, so that I can show our information governance lead the separation holds.
- Traces to: EPIC-4 · UR-2 (FR-2.2) · J-3 → JS-3.1 · KR-1.2
- Rules: BR-6 · NFR-SEC-01
- Priority (provisional): value 5, penalty 7
- Seed example: council A's administrator sees council B's refused request for 24 Mill Lane, with time and account, the morning after.
- Acceptance criteria: ideate/acceptance-criteria/US-44.md (from the example map)
- Notes: rewritten, with US-40 to US-43, from "As an admin, I want a multi-tenant RBAC module so that security is handled" (Interfaces / user-class split).

## Coverage

| Source | Stories |
|---|---|
| EPIC-1 titles (6) | US-10 to US-15 |
| EPIC-4 titles (5) | US-40 to US-44 |
| UR-1 FR-1.1 / FR-1.2 | US-11, US-12, US-14, US-15 / US-13 |
| UR-2 FR-2.2 / FR-2.3 (proposed) | US-40, US-41, US-44 / US-42 |
| Disfavoured classes: another council's staff / another applicant / the public | US-41, US-44 / US-42 / US-43 |

**Forward trace (proposed for the user's approval; editing reopens those artifacts):** epic list Stories column, EPIC-1 → US-10–US-15, EPIC-4 → US-40–US-44; FRD Story column, FR-1.1 → US-11, US-12, US-14, US-15; FR-1.2 → US-13; FR-2.2 → US-40, US-41, US-44; new FR-2.3 → US-42.

## Intake Log (from the story map)

| Item | Kind | Decision |
|---|---|---|
| Application fees: no story takes payment | Gap | Declined 2026-11-20: fees stay on each council's existing payment page in Release 1 (a named manual cell on the map) |
| Orphans | Orphan | None: every story is placed (US-43 sits in the map's Later row) |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| Access stories from the disfavoured user classes | Nobody asks for them; they are where isolation requirements come from |
| "RBAC module" rewritten by user class | A module is a solution and a task; each class is a testable story |
| A user role where no persona exists | Cohn's role brainstorming stands in until `user-persona` adds one |
| FR-2.3 proposed, not invented | The story found a hole in the approved FRD; the user decides |
| One rule story for every council | Same behaviour, different data; per-tenant stories only where behaviour or data really differs (EPIC-5A/B/C) |
| Spike with a question and a decision note | The GIS is an unknown external system; its stories wait on the answer |
| BR-6, NFR-SEC-01, NFR-REL-03 cited | Rules and quality targets keep one owner |
| Gap declined and logged | Nothing joins or leaves the backlog without the user |
| Forward trace proposed | Editing approved artifacts reopens them; the user approves the fill |
