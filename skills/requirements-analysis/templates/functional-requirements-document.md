---
name: functional-requirements-document
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: which selected-path deliverables and job stories these requirements serve, for which user classes>
profile: <standard | enterprise>
status: <draft | approved (baseline)>
linked-kr: <KR ID(s) from strategy/okrs.md>
linked-impact-map: <ideate/impact-map.md | ideate/impact-maps/<outcome>.md | none (standard, map not produced)>
linked-jtbd: ideate/jtbd-analysis.md
traces_to: strategy/okrs.md (<KR>); <linked-impact-map> (selected path); ideate/jtbd-analysis.md (<J-n, JS-n.m>); ideate/user-personas.md (<P-n>)
---

<!-- Copy into ideate/requirements.md and fill. Lean: no FRD (the user story backlog is the
     functional requirements). Write it after the impact map; never draw the map from it.
     Delete these comments. -->

# Functional Requirements — <Product>

**Translation.** <Which inputs (selected path, job stories, stakeholder concerns) become which requirements, for which consumers (nfr-specification, epic-definition, Design).>

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`.

## Scope and Exclusions

**In scope (this release):** <the selected-path deliverables, in a line each>

**Excluded:** <what is explicitly not in this release, and why: options on the map, later cycles, out of product>

**Business requirements (cited, not restated):** <KR-n.m: "…"; strategy-kernel coherent action CA-n>

## User Classes

| User class | Favoured / disfavoured / ignored | Persona | Champion |
|---|---|---|---|
| <class> | favoured | <P-n> | <the product owner / named design partner> |
| <class> | disfavoured | — | <the product owner> |

## User and Functional Requirements

<!-- One UR per selected-path deliverable and user class. Every UR traces to a deliverable
     and to a job statement → job story. FRs beneath it: one behaviour each, a fit criterion
     each, no performance or availability numbers (those go to the hand-off list).
     Priority: high / medium / low (provisional); never Must / Should / Could / Won't. -->

### UR-1: <user class> must be able to <capability>

- **Traces to:** deliverable <SOL-n / named deliverable> (selected path, <linked-impact-map>) · job <J-n> "<job statement>" → job story <JS-n.m> · <KR-n.m>
- **Rationale:** <the impact this enables and why the user class needs it>

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) |
|---|---|---|---|---|---|
| FR-1.1 | <one behaviour> | <who/what, input, observable result, how many> | <acceptance test> | <BR-n; QA-n> | <high> |
| FR-1.2 | <…> | <…> | <…> | <…> | <medium> |

### UR-2: <…>

<!-- repeat -->

## Business Rules

| ID | Rule | Kind | Source | Cited by |
|---|---|---|---|---|
| BR-1 | <policy, regulation, formula or fact> | <fact / constraint / action enabler / inference / computation> | <regulation, policy, product owner + date> | <FR-…> |

## Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-1 | <limit on design or build choices> | <customer / regulator / contract / existing platform — never a configured default> |

## External Interfaces and Data

<!-- Standard: only those the selected path needs. Enterprise: every one. -->

| ID | Interface or data requirement | Direction / retention | Source |
|---|---|---|---|
| IF-1 | <system or channel and what crosses it> | <in / out / both> | <…> |
| DR-1 | <data that must be held, kept, reported or retired> | <retention, citing BR-n> | <…> |

## Transition Requirements

<!-- Whenever anything is replaced, even a spreadsheet or a paper diary.
     Greenfield: "None, because <reason>." -->

| ID | Requirement | Kind | Fit criterion |
|---|---|---|---|
| TR-1 | <…> | <data migration / parallel run / cutover and rollback / training / decommission> | <…> |

## Quality-Attribute Hand-off (to `nfr-specification`)

<!-- Concerns only. Targets are set in the NFR specification, scaled to the profile. -->

| ID | Quality concern | Constrains | Why it matters here |
|---|---|---|---|
| QA-1 | <performance / availability / security / usability / …: what must be good enough> | <FR-…> | <…> |

## Conflicts

<!-- Enterprise: every stakeholder conflict. Standard: when any. The user decides. -->

| ID | Requirements | Who wants what | Recommendation | Decision (user, date) |
|---|---|---|---|---|

## Assumption Log

| ID | Assumption | Requirements that depend on it | Impact if false | How it will be confirmed |
|---|---|---|---|---|
| ASM-1 | <…> | <FR-…> | <…> | <question for the user / snapshot / assumption test> |

## TBD List

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | <…> | <FR-…> | <the product owner> | <before the Design phase gate> |

## Waiting Room

| Item | Reason deferred | Would return if |
|---|---|---|
| <option deliverable / preference / idea> | <option on the map / fails the necessity test / later cycle> | <…> |

## Traceability

| Source | Served by |
|---|---|
| <SOL-n> (selected path) | <UR-1> |
| <JS-n.m> | <UR-1, UR-2> |
| <KR-n.m> | <UR-…> |

<!-- Enterprise adds forward columns, filled as later artifacts are written:
| FR | Story | Acceptance criteria | Test | -->

## Change Log

| Version | Date | Change | Reason | Impact | Decided by |
|---|---|---|---|---|---|
| 1.0.0 | <date> | First baseline | Ideate, cycle <n> | — | <the user> |
