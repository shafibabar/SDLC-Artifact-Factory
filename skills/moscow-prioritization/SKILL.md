---
name: moscow-prioritization
description: >
  Teaches how to finalise priority at the end of Ideate with MoSCoW (DSDM):
  Must Have (the Minimum Usable SubseT, which is the story map's walking
  skeleton, checked both ways), Should Have, Could Have and Won't Have this
  time, for one release. Covers the "what happens if it is not delivered?"
  test and the workaround clause (any workaround, even manual, means not a
  Must), judging a high epic's stories one by one, the prioritisation
  agreement (the product owner decides), contingency as a droppable Should /
  Could tier in cut order instead of a capacity percentage, Won't with a
  reason and a look-again point, Cohn's value / cost / risk / knowledge
  tie-break, and the Kano cross-check (Basic, Performance, Delighter). Use
  when prioritising a backlog, turning provisional high / medium / low or
  value / penalty into Must / Should / Could / Won't, challenging "everything
  is a Must", settling a contested Must, or applying MoSCoW with no
  estimates. Used by the requirements-analyst agent last in Ideate
  (/sdlc-ideate), after the story map; required at standard and enterprise
  (ideate/moscow.md); at lean there is no MoSCoW file and the Must /
  Won't-this-time block closes ideate/user-stories.md.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, prioritization, moscow, minimum-usable-subset, walking-skeleton, dsdm, kano, release-planning]
produces: moscow-prioritized-backlog
domain: discovery
status: stable
related: [story-mapping, user-story-writing, epic-definition, requirements-analysis, user-persona, jtbd-analysis, nfr-specification, uat-plan, roadmap-authoring, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/dsdm-agile-project-framework.md
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md
  - research/requirements-and-user-stories/user-story-mapping-patton-economy.md
  - research/product-strategy-and-gtm/lean-product-playbook-olsen.md
---

# MoSCoW Prioritization

## Purpose

MoSCoW answers: **for this one release, what is guaranteed, and what gives way if the release runs into trouble?** It comes from DSDM (the DSDM Agile Project Framework; the acronym is Dai Clegg's), not from Cohn, Patton or the Hathaways. DSDM fixes time, cost and quality and lets the features vary. MoSCoW decides **in advance** which features give way, so the date and the quality bar never have to.

In this plugin MoSCoW **finalises a provisional priority**. Requirements, epics and stories are written with high / medium / low (value and penalty scores at enterprise), never Must / Should / Could / Won't. MoSCoW runs **last in Ideate**, after the story map, and turns those into release decisions.

## Where It Sits

```
Ideate: … epics ─► stories ─► example maps ─► acceptance criteria ─► story map ─► MOSCOW
```

| Reads | What it takes |
|---|---|
| `story-mapping` | The walking skeleton (the proposed Must set), release slices, the two-way Must check against provisional priorities |
| `user-story-writing`, `epic-definition` | Stories with provisional priority; epic sizes by story count; at lean the backlog with its spine |
| `requirements-analysis` | Business rules and legal or regulatory obligations (BR-n), the waiting room |
| `user-persona`, `jtbd-analysis` | Who feels the pain of a missing story; at enterprise, the persona-weighted feature matrix |

| Feeds | What it gives |
|---|---|
| `uat-plan` | UAT scope: the release's Must Have stories |
| `story-mapping` | Any re-cut MoSCoW forces (a legal Must added, a workaround story moved off the skeleton) |
| `roadmap-authoring` | Won'ts with their look-again points; the first release's confirmed scope |

## The Four Categories (DSDM)

| Category | Test | If the answer is no |
|---|---|---|
| **Must Have** | "What happens if this is not delivered?" answers: **no point delivering**, **illegal**, **unsafe**, or **not viable**; and there is **no workaround** | Not a Must |
| **Should Have** | Important; leaving it out hurts, but the release is still viable, often with a workaround | Could, or Won't |
| **Could Have** | Wanted; leaving it out hurts less than a Should. The first contingency dropped | Won't |
| **Won't Have this time** | Agreed out of **this** release, recorded with a reason and when to look again | Close it if it will never be built |

**The workaround clause** (DSDM) is the part most often skipped and the one that removes most false Musts: **if there is any workaround, even a manual or painful one, it is not a Must.** For a legal, safety or regulatory obligation, a workaround counts only if it still meets the obligation. The Hathaways (*Getting and Writing IT Requirements in a Lean and Agile World*) ask the same question of requirements, "what happens if we don't build this?": with no consequential answer it is a preference, not a requirement.

**Should vs Could is degree of pain**: business value lost and the number of people affected. Not "degraded vs barely noticed" by feel. Volume of insistence is never a criterion.

## Judge Musts One by One

A Must epic does not make Must stories. Run the test **on each story**: under a high epic, some stories are on the skeleton and some are Shoulds or Coulds (edge cases, a second input format, a convenience). Never copy an epic's priority onto its stories. Epic size by story count (S / M / L) is a relative weight, never an estimate.

## Must = Minimum Usable SubseT = Walking Skeleton (D045)

DSDM expands MUST as the **Minimum Usable SubseT**: the guaranteed set that *together* gives a usable solution. "Usable" means end to end, which is the walking skeleton's own test (Patton, crediting Alistair Cockburn). So the check runs **both ways**, exactly as `story-mapping` runs it:

1. **Every skeleton story is a Must.** If the workaround clause finds a workaround for one, that story moves to a later slice (or the contingency) and the workaround becomes a named manual cell on the skeleton. The skeleton must still walk.
2. **Every Must sits on the skeleton.** A Must off the skeleton is either not a Must (demote it) or a **legal, safety or regulatory Must**, which is **added to the skeleton** at the step it protects and marked with its rule.

A pile of Musts with a hole in the journey is not *usable*, so it fails DSDM's own definition: add the missing step, never accept the gap. The map **proposes** the skeleton; MoSCoW **confirms** it at release level and hands any re-cut back to `story-mapping`. Never leave the two lists disagreeing. Stories in slices below the skeleton are not Musts of *this* release; they get their own MoSCoW when their release comes. The full rule set, levels and negotiation: `./references/dsdm-moscow-rules.md`. Read it before binning, and whenever a Must is contested.

## Contingency, Not a Capacity Ceiling

DSDM guides Musts to no more than about 60% of a timebox's effort so that contingency absorbs wrong estimates. **This plugin does not use the percentage (D045).** It needs person-week estimates, and agents build the product, so no skill produces them, and DSDM itself lowers the percentage when estimates are unreliable. Keep the purpose with three **structural checks**:

1. **Usable:** the Musts pass the two-way skeleton check.
2. **Droppable:** the release holds a non-empty Should / Could tier, **listed in the order it would be cut** (Coulds first, then Shoulds; a protected Delighter last).
3. **Workaround-free:** every Must has passed the workaround clause.

If the Musts outgrow the skeleton or no droppable tier is left, stop: the product owner decides the scope (narrow the release, move a date, or demote), never the analyst. The binding constraints to name are the release date the product owner set (if any), the quality bar, and the model and review budget, not team capacity. At enterprise, an optional **report-only** line may give the Must share by story count (or weighted by epic size); it is never a pass / fail gate. Why the 60% rule was dropped, and the arithmetic of the optional line: `./references/dsdm-moscow-rules.md` § 5.

## The Prioritisation Agreement Comes First

Before binning, write the agreement DSDM asks for: the **constraint** (date, quality bar, review budget), **who decides** (the product owner, holding DSDM's Business Visionary and Business Ambassador roles), **what drops first** when the release is under pressure, and **how a disputed Must is escalated** (to the product owner, with the evidence). The requirements-analyst facilitates and records (DSDM's Business Analyst role) and never decides a contested priority.

## Breaking Ties Below the Musts

- **Cohn's four factors** (*User Stories Applied*): value, cost, risk removed and knowledge gained. Use them to order Shoulds and Coulds in the cut list, never to make a Must. A spike or a risky story often goes early because of risk and knowledge, not value.
- **Kano cross-check** (Noriaki Kano, as used by Dan Olsen, *The Lean Product Playbook*): a different axis. Kano classifies how satisfaction responds to a feature (Basic, Performance, Delighter, Indifferent, Reverse); MoSCoW decides what this release guarantees. A Kano-Basic that is not a Must gets a second look (it does not get promoted automatically); a Delighter is protected in the cut order; Indifferent and Reverse go to Won't. Classify per persona, never on a blended average. The axes, the mapping and the per-persona rules: `./references/moscow-and-kano.md`. Read it when a story's Kano class is cited as a reason for its bin.

## Three Levels, Re-run Every Release

DSDM prioritises at three levels: **project** (the provisional priority on requirements, epics and stories), **release** (this skill) and **iteration** (in Implement, against the release Musts). The same story can be a Could now and a Must two releases later. Each Won't is looked at again at the release its row names.

## Producing the Artifact

1. **Check the profile** (Scale, below). At lean, write no `moscow.md`.
2. **Read** the story map's skeleton and Must check (at lean, the walked spine), the backlog, the rules (BR-n).
3. **Write the prioritisation agreement.**
4. **Test every skeleton story** with the Must test and the workaround clause, one by one; then every story off the skeleton for a legal, safety or regulatory obligation.
5. **Run the two-way check**; hand any re-cut to `story-mapping`.
6. **Bin the rest**: Should vs Could by pain; Won't with reason and look-again.
7. **Order the contingency** with Cohn's factors and the Kano cross-check.
8. **Validate** against `./resources/moscow-checklist.md` and run `python3 ./scripts/check-moscow.py <file> [--story-map ideate/story-map.md] [--backlog ideate/user-stories.md]`. If you cannot run it, re-check the two-way list and the cut order by hand.
9. **Write** from `./templates/moscow-prioritized-backlog.md` to `ideate/moscow.md` (at lean, the block from `./templates/lean-must-wont-block.md` closing `ideate/user-stories.md`).

## Scale

`phase-requirements.json`: the MoSCoW artifact is **skipped** at lean and **required** at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | **No `moscow.md`.** The backlog `ideate/user-stories.md` closes with the **Must / Won't-this-time block**: a spine line, the Musts (the walking skeleton, one story or named manual step per journey step), the Won'ts this time with a workaround or reason and a look-again point, the contingency with provisional priorities, a learning checkpoint. No Should / Could labels. `./examples/01-lean-toolshed.md` |
| **standard** | `ideate/moscow.md`: prioritisation agreement; Must (each with its DSDM signal and "no workaround"), Should, Could, Won't this time; contingency in cut order; the two-way skeleton check; Kano notes on the contingency. `./examples/02-standard-rebound.md` |
| **enterprise** | Adds project-level (value / penalty) beside release priorities, legal and contractual Musts per tenant marked with their rule, a re-cut hand-off to the story map, the optional report-only Must share, a priority change log across releases, and any scope escalation recorded with the product owner's decision. `./examples/03-enterprise-permitry.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Everything is a Must** | No contingency; the first surprise moves the date. Apply the workaround clause story by story |
| **High epic = Must stories** | DSDM judges each story; edge cases under a Must epic are Shoulds |
| **Invented person-weeks** | False precision for a 60% rule this plugin dropped; use the three structural checks |
| **Musts ≠ skeleton** | Either the release is not usable or a skeleton step is not guaranteed |
| **Kano-Basic, therefore Must** | Different axes; Basic means look again, not promote |
| **Won't with no reason or look-again** | Re-raised every conversation; "this time" means not now, not never |
| **The analyst decides a dispute** | Priority belongs to the product owner; the analyst records |
| **MoSCoW before the story map** | Pre-empts the skeleton; provisional priority until this step |
| **Product rules as skill rules** | A compliance persona or tenant rule belongs in that product's artifact, not every product's |

Use canonical terms from `glossary-management`: **MoSCoW**, **Minimum Usable SubseT**, **Workaround Clause**, **Walking Skeleton**, **Provisional Priority**, **Contingency**, **Kano Model**, **Release Slice**. Run `methodology-review` before hand-off.
