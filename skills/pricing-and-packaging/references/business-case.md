# The Pricing Business Case — Reference

Self-contained. Read this when building or reviewing the pricing business case, choosing its sensitivity rows, deciding whether a case is credible enough to proceed, or applying the GTM's price strategy (maximisation, penetration, skimming) at tier level. Sources: Madhavan Ramanujam and Georg Tacke, *Monetizing Innovation* (bottom-up case, price strategy); Ash Maurya, *Running Lean* (the Fermi check).

---

## 1. Bottom-up, never top-down

Per segment (and per region where cost to serve differs):

```
customers   = segment size × adoption at this price
revenue     = customers × price
contribution = revenue − customers × cost to serve
net         = Σ contribution − fixed cost to build and run
```

| Input | Comes from | Label |
|---|---|---|
| Segment size | Counted from a list, directory or market data with a source | sourced / estimate |
| Adoption at this price | WTP evidence: purchase likelihood at the price, pilot conversion | stated / committed |
| Price | This artifact's list price, net of the expected discount depth | — |
| Cost to serve | Canvas cost structure: hosting, support, payment fees, per region | estimate / observed |
| Fixed cost | Build and run cost not tied to a customer | estimate |

**The anti-pattern** Ramanujam and Tacke warn against: "the market is $2B; if we get 1% we make $20M." It hides the adoption assumption inside a percentage nobody tested and says nothing about price. Replace it with counted segments and adoption from evidence.

Maurya's **Fermi check** is the lean cousin: price × customers needed to reach a minimum success criterion, against the cost structure. If no realistic adoption covers cost, the model fails before any interview.

## 2. Sensitivity on the weakest inputs

The two weakest inputs are almost always **price** and **adoption**. Show at least:
- a grid of price × adoption at, for example, −20% / base / +20% of each;
- the **break-even adoption** at the base price;
- the pessimistic row stated in words: "if adoption is 20% below and price 20% below, net is …".

Price and adoption move together in reality (a higher price lowers adoption); the grid shows them separately so the reader sees which one the case depends on. Where WTP evidence gives paired points (likelihood at price A and at price B), add them as named scenarios.

`../scripts/calculate-business-case.py` does the arithmetic from a small JSON file and prints the tables in Markdown.

## 3. The case is a gate

A case that is not credible at its pessimistic row is not "approved with risk". The offer is **reshaped** (reconfigure the tiers, reprice within the evidence, retarget another segment) or **stopped**. This is how the book catches **undead** products (no evidence anyone will pay) and **hidden gems** (a segment whose case is strong but which nobody offers to).

## 4. Price strategy at tier level

The GTM names the strategy; this artifact applies it.

| Strategy | Applied here as | Required in the artifact |
|---|---|---|
| **Maximisation** (default) | List prices at the level the WTP evidence and value anchor support | Nothing extra |
| **Penetration** | Prices below that level to win share | The GTM's named network effect, scale economy or lock-in, **and** the exit condition (date, customer count or share) at which prices move to the maximisation level, with the change rule for customers acquired cheaply |
| **Skimming** | Launch high to the premium segment, step down to reach the next | The premium segment, the step-down schedule with dates or triggers, and the rule that early buyers are not punished for paying more (for example, a credit) |

A low price with none of the penetration conditions is planned **minivation**: it sells, looks like success and leaves the value uncaptured. Raising a price later is far harder than lowering one.

## 5. Four-failure check

Run before hand-off:

| Failure | Question |
|---|---|
| **Feature shock** | Does any tier carry fillers or killers that add cost or confusion? |
| **Minivation** | Is any price far below the value anchor and the top of its WTP range, with no penetration case? |
| **Hidden gem** | Is a high-WTP segment left without an offer? |
| **Undead** | Is there committed evidence anyone will pay? |
