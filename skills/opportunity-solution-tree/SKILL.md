---
name: opportunity-solution-tree
description: >
  Teaches how to build the opportunity solution tree (OST; Teresa Torres,
  Continuous Discovery Habits) in Ideate: one desired outcome at the root, a
  product outcome the team can move, never a business outcome or a traction
  metric; the opportunity space beneath it (customer needs, pain points and
  desires in the customer's voice, nested under the steps of the customer's
  experience, each citing interview snapshots or feedback items);
  compare-and-contrast prioritisation of sibling opportunities to one target
  opportunity; several candidate solutions for it, about three carried forward;
  and assumption tests (desirability, viability, feasibility, usability, ethical)
  whose success criteria are set before they run. Use when mapping
  opportunities, building or updating an opportunity solution tree, deciding
  which customer problem to work on next, turning interview snapshots or beta
  feedback into customer needs, choosing a target opportunity, comparing
  solutions, or planning assumption tests. Used by the requirements-analyst
  agent in Ideate (/sdlc-ideate) after the JTBD analysis and before the impact
  map; at lean, a short ranked opportunity list under one outcome.
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-24
tags: [ideate, discovery, opportunity-solution-tree, opportunity-mapping, desired-outcome, target-opportunity, assumption-testing, continuous-discovery]
produces: [opportunity-solution-tree, assumption-test]
domain: discovery
status: stable
related: [jtbd-analysis, impact-mapping, feedback-template, beta-program-design, okr-authoring, user-persona, user-story-writing, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/continuous-discovery-habits-torres.md
  - research/requirements-and-user-stories/impact-mapping-adzic.md
  - research/product-strategy-and-gtm/competing-against-luck-christensen.md
  - research/human-ai-collaboration/unleash-creativity-with-ai-bier.md
  - research/product-strategy-and-gtm/inspired-cagan.md
---

# Opportunity Solution Tree

## Purpose

The opportunity solution tree is the central artifact of Teresa Torres's *Continuous Discovery Habits*. It holds, in one picture, **why** the team is working on a solution: this solution, for **this** customer opportunity, toward **this** outcome. Read top-down:

```
Desired outcome (one product outcome)
 └─ Opportunities: customer needs, pain points, desires (customer's voice), nested
     └─ Solutions: several per target opportunity, about three carried forward
         └─ Assumption tests: small, fast, success criteria set before they run
```

No other artifact in the plugin keeps a growing, structured set of customer needs that next week's evidence can be added to. Job stories (`jtbd-analysis`) describe jobs; impact-map impacts (`impact-mapping`) describe behaviour changes. The tree sits between them.

## Where It Sits

```
Ideate: personas ─► JTBD analysis ─► OPPORTUNITY SOLUTION TREE ─► impact map ─► functional requirements ─► epics …
          ▲ dated interview snapshots (Ideate)  ▲ feedback-log items and beta check-ins (Customer Validation)
```

| Reads | What it takes |
|---|---|
| The OKR set (`okr-authoring`) | The Key Result the outcome serves. Classify it first (below) |
| Interview snapshots (`jtbd-analysis`) | Each snapshot's **opportunities heard**, already in the customer's voice and tagged with an experience step. Placed with no rewording |
| `jtbd-analysis` | Job statements and the steps of the job, as candidate top-level branches; the target desired-outcome statement, as a sizing input |
| Feedback logs (`feedback-template`), beta check-ins (`beta-program-design`) | Each item's underlying need is evidence of an opportunity. A missing-capability request is an opportunity to compare, not a feature to schedule |

| Feeds | What it gives |
|---|---|
| `impact-mapping` | The outcome becomes the map's WHY (with the KR's metric fields); the target opportunity explains the gap between an actor's current and wanted behaviour (HOW); the carried-forward solutions are WHAT candidates, with their assumptions and tests |
| `user-story-writing` (lean, no impact map) | The target opportunity's chosen solution, as the backlog's starting point |
| The next discovery cycle | Test results and post-launch evidence close, prune or re-rank branches |

## Who Does What

This plugin has no product trio. Torres's trio (product manager, designer, tech lead deciding together) becomes, here, an adaptation the artifact names as this plugin's, not Torres's:

- **The user** (the product owner) holds the customer conversations, runs the assumption tests with real people, and **chooses the target opportunity**: a reversible decision the agent prepares but does not make.
- **The agent** synthesises snapshots, places opportunities, lays out the sibling comparison, generates solutions, lists and ranks assumptions, and drafts each test with its success criterion.
- **An engineering agent** is asked for feasibility notes on specific feasibility assumptions, never for the whole tree.

The agent never claims evidence no conversation produced: an opportunity with no snapshot or feedback item behind it is tagged `[assumption]`.

## The Root: Classify the Outcome Before Building

Torres separates three kinds of metric. Label the linked KR before writing anything else:

| Kind | Measures | At the root? |
|---|---|---|
| **Business outcome** | The business's progress: revenue, retention, cost. Lags; many teams move it | **No.** Ask which customer behaviour the team believes drives it, and root the tree there. If nobody knows, flag it to the user and to the OKR owner |
| **Product outcome** | A change in what customers do in the product, which the team can move directly and which responds quickly | **Yes** |
| **Traction metric** | Use of one specific feature | **No.** It is a solution already chosen. Ask what the feature was for, and root the tree at that |

When the right metric is not yet known, the root may be a **learning goal** (find the metric that matters) before it becomes a performance goal. Carry the KR's metric, meter, baseline and target into the root, field by field (Adzic, *Impact Mapping*); never invent a number the KR lacks.

**Name clash, keep apart:** Torres's *desired outcome* is this tree's root metric. Ulwick's *desired-outcome statement* (`jtbd-analysis`) is a customer's success measure within a job. A desired-outcome statement may inform how an opportunity is sized; it never sits at the root.

The full typology with worked reclassifications: `./references/outcomes-and-opportunities.md` §1. Read it whenever the KR is revenue, retention, a cost, or a feature's usage.

## The Opportunity Space

Every opportunity must pass four rules:

1. **Customer's voice.** A need, pain point or desire as the customer would say it, from a snapshot or feedback item: "I never know who still owes me until I check the bank app."
2. **Not a solution in disguise.** "I wish there was a dashboard" is a solution; the opportunity is what the dashboard is for. **Test: could more than one solution address it?** If not, rewrite it one level up.
3. **Nested.** Big opportunities break into smaller, more solvable children. The **top level is the steps of the customer's experience**, from an experience map of what the team currently knows (the experience-step tags on snapshots supply it). Every child sits under exactly one parent.
4. **Evidenced.** Each cites the snapshots or feedback items it was heard in, and counts the **independent stories** behind it. A new snapshot's opportunities are merged with existing ones, not appended as duplicates.

An opportunity is not a job (higher, solution-free, stable; Christensen) and not an impact (an actor's behaviour change; Adzic). Framing, nesting, merging and the experience map in full: `./references/outcomes-and-opportunities.md` §2–§3.

## Choosing a Target Opportunity

Torres argues for **compare-and-contrast** decisions over **whether-or-not** decisions. So:

- **Compare siblings under the same parent, one level at a time.** Choose among the top-level branches, then among that branch's children, and stop at an opportunity small enough to act on. Never rank every node of the tree in one flat list.
- **Use all four lenses, one column each** in the comparison table at every level: **opportunity sizing** (how many customers, how often: count independent stories), **market factors** (table stakes or a differentiator), **company factors** (strategy kernel, strengths), **customer factors** (how important to the customer, how badly served today). A comparison on story counts alone is sizing only.
- **No numeric score at small n.** With a handful of conversations, the comparison is qualitative; any rating is labelled directional. Ulwick's opportunity score belongs to desired-outcome statements with a survey sample (`jtbd-analysis`), not to tree nodes.
- **The result is one target opportunity**, a two-way-door decision recorded with its reason and revisited next cycle.

Worked comparisons: `./references/outcomes-and-opportunities.md` §4.

## Solutions and Assumption Tests

For the target opportunity only:

1. **Generate many solutions**, then **carry about three forward together**, so every test compares options instead of voting on a favourite. With no team to ideate alone-then-together (Torres), the agent runs two passes, the second under a constraint ("no new code", "one week"), and includes at least one non-software option (Adzic; Bier, *Unleash Your Creativity with AI*).
2. **List each solution's assumptions** by walking the tree's lines (why would this solution address this opportunity, why would that move the outcome), by story-mapping the solution's steps, and by a pre-mortem. Type each: **desirability, viability, feasibility, usability, ethical**. The first four match Cagan's risks (*Inspired*); Torres adds **ethical**: could it do harm, and should it be done at all.
3. **Rank by importance × evidence** (David Bland's map, via Torres): test the important, low-evidence ones first.
4. **Write each test's success criterion before it runs**, with a number: "at least 4 of 6 clinic owners pick the reminder over the deposit". A result is recorded against that bar, never judged afterwards.
5. **Test small first**, across the solution set, and grow tests only as confidence grows.

Assumption types, test designs, recording results and closing the loop after launch: `./references/solutions-and-assumption-tests.md`. Read it before writing any test.

## Producing the Artifact

1. **Check the profile** (Scale, below) and read the OKR set, snapshots, feedback logs and JTBD analysis.
2. **Classify the KR** and write the root. Stop and ask if it is a business outcome with no known product outcome behind it.
3. **Build the opportunity space** from evidence: top level from experience steps, children merged from snapshots and feedback, each with citations and a story count.
4. **Compare siblings level by level**; present the comparison; the user picks the **target opportunity**.
5. **Generate solutions, carry about three forward, list and rank assumptions, draft tests** with success criteria set first (standard and enterprise).
6. **Validate** against `./resources/ost-checklist.md` and run `python3 ./scripts/check-opportunity-solution-tree.py <artifact>`.
7. **Write the file** from `./templates/opportunity-solution-tree.md` (or, at lean, `./templates/ranked-opportunity-list.md`); present it before the impact map.

**Lifecycle.** The tree is versioned **per discovery cycle**. New snapshots and feedback are new dated files and never edit the approved tree; it is revised deliberately when evidence restructures a branch or changes the target. Assumption-test results go in new dated files from `./templates/assumption-test.md` (`ideate/assumption-tests/<yyyy-mm-dd>-<slug>.md`), so running a test never reopens an approved artifact.

## Scale

`phase-requirements.json`: **optional** at lean, **required** at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | Not a tree: one product outcome and a **short ranked list** of three to seven opportunities, each in the customer's voice with its evidence, ending in a target and one or two solution ideas. Written when the user has heard from customers: `./examples/01-lean-pottery-studio.md` |
| **standard** | The full tree for the one product outcome in play: experience-step branches, target opportunity, about three solutions, typed and ranked assumptions, tests with preset criteria: `./examples/02-standard-physio-clinics.md` |
| **enterprise** | **One tree per product outcome** (`ideate/opportunity-solution-trees/<outcome>.md`), opportunities tagged by segment or tenant role so one segment's need is never averaged into another's, and **assumption-test tracking**: every test a dated file, each tree listing its tests' status: `./examples/03-enterprise-freight-platform.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Revenue at the root** | A business outcome lags and many teams move it; the tree cannot steer by it |
| **A feature's usage at the root** | A traction metric decides the solution before discovery starts |
| **Solutions in disguise** | "I need an export button" admits one answer; the need behind it admits many |
| **A flat backlog called a tree** | Opportunities with no parent, or ranked all together across levels |
| **Whether-or-not on one idea** | "Should we build the reminder?" with nothing to compare it with |
| **One solution per opportunity** | The team falls in love with its first idea; tests become votes |
| **Testing the whole idea** | An MVP built to see what happens, when one assumption was the risk |
| **Criteria set after the result** | Any outcome can be read as success |
| **No ethical assumptions** | Harm, over-collection or surveillance risk goes untested |
| **Agent as interviewer or tester** | The agent cannot talk to customers; uncited opportunities are `[assumption]` |
| **Weekly edits to the approved tree** | Every edit reopens it; evidence goes in dated files, the tree changes per cycle |
| **Product-specific opportunities as rules** | A compliance need required of every product belongs in an example |

Use canonical terms from `glossary-management`: **Opportunity Solution Tree**, **Desired Outcome**, **Business Outcome**, **Product Outcome**, **Traction Metric**, **Opportunity**, **Target Opportunity**, **Experience Map**, **Assumption Test**, **Compare-and-Contrast Decision**, **Interview Snapshot**, **Desired-Outcome Statement**. Run `methodology-review` before hand-off.
