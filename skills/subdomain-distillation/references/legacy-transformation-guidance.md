# Legacy Transformation Guidance

Per *Domain-Driven Transformation* (Lilienthal & Schwentner). Self-contained
— loadable without reading `SKILL.md` first, though it assumes the
Core/Supporting/Generic classification from there. Applies specifically to
an **existing, already-built system** — greenfield subdomain distillation
doesn't need this file; the sequencing question it answers ("which
subdomain do we touch first") only exists once there's a legacy system with
real risk and organizational inertia to work around.

---

## Classification Drives Sequencing, Not Just Investment

For a greenfield product, Core/Supporting/Generic classification mainly
answers an investment question (how much modeling effort). For a legacy
transformation, it also answers a **sequencing** question: which subdomain
gets touched first. Get this wrong and a transformation effort either burns
credibility on a low-value change or takes on unacceptable risk before
anyone trusts the new approach.

**Prioritize a subdomain for transformation when it is:**

1. Genuinely **Core** — real business value, which secures stakeholder buy-in
   and sustained funding for the effort (a transformation that starts with a
   Generic subdomain struggles to justify itself to leadership).
2. **Bounded technical risk** — don't start with the most tangled, highest-
   risk part of the system even if it's Core. A failed first transformation
   attempt kills appetite for the rest. Start where the Core Domain value is
   real but the blast radius of getting it wrong is contained.
3. Backed by **existing organizational pain** — a subdomain stakeholders
   already feel friction with builds momentum faster than one chosen on
   pure technical merit.

**Generic subdomains in a legacy system are usually replace, not migrate**
candidates — if a bought solution exists, replacing a legacy Generic
subdomain outright is often lower-risk and lower-effort than painstakingly
untangling and preserving custom legacy code for something that was never
supposed to be custom-built. Reserve migration effort for Core and
Supporting subdomains.

## Strangler Fig, Sequenced by Classification

Once a Core subdomain is chosen, extract it into its own Bounded Context
incrementally while the legacy system keeps running (the Strangler Fig
pattern) — classification tells you *which* piece to strangle first (the
chosen Core subdomain) and which pieces can safely wait longest (Generic —
least valuable to touch, and per above, often a replace-not-migrate
candidate rather than something worth strangling at all).

If the chosen Core subdomain's code is currently tangled with Generic or
Supporting concerns (a common legacy state), apply **Segregated Core** (see
`classification-techniques.md`) as the concrete first step — the Strangler
Fig extraction target *is* the segregated Core once separated.

## Classification Is Organizationally Political

Unlike a greenfield product where classification is mostly a modeling
judgment call, in a legacy transformation **different stakeholders
genuinely disagree about what's Core** — engineering, product, leadership,
and different business units carry different histories and incentives.
Treat classification as a **collaborative workshop outcome**, not a
unilateral technical ruling. Where `ddd-agent-handoff`'s conflict resolution
gives domain-modeler final say on Context Map disputes (a modeling-
correctness question), subdomain-classification disagreements in a
transformation are a **business prioritization** question — resolve them by
facilitation and stakeholder sign-off, not by one agent's authority.

## Domain Vision Board

A lightweight, single-page artifact for socializing *why* a subdomain is
classified Core and prioritized, aimed at stakeholders beyond engineering —
expressed as a Miro board spec per `miro-board-notation`, since it's meant
to be built and reviewed collaboratively in a workshop, not read as prose.

Color Legend: `blue` = filled-in content, `gray` = section label.

**Items:**

| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| F1 | frame | Domain Vision Board — `<subdomain name>` | — | — |
| L1 | sticky_note | Target users/stakeholders | F1 | gray |
| V1 | sticky_note | `<who actually uses or is affected by this>` | F1 | blue |
| L2 | sticky_note | Needs addressed | F1 | gray |
| V2 | sticky_note | `<what problem this solves for them>` | F1 | blue |
| L3 | sticky_note | Why this is Core | F1 | gray |
| V3 | sticky_note | `<the specific competitive/business reason>` | F1 | blue |
| L4 | sticky_note | Transformation priority + rationale | F1 | gray |
| V4 | sticky_note | `<tier and why, per the sequencing rules above>` | F1 | blue |
| L5 | sticky_note | Explicitly out of scope | F1 | gray |
| V5 | sticky_note | `<what this transformation effort will not touch>` | F1 | blue |

**Connectors:** none — this board is a filled-in form, not a relationship
diagram.

## Transformation Prioritization Table

Once classification (per `SKILL.md`) is done for every identifiable
subdomain in the legacy system, sequence the transformation:

| Subdomain | Classification | Current tangle/risk | Priority tier | Rationale |
|---|---|---|---|---|
| `<name>` | Core / Supporting / Generic | Low / Medium / High | 1st / 2nd / Replace-not-migrate | `<one line>` |

Tier 1 goes to Core subdomains with bounded risk (per the sequencing rules
above). Generic subdomains default to "Replace-not-migrate" rather than a
numbered tier at all, unless a specific reason argues for preserving the
legacy implementation.
