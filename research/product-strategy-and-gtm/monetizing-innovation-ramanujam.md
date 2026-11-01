# Monetizing Innovation: How Smart Companies Design the Product Around the Price
**Authors:** Madhavan Ramanujam and Georg Tacke (Simon-Kucher & Partners)
**Domain:** Pricing, Monetization & Product Strategy

## Core Concepts

- **Design the product around the price, not the price around the product.** The book's central claim is that most new products fail to make money not because the idea or the engineering is bad but because pricing is treated as the last step: build, then ask "what can we charge?". Ramanujam and Tacke invert the order. The willingness-to-pay conversation happens at the idea stage, and it decides which product is built, for whom, with which features, under which revenue model and at what price. Price is a design input, like a requirement, not a sticker added at launch. The Porsche Panamera (a car whose features and target price were set from willingness-to-pay research before it was engineered) is the book's signature example of the method; treat the case details as illustration, not evidence (see Caveats). This repo's `skills/gtm-strategy/SKILL.md` does the opposite: pricing is component 6 of 7 (`:40`, `:144-156`), produced after positioning, channels and the sales model, and exact prices are deferred to a "commercial plan" no skill produces (`:156`; W1-34).

- **Four ways innovations fail to monetize.** The book names four failure types, each a symptom of pricing late:
  - **Feature shock**: too many features crammed in, so the product is confusing, over-engineered and priced too high for what any one segment values. Every stakeholder's favourite feature goes in because nobody asked which features customers will pay for.
  - **Minivation**: the right product priced too low, or aimed at too small a market, so it sells but leaves most of its value uncaptured. It looks like success, which is why it goes unnoticed.
  - **Hidden gem**: a valuable idea the company never pursues, usually because it does not fit the core business or nobody tested what customers would pay for it.
  - **Undead**: a product nobody wants, launched anyway because the idea had momentum and no one checked demand and willingness to pay before building. It lingers on.

  The first two are the ones a product team controls most directly. Feature shock is a configuration failure (wrong features in the box); minivation is a price-level or market-size failure (right box, wrong price). An agent-built product is unusually exposed to feature shock, because adding a feature costs an agent little and nothing in the pipeline asks whether a segment will pay for it.

- **Have the willingness-to-pay (WTP) talk early, and keep having it.** WTP is gathered in customer conversations before the product is defined, then refined. The book's practical toolkit is a set of direct but structured questions rather than a single "how much would you pay?":
  - For a described offer, the price that would be **acceptable**, the price that would be **expensive** (but still considered), and the price that would be **prohibitively expensive**. The spread between them gives a range, not a point.
  - Which features or benefits matter most, often by forcing a trade-off (rank them, or allocate a fixed budget across them), so that "everything is important" cannot be the answer.
  - Purchase-likelihood at a stated price, and what would have to change to buy.
  - More formal methods (conjoint-style trade-off studies) for larger stakes, later.

  The book accepts that stated WTP is biased and noisy and treats it as directional evidence that beats internal guessing, especially when triangulated across questions. This sits in deliberate tension with *The Mom Test* (`the-mom-test-fitzpatrick.md`), which warns against hypothetical "would you buy" questions. The two reconcile if stated WTP is recorded as a range hypothesis and upgraded only by commitment (a pre-order, a letter of intent, a paid pilot), which is Maurya's "ask for money early" (`running-lean-maurya.md:73`).

- **Segment by needs, value and willingness to pay, not by demographics.** One-size-fits-all pricing is the norm the book argues against: customers differ in what they need and in what they will pay, so one offer at one price overcharges some, undercharges others and loses the rest. Segments are formed from needs and WTP data (who values what, and how much), and a firmographic description (size, industry) is attached afterwards to make the segment findable. Each segment then gets an offer designed for it. This is narrower than, and complements, the beachhead logic already in `gtm-strategy` (Moore): the beachhead picks *which* segment to win first; WTP segmentation decides *what to sell them and at what price*, and shows which later segments are worth monetising differently.

- **Configuration and bundling: leaders, fillers and killers.** Once segments are known, every candidate feature is sorted per segment:
  - **Leaders**: features the segment values highly and will pay for. They define the offer and justify its price.
  - **Fillers**: nice-to-haves with little stand-alone WTP. They round out a package but should not drive cost or complexity.
  - **Killers**: features that make the segment *less* likely to buy (added complexity, a capability they would have to pay for and do not want, a commitment they resist). They must be kept out of that segment's package, even if another segment wants them.

  Packages are then built segment by segment, commonly as **good-better-best** tiers, where each tier's leaders match one segment and the tier boundaries ("fences") stop a high-WTP customer from buying down. Bundling is used when it raises total WTP (customers value the components differently, so the bundle captures more than separate prices would) and avoided when it forces a killer on someone. Feature shock is the result of skipping this sort.

- **How you charge matters more than how much.** The monetization model (the book's term for the structure of charging, including the price metric, the "per what") often unlocks more value than tuning the price level. The models the book discusses include:
  - **Subscription**: recurring access; predictable for both sides; churn is the risk.
  - **Usage-based / pay-as-you-go**: charge per unit of consumption or outcome, so price scales with the value a customer receives. The choice of metric is the core decision: it should track customer value, be easy to understand and measure, and grow as the customer succeeds.
  - **Dynamic pricing**: price varies with demand, time or capacity.
  - **Auction**: price set by bidding, where demand is uncertain or scarce capacity is sold.
  - **Freemium**: a free tier to drive adoption, with a paid tier the free one does not cannibalise. It works only when the free tier is a genuine funnel and the fence to paid is clear; otherwise it trains customers that the product is free.
  - **Alternative and indirect models** (for example, third parties paying, or outcome- and shared-value models where price is tied to the result delivered).

  Not every chapter list is recalled exactly (see Caveats); the load-bearing rule is that the model is chosen to fit how the customer gets value and how the segment prefers to pay. This complements Osterwalder's revenue-type list and fixed/dynamic split (`business-model-generation-osterwalder.md:16,95`), which names the options but not how to choose between them by WTP and value metric.

- **Pricing strategy: maximisation, penetration or skimming.** After model and configuration, the book asks which price-level strategy the business goal calls for:
  - **Maximisation**: set the price that maximises profit (or revenue) from the start. The default for most B2B and differentiated products.
  - **Penetration**: price low to win share quickly. Justified only by network effects, scale economies, lock-in or a land-grab market; otherwise it is planned minivation, and raising a price later is far harder than lowering one.
  - **Skimming**: launch high to the customers with the highest WTP and step down over time to reach more segments. Suits innovations with a clear lead and an early-adopter segment that will pay a premium.

  The strategy must be consistent with the positioning (a premium differentiation claim cannot be sold at a penetration price) and with the competitive response expected.

- **Behavioural pricing.** Customers do not evaluate prices rationally, and the book treats behavioural tactics as legitimate design tools, applied after the economic structure is right:
  - **Anchoring**: the first or highest price seen sets the reference for the rest; presenting the top tier first makes the middle tier look reasonable.
  - **Compromise effect (centre-stage)**: given three options many buyers pick the middle one, which is why good-better-best places the intended best-seller in the middle.
  - **Decoy options**: an option designed mainly to make another look better value.
  - **Framing and partitioning**: how a price is broken down (per day vs per year, per user vs flat) changes how it feels; so does whether a saving is shown as a gain or a loss avoided.
  - **Price-quality inference**: a price that is too low can signal low quality, especially to a risk-averse B2B buyer.

  These amplify a good configuration; they do not rescue a bad one.

- **Build the business case from WTP data, not from a top-down market share.** The business case is assembled bottom-up: segment sizes × expected adoption at the chosen price (from WTP research) × price, minus the cost to build and serve each segment. It is tested with sensitivity analysis on the weakest inputs (adoption and price). A business case that starts from "if we get 1% of the market" is the book's cautionary pattern. The case is also the gate: an innovation that cannot show a credible case should be reshaped (reconfigured, repriced, retargeted) or stopped before it is built, which is how hidden gems and undead products are caught.

- **Launch: communicate value and protect price integrity.** At launch, the value story has to be in the hands of everyone who sells (the price is defended by value, not by discount), and the company needs discount discipline: discounts given only in exchange for something (volume, term, a reference), with limits on who can grant them. Introductory prices that cannot be sustained, and ad-hoc discounting, train customers to wait for deals and erode the price permanently. After launch, actual win/loss and price-objection data are fed back to adjust configuration and price.

## Actionable Techniques

- **Move pricing ahead in the GTM sequence, or at least make it read upstream evidence.** In `gtm-strategy`, the pricing decision should consume WTP evidence gathered with the ICP and positioning, not be authored after the sales model. Practically: add a "WTP evidence" input to the ICP/beachhead step and make the Pricing Model component cite it.
- **Run a WTP conversation guide, written by the agent, held by the user.** The agent cannot hold customer conversations (the same constraint as W1-23). It drafts a short guide: the offer description; acceptable / expensive / prohibitively expensive price questions; a forced feature trade-off; purchase likelihood at one or two candidate prices. The user (or a design partner session) runs it. Results are recorded as a range per segment, labelled "stated" until a commitment upgrades them.
- **Sort features into leaders, fillers and killers per segment before tiering.** A small table: feature × segment, each cell L / F / K, with the evidence behind it. Tiers are then built so each tier carries its segment's leaders and none of its killers.
- **Choose the pricing metric with three tests.** Does it track the value the customer receives? Can the customer predict their bill? Does it grow as the customer succeeds? Record the rejected metrics and why.
- **State the price strategy and its justification.** Maximisation by default; penetration only with a named network effect, scale economy or lock-in; skimming only with a named premium early segment and a planned step-down.
- **Price as a range with a stated basis, not "set later".** The GTM artifact states a price range per tier derived from WTP evidence and the value anchor, with exact list prices refined in soft launch. This replaces the dangling "commercial plan" (W1-34).
- **Add a failure-mode check before handoff.** Ask four questions: is any tier carrying fillers or killers that add cost or confusion (feature shock)? Is the price far below the value anchor and the top of the stated WTP range without a penetration rationale (minivation)? Is there evidence anyone will pay (undead)? Is a high-WTP segment being left unserved (hidden gem)?
- **Define a discount policy at enterprise scale.** Who can discount, by how much, and what the customer gives in return.

### What a pricing section in a GTM artifact should minimally contain, by scale

The repo's scale profiles (`skills/artifact-manifest/resources/phase-requirements.json`) **skip** the `gtm-strategy` artifact at **lean** and require it at standard and enterprise. So the lean row applies only when the user opts in or when a monetisation decision sits in another artifact (for example, a one-line note in the vision or canvas).

| Scale | Typical product | Minimum pricing content |
|---|---|---|
| **Lean** (artifact skipped by default) | Internal tool, free side project, single-segment MVP | One line: "Not monetised" (internal / free) with the reason, **or** the monetisation model, the pricing metric and one price point with its WTP basis (even "3 conversations, stated"). Name the killer to avoid (for example, mandatory sign-up for an internal tool). No tiers. |
| **Standard** | B2B or B2C SaaS, one beachhead, self-serve or product-assisted | WTP evidence summary (who, how many, stated vs committed, range per segment); segment(s) defined by needs and WTP; monetisation model and pricing metric with the three-test rationale; value anchor (quantified customer value) as the ceiling; price strategy (maximisation / penetration / skimming) with justification; a price **range** per tier; leaders per tier if tiered; Stage 2 exit condition on price acceptance. |
| **Enterprise** | Multi-segment B2B, tiered, sales-led or hybrid | Everything in standard, plus: a leaders / fillers / killers table per segment; good-better-best tiers with explicit fences; bundling and add-on decisions with reasons; a bottom-up business case with sensitivity on price and adoption; behavioural presentation choices (anchor tier, intended centre option); a discount and price-integrity policy; the value-communication brief for anyone who sells; post-launch price review triggers (win/loss, price objections). |

## Applies To

| Skill/Agent | Current content (as read) | What this book changes |
|---|---|---|
| `skills/gtm-strategy/SKILL.md` `:31-43` (component order) | Pricing is component 6 of 7, after channel and sales model. | Keep the document order if preferred, but state that the pricing component **consumes WTP evidence gathered at the ICP/beachhead step** and constrains configuration. Add "WTP evidence" to what the beachhead choice records (`:47-58`), since WTP is also a segmentation input. |
| `skills/gtm-strategy/SKILL.md` `:144-154` (pricing table) | One table mixing pricing **metrics** (per seat, per data volume, per connector), a **structure** (flat) and a **packaging** choice (tiered). Domain-specific rows ("per connector", "B2B data products"). | Split into three decisions: (1) monetisation model (subscription, usage, freemium, dynamic, alternative); (2) pricing metric with the three tests; (3) configuration (single offer vs good-better-best, leaders / fillers / killers). Make the rows product-neutral and move connector/GB examples to `examples/`. |
| `skills/gtm-strategy/SKILL.md` `:156` (value anchor) | "Anchor the price to value, not cost", with an unsourced 40-hour illustration; "exact price points are set in the commercial plan". | Ground the value anchor in this book. Distinguish **value anchor** (economic value to the customer; a ceiling) from **WTP** (what the segment will actually pay; the evidence). Replace the commercial-plan deferral (W1-34) with "state a price range per tier from WTP evidence; refine list prices in Stage 2". Add the price strategy choice (maximisation / penetration / skimming). |
| `skills/gtm-strategy/SKILL.md` `:134-138` (sales model) | Contract model, trial model (incl. freemium) and expansion motion sit in the sales-model table. | Cross-reference the pricing component: freemium is a monetisation model with fence and cost-to-serve conditions, and the expansion motion should follow the pricing metric (a usage metric expands by usage). One home for each decision. |
| `skills/gtm-strategy/SKILL.md` `:166-170` (launch stages) | Stage 2 "validates pricing"; exit criteria do not mention price evidence at Stage 1. | Stage 1 exit adds "WTP range per segment recorded from design-partner conversations" (alongside W1-35's Mom-Test check). Stage 2 exit adds "price accepted within the stated range without structural discounting" (the worked example already has a version of this, `references/gtm-template.md:75`). |
| `skills/gtm-strategy/SKILL.md` `:196` (quality criterion) | "Pricing anchor: model anchored to quantified customer value." | Add criteria: WTP evidence cited (source, count, stated vs committed); pricing metric justified; price strategy named; at enterprise scale, no killer in any tier and a discount policy present. |
| `skills/gtm-strategy/SKILL.md` `:208` (anti-patterns) | Cost-plus pricing only. | Add **pricing last** (price chosen after the product is built), **feature shock** (tiers built from everything the team can add), **minivation** (penetration price with no network effect or lock-in), and **discount drift** (ad-hoc discounts with no give-get). |
| `skills/gtm-strategy/SKILL.md` `:179` | "benchmark: 15–25% for PLG B2B", unsourced (W1-34). | This book does not supply that benchmark. Drop it or source it elsewhere; do not attribute it to Ramanujam. |
| `skills/gtm-strategy/references/gtm-template.md` `:64-68` | Flat tiers by storage sources; value anchor "~40 hours per quarter", "$6,000–10,000/quarter"; "exact price points are set in the commercial plan". | When this worked artifact moves to `examples/` (W1 folder move), add a WTP evidence line, a leaders/fillers/killers note for the three tiers, a stated price strategy and a price range. Label the 40-hour figure as an assumption to be confirmed in Stage 1, since it is not evidence. |
| New `skills/gtm-strategy/references/pricing.md` (or `templates/wtp-conversation-guide.md`) | Does not exist. | Holds the depth: failure modes, WTP question set, leaders / fillers / killers, model selection, strategy choice, behavioural tactics, business-case structure, price integrity, and the per-scale minimum table above. `SKILL.md` keeps a short decision-shaping summary and a pointer. |
| `skills/business-model-canvas/SKILL.md` `:83-84`, `:90-91` | Segments carry "distinct … willingness to pay"; Revenue Streams carry "the value anchor that justifies the price". | Already consistent with this book; cite it in `sources:`. Add that Revenue Streams **reference** the GTM pricing decision rather than re-derive it (W1 overlap note). |
| `skills/business-model-canvas/references/canvas-blocks.md` `:37-40` (Block 1) | "For B2B, segment by company profile: size band, industry vertical, regulatory exposure, technical maturity." | Segments are formed from needs and WTP first; the company profile is attached to make each segment findable. Reword so firmographics describe a segment rather than define it. |
| `skills/business-model-canvas/references/canvas-blocks.md` `:141-159` (Block 5) | Pricing model, mechanism, relative contribution, value anchor; mistakes: no proposition behind a stream, pricing to cost. | Add the pricing **metric** (per what) as distinct from mechanism, and a "WTP evidence" field. Add a mistake: a single price for segments with clearly different WTP. |
| `skills/business-model-canvas/references/canvas-blocks.md` `:293-294` (coherence Q5) | "Do the Revenue Streams flow from Customer Segments who receive the Value Propositions?" | Extend: "…at a price inside that segment's recorded WTP range?" This makes the check catch both undead (no WTP) and minivation (price far below range). |
| `skills/business-model-canvas/references/canvas-template-and-example.md` `:44-47` | Revenue template: model, mechanism + tiering, value anchor. | Add "Pricing metric", "WTP evidence (stated / committed)" and "See GTM pricing section" lines. |
| `agents/product-strategist.md` | Not read for this file. | No ownership change. Applying leaders / fillers / killers or choosing a strategy for a specific product is the agent's reasoning; the criteria belong in the skill. |
| `skills/beta-program-design` | Not read for this file. | Light link only: a design-partner programme is where the first committed WTP evidence (a paid pilot, a signed price) is gathered. Check the skill before proposing a change. |

## Candidate New Skills/Agents

- **No new skill now; a `references/pricing.md` inside `gtm-strategy` first.** Pricing is already a `gtm-strategy` component, the lean profile skips GTM, and the Revenue Streams block in the canvas should point at it. A reference file gives the depth without a second artifact.
- **A `pricing-and-packaging` skill is a candidate at enterprise scale.** If enterprise products need a separate pricing artifact (tier matrix, fences, discount policy, business case with sensitivity), it is a coherent body of knowledge with its own output, owned by `product-strategist`. Revisit when an enterprise product reaches Strategy; adding it now would create a third home for pricing (GTM, canvas, new skill).
- **A WTP conversation guide could be shared** with the interview guides implied by W1-23 and the Mom Test file: one "customer conversation guide" reference with a pricing module, rather than separate guides per skill.
- **No new agent.**

## Key Terminology

Candidates for `skills/glossary-management/` (strategy terms, not DDD terms):

- **Willingness to Pay (WTP)**: the price range a segment would accept for a defined offer, recorded as stated (from conversation) or committed (from a purchase, pre-order or signed pilot).
- **Price-First Design**: deciding segment, configuration, monetisation model and price before building, from WTP evidence.
- **Feature Shock / Minivation / Hidden Gem / Undead**: the four monetisation failure modes.
- **Leader / Filler / Killer**: per-segment feature classes: drives purchase / adds little / reduces purchase likelihood.
- **Good-Better-Best**: three-tier packaging, each tier aimed at one segment, separated by fences.
- **Fence**: a rule that stops a customer from buying a cheaper tier than their segment's (a usage limit, a feature, a contract term).
- **Monetisation Model**: how a product charges (subscription, usage, dynamic, auction, freemium, alternative).
- **Pricing Metric**: the unit the price is charged per; should track customer value.
- **Value Anchor**: the quantified economic value to the customer that bounds the price from above. Already used in `gtm-strategy` and `business-model-canvas`; this book grounds it.
- **Price Integrity**: keeping realised price close to list price through discount discipline (discounts only with a give-get).

## Caveats

- **High confidence.** The price-first thesis and the book's subtitle; the four failure types and their meaning; the WTP-talk-early principle with the acceptable / expensive / prohibitively expensive question set; segmentation by needs and WTP rather than demographics; leaders, fillers and killers; good-better-best; "how you charge matters more than how much"; maximisation, penetration and skimming; anchoring and the compromise effect; a business case built bottom-up from WTP data; value communication and discount discipline at launch. These are the book's most repeated ideas and appear in the authors' public talks and Simon-Kucher material.
- **Medium confidence.** The exact list and naming of monetisation models in the book's models chapter (I am confident of subscription, dynamic, auction and freemium; less sure of the exact framing of usage and "alternative" models); the exact set of behavioural tactics in that chapter (decoy and framing may be presented differently); the exact chapter order. Check before quoting any of these as a closed list.
- **Case studies.** The book has a set of company case studies (Porsche's Panamera is the best known; others such as LinkedIn are recalled less firmly). I name only Porsche, as an illustration, and do not reproduce details. Do not cite cases as evidence in a skill.
- **Not stated.** The book reports survey figures on how often innovations fail to meet revenue targets and similar statistics. I do not reproduce any of them, and no page numbers or quotations are given, because I cannot recall them reliably.
- **Fit with this repo.** The book is written for companies with sales teams, market-research budgets and large launches. For a solo product owner with AI agents, the parts that carry over are the order (price before build), the WTP conversation (held by the user, guided by the agent), the leader/filler/killer sort and the failure-mode check. Conjoint studies and large-sample research conflict with the frugality constraint and belong only at enterprise scale, if at all. The Mom Test tension (stated WTP vs hypothetical questions) is real; the resolution above (stated = hypothesis, commitment = evidence) is this file's synthesis, not the book's.
- **Practitioner book.** It is consulting practice distilled by a pricing firm, not peer-reviewed research. Treat it, as this cluster treats Dunford and Osterwalder, as actionable but not proven.
- **Line references** were taken from the skills as read on 2026-10-19 (gtm-strategy v2.0.0, business-model-canvas v2.1.0). Re-check them before implementing (W1-49).
