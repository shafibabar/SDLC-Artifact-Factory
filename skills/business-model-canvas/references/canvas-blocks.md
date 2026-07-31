# Canvas Blocks — Deep Reference

Full treatment of every Business Model Canvas (BMC) block, the four Lean Canvas
substitutions, and the coherence check. Grounded in Alexander Osterwalder &
Yves Pigneur, *Business Model Generation*; Ash Maurya, *Running Lean* (the Lean
Canvas); and the value-proposition/needs-fit discipline in Dan Olsen, *The Lean
Product Playbook*. Read this when filling a block, not the SKILL.md body alone.

For each BMC block: its **definition**, the **question it answers**, and the
**common mistakes** that make the block look complete while quietly breaking the
model's coherence.

---

## The Two Halves and the Bottom Rail

The BMC splits into a **Value side** (Value Propositions in the centre; Customer
Segments, Channels, and Customer Relationships on the right — everything the
customer sees and experiences) and an **Efficiency side** (Key Partnerships, Key
Activities, and Key Resources on the left — everything the business does to
produce and deliver that value). **Revenue Streams** and **Cost Structure** run
across the bottom as the financial rail. The right side describes *what* value is
delivered and *to whom*; the left side describes *how* it is produced; the bottom
tells you whether *what you earn from the right exceeds what the left costs.*

---

## BMC Block 1 — Customer Segments

**Definition.** The distinct groups of people or organisations the business aims
to reach and serve. A segment is a group with a *distinct need*, reached through
a *distinct channel*, expecting a *distinct relationship*, with a *distinct
willingness to pay* — not a demographic slice for its own sake.

**Question it answers.** *Who are we creating value for? Who are our most
important customers?*

**How to work it.**
- List every distinct segment. For B2B, segment by company profile: size band,
  industry vertical, regulatory exposure, technical maturity.
- Rank them: which is the primary Ideal Customer Profile (ICP)?
- Distinguish **users** (who operate the product) from **buyers** (who sign the
  cheque) whenever they differ — both must be served, and they often want
  different things.

**Common mistakes.**
- **"All SMBs" as one segment.** If two groups need different value, buy through
  different channels, or pay differently, they are two segments — collapsing them
  hides the fact that no single group is actually well served (Olsen's blended-
  average trap).
- **Confusing a persona with a segment.** A persona is one archetypal person; a
  segment is the market group. A canvas segments the market, then personas detail
  the humans inside a segment.
- **Listing buyers as if they were users** (or vice versa) and then writing one
  value proposition that satisfies neither.

---

## BMC Block 2 — Value Propositions

**Definition.** The bundle of products and services that creates value for a
specific segment — the reason that segment chooses you over the alternative. It
is stated as *pain relieved* + *gain created*, not as a feature list.

**Question it answers.** *What value do we deliver? Which problem do we solve or
need do we satisfy, for which segment?*

**How to work it.**
- One value proposition per segment (they may legitimately differ).
- State it as: *what the customer gains* + *which pain is relieved*.
- It must be **differentiated** — if a competitor delivers the same value, it is
  not a proposition, it is table stakes.
- **Trace it to a ranked underserved need** (from `jtbd-analysis`, ideally scored
  with Olsen's Opportunity Score = Importance + max(Importance − Satisfaction, 0)),
  so a reviewer can confirm it targets the highest-opportunity need, not merely a
  plausible-sounding one.

**Common mistakes.**
- **Feature-first propositions.** "Real-time compliance scanning" is a feature.
  "Know within 30 minutes whether your estate has a SOC 2 CC6 violation — without
  a single file leaving your infrastructure" is a value proposition.
- **Undifferentiated value** that any competitor could also claim.
- **A proposition with no traced need behind it** — differentiation the customer
  does not actually care about.

Value Propositions are the **hinge of the whole canvas**: weaken this block and
every block downstream builds on a flawed foundation.

---

## BMC Block 3 — Channels

**Definition.** How the business reaches its segments to deliver the value
proposition — across the full path: awareness, evaluation, purchase, delivery,
and after-sales support.

**Question it answers.** *Through which channels do our segments want to be
reached, and how are we reaching them now?*

**How to work it.** Separate the two jobs a channel does: **reaching prospects**
(awareness and sales) and **delivering the product** (deployment and support).
For a private-deployment product, the delivery channel *is* the deployment
mechanism (self-hosted, customer cloud, managed private) and can itself be part
of the differentiation.

**Common mistakes.**
- **Conflating the sales channel with the delivery channel** — they can be
  entirely different motions with different costs.
- **Omitting the support phase**, which is where cost-to-serve is decided.

---

## BMC Block 4 — Customer Relationships

**Definition.** The type of relationship the business establishes with each
segment — from fully automated to deeply personal.

**Question it answers.** *What type of relationship does each segment expect us to
establish and maintain, and what does it cost?*

| Relationship type | Description | Fits |
|---|---|---|
| Self-service | Customer helps themselves | PLG products, simple setup |
| Automated | System-driven personalisation | SaaS with data-driven onboarding |
| Dedicated account management | A named human relationship | Enterprise, high-touch B2B |
| Community | Peer-to-peer support | Developer tools, open-source |
| Co-creation | Customer shapes the product | Design-partner programs |

For SMB private-deployment products, **self-service onboarding + community + light
human support** usually scales best, with **co-creation** limited to a handful of
early design partners.

**Common mistakes.**
- Promising **dedicated management** the Cost Structure cannot fund at the target
  price.
- Ignoring that the relationship type is a **major cost driver**, not just a
  customer-experience choice.

---

## BMC Block 5 — Revenue Streams

**Definition.** The cash the business generates from each segment — the pricing
model, the mechanism, and the value anchor that justifies the price.

**Question it answers.** *For what value are customers willing to pay? How do they
pay today, and how would they prefer to?*

**How to work it.** State the pricing model (from GTM strategy), the mechanism
(subscription, one-time licence, usage-based, transaction fee), the relative
contribution of each stream if several, and the **value anchor** — the concrete
thing the price is measured against (e.g., compliance-officer hours of audit-prep
saved per quarter).

**Common mistakes.**
- **A revenue stream with no value proposition behind it.** Every stream must
  trace to a proposition a segment will actually pay for.
- **Pricing to cost rather than to value** — leaving the value anchor blank.

---

## BMC Block 6 — Key Resources

**Definition.** The most important assets required to make the model work.

**Question it answers.** *Which assets does our value proposition require to be
delivered, distributed, and monetised?*

| Resource type | Examples |
|---|---|
| Physical | Servers, customer-deployed infrastructure |
| Intellectual | Proprietary algorithms, trained models, patents, curated data |
| Human | Domain expertise, engineering capability, key relationships |
| Financial | Capital, credit lines, runway |

The **intellectual** resources are usually the moat — for a private-deployment
data product, the entity-extraction pipeline, the compliance rule engine, and the
relationship-graph design.

**Common mistakes.**
- Listing **generic resources** ("a team", "money") that any competitor also has.
- Failing to name the **one or two resources that are genuinely hard to
  replicate** — the defensibility of the whole model.

---

## BMC Block 7 — Key Activities

**Definition.** The most important things the business *must do* to make the model
work — the activities without which value cannot be delivered.

**Question it answers.** *Which activities do our value proposition, channels,
relationships, and revenue streams require?*

Categories: **production** (building/running the product), **problem-solving**
(applying domain expertise to complex customer needs), **platform/network
management**.

**Common mistakes.**
- **Listing every activity the company does.** Key Activities are only those that,
  if stopped, would directly prevent value delivery.
- **A Key Activity with no matching Key Resource** — an activity you cannot
  actually perform.

---

## BMC Block 8 — Key Partnerships

**Definition.** The network of suppliers and partners that provide resources or
perform activities the business chooses not to own.

**Question it answers.** *Who are our key partners and suppliers? Which resources
do they provide, and which activities do they perform?*

Partnership motivations:
- **Optimisation / economy of scale** — buyer-supplier relationships for resources
  you should not own (cloud providers, open-source model providers).
- **Reduction of risk and uncertainty** — partners providing credibility,
  distribution, or assurance (certification bodies, channel partners).
- **Acquisition of resources or activities** — partners filling capability gaps
  (implementation partners, resellers).

**Common mistakes.**
- **Aspirational partnerships** — listing partners you hope to sign. Only
  relationships that exist or are realistically closable within the planning
  horizon belong on the canvas.
- **Listing customers as partners** — a customer is not a partner.

---

## BMC Block 9 — Cost Structure

**Definition.** All costs the business model inherits from its resources,
activities, and partnerships.

**Question it answers.** *What are the most important costs? Which resources and
activities are most expensive?*

**How to work it.** Classify the model as **cost-driven** (optimise every cost) or
**value-driven** (invest in premium value delivery). List the three-to-five
highest line items, and separate **fixed** costs (infrastructure, core team) from
**variable** costs (per-customer deployment, support).

**Common mistakes.**
- **Ignoring CAC and cost-to-serve.** For B2B SaaS these are often the two largest
  drivers, yet teams list only infrastructure and engineering.
- Treating the block as an **accounting exercise** rather than a check on whether
  the Revenue Streams above it can actually cover it.

---

## The Lean Canvas: Four Substitutions

Ash Maurya's Lean Canvas keeps the same one-page grid but, for an early-stage
product where the biggest unknowns are the *problem* and *traction*, replaces four
BMC blocks whose answers are still guesses with four blocks that force the riskiest
assumptions onto the page. **The four BMC blocks it removes are Key Partnerships,
Key Activities, Key Resources, and Customer Relationships** — the internal /
back-office blocks — because at the search-for-fit stage these cannot be known and,
if filled, project false certainty.

| BMC block removed | Lean Canvas block added | Why the swap at startup stage |
|---|---|---|
| **Key Partnerships** → | **Problem** | Before anything else, the top 1–3 problems worth solving are the riskiest unknown; partnerships are premature. The Problem block also lists **existing alternatives** — how customers solve (or work around) the problem today, absent your product — which is the true competitive baseline. |
| **Key Activities** → | **Solution** | Activities cannot be defined until a solution is chosen; the Solution block captures the *smallest* set of features that addresses each listed problem, kept deliberately thin so it stays testable. |
| **Key Resources** → | **Key Metrics** | The handful of numbers that show the business is (or isn't) working matter more than a resource inventory this early — the metrics that would signal product-market fit. |
| **Customer Relationships** → | **Unfair Advantage** | Relationship type is a later concern; the sustainable moat — *something that cannot be easily copied or bought* — is the assumption a startup most needs to state and defend. Most first-draft canvases leave this block honestly blank, and Maurya says that is fine: an empty Unfair Advantage is a truthful admission, not a defect to paper over. |

The five blocks the Lean Canvas keeps unchanged from the BMC: **Customer Segments,
Value Propositions, Channels, Revenue Streams, and Cost Structure.** Maurya also
splits Customer Segments to surface **early adopters** — the specific first
customers, not the whole eventual market — as the people the canvas is really for.

**When to migrate.** Use the Lean Canvas while the problem and solution are still
hypotheses (this repo: Stage 1, closed beta). Once real design-partner usage has
validated the problem and the solution, migrate to the full BMC (Stage 2, soft
launch), where Partnerships, Activities, Resources, and Relationships can now be
answered with evidence rather than guesses.

---

## The Coherence Check (Run After Every Block Is Filled)

The canvas's value is the *fit between* blocks. After filling them, answer all
seven — a "no" means the block containing the gap must be revised:

1. Does every **Value Proposition** directly address a named **Customer Segment**'s
   problem?
2. Does every **Channel** reach the **Customer Segments** the propositions target?
3. Do the **Key Activities** produce the **Value Propositions** — and nothing that
   appears nowhere else on the canvas?
4. Do the **Key Resources** enable the **Key Activities**?
5. Do the **Revenue Streams** flow from **Customer Segments** who receive the
   **Value Propositions**?
6. Do the **Cost Structure** items map back to **Key Activities** and **Key
   Resources**?
7. Is there at least one item on the canvas competitors **cannot easily
   replicate**?

A canvas that passes all seven is coherent. A beautiful canvas that skips the
check is a decorated risk register — nine unconnected lists that individually look
finished while the flows between them silently contradict.

---

## Anti-Patterns (Across the Whole Canvas)

- **Nine unconnected lists.** Each block filled in isolation, coherence check
  skipped. The fit is the product, not the blocks.
- **Feature-first value propositions.** If the entry names no pain or gain, it is
  not a value proposition.
- **Aspirational partnerships.** Only real or realistically-closable relationships.
- **Frozen canvas.** Completed once, never revisited — re-validate at every
  launch-stage transition.
- **Full BMC before validation.** Using the complete BMC while the problem and
  solution are still hypotheses projects false certainty into Partnerships and
  Relationships that cannot yet be known. Use the Lean Canvas until Stage 2.
