---
name: domain-storytelling
description: >
  Teaches how to use Domain Storytelling (Stefan Hofer & Henning Schwentner) —
  a pictographic modelling technique where domain experts narrate how they work
  while a modeller draws the story using actors, work objects, and activities.
  Domain Storytelling surfaces Ubiquitous Language, validates Bounded Context
  boundaries, and complements Event Storming by revealing the human narrative
  behind the event flow. Used by the domain-modeler agent at the start of the
  Design phase, typically before or alongside Event Storming.
version: 1.1.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, ddd, domain-storytelling, ubiquitous-language, discovery, bounded-context]
---

# Domain Storytelling

## Purpose

Domain Storytelling is a collaborative modelling technique where a domain expert tells a story about how they do their work while a facilitator draws it using a simple pictographic notation. The goal is to build a shared understanding of the domain by listening to real stories, not by designing abstract models.

Where Event Storming asks "what happened?", Domain Storytelling asks "who does what with what?" The two techniques are complementary: Event Storming maps the event flow; Domain Storytelling reveals the actors, work objects, and activities that produce that flow.

---

## The Pictographic Language

Domain Storytelling uses a minimal notation with five elements:

| Element | Symbol | Description |
|---|---|---|
| **Actor** | Person icon (circle with stick figure) | A person or group doing work — a role, not an individual |
| **Work Object** | Rectangle | A thing that actors work with — a document, a system, a data item |
| **Activity** | Arrow with a number | An action an actor performs on a work object, or that transfers a work object between actors |
| **Annotation** | Rounded rectangle | Context, condition, or clarification — optional |
| **Group / Boundary** | Dashed box | A team, department, or system boundary that groups related elements |

The numbers on activities create a sequence — story step 1, step 2, step 3 — making the story readable left-to-right, top-to-bottom.

---

## Running a Domain Storytelling Session

### Who should be in the room

- 1 domain expert (the narrator)
- 1 modeller (draws the story while the expert narrates)
- 1-2 observers (ask clarifying questions — engineers or product manager)

Do not pack the room. Too many participants turns storytelling into a committee meeting.

### The Session Protocol

**Step 1 — Choose a scenario**

Pick one concrete scenario — a real situation the domain expert has encountered. Not a general process description ("usually what happens is..."), but a specific story ("last Tuesday, Yuki needed to...").

Example prompts:
- "Tell me about the last time you had to prepare a compliance report."
- "Walk me through what happens from the moment a new storage source is connected."
- "Tell me about a time when you discovered a data risk you didn't know about."

**Step 2 — Let the expert narrate**

The domain expert tells the story in their own words. The modeller draws each element as the expert mentions it:
- Mention of a person or role → draw an Actor
- Mention of something they work with → draw a Work Object
- Mention of an action → draw an Activity (numbered arrow)

Do not interrupt to correct or design. Draw what you hear. Let the story flow.

**Step 3 — Read the story back**

After the expert finishes, the modeller reads the drawn story back: "So first, [Actor] does [Activity 1] with [Work Object 1]... then [Actor] does [Activity 2]..."

The expert corrects anything that was drawn incorrectly. This is the validation step.

**Step 4 — Ask clarifying questions**

After validation, observers may ask one round of targeted questions:
- "What do you call this work object — I've heard it called both 'file' and 'document'?" (term discovery)
- "Where does this work object come from?" (origin discovery)
- "What happens if [edge case]?" (exception scenario)

Record new terms, boundaries, and conditions as annotations on the drawing or as separate notes.

**Step 5 — Run variation scenarios**

After the primary story, run one or two variations:
- "What happens when the storage source is disconnected during a scan?"
- "What if the classification result is disputed?"

Variations reveal exceptions, edge cases, and alternate flows that the primary story hides.

---

## What to Look for

While drawing, actively watch for:

| Signal | Implication |
|---|---|
| The expert uses a term you haven't heard before | New Ubiquitous Language candidate |
| The same work object is called two different names | Synonym conflict — ask which is canonical |
| An actor does something "to the system" without naming what system | External System or another Bounded Context |
| The expert says "then IT does something..." | Team or system boundary — potential Bounded Context boundary |
| The story stops and the expert says "well, it depends..." | Exception or policy — explore it |
| An activity involves someone outside the team | Collaboration pattern — maps to a context relationship pattern |
| The expert draws a distinction you missed | The model is wrong — update it |

---

## Output from Domain Storytelling

A Domain Storytelling session produces:

| Output | Feeds |
|---|---|
| Named Actors | Ubiquitous Language (Actor types) |
| Named Work Objects | Ubiquitous Language (domain concepts) |
| Numbered Activity sequence | Event Storming (command/event flow) |
| Boundary markers | Bounded Context candidates |
| New terms discovered | `ubiquitous-language` skill |
| Exceptions and edge cases | `acceptance-criteria` skill (edge cases) |
| Synonym conflicts | `ubiquitous-language` skill (synonym elimination) |

---

## Scope Levels

Domain Storytelling can be run at two scopes:

| Scope | Zoom level | Use for |
|---|---|---|
| **Coarse-grained** | Organisation or product level | Discovering Bounded Contexts; understanding the big picture before Event Storming |
| **Fine-grained** | One process or feature | Validating a specific workflow; discovering edge cases for a user story |

Start coarse-grained, then zoom into the fine-grained for processes identified as complex or contentious in the coarse-grained session.

---

## Worked Example

Fine-grained story: "The compliance officer investigates a newly flagged Restricted document."

| Step | Actor | Activity | Work Object | Annotation |
|---|---|---|---|---|
| 1 | Compliance Officer | reviews | Classification Alert | Alert raised when a DataAsset was classified Restricted |
| 2 | Compliance Officer | opens | DataAsset detail view | Shows SensitivityLevel, StorageSource, extracted entities |
| 3 | Compliance Officer | checks | StorageSource permissions | "I always check who can see the folder it lives in" |
| 4 | Compliance Officer | requests | Access Review | Sent to the storage owner — a different team |
| 5 | Storage Owner | confirms or amends | Sharing Settings | Boundary: this happens in Google Drive, outside our system |
| 6 | Compliance Officer | records | Audit Record | "If I don't write it down, the auditor assumes it never happened" |

Discoveries from this story:
- **Term:** the expert said "flagged document", never "classified asset" — candidate synonym conflict for the Ubiquitous Language (`DataAsset` vs "document"); resolved to keep `DataAsset` in the model and "document" only in UI copy.
- **Boundary marker:** step 5 crosses into Google Drive — confirms the Storage Integration context boundary and its ACL.
- **Policy candidate:** "whenever a DataAsset is classified Restricted, an Access Review is requested" — feeds Event Storming as a Policy following the `DataAssetClassified` Domain Event.
- **Variation explored:** "what if the storage owner never responds?" → escalation after 5 business days — an edge case for `acceptance-criteria`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Concrete scenario | Session uses a specific story from real experience | General process description ("usually...") |
| Story read back | Modeller reads the drawn story back; expert corrects it | Story drawn but never validated with the expert |
| New terms captured | All new Ubiquitous Language candidates are noted | Terms used by the expert but not recorded |
| Variation scenarios | At least one exception or alternate flow explored | Only the happy path told |
| Boundary markers | Actor-to-actor handoffs across team or system boundaries are marked | All activities treated as within one boundary |
| Feeds forward | Session output explicitly maps to downstream artifacts | Domain Storytelling output produced but not referenced by any other artifact |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Designing while drawing** — the modeller draws the system they intend to build, not the story being told | The session stops being discovery; the expert validates the modeller's assumptions instead of narrating reality | Draw only what the expert says, in the expert's words; design later, from the validated story |
| **Translating on the fly** — replacing the expert's words with technical vocabulary ("so, a record gets persisted...") | The Ubiquitous Language candidates are destroyed at the moment of capture | Write the expert's exact terms; reconcile them with the model afterwards via the `ubiquitous-language` skill |
| **Committee storytelling** — several experts narrating one story together | The story becomes a negotiated average that matches nobody's actual work | One narrator per story; run additional sessions to capture other perspectives, then compare |
| **Abstract process description** — "usually what happens is..." accepted as a story | Generalisations hide the exceptions and hand-offs that concrete stories reveal | Insist on one specific, remembered occasion with real (roleised) people and real objects |
| **Interrogation instead of narration** — observers interrupting with questions throughout | Breaks the expert's flow; the story fragments into answers shaped by the questions | Hold all questions until after the read-back (Step 4) |
| **Happy path only** | The costly behaviour lives in the exceptions; a happy-path model under-specifies the domain | Always run at least one variation scenario (Step 5) |
| **Shelfware story** — the drawing is filed and nothing downstream references it | The session cost is sunk; Event Storming and the glossary re-discover the same facts later | Every story ends with a filled "Feeds Forward To" table naming target artifacts |

---

## Output Format

```markdown
---
name: domain-story
product: [product name]
domain: [domain or subdomain name]
scenario: [one-line description of the story]
scope: [coarse-grained | fine-grained]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Domain Story: [Scenario Name]

## Participants
- **Domain expert:** [role]
- **Modeller:** domain-modeler agent
- **Observers:** [roles]

## The Story (narrative)
[Written narrative of the story as told by the domain expert — in their language]

## Story Steps (structured)

| Step | Actor | Activity | Work Object | Annotation |
|---|---|---|---|---|
| 1 | [Actor] | [Action] | [Work Object] | [Condition / context] |

## Boundary Markers
[Where did the story cross a team or system boundary? What was on each side?]

## Variation Scenarios
### Variation 1: [Scenario name]
[Steps for the variation]

## Terms Discovered
| Term as used | Type (Actor / Work Object / Activity) | Canonical? | Action |
|---|---|---|---|

## Synonym Conflicts
| Term A | Term B | Context | Resolution |
|---|---|---|---|

## Feeds Forward To
| Output | Target artifact |
|---|---|
| [Named element] | [Downstream artifact] |
```
