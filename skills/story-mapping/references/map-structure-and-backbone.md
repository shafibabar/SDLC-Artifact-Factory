# Map Structure and the Backbone

Self-contained reference for `story-mapping`. Read it before laying a backbone, when the spine does not read as a story, when more than one persona acts in the journey, and when reading a filled map for gaps. The vertical cut (walking skeleton, release slices, the Must check) is in `slicing-and-walking-skeleton.md`.

Grounded in Jeff Patton with Peter Economy, *User Story Mapping* (the two axes, the three layers, the backbone, narrating the spine, mapping as a conversation).

---

## 1. The three working layers

Patton builds a map in three layers of resolution, top down:

| Layer | Patton's name | What it is | In this plugin |
|---|---|---|---|
| 1 | **Big picture** | Why this is being built, for whom, and the outcome hoped for | Already written upstream: the Key Result, the impact map's selected path, the primary persona. The map's Big Picture section cites them; it never re-derives them |
| 2 | **Backbone** | The narrative spine: **activities** decomposed into **tasks** | The epics (backbone candidates), arranged in journey order |
| 3 | **Details** | The stories under each task | The written stories (US-n) |

Patton has the team "frame the opportunity" before any task or story. In this plugin that frame is the KR and the impact map. Without it, the map is a tidy picture of the wrong product: stop and name the missing input.

---

## 2. The backbone (horizontal: time)

- **Left to right in the order the persona meets each activity.** Narrative order, never priority.
- **Two grains.**
  - **Activities:** coarse buckets of what the user is trying to do ("Fill the diary", "Prepare an application"). Categories, not stories.
  - **Tasks:** user goals within an activity ("Send a confirm request", "See the checklist for my site"). A task is a goal, never a click ("open the modal") and never a system stage ("persist the record").
- **Epics are backbone candidates.** Patton has no "epic"; his backbone tasks are the closest equivalent (`epic-definition` says the same). Each epic usually becomes one task. When an epic's stories happen at different points of the journey (a confirm request is *sent* early and *followed up* later), place each story at its step, tagged with its epic. The journey wins over the epic's grouping.
- **Only the selected path.** The backbone is seeded from the impact map's selected-path deliverables, through the epics. Option branches and non-software deliverables (a procedure, training) are not tasks. A selected procedure can still appear as a **manual cell** in the walking skeleton when the journey depends on it.
- **Transition work** (a migration, a parallel run) sits at the step where the user meets it, usually at the start ("bring existing cases over") or the end ("retire the old system").
- **Rules that protect a step** (tenant isolation, access, consent) are not their own activity. Their stories sit under the activity where the user would otherwise see someone else's data.

### Several personas, one backbone

When more than one persona acts (an admin sets up, an applicant submits, an officer decides), keep **one** backbone in the order things happen to the work, and name the persona on each activity: "Bring the council on (council admin)", "Prepare an application (applicant)". Three separate maps hide the hand-offs, which is where journeys break. A persona with a separate journey that never touches the others' work (an auditor reading exports months later) gets a short second backbone below the first, with its own skeleton row.

---

## 3. The body (vertical: necessity)

Under each activity, stories run top to bottom by **necessity**: what the step needs to be minimally whole.

- **Top:** the one story (or existing capability, or manual step) that makes the step work at all.
- **Middle:** improvements, a second persona, richer options.
- **Bottom:** edge cases, configuration, nice-to-haves.

The vertical order is not the provisional priority carried over from the epic. A high-priority epic's edge-case story still sits low. DSDM says the same about priority: a Must epic's stories are judged one by one.

---

## 4. Narrating the spine (with the user)

The backbone is right when it reads aloud, left to right, as one story: "First the front desk has the appointment in the diary. Then the patient gets a confirm request and replies. Then, before the cut-off, the front desk sees who hasn't answered and offers those slots to the waitlist."

A jump, an unexplained step, or a step that only makes sense from the system's side means the spine is wrong. Loops (re-scan, re-submit) and branches are allowed: annotate them rather than forcing a straight line.

**The narration step is this plugin's adaptation of Patton's live session.** Patton treats a map produced alone and handed over as having missed the point. A single agent cannot gather a team, so before the map is final the agent **reads the spine to the user as a story and asks where it is wrong**: a missing step, the wrong order, a persona who would not do this. Record what changed in the map's narration line. This is separate from the ordinary approval at the end, and it comes first.

---

## 5. Facilitation order

1. **Confirm the big picture** exists (KR, selected path or lean KR trace, primary persona).
2. **Lay the backbone** before placing any story: activities, then tasks.
3. **Narrate the spine with the user.** Fix the order before going deeper.
4. **Place every story** under its step, by necessity.
5. **Read for gaps** (section 6).
6. **Cut the skeleton and slices** (`slicing-and-walking-skeleton.md`).
7. **Keep it living.** After a slice ships, absorb what changed and re-cut. A map that disagrees with the backlog is trusted and wrong.

**Stories first, map second, on purpose.** Patton uses mapping to *generate* the backbone and stories. Here the stories were already written from the epics, so the map's job shifts to arranging them and exposing what the decomposition missed. Each gap is proposed as a new story for `user-story-writing`; nothing is added to the backlog without the user.

---

## 6. Reading the map for gaps

| Question | A "no" means |
|---|---|
| Can the user finish each activity using only its top-row cell? | Move a lower story up, or name the manual step |
| Does every activity have at least one story or a named existing or manual capability? | A **discovery gap**: the journey has a hole. Propose the missing story |
| Are some activities deep and others shallow? | Check whether the shallow ones are simple or just under-explored |
| Does every backlog story appear on the map? | An **orphan**: place it, or challenge why it exists (no journey needs it) |
| Does every map story trace back to a selected-path deliverable (or the KR at lean)? | Scope from an option branch or nowhere: remove it or record the trace |
| Read across the top row: does it walk end to end? | The skeleton is broken (`slicing-and-walking-skeleton.md`) |

---

## 7. Map-shaped things that are not maps

- **A backlog turned sideways.** Columns pasted in priority order with no necessity gradient. The defining failure: priority is not narrative order, so a priority list cannot be rearranged into a map without re-thinking it.
- **The system-perspective spine.** "Ingest → Process → Store → Serve", "Upload → Parse → Index → Query". The pipeline's journey, not the persona's. Ask "what is the *person* trying to get done at this point?" and rename each step as their goal; often several system stages collapse into one user task.
- **Tasks at UI grain.** "Click connect" is an interaction; it belongs in a story's acceptance criteria.
- **Skipping the big picture.** A backbone with no KR or selected path behind it.
- **The solo document.** No narration with the user: a picture, not shared understanding.
- **The frozen map.** Built once, never re-cut.

---

## 8. Terminology accuracy

- **Backbone**, **walking skeleton** and **release slice** are Patton's terms; he credits Alistair Cockburn with the walking skeleton.
- **INVEST** is Bill Wake's, popularised by Mike Cohn. **MoSCoW** and the **Minimum Usable SubseT** are DSDM's. **Given/When/Then** comes from BDD (Dan North, Chris Matts). None is Patton's.
- The **"skateboard → bicycle → car"** MVP sketch is Henrik Kniberg's, not Patton's.
