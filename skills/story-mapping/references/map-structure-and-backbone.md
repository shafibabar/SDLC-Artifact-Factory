# Map Structure and the Backbone

Reference for the *shape* of a User Story Map (Jeff Patton, *User Story Mapping*,
with Peter Economy): the three working layers, the backbone vs. the body, how to
facilitate building one, and the failure modes that produce a map-shaped thing
that is not a map. Read alongside `slicing-and-walking-skeleton.md`, which covers
the vertical cut (releases and the walking skeleton).

---

## The three working layers

Patton frames a map as three layers of resolution, built roughly top-down:

| Layer | Patton's name | What it is | This repo's Level |
|---|---|---|---|
| 1 | **Big picture** | *Why* you're building this and for *whom* — the opportunity, the target user, the outcome hoped for | Framed upstream by `impact-mapping` / JTBD, not on the map |
| 2 | **Backbone** | The narrative spine: **activities** decomposed into **tasks** | Level 1 (Activities) + Level 2 (Tasks/Epics) |
| 3 | **Details** | The individual **stories** placed under each task | Level 3 (Stories) |

The big picture is produced *before* the backbone — Patton's "frame the
opportunity" pass. It is one page stating the business objective, the target
persona, and the outcome hypothesis. In this repo that framing already exists as
the impact map and the JTBD job statements; the story map consumes them rather
than re-deriving them.

---

## Backbone vs. body — the distinction that makes it a map

This is the single most important structural idea, and the one most often lost.

### The backbone (horizontal, time)

- Runs **left-to-right in the order the user actually encounters activities and
  tasks** — narrative flow, not priority.
- Two grains:
  - **Activities** — big, coarse buckets of user behaviour ("Connect Sources",
    "Scan & Classify", "Review & Report", "Manage & Govern"). These are
    categories, not stories.
  - **Tasks** — the specific things a user does within an activity ("Connect
    Google Drive", "Trigger a scan", "View the gap report"). A task is at the
    grain of a goal the user is trying to accomplish, *not* a UI interaction
    ("click the blue button" is never a backbone task).
- Backbone tasks are the rough equivalent of what this repo calls **epics** —
  the pre-decomposition form. Patton's own vocabulary doesn't use "epic"; that is
  Cohn/Lean-Startup territory layered on top.

### The body (vertical, necessity)

- Under each backbone task sit the **stories** for that task.
- Ordered **top-to-bottom by necessity** — *what the story needs to be minimally
  whole* — **not** by "depth of detail" and **not** by an arbitrary priority
  number.
  - **Top row:** the one story that makes the task work at all.
  - **Middle rows:** improvements, additional personas, richer options.
  - **Bottom rows:** edge cases, configuration, nice-to-haves.
- The vertical axis must read as a *necessity gradient*: minimal-but-functional at
  the top, refinements descending below. If every row looks equally important,
  the body has not been ordered — it has been dumped.

### Why the two axes matter together

A flat backlog is a single sorted list; it destroys the narrative relationships
between stories. The two-axis map restores them: horizontal tells you *when* in
the journey a story lives, vertical tells you *how essential* it is to that step.
Only with both can you cut a coherent release (see the sibling reference).

---

## The narrative-spine test

The backbone is correct when you can **read the activities and tasks aloud, left
to right, as a coherent story**:

> "First the Data Steward *connects a source*. Then they *trigger a scan* over it.
> Then they *review the compliance gap report* it produces. Then they *set a
> retention policy* to close a gap."

If the reading has a logical jump, an unexplained sequence, or a step that only
makes sense from the system's point of view, the spine is wrong. Loops and
branches are allowed (a user may re-scan, or connect several sources before
scanning) — mark them with an annotation rather than forcing a strict line.

Because this repo cannot run Patton's live whole-team session, the adaptation is
to **narrate the spine aloud with Shafi** as an explicit step before the map is
final — the closest available analog to the book's cross-functional walkthrough,
and the moment where the "map is a conversation, not an artifact" value is
approximated. This is distinct from the generic "present artifact, wait for
approval" step used for every other Ideate artifact.

---

## How to facilitate building a map

Patton's practice is a live, whole-team session (product, design, engineering,
business, in one room or call, on sticky notes or a shared board). Under this
repo's solo-agent workflow the *sequence* still holds even though the room does
not:

1. **Frame the opportunity first.** Confirm the big picture — objective, target
   persona, outcome hypothesis — is already stated (impact map / JTBD). Do not
   generate a backbone without it.
2. **Lay the backbone before any stories.** Walk the product from the persona's
   viewpoint and place activities left-to-right, then decompose each into tasks.
   Resist writing stories until the horizontal reading narrates cleanly.
3. **Narrate the spine** (the test above). Fix ordering before going deeper.
4. **Fill the body.** Under each task, place every story from the backlog,
   ordered top-to-bottom by necessity. Every backlog story must land somewhere.
5. **Read for gaps** (checklist below) before cutting any release slice.
6. **Cut slices** — covered in `slicing-and-walking-skeleton.md`.
7. **Keep it living.** After a slice ships, absorb what changed and re-cut. A map
   that disagrees with the backlog is worse than none — it is trusted and wrong.

---

## Reading the map for gaps

After the body is filled, walk the spine and interrogate each activity:

| Question | What a "no" means |
|---|---|
| Can the user complete this activity using only its top-row story? | If not, a lower story must move up to make the step minimally whole. |
| Is there a backbone step with *no* stories under it at all? | A discovery gap — the journey has a hole; go write the missing stories. |
| Are some activities piled deep while others are shallow? | Imbalanced discovery — investigate whether the shallow steps are truly simple or just under-explored. |
| Does every backlog story appear somewhere on the map? | An orphan story belongs to a step (place it) or to no journey (challenge why it exists). |
| Does the top row, read across the whole backbone, function end-to-end? | The walking skeleton is broken — see the sibling reference. |

---

## Common mistakes (map-shaped things that are not maps)

- **A backlog turned sideways.** The columns are just the flat backlog pasted in
  priority order, with no necessity gradient down any column. If the vertical axis
  does not read "minimally whole at the top, refinements below," it is a backlog
  wearing a map's clothes. This is the defining failure — a real map *cannot* be
  produced by re-arranging a priority-sorted list, because priority is not
  narrative order.
- **The system-perspective spine.** "Ingest → Process → Store → Serve" narrates
  the *pipeline's* journey, not the user's. The backbone must narrate what the
  *persona* does, or the map can never reveal where a user gets stuck.
- **Tasks at UI grain.** "Click connect", "open the modal" are interactions, not
  tasks. Backbone tasks are user goals ("Connect Google Drive"); UI steps are
  implementation detail that belongs inside a story's acceptance criteria.
- **Skipping the big picture.** Jumping straight to tasks without the opportunity
  frame produces a tidy map of the wrong product.
- **The solo document.** Treating the finished diagram as the deliverable and
  skipping the narration entirely — capturing a picture while missing the shared
  understanding Patton says is the actual point.
- **The frozen map.** Built once during discovery and never revisited, so it
  silently drifts out of agreement with the evolving backlog.

---

## Terminology notes (accuracy)

- **Backbone** and **walking skeleton** are Patton's terms (he credits Alistair
  Cockburn for the walking skeleton).
- **INVEST** (the story-quality checklist applied to body stories) is Bill Wake's,
  popularised by Mike Cohn — not Patton's. Do not attribute it to this book.
- **MoSCoW** is DSDM's, not Patton's; it can inform vertical placement but a
  release slice is not a MoSCoW "Must" cut (see the sibling reference).
- The **"skateboard → bicycle → car"** MVP sketch is Henrik Kniberg's
  illustration, not Patton/Economy content — do not attribute it to this book.
