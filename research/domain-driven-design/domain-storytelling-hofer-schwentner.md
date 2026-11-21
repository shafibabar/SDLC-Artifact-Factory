# Domain Storytelling
**Authors:** Stefan Hofer and Henning Schwentner (*Domain Storytelling: A Collaborative, Visual, and Agile Way to Build Domain-Driven Software*, Addison-Wesley, 2021); also domainstorytelling.org and the Egon.io modeller
**Domain:** Domain-Driven Design — collaborative domain discovery (Domain Storytelling: pictographic language, scope, workshop, uses)

This file grounds `domain-storytelling`, which the Wave 2 audit found citing Hofer & Schwentner with no research file and teaching modes and step counts the book doesn't give (W2-22, W2-41). It doesn't repeat `strategic-design-supplement.md` (what a Bounded Context, a subdomain and the Ubiquitous Language are) or `introducing-eventstorming-brandolini.md` (Event Storming formats and notation). It covers how Domain Storytelling produces evidence for those steps, and how it differs from Event Storming. Decision D047-8 (agent-run mode) frames the agent-run sections.

## Core Concepts

- **A domain story is told by the people who do the work and drawn while they tell it.** Domain experts tell how they work; someone draws each sentence as it is spoken, with a small set of icons, so the tellers see the picture grow and correct it. The method comes from the authors' work at WPS and the University of Hamburg, where it grew out of earlier "cooperation pictures". The picture records a conversation; the conversation is the point.
- **The pictographic language has a few elements.**
  - **Actors:** people, groups or software systems that do something. Each gets an icon (person, group, system) and a role name, not a personal name.
  - **Work objects:** what actors create, use, pass on or talk about: a document, a phone call, an email, money, a form. Icons are chosen to suit the domain; the icon set is not fixed.
  - **Activities:** arrows labelled with a verb, linking an actor to a work object (and on to another actor).
  - **Sequence numbers:** each sentence is numbered in the order told. Actors and work objects are drawn once and reused, so later sentences connect to earlier ones.
  - **Annotations:** free text for what the icons can't say: conditions, variants not drawn, example data, comments.
  - **Groups:** an outline around part of the story, labelled, to mark an organisational unit, a place, a subdomain or a candidate boundary.
- **Every sentence reads "actor – activity – work object", often with a recipient.** "The clerk enters the claim", or "The customer sends the claim form to the clerk", where the second actor comes after a preposition. The skill's strict three-part rule is narrower than the book.
- **One diagram tells one concrete scenario.** A story describes one case that happened, or could happen, with no branches, loops or "if". The usual case (the happy path) comes first. Important variants and error cases are told as separate stories; minor ones go in an annotation. Branches belong to flowcharts and BPMN, which the authors keep apart from Domain Storytelling.
- **Three scope factors describe every story.**
  - **Granularity:** coarse-grained (a whole business process or value chain, with each sentence covering a lot) or fine-grained (one part of it, step by step). Granularity is the level of detail per sentence, not a step count.
  - **Point in time:** as-is (how work is done today) or to-be (how it will be done).
  - **Domain purity:** pure (the work as people do it, with no software shown) or digitalised (software systems appear as actors, and electronic artefacts as work objects).
  - The book writes the combination as a short label, such as coarse-grained / as-is / pure, and picks the combination from the goal. A common path is coarse-grained as-is pure for orientation, then fine-grained to-be digitalised for requirements.
- **The workshop has named roles.** **Storytellers** are domain experts, and there can be several, each telling the part they do. The **moderator** runs the session and asks questions. The **modeller** draws, often on a screen everyone can see. The moderator and modeller may be one person, though the book finds it easier with two. **Listeners** (developers, product people) mostly listen and ask questions.
- **The modeller retells the story to check it.** At points during the session, and at the end, the modeller reads the picture back sentence by sentence and the storytellers correct it. The retelling is the method's main quality check, and it confirms the words as well as the order.
- **Domain Storytelling serves several purposes (the book's second part).** Learning the domain language; finding boundaries (subdomains and Bounded Contexts); working with requirements and scoping; modelling in software; supporting organisational change and process improvement; and, as recalled, finding "shadow IT" (work done in spreadsheets, email and other unofficial tools, which shows up in as-is digitalised stories).
- **Bounded Contexts come from groups and changes of language.** On a coarse-grained story, draw groups around sentences that belong together. As recalled, the hints are: a work object changes name or meaning; a different department or role takes over; part of the story runs at a different pace or on a different trigger; a handover to another actor. A group is a candidate boundary to test, not a decision.
- **Stories feed requirements and the Ubiquitous Language.** Fine-grained to-be digitalised stories show what the software should do. Sentences where a person works with a software actor are candidates for user stories. Variant stories are candidates for acceptance criteria and examples. The actors, work objects and verbs in the storytellers' own words are the raw material for the Ubiquitous Language, and retelling with a proposed term tests it.
- **Domain Storytelling and Event Storming complement each other.** Domain Storytelling is built around actors and work objects: who does what with what, for whom, in order. A moderator guides it, and the group is small. Event Storming is built around events: what happened, on a timeline. Its group is large, and everyone writes in parallel at first. The book discusses using both. Stories suit work with clear handovers between people. Event Storming suits reactive, event-heavy processes and large cross-department groups. Neither has to come first.
- **Tooling: Egon.io.** A free, open-source modeller that runs in a browser, maintained by the authors' circle. It draws the pictographic language with an adjustable icon set, replays a story sentence by sentence, and exports images and its own story file. Paper, whiteboards and general drawing tools also work.

## Actionable Techniques

- **Pick the scope from the question, and record all three factors.** For orientation or boundaries, use coarse-grained as-is pure. For requirements for a new system, use fine-grained to-be digitalised. To find where today's tools hurt, use fine-grained as-is digitalised.
- **Draw one scenario per story, and name it.** Start with the usual case. Ask "what else can happen?" and make each important answer its own story, cross-referenced to the first.
- **Run the retelling loop.** Read the picture back in full sentences at least once before calling a story done. Treat every correction as a vocabulary or ordering finding.
- **Mark candidate boundaries with groups and record the evidence.** For each group, say which hint applies: language shift, change of role, change of pace or trigger, or handover. Send it on to `bounded-context-mapping` as a candidate.
- **Turn to-be stories into backlog items.** Each person-and-software sentence becomes a candidate user story. Each variant story becomes a candidate acceptance criterion or Gherkin scenario.
- **Agent-run mode (D047-8): claim a draft story, not a told one.** An agent working from documents can:
  - build stories from named artifacts (personas, journey maps, problem statement, requirements), citing the source for each sentence;
  - label every sentence no artifact supports as an assumption;
  - state the scope factors;
  - pose a variant story per persona or failure case;
  - list open questions, such as "who actually does step 4?", for the product owner at the gate.
- **What agent-run mode can't claim.** It can't claim the storytellers' own words, a validated sequence, or knowledge no document holds. The book makes the storyteller a domain expert telling their own work, and treats the retelling to that person as the check. Without it, an agent-run story is a hypothesis. Its "Terms Discovered" are terms found in documents, not expert language. A human session stays optional; when held, its validated stories replace the assumptions they confirm.

## Applies To

| Skill file (lines) | What it currently says | What this research changes |
|---|---|---|
| `skills/domain-storytelling/SKILL.md:3-12` | Description: "facilitate" sessions, "subject-verb-object", "pure vs. annotated storytelling modes" | Use the book's terms (three scope factors; actor – activity – work object) and add the agent-run trigger ("draft domain stories from these artifacts"). This is a trigger change, so a MAJOR bump |
| `domain-storytelling/SKILL.md:52-60` | Two modes, pure and annotated; annotated adds software labels | **Doesn't match the book.** "Annotated" isn't a book term. Replace it with domain purity (pure vs digitalised, where software appears as actors), and add point in time (as-is vs to-be) and granularity as the three scope factors |
| `domain-storytelling/SKILL.md:64-73` | Coarse = 5–10 steps for BC discovery; fine = 15–30 steps for Aggregate design | **The step counts have no source.** Drop them, or label them a house heuristic. Define granularity by detail per sentence. The purposes (coarse for boundaries, fine for requirements and modelling) roughly match the book |
| `domain-storytelling/SKILL.md:32-44` | Every sentence has "exactly three parts"; arrow Actor → Work Object | Allow a recipient actor ("sends the form *to* the clerk"). Arrows go actor → work object → actor |
| `domain-storytelling/SKILL.md:46-48, 77-87`; `agents/domain-modeler.md:148-149` | Domain Storytelling always runs before Event Storming | The book treats them as complementary with no fixed order. Keep the order as the plugin's choice, gated by `phase-requirements.json:342-351` (lean: skip; standard and enterprise: optional). Today the agent runs two stories on every product |
| `domain-storytelling/SKILL.md:99, 149-154` | "Boundary markers"; read-back criterion; at least one variation | Rename boundary markers to the book's **groups**, with the hint recorded. Read-back matches the modeller's retelling. Add "one scenario per diagram, no branches" |
| `domain-storytelling/SKILL.md:158-210` | Output Format: `scope: coarse|fine`, `mode: pure|annotated`; Facilitator = agent | Move it to `templates/domain-story.md` with `granularity`, `point_in_time` and `purity` fields; storyteller, moderator and modeller roles; `run: agent-run|workshop`; and a source column (artifact or "assumption") on Story Steps |
| `domain-storytelling/SKILL.md:21-25` | `related:` lists `acceptance-criteria`; the body never names it | The book's requirements use justifies the link: variant stories lead to acceptance criteria. Say so in the body, or drop the entry |
| `domain-storytelling/references/facilitation-guide.md:13-23` | Narrator, facilitator, observers; one narrator; a maximum of 6 | Use the book's roles (storytellers, moderator, modeller, listeners). The book allows several storytellers in one session. The maximum of 6 has no source and should be labelled a house rule |
| `facilitation-guide.md:101-116, 142-147` | No interruptions; the facilitator draws in silence; stop at 30 steps | As recalled, the book's moderator asks questions while the story unfolds and the modeller retells along the way, not only at the end. The 30-step stop has no source |
| `facilitation-guide.md:196-211` | Pure → annotated overlay: "which microservice or module owns each" | Replace it with a separate digitalised (usually to-be) story. Service ownership belongs to `container-diagram` (D047-6), not a discovery artifact |
| `facilitation-guide.md:215-235`; `references/notation-guide.md:115` | Variations drawn as steps 4a–4c, with gaps left in the numbering | The book tells variants as separate stories, so the suffixed steps should go. Minor variants can go in an annotation |
| `notation-guide.md:27-62, 157, 164-186` | Fixed shapes (dashed external actor, four work-object shapes); "exactly five element types"; Miro mapping | The book's icon set is open: person, group and system actors, and work-object icons chosen per domain. Its elements are actors, work objects, activities, sequence numbers, annotations and groups. Name Egon.io as the reference tool, keep Miro as an alternative, and call the dashed external actor a house convention |
| `facilitation-guide.md:3-5`; `notation-guide.md:3-4`; `worked-examples.md:5` | "Usable independently of `skills/domain-storytelling/SKILL.md`" (lint L5 ×3) | Reword without the path, and move `worked-examples.md` to `examples/` (two files) |
| `worked-examples.md:231-258` | Go Aggregate method signatures inside a Design-phase story | Remove them (D047-10). The book's modelling-in-software link is that work objects and activities are candidates for model elements; code belongs in the `go-*` skills |
| `facilitation-guide.md:15-16`; `agents/domain-modeler.md:94, 109-110, 180, 268` | A narrator is required; the agent "runs" sessions; the checklist says "sessions … complete" | Add agent-run mode (D047-8): cite a source per sentence, label assumptions, send open questions to the product owner, and mark each story agent-run or workshop. Filenames or frontmatter should carry as-is/to-be |
| `skills/ubiquitous-language/SKILL.md:71`; `references/ul-discovery-and-curation.md:59-61` | Domain Storytelling yields connective language; validate a term by retelling | This matches the book. Add that agent-run stories yield document terms, labelled as such, not expert language |
| `skills/bounded-context-mapping/SKILL.md:44-50` | Four signals; the linguistic fracture line is primary | Read groups on a coarse-grained story (language shift, role change, handover) as evidence for signal 1. They are not a fifth signal and not decisions, the same treatment as the Event Storming hints |
| `skills/event-storming-facilitation/SKILL.md:13` | Event Storming runs "before architecture decisions"; both skills claim term discovery | Keep the split: stories for actor and work-object handovers, Event Storming for events and policies. Each skill should state the contrast once and point to the other, not restate it |

## Candidate New Skills/Agents

- **No new skill or agent.** Domain Storytelling stays in `domain-storytelling`, owned by `domain-modeler`.
- **New folder content in the existing skill:**
  - `references/agent-run-mode.md`: source citing, assumption labelling, open questions;
  - `templates/domain-story.md`, with the three scope factors and a source column;
  - three `examples/` from the Wave 2 findings: coarse as-is library reservation; fine to-be pharmacy repeat prescription with a digitalised step; enterprise customs clearance with a group per organisation.

## Key Terminology

- **Domain Story** — one concrete scenario told as numbered actor – activity – work object sentences.
- **Actor / Work Object / Activity** — who acts; what they act on or pass; the verb arrow between them.
- **Annotation** — free text on the diagram for conditions, minor variants or example data.
- **Group** — a labelled outline around part of a story; a candidate boundary or organisational unit.
- **Granularity (coarse-grained / fine-grained)** — the level of detail per sentence.
- **Point in time (as-is / to-be)** — today's work or the intended future work.
- **Domain purity (pure / digitalised)** — without or with software systems shown as actors.
- **Storyteller / Moderator / Modeller** — the domain expert who tells, the person who guides, the person who draws and retells.
- **Egon.io** — the authors' free, browser-based modeller for the pictographic language.
- **Agent-run mode** — this plugin's term (D047-8), not the book's: a draft story built from named artifacts, with assumptions labelled.

## Caveats

- **Recalled with confidence:** the pictographic elements (actors, work objects, activities, sequence numbers, annotations, groups); the actor – activity – work object sentence with an optional recipient; one scenario per story; the three scope factors and their names (granularity, point in time, domain purity; pure vs digitalised); the storyteller, moderator and modeller roles; the retelling check; Egon.io; the complementary relationship to Event Storming.
- **Uncertain:** exact chapter titles and order (the book has a method part and a uses part, but no chapter numbers are given here); the exact list of boundary hints; whether "finding shadow IT" is its own chapter; any numeric guidance on group size, session length or sentences per story. The book gives no 5–10 / 15–30 step rule that is recalled. The live-questioning versus silent-drawing point is recalled from the authors' general practice, not a fixed passage.
- **No quotations or page numbers.** Everything here is paraphrased from working knowledge, not a fresh re-read.
- **Agent-run mode is this plugin's adaptation, not the authors' method.** The book's storyteller is the person who does the work. A story with no storyteller is a draft to be confirmed, and the skill must not present it as a told story.
