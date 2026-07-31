# Impact Map Levels — Depth Reference

The four levels of an Impact Map (Gojko Adzic, *Impact Mapping*) in full: the exact
questions to ask at each, the distinction that makes the map work (impacts are actor
behavior changes / outcomes; deliverables are hypotheses that may be wrong), and how
to prune deliverables down to an MVP cut. This reference is grounded in Adzic's
technique and cross-read against Cagan's outcome-over-output framing (*Inspired*) and
Olsen's problem-space/solution-space discipline (*The Lean Product Playbook*).

---

## The map is a directed chain, not four independent lists

An Impact Map is a mind-map with the **goal at the centre (or root)** and three rings
of branches: actors branch off the goal, impacts branch off each actor, deliverables
branch off each impact. The direction is what matters. Reading **down** (WHY → WHO →
HOW → WHAT) is how you *build* the map — you are decomposing a goal into the concrete
things that might move it. Reading **up** (WHAT → HOW → WHO → WHY) is how you *defend
scope* — every leaf deliverable must trace all the way back to the goal, or it does
not belong on the map.

This bidirectional traceability is the entire value. A flat feature list cannot answer
"why is this feature here?"; an impact map answers it structurally — "this deliverable
exists to cause *that* behavior change in *that* actor, which moves *this* goal."

```
                        ┌── HOW impact ──┬── WHAT deliverable
        ┌── WHO actor ──┤                └── WHAT deliverable
        │               └── HOW impact ───── WHAT deliverable
WHY ────┤
Goal    │               ┌── HOW impact ───── WHAT deliverable
        └── WHO actor ──┤  (blocker)
                        └── HOW impact ───── WHAT deliverable
```

---

## Level 1 — WHY: the Goal

**Question asked:** *Why are we doing this? What measurable outcome are we trying to
create?*

The goal is the single most important element and the most commonly botched. It must be:

- **An outcome, not an output.** An outcome is a change in the world that someone
  *outside the delivery team* produces through their behavior. "Ship the compliance
  dashboard" is an output — it is entirely within the team's control and requires no
  one else to do anything. "80% of trial teams discover their first compliance gap
  within 30 minutes of connecting a source" is an outcome.
- **Measurable.** A number with a target, or a binary condition. "Improve the product"
  fails; it can never be shown true or false.
- **Sourced from an OKR Key Result.** Each Key Result becomes its own goal, its own
  map. Do not put two Key Results on one map — the actor and impact analysis for each
  is different, and merging them hides which behavior serves which result.

**The single-goal rule.** One map, one goal. If you find yourself writing "and" in the
goal statement, you have two maps.

**Litmus test for a goal:** ask "could the team achieve this entirely on its own,
without anyone outside the team changing what they do?" If yes, it is a deliverable
masquerading as a goal (Cagan's feature-factory tell), and the real goal is the
behavior change you were *hoping* the deliverable would cause.

---

## Level 2 — WHO: the Actors

**Question asked:** *Who can produce the desired outcome? Who can obstruct it?*

Actors are people or groups whose behavior can *cause or block* the goal. List them
before thinking about any feature. Four types are worth distinguishing:

| Actor type | Definition | Example (this repo's product) |
|---|---|---|
| **Primary** | Behavior directly produces the goal; usually the end user | Data Steward, Compliance Officer |
| **Secondary** | Supports the primary actor's behavior | Customer IT / onboarding lead |
| **Off-stage** | Decisions affect the goal but they don't use the product | CISO (sponsor), auditor, procurement |
| **Blocker** | Can *prevent* the goal by withholding an action | IT Security (deployment approval) |

**The blocker discipline.** Adzic is explicit that identifying who can *block* the goal
is as important as identifying who can cause it. A map with only supporters has skipped
half the analysis. For a blocker, the impact (next level) is phrased as *removing* the
blocking behavior — "IT Security approves the deployment request without escalating it."

**Actor specificity test.** An actor must be concrete enough to have *observable
behavior*. "The customer", "IT", "the market" fail — none of them can be watched doing
anything. The Data Steward *can* be observed connecting a storage source. If you cannot
finish the sentence "we would know this actor changed because we'd see them ___", the
actor is too vague. This is where `user-persona` output feeds the map: a persona is
already specific enough to be a WHO actor.

---

## Level 3 — HOW: the Impacts (the crux)

**Question asked:** *How should this actor's behavior change for the goal to be reached?
What would they start doing, stop doing, or do differently?*

**This is the level that makes an impact map an impact map, and the level teams get
wrong.** An impact is a **change in an actor's behavior — an outcome**, never a feature
and never an activity.

The distinction, stated three ways because it is that important:

- **Impacts are outcomes, not outputs.** An outcome is something the *actor* does
  differently. An output is something the *team* ships. "Maya connects all her storage
  sources in the first session" is an outcome (Maya's behavior). "Build a connector" is
  an output (the team's behavior) — it belongs one level down, in WHAT.
- **Impacts are behaviors, not feature-usage.** "Maya uses the report feature" is a
  disguised deliverable — it names the feature, not the behavior change. The real impact
  is what the feature *lets her do differently*: "Maya briefs the CISO from live data
  instead of a week-old spreadsheet." Notice this impact could be caused by several
  different features — that is the sign it is phrased correctly.
- **Impacts are the actor's, not the product's.** The product does not have behavior;
  actors do. "The system generates a report" is not an impact. "The auditor accepts the
  generated report without requesting a manual evidence pack" is.

**Good vs. bad impacts:**

| Bad (feature/activity) | Good (behavior change / outcome) |
|---|---|
| Maya uses the compliance report | Maya briefs the CISO from live data, not a stale spreadsheet |
| IT deploys the product | IT deploys without raising a support ticket |
| User connects a source | Data Steward connects *all* sources in the first session |
| System sends alerts | Compliance Officer acts on a gap the day it appears, not at quarter-end |

**Phrasing formula:** *[Actor] [starts / stops / does more / does less / does
differently] [observable behavior] [instead of the current behavior].* Naming the
*current* behavior the impact replaces is what keeps it honest — it forces the impact
to describe a real change, not a restatement of the feature.

**Where impacts come from.** `jtbd-analysis` job stories are the richest source: a
validated job story already describes what the actor is trying to get done in their real
work context, which is exactly the behavior an impact should move. Olsen's problem-space
discipline applies here — an impact written in the product's UI vocabulary ("uses the
dashboard") is a solution-space smell; rewrite it in the actor's work-context language
until it could be satisfied by more than one deliverable.

---

## Level 4 — WHAT: the Deliverables (droppable hypotheses)

**Question asked:** *What could we build or do to cause this behavior change?*

Deliverables are features, content, processes, or configuration options that *might*
cause an impact. The defining property, and the reason the map prevents waste:

**Deliverables are hypotheses that may be wrong — and are therefore droppable.**

Adzic's framing is that the WHAT level is the *most uncertain* level, not the most
certain. The team is confident about the goal (it came from strategy), reasonably
confident about the actors, thoughtful about the impacts — but the deliverables are
*guesses* about what will cause the impact. Any given deliverable might fail to move the
behavior at all. This is the same claim Cagan makes about all four product risks
(value/usability/feasibility/viability) being *assumptions* until tested, and the same
reason Olsen builds a hi-fi MVP before committing engineering: the feature is a bet, not
a fact.

Three consequences follow, and they are the whole payoff of the technique:

1. **Multiple deliverables can serve one impact — you don't build them all.** List every
   candidate that might cause the behavior change, then pick the cheapest one or two that
   would plausibly do it. The rest wait.
2. **A deliverable that causes no impact is cut immediately.** If you cannot draw a line
   from a proposed feature up to a behavior change that moves the goal, it is waste by
   definition — no further debate needed. This is the map's forcing function against the
   feature factory.
3. **You stop as soon as the impact is achieved.** Because deliverables are means to a
   behavioral end, you keep only enough of them to cause the change. Once an impact is
   met, remaining deliverables under it become deferred backlog, not obligations.

### Pruning: from full map to MVP cut

The full map is a *menu of options*, all traced to the goal. Turning it into a scope
decision is a deliberate three-step prune:

1. **Rank actors by leverage.** Which actor, if their behavior changed, moves the goal
   most directly? Focus there first. (Off-stage and blocker actors are often addressed
   with a single deliverable, not a whole branch.)
2. **Rank impacts by leverage within the priority actors.** For the priority actor,
   which behavior change has the most effect on the goal per unit of effort?
3. **Select the minimum deliverable set for the priority impacts.** For each priority
   impact, choose the *smallest* set of deliverables that would reliably cause the
   behavior change. That set — and only that set — is the MVP scope.

Everything not selected stays on the map as **deferred deliverables**, each already
traced to an impact and a goal, so re-prioritizing it later is nearly free. A map
delivered *without* this cut has skipped its entire purpose: the impact map is a
prioritization instrument, and the prioritization is the cut.

**Optional risk annotation (Cagan).** For each deliverable selected into MVP scope, you
can note which of the four product risks — value, usability, feasibility, viability — is
already tested versus still assumed. This upgrades the MVP cut from "traced to a goal"
(the map's default bar) to "traced to a goal *and* risk-tested," and flags which
deliverables should get a cheap prototype or concierge test before they are committed.

---

## Common failure modes at each level

| Level | Failure mode | Fix |
|---|---|---|
| WHY | Goal is an output ("ship X") or unmeasurable ("improve X") | Restate as a metric an actor's behavior produces |
| WHO | "The customer" / "IT" — no observable behavior | Replace with a specific persona/role |
| WHO | Only supporters, no blockers | Ask "who can *prevent* this?" and add them |
| HOW | Impact names a feature ("uses the dashboard") | Rewrite as the behavior it enables, in work-context language |
| HOW | Impact describes the *system's* behavior | Reattribute to the actor — products don't have behavior |
| WHAT | Every deliverable treated as required | Select the minimum set; defer the rest |
| WHAT | Deliverable traces to no impact | Cut it — it is waste by definition |
| whole map | Built backwards to justify an existing backlog | Discard the backlog; rebuild top-down from the goal |
