# Requirement Types and the Classification Pass

Self-contained. This file holds the one taxonomy the functional requirements document (FRD) uses, how to sort raw input into it, and how to turn a stakeholder's want into a need. Read it before classifying the inputs for an FRD, and whenever an input fits no type.

## One taxonomy, three levels plus types

Karl Wiegers and Joy Beatty (*Software Requirements*, 3rd ed.) separate requirement **levels** from other requirement **types**. Mixing them up causes most requirements defects. Thomas and Angela Hathaway (*Getting and Writing IT Requirements in a Lean and Agile World*) use four levels (Business, Stakeholder, Solution, Transition). This plugin uses one taxonomy, Wiegers' levels plus types, and adds the Hathaways' Transition type. The mapping, so the two vocabularies never compete:

| This plugin (Wiegers + Transition) | Hathaway's level | Where it lives |
|---|---|---|
| **Business requirement**: why the product is built (objective, success measure) | Business | Vision, strategy kernel, OKR set. The FRD **cites** KR IDs; it never rewrites them |
| **User requirement** (UR-n): what a user class must be able to do | Stakeholder | FRD, one per selected-path deliverable and user class. Upstream it is the job story; downstream it becomes epics and stories |
| **Functional requirement** (FR-n.m): what the software must do so the user can | Solution, functional | FRD, under its UR, each with a fit criterion |
| **Quality attribute**: how well (performance, availability, security, usability, …) | Solution, non-functional | Handed off to `nfr-specification`, which sets targets |
| **Transition requirement** (TR-n): one-time work to move from the current state | Transition | FRD, its own section |

Beside the levels sit these types (Wiegers):

| Type | What it is | Rule |
|---|---|---|
| **Business rule** (BR-n) | A policy, regulation, standard, formula or fact that is true whether or not any software exists | Catalogued once with its source; FRs cite the ID. A rule outlives the product |
| **Constraint** (CON-n) | A limit on design or build choices **imposed from outside**: a customer mandate, a regulator, a contract, an existing platform the product must run on | Name who imposed it. An owner-configured tech-stack default is a decision recorded in `sdlc-config.json`, not a constraint |
| **External interface** (IF-n) | A connection to another system, device or user channel (an email gateway, a payment provider, a legacy API) | What crosses the boundary and in which direction; protocol detail belongs to Design |
| **Data requirement** (DR-n) | Data the product must hold, keep, report or retire: definitions, retention, reports | Retention periods that come from law are business rules; the DR cites them |

Two things are **not** requirements and never get a requirement ID: an **assumption** (goes to the assumption log, ASM-n) and an **open question** (goes to the TBD list).

## Business-rule taxonomy

Wiegers and Beatty sort business rules into five kinds. Typing a rule tells the analyst what kind of FR it produces.

| Kind | Example (any product) | Typically produces |
|---|---|---|
| **Fact** | "A member account belongs to exactly one household" | Data requirements, validations |
| **Constraint** | "A loan may not exceed 14 days"; "personal data stays in the EU" | Validations, refusals, an NFR the rule is cited by |
| **Action enabler** | "When a booking is cancelled within 24 h, offer the slot to the waitlist" | An FR triggered by an event |
| **Inference** | "A member with two overdue loans is suspended" | An FR that derives a state |
| **Computation** | "Late fee = 0.50 per day, capped at 10.00" | An FR with a formula, and fit criteria with worked values |

**One fact, one home.** A regulation such as data residency is a business rule (BR-n) in the FRD, its source named. `nfr-specification` holds the measurable obligation (where data is stored, how it is verified) and cites BR-n. Neither restates the other.

## User classes and the product champion

Wiegers groups users into **user classes** by how they use the product: frequency, features used, privileges, expertise. Each class is:

- **favoured**: the product is built for them;
- **disfavoured**: the product must keep them out or limit them (an unauthenticated visitor, another tenant's staff, a suspended member). Disfavoured classes are where access and isolation requirements come from that nobody would otherwise write;
- **ignored**: in scope of nothing.

A persona (`user-persona`) is a picture of one member of a class. Each important class has a **product champion**, one real person who speaks and decides for that class. In this plugin the user (the product owner) is the champion for every class unless they name a design partner. Say so in the FRD.

## The classification pass

Before drafting anything, put every candidate statement from the inputs into one bucket: business requirement, user requirement, functional requirement, business rule, constraint, quality attribute, external interface, data requirement, transition requirement, **solution idea**, assumption or open question. An input that fits no bucket is either out of scope or not understood yet. Ask the user.

## Wants and solution ideas: the why-chain

Stakeholders describe solutions because that is how people think (the Hathaways call premature solutioning the most common requirements defect). Any statement that names a widget, screen, button, report format, technology or vendor is a **solution idea** until proven otherwise.

1. Ask "why do you need that?" at least once, usually twice. Stop when the answer names a capability or an outcome, not a UI element.
2. Record the need as the user requirement. Keep the original want in the rationale or as a design note; it may still be the best solution, but now it is negotiable.
3. If the person who stated the want cannot be asked now (their words reached you through notes), do not stop at "need unknown". Write the most likely need as a **hypothesis**: a user requirement marked as resting on an assumption (ASM-n), with the why-question for the user to put to them. Reasoning about the probable need is analysis; presenting it as their answer would be invented evidence.
4. Apply the **necessity test**: "what happens if we don't build this?" If the honest answer is nothing consequential, it is a preference. Put it in the waiting room with that reason.

Worked want:

> **Want:** "A dropdown on the report page that emails the weekly report to my boss every Friday."
> **Why?** "So she sees the numbers before Monday's meeting." **Why does she need them then?** "She decides Monday which depots get overtime."
> **Need (UR):** The operations manager must have the previous week's depot workload figures before the Monday planning meeting.
> **FRs:** deliver the weekly workload summary to named recipients on a schedule the operations manager sets; recipients see the same figures as the report page.
> **Solution idea kept as a note:** dropdown + email. Design may choose a scheduled email, a shared dashboard link or a calendar attachment.
> **Necessity:** without it, overtime is decided on last month's figures (the cause named in the stakeholder map). Necessary.

A second want that fails the test: "custom colour themes per user". Why? "People like choosing." What happens without it? Nothing that moves the KR. Waiting room, reason recorded.

## Transition requirements

The Hathaways note that transition requirements are the category most often omitted entirely, because they are neither what the product does nor how well it does it. Wiegers covers the same ground in his chapter on replacement projects; Volere calls it "migration to the new product". Run this checklist once per release whenever anything is being replaced, **including a spreadsheet, a paper diary or a shared inbox**:

| Kind | Question |
|---|---|
| **Data migration** | What data must come across, from where, how is it cleaned, and how will we know it all arrived? |
| **Parallel run** | Will old and new run side by side? For how long, and which is the record during it? |
| **Cutover and rollback** | What is the switch-over moment, and how do we go back if it fails? |
| **Training and adoption** | Who must learn what before cutover, and how do we know they have? |
| **Decommission** | When and how is the old tool retired, and what must be archived first (retention rules)? |

Each transition requirement gets a fit criterion like any other ("all 1,240 loan records imported; a reconciliation count matches the spreadsheet row count; zero orphaned member references"). A greenfield product with no current tool writes "Transition requirements: none, because <reason>".
