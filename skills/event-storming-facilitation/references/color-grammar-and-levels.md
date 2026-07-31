# Color Grammar and the Three Levels — In Depth

This reference gives the precise meaning of every Event Storming sticky-note
color (Alberto Brandolini's standard grammar), the modeling element each maps
to, and each of the three levels in full with explicit entry and exit criteria.
The `SKILL.md` body carries only the compact legend and a level summary; this
file is the authoritative version.

---

## The Color Grammar

Event Storming is a *notation*, not just a brainstorm. The color of a sticky
note is a strict type declaration — a modeler reading the wall must be able to
tell a Domain Event from a Command from a Policy at a glance, without reading
the text. Never mix meanings across colors, and never invent a new color
mid-session without agreeing it with the room first.

### Orange — Domain Event

- **Meaning:** something that *happened* in the domain, stated in the past tense,
  significant to the business (never a technical side effect).
- **Maps to:** a Domain Event in the domain model — the immutable record of a
  fact. Domain Events are Evans' own post-2003 addition to the DDD tactical
  pattern set; they are the primary currency of Event Storming.
- **Naming:** `<Noun><PastTenseVerb>` — `DataAssetRegistered`, `ScanCompleted`,
  `DataAssetClassified`, `RetentionPeriodExpired`. Never `RegisterDataAsset`
  (that is a Command) and never `DatabaseRowInserted` (that is implementation).
- **Test:** could a domain expert who has never seen the code confirm this
  actually happens in their world? If not, it is not a Domain Event.

### Blue — Command

- **Meaning:** an instruction given to the system, in the imperative present —
  the *intent* that, if accepted, produces a Domain Event.
- **Maps to:** a Command in the CQRS write model. Exactly one Aggregate handles
  each Command.
- **Naming:** `<Verb><Noun>` — `ClassifyDataAsset`, `RequestAccessReview`.
- **Relationship:** a Command sits immediately to the *left* of the Event(s) it
  produces. A Command that produces no Event is a gap or a query in disguise.

### Yellow (small) — Actor / Role

- **Meaning:** a person or role who decides to issue a Command. In this repo's
  product the recurring Actors are **Data Steward** and **Compliance Officer**.
- **Maps to:** an actor/persona in the model; informs authorization design
  (Attribute-Based Access Control) later, not during storming.
- **Placement:** to the left of the Command it triggers.

### Yellow (large) — Aggregate

- **Meaning:** the "thing" that receives a Command, enforces its invariant, and
  emits the resulting Domain Event. Discovered at Design Level, not before.
- **Maps to:** an Aggregate (a transactional-consistency boundary). See the
  `aggregate-design` skill for the boundary rules; storming only surfaces the
  candidate cluster.
- **Placement:** between the Command and the Event, sitting under both.

### Purple — Policy (Reaction)

- **Meaning:** an automation or business reaction rule of the exact form
  "**Whenever** [Domain Event], **then** [Command]." Policies capture the
  "the system should automatically…" statements domain experts make.
- **Maps to:** a Policy / Process Manager / event handler that turns one
  context's Event into another Command — the seam where Event Choreography lives.
- **Example:** "Whenever `DataAssetClassified` with SensitivityLevel = Restricted,
  then `RequestAccessReview`."

### Green — Read Model

- **Meaning:** the view or query result an Actor looks at *before* deciding to
  issue a Command. It is what the human needs to see to act.
- **Maps to:** a Read Model in CQRS (see `read-model-design`).
- **Example:** "Unclassified Assets Queue" that a Compliance Officer scans.

### Pink — External System

- **Meaning:** a system outside this domain's boundary — a third party or
  another team's service — that either produces or consumes events at the edge.
- **Maps to:** an integration point; every pink card implies an Anti-Corruption
  Layer question for `bounded-context-mapping`.
- **Example:** Google Drive, Amazon S3, an external DLP scanner.

### Red — Hotspot

- **Meaning:** a point of conflict, uncertainty, disagreement, or missing
  knowledge. Recorded, **never resolved on the wall.**
- **Maps to:** an entry in the architecture risk register; resolved after the
  session (see `facilitation-guide.md`).

### Green (small) / lilac — Opportunity

- **Meaning:** an insight about a *better* way the process could work — parked
  for the backlog, not acted on during the session.

### Pivotal Events and the vertical divider

Some Domain Events are **pivotal events** — they mark a change of phase in the
domain narrative (e.g. `DataAssetClassified` separates ingestion from
compliance). Draw a **vertical line** straight down across the whole timeline at
each pivotal event. These vertical dividers are the first visual cue of where
subdomain and Bounded Context boundaries will fall — they frequently coincide
with the language changing on either side. This is Brandolini's standard
big-picture technique for finding candidate boundaries before any box is drawn.

---

## Level 1 — Big Picture

**Purpose:** explore the entire domain landscape and build a shared narrative.
Breadth over precision.

**Entry criteria:**
- The domain/subdomain in scope is named.
- At least one participant with first-hand domain knowledge is present (a Data
  Steward and/or Compliance Officer for this product). Without one, run
  discovery interviews first — storming from engineer assumption produces a wall
  of guesses.

**Activity:** chaotic orange-only dump → enforce the timeline → narrative walk →
mark hotspots → draw vertical lines at pivotal events → group into rough
subdomain areas (swim lanes).

**Exit criteria (all must hold before Process Level):**
- The timeline reads as a coherent left-to-right story with no unexplained gaps.
- Every card is past tense and business-meaningful.
- Pivotal events are marked and candidate subdomain areas are named.
- Every disagreement is captured as a red hotspot rather than argued out.

**Output:** complete event timeline, hotspot list, rough subdomain boundaries.

---

## Level 2 — Process Level

**Purpose:** zoom into ONE process identified at Big Picture and reconstruct its
full cause-and-effect chain.

**Entry criteria:**
- Big Picture is complete and its exit criteria met.
- The single process to zoom into is chosen (usually one bounded by two pivotal
  events).

**Activity:** for every orange Event, add the blue Command that caused it, the
yellow Actor or purple Policy that issued that Command, the green Read Model the
Actor consulted, and any pink External System at the edge. The target shape:

```
[Read Model] → (Actor) → [Command] → {Aggregate} → <Domain Event> → «Policy» → [Command] → …
```

**Exit criteria (all must hold before Design Level):**
- Every Domain Event traces back to a Command (issued by an Actor or a Policy) —
  no orphan events.
- Every Policy is written in "Whenever … then …" form.
- Every External System interaction is on the wall as a pink card.

**Output:** detailed process flow with cause and effect for one process.

---

## Level 3 — Design Level

**Purpose:** derive Aggregates and Bounded Context candidates from the modeled
process.

**Entry criteria:**
- At least one process is modeled to Process-Level completeness.

**Activity:**
- **Aggregate discovery:** cluster the Commands and Events that happen to the
  *same conceptual thing and share one true invariant*. Name each cluster — the
  name enters the Ubiquitous Language. The boundary is justified by the
  transactional-consistency rule, not by "these all touch the same table."
- **Bounded Context discovery:** group Aggregates that share one Ubiquitous
  Language and one owner into a box. The box boundary sits where the language
  changes meaning — often exactly at a pivotal event's vertical line.

**Exit criteria:**
- Every Command is handled by exactly one named Aggregate.
- Every Aggregate has at least one stated invariant justifying its boundary.
- Every Bounded Context boundary is justified by a language change or ownership
  change, and named in the Ubiquitous Language.

**Output:** Aggregate candidates, Bounded Context candidates, service list — the
handoff into `aggregate-design` and `bounded-context-mapping`.

---

## Why the order is non-negotiable

Jumping to Design Level first means the boundaries get drawn from architectural
preference, and the session merely ratifies a decision someone already made. The
whole value of Event Storming is that boundaries *emerge* from the clustered
evidence of Commands and Events — which only exists after Big Picture and
Process Level have put that evidence on the wall.
