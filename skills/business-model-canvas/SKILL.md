---
name: business-model-canvas
description: >
  Teaches the product-strategist to build a Business Model Canvas — the nine
  building blocks (Customer Segments, Value Propositions, Channels, Customer
  Relationships, Revenue Streams, Key Resources, Key Activities, Key
  Partnerships, Cost Structure) and the Lean Canvas variant (Problem, Solution,
  Key Metrics, Unfair Advantage replacing four blocks) — including which variant
  to use when, how the blocks constrain each other, and the canvas artifact. Used
  during Strategy to make the business model of a product explicit before deeper
  design.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, business-model, canvas, lean-canvas, value-proposition, discovery]
related: [gtm-strategy, competitive-analysis, vision-statement, jtbd-analysis, impact-mapping]
---

# Business Model Canvas

## What the Canvas Is

A Business Model Canvas (Alexander Osterwalder, *Business Model Generation*) maps a
whole business onto a single page of nine interlocking building blocks. For a
product team it answers one question: **is this a coherent, viable business, and
do the nine blocks actually fit together — or is one block quietly contradicting
another?** Its value is not the nine lists; it is the *fit between* them.

Completing the canvas during Strategy, before architecture or roadmap, surfaces
business-model risk while it is still cheap to change. It sits alongside the other
Strategy artifacts: it consumes segment thinking from `user-persona`, feeds the
Value Propositions block into `gtm-strategy`'s positioning, and its Customer
Segments block draws on `competitive-analysis`.

---

## BMC or Lean Canvas — Choose Before You Fill Anything In

The variant is a decision, not a default. Pick it from where the product sits on
the certainty curve:

| Use **full BMC** when… | Use **Lean Canvas** (Ash Maurya) when… |
|---|---|
| The business model is broadly known — established company, a new line in a proven model, or a validated product | The product is early-stage / pre-revenue and the biggest unknowns are *the problem itself* and *whether anyone will pay* |
| Partners, resources, and activities are real and nameable | Partnerships and internal activities are still guesses that would project false certainty |
| You are optimising and communicating a model | You are hunting for product-market fit and want the riskiest assumptions on the page |

The Lean Canvas keeps the same one-page shape but **replaces four BMC blocks**
(Key Partnerships, Key Activities, Key Resources, Customer Relationships) with
four risk-focused blocks (**Problem, Solution, Key Metrics, Unfair Advantage**).
Which block replaces which, and why each swap makes sense at the startup stage, is
in `references/canvas-blocks.md`. For this repo's first product: use **Lean
Canvas** during Stage 1 (closed beta), migrate to **full BMC** at Stage 2 (soft
launch) once problem and solution are validated.

---

## The Nine Blocks (BMC)

The canvas has a **Value** side (centre and right — what the customer experiences)
and an **Efficiency** side (left — what the business does internally), with Revenue
and Cost running across the bottom.

```
┌──────────────┬──────────────┬────────────────┬────────────────┬──────────────┐
│ Key          │ Key          │ Value          │ Customer       │ Customer     │
│ Partnerships │ Activities   │ Propositions   │ Relationships  │ Segments     │
│              ├──────────────┤                ├────────────────┤              │
│              │ Key          │                │ Channels       │              │
│              │ Resources    │                │                │              │
├──────────────┴──────────────┴────────────────┴────────────────┴──────────────┤
│ Cost Structure                             Revenue Streams                    │
└───────────────────────────────────────────────────────────────────────────────┘
```

Each block, in one line — full definition, the question it answers, and its
common mistakes are in `references/canvas-blocks.md`:

1. **Customer Segments** — who you create value for; the distinct groups with
   distinct needs and willingness to pay (segments, not personas).
2. **Value Propositions** — the pain relieved and gain created for each segment;
   the bridge every other block builds on. Not a feature list.
3. **Channels** — how you reach, sell to, deliver to, and support each segment.
4. **Customer Relationships** — the relationship type each segment expects
   (self-service, dedicated, community, co-creation…).
5. **Revenue Streams** — what each segment will pay for, the mechanism, and the
   value anchor that justifies the price.
6. **Key Resources** — the assets the value proposition requires (physical,
   intellectual, human, financial) — often the moat.
7. **Key Activities** — the few activities without which value cannot be
   delivered (production, problem-solving, platform).
8. **Key Partnerships** — the suppliers and partners who provide resources or
   perform activities you should not own yourself.
9. **Cost Structure** — the costs the model inherits from its resources and
   activities, including CAC and cost-to-serve.

---

## The Load-Bearing Principle: Blocks Constrain Each Other

A canvas is a **dependency graph, not nine independent lists.** A change in one
block ripples outward and must be re-checked, not patched locally:

- Change a **Customer Segment** → its **Channels**, **Customer Relationships**, and
  **Revenue Streams** all likely change with it (a new segment reached, related to,
  and monetised differently).
- Weaken a **Value Proposition** → every block downstream is building on a flawed
  foundation, because Value Propositions are the hinge between the customer side
  and the business side.
- Add a **Key Activity** with no **Key Resource** behind it, or a **Revenue Stream**
  with no **Value Proposition** justifying it → an incoherent model that looks
  complete but does not hold.

This mirrors the dependency discipline in Dan Olsen's **Product-Market Fit
Pyramid** (`related: jtbd-analysis`) — an error in a lower layer silently
invalidates everything stacked above it. After filling all blocks, run the
seven-question **coherence check** in `references/canvas-blocks.md`; a canvas that
skips it is a decorated risk register.

---

## Value Propositions Must Trace to a Ranked Need

The single most common weak canvas states a plausible-sounding value proposition
with nothing behind it. Every Value Propositions entry should cite the **ranked
underserved need** it satisfies (from a `jtbd-analysis` pass, ideally scored with
Olsen's Opportunity Score) — the same way `impact-mapping` requires a WHAT to
trace to a WHY. A value proposition that names a customer pain or gain is valid; one
that restates a product feature ("real-time compliance scanning") is not.

---

## How to Use This Skill

1. **Choose the variant** (table above) before filling anything in.
2. **Fill the blocks** using the one-line prompts here; open
   `references/canvas-blocks.md` for each block's full definition, its question,
   and its common mistakes, plus the four Lean Canvas substitutions.
3. **Run the coherence check** (seven questions, in references) and revise the
   block containing any gap.
4. **Emit the artifact** using the template and worked example in
   `references/canvas-template-and-example.md`.
5. **Re-validate at every launch-stage transition** (closed beta → soft launch →
   GA) — the blocks that survive contact with paying customers are rarely the ones
   you first drew.

---

## Quality Bar

| Criterion | Pass |
|---|---|
| Completeness | Every block (nine for BMC, or the variant's set) has a substantive entry — no "TBD" |
| Segment specificity | Segments defined by size band, vertical, and regulatory exposure — never "all SMBs" |
| Value-prop form | States pain relieved + gain created, differentiated, traced to a ranked need |
| Revenue traceability | Every Revenue Stream traces to a Value Proposition a segment will pay for |
| Cost realism | CAC and cost-to-serve appear alongside build/run costs |
| Coherence | All seven coherence questions pass, or the gap block is revised |
| Defensibility | At least one canvas item competitors cannot easily replicate |

Full worked reasoning, the block-by-block deep dive, the coherence checklist, the
Lean Canvas substitutions, the artifact template, and a fully worked canvas for
this repo's data-estate/compliance product live in `references/`.
