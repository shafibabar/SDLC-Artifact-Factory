# Domain Storytelling — Session Facilitation Guide

Self-contained reference for facilitating a Domain Storytelling session from
pre-session planning through post-session handoff. Usable independently of
`skills/domain-storytelling/SKILL.md` being in context.

---

## Pre-Session: Who to Invite

### Participant Roles and Count

| Role | Count | Responsibility |
|---|---|---|
| **Domain expert** (narrator) | 1 per session | Tells the story — the person who actually does the work described |
| **Facilitator** (domain-modeler agent) | 1 | Draws the story; keeps the session discipline |
| **Observers** | 1–3 (engineers, PM) | Ask clarifying questions in Step 4 only — not during narration |

**Maximum group size: 6 participants total (narrator + facilitator + observers).**
More than six turns storytelling into a committee meeting. Each additional voice
beyond the narrator creates pressure to negotiate a "consensus story" that matches
nobody's actual work. When multiple domain experts disagree about the workflow, run
separate sessions and compare the stories afterward — don't merge them in the room.

**Who to choose as narrator:**
- The person who performs the work being modelled daily, not the manager who oversees it
- Someone who has worked the domain long enough to know the exceptions, not only the
  happy path
- Avoid architects or analysts as narrators — they tend to describe the system as it
  should be, not as it is

**Who to choose as observers:**
- Engineers who will implement the Bounded Context the story is exploring
- A product manager who needs to understand the workflow's vocabulary
- A second domain expert who may be invited to narrate a variation scenario afterward

### Scenario Selection

The most important preparation decision is choosing the right scenario to start with.

**Criteria for a good starting scenario:**
- Concrete and specific — a real situation that has happened, not a general process
- Contains the workflow the team most urgently needs to understand
- Within the narrator's direct experience — they were there, they did it themselves
- A reasonably complete end-to-end flow — from a clear trigger to a clear outcome

**Example scenario prompts (use one to frame the session):**
- "Tell me about the last time you had to prepare a compliance report from scratch."
- "Walk me through what happens from the moment a new storage source is connected."
- "Tell me about a time when you found a data risk you hadn't expected."
- "Walk me through a typical day when a new dataset arrives that needs to be classified."

**Avoid:**
- "How does the classification process work?" — invites a general description, not a story
- "What are the steps in the data-onboarding workflow?" — asks for a procedure, not a narrative
- A scenario involving exceptional or pathological edge cases as the *primary* story — those
  belong in variation scenarios after the primary story is validated

### Setup (Miro or Physical Whiteboard)

| Setup item | Guidance |
|---|---|
| Blank canvas | Start with an empty board — no pre-drawn Actor boxes or Work Object slots |
| Colour legend | Create a small legend: human Actor colour, system Actor colour, external Actor colour, Work Object colour |
| Clock | Set a visible timer — target 45–60 minutes for primary story + one variation |
| Notation card | Display the five element types (from `references/notation-guide.md`) where the narrator can see them |

Do not pre-populate the canvas with actors or work objects you expect to find. The
discipline of discovering them during narration is the mechanism by which Ubiquitous
Language candidates emerge.

---

## Session Opening Script

### Explain the Method (2 minutes)

Open with a brief explanation before asking the narrator to begin:

> "We're going to draw a picture of how you work. I'll ask you to tell me a story —
> a real, specific situation you've been through — and I'll draw it as you talk.
> Every time you mention a person or system, I'll draw a shape for them. Every time
> you mention something you work with — a document, a record, a file — I'll draw
> a box for it. And every time you do something, I'll draw an arrow connecting those shapes.
>
> After you've told the story, I'll read it back to you from the picture, and you'll
> tell me if I got it right. That's all."

### Demonstrate with One Example Sentence (2 minutes)

Before the narrator begins, model the method with one example sentence from a
completely different domain (do not use an example from the domain being modelled):

> "For instance, if I said 'The librarian checks out a book to a patron', I'd draw
> a person shape for the librarian, a book shape for the book, and an arrow labelled
> 'checks out' from the librarian to the book, with the number 1 on it."

Draw this on the canvas. It shows the narrator exactly what the model will look like
and removes any anxiety about the output.

### Ground Rules (30 seconds)

State three ground rules before the story begins:

1. **No software concepts** — use your own words, not technical vocabulary
2. **No "the system"** — if the story involves software, say which software or which team
3. **No interruptions** — tell the full story first; questions come after

---

## Story Collection Protocol

### Step 1 — Invite the Narrative

Ask the opening question you prepared in the pre-session scenario selection.
After the narrator begins, stay silent and draw. Do not redirect or probe during narration.

**Your drawing discipline:**
- Mention of a role or person → draw an Actor (correct type per `references/notation-guide.md`)
- Mention of something they work with → draw a Work Object (correct shape)
- Mention of an action → draw a numbered Activity arrow from Actor to Work Object
- Mention of a condition or exception → draw an Annotation on the arrow
- Mention of an external system → draw an External Actor (dashed border)
- Handoff to a different team or role → mark a tentative boundary group

If the narrator outpaces your drawing, say: "Hold on — let me catch up with you."
It is better to slow the narrator briefly than to lose a step in the sequence.

### Step 2 — Transcribe Each Sentence

As you draw each activity, confirm the sentence structure is preserved:

- Does the arrow have exactly one verb? (If the narrator said "I classify and record", draw two arrows)
- Does the verb label use the narrator's exact word? (Not your synonym — their word)
- Is the Work Object named in the narrator's language? (Not your implementation term)

**What to do if the narrator uses a technical term in pure mode:**
Do not correct them in the moment — they may not know they did it. Record the term.
After the session, flag it: "You mentioned 'data pipeline' at step 7 — is that the
word your colleagues all use, or is there a business term for it?"

### Step 3 — When to Stop

Stop collecting the story when:
- The narrator says "and that's it" or "then we're done"
- The story loops back to a state that already appeared (the workflow is cyclic — note where the cycle is)
- The story has exceeded 30 steps without reaching an end (the scenario is too broad — stop and scope it down)

If the story is not reaching a natural end, gently redirect: "What does done look like?
What tells you this situation is resolved?"

---

## Validation Pass (Step 4)

After the narrator finishes, read the story back from the pictogram:

> "Let me read back what I drew. First, [Actor A] does [Activity 1] with [Work Object 1].
> Then [Actor A] does [Activity 2] with [Work Object 2]. Then [Actor B]..."

Read every step. After each three or four steps, pause and say: "Does that look right?"

**When the narrator corrects you:**
- Update the drawing immediately
- If they correct the vocabulary ("I didn't say 'reviews' — I said 'checks'"), change the label
- If they correct the sequence ("that happens before step 3, not after"), renumber
- Do not defend the drawing — it exists to capture their reality, not to represent your interpretation

**What the validation pass reveals:**
- Steps the narrator mentioned quickly that the model missed
- Actors implied but not explicitly stated ("the system sends an alert" — to whom?)
- Work Objects that are created during a step but not shown receiving a downstream activity

---

## Clarifying Questions (Step 5, Observers)

After the validation pass, observers may ask **one round** of targeted questions.
Questions must be about what is already on the board — not about what is missing.

**Good observer questions:**
- "At step 3, you mentioned a 'flagged document' — is that the same thing as a 'Classification Alert'?" (term disambiguation)
- "Where does the Work Object at step 2 come from before step 1?" (origin discovery)
- "Who at the Storage Owner side actually receives the Access Review request?" (boundary clarification)

**Bad observer questions (defer these to variation scenarios):**
- "What happens if the Storage Owner never responds?" (edge case — this is a variation scenario)
- "Could we automate step 4?" (design suggestion — not a discovery question)
- "Why does step 6 happen before step 5?" (design critique — the story shows what is, not what should be)

Record new terms, boundary clarifications, and conditions from this round as annotations
on the drawing or in the "Terms Discovered" table of the Domain Story artifact.

---

## Pure → Annotated Transition

After the pure story is validated, you may add software-layer labels if needed.

**Transition protocol:**

1. Tell the narrator: "The story is captured correctly. I'm now going to add some software
   labels so the engineers can connect it to our design — the story itself doesn't change."
2. Go through the Work Objects: for each one, ask: "In our system, what would we call this?"
   Add the software name as an annotation, not a replacement.
3. Go through the System Actors: confirm which microservice or module owns each one.
4. Mark any External Actors with their integration protocol if known (REST API, Google Drive API).

**Do not change the narrator's vocabulary** in the pure model. The annotated model is
an overlay — the domain expert's words remain on the drawing, with software names added
alongside them.

---

## Variation Scenarios

After the primary story and its validation, run one or two variation scenarios.

### Which Variations to Choose

| Variation type | Purpose | Example prompt |
|---|---|---|
| Exception path | Reveals error handling, escalation paths, edge cases | "What happens when the Storage Owner never responds to the Access Review?" |
| Alternate actor | Shows the same workflow from a different role's perspective | "Walk me through the same situation from the Storage Owner's point of view." |
| Negative case | Exposes what happens when a condition is false | "What happens when the DataAsset fails the Restricted check?" |
| System failure | Surfaces resilience concerns | "What do you do if the Classification Service is unavailable?" |

### Variation Protocol

1. Ask the variation prompt
2. Draw only the steps that differ from the primary story — reference the primary story
   steps that remain the same by number ("steps 1–3 are the same, then...")
3. Number variation steps with a suffix (e.g., steps 4a, 4b, 4c) to keep them distinct
4. Validate the variation story the same way as the primary
5. Record variation-specific terms and boundary markers

---

## Post-Session: Feeds Forward

Every session must end with the "Feeds Forward To" table in the Domain Story artifact completed.

| Common output | Where it goes |
|---|---|
| New Ubiquitous Language candidates | `ubiquitous-language` skill — verify against existing glossary |
| Synonym conflicts discovered | `ubiquitous-language` skill — resolve to a canonical term |
| Bounded Context boundary candidates | `bounded-context-mapping` skill — feed to BC workshop |
| Variation scenarios revealing exception flows | `acceptance-criteria` skill — these become Gherkin scenario outlines |
| Policy candidates ("whenever X happens, Y must occur") | Event Storming board — these are Policy sticky notes |
| Aggregate operation candidates | `aggregate-design` skill — verbs from fine-grained stories map to Aggregate command methods |

---

## Common Facilitation Failure Modes

| Failure mode | Symptom | Correction |
|---|---|---|
| **Designing while drawing** | The facilitator draws the system they intend to build, not the story being told | Draw only what the expert says, in the expert's words |
| **Translating on the fly** | The facilitator replaces the expert's words with technical terms during narration | Record the exact term; reconcile afterward via `ubiquitous-language` |
| **Committee storytelling** | Multiple experts narrating simultaneously; story becomes a negotiated average | One narrator per story; run additional sessions for other perspectives |
| **Abstract process description** | Narrator says "usually what happens is..." — general description, not a story | Redirect: "Tell me about a specific time, last week or last month..." |
| **Interrogation instead of narration** | Observers interrupting with questions throughout narration | Enforce the ground rule: questions only after the validation pass |
| **Happy path only** | No variation scenarios run; exceptions never surfaced | Always run at least one variation after the primary story |
| **Shelfware story** | Session output filed; "Feeds Forward To" table empty | Require the completed table before closing the session artifact |
