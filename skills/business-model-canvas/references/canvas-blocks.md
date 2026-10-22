# Canvas Blocks — Lookup Lists

Self-contained. Read this when filling or reviewing a block: what each block is, the question it answers, the lists to choose from, and the mistakes that make a block look complete while breaking the model. Sources: Osterwalder and Pigneur, *Business Model Generation* (the nine blocks and their typologies); Maurya, *Running Lean* (the Lean Canvas); Ramanujam and Tacke, *Monetizing Innovation* (willingness to pay, charging unit); Olsen, *The Lean Product Playbook*; Moore, *Crossing the Chasm*; Dunford, *Obviously Awesome*.

The typology lists below are recalled from the books and may differ slightly in wording from the printed text. Use them as prompts for choosing, not as closed lists to quote.

---

## The layout

The full canvas has a **value side** (Value Propositions in the centre; Customer Relationships, Channels and Customer Segments on the right), an **efficiency side** (Key Partnerships, Key Activities, Key Resources on the left) and a **financial rail** (Cost Structure and Revenue Streams across the bottom). The right side says what value is delivered to whom; the left says how it is produced; the bottom says whether what the right earns covers what the left costs.

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

On the Lean Canvas the same positions hold Problem (with Existing Alternatives), Solution, Key Metrics, Unique Value Proposition (with High-Level Concept), Unfair Advantage, Channels and Customer Segments (with Early Adopters); the bottom rail is unchanged.

| Full-canvas position | Lean Canvas block in that position |
|---|---|
| Key Partnerships | **Problem** + Existing Alternatives |
| Key Activities | **Solution** |
| Key Resources | **Key Metrics** |
| Value Propositions | **Unique Value Proposition** + High-Level Concept (renamed and sharpened, *not* unchanged) |
| Customer Relationships | **Unfair Advantage** |
| Channels | Channels (unchanged) |
| Customer Segments | Customer Segments + Early Adopters |
| Cost Structure, Revenue Streams | unchanged |

The pairing is positional. Maurya argues the change as removals and additions, not four one-to-one trades: partners, activities and resources are about running a business that does not exist yet; relationships are covered early by channels and direct contact with early customers; the four added blocks hold the startup's real risk.

---

## Customer Segments

**Question.** Who are we creating value for, and who matters most?

**Segment types** (Osterwalder): *mass market*, *niche market*, *segmented* (related groups with slightly different needs), *diversified* (unrelated groups), *multi-sided platform* (two or more interdependent groups, all needed for the model to work; see `business-model-patterns.md`).

**How to work it.**
- Form segments from **needs and willingness to pay** first; attach the firmographic or demographic description afterwards so the segment can be found (Ramanujam and Tacke).
- Separate **users** (who operate the product) from the **economic buyer** (who owns the budget and the risk, Moore's term). Each gets its own customer profile when their pains differ.
- Rank segments and name the primary. The beachhead criteria and the order of later segments ("bowling alley") belong to `gtm-strategy`.
- Lean Canvas: name the **Early Adopters**, the narrow first group who have the problem worst and know it, not the eventual market. One canvas per segment whose top problem differs.

**Mistakes.** "All SMBs" as one segment (Olsen's blended average: nobody is well served). A persona in place of a segment (a persona is one archetype inside a segment). One value proposition written for a buyer and a user who want different things.

## Value Propositions (full canvas) / Unique Value Proposition (Lean)

**Question.** What value do we deliver to this segment, and why us rather than the alternative?

**Value elements** (Osterwalder, prompts): newness, performance, customisation, getting the job done, design, brand / status, price, cost reduction, risk reduction, accessibility, convenience / usability. Quantitative (price, speed) or qualitative (design, experience).

**How to work it.**
- One entry per segment, from that segment's Value Proposition Canvas (`value-proposition-canvas.md`): only the top-ranked pains and gains the value map addresses.
- Each entry ends with the **competing alternative** it beats ("…unlike a spreadsheet and email reminders"), taken from `competitive-analysis`. If a competitor delivers the same value, it is table stakes, not a proposition.
- Dunford's intermediate step: group the unique attributes into **value themes**, then state the theme the segment cares about most.
- Lean Canvas **UVP**: one clear, compelling message that turns an unaware visitor into an interested one, aimed at the top Problem for the Early Adopters. Optional **High-Level Concept**: an "X for Y" analogy.

**Mistakes.** Feature-first ("real-time scanning" is a feature; "know before the audit which files put you at risk" is value). Undifferentiated value. A UVP that lists five benefits.

## Channels

**Question.** Through which channels does each segment want to be reached, and which work best for the cost?

**Channel phases** (Osterwalder): awareness → evaluation → purchase → delivery → after-sales. **Own vs partner**, **direct vs indirect**: own channels give margin and control; partner channels give reach at lower margin.

**Mistakes.** Conflating the sales channel with the delivery channel (different motions, different costs). Omitting after-sales, where cost-to-serve is decided. A channel that reaches the eventual market but not the Early Adopters. Restating the GTM channel plan: name the channel and phase, let `gtm-strategy` own the plan.

## Customer Relationships (full canvas only)

**Question.** What relationship does each segment expect, and what does it cost?

**Types** (Osterwalder): personal assistance, dedicated personal assistance, self-service, automated services, communities, co-creation. **Motivations:** acquisition, retention, boosting sales (upselling).

**Mistakes.** Promising dedicated assistance the Cost Structure cannot fund at the price. Treating the relationship as an experience choice rather than a major cost driver.

## Revenue Streams

**Question.** For what value will each segment pay, how, and on what evidence?

**Revenue types** (Osterwalder): asset sale, usage fee, subscription, lending / renting / leasing, licensing, brokerage fee, advertising. **Transaction** (one-time) vs **recurring**. **Pricing mechanism:** fixed (list, feature-dependent, segment-dependent, volume-dependent) or dynamic (negotiation, yield management, auction).

**What the block states** (Ramanujam and Tacke):
- The revenue type and mechanism.
- The **charging unit** (pricing metric, the "per what"). Three tests: does it track the value the customer receives; can the customer predict the bill; does it grow as the customer succeeds?
- The **value anchor**: the quantified value to the customer that bounds the price from above.
- **Willingness-to-pay evidence**: a range per segment, labelled *stated* (from conversations, a hypothesis) or *committed* (pre-order, letter of intent, paid pilot: evidence).
- A pointer: "Price levels, tiers and strategy: `gtm-strategy` Pricing Model." The canvas does not restate them. At lean (no GTM artifact), one price point with its basis, or "not monetised" with the reason.

**Mistakes.** A stream with no segment receiving a value proposition behind it. Pricing to cost (value anchor blank). One price for segments with clearly different willingness to pay. Treating stated interest as committed.

## Key Resources (full canvas only)

**Types:** physical, intellectual (often the moat: data, models, rules, patents), human, financial. **Mistake:** generic resources ("a team", "money"); failing to name the one or two that are hard to replicate.

## Key Activities (full canvas only)

**Types:** production, problem solving, platform / network. Only the activities without which value could not be delivered. **Mistake:** listing everything the company does; an activity with no resource behind it.

## Key Partnerships (full canvas only)

**Types:** strategic alliance between non-competitors, coopetition, joint venture, buyer–supplier. **Motivations:** optimisation and economy of scale; reduction of risk and uncertainty; acquisition of resources or activities. **Mistakes:** aspirational partners (only those that exist or can realistically be signed in the planning horizon); a customer listed as a partner.

## Cost Structure

**Spectrum:** cost-driven ↔ value-driven. **Characteristics:** fixed, variable, economies of scale, economies of scope (often the honest answer to "why does margin improve as we grow?").

**How to work it.** The three to five largest items, fixed vs variable, always including **customer acquisition cost** and **cost to serve** (per segment where they differ; per region where hosting or support differs). Run a **Fermi check**: price × customers needed to reach the stated minimum success, against these costs. A Revenue Stream that cannot plausibly cover the costs at any realistic conversion fails before any interview.

**Mistakes.** Only infrastructure and engineering listed. An accounting list that is never compared with the revenue above it.

---

## Lean Canvas blocks

### Problem + Existing Alternatives

The top one to three problems for the Early Adopters, **ranked**, and for each how it is solved today without you: workarounds, spreadsheets, a competitor, doing nothing. The alternatives are the true competitive baseline (Dunford's competitive alternatives). On a later pass, rank from `jtbd-analysis`'s scored jobs; do not copy an interview script here.

### Solution

The smallest set of capabilities that addresses each listed problem, one line per problem. Nothing that maps to no problem. Kept thin so it stays testable; the MVP is the smallest thing that delivers the UVP to the Early Adopters.

### Key Metrics

The few numbers that show the model working, organised on the customer lifecycle (McClure's **AARRR**, as Maurya uses it): Acquisition, Activation, Retention, Revenue, Referral. One rate or cohort metric for each step that matters at this stage; mark the current bottleneck. Reject running totals ("cumulative sign-ups"): they only go up and decide nothing (actionable vs vanity metrics).

### Unfair Advantage

Something that **cannot be easily copied or bought** (Maurya). Candidates: insider knowledge, a community or customer base you already have, network effects, a data asset that grows with use, the right endorsements, an asymmetry the strategy kernel's guiding policy relies on. **Not** unfair advantages: features, being first, speed, hard work, passion, "a great team" in general. If nothing survives the filter, write `unknown: tested by <what would show one exists>`.

---

## Risk by block

| Risk | Question | Blocks |
|---|---|---|
| **Product** | Is the problem real, and does the solution solve it? | Problem, Solution, UVP / Value Propositions, Key Metrics |
| **Customer** | Can we reach the Early Adopters and the segment? | Customer Segments, Channels (and Customer Relationships on a full canvas) |
| **Market** | Is it a viable business? | Revenue Streams, Cost Structure, Unfair Advantage (and Key Partnerships / Resources on a full canvas) |

How to rank them and write the tests: `evidence-and-risk.md`.
