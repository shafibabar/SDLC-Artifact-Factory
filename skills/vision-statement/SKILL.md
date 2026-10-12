---
name: vision-statement
description: >
  Teaches how to write a product vision statement: the durable, multi-year picture
  of the future a product is building toward, with the customer as the protagonist,
  plus the decisions the vision rules out and the north star it implies. Use when
  writing, reviewing or revising a product vision, separating vision from mission
  or from the positioning statement, telling the vision to a team or investor,
  deciding whether a product area or team needs its own vision, or setting a
  north star metric. Used by the product-strategist agent at the start
  of every Strategy phase (/sdlc-strategy) to anchor every later artifact.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, vision, product-discovery, north-star]
produces: vision-statement
domain: strategy
status: stable
related: [mission-statement, gtm-strategy, okr-authoring, competitive-analysis, glossary-management]
sources:
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/product-strategy-and-gtm/obviously-awesome-dunford.md
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/loved-lauchengco.md
  - research/storytelling-and-narrative/the-best-story-wins.md
  - research/storytelling-and-narrative/business-storytelling-for-dummies.md
---

# Vision Statement

## Purpose

A vision answers one question: **what future are we building toward, and why does it matter?** In Cagan's framing (*Inspired*), the product vision is the multi-year picture of what the product is trying to become and why it matters. It is durable and rarely revised. Strategy is a separate thing: the focused, sequenced bets that move toward the vision, which means saying no to most other things. The vision comes first, and every later artifact (mission, roadmap, OKRs, GTM, architecture) must trace back to it.

A vision is not a feature list, a mission, or a sales pitch. It describes the world as it will be when the product has succeeded, so a team member can use it to settle a real decision.

---

## Vision, Mission and Positioning Are Three Different Artifacts

| | Vision (this skill) | Mission (`mission-statement`) | Positioning statement (`gtm-strategy`) |
|---|---|---|---|
| Question | Where are we going, and why does it matter? | What do we do today to get there? | Why should *this buyer* pick us over *that alternative*? |
| Horizon | 3–5+ years; rarely changes | Current stage; evolves with strategy | Re-tested at every launch stage and after real win/loss evidence (Lauchengco, *Loved*) |
| Audience | The team and its backers | The team | The market |
| Shape | A future-state logline | "We [verb] for [user] so that [outcome]" | "For [ICP] who [pain], [product] is a [category] that [benefit]. Unlike [alternative], …" |

**Do not write the vision in the positioning template.** "For… who… is a… Unlike…" is Moore's positioning statement (*Crossing the Chasm*), and Dunford (*Obviously Awesome*) flags it as a compression of positioning work. It names a market category and a competitor, which tie it to today's market rather than to the future the product creates. The positioning statement belongs in `gtm-strategy`.

---

## Required Components

| Component | Question it answers | Guidance |
|---|---|---|
| **Protagonist** | Whose world changes? | A real, named user group, and it is the **hero**. The product enables the change; it is not the main character (Luhn, *The Best Story Wins*). |
| **Today's need** | What do they struggle with now? | State the underlying **need**, not the surface want. "Prove what sensitive data they hold" is a need; "a compliance dashboard" is a want. |
| **Future state** | What is true for them when we succeed? | An observable change in their world, still true in 3–5 years. |
| **Why it matters** | What is at stake? | The consequence for the protagonist, or the world, if this future arrives or doesn't. |
| **Durable bet** | What belief makes this future reachable? | The lasting conviction the product rests on (e.g. "their data never has to leave their boundary"). It must be technology-agnostic. It is *not* a competitor comparison. |

The artifact also carries two consequences of the vision:
- **What this vision rules out:** 2–3 plausible directions it makes a "no". A vision that rules nothing out cannot settle a decision (Cagan: strategy is saying no).
- **North star implication:** the single metric that would show the vision is being achieved.

---

## One Product, Many Teams

A shared vision is what lets many teams decide independently and still build one product. That does **not** mean each team writes its own vision. The chain is Cagan's: **one product vision → product strategy (which problems first) → team objectives** (`okr-authoring`). A team stays connected by knowing which part of the shared future it is moving, not by holding a picture of its own.

**Default: one vision per product; teams get objectives, not visions.** A vision should last 3–5+ years, but team boundaries change with every reorganisation. Team-level visions also tend to diverge (one team optimises for "every source connected in minutes", another for "no data leaves the tenant boundary"), and the conflict surfaces only where their work meets.

**A sub-vision is warranted only when all four hold:**

1. **Durable area, not a team.** It belongs to a product line or platform that outlives any team structure.
2. **A distinct slice or a distinct protagonist.** Either it delivers one named slice of the parent's future state for the same protagonist (a product line), or it serves a genuinely different user the parent depends on (an internal developer platform whose protagonist is the product's engineers).
3. **Traceable, never rival.** Its future state is a consequence of the parent's, and nothing it pursues is something the parent rules out. Its north star rolls up into the parent's.
4. **Changes decisions.** Deleting it would make teams decide differently. If nothing would change, it is a slogan; delete it.

An MVP or a single-line product needs one vision. Read `./examples/03-enterprise-platform-cascade.md` for a full cascade, including what the teams below each line get instead of a vision.

---

## How to Write One

1. **Start from the need, not the product.** Read the problem statement in the product's context file. Name the protagonist and the need behind their stated want.
2. **Picture the future state concretely.** Ask what the protagonist can do, know or stop worrying about in 3–5 years, and write it as their changed world.
3. **Compress to a logline**, at most 60 words, with the protagonist as the subject: *[Protagonist] [can / no longer has to] [future state], [because / so that] [why it matters], [durable bet].* Compress beats rather than dropping them (Luhn): all five components should still be present in miniature.
4. **Write what it rules out.** For each of 2–3 tempting directions, check whether the vision clearly says no. If it can't, sharpen it.
5. **Derive the north star.** If you can't name one metric that tracks the future state, the future state is too vague.
6. **Optionally, tell it.** For onboarding, investors or a sceptical stakeholder, expand the logline into a 120–180-word story. Read `./references/telling-the-vision.md` for the technique. The told version never replaces the ≤ 60-word artifact.
7. **Validate** against the quality criteria below, then produce the artifact from `./templates/vision-statement-template.md`.

**Examples, simple to complex:**
- An internal tool, the simplest case: read `./examples/01-internal-tool.md`.
- A B2B SaaS product, including rewriting a positioning-template "vision" into a real one: read `./examples/02-b2b-saas-rewrite.md`.
- An enterprise multi-tenant platform where a company vision cascades into product-line visions, and teams below them get objectives instead: read `./examples/03-enterprise-platform-cascade.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Length | ≤ 60 words | > 60 words |
| Horizon | Describes a future 3–5+ years out | Describes what the product does today (that's a mission) |
| Protagonist | A real, specific user group is the subject and hero | "Everyone", "businesses", or the product/company as hero |
| Need, not want | The stated pain is the underlying need | A feature request restated as a pain |
| Not a positioning statement | No market category and no named competitor | Uses the "For… who… is a… Unlike…" template |
| Decides something | Its "rules out" list names real, tempting directions it rejects | Rules nothing out, so it can justify any roadmap |
| Technology-agnostic | Outcomes and beliefs, not implementation | Names a stack, platform or protocol |
| Stable | Survives any single product decision for 3+ years | Invalidated by one roadmap change |
| North star | Implies one measurable metric | No metric could track it |
| Cascade (sub-visions only) | Passes all four sub-vision tests; names its parent and the slice it delivers | Written for a team, or pursues something the parent rules out |

---

## Anti-Patterns

| Anti-pattern | Example | Why it fails |
|---|---|---|
| **Positioning in disguise** | "For SMB compliance teams who…, X is a data intelligence platform… Unlike cloud DLP…" | A market-facing comparison tied to today's category and competitor; that's `gtm-strategy`'s job |
| **Company as hero** | "To become the leading data governance company" | The protagonist is the vendor; nobody's world changes |
| **Too tactical** | "To provide a dashboard that scans Google Drive" | A feature, not a future state |
| **Unfalsifiable** | "To help every company manage data better" | Rules nothing out, so no decision is settled |
| **Disguised mission** | "We scan storage and classify sensitive data" | Present-tense work belongs in `mission-statement` |
| **Technology-locked** | "The best Kubernetes-native governance tool" | Technology changes; the vision must outlast it |
| **A vision per team** | "Ingestion team vision: every source connected in minutes" | Teams reorganise faster than visions should change, and team visions pull apart; the team needs an objective drawn from the strategy |

Use the canonical terms from `glossary-management`: **North Star Metric**, **Jobs To Be Done** (the need is the job), **Outcome-Driven Development** (the future state is an outcome, not a feature).
