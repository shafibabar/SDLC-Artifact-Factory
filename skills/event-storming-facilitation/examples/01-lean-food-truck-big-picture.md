# Example 1 — Lean: Big Picture only, agent-run, boundary candidates from pivotal events (simplest case)

Self-contained. **Curbside** lets customers pre-order from one food truck, Mo's Dumplings, and pick up at a stated time. **Lean** profile, so the Big Picture is the only format. Nobody else is available, so the domain-modeler runs it agent-run from `strategy/vision.md`, `ideate/personas.md` (Mo, the owner; Priya, a lunchtime customer) and `ideate/job-stories.md` (J1–J5).

## Input

> **User:** "We're lean, so just list the events and move on. No need for boundaries or any of that."

## Working it

- **Sweeps, one per persona.** Priya: browse today's menu, place a pre-order, pay, get a ready text, collect. Mo: publish today's menu and location, set a pickup-slot limit, start cooking, mark ready, close the day.
- **Unhappy paths asked for:** sold out after ordering; Priya doesn't turn up; the truck moves location; payment fails. Only "sold out" appears in an artifact (J4). The rest are *assumed*.
- **Reverse narrative** from `DayClosed` backwards found a missing event: nothing records what happens to uncollected orders → `OrderAbandoned` (*assumed*) and a hotspot.
- **Pivotal events:** `MenuPublished` (the day opens for orders) and `CookingStarted` (orders stop being changeable). Two swimlanes: ordering and cooking.
- **Boundary hints, even at lean.** Before `CookingStarted` the words are Priya's (order, slot, pay). After it they are Mo's (batch, ticket, ready). "Order" to Priya is what she bought; to Mo, a ticket in a cooking batch. The actor changes too. That gives two **candidates**: Ordering and Kitchen.

## Output — the reply, and `artifacts/curbside/design/event-storming/big-picture.md`

> Here's the Big Picture. I built it from your vision, personas and job stories, with no one else in the room, so treat it as a draft: 4 of the 14 events are my assumptions, and they're marked. Lean still needs boundary candidates, because this wall is the only place they come from. There look to be two: ordering, in the customer's words, and the kitchen, in Mo's. That's a hint for the next step, not a decision. Three questions for you, most important first: what happens to an order nobody collects; can a customer cancel once cooking has started; and does a payment failure lose the slot? Next comes the subdomain classification, a short table at lean.

```markdown
---
name: event-storming-big-picture
product: curbside
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-04-14
summary: Curbside Big Picture, agent-run; 14 events, pivotal MenuPublished and CookingStarted; two boundary candidates (Ordering, Kitchen); top hotspot uncollected orders.
profile: lean
mode: agent-run
traces-to: [strategy/vision.md, ideate/personas.md, ideate/job-stories.md]
---

# Event Storming Big Picture: Curbside

**How this wall was built:** agent-run from the artifacts in `traces-to`; a hypothesis, 4 of 14 events *assumed*.

## Timeline

| # | Domain Event | Actor or system | Swimlane | Source |
|---|---|---|---|---|
| 1 | **MenuPublished** | Mo | Ordering | job-stories J1 |
| 2 | PickupSlotsOpened | Mo | Ordering | job-stories J1 |
| 3 | PreorderPlaced | Priya | Ordering | job-stories J2 |
| 4 | PaymentTaken | Payment Provider | Ordering | vision |
| 5 | PaymentFailed | Payment Provider | Ordering | *assumed* |
| 6 | ItemSoldOut | Mo | Ordering | job-stories J4 |
| 7 | PreorderRefunded | Payment Provider | Ordering | job-stories J4 |
| 8 | **CookingStarted** | Mo | Kitchen | personas (Mo) |
| 9 | OrderReady | Mo | Kitchen | job-stories J3 |
| 10 | ReadyTextSent | Messaging service | Kitchen | job-stories J3 |
| 11 | OrderCollected | Priya | Kitchen | job-stories J5 |
| 12 | OrderAbandoned | — | Kitchen | *assumed* |
| 13 | TruckRelocated | Mo | Ordering | *assumed* |
| 14 | DayClosed | Mo | Kitchen | *assumed* |

## Pivotal Events

| Event | Why it marks a change of phase |
|---|---|
| MenuPublished | The day opens for orders |
| CookingStarted | Orders stop being changeable; the kitchen takes over |

## Bounded Context Candidates (hints, not decisions)

| Candidate | Spans events | Evidence |
|---|---|---|
| Ordering | 1–7, 13 | Before CookingStarted; actor Priya; "order" = what she bought |
| Kitchen | 8–12, 14 | After CookingStarted; actor Mo; "order" = a ticket in a cooking batch |

## Hotspots (ranked)

| Rank | ID | Hotspot | Kind | Goes to | Question for the product owner | Assumed meanwhile |
|---|---|---|---|---|---|---|
| 1 | H1 | Uncollected orders | Rule | Product owner | What happens to an order nobody collects by close? | Kept until DayClosed, no refund |
| 2 | H2 | Cancel after cooking | Rule | Product owner | Can a customer cancel once cooking has started? | No |
| 3 | H3 | Failed payment and the slot | Rule | Product owner | Does a failed payment release the pickup slot? | Released after 5 minutes |

## Words Found

order (two meanings, see candidates), pickup slot, ticket, batch, ready text

## Next

Lean: no Process Modelling. Subdomain classification next (`subdomain-distillation`).
```

## Why this is right

- Lean still produced boundary candidates, from the pivotal event, the actor change and the word "order".
- Every event cites its artifact; the four inferred ones say *assumed*, and the reply says how many.
- The hotspots are ranked questions for the product owner, not guesses marked resolved. No aggregates are named.
