# Domain Storytelling — Pictogram Notation Guide

Self-contained reference for drawing and reading Domain Story pictographic models.
Usable independently of `skills/domain-storytelling/SKILL.md` being in context.

---

## The Fundamental Rule: One Sentence Per Arrow

Every arrow in a Domain Story represents exactly one sentence of the form:

> **[Actor]** → **(numbered, activity-labelled arrow)** → **[Work Object]**

No arrow may carry two activities. No activity may span two work objects without two
separate arrows. This rule enforces the core discipline of Domain Storytelling: the
model is the sentence, nothing more. When a facilitator is tempted to draw a single
arrow that "does two things," the signal is that the domain expert's narrative contains
two distinct steps — draw two arrows.

**Why this matters for Ubiquitous Language:** Each arrow captures one verb in the
domain expert's vocabulary. A compound arrow like "classifies and records" destroys two
distinct verbs into one. Separate arrows preserve both verbs as individual, named
activities that become Ubiquitous Language candidates in their own right.

---

## Element Shapes

### Actor Shapes

An Actor is any person, system, or role that performs or receives an activity.

| Actor type | Visual shape | When to use | Example |
|---|---|---|---|
| **Human Actor** | Circle with head-and-shoulders silhouette (person icon) | A human role — never an individual by name | Compliance Officer, Data Steward, Storage Owner |
| **System Actor** | Rectangle with rounded corners and a small monitor or server icon | Software system owned by the team (internal) | Classification Service, Graph Projector |
| **External Actor** | Dashed-border rectangle | A system or organisation outside this team's boundary | Google Drive, Okta, Audit Authority |

**Rule:** Actors are roles, never named individuals ("Yuki" → "Data Steward"). Naming
an individual produces a model that is true only for that person. Naming a role produces
a model that is true for anyone in that role.

**Rule:** External Actors reveal Bounded Context boundaries. When a story crosses from
an internal Actor to an external system, the handoff point is where Context Map
integration patterns apply (Published Language, Anti-Corruption Layer, Conformist, etc.).

**Rule:** "The system" is not a valid Actor name. If an expert says "then the system
does...", ask: "which system?" or "which team or service owns that step?" The answer
names either an internal System Actor (if owned by this team) or an External Actor (if
not owned by this team).

### Work Object Shapes

A Work Object is a thing that Actors work with — it is passed, created, reviewed,
modified, or consumed during an activity.

| Work Object type | Visual shape | When to use | Example |
|---|---|---|---|
| **Document** | Rectangle with folded upper-right corner | A human-readable document or form | Compliance Report, Audit Record, Incident Note |
| **Data Object** | Plain rectangle | A structured data item or record in a system | DataAsset, Classification Result, StorageSource |
| **Physical Object** | Rectangle with 3D-depth outline | A tangible physical thing | Storage Device, Printed Report |
| **Conversation / Message** | Speech bubble or rounded rectangle | A spoken exchange, notification, or alert | Slack Notification, Email Alert, Classification Alert |

In practice for software domain modelling, most Work Objects are Data Objects.
Documents appear when a human-readable artifact is the subject of an activity
(filling, reviewing, signing). Physical objects appear rarely in digital domains.

**Naming rule:** Use the same name for a Work Object that the domain expert uses.
If the expert says "the file" and the model says "DataAsset", the model is wrong.
Record the expert's term; reconcile with the canonical Ubiquitous Language afterward
via the `ubiquitous-language` skill — not during the session.

### Activity (Labelled Arrow)

An Activity is the verb connecting an Actor to a Work Object. In a Domain Story
pictogram it is drawn as a directed, labelled arrow:

```
[Actor] ---(step N: "classifies")---> [Work Object]
```

**Placement:** The step number appears on or above the arrowhead, at the midpoint of
the arrow. The activity label (the verb) appears beside the step number.

**Label rules:**
- Use the domain expert's exact verb — not a synonym, not a normalised technical verb
- Use the simple present tense: "classifies", not "classification" or "is classifying"
- Keep the label to one or two words; longer labels are usually a compound activity

### Annotation

An Annotation adds context to an activity or work object — a condition, a constraint,
a business rule, or a clarification the expert stated while narrating.

| Visual shape | When to use |
|---|---|
| Rounded rectangle (sticky note style) | Attach to an arrow or a work object to capture a business rule or condition expressed during narration |

**Examples of annotations:**
- On an activity: "only if previous scan completed"
- On a work object: "must be reviewed within 5 business days"
- On a boundary marker: "Google Drive API call — rate-limited"

Annotations are not required for every step. Use them when the expert says something
that qualifies or constrains the activity — "I always check...", "only when...",
"unless...". These are invariant or policy candidates.

### Sequence Numbers

Sequence numbers order the activities into a readable story. Conventions:

| Convention | Guidance |
|---|---|
| Left-to-right, top-to-bottom | Primary story flow; step 1 at upper left, last step at lower right |
| Gaps in the sequence | Use gaps to leave room for variation steps (e.g., steps 1–5 primary, steps 5a–5c for a variation) |
| Concurrent activities | Two arrows with the same step number represent activities that happen in parallel |

**Concurrent activities:** when an Actor performs two activities simultaneously (e.g.,
"sends an alert to the Compliance Officer and records the Classification Result at the
same time"), draw two arrows from the same Actor, both labelled with the same step
number. This is the only case where a single step number appears more than once.

### Boundary Marker (Group / Dashed Box)

A dashed rectangle groups related elements — Actors, Work Objects, Activities — that
belong to the same team, department, or system boundary. When a story crosses the
boundary line between two boxes, the crossing point is a Bounded Context boundary
candidate or an integration seam.

---

## Reading a Domain Story

To read a completed Domain Story from the pictogram:

1. Find step 1 — the first numbered arrow
2. Read the sentence: "[Source Actor] [Activity verb] [Work Object]"
3. Follow the next numbered arrow; if the Work Object from step N is the actor's input
   in step N+1, draw that connection explicitly with a second arrow
4. At every External Actor boundary crossing, note the integration handoff
5. At every annotation, record the business rule or condition it states

A correctly drawn Domain Story should be fully readable as a series of sentences by
someone who was not in the room when it was drawn.

---

## Anti-Patterns: What Domain Storytelling Is NOT

These shapes appear frequently in other notations but have no place in Domain
Storytelling. Their use signals that the facilitator has imported a different notation.

| Anti-pattern | What it looks like | Why it fails |
|---|---|---|
| **Decision diamond** | Diamond-shaped branch node (as in flowcharts) | Domain Stories are narratives, not flow-control diagrams. A diamond hides the two different stories the expert would tell for each branch. Draw two separate stories: the primary and the variation. |
| **Swim lanes** | Horizontal or vertical bands separating actors | Swim lanes flatten the sequential narrative into a parallel grid, making the story harder to read as sentences. Actor columns in a Domain Story kill the subject-verb-object flow. |
| **Flowchart shapes** | Terminator, process, data shapes (rounded rectangles, parallelograms, etc.) | Domain Storytelling has exactly five element types. Any shape from BPMN, UML, or flowchart notation imported into a Domain Story introduces ambiguity — does that rounded rectangle mean "Actor", "Annotation", or "Process"? |
| **The "system" as a catch-all Actor** | A single box labelled "System" or "Platform" receiving multiple unrelated activities | This is the single most common Domain Storytelling error. "The system" is opaque — it hides the question of *which* actor (which team, which service) actually does the work. Each step attributed to "the system" must be interrogated: "Which team owns this step?" |
| **Compound arrows** | A single arrow labelled "classifies and records" or carrying two activity verbs | Violates the one-sentence-per-arrow rule. Split into two arrows. |
| **Technology-first Work Objects** | Work Objects named with implementation concepts ("database row", "API response", "microservice call") in a pure story | Pure mode is domain language only. Technology names appear only in annotated mode, added explicitly after the pure story is validated. |

---

## Miro Board Element Mapping

For distributed facilitation in Miro, use these built-in element types to represent
each pictogram:

| Domain Storytelling element | Miro element | Notes |
|---|---|---|
| Human Actor | Miro "Person" smart shape, or a circle with a head-and-shoulders icon | Use a consistent colour across all human actors in the same Bounded Context |
| System Actor (internal) | Miro rounded rectangle (blue fill) | Distinguish from External Actors by colour |
| External Actor | Miro rounded rectangle (grey fill, dashed border) | Dashed border signals "outside our boundary" |
| Work Object — Data Object | Miro plain rectangle (white fill, solid border) | Label in the domain expert's exact words |
| Work Object — Document | Miro sticky note, or a rectangle with a folded corner graphic | Use consistently for human-readable documents |
| Activity arrow | Miro connector (arrow) with label for verb and bold number for step | Enable "smart" connectors so arrows reflow when elements move |
| Annotation | Miro sticky note attached to the connector or work object | Yellow or orange to distinguish from Work Objects |
| Boundary / Group | Miro frame or dashed rectangle | Label the frame with the team or system name |

**Miro session tips:**
- Lock Actor and Work Object elements once placed — experts often want to move them;
  locking prevents accidental displacement mid-narration
- Create a colour legend in the top-left corner of the board at session start
- Use separate Miro frames for the primary story and each variation scenario
- Export the board as an image after the session; embed it in the Domain Story artifact
  under the "Story Steps" section as a visual supplement to the table

---

## Quick Reference Card

```
Actor (human)    ●‿● — a role, never a name
Actor (system)   [■■] — owned by this team
Actor (external) [▫▫] — dashed border, outside our boundary

Work Object      [  ] — plain rectangle, expert's own term

Activity        ─── N: verb ──→ — numbered, one verb only
Annotation       └(note) — condition or rule attached to arrow/object

Rule 1: One sentence per arrow — one Actor, one Activity, one Work Object
Rule 2: Actor names are roles; Work Object names are the expert's exact words
Rule 3: Pure mode = zero technical vocabulary until the story is validated
Rule 4: External Actors mark Bounded Context boundary candidates
Rule 5: Concurrent activities share the same step number
```
