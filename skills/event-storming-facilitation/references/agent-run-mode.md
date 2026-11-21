# Agent-Run Mode

The procedure behind `SKILL.md` § 1. Decision D047-8 adds it because the domain-modeler runs Design with no domain expert present. It is this plugin's adaptation of Brandolini's method, not his endorsement: his method assumes the right people are in the room (`research/domain-driven-design/introducing-eventstorming-brandolini.md`, Caveats). Being honest about what it loses is the point.

## 1. Inputs

Read, and list in the artifact's `traces-to`:

- the vision, strategy kernel and positioning (what the business does and for whom);
- personas, stakeholder map, job stories and user stories (who acts and why);
- acceptance criteria and any domain stories (`domain-storytelling`), which often hold the unhappy paths;
- for an existing system: its documentation, data model and integrations.

## 2. Big Picture, agent-run

| Brandolini's phase | What the agent does |
|---|---|
| Chaotic exploration | Sweep the domain once per persona and stakeholder, writing every event that person would see or cause. One sweep per viewpoint stands in for many people writing at once |
| Enforce the timeline | Order, merge duplicates, list near-duplicates as possible distinct events. Mark pivotal events and swimlanes, with the reason for each |
| People and systems | Actors from the personas; external systems from the integrations named in the artifacts |
| Walkthrough and reverse narrative | Tell the story forwards, then backwards from the last event; every missing step becomes an event (labelled *assumed* if no artifact states it) or a hotspot |
| Problems and opportunities | Hotspots wherever artifacts disagree, are silent, or a step has no owner; opportunities where an artifact mentions a pain with no feature |
| Pick the problem | Rank the hotspots and give the reason for the order (risk to the Core, number of flows affected, how much the model depends on the answer) |

**Ask for the unhappy paths every time:** what if the payment fails, the person doesn't turn up, the stock runs out, nobody approves in time, the data is wrong?

## 3. Citing and labelling

Every card carries a source:

| Source label | Means |
|---|---|
| `ideate/job-stories.md` (any artifact path) | An artifact states it |
| *assumed* | Inferred by the agent; no artifact states it |
| `session YYYY-MM-DD` | Confirmed in a human session |

An event that no artifact supports is never presented as a fact. The transcript's tables have a Source column for this.

## 4. Hotspots as open questions

Each hotspot becomes a question for the product owner, with why it matters and the assumption used meanwhile:

| # | Hotspot | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|---|
| H1 | Who cancels a late order? | Can the customer cancel after the truck starts cooking, and is anything refunded? | Decides whether `OrderCancelled` can follow `CookingStarted` | No cancellation after cooking starts |

They are presented at the domain-modeler's review gate. None is marked resolved without an answer. Each answer replaces its assumption, and the cards it touches are updated.

## 5. What it can't claim

- Shared understanding: nobody else has seen the wall.
- Resolved disagreements: it can only find where the artifacts disagree.
- Discovery of what no document contains: the tacit knowledge a workshop exists to surface.

So the reply at the gate says plainly that the wall is a hypothesis built from documents, how many cards are *assumed*, and which hotspots most need an answer. A human session stays optional. If the product owner holds one, its results replace the assumptions they confirm (`./facilitation-guide.md` § 6).
