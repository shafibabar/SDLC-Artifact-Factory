# Packaging, Tiers and Fences — Reference

Self-contained. Read this when sorting features into leaders, fillers and killers, choosing a tier architecture, naming the fence at each tier boundary, deciding on add-ons and bundles, or choosing how the tiers are presented. Sources: Madhavan Ramanujam and Georg Tacke, *Monetizing Innovation* (configuration, bundling, behavioural pricing); Alexander Osterwalder and Yves Pigneur, *Business Model Generation* (fixed and dynamic pricing mechanisms). A practitioner literature: actionable, not proven.

---

## 1. Leaders, fillers and killers

Sort every candidate feature **per segment**. One table, feature × segment, each cell L, F or K, with the evidence behind it.

| Class | Meaning | Rule |
|---|---|---|
| **Leader** | The segment values it and pays for it | Defines the tier and justifies its price |
| **Filler** | Nice to have; little stand-alone WTP | Rounds out a tier; never drives its price, cost or complexity |
| **Killer** | Makes the segment *less* likely to buy: complexity, an unwanted commitment, a cost to carry, a capability they would pay for and not want | Never in that segment's tier, even if another segment wants it |

The same feature can be all three across segments: a compliance module is a leader for a regulated buyer, a filler for a mid-size one and a killer for a five-person team (it adds set-up they must skip).

**Feature shock** is what happens when nobody sorts: every feature goes into the top tier, the product is confusing, and it is priced above what any one segment values. An agent-built product is especially exposed, because a feature costs an agent little to add and nothing asks whether a segment pays for it.

## 2. Tier architectures

| Architecture | Fits when | Watch for |
|---|---|---|
| **Single offer** | One segment, one leader set | Leaving a high-WTP segment unserved (hidden gem) |
| **Good-better-best** | Two or three segments with different leaders and WTP | Tiers that differ only in fillers (no fence) |
| **Core + add-ons** | A leader valued by only some customers of a tier | Add-on sprawl: a price book nobody can quote |
| **Usage tiers** | The charging unit itself separates segments (volume, sources, seats) | Bill shock; a unit that grows with something the customer wants to shrink |
| **Freemium + paid** | The free tier is a genuine funnel and the fence to paid is clear | Free-tier cost to serve; training users that the product is free |

Osterwalder's typology is the vocabulary for the **mechanism**: fixed (list price, feature-dependent, segment-dependent, volume-dependent) or dynamic (negotiation, yield management, auction). Good-better-best is feature- and segment-dependent fixed pricing; an enterprise tier "priced on request" is negotiation, and then the discount policy carries the weight (`./price-integrity-and-change.md`).

## 3. Fences

A **fence** is the rule that stops a customer whose segment values the higher tier from buying the lower one. Every tier boundary names one, and the segment it holds.

| Fence type | Example | Holds well when |
|---|---|---|
| **Usage limit on the charging unit** | Up to 150 active clients; 3 connected sources | The limit tracks the value the bigger segment gets |
| **A leader only the higher segment values** | Partner reporting; audit evidence; SSO | The lower segment sees it as a filler or killer, so it doesn't feel withheld |
| **Contract term** | 99.95% SLA, data residency in a named region, named support, annual term | The higher segment's procurement requires it |
| **Deployment or region** | Single region vs per-tenant region pinning | Cost to serve really differs |
| **Eligibility** | Education, non-profit, startup programme | Verifiable at sign-up |

**The fenceless-tier test.** For each pair of adjacent tiers, ask: would a customer in the higher tier's segment get its leaders from the lower tier? If yes, there is no fence. The classic failure is the segment's main leader in every tier, with the tiers separated by fillers (themes, export formats, "priority" email): everyone buys the cheapest tier.

A fence must be honest and enforceable: a limit the product actually meters, a feature that is really different. A fence that annoys the lower segment (crippling a leader they need) turns it into a killer.

## 4. Bundles and add-ons

- **Bundle** when customers value the components differently and the bundle captures more total WTP than separate prices would.
- **Do not bundle** when it forces a killer on a segment, or hides a filler's cost in a leader's price.
- **Add-on** a leader that only part of a tier's segment values, and that would otherwise push the whole tier's price up.
- Record the reason for each bundle and add-on decision.

## 5. Behavioural presentation, used honestly

Ramanujam and Tacke treat behavioural tactics as legitimate design tools, applied **after** the economic structure is right. They amplify a good configuration; they do not rescue a bad one.

| Tactic | Honest use | Deceptive use (a defect) |
|---|---|---|
| **Anchoring** | Show the top tier first, so the middle tier reads as reasonable | A "was $199" price nobody ever paid |
| **Compromise effect (middle option)** | Put the intended best-seller in the middle of three | A middle tier designed so no one can use it without an add-on |
| **Decoy** | A real, purchasable option that makes value clear | An option that cannot actually be bought |
| **Partitioning and framing** | Per user per month when buyers budget that way; annual saving shown plainly | Fees revealed at checkout; pre-ticked add-ons |
| **Price-quality inference** | Not underpricing a risk-averse B2B buyer into doubt | — |

Fake reference prices, resetting countdowns and drip pricing are deception, not design, and can breach consumer-protection law in many markets.
