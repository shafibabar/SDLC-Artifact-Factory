---
name: stakeholder-mapping
description: >
  Teaches how to write the stakeholder map in two separate halves: (a) delivery
  stakeholders, the real people whose cooperation the product needs (product owner,
  design partners, reviewers, internal teams), placed on Mendelow's power/interest
  grid with a stated high/low cut-off, an engagement plan with cadence, salience
  re-scoring when urgency appears, pre-wiring order, and decision rights (RACI, or
  RAPID's Agree for a security or compliance veto) with exactly one Accountable
  person and AI agents only ever Responsible; and (b) the customer's buying
  committee, hypothesised roles per segment with the belief each needs, its likely
  objection, the proof that answers it, its likely Mobilizer / Talker / Blocker
  profile and what no decision costs it, never given a cadence. Use when mapping
  stakeholders, drawing a power/interest grid, writing a RACI, mapping a B2B
  buying committee, naming a Mobilizer or Blocker, planning stakeholder
  engagement, or reviewing a map that mixes customer archetypes with the team.
  Used by the product-strategist agent in the Strategy phase (/sdlc-strategy),
  after the vision and before the competitive analysis; required at standard and
  enterprise, skipped at lean.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, stakeholders, buying-committee, power-interest-grid, raci, communication, product-discovery]
produces: stakeholder-map
domain: strategy
status: stable
related: [vision-statement, competitive-analysis, strategy-kernel, gtm-strategy, pricing-and-packaging, roadmap-authoring, user-persona, beta-program-design, uat-plan, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/challenger-customer-adamson-dixon.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/product-roadmaps-relaunched-lombardo.md
  - research/storytelling-and-narrative/business-storytelling-for-dummies.md
  - research/data-governance-and-mdm/simple-data-mdm-srinivasan.md
  - research/service-design/this-is-service-design-doing-stickdorn.md
---

# Stakeholder Mapping

## Purpose

A product fails for reasons its users never see: a security reviewer who was not asked, a budget holder who was never convinced, a buying group that could not agree and quietly chose to do nothing. The stakeholder map finds those people before they become the reason.

It answers two different questions, and the commonest defect is answering them on one grid:

| | (a) Delivery stakeholders | (b) Customer buying committee |
|---|---|---|
| Question | Whose cooperation do we need to build and launch this? | Who inside the customer takes part in deciding to buy, and what does each need to believe? |
| Who | **Real people** you can meet: the product owner, design partners, a security reviewer, a finance approver, platform teams, support | **Roles in a segment** (economic buyer, user team, security, finance, legal): hypotheses about a kind of organisation, not people |
| Tools | Power/interest grid, engagement plan with cadence, salience re-scoring, pre-wiring, decision rights (RACI / RAPID) | Belief needed, likely objection, proof, likely profile (Mobilizer / Talker / Blocker), cost of no decision |
| Cadence | Yes: these people get meetings, reviews, updates | **Never.** You cannot send a monthly newsletter to "the CISO of a mid-size hospital" |

Splitting the map this way follows the stakeholder-analysis tradition for the delivery side (Mendelow's power/interest grid; Colin Eden and Fran Ackermann, *Making Strategy*) and Brent Adamson, Matthew Dixon et al., *The Challenger Customer* for the customer side. Geoffrey Moore (*Crossing the Chasm*) supplies the split every committee starts from: the **economic buyer** who owns the budget and the risk is not the user or champion who found the product.

A stakeholder map is **not** a service ecosystem map. The ecosystem map in Stickdorn et al., *This Is Service Design Doing*, traces actors and value exchanges inside a service; this artifact is about buy-in and decision rights. Do not merge them.

## Where It Sits

```
Vision ─► STAKEHOLDER MAP ─► Competitive analysis ─► Strategy kernel ─► Canvas ─► GTM ─► (Pricing) ─► OKRs ─► Roadmap
```

| Reads | What it takes |
|---|---|
| `vision-statement` | The protagonist and the target segment(s) whose buying committee is mapped |
| Problem statement, `sdlc-config.json` | Who the team is; any regulator, auditor or partner the product must satisfy |

| Feeds | What it gives |
|---|---|
| `competitive-analysis` | Committee roles whose criteria count, and who defends the status quo |
| `strategy-kernel` | The constraints and inertia the diagnosis must name (a veto holder, a committee that stalls) |
| `gtm-strategy` | **The buying committee for the beachhead.** The GTM cites it and adds only motion decisions: where consensus is built and how Stage 1 confirms the Mobilizer. It never keeps a second committee table |
| `pricing-and-packaging` | The roles whose price objections the value brief answers |
| `roadmap-authoring` | The engagement plan and pre-wiring order for the roadmap review |
| `user-persona` | Committee roles become buyer and secondary personas; delivery stakeholders do not become personas |
| `beta-program-design`, `uat-plan` | The design-partner cohort, from the delivery register |

**One home for the buying committee.** This artifact owns the committee table for every segment the vision targets. If the GTM later picks a beachhead the map does not cover, add that segment's committee here (a new version) rather than writing it in the GTM.

## Scale

`phase-requirements.json` **skips** this artifact at **lean** and **requires** it at **standard** and **enterprise**.

| Profile | Shape |
|---|---|
| **lean** (skipped) | No artifact. Internal stakeholders are the product owner alone. If the buyer is not the user, one line in the vision or the Lean Canvas Customer Segments names who decides. If the user asks for a map anyway: delivery half only, two to four people, no grid needed: `./examples/01-lean-lunch-tracker.md` |
| **standard** (SMB B2B, self-serve, consumer) | Delivery register of two to five roles (product owner, design partners, perhaps one reviewer) on the grid with an engagement plan; a buying committee of two to four roles for the target segment with one Mobilizer hypothesis and one Blocker; decision rights for three to five decisions. Self-serve does not remove the committee: it appears at procurement, when security and finance review a trial a user started. A pure consumer purchase records "no committee: the user buys", with the reason: `./examples/02-standard-ledgerline.md` |
| **enterprise** (sales-led, regulated, multi-tenant) | A committee **per segment or tenant type**, each with Mobilizer and Blocker hypotheses, a collective-learning plan and a consensus kit per role; salience for regulators and auditors; a delivery map with Eden and Ackermann's **influence links** between teams; a pre-wiring order for every gate review; RACI or RAPID with exactly one A per decision and an explicit Agree where a sign-off can veto: `./examples/03-enterprise-platform.md` |

## The Rules

**1. Two halves, never one grid.** Delivery stakeholders and committee roles are listed in separate sections. A role appears on the delivery side only when a real person in it is engaged (a design partner's office manager who reviews the beta is delivery; "office managers at 5–50-staff firms" is a committee role). Beneficiaries and outside parties (auditors, regulators, channel partners) go where they are actually engaged.

**2. The grid uses a stated scale.** Mendelow's grid is qualitative: each stakeholder is **high** or **low** on power and on interest, with a one-line reason. If a number is kept, use **1–5 with 3 and above as high**, and say so in the artifact; never a 1–3 score on a 2×2, where 2 lands nowhere. Quadrants, with Eden and Ackermann's names as aliases: **Manage Closely** (high power, high interest; Mendelow's key players, their Players), **Keep Satisfied** (high power, low interest; Context setters), **Keep Informed** (low power, high interest; Subjects), **Monitor** (low on both; the Crowd). The quadrant routes effort; it is not the plan. Detail: `./references/stakeholder-analysis-tools.md`.

**3. A high-power, low-interest stakeholder is mitigated before they are asked.** The Context setter who has not noticed you yet (a security reviewer, a CISO, a finance approver) is the profile that silently kills a launch. Give them what answers their concern **before** the request reaches them. Match the lever to the concern: a factual brief for security trust; transparency into how the product's automated decisions are reached for someone whose doubt is about trusting its outputs (Srinivasan, *Simple Data / MDM*); and, for a powerful person who is not yet motivated, a short change story beside the facts, because facts alone rarely move a risk-averse reader (Dietz and Silverman, *Business Storytelling For Dummies*).

**4. Re-score on urgency, not only at gates.** Positions move. Mitchell, Agle and Wood's **stakeholder salience** says attention follows power, legitimacy and **urgency**; a stakeholder who gains urgency (a deadline, an incident, an audit, a deployment request) is re-scored the day it happens. Re-score everyone at each phase gate and mark moving stakeholders with an arrow.

**5. Committee roles are hypotheses with a belief, an objection and a proof.** For each role: what it must believe to say yes, its likely objection, the evidence that answers it, its **likely** profile, and what it loses by staying put. Profiles are attitudes, not job titles: a CISO can be a Skeptic, a Friend or a Blocker. Label every profile "likely" and say how design partners will confirm it. The agent cannot hold those conversations; the user does. Detail: `./references/buying-committee.md`.

**6. Name one Mobilizer hypothesis and one Blocker per segment, and the cost of no decision.** *The Challenger Customer*: deals rarely die to a rival; they stall because the group cannot agree and returns to the status quo. Name who can move the organisation (a **Mobilizer**: Go-Getter, Teacher or Skeptic), who defends the status quo (the **Blocker**, handled by the Mobilizer, not converted by you), and what no decision costs each role. Do not mistake the **Friend**, who answers every email, for the Mobilizer.

**7. Decision rights: exactly one Accountable, and it is a person.** RACI (from practice; no single author): Responsible does the work, **Accountable** owns the outcome (one per row), Consulted gives two-way input before, Informed hears after. **An AI agent or a hook may be Responsible, never Accountable**; accountability needs someone who can be asked why. Where a security or compliance sign-off can block a release, show it as Bain's RAPID **Agree** (a formal veto), not hidden as a Consulted. Keep Consulted lists short; everyone consulted means nothing decided.

**8. Pre-wire before group reviews.** For each gate review the map lists who is seen **one at a time, in what order**, before the meeting (Lombardo et al., *Product Roadmaps Relaunched*: shuttle diplomacy and nemawashi), so the meeting confirms an alignment rather than starting a fight. On the customer side the equivalent is **collective learning**: the Mobilizer gets the committee to agree on the problem before anyone compares solutions.

**9. Roles, not personal names.** Delivery stakeholders are written as roles ("the product owner", "design partner 2's office manager"); a personal name appears only with that person's consent, and never for the product owner. Committee roles are never named people.

## How to Build One

1. **Read the inputs** (Where It Sits). Confirm the profile; at lean, stop unless the user asks.
2. **List delivery stakeholders**: the product owner, the design-partner cohort (by company or role), and every reviewer, approver, internal team or outside party whose cooperation the build or launch needs.
3. **Place them**: high or low on power and interest, with a reason; quadrant; salience note where urgency is near (rules 2 and 4).
4. **Write the engagement plan**: per stakeholder or quadrant, what they need, channel, cadence, owner (a person), re-score trigger; pre-mitigate every Context setter (rule 3).
5. **Write the pre-wiring order** for the next gate review (rule 8).
6. **Write decision rights** for the decisions that matter: one A per row, a person; agents only R; Agree for vetoes (rule 7).
7. **For each target segment, list committee roles**, starting from Moore's economic buyer vs user; fill belief, objection, proof, likely profile and loss by staying put; name the Mobilizer hypothesis, the Blocker and the cost of no decision (rules 5 and 6). At enterprise add the collective-learning plan and the consensus kit.
8. **Write the Blocker Risk Register** across both halves.
9. **Validate** against `./resources/stakeholder-map-checklist.md`, run `./scripts/check-stakeholder-map.py <artifact>` for the mechanical checks (one A per row, no agent as A, quadrant matches the stated scale, no cadence in the committee), then write the artifact from `./templates/stakeholder-map.md` at `strategy/stakeholder-map.md`.

**Examples, simple to complex:**
- Lean internal lunch tracker: artifact skipped, and the half-page delivery list written when the user asked: `./examples/01-lean-lunch-tracker.md`.
- Standard B2B SaaS (Ledgerline): a mixed one-grid draft split into delivery and committee halves; a two-A RACI and a misplaced reviewer fixed: `./examples/02-standard-ledgerline.md`.
- Enterprise multi-tenant platform: committees per tenant type, regulator salience, influence links between platform teams, RAPID with a security Agree, pre-wiring order: `./examples/03-enterprise-platform.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Split | Delivery and committee halves are separate sections | Customer archetypes and the team on one grid |
| Scale | High/low with reasons, or 1–5 with "3+ is high" stated | 1–3 scores on a 2×2; a 2 with no rule |
| Context setters | Every high-power, low-interest stakeholder has a mitigation delivered before the ask | "Keep satisfied" with no action |
| Engagement plan | Every delivery stakeholder in Manage Closely and Keep Satisfied has need, channel, cadence and a person who owns it | "We'll update stakeholders as needed" |
| Committee rows | Every role has belief, objection, proof, likely profile, loss by staying put | A list of titles |
| Mobilizer and Blocker | One of each per segment, labelled likely, with how it is confirmed | "CISO = Blocker" as fact; the friendliest contact called the champion |
| No cadence on archetypes | Committee section has no frequency, channel or newsletter | Monthly updates to "the CFO" |
| Decision rights | Exactly one A per decision, a person; agents R only; vetoes as Agree | Two As; an agent as A; security sign-off as C |
| Shape and scale | Frontmatter `name`, `version`, `phase`, `owner`, `created`, `summary`, `profile`; matches the Scale table | Missing `summary`; a lean product with a full map |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **One grid for everyone** | Archetypes get cadences nobody can deliver; real reviewers get lost among hypotheses |
| **Users-only map** | The people who stop products (budget holders, security reviewers) mostly never log in |
| **Grid without actions** | The grid routes effort; with no engagement plan it is decoration |
| **Static register** | Interest jumps the day a request lands; a map scored once is wrong by the next gate |
| **Blocker denial** | Blockers always exist; an empty column means they have not been found yet |
| **Shared or automated accountability** | Two As is no A; an agent as A means nobody answers for the decision |
| **Hidden veto** | A sign-off that can block a release, recorded as "Consulted", surprises everyone at the gate |
| **Friend-as-champion** | The contact who answers every email may be a Talker who cannot move the organisation |
| **Newsletter to an archetype** | A role in a segment cannot be engaged; it can only be hypothesised and tested |
| **Consensus on the solution first** | Showing options before the committee agrees on the problem invites each role to defend its own priority, and the group stalls into no decision |

Use canonical terms from `glossary-management`: **Delivery Stakeholder**, **Buying Committee**, **Power/Interest Grid**, **Stakeholder Salience**, **Mobilizer**, **No Decision**, **Consensus Kit**, **RACI**, **Design Partner**. Run `methodology-review` before hand-off.
