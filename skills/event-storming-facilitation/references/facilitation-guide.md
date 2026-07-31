# Facilitation Guide — Running the Workshop

The step-by-step procedure for facilitating an Event Storming session: who is in
the room, the physical (or virtual) space, timeboxing, the pass-by-pass
procedure at each level, hotspot and opportunity handling, and the anti-patterns
that quietly ruin a session. The `SKILL.md` body carries only the four-move arc;
this file is the operational detail behind it.

---

## Participants

Event Storming is a *group* modeling exercise. A session run by engineers alone
produces a wall of assumptions.

- **Domain experts (mandatory):** at least one person with first-hand knowledge
  of how the domain actually works. For this repo's data-estate / compliance
  product that means a **Data Steward** (how assets are discovered, ingested,
  catalogued) and/or a **Compliance Officer** (how classification, access
  review, and retention decisions are actually made). If no expert is available,
  stop and run discovery interviews first.
- **Engineers / modelers:** the people who will build the system; they ask
  questions and enforce the notation, they do not dictate the model.
- **The facilitator:** owns the *process*, not the content. Sequences the
  timeline, questions vague cards, enforces the color grammar and past tense,
  keeps hotspots from turning into debates. The facilitator does **not** write
  most of the cards — everyone writes.
- **Group size:** small enough that everyone can reach the wall — split a very
  large group into a Big Picture together, then parallel Process-Level tables.

---

## Space and Materials

- **An unlimited modeling surface.** Brandolini's signature requirement: a long
  roll of paper along a wall (8+ metres is normal), not a whiteboard, so the
  timeline never runs out of room. Running out of wall silently biases the model
  toward brevity. Virtually, use an infinite canvas (Miro/Excalidraw-style) with
  the same discipline.
- **Sticky notes in every grammar color** (orange, blue, yellow small/large,
  purple, green, pink, red) — enough that no one has to ration them.
- **Markers** thick enough to read from across the room.
- A visible legend of the color grammar taped up where everyone can see it.

---

## Timeboxing

Event Storming is deliberately time-pressured; the pressure is what produces
volume and prevents premature polishing.

| Level | Rough duration | Rhythm |
|---|---|---|
| Big Picture | A full day (or several hours minimum) | Short timeboxed passes, frequent stand-back-and-walk-the-wall |
| Process Level | Half a day per process | One process at a time; do not fan out until the first is solid |
| Design Level | Half a day | Cluster, name, box, justify |

Keep each pass short (10–20 minutes) then regroup. A pass that runs long turns
divergent exploration into convergent bikeshedding.

---

## Big Picture — Pass by Pass

1. **Kickoff & chaotic dump.** Prompt: *"Write down everything that happens in
   this domain — every event, something that already happened, in the past
   tense — one per orange card. Don't organize, don't discuss, just write."*
   Silence and speed. Aim for volume, including the ugly cases.
2. **Enforce the timeline.** Together, order the orange cards left to right in
   the sequence they occur in the real domain. Duplicates get stacked, near-
   duplicates get reconciled by the room (or become a hotspot).
3. **Enforce the language.** Walk every card: past tense? business-meaningful?
   Rewrite `DatabaseRowInserted` into `DataAssetRegistered`; demote anything
   present/future into a Command or a goal to handle later.
4. **Narrative walk.** Read the timeline aloud, left to right, as a story: *"A
   Data Steward connects a source, then the source is scanned, then assets are
   discovered, then…"* Every gap in the story is a missing-event signal.
5. **Provoke the unhappy path.** Explicitly ask *"what goes wrong here?"* —
   failures, rejections, timeouts, disputes. The domain's hardest rules live in
   the exceptions; a happy-path-only wall produces naive Aggregates.
6. **Mark hotspots.** Every point of confusion or disagreement gets a red card,
   placed on the offending event. Do not resolve — record and move on.
7. **Pivotal events & vertical lines.** Identify the events that mark a phase
   change and draw a vertical divider across the timeline at each — the first
   cue of subdomain boundaries.
8. **Swim lanes / subdomain areas.** Group related events into named areas.
   These names become the first Bounded Context candidates.

---

## Process Level — Procedure

Pick one process (typically the span between two pivotal events). For every
orange Domain Event, work *right to left* asking:

1. **What Command caused this event?** → blue card to its left.
2. **Who issued that Command?** → yellow Actor, or…
3. **…did another Event trigger it automatically?** → purple Policy
   ("Whenever [Event], then [Command]").
4. **What did the Actor look at to decide?** → green Read Model.
5. **Does anything external produce or receive this?** → pink External System.

Every step must be traceable. An Event with no cause is a gap; a Command with no
Actor and no Policy is a gap.

---

## Design Level — Procedure

1. **Cluster into Aggregates.** Ask *"which Commands and Events happen to the
   same thing and must stay consistent together?"* Name the cluster.
2. **Name and box Bounded Contexts.** Group Aggregates that share one language
   and owner; the box edge sits where language changes.
3. **Justify every boundary** in writing — invariant for Aggregates, language/
   ownership change for Bounded Contexts.
4. **List the services** each Bounded Context implies (this repo defaults to one
   microservice per Bounded Context with per-tenant physical isolation).

---

## Hotspot Resolution (after the session)

Every red card must be resolved or explicitly deferred — never left to rot and
never settled mid-session by seniority.

| Hotspot type | Resolution approach |
|---|---|
| Language disagreement | Run a ubiquitous-language session; choose the canonical term |
| Process uncertainty | Schedule a domain-expert interview or a follow-up session |
| Technical-feasibility concern | Flag to the architect; record as an architecture risk |
| Missing domain knowledge | Identify the knowledge holder; schedule follow-up |
| Scope dispute | Escalate to Shafi — this is a product decision, not a modeling one |

Opportunities (green/lilac) go straight to the product backlog, not the risk
register.

---

## Transcription

Transcribe the wall into the skill's Output Format the **same day**. A physical
wall's information decays within days — people forget why a card was placed,
photos lose context, and downstream skills are forced to re-derive everything.
Every transcribed output row names the skill it feeds.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Design-first storming** — jumping straight to Aggregates/services | Boundaries come from architectural preference, not domain evidence; the session ratifies a foregone decision | Complete Big Picture first; let Aggregates emerge from clustering |
| **Technical events on the wall** — `DatabaseRowInserted`, `KafkaMessagePublished` | Describe implementation, crowd out the business narrative | Enforce Pass 3: every event meaningful to a domain expert |
| **Resolving hotspots by authority** — loudest/most-senior voice settles it | The disagreement is real domain knowledge; suppressing it hides a risk | Red card, move on; resolve after via the table above |
| **CRUD-lane sorting** — organize by entity ("all File events here") | Recreates a data model, destroys the temporal narrative that reveals causality | Keep the timeline temporal; group into subdomains only at Pass 8 |
| **Happy-path only** — no failure/dispute/timeout events | The domain's hardest rules live in exceptions; produces naive Aggregates | Explicitly prompt "what goes wrong?" in the dump and the walk |
| **Facilitator writes all the cards** | Participants disengage; the model reflects the facilitator, not the room | Everyone writes; the facilitator sequences and questions |
| **Storming without a domain expert** | Every card is a guess; hotspots can't be told from facts | Require a first-hand expert or run discovery interviews first |
| **Wall archaeology** — cards never transcribed | Outputs decay within days; downstream skills re-derive everything | Transcribe into the Output Format the same day |
| **Running out of wall** — too small a surface | Silently biases the model toward brevity, dropping real events | Use an unlimited surface (long paper roll / infinite canvas) |
