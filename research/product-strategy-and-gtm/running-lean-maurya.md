# Running Lean: Iterate from Plan A to a Plan That Works (with notes on Scaling Lean)
**Authors:** Ash Maurya
**Domain:** Lean Startup Practice, Business Model Validation, Traction Metrics

*Running Lean* (first self-published 2010, O'Reilly second edition 2012, a substantially rewritten third edition 2022) turns Eric Ries's Lean Startup and Steve Blank's Customer Development into a step-by-step practice built around one artifact, the **Lean Canvas**. *Scaling Lean* (2016) is its sequel: it moves the focus from "is the problem real?" to "is the model producing traction?" This file covers both where I know them well, and says plainly where I do not. It complements `business-model-generation-osterwalder.md` (the Business Model Canvas itself, the Value Proposition Canvas and evidence-graded testing). That material is not repeated here.

## Core Concepts

- **The Lean Canvas is a one-page business model for the stage when almost everything is a guess.** Maurya adapted Osterwalder's Business Model Canvas because, for a new product, the hardest unknowns are whether the problem is real and whether anyone will pay. They are not partners, activities or resources. The Lean Canvas keeps the BMC's one-page grid and five of its blocks (Customer Segments, Channels, Revenue Streams, Cost Structure, and the central value block, renamed and sharpened). It swaps in four new blocks: **Problem, Solution, Key Metrics, Unfair Advantage**. Its purpose is to write down "Plan A" quickly, so the riskiest parts can be found and tested, rather than to describe a business that already works. The skill states this choice well (`skills/business-model-canvas/SKILL.md:41-54`).

- **Which block replaces which: settled positionally, less so in Maurya's reasoning.** On the printed canvas the layout is not in doubt:

  | BMC position | Lean Canvas block in that position |
  |---|---|
  | Key Partnerships (far left column) | **Problem** (with *Existing Alternatives* beneath it) |
  | Key Activities (left-centre, top) | **Solution** |
  | Key Resources (left-centre, bottom) | **Key Metrics** |
  | Value Propositions (centre) | **Unique Value Proposition** (with *High-Level Concept* beneath it) |
  | Customer Relationships (right-centre, top) | **Unfair Advantage** |
  | Channels (right-centre, bottom) | **Channels** (unchanged) |
  | Customer Segments (far right) | **Customer Segments** (with *Early Adopters* beneath it) |
  | Cost Structure / Revenue Streams (bottom rail) | unchanged |

  This matches the skill (`references/canvas-blocks.md:262-267`) and the Wave 1 check. One thing is less certain. As I recall, Maurya explains the change as **removals and additions argued separately**, not as four one-to-one trades. He removes Key Partners, Key Activities and Key Resources because they are about running a business, which is premature before the product exists. He removes Customer Relationships on the grounds that Channels and the direct contact of early customer conversations cover it. He adds Problem, Solution, Key Metrics and Unfair Advantage because they carry the startup's real risk. The skill's "why this swap" column (`canvas-blocks.md:262-267`) gives each pair its own one-to-one reason. That works as teaching, but it is the skill's own framing and should not be presented as Maurya's argument.

- **The central block is not "Value Propositions unchanged".** Maurya renames it the **Unique Value Proposition (UVP)**: a single, clear, compelling message that says why you are different and worth attention, aimed at turning an unaware visitor into an interested prospect. Below it he adds an optional **High-Level Concept**, a short "X for Y" analogy. The skill's template already uses the name "Unique Value Proposition" (`references/canvas-template-and-example.md:88`). But `canvas-blocks.md:269-270` lists Value Propositions among the five blocks "unchanged from the BMC", so the skill contradicts itself.

- **Three sub-boxes carry much of the canvas's value.** Later versions of the canvas (from about the second edition) added three:
  - **Existing Alternatives**, under Problem: how customers solve the problem today, including workarounds and doing nothing. This is the true competitive baseline, the same idea as Dunford's "competitive alternatives" (`obviously-awesome-dunford.md`).
  - **Early Adopters**, under Customer Segments: the narrow first group who have the problem worst and know it. They are not the whole eventual market.
  - **High-Level Concept**, under UVP.

  The skill has Existing Alternatives (`canvas-blocks.md:264`) and Early Adopters (`canvas-blocks.md:270-272`, template `:85-86`). It does not have High-Level Concept.

- **Fill order is deliberate: Problem and Customer Segments first, together.** Maurya's recommended order is: Problem and Customer Segments (as a pair, because a different segment has different problems), then UVP, Solution, Channels, Revenue Streams, Cost Structure, Key Metrics, and Unfair Advantage last. The logic is that everything else derives from a real problem held by a real segment. Solution comes fourth on purpose, against the founder's instinct to start with it. The skill's Lean Canvas template happens to list blocks in exactly this order (`canvas-template-and-example.md:81-107`), but nothing tells the user that the order is the method. It also gives no reason for the order.

- **Working rules for the first canvas.** As I recall them:
  - Sketch it fast. Maurya suggests a short single sitting rather than a long research project.
  - It is fine to leave a block blank or mark it as unknown. A blank is information; it names a risk.
  - Write it for "now", with the knowledge you have today.
  - Make **one canvas per customer segment**, because segments with different problems are different business models.
  - Keep the canvas alive: update it as you learn, rather than filing it.

  The skill already allows an honestly blank Unfair Advantage (`canvas-blocks.md:267`). But its Quality Bar requires "no TBD" in any block (`SKILL.md:157`), which conflicts with Maurya's blank-is-allowed rule for the Lean variant.

- **Risk comes in three kinds, and ranking risk is the point of the canvas.** In the second edition Maurya groups startup risk into three:
  - **Product risk**: getting the product right. Is the problem real, and does the solution solve it? Blocks: Problem, Solution, UVP, Key Metrics.
  - **Customer risk**: building a path to customers. Can we reach early adopters? Blocks: Customer Segments, Channels.
  - **Market risk**: building a viable business. Do pricing, costs and competition work? Blocks: Revenue Streams, Cost Structure, Unfair Advantage.

  He ranks canvases (when there are several segments) and the blocks within a canvas by risk. The riskiest assumptions are tested first. A segment with a severe, recognized problem, reachable through a channel you control, and willing to pay usually ranks ahead of a larger but vaguer one. The skill has no risk ranking. It has a coherence check (are the blocks consistent?) but nothing that asks which block is most likely to be wrong.

- **Validation runs in stages, each with exit criteria.** The second edition's process is:
  1. **Document Plan A** (the canvas).
  2. **Identify the riskiest parts.**
  3. **Systematically test** them, in roughly four steps:
     - *Understand the problem*: problem interviews.
     - *Define the solution*: solution interviews with a demo or mock-up, and an early price test.
     - *Validate qualitatively*: an MVP delivered to early adopters, followed by MVP interviews and a soft launch.
     - *Verify quantitatively*: launch, and measure with cohort metrics.

  These map to three fit milestones:
  - **Problem/Solution Fit**: a must-have problem exists, and a solution customers want addresses it.
  - **Product/Market Fit**: the product is something people want, shown by retention and demand you can measure.
  - **Scale**: growth.

  Before Product/Market Fit the goal is learning, not growth, and work that does not reduce a ranked risk is waste.

- **Problem interviews and solution interviews are different conversations with different exit criteria.**
  - **Problem interview.** This is a scripted conversation. It sets the scene, tells a short story of the problem, and asks the person to *rank* the top problems you listed. It then explores how they handle each one today, that is, their existing alternatives. It ends by asking for a follow-up and referrals. It is "done" when you can: name the early-adopter profile; name a must-have problem, consistently ranked high; and describe how customers solve it today.
  - **Solution interview.** This shows a demo or mock-up, tests the pricing, and checks which features address which ranked problem. It is "done" when you know the minimum feature set and a price early adopters accept.

  Maurya argues for asking for money early, because price is part of the product and a stated price is a stronger signal than stated interest. This sits alongside, and is less strict than, Fitzpatrick's *The Mom Test* (`the-mom-test-fitzpatrick.md`). Maurya's problem interview briefly describes the problem you think customers have, which the Mom Test would warn against. The repo's interview discipline already lives in `jtbd-analysis` (`skills/jtbd-analysis/SKILL.md:102-120`) and should stay there.

- **The MVP is the smallest thing that delivers the UVP to early adopters, and every experiment is a falsifiable hypothesis.** Maurya defines the MVP by subtraction. Start from the solution, cut every feature not needed to deliver the UVP to the early adopter, and charge for it where you can. A concierge or manual version is a legitimate MVP. He frames each experiment as a falsifiable hypothesis, roughly "[a specific, repeatable action] will drive [an expected, measurable outcome]". The experiment is time-boxed, its success criterion is set before it runs, and it targets one ranked risk. He separates **actionable metrics** from **vanity metrics** (Ries's distinction) and relies on **cohort analysis** rather than running totals.

- **Key Metrics follow the customer lifecycle, not a dashboard wish-list.** Maurya uses Dave McClure's "pirate metrics" funnel to organise the Key Metrics block: **Acquisition, Activation, Retention, Revenue, Referral (AARRR)**. The block should name the few lifecycle numbers that show the model working, with the focus moving down the funnel as the stage changes. The skill says only "the metrics that would signal product-market fit" (`canvas-blocks.md:266`, template `:103-104`). That gives the block no structure, so it fills with whatever metrics are easy to count.

- **Unfair Advantage is something that cannot be easily copied or bought.** Maurya's examples (from memory) include insider information, a dream team, personal authority, large network effects, an existing community or customers, and the right expert endorsements. By his rule, features, being first, hard work and passion are *not* unfair advantages, because a competitor can copy or buy them. He accepts that this block is often honestly blank at the start. The skill captures the blank-is-honest point (`canvas-blocks.md:267`). It lacks the "not an unfair advantage" list, which is the more useful filter. The same filter applies to the BMC coherence question 7 (`canvas-blocks.md:297-298`).

- ***Scaling Lean*: traction is the goal, and the business model is a "customer factory".** The sequel argues that, after the problem is validated, progress is measured by **traction**: the rate at which the business model captures monetizable value from its customers. It models the business as a **customer factory**. Unaware visitors enter, and the AARRR steps turn them into happy customers, who in turn feed acquisition through referral. Growth work is then a throughput problem. Using Goldratt's **Theory of Constraints**, you find the single step of the factory that is the current bottleneck and work only on that. Supporting techniques:
  - **Minimum Success Criteria**: the smallest outcome, a few years out, that would count as success.
  - **Fermi (back-of-envelope) estimates**: a quick check of whether the model can plausibly reach those criteria, given price, customer lifetime and conversion. The check is done before any experiment is run.
  - **Traction roadmap**: staged milestones, which Maurya builds from a roughly 10x growth step per stage.
  - **Time-boxed cycles**: about 90 days, with short sprints inside them, in which competing experiments are proposed, chosen and reviewed.

- **The third edition reworks the frame.** As far as I know, the 2022 edition folds *Scaling Lean*'s ideas back in. It presents a "Continuous Innovation Framework" with design, validation and growth phases. It adds a **customer forces** model of why customers switch, close in spirit to JTBD switch interviews, and a demo-sell-build sequence built around a strong first offer. I know this edition less well. Treat its specifics as unverified (see Caveats).

## Actionable Techniques

- **Pick the variant by evidence state, not by product name.** Use a Lean Canvas until Problem/Solution Fit has been shown: a must-have problem ranked high by early adopters, and a solution and price they accept. Move to the full BMC once partners, activities and resources can be named from operating evidence. This is the general form of the product-specific rule W1-33 flags (`SKILL.md:56-58`, `canvas-blocks.md:274-278`, `:315-317`).
- **Fill in Maurya's order and say why.** Problem and Customer Segments as a pair, then UVP, Solution, Channels, Revenue, Cost, Key Metrics, Unfair Advantage. Before writing the Solution, list the Existing Alternatives under Problem and the Early Adopters under Segments.
- **One canvas per segment.** If two segments have different top problems, draw two canvases. Then rank them by risk (pain severity, reachability, willingness to pay) and pursue one.
- **Allow, and label, honest blanks.** In a Lean Canvas, "unknown: to be tested by [experiment]" is a valid entry. "TBD" with no test is not. This reconciles Maurya with the skill's no-TBD rule.
- **Rank risk by type, then attach a test.** Tag each block entry as product, customer or market risk. Rank the top two or three. For each, write a falsifiable hypothesis with a success criterion set in advance and a time box. This pairs with the per-block evidence state in the Osterwalder file and W1-32: the evidence state says *how proven* an entry is; the risk rank says *which unproven entry to test next*.
- **Use problem- and solution-interview exit criteria as the gate out of the Lean Canvas.** Write the exit criteria into the canvas artifact as checkboxes, so "we validated it" means something specific.
- **Structure Key Metrics on AARRR.** Name one metric per customer-factory step that matters at the current stage, and mark the bottleneck. Reject running totals (cumulative sign-ups) in favour of cohort or rate metrics.
- **Run a Fermi check on the bottom rail.** Estimate: price × expected customers needed to reach a stated Minimum Success Criterion, against the cost structure. A Revenue Stream that cannot plausibly cover Cost Structure at any realistic conversion rate fails before any interview is run.
- **Filter Unfair Advantage.** Strike any entry a well-funded competitor could copy or buy within the planning horizon (features, speed, "great team" in general). If nothing survives, leave it blank and say so.

## Applies To

| Skill/Agent | Current state (as read) | What this book adds, with concrete changes |
|---|---|---|
| `skills/business-model-canvas/SKILL.md` | Variant table is sound (`:41-54`) and attributes the Lean Canvas to Maurya (`:46`). Product-specific stage rule in the body (`:56-58`, W1-33). Procedure is variant → fill → coherence check → emit → re-validate (`:137-149`). Quality Bar requires "no TBD" in every block (`:157`). No `sources:` field. The description (`:4-11`) correctly names the four substituted blocks. | (1) Replace `:56-58` with the generic evidence rule: Lean Canvas until Problem/Solution Fit exit criteria are met, then BMC. Move the product case to `examples/` (W1-33). (2) Procedure step 2: for the Lean variant, fill in Maurya's order (Problem + Segments first), one canvas per segment. (3) Add a step between fill and coherence check: **rank risk** (product / customer / market) and attach a falsifiable test to the top two or three. Merge with W1-32's evidence state so there is one per-block marker, not two. (4) Quality Bar `:157`: make Completeness variant-aware. A Lean Canvas entry may read "unknown: tested by X"; bare "TBD" still fails. (5) Quality Bar `:163` Defensibility: apply the "cannot be copied or bought" filter. (6) Add `research/product-strategy-and-gtm/running-lean-maurya.md` to `sources:`. No description change is needed, so no MAJOR bump from this file alone. |
| `skills/business-model-canvas/references/canvas-blocks.md` | Source line cites *Running Lean* (`:5-6`) with no research file until now. Substitution table (`:262-267`) is positionally correct. It gives one-to-one "why" reasons that are the skill's framing, not exactly Maurya's. `:269-270` says Value Propositions is unchanged. Key Metrics is one vague line (`:266`). Unfair Advantage covers the honest-blank point (`:267`). The migration rule (`:274-278`) and anti-pattern (`:315-317`) are product-specific. | (1) Correct `:269-270`: the central block becomes the **Unique Value Proposition**, with an optional **High-Level Concept** ("X for Y"). Four of the BMC's blocks carry over unchanged, not five. (2) Reword the table's lead-in to say the pairing is positional, and that Maurya argues the removals and additions separately. (3) Expand Key Metrics with the AARRR customer-factory structure and the actionable vs vanity distinction. (4) Add the "not an unfair advantage" list (features, first-mover, passion, generic team). (5) Make `:274-278` and `:315-317` generic (W1-33). (6) Add the three-risk table (which blocks carry product, customer and market risk). It is look-up content, so it belongs in `references/`. |
| Coherence check (`canvas-blocks.md:282-302`; W1 proposes `resources/coherence-check.md`) | Seven questions, of which Q3, Q4 and Q6 test Key Activities and Key Resources. **Those blocks do not exist on a Lean Canvas**, so the check cannot be run as written on the variant the skill recommends for early products. | Add a **Lean Canvas coherence set** next to the BMC set. (L1) Does the Early Adopter group actually hold the top-ranked Problem? (L2) Are Existing Alternatives named for each Problem? (L3) Does the UVP speak to the top Problem, not to a feature? (L4) Does each Solution item map to a listed Problem, with nothing extra? (L5) Do the Channels reach the Early Adopters specifically? (L6) Is each Key Metric a rate or cohort number tied to an AARRR step? (L7) Does a Fermi estimate show Revenue can cover Cost at a plausible conversion rate? (L8) Does the Unfair Advantage survive the copy-or-buy filter, or is it honestly blank? Add the Osterwalder file's Q10 (evidence state plus test) to both sets. |
| `references/canvas-template-and-example.md` (W1: split into `templates/bmc.md`, `templates/lean-canvas.md`, `examples/`) | The Lean template (`:74-108`) lists the nine blocks in Maurya's order, with Existing Alternatives and Early Adopters. It has no High-Level Concept, no risk or evidence marker, no experiments section and no exit criteria. The worked example is BMC only (`:112-149`). | In `templates/lean-canvas.md`: (1) add `High-level concept:` under UVP; (2) add a per-entry `risk: product/customer/market` and `evidence:` marker; (3) add a "Riskiest assumptions → experiments" section (hypothesis, success criterion, time box); (4) add a "Problem/Solution Fit exit criteria" checklist; (5) structure Key Metrics as AARRR rows. For `examples/`: W1 example 1 (a lunch-order tracker with Unfair Advantage honestly blank) and example 2 (Lean → BMC migration after design partners) are exactly the cases this book describes. Example 2 should show which interview exit criteria triggered the migration. |
| `skills/artifact-manifest/resources/phase-requirements.json` | `business-model-canvas` is `"lean": "skip"`, although its accepted paths include `strategy/lean-canvas.md`. | An observation for the owner, not a change for this file. The Lean Canvas is the lightest business-model artifact there is, and Maurya designed it for the smallest products. Making it `optional` (not `skip`) at the lean profile, for the Lean variant only, would match the book. The skill should at least state the lean-profile rule, as W1 already notes. |
| `skills/beta-program-design/SKILL.md` | Stages run closed alpha → closed beta → open beta → GA (`:42-51`), with Blank's earlyvangelist screening (`:59-68`) and extend / remediate / pivot outcomes that name the suspect hypothesis (`:130-138`). | Close alignment. Maurya's "validate qualitatively" step is the closed beta, and "verify quantitatively" is open beta to GA. Two light additions: (1) the pivot decision should name which canvas block the failed hypothesis lives in, so the business-model canvas is updated, not just the beta record; (2) the graduation bar's quantitative dimension (`:127`) is all quality metrics (UAT, defects, SLOs). An AARRR retention or activation signal from the canvas's Key Metrics would add the Product/Market Fit evidence Maurya treats as the real exit test. Keep ownership with `requirements-analyst`. |
| `skills/jtbd-analysis/SKILL.md` | Owns the interview discipline via the Mom Test (`:102-120`). | Maurya's problem interview (rank the problems, explore existing alternatives) and the customer-forces model (3rd ed.) overlap with this skill's job and switch analysis. Do not copy Maurya's script into `business-model-canvas`. Point the Problem block at `jtbd-analysis`'s interviewing reference, and let its ranked jobs feed the Problem ranking. Note the one real tension: Maurya's script describes the problem up front, which the Mom Test would avoid. The Mom Test should govern the actual conversation. |
| `skills/gtm-strategy/SKILL.md` | Owns ICP, positioning, channels and pricing. | Early Adopters is a narrower cut than the ICP, and the High-Level Concept is close to a positioning tagline. The canvas should reference GTM decisions rather than restate them (W1 overlap note). Maurya's "charge from day one" belongs with pricing only as an early-validation tactic. Value-based price-setting is *Monetizing Innovation*'s territory (W1 coverage). |
| `skills/okr-authoring`, `skills/roadmap-authoring` | Not read in depth for this file. | A light link. *Scaling Lean*'s Minimum Success Criteria and traction roadmap are a business-model-level counterpart to OKRs and roadmaps. At most, add a cross-reference; do not restate them. |
| `agents/product-strategist.md` | Owns business-model-canvas. | No ownership change. Risk ranking, experiments and the Fermi check are knowledge that `product-strategist` applies. Choosing *which* experiment to run for a given product is the agent's reasoning, not the skill's. |

## Candidate New Skills/Agents

- **No new skill is warranted for the Lean Canvas itself.** It is a variant of an artifact that `business-model-canvas` already owns, and both are written to the same manifest artifact (`phase-requirements.json` accepts either path).
- **A shared assumption-testing reference is again a candidate.** It would cover risk ranking, falsifiable hypotheses, success criteria set in advance, and time-boxed experiments. The Osterwalder file reached the same conclusion from *Value Proposition Design* and *Testing Business Ideas*. Maurya's experiment format, Blank's Customer Development and Bland's Test Cards are three versions of one practice. It cuts across `business-model-canvas`, `beta-program-design`, `jtbd-analysis` and `impact-mapping`. One shared home is better than four partial copies.
- **A `traction-model` (customer factory) skill is a borderline case.** The AARRR funnel, bottleneck finding, Fermi estimates and the traction roadmap form a coherent body of knowledge with its own possible artifact. But this repo's products enter Customer Validation through `beta-program-design` and observability skills, and adding a traction skill now risks a third home for metrics. The recommendation is to start with a Key Metrics section in `canvas-blocks.md`, and revisit if a post-launch growth phase is added.
- **No new agent.**

## Key Terminology

- **Lean Canvas**: Maurya's one-page adaptation of the Business Model Canvas for products whose problem and traction are unproven.
- **Problem / Existing Alternatives**: the top one to three problems for the early adopter, and how they are solved today without you.
- **Customer Segments / Early Adopters**: the target market, and the narrow first group who feel the problem most and know it.
- **Unique Value Proposition (UVP)**: one clear, compelling message stating why you are different and worth attention.
- **High-Level Concept**: an "X for Y" analogy that makes the UVP quick to grasp.
- **Solution**: the smallest set of capabilities that addresses each listed problem.
- **Key Metrics**: the few lifecycle numbers that show the model working, usually organised by AARRR.
- **Unfair Advantage**: something that cannot be easily copied or bought.
- **Plan A**: the first canvas, written quickly as a set of guesses to be tested.
- **Product / Customer / Market risk**: risk in getting the product right, in reaching customers, and in building a viable business.
- **Problem Interview / Solution Interview / MVP Interview**: three conversations, each with its own exit criteria, that move from "is the problem real?" to "will they use and pay for this?"
- **Problem/Solution Fit, Product/Market Fit, Scale**: the three stages of progress.
- **MVP (Minimum Viable Product)**: the smallest thing that delivers the UVP to early adopters.
- **Actionable vs Vanity Metrics**: metrics that tie a specific action to an outcome, versus totals that only go up.
- **Customer Factory**: *Scaling Lean*'s model of the business as a machine that turns visitors into happy customers through the AARRR steps.
- **Traction**: the rate at which a business model captures monetizable value from its customers.
- **Minimum Success Criteria / Fermi Estimate / Traction Roadmap**: the smallest worthwhile outcome, a rough check that the model can reach it, and the staged milestones on the way.

Several of these (MVP, Product/Market Fit, actionable metric) are not in the CLAUDE.md glossary. If the skill adopts them, they should be added through `glossary-management`, not used ad hoc.

## Caveats

- **High confidence.** I am confident of:
  - the Lean Canvas's nine blocks and their positions relative to the BMC, including which BMC blocks are removed;
  - the UVP rename and the High-Level Concept;
  - the Existing Alternatives and Early Adopters sub-boxes;
  - the fill order with Problem and Customer Segments first;
  - one canvas per segment, and honest blanks being acceptable;
  - the product / customer / market risk grouping;
  - the problem-interview and solution-interview distinction and their general exit criteria;
  - the three stages (Problem/Solution Fit, Product/Market Fit, Scale);
  - the MVP-by-subtraction and falsifiable-hypothesis framing;
  - the AARRR basis for Key Metrics;
  - the "cannot be easily copied or bought" definition of Unfair Advantage;
  - *Scaling Lean*'s traction definition, customer factory, Theory of Constraints bottleneck focus and Fermi estimates.

  All of these are repeated across Maurya's books, blog and public LEANSTACK material.
- **Medium confidence.** These are my recollection and may differ from the printed text:
  - the exact steps of the problem-interview script;
  - the exact wording of the exit criteria;
  - the second edition's four-step "understand, define, validate qualitatively, verify quantitatively" naming;
  - the list of example unfair advantages;
  - the 10x traction-roadmap rule and the roughly 90-day cycle length;
  - the reason he gives for dropping Customer Relationships.

  On the block-pairing question: the *positional* replacement is certain. Whether Maurya himself argues it as four one-to-one trades, as the skill's table does, is the part I am unsure of. My recollection is that he does not.
- **Low confidence.** I know the **third edition (2022)** only in outline: the Continuous Innovation Framework, customer forces, and a demo-sell-build sequence. Its specific canvas wording, stage names and any changes to the Lean Canvas should be checked against the book before a skill quotes them.
- **No page numbers, quotations or statistics are given.** I cannot reproduce them reliably. The "time to sketch a canvas" advice is given as "a short single sitting" because I do not trust a specific figure. I have deliberately left out any product/market-fit survey threshold that the book may cite.
- **Practitioner framework, not evidence.** Like Osterwalder, Blank and Ries, Maurya writes from coaching experience and case stories. The methods are widely used, but their effectiveness is asserted, not measured. The repo should treat them as actionable but not proven, as it treats Dunford and Cagan.
- **Fit with this repo's context.** Maurya writes for founders running live interviews. Here, an agent drafts a canvas for one reviewer, so what carries over directly is the canvas structure, the fill order, risk ranking and exit criteria. The interviews and experiments happen outside the plugin, and the artifact should record their results, not pretend to run them.
- **Stale line references in Wave 1 findings.** `wave-1-findings.md` cites the Lean Canvas mapping at `canvas-blocks.md:143-148` and its attribution at `:135`. In the current file these are `:262-267` and `:254`. The conclusion (the mapping is correct) stands.
