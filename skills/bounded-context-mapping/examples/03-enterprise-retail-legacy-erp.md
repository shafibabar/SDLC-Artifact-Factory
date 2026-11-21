# Example 3 — Enterprise: a current and a target map, with a legacy ERP drawn as one boundary (hardest case)

Self-contained. **Harrowgate Retail** runs 140 hardware stores and replaces its store operations with a new platform, at the **enterprise** profile. A 20-year-old ERP holds stock, pricing, purchasing and finance in one database, and nobody can say where one part ends. A human Big Picture was held with store managers, buyers and finance.

## Input

> **User:** "Draw the map for the new platform. Don't bother with the ERP, it's going eventually."

## Working it

- **Map what is first** (Evans; Vernon). The ERP isn't going this year, and every new context will touch it. Leaving it off hides the work the transition needs. So a **current map** comes first, with the ERP drawn as **one box** marked "legacy, no coherent model": drawing tidy contexts inside it would describe a model that doesn't exist.
- **The target map** sits beside it: the new contexts (Store Replenishment, Pricing, Click and Collect) and the ERP still present, reached through one translation layer on each new context's side (pattern chosen in `context-map-patterns`).
- **Language evidence:** "stock" means units on the shelf to store managers, a value on the balance sheet to finance, and an order quantity to buyers. "Price" means the shelf price in stores and a margin-bearing cost-plus figure in buying. The lines go there.
- **Two internal contexts that succeed or fail together:** Store Replenishment and Click and Collect share the shelf; the team that models both plans changes jointly (the pattern is `context-map-patterns`' call).
- **A boundary move is coming:** promotions currently live in the ERP and will move to Pricing. That's a planned move (`SKILL.md` § 6), listed under the target map, not hidden in it.

## Output — the reply, and extracts of `context-map.md`

> I've drawn two maps. The ERP stays on both. It isn't going this year, and every new context has to deal with it. On the current map it's one box: there's no clean model inside it to draw. On the target map the new contexts sit beside it, each reaching it through its own translation, so the ERP's tangle doesn't leak into them. The lines come from where words change meaning. "Stock" is shelf units in stores, a value in finance and an order quantity in buying. "Price" is the shelf price in stores and a cost-plus figure in buying. Moving promotions out of the ERP is listed as a planned change, so it doesn't happen silently.

```
Current map
┌──────────────────────────────────────┐      ┌───────────────────┐
│ ERP  [legacy, no coherent model]     │──U─D▶│ Store tills       │
│ stock, pricing, purchasing, finance, │      │ [external]        │
│ promotions in one database           │      └───────────────────┘
└──────────────────────────────────────┘

Target map
┌──────────────────────┐        ┌────────────────────────┐
│ ERP [legacy]         │──U──D─▶│ Store Replenishment    │
│                      │        │ (Core)                 │
│                      │──U──D─▶├────────────────────────┤
│                      │        │ Click and Collect      │
│                      │──U──D─▶│ (Supporting)           │
└──────────────────────┘        └────────────────────────┘
          │U                       Pricing (Supporting) ◀─D──U── ERP
```

| Planned boundary move | From | To | Trigger | Review |
|---|---|---|---|---|
| Promotions | ERP | Pricing | Pricing live in 20 stores | `container-diagram`, the event catalogue; context map MAJOR version |

## Why this is right

- The current map was drawn although the user wanted only the target. Mapping what is, mess included, is what makes the transition visible.
- The legacy region is one honest box, not invented contexts.
- Lines follow words that change meaning; a coming boundary move is planned in the open, not slipped into the target map.
