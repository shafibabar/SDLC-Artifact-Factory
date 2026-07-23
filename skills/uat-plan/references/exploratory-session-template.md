# Exploratory Session Template

Full mechanics for the exploratory-testing component of a UAT plan, per
Elisabeth Hendrickson's *Explore It!* (`research/testing/explore-it-hendrickson.md`).
Self-contained — loadable without reading `SKILL.md` first.

---

## Why This Exists Alongside Scripted Scenarios

Scripted `uat-scenario`s prove a known example works — they can only check
what someone already wrote down. Exploratory testing exists specifically to
surface the risks, edge cases, and interactions **no one wrote a scenario
for** — not because scripted testing is deficient, but because it is
structurally incapable of finding what it didn't anticipate. A charter has
no pass/fail; it produces findings.

## The Charter

Hendrickson's template: **"Explore [target/area], with [resources], to
discover [information]."** Names *what* to explore, *what to bring* (test
data, tools, environment access, personas), and *what you're trying to
learn* — without prescribing exact steps, which is what preserves the
freedom to follow what's found.

**Example, this repo's domain:** "Explore the sensitivity-classification
workflow, with a mix of scanned low-quality PDFs and edge-case file types,
to discover whether misclassification or crashes occur outside the
happy-path documents already covered by scripted UAT scenarios."

## Session Structure: Charter → Time-Boxed Execution → Debrief

A session record captures:

| Field | Content |
|---|---|
| Charter | The Explore/with/to-discover statement |
| Time-box | Typically 45–90 minutes — long enough to explore, short enough to stay focused |
| Tester | Who ran the session (same executor pool as scripted scenarios — see `SKILL.md`'s Participant Roles) |
| Environment | Same canary tenant / staging environment as scripted UAT — never a separate, less-representative environment |
| Notes | A running log of actions and observations captured **during** the session, not reconstructed afterward from memory |
| Bugs/Issues found | Routed to `feedback-template`, exactly as a scripted scenario's failure would be |
| New charters surfaced | What the session revealed that deserves its own follow-on charter — exploration is branching, not a single closed pass |
| Debrief summary | What was learned, in a few sentences |

## Heuristics for Generating Test Ideas

A checklist to run down when a charter needs concrete probes, not a
prescription for what to test — pick the ones relevant to the target area:

- **CRUD** — for any persistent thing: Create, Read, Update, Delete, and the *interactions between them* (can you delete something still referenced elsewhere? does an update survive a re-read?).
- **Boundaries** — the edges of any range: minimum, maximum, zero, one below/above a limit, empty, off-by-one.
- **Position / "Goldilocks"** — first, last, only-one, none, many; too few, too many, just right.
- **Interruptions** — start a workflow, then stop mid-way (navigate away, lose connectivity, let a session expire, switch users) and resume or abandon it. One of the highest-yield heuristics for state-management bugs, since a scripted test normally runs a workflow start-to-finish and never interrupts it.
- **Configuration variance** — the same feature under different browsers, devices, locales, permission levels, feature-flag states, or environment configurations.
- **Saboteur mindset** — deliberately trying to break things a well-behaved user never would (wrong input types, out-of-order steps, malformed data) — a distinct stance from "does the happy path work."

## The SFDIPOT Coverage Audit

Before closing an exploratory pass on a feature, check whether each of
**S**tructure, **F**unction, **D**ata, **I**nterfaces, **P**latform,
**O**perations, and **T**ime has been touched by at least one charter —
this catches "we only ever explored the happy-path UI, never the
underlying data/platform/timing dimensions." This is a completeness
check across a set of charters, not a per-charter requirement.

## Charter-Generates-Charter Discipline

Every debrief produces zero or more follow-on charters for what the
session surfaced but didn't have time to pursue. Treat exploration as an
ongoing, branching activity within the time-boxed UAT window — not a
single session that either finds something or doesn't.

## Honesty About Who Actually Explores

Hendrickson is explicit that exploratory testing's value comes from a
skilled human's in-the-moment curiosity — learning something and
immediately designing the next probe from it is the part hardest to hand
to an agent running a fixed prompt. **The adaptation this repo uses**: the
requirements-analyst (facilitator) drafts the charter and relevant
heuristics checklist; the actual exploring is done by the human executor
(design partner, or Shafi acting as proxy per `SKILL.md`'s Participant
Roles) using the charter as a mission brief. This keeps the book's core
claim intact (exploration needs human judgment) while giving the agent a
concrete artifact it can genuinely author. **Do not** have an agent
simulate "exploring" a UI autonomously (e.g., reasoning over screenshots
without a live human driving) and label that exploratory — that is
scripted testing wearing an exploratory label, and this repo states that
distinction explicitly rather than glossing over it.
