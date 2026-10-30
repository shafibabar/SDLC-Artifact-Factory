# Slicing and the Walking Skeleton

Self-contained reference for `story-mapping`. Read it before cutting the walking skeleton or any release slice, whenever the Must list and the skeleton disagree, when someone calls an experiment the MVP, and after a release ships (re-cutting). The backbone and body are in `map-structure-and-backbone.md`.

Grounded in Jeff Patton with Peter Economy, *User Story Mapping* (walking skeleton, slices, learning vs release MVP, re-cutting); the DSDM Agile Project Framework (MoSCoW, the Minimum Usable SubseT, the workaround clause, priority per release); and Marty Cagan, *Inspired* (prototypes belong to discovery).

---

## 1. The walking skeleton

**Definition.** The thinnest slice of the map that **works end to end across the whole backbone**: one complete path from the first activity to the outcome the product exists for, however bare. Read it as the top row across every activity at once. The name is literal: a skeleton that can already walk before any flesh is added.

**The end-to-end test.** Read the top row aloud as one sentence: "The member *sees the drill is in*, *borrows it*, *gets a reminder*, *brings it back*." If any activity has no working top cell, the user hits a wall there and the skeleton is **broken**, not incomplete.

**What a skeleton cell may hold.**

| Cell | Allowed | Example |
|---|---|---|
| A story (US-n) | Yes | `US-4` |
| Several stories | Yes, when the step needs both to work at all | `US-41, US-42 (regulatory: BR-6)` |
| An existing capability | Yes, marked | `(existing: appointment already in the diary)` |
| A named manual step | Yes, marked; ugly still walks | `(manual: front desk phones the waitlist)` |
| Blank or "—" | **Never** | The skeleton does not walk |

"Walking skeleton" is more precise than "MVP slice": "minimum viable" invites a favourite-features list; "walks end to end" is a test anyone can run.

---

## 2. Must = Minimum Usable SubseT = walking skeleton

The plugin's decision (D045): **the release's Musts are DSDM's Minimum Usable SubseT, and that is the walking skeleton.** DSDM expands MUST as *Minimum Usable SubseT*, the guaranteed set that together gives a usable solution. A Must set with a hole in the journey is not *usable*, so it fails DSDM's own definition. Patton states the same idea as a shape on the map. The two meet in one rule, checked both ways.

### The two-way check

| Direction | Check | If it fails |
|---|---|---|
| Skeleton → Must | Every story on the skeleton row is a Must for this release | MoSCoW found a workaround (DSDM: **any** workaround, even manual or painful, means not a Must)? Move the story to a later slice, put the workaround in the cell as a named manual step, and re-run the end-to-end test |
| Must → skeleton | Every Must for this release is on the skeleton row | Not needed for the journey and not legal, safety or regulatory? **Demote it** (Should or Could). Legal, safety or regulatory (DSDM's other Must signals)? **Add it to the skeleton** at the step it protects, marked with its rule |

The second fix is the one DSDM does not state: it never mentions story maps, so "a regulatory Must must sit on the skeleton" is this plugin's reading of "usable". It keeps the two lists identical, which is the point.

**Who does what.** The map **proposes** the skeleton and records the two-way check against the provisional priorities. `moscow-prioritization` **confirms** it at release level, applying the workaround clause story by story. At lean, the backlog's closing Must / Won't-this-time block is the skeleton list. Neither skill may leave the two disagreeing.

**Provisional priority is not the answer.** Epics and stories carry high / medium / low until MoSCoW. A high epic's stories are judged one by one (DSDM): some are on the skeleton, some are not. Do not copy an epic's priority onto all of its stories.

**Slices below the skeleton.** Their stories are not Musts of *this* release. DSDM prioritises per release: when Release 2 comes, MoSCoW runs again and Release 2's skeleton additions become that release's Musts.

---

## 3. Release slices: by outcome, never by layer

Each horizontal cut below the skeleton is a **release slice**. The rule: **each slice, added to those above it, leaves the journey complete for the users it targets, and names the outcome it adds.**

| | Outcome slice (right) | Vertical or component slice (wrong) |
|---|---|---|
| Shape | Thin cut across the activities that change | Deep cut finishing one activity, or one service |
| User | Completes the whole journey, with fewer options | Perfects one step, then hits a wall |
| Example | "Paper-diary clinics join: copy the day's bookings in; reminders and confirm requests already work" | "All four connectors first, scanning next quarter"; "Tenant Service release" |

A slice may be empty in a column where nothing changes for its users (a new segment joining may only add an onboarding step). A slice that adds a *new user segment or tenant* is legitimate and common at enterprise: "council B goes live" is an outcome.

**Name the outcome, not the content.** "Release 2: refills run themselves" tells the roadmap something; "Release 2: US-3, US-5, US-6" does not.

At standard and enterprise, cut at least the skeleton and Release 2. Everything beyond the last slice is listed as "Later", not left unplaced.

---

## 4. Learning checkpoints and re-cutting

Patton expects a "what did we learn?" checkpoint after each slice ships, and he expects later slices to change. Each slice in the artifact carries:

- **Signal:** what to read after it ships. Copy it from the impact map's selected path (or the KR at lean); do not invent a second one.
- **Re-cut trigger:** what result would change the later slices. Copy the impact map's re-plan trigger where it exists ("reply rate under 70% after four weeks → try the calendar-file option").

When a trigger fires, re-cut: move stories between slices, add the next option's stories (through a new epic, after the impact map changes), and record the re-cut. At enterprise the map keeps a **re-cut log** (date, what moved, why). A story map that no longer matches the backlog is worse than none.

**The roadmap.** The roadmap is written in Strategy, before the map exists. The first release slice is the first concrete test of the roadmap's Now horizon, and the map's arrival is a named roadmap revision trigger (`roadmap-authoring`). Note it in the artifact; do not edit the roadmap from here.

---

## 5. Release MVP and learning MVP

Patton separates two things both called "MVP":

| | Release-MVP | Learning-MVP |
|---|---|---|
| Question | What is the smallest thing real users can complete the journey with? | What is the cheapest way to test this belief? |
| Form | The walking skeleton, production quality, minimal scope | Fake door, concierge or Wizard-of-Oz test, clickable or live-data prototype, feasibility spike |
| Home | This map | Upstream: assumption tests on the `opportunity-solution-tree`, typed assumptions on the impact map |
| Failure | Treating it as a prototype (cutting quality) | Shipping it, or demanding production rigour from it |

Marty Cagan (*Inspired*) makes the same cut from the other side: discovery uses prototypes of different fidelities to test value, usability and feasibility *before* delivery is committed, and none of them ship. When a user calls a fake-door test "our MVP", answer both halves: the test belongs upstream as an assumption test (and its result can reshape the map), and the release-MVP is still the walking skeleton, which ships.

A spike story on the map (a feasibility question inside delivery, "what does each council's GIS return?") is not a learning-MVP: it is a delivery task that unblocks a story, and sits under the story's step.

---

## 6. Common slicing mistakes

- **The broken skeleton.** A top row with a blank activity.
- **Musts with a hole.** A Must list that skips a journey step: not usable, not a skeleton.
- **The orphan Must.** A Must nobody needs to walk the journey: demote, unless legal, safety or regulatory.
- **The Should on the skeleton.** A skeleton story with no workaround but ranked Should: the release is not guaranteed to walk.
- **Every tenant at once.** "Release 1 = onboarding complete for all tenants" is the vertical slice at enterprise scale. One tenant (or pilot segment) walking end to end comes first; the others are later slices.
- **The everything slice.** One cut containing the whole map: there was no slicing.
