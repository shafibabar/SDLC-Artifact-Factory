# Selected Path, Assumptions and Re-planning — Depth Reference

Self-contained. How an impact map becomes a decision without becoming a priority list: choosing one path (Gojko Adzic, *Impact Mapping*), writing the assumption each link rests on with its type (Marty Cagan's four risks, *Inspired*; Teresa Torres's ethical type and test discipline, *Continuous Discovery Habits*), the signal that shows whether it worked, and the re-plan loop that keeps the map alive. The levels themselves are in `impact-map-levels.md` beside this file.

---

## 1. Why there is no priority column

The full map is a menu of options, all traced to the goal. A Must / Should / Could / Won't column on it does two wrong things:

- It **pre-empts MoSCoW.** In this plugin `moscow-prioritization` runs last in Ideate, on stories, against a delivery window. Epics and stories carry only a provisional priority until then. A map that already says "Must" has decided before the stories exist.
- It turns **options into commitments.** Adzic's WHAT level holds possibilities, many never to be built. A "Could" reads as "later, probably"; an option reads as "only if the selected path fails or the next cycle chooses it".

So each row carries **Path** (`selected` or `option`), **Assumption** and **Signal** instead.

---

## 2. Choosing the path

Adzic's prioritisation is choosing **one path** through the map:

1. **One goal** (the map has only one).
2. **The most promising actor**: whose behaviour change moves the goal most directly. Where an opportunity solution tree exists, this is the actor whose behaviour the **target opportunity** explains; the user already chose that opportunity by comparing siblings.
3. **The impact most likely to move the goal** for that actor.
4. **The cheapest deliverables likely to cause that impact**: where the tree compared solutions, its carried-forward solutions (usually tested side by side, so more than one may be on the path until a test decides); elsewhere, the cheapest option, non-software first.
5. **Blocker removal on the path.** If a blocker would stop the selected deliverables working (a practitioner who keeps bookings off the system, so no reminder ever goes out), its cheapest unblocking deliverable joins the path.

Everything else is an **option**, already traced to the goal, so choosing it later is nearly free. The path is a **bet to test**, not a release plan: it is not the MVP and not the walking skeleton. The selected deliverables become epics; the epics form the story map's backbone; the story map decides the walking skeleton (`story-mapping`).

The agent proposes the path; **the user confirms it**, as they chose the target opportunity.

---

## 3. Writing assumptions

Every link on the path rests on a belief. Write two kinds:

| Link | Shape | Example |
|---|---|---|
| **Deliverable → impact** | If we do X, actor A will change behaviour B | "If patients get a confirm request 72 h ahead, most reply" |
| **Impact → goal** | If actor A changes behaviour B, the metric moves | "Patients who confirm or cancel ahead let clinics refill the slot, so no-shows fall" |

Type each one (the tree uses the same five types, so tests carry over unchanged):

| Type | Question | Source |
|---|---|---|
| **Desirability** | Do they want it; will they change behaviour? | Cagan (value risk) |
| **Usability** | Can they do it? | Cagan |
| **Feasibility** | Can it be built or run with what we have? | Cagan |
| **Viability** | Does it work for the business: cost, sales, legal, support? | Cagan |
| **Ethical** | Could it do harm; should it be done at all? Over-collection, surveillance, exposure to people who never consented, pressure on a vulnerable actor | Torres |

**Consider at least one ethical assumption on the path.** The "who will be affected?" question at WHO is where they surface: the family member who reads a reminder text, the driver whose location becomes visible, the employee whose activity a dashboard ranks.

**Order by importance × evidence** (a map Torres credits to David Bland): test the assumptions that are important to the path and have little evidence first. Each test gets a **success criterion with a number, written before it runs** ("at least 4 of 6 …"); a result is recorded against that bar, never judged afterwards. Where the tree already holds a test (T-n) for the assumption, cite it rather than writing a second one. Results go in dated files under `ideate/assumption-tests/` (`opportunity-solution-tree`), never into the approved map.

---

## 4. Signals

A signal is how an impact will be observed once its deliverable ships: "we would see it in ___". It names a measurable behaviour of the actor (reply rate, median time to accept, share of bookings entered the same day), not a delivery fact (it shipped, it was used once). Usage of the deliverable is at most a leading indicator; the signal is the behaviour change.

Every impact on the selected path has a signal. Option rows may leave the signal brief, but an impact that has no conceivable signal is a sign it is not a behaviour.

---

## 5. Measure and re-plan

Adzic's loop: deliver the smallest thing on the path, measure whether the behaviour changed, return to the map.

| Observation | What it means | Next move |
|---|---|---|
| The impact signal does not move by the date | The deliverable was a wrong guess (deliverable → impact assumption failed) | Try the next option under the **same** impact |
| The impact moves, the goal does not | The impact → goal assumption was wrong | Return to the map: a different impact or actor; or to the tree, the opportunity was not the one that matters |
| Both move | The bet held | Choose the next path, or stop: remaining options under this impact are no longer needed |
| A blocker appears that the map did not name | WHO was incomplete | Add the actor and its unblocking options |

Write this as the artifact's **Re-plan Trigger**: concrete signals and dates. It makes the map a living roadmap input instead of a one-time scope document. Revisions are deliberate (a new version, approved again), not weekly edits: every edit reopens an approved artifact.

---

## 6. Hand-off

| Consumer | What it takes from the selected path |
|---|---|
| `requirements-analysis` | Each functional requirement cites the selected deliverable it serves |
| `epic-definition` | Each selected deliverable → a candidate epic; the impact is its hypothesis; the signal its success measure |
| `story-mapping` | Selected deliverables, through epics, seed the backbone. Option branches never appear on the story map. The walking skeleton is decided there |
| `moscow-prioritization` | Finalises priority on the stories that come out of the path |
| `okr-authoring` | The OKR set's Initiatives for the KR are the path's deliverables; other ideas stay options on the map, so there are never two lists of bets for one KR |
| Next discovery cycle (`opportunity-solution-tree`) | Impacts marked "— not on tree", failed assumptions, and the re-plan trigger's outcome |
