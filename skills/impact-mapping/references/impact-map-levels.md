# Impact Map Levels — Depth Reference

Self-contained. The four levels of an impact map (Gojko Adzic, *Impact Mapping*) and the opportunity link between HOW and WHAT (Teresa Torres, *Continuous Discovery Habits*): the questions to ask at each, the distinctions that make the map work, and how deliverables are generated. Cross-read against Cagan's outcome-over-output framing (*Inspired*), Olsen's problem-space / solution-space discipline (*The Lean Product Playbook*) and Bier's divergent-generation techniques (*Unleash Your Creativity with AI*). Selecting the path, typing assumptions and re-planning are in `selected-path-and-replanning.md` beside this file.

---

## The map is a directed chain, not five lists

The goal sits at the root. Actors branch off the goal, impacts off each actor, the opportunity behind each impact, and deliverables off each impact. Read **down** (WHY → WHO → HOW → WHAT) to *build* the map; read **up** (WHAT → HOW → WHO → WHY) to *defend scope*: every leaf must trace to the goal along one path, or it does not belong.

```
                        ┌── HOW impact ── OPP ──┬── WHAT option
        ┌── WHO actor ──┤                       └── WHAT option
        │               └── HOW impact ── —  ──── WHAT option
WHY ────┤
Goal    │               ┌── HOW impact ── OPP ──── WHAT option
        └── WHO blocker ┤  (remove the obstruction)
                        └── HOW impact (prevent) ─ WHAT option
```

A flat feature list cannot answer "why is this here?". The map answers it structurally: this deliverable exists to cause *that* behaviour change in *that* actor, because of *that* customer need, which moves *this* goal.

---

## Level 1 — WHY: the Goal

**Question:** *Why are we doing this? What measurable change are we trying to create?*

- **An outcome, not an output.** A change someone *outside the team* produces through their behaviour. "Launch the reminders feature" is an output; the team can do it alone. "No-show rate 12% → 7%" is an outcome.
- **A problem, not a solution.** "Build a mobile app" is a solution; the goal is the business change the app was supposed to bring.
- **Measured in fields, not prose.** Adzic borrows the measurement discipline from Tom Gilb: say *what* is measured (the scale or metric), *how* it is measured (the meter), the current value (baseline), the target and the deadline, plus an optional **constraint**, a level something must not fall below. These are the same fields `okr-authoring` requires on every Key Result, so the map copies them field by field from the opportunity solution tree's root and the linked KR. A field the KR lacks says "not set in KR" and goes back to `okr-authoring`; the map never invents a number.
- **A product outcome.** The opportunity solution tree has already classified the KR (Torres): a **business outcome** (revenue, retention) is too far away to steer by, and a **traction metric** (use of one feature) decides the solution in advance. The map's goal is the tree's **desired outcome**, a product outcome. With no tree, classify first with `opportunity-solution-tree`.
- **One goal per map.** An "and" in the goal means two maps.

**Litmus test:** *could the team achieve this entirely on its own, with nobody outside it changing what they do?* If yes, it is a deliverable posing as a goal.

---

## Level 2 — WHO: the Actors

**Questions, in order:**
1. Who can **produce** the desired effect?
2. Who can **obstruct** it?
3. Who are the **users** of the product?
4. Who will be **affected** by it?

Record the answers before thinking about any feature. Actors can be individuals, roles or groups, as long as their behaviour can be observed.

| Actor type | Definition | Example |
|---|---|---|
| **Primary** | Their behaviour directly produces the goal; often the end user | A patient with a booking weeks ahead; a carrier's dispatcher |
| **Secondary** | Supports the primary actor's behaviour | A clinic's front desk; a driver updating availability |
| **Off-stage** | Decisions affect the goal, but they do not use the product | A sponsor, an auditor, a regulator, procurement |
| **Blocker** | Can *prevent* the goal by withholding an action | A practitioner who keeps a paper diary; a works council that can veto location sharing |

**The blocker discipline.** Obstructing actors matter as much as helpful ones, because removing an obstacle is often the cheapest path to the goal. Record at least one, or state why none exists. A blocker's impact is phrased as removing the obstruction: "enters every booking in the system the same day instead of in the paper diary".

**The affected question** finds side-effect actors: people the change touches who never asked for it (a patient's family who reads a reminder text; a driver whose location is shared). They are where **ethical** assumptions come from.

**Specificity test.** Finish the sentence "we would know this actor changed because we would see them ___". "The customer", "IT", "the market" cannot finish it. A persona from `user-persona` usually can. In enterprise maps, use one **shared actor register** across all maps, so the same dispatcher is not a primary actor described one way in one map and another way in the next.

---

## Level 3 — HOW: the Impacts (the crux)

**Question:** *How should this actor's behaviour change for the goal to be reached?*

This is the level that makes an impact map an impact map, and the one teams skip. An impact is a **change in an actor's behaviour**: never a feature, never an activity of the team, never the system's behaviour.

- **Outcomes, not outputs.** "The patient confirms or cancels ahead instead of not turning up" is the actor's behaviour. "Send reminder texts" is the team's; it belongs in WHAT.
- **Behaviours, not feature usage.** "The dispatcher uses the availability screen" names a deliverable. The impact is what it lets them do differently: "accepts a tender within the hour without phoning drivers first". A correctly phrased impact could be caused by several different deliverables.
- **The actor's, not the product's.** "The system sends alerts" is not an impact; "the front desk refills a cancelled slot the same day" is.
- **Zone of control vs sphere of influence** (Adzic and Evans, *Fifty Quick Ideas to Improve Your User Stories*): deliverables sit in the team's zone of control (it ships them); impacts sit in its sphere of influence (it can make them likelier, not guarantee them); the wider world lies beyond both. That is why an impact can never be a deliverable, and why every impact needs a signal.

**Phrasing formula:** *[Actor] [starts / stops / does more / does less / does faster / does differently] [observable behaviour] instead of [current behaviour].* Naming the current behaviour forces a real change.

**Prevent impacts.** Impacts can be negative: behaviour that hurts the goal and should stop or not start. Not only blockers have them: a primary actor whose current behaviour works against the goal does too ("stops accepting a load and cancelling it an hour later").

**Signal.** Each impact says how it would be observed: "we would see it in the share of 72 h confirm requests answered", "in acceptance timestamps". An impact with no signal cannot be tested when its deliverable ships.

| Bad (feature / activity) | Good (behaviour change, with signal) |
|---|---|
| The clinic owner uses the reminders page | The patient replies to confirm or cancel instead of not turning up. *Signal: reply rate; no-show rate* |
| Front desk gets notifications | The front desk offers a released slot to the waitlist the same day. *Signal: share of released slots refilled* |
| Dispatcher uses the app | The dispatcher accepts within the hour without phoning drivers. *Signal: median time to accept* |
| System shares location | The driver keeps availability current without being chased. *Signal: share of drivers with an entry under 24 h old* |

**Where impacts come from.** `jtbd-analysis` job stories describe what an actor is trying to get done in their real context, the behaviour an impact should move. Olsen's rewrite test applies: an impact in the product's UI vocabulary ("uses the dashboard") is a solution-space smell; rewrite it in the actor's work-context language until more than one deliverable could satisfy it.

---

## Between HOW and WHAT — the Opportunity

**Question:** *Why doesn't the actor already behave that way?*

Torres's opportunity solution tree holds the answer: customer needs, pain points and desires, in the customer's voice, each answerable by more than one solution. The map's Opportunity column cites the tree's OPP-ID behind each impact:

- The **selected path** cites the tree's **target opportunity**, so the impact the team bets on is explained by the need the user chose to work on.
- Other impacts cite whichever tree opportunity explains them, or "— not on tree". An impact with no opportunity behind it is not wrong, but it is unevidenced: a candidate for the next discovery cycle's interviews.
- Blocker and off-stage actors are rarely the tree's customers; their rows usually say "— not on tree" with a short reason ("internal practice habit").

An opportunity is not an impact: the opportunity is the need ("patients forget appointments booked weeks ahead"); the impact is the behaviour change it unlocks ("confirms or cancels ahead"). Keeping both on the row is what lets a deliverable answer the need rather than restate the behaviour.

---

## Level 4 — WHAT: the Deliverables (options)

**Question:** *What could we, the organisation, do to cause this behaviour change?*

Adzic is clear that WHAT holds *possible* deliverables. They are **options, and many are expected never to be built**. It is the *most uncertain* level: the goal came from strategy, the actors and impacts from evidence, but each deliverable is a guess about what will cause a behaviour change. This is the same claim Cagan makes about value, usability, feasibility and viability: assumptions until tested.

**Not only software.** Training, a process change, a message template, a policy, a partnership, a manual workaround or content can each cause an impact more cheaply than a feature. Ask first: *what is the cheapest thing, not necessarily software, that might cause this?*

**Generating candidates, as an agent.** Bier's point is that the first few ideas a model (or a person) produces are the most average, and a second attempt anchors on the first unless a constraint breaks it. So:

1. **Where the tree already compared solutions** (the impact explained by the target opportunity), its carried-forward solutions are the candidates, with their assumptions and tests. Do not re-generate them.
2. **Elsewhere**, generate two to three times as many candidates as will be kept. Pass one: unconstrained. Pass two: under a deliberate constraint ("no new code", "one week", "assume the opposite of pass one", "what would a sceptical clinic owner do instead?"). Then narrow.
3. **At least one non-software option per impact** on or near the selected path.

Three consequences are the payoff of the technique:
1. **Several deliverables can serve one impact; you do not build them all.** Pick the cheapest one or two likely to cause the change; the rest stay as options.
2. **A deliverable that traces to no impact is cut**, with no further debate.
3. **Stop when the impact is achieved.** Remaining options under it stay on the map, not in the plan.

**Keep it small.** Detail deliverables only under impacts the team might choose next; leave deeper branches as one-line placeholders.

---

## Failure modes at each level

| Level | Failure mode | Fix |
|---|---|---|
| WHY | Goal is an output or unmeasurable | Restate as a metric actors' behaviour produces, in fields |
| WHY | Revenue or a feature's usage as the goal | Use the tree's product outcome (`opportunity-solution-tree`) |
| WHY | Invented baseline or target | Copy from the KR; "not set in KR" goes back to `okr-authoring` |
| WHO | "The customer", "IT" | A specific persona or role with observable behaviour |
| WHO | Only supporters | Ask "who can obstruct this?"; add a blocker or say why none exists |
| WHO | Same actor described twice across enterprise maps | One shared actor register |
| HOW | Names a feature ("uses the dashboard") | Rewrite as the behaviour it enables, in work-context language |
| HOW | Describes the system | Reattribute to an actor |
| HOW | No signal | Add "we would see it in ___" |
| Opportunity | Selected impact has no tree opportunity | Cite the target opportunity, or question the path |
| WHAT | Features only | Add the cheapest non-software option first |
| WHAT | One candidate per impact | Two passes, the second under a constraint |
| WHAT | Deliverable traces to no impact | Cut it |
| whole map | Drawn from existing requirements or a backlog | Discard the list; rebuild from the goal |
| whole map | Hundreds of nodes | Keep detail only where the next choice is |
