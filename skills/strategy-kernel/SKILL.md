---
name: strategy-kernel
description: >
  Teaches how to write a product strategy kernel (Rumelt): a diagnosis that names
  the critical challenge (the crux), a guiding policy that chooses one approach,
  names the advantage it exploits and rules whole directions out, and a few
  coherent actions that reinforce each other. Use when writing, reviewing or
  revising a product strategy, testing a draft strategy for goals-as-strategy,
  fluff or a dog's dinner of objectives, deciding what sits between the vision
  and the OKRs, or asked for a mission statement (this plugin has none; the
  kernel replaced it). Used by the product-strategist agent in every Strategy
  phase (/sdlc-strategy), after the vision and before the OKR set and roadmap.
version: 1.0.0
phase: strategy
owner: product-strategist
created: 2026-10-19
tags: [strategy, strategy-kernel, diagnosis, guiding-policy, coherent-actions, rumelt]
produces: strategy-kernel
domain: strategy
status: stable
related: [vision-statement, okr-authoring, roadmap-authoring, competitive-analysis, stakeholder-mapping, business-model-canvas, gtm-strategy, glossary-management]
sources:
  - research/product-strategy-and-gtm/good-strategy-bad-strategy-rumelt.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/product-strategy-and-gtm/obviously-awesome-dunford.md
  - research/product-strategy-and-gtm/measure-what-matters-doerr.md
---

# Strategy Kernel

## Purpose

The vision says where the product is going. The strategy kernel says **what stands in the way, and how we will get past it.** The structure is Rumelt's (*Good Strategy / Bad Strategy*): every real strategy has a **kernel** of three parts, and all three must be present.

1. **Diagnosis**: what is going on, and the one challenge that makes it hard.
2. **Guiding policy**: the overall approach chosen to deal with that challenge. It points effort in one direction and rules whole families of action out.
3. **Coherent actions**: a few concrete moves that carry out the policy and reinforce each other.

Rumelt's central claim is that most documents called "strategy" are not strategies. They are goals, visions, slogans or budgets. A strategy is a *response to a challenge*, not a statement of ambition. Cagan (*Inspired*) makes the same split for products: the vision is the durable picture; the strategy is the focused bets that move toward it, which means saying no to most other things. The kernel is the artifact that holds that strategy.

**This kernel replaced the mission statement.** Rumelt gives no support for a separate mission artifact, and he names fill-in-the-blank vision / mission / values planning as a *cause* of bad strategy, because every slot can be filled without ever diagnosing a problem. Cagan does not define a mission either. The mission's two useful jobs now live where they belong: its present-tense purpose line ("we [do X] for [user] so that [outcome]") is one line of the vision (`vision-statement`), and its scope boundary is the guiding policy's **rules-out** list, which now carries a reason. If someone asks for a mission statement, write the vision's purpose line and this kernel.

---

## Where the Kernel Sits

```
Vision ──► Strategy kernel ──► OKR set ──► Roadmap
(where)    (what blocks us,     (proximate     (coherent actions,
           how we get past it)   objectives)    sequenced)
```

| Kernel part | Consumed by | How |
|---|---|---|
| Diagnosis | everything below | The OKRs and roadmap are judged by whether they attack *this* challenge |
| Guiding policy | `okr-authoring` | Each Objective is the next **proximate objective** the policy implies: close enough to reach this cycle, clear enough that the team knows what to do next |
| Guiding policy | `business-model-canvas`, `gtm-strategy` | The advantage it relies on is the canvas's Unfair Advantage; a *focus* policy is what the GTM beachhead carries out |
| Coherent actions | `roadmap-authoring` | The roadmap sequences them; each roadmap item serves an action and is tested for coherence, not only traceability |

Doerr (*Measure What Matters*) puts OKRs *under* a long-term direction: they come from it and are not derived from a plan of work. The kernel is that direction made specific. Without it, an OKR set is exactly what Rumelt calls goals mistaken for strategy: targets with no stated theory of how the obstacle is overcome. The one feedback loop runs upward: if no coherent set of actions could reach an Objective, the Objective is not proximate, and it goes back for revision.

**Inputs.** Always the vision and the problem statement. At standard and enterprise also the stakeholder map (whose constraints and inertia the diagnosis must name) and the competitive analysis (the competitive alternatives and the unique attributes an advantage is built from). Read them first; the kernel is written after them and before the business model canvas and GTM strategy.

---

## The Three Parts

| Part | Question | Write it as | Passes when |
|---|---|---|---|
| **Diagnosis** | What is the critical challenge, and why is it hard? | A judgement, not a data dump: the situation reduced to the few things that matter, ending on the **crux** | A reader can name the obstacle; it could be shown wrong by evidence |
| **Guiding policy** | What approach do we take to that challenge? | One approach, the **advantage or leverage** it uses, and what it **rules out**, each exclusion with its reason | Whole, tempting directions are now a "no", *because of* the diagnosis |
| **Coherent actions** | What do we actually do? | 3–6 concrete moves (lean: 2–3), each stating which other action or which part of the policy it reinforces | No action works against another; deleting one weakens another |

**Finding the crux** (Rumelt, *The Crux*, summarised in the research file). List the challenges honestly, then pick the one that is both **important** (solving it unlocks much of the rest) and **addressable** (the team can actually do something about it). A challenge that is critical but impossible ("the incumbent has ten times our funding") is as bad a crux as one that is easy but trivial. Name the others you set aside, so a reviewer can disagree.

**Choosing the guiding policy.** A policy gets its force from a source of power: concentrating effort on a pivot point, fixing the weakest link first, focusing on one segment or job, using an advantage, or riding a wave of change. Read `./references/sources-of-power.md` when you need prompts for the policy, or when the draft policy relies on no advantage at all.

**The advantage is not a mission differentiator.** An advantage is an asymmetry in a specific situation: something you can do that the real alternatives cannot, which the customer values. It comes from the competitive analysis: Dunford's competitive alternatives (including doing nothing) and the unique attributes that survive "real" and "valued". The positioning statement in `gtm-strategy` is derived from that same evidence; the kernel never hands it a slogan to compress.

---

## What a Kernel Is Not

| It is not | Because | Where that belongs |
|---|---|---|
| A goal ("reach $1M ARR", "become the leader") | Says *how much*, not *how*; names no obstacle | A Key Result in `okr-authoring`, under the policy |
| A vision | An aspiration is necessary context but not a strategy | `vision-statement` |
| A mission sentence | Rules things out by wording, not by a diagnosed reason | The purpose line of `vision-statement` |
| A positioning statement | Speaks to the market, not to the team's choices | `gtm-strategy` |
| A roadmap or backlog | A list of work with no challenge above it is a dog's dinner | `roadmap-authoring`, which sequences the coherent actions |

---

## Scale

The kernel is **required at every profile** (`phase-requirements.json`), because a lean product needs a written challenge most of all: without one it goes from a vision straight to targets. Size changes; the three parts never do.

| Profile | Shape |
|---|---|
| **lean** | About 150 words: one short paragraph per part; 2–3 actions; rules-out list of 2; inputs are the vision and problem statement (plus a competitive analysis if one was written) |
| **standard** | One page: the crux plus the challenges set aside; policy with its named advantage; 3–5 actions with their reinforcement links; a review trigger |
| **enterprise** | A company kernel (one diagnosis, one policy) and, only where a product line faces a *different* crux, a line kernel that names the company kernel as its parent and contradicts nothing it rules out. Lines that share the company crux get actions, not their own kernel |

---

## How to Write One

1. **Read the inputs** above. Note the vision's protagonist, need and durable bet; the kernel works for that future, it does not restate it.
2. **List the challenges** (5–8 at standard, fewer at lean): what stops the protagonist's future arriving, including your own inertia and the alternatives customers use today.
3. **Pick the crux**: important *and* addressable. Write the diagnosis as a short judgement that ends on it, and record the challenges set aside.
4. **Choose the guiding policy.** Write the approach, the advantage or leverage it uses, and 2–4 tempting directions it rules out, each with its reason traced to the diagnosis.
5. **Design the coherent actions.** For each, state what it reinforces. If one capability caps the value of the rest (a chain-link constraint), its action goes first. Cut any action that reinforces nothing.
6. **Write the hand-off**: the proximate objectives the policy implies for the next cycle, as a short list for `okr-authoring` to turn into Objectives. Keep numbers out; targets belong in the Key Results.
7. **Treat it as a hypothesis.** Record the evidence that would show the diagnosis is wrong (a beta result, a lost-deal pattern, a churn reason) and revise the kernel *before* the next OKR cycle when it arrives.
8. **Validate** with `./resources/bad-strategy-checklist.md` before hand-off, then produce the artifact from `./templates/strategy-kernel-template.md` at `strategy/strategy-kernel.md`.

**Examples, simple to complex:**
- A lean internal tool, the whole kernel in about 150 words: read `./examples/01-lean-internal-tool.md`.
- A B2B SaaS product whose draft "strategy" was a list of growth goals, rewritten into a kernel: read `./examples/02-b2b-saas-goals-rewrite.md`.
- An enterprise multi-tenant, multi-region platform with three product lines, where only one line earns its own kernel: read `./examples/03-enterprise-platform-kernel.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All three parts | Diagnosis, guiding policy and coherent actions are each present and labelled | Any part missing, or merged into a paragraph of intent |
| Challenge named | The diagnosis names one crux, important and addressable | Restates the goal, lists data, or names an obstacle nobody can act on |
| Falsifiable | Evidence that would prove the diagnosis wrong is stated | Nothing could ever show it wrong |
| Policy decides | The rules-out list names real, tempting directions, each with its diagnosed reason | Rules nothing out, or "serve every segment" |
| Advantage named | The policy names the advantage or leverage it uses, from the competitive evidence | Relies on effort and enthusiasm alone |
| Coherent | Each action reinforces another or the policy; none works against another | A pile of separately sensible initiatives |
| No goals in disguise | Targets appear only as proximate objectives handed to the OKRs, without numbers | "Grow 3×", "be #1" stated as the strategy |
| Traceable | Names the vision it serves; enterprise line kernels name their parent | Free-standing |
| Size fits the profile | Matches the Scale table | A lean kernel padded to three pages |

---

## Anti-Patterns

Rumelt's four hallmarks of bad strategy, plus the ways this plugin's artifacts drift into them:

| Anti-pattern | Example | Why it fails |
|---|---|---|
| **Fluff** | "Leverage our innovative platform to deliver best-in-class value" | Delete the adjectives and no decision is left |
| **Failure to face the challenge** | A kernel with goals and actions but no named obstacle | Nobody can judge or improve a strategy that names no problem |
| **Goals as strategy** | "Strategy: 500 paying firms and 95% retention by Q4" | A goal says what you want, not how you overcome what stops you |
| **Dog's dinner** | Eight actions, one from every function, none linked | No priority and no common policy; entropy, not strategy |
| **Blue-sky objective** | "Become the trusted leader in data governance" handed to the OKRs | An end state with no feasible next step; not proximate |
| **The policy that rules nothing out** | "Serve SMB and enterprise, cloud and on-prem" | Without a "no" it guides nothing |
| **Mission in disguise** | "We catalog data for compliance teams so they can prove it" as the policy | A present-tense purpose line; it belongs in the vision |
| **Differentiator as slogan** | "Our differentiator is no data movement" with no alternative named | An advantage must be shown against the real alternatives (`competitive-analysis`) |
| **Frozen kernel** | Unchanged after the beta disproved the diagnosis | It is a hypothesis; revise it before the next OKR cycle |

Use the canonical terms from `glossary-management`: **Strategy Kernel**, **Diagnosis**, **Crux**, **Guiding Policy**, **Coherent Actions**, **Proximate Objective**.
