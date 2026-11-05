# Selection Guide

The questions behind `SKILL.md` § 1 and § 3, asked in order for each line on the map, plus the language-collision check and the signals that change the answer. Grounded in Khononov (*Learning Domain-Driven Design*, Ch. 4) and Evans (*Domain-Driven Design*, Ch. 14), as summarised in `research/domain-driven-design/strategic-design-supplement.md`. Examples use several products.

## 1. Question one: who has to cooperate?

| Situation | Group | Candidates |
|---|---|---|
| Two teams whose contexts succeed or fail together, who plan in step | Cooperation | Partnership |
| One team owns both contexts, and they genuinely share part of the model | Cooperation | Shared Kernel |
| One side is clearly upstream | Customer–supplier | Customer/Supplier, Conformist, Anticorruption Layer, Open Host Service |
| Neither needs the other | None | Separate Ways |
| The other side is a legacy region with no coherent model | Customer–supplier, with a boundary round the mud | Anticorruption Layer into a Big Ball of Mud |

**One agent, many contexts.** In an agent-built product the internal contexts have one modeller and one owner, so there is no second team for Partnership or for negotiating Customer/Supplier terms. For internal lines, decide on model quality and rate of change: Shared Kernel for a small genuinely shared part, otherwise the customer–supplier patterns by questions two and three. For **external** lines (vendors, partners, another company's system) the power reasoning applies in full.

## 2. Question two: is the upstream model good enough to adopt?

Inside the customer–supplier group:

| The downstream is… | The upstream is… | Choose |
|---|---|---|
| Not Core | Clean, stable, and passes the collision check (§ 3) | **Conformist** |
| Core | Anything | **Anticorruption Layer** |
| Any | Messy, legacy, or its contract churns | **Anticorruption Layer** |
| Any | Willing to commit to the downstream's needs | **Customer/Supplier**, with consumer-driven contract tests |

The downstream's type comes from `subdomain-classification`.

## 3. The language-collision check

For each upstream term the downstream would use:

1. Does the downstream's language give it a **different meaning**?
2. Would adopting it force a **concept the downstream doesn't have**?
3. Would adopting it **break one of the downstream's invariants**?

Any "yes" means translate (Anticorruption Layer). All "no" means Conformist is safe, and a translation layer would be cost without benefit.

**Example.** A booking app for rowing clubs reads boat availability from a club-management vendor. The vendor's `Resource` means any bookable thing (a boat, a room, a coach). The app's `Boat` has a crew size and a rigging that the vendor doesn't model, and the app's rule "a coxed four needs five people" depends on it. Question 2 is yes, so translate. The vendor's `Member` means the same as the app's `Member`; for members alone, Conformist would be fine.

**The pass-through test.** If the "translation" renames nothing and changes no meaning, the line is Conformist. Name it so, and remove the layer.

## 4. Question three: how many consumers?

| Consumers | Choose | Contracts |
|---|---|---|
| One or a few, each negotiating | Customer/Supplier | Consumer-driven contract tests, per consumer |
| Several, or more expected | Open Host Service with a Published Language | Versioned protocol discipline for all; contract tests for named consumers who agreed |

Moving from private contracts to one public protocol is a judgement about whether per-consumer negotiation is still manageable; there's no fixed threshold. Write the trigger into the reason ("move to Open Host Service when a fourth consumer signs").

## 5. Signals that change the answer

| Signal | Effect |
|---|---|
| The upstream refuses contract tests, or has broken compatibility before | Treat it as not accommodating: Conformist or Anticorruption Layer, by question two |
| The upstream is a regulated vendor with a fixed API | No negotiation possible: Conformist or Anticorruption Layer, by the collision check |
| The upstream is being retired | Anticorruption Layer, with the retirement plan; don't build a Conformist dependency on it |
| Two internal contexts with one owner keep needing the same small concept | Shared Kernel, listed, with shared tests |
| A supposed dependency shows no event crossing the line on the Event Storming wall | Separate Ways may be right; confirm first |

## 6. Writing the reason

Each row of the Relationships table states:

- the pattern;
- **why**, in terms of § 1–4 (who cooperates, the model quality and the downstream's type, the consumer count);
- **the pattern considered and rejected**, and why it lost;
- **the contract** the pattern obliges (`SKILL.md` § 4), and **how strict** it is: a typed schema or tolerant readers, and whether each consumer receives only what it reads (no stamp coupling);
- in agent-run mode, *assumed* on any part resting on a guess about the upstream, with an open question.
