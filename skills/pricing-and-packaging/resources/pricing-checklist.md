# Pricing and Packaging Checklist

Self-contained. The rule set a pricing-and-packaging artifact is cross-checked against before it is presented for approval. Every row must pass at the artifact's profile. Rows marked *(enterprise)* apply only at enterprise.

| # | Check | Pass | Fail |
|---|---|---|---|
| 1 | **Frontmatter** | `name`, `version`, `phase`, `owner`, `created`, `summary` (one sentence naming tiers, fences and price basis), `traces_to` the GTM | Missing `summary`; no trace to the GTM |
| 2 | **Inside the GTM** | Model, charging unit and strategy cited from the GTM; every list price inside the GTM range | A new charging unit, or a price outside the range, with the GTM not reopened |
| 3 | **WTP evidence** | Per segment: role asked, count, label (stated / committed / observed), range, date | A single number; no source; stated figures treated as committed |
| 4 | **Segments** | Formed by needs and WTP; firmographics only to find them; no two segments with identical leaders and WTP | Segments by company size alone |
| 5 | **Leaders / fillers / killers** | Every feature classified per segment, with evidence | Features listed per tier with no classification |
| 6 | **No killer in its segment's tier** | Each tier excludes its segment's killers | A feature a segment said makes it less likely to buy sits in that segment's tier |
| 7 | **Fences** | Each tier boundary names a fence (usage limit, leader, contract term) and the segment it holds | The same leader in every tier; tiers separated only by fillers |
| 8 | **Price basis** | Between WTP and the value anchor; cost to serve shown only as the floor | Cost-plus margin; a competitor's price copied; price below cost to serve |
| 9 | **Strategy applied** | Penetration has its exit condition; skimming its step-down schedule | A low price with no network effect, lock-in or exit (minivation) |
| 10 | **Business case** | Bottom-up per segment; inputs labelled; price × adoption sensitivity; pessimistic row in words; gate decision | "1% of the market"; one optimistic line; no gate |
| 11 | **Discounts** | Every discount has a get; a named approver and limit per rung | "As needed"; end-of-quarter discounts; no limit |
| 12 | **Honest presentation** | Anchoring and middle option on real, purchasable offers | Fake "was" prices, hidden fees, resetting countdowns, pre-ticked add-ons |
| 13 | **Change rules** | Intro-price end date; grandfathering and notice; review triggers with thresholds | Silent price changes; "forever" pilot prices |
| 14 | **Four-failure check** | Feature shock, minivation, hidden gem, undead each answered | Not run |
| 15 | *(enterprise)* **Value brief by role** | Each buying-group role's price objection with value line and proof; price losses distinguished from no decision | Discount as the only answer to objections |
| 16 | *(enterprise)* **Regions and add-ons** | Cost to serve per region where it differs; each add-on and bundle has a reason | One global cost line for regions that cost differently |
| 17 | **Scale** | Lean: no artifact. Standard: only when the Scale table's trigger applies | A tier matrix for a lean product |

**If several rows fail, fix in this order:** 2 (outside the GTM), 3 (no evidence), 7 (no fences), 8 (cost-plus), 10 (business case), 11 (discounts), then the rest.
