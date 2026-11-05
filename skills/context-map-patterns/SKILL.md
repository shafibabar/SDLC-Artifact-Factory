---
name: context-map-patterns
description: >
  Choose the relationship pattern for each line on a Context Map, and record
  why: Partnership, Shared Kernel, Customer/Supplier, Conformist,
  Anticorruption Layer, Open Host Service with Published Language, Separate
  Ways, and Big Ball of Mud as a boundary around legacy. Covers choosing in a
  fixed order (who has to cooperate, whether the upstream model is good
  enough to adopt, how many consumers), Conformist versus Anticorruption
  Layer as a trade-off rather than "always translate", the pass-through
  translator that is really Conformist, why Partnership needs two teams, a
  small enumerated Shared Kernel versus a shared grab-bag, which lines need
  consumer-driven contract tests, and how the reasoning changes when one
  agent builds every internal context. Use when picking or reviewing the
  pattern on a line between two Bounded Contexts or a context and an
  external system. Finding and drawing the contexts is
  bounded-context-mapping; building a translator in code is
  integration-design. Used by domain-modeler and enterprise-architect.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, context-map, relationship-patterns, anticorruption-layer, conformist, open-host-service, shared-kernel, contract-tests]
produces: context-map
domain: domain-modeling
status: stable
related: [bounded-context-mapping, integration-design, go-contract-test, event-schema-design, api-contract-design, subdomain-distillation, ubiquitous-language]
sources:
  - research/domain-driven-design/strategic-design-supplement.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/building-microservices-newman.md
  - research/testing/contract-testing-in-action-cruz-prescott.md
---

# Context Map Patterns

## Purpose

Each line on a Context Map needs one relationship pattern: it says who adapts to whom and what each side owes the other. `bounded-context-mapping` finds the contexts and draws the lines (D047-5); this skill chooses the pattern on each line and writes the reason into the same artifact, the Relationships table of `design/context-map.md`. How a translator is built is `integration-design`; how the event schemas are versioned is `event-schema-design`.

## 1. Choose in a Fixed Order

For each line, ask three questions in this order (Khononov's grouping, applied as a sequence in `research/domain-driven-design/strategic-design-supplement.md`):

1. **Who has to cooperate?** Khononov's three groups:
   - **Cooperation:** both sides plan changes together → *Partnership* or *Shared Kernel*.
   - **Customer–supplier:** one side is upstream, and the choice depends on where the power sits → *Customer/Supplier*, *Conformist*, *Anticorruption Layer*, *Open Host Service*.
   - **No integration** → *Separate Ways*.
2. **Is the upstream model good enough to adopt?** If yes, *Conformist* is a legitimate, cheap choice. If not, *Anticorruption Layer*.
3. **How many consumers?** Many → *Open Host Service* with a *Published Language*, one public protocol instead of one translator per consumer.

**When one agent builds every internal context,** the team axis collapses for internal lines: there is no second team to negotiate with, so the choice rests on model quality and how often things change. The power reasoning still applies in full to external systems and vendors. Detailed questions and signals: `./references/selection-guide.md`.

## 2. The Patterns

| Pattern | Means | Fits when | Source |
|---|---|---|---|
| **Shared Kernel** | Two contexts share a small, explicit part of the model, changed only by agreement, with shared tests | Duplicating costs more than coordinating; natural when *one* team owns both contexts | Evans 2003 |
| **Customer/Supplier** | Upstream commits to the downstream's needs | Two parties who can negotiate; the downstream's acceptance tests run in the upstream's suite | Evans 2003 |
| **Conformist** | Downstream takes the upstream model as it is | The upstream model is good enough and the downstream isn't Core; the upstream won't accommodate | Evans 2003 |
| **Anticorruption Layer** | Downstream translates the upstream model into its own language | The downstream is Core, or the upstream is messy or legacy, or its contract churns | Evans 2003 |
| **Open Host Service** | Upstream publishes one protocol for all consumers | Several consumers; separates the internal model from the public one | Evans 2003 |
| **Published Language** | A documented shared exchange language, often with OHS | The protocol's schema (Khononov folds it into OHS) | Evans 2003 |
| **Separate Ways** | No integration | Integrating costs more than it returns; or a Generic capability each side can get on its own | Evans 2003 |
| **Partnership** | Two teams whose contexts succeed or fail together plan changes jointly | Two teams that communicate well and work in step; poor for one team, which has no second party | Vernon (IDDD) and the later *DDD Reference*, not the 2003 book |
| **Big Ball of Mud** | A region with no coherent model | Legacy: draw a boundary round it, don't extend it, reach it through an Anticorruption Layer | Foote and Yoder's term, added to the map vocabulary by Vernon and the *DDD Reference* |

Each pattern in depth, what it obliges each side to, and when not to use it: `./references/pattern-catalogue.md`.

## 3. The Trade-offs That Matter Most

- **Conformist or Anticorruption Layer.** Not "always translate an external API". Conformist when the upstream model is good and the downstream isn't Core. A translation layer when the downstream is Core, the upstream is messy, or the contract churns. Test it with the language-collision check: does adopting the upstream's terms force a different meaning, a concept the downstream doesn't have, or a broken invariant? (`./references/selection-guide.md` § 3).
- **A translator that copies fields one-to-one is Conformist in disguise.** It costs a layer and protects nothing. Either translate into the downstream's own language or call it Conformist.
- **Partnership needs two teams.** With one team (including one agent) there is no second party to plan with; use a Shared Kernel if the model really must be shared. A time-box on Partnership is house guidance, not the books'.
- **A Shared Kernel is small and listed.** Name its members, give it shared tests, and weigh duplication against coordination. A growing shared `common` model is coupling with a pattern's name.

## 4. What Each Line Obliges: Contracts

| Pattern | Contract obligation |
|---|---|
| Customer/Supplier | **Consumer-driven contract tests:** the downstream writes them, and they run in the upstream's pipeline (Evans's downstream acceptance tests; Newman; Cruz and Prescott) |
| Open Host Service | **Versioned protocol discipline** for every consumer: versioning, deprecation, change notice (`event-schema-design`, `api-contract-design`). Contract tests only for *named* consumers who have agreed to them |
| Anticorruption Layer to a vendor | Integration tests against the vendor's API; a vendor won't run your tests |
| Shared Kernel | Shared tests both sides run on every change |
| Conformist, Separate Ways | None beyond noting the upstream's version and release pace (Conformist) |

**How strict each contract is, decided per line, separately from the pattern** (Ford, *Software Architecture: The Hard Parts*): a *strict* contract (a typed schema) catches errors earlier but couples producer and consumer more tightly; a *loose* one (tolerant readers that ignore what they don't use) lets each side evolve on its own but fails later. Passing a large shared structure when a consumer reads a few fields is *stamp coupling*: that consumer is now coupled to every field. Two lines with the same pattern can carry very different coupling risk.

## Producing the Rationale

Copy `./resources/pattern-checklist.md` and tick it as you go.

1. **Read** `design/context-map.md` (the lines `bounded-context-mapping` drew), the subdomain classification (which side is Core) and the language documents (for the collision check).
2. **For each line, answer the three questions in § 1 in order,** and show each answer in the reason (who cooperates → is the upstream model good enough → how many consumers), even when the consumer count is what decides it. Then check § 3's trade-offs.
3. **Write** the Relationships table: Upstream, Downstream, Pattern, Reason (which must name at least one pattern considered and rejected, and why) and Contract: what the pattern obliges **and** how strict the contract is (§ 4). Agent-run: a choice resting on an assumption about the upstream (its stability, its owner's willingness) is marked *assumed*, with an open question for the product owner.
4. **Validate, then loop.** Run `./scripts/validate-pattern-rationale.sh design/context-map.md`. Fix every FAIL and run it again until it exits clean, then go through the checklist items the script can't judge.
5. **Present** with the map at the review gate: each pattern and its reason, and for every request you declined, its reason in full (§ Gotchas).

Worked cases, simplest to hardest: `./examples/01-lean-conformist-to-payments.md` (Conformist to a good vendor model), `./examples/02-standard-supplier-to-open-host.md` (Customer/Supplier with contract tests, moving to Open Host Service at the fourth consumer), `./examples/03-enterprise-pass-through-and-common.md` (a pass-through translator diagnosed, a `common` "kernel" dissolved).

## Gotchas

Each trap comes with the reason to give in full.

- **"It's an external API, so it's an Anticorruption Layer, always."** *Reason:* Conformist is a legitimate, cheap choice when the upstream model is good enough and the downstream isn't Core (Evans); a translation layer is for a Core downstream, a messy or legacy upstream, or a churning contract (Khononov). *Instead:* run the collision check and state which condition applies.
- **"Our translator maps every field one-to-one; that's our ACL."** *Reason:* a translation that renames nothing protects nothing; it is Conformist with extra code. *Instead:* translate into the downstream's own language where meanings differ, or name the line Conformist and delete the layer.
- **"We're one team; let's call it Partnership."** *Reason:* Partnership is two teams planning together because their contexts succeed or fail together; one team (or one agent) has no second party. More generally, with one owner the team-based reasoning behind the patterns falls away for internal lines, so the choice rests on the models: how good and stable each is, how often it changes, and what duplication would cost. Customer/Supplier's negotiated commitments and consumer-driven contract tests assume two parties too. *Instead:* a small, listed Shared Kernel if part of the model must really be shared; otherwise make one side upstream and have the downstream conform (good model, not Core) or translate (Core, or meanings differ), and coordinate tight runtime coupling with events and a clear owner for each rule.
- **"Everything shared goes in `common`; that's our Shared Kernel."** *Reason:* a Shared Kernel is small, explicitly listed and changed only by agreement with shared tests; a grab-bag that grows is coupling under a pattern's name, and it forces one meaning on words that differ by context. *Instead:* for each concept, weigh the cost of duplicating it in each context against the cost of coordinating every change to a shared copy; keep shared only what wins that test (usually a few stable value formats), list it, give it shared tests, and move the rest back into each context's own model.
- **"Every consumer of our Open Host Service needs consumer-driven contracts."** *Reason:* an OHS owes all consumers versioned protocol discipline; contract tests are for named consumers who agreed to them, and Customer/Supplier is where they are required. *Instead:* version and deprecate the protocol; add contract tests for the named consumers.
- **"Pick whatever pattern we used last time."** *Reason:* the pattern follows from who must cooperate, whether the upstream model is good enough, and how many consumers there are, in that order. *Instead:* answer the three questions per line and write the reason with the rejected alternative.
- **Treating the pattern as the whole contract decision.** *Reason:* how strict each contract is (typed schema or tolerant reader, and whether consumers receive only the fields they read) is a separate choice (Ford); two lines with the same pattern can carry very different coupling risk. *Instead:* state the strictness per line in the Contract column, and avoid stamp coupling.
- **Writing translator code here.** *Reason:* design skills are stack-neutral (D047-10). *Instead:* name the translation (what maps to what); the code is `integration-design` and the `go-*` skills.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Pattern archaeology** | Names whatever integration exists; documents accidents, not decisions | Choose by § 1, then build to match |
| **Union-of-wishes OHS** | Every consumer's special request added; it can never shed a field | Design for the main consumers; add only for a named, committed consumer |
| **Building against a Big Ball of Mud directly** | Its instability spreads into new contexts | One translation layer as the single entry point |
| **Separate Ways by assumption** | Duplication and drift if a real dependency existed | Confirm from the Event Storming wall that no event is needed across the line |
| **A reason with no rejected alternative** | Can't be reviewed: nothing shows what was weighed | Name the pattern considered and why it lost |
