# Introducing EventStorming
**Authors:** Alberto Brandolini (*Introducing EventStorming*, Leanpub, written 2013–2021 and still marked unfinished)
**Domain:** Domain-Driven Design — collaborative domain discovery (Event Storming: formats, notation, facilitation)

This file grounds `event-storming-facilitation` and the Event Storming parts of `ubiquitous-language`, the two skills the Wave 2 audit found citing Brandolini with no research file (W2-42). It does not repeat `strategic-design-supplement.md`, which covers what a Bounded Context and a subdomain are, how subdomains are classified, and the Context Map patterns. This file covers how Event Storming produces the evidence those steps start from. Decisions D047-8 (agent-run mode) and D047-14 (subdomain classification after Big Picture) set the frame for the agent-run sections.

## Core Concepts

- **Event Storming is a group discovery workshop, not a notation exercise.** Brandolini's starting point is that the software ends up encoding the developers' understanding of the domain, gaps included. The workshop puts the people who hold the knowledge and the people who need it in front of one wall, so gaps and disagreements become visible quickly. The stickies serve that conversation; they aren't the product.
- **There are three formats, each with a different purpose and a different room.**
  - **Big Picture:** explores a whole line of business, across department boundaries, to build a shared view and find where the problems are. It is broad and deliberately imprecise. The room is large (often 10–30+ people) and mixed: domain experts from every department involved, decision makers, and the technical people.
  - **Process Modelling:** takes one process and models it end to end with a stricter grammar until every path makes sense. The room is smaller: the people who run the process, the people who will change it, and the people who build the software.
  - **Software Design:** turns a modelled process into software building blocks (aggregates or similar consistency units, read models, policies) and their boundaries. Mostly developers, with domain experts on hand to answer rule questions.
- **The notation is added step by step ("incremental notation").** Big Picture opens with orange events only. Hotspots, people and systems come in as the session needs them, and the full grammar arrives in Process Modelling. Brandolini cares more about one consistent legend in the room than about specific colours.
- **The sticky-note grammar, as most sources give it.** Orange: domain event, a fact in the past tense that matters to the business. Blue: command or action, a decision or intent. Small yellow: actor or person. Lilac: policy, the "whenever X, then Y" reaction (Brandolini also allows "eventually" policies people carry out by hand). Green: read model or information, what a person looks at before deciding. Large pink: external system. Hotspot: a bright pink, magenta or purple note, often turned 45 degrees so it stands out. Large pale yellow: the aggregate or consistency unit, used only in Software Design. Opportunities, the upside of a hotspot, are often green.
- **Colours vary, and that is admitted.** Sticky-pad colours on sale have shifted over the book's life. Practitioners disagree on hotspots (pink, red, magenta, purple) and policies (lilac, purple). Some use the same pink for hotspots and external systems, told apart only by rotation and size. Brandolini has also said the word "aggregate" puts domain experts off. He suggests talking about the rules or constraints a decision must respect and naming the unit later. A plugin legend is a house choice and should say so.
- **The Big Picture runs in phases.**
  - **Chaotic exploration:** everyone writes orange events at the same time, in silence, with no ordering and no debate.
  - **Enforcing the timeline:** the room orders events left to right, removes duplicates and settles near-duplicates. Structure starts to appear: *pivotal events* (the few events that mark a change of phase), *swimlanes* (parallel flows), and sometimes chapters or temporal milestones.
  - **People and systems:** actors and external systems are added where they cause or receive events.
  - **Explicit walkthrough:** someone tells the story aloud along the timeline, and the room corrects it. Brandolini also runs it backwards from the end ("reverse narrative") to find missing events.
  - **Problems and opportunities:** hotspots for pain, risk and disagreement; opportunities for ideas.
  - **Picking the problem:** each participant gets a small number of votes (arrows) to place on the hotspots that matter most. The vote picks what to work on next.
- **Hotspots are a main output, not something to tidy away.** A hotspot marks where knowledge is missing, people disagree, or the business hurts. The facilitator records it and keeps going, and does not let the loudest voice settle it. The ranked hotspot list is often the most useful thing a Big Picture produces.
- **Process Modelling has "the picture that explains everything".** An actor looks at a read model and issues a command. The command reaches a system, which produces an event. A policy reacts to the event and issues the next command, and new events update the read models people consult. Brandolini's rule is that every path must reach a stable end, with every colour in its place in that chain. A gap in the chain is a question to ask, not something to fill in silently.
- **Big Picture output suggests boundaries but doesn't draw them.** Pivotal events, swimlanes, a change of actors, and places where the same word starts to mean something else all hint where Bounded Contexts and subdomains may lie. Brandolini presents these as clues to follow up, not decisions. Boundaries are confirmed in Process Modelling, Software Design and the later context-mapping work.
- **The facilitator runs the process, not the content.** The facilitator prepares the room, keeps the legend visible, introduces notation at the right moment, asks about vague stickies, protects hotspots, and keeps time. They write few stickies themselves.
- **Inviting the right people matters more than anything else.** Brandolini's rule is to invite both the people with questions and the people with answers. A session without the knowledge holders gives a confident-looking wall that is mostly guesswork. The value comes from the people meeting; the stickies only record it.
- **The space must be unlimited.** Use a long paper roll on a wall, not a whiteboard, and remove tables and chairs so people stand and move. A small surface quietly limits how much people say.
- **Remote sessions work, at a cost (recalled with less confidence).** Brandolini's pandemic-era notes, as recalled, say an online canvas loses much of the parallel chaos and the body language. They suggest shorter sessions spread over several days, smaller groups, more preparation and a prepared board. They treat remote as a different workshop, not the same one moved online.

## Actionable Techniques

- **Pick the format from the question.** "What does the business look like, and where does it hurt?" calls for Big Picture. "How should this one process work?" calls for Process Modelling. "What software units carry these rules?" calls for Software Design. Don't run Software Design on a process nobody has modelled.
- **Run the Big Picture phases in order, then stop at the vote.** Run every phase from chaotic exploration to arrow voting. The voted hotspots and the pivotal events choose which processes go on to Process Modelling.
- **Ask for the unhappy paths out loud.** During the walkthrough ask "what goes wrong here?" and "what happens if nobody acts?". Then run the reverse narrative to find missing events.
- **Record boundary hints with their evidence.** For each candidate boundary, record the pivotal event or swimlane, the actor change, and the word whose meaning shifts. Mark it a candidate. Subdomain classification comes next (D047-14).
- **Check every Process Modelling path against the chain.** A path is complete when it runs read model → actor → command → system → event → policy → … and ends in a stable state. Each break becomes a hotspot.
- **Agent-run mode (D047-8): claim a hypothesis wall, not a workshop.** An agent working from documents can:
  - derive events, actors, commands and policies from named artifacts, citing the artifact for each card;
  - sweep the perspective of each persona and stakeholder in those artifacts, standing in for the many authors of chaotic exploration;
  - ask for the unhappy paths;
  - label every card that no artifact supports as an assumption.
- **What agent-run mode can't claim:** shared understanding, resolved disagreements, or discovery of what no document contains. Its hotspots are open questions for the product owner at the phase gate, and none is marked resolved without an answer. A human session stays optional and, when held, replaces the assumptions it confirms.

## Applies To

| Skill file (lines) | What it currently says | What this research changes |
|---|---|---|
| `skills/event-storming-facilitation/SKILL.md:3-15` | The description names "Big Picture, Process Level, and Design Level", gives a fixed seven-colour legend, and presents the work as a human workshop | Use Brandolini's names (Big Picture, Process Modelling, Software Design) and keep the current names as aliases. Add the agent-run trigger ("model the domain from these artifacts"). This is a trigger change, so a MAJOR bump |
| `event-storming-facilitation/SKILL.md:50-54`; `references/color-grammar-and-levels.md:108-130`; `phase-requirements.json:364` | Bounded Context candidates come out of Design Level only; the lean note says Big Picture alone "still identifies the Bounded Contexts" | Big Picture gives boundary *hints* (pivotal events, swimlanes, actor changes, shifts in meaning), recorded with evidence and marked as candidates. That gives lean a stated way to get candidates (W2 eval idea b) |
| `event-storming-facilitation/SKILL.md:68-77`; `references/color-grammar-and-levels.md:59-94` | Purple policy, red hotspot, "green (small) / lilac" opportunity | Brandolini's usual set is lilac policy, a magenta or pink hotspot (often rotated) and a green opportunity. Choose one plugin legend, say it is a house choice, and add a short note that colours vary |
| `ubiquitous-language/references/ul-discovery-and-curation.md:45-57` | Lilac = hotspot; yellow = aggregate | This contradicts `event-storming-facilitation`, which uses purple for policy and lilac for opportunity. Use the same legend as `event-storming-facilitation`. Small yellow is the actor and yields role terms; large yellow (aggregate) appears only in Software Design |
| `ubiquitous-language/SKILL.md:69-70` | Event Storming yields terms from orange, blue and yellow (aggregate) cards | Add actors (role names), read models (information names) and policies ("whenever" rules) as sources. Hotspots that dispute a word are language questions for the per-context language, not modelling noise |
| `event-storming-facilitation/references/color-grammar-and-levels.md:13-17` | The colour is a "strict type declaration"; never add a colour mid-session | Keep strictness for the transcribed output. During a session, notation is added step by step (orange only at first); add that to the Big Picture procedure |
| `event-storming-facilitation/SKILL.md:81-97`; `references/facilitation-guide.md:63-87` | One four-move arc "at every level"; eight Big Picture passes ending in swimlanes | Big Picture follows Brandolini's phases: add people and systems, the explicit and reverse walkthrough, problems and opportunities, and arrow voting. Move 4 (aggregates and boundaries) belongs to Software Design only |
| `event-storming-facilitation/references/color-grammar-and-levels.md:113-118`; `references/facilitation-guide.md:16-21, 157-158` | A domain expert is mandatory; without one, "stop and run discovery interviews"; storming without an expert is an anti-pattern | Add agent-run mode (D047-8): cite the source artifact for each card, label assumptions, send hotspots to the product owner as questions. Rewrite the anti-pattern as "presenting an agent-run wall as a workshop". Keep Brandolini's point that the value comes from the people, and say what agent-run mode can't claim |
| `event-storming-facilitation/SKILL.md:120-126, 143`; `references/facilitation-guide.md:121-135` | Hotspots are resolved after the session and feed an "Architecture risk register" no skill produces | Hotspots are a main output: rank them (the arrow vote, or the agent's stated priority) and send them to the product owner's gate and `architecture-evaluation`. Opportunities go to the backlog |
| `event-storming-facilitation/references/color-grammar-and-levels.md:144-150` | Process shape: read model → actor → command → aggregate → event → policy | Brandolini's Process Modelling has a *system* in that slot. The aggregate replaces it only in Software Design. Add his rule that every path must reach a stable end |
| `event-storming-facilitation/references/facilitation-guide.md:28-29, 35-39` | Group size and an infinite canvas for virtual sessions | Add who attends each format and the remote caveats: shorter sessions over several days, smaller groups, a prepared board |
| `event-storming-facilitation/references/facilitation-guide.md:116-117` | Design Level lists services, "one microservice per Bounded Context with per-tenant physical isolation" | Remove it. Service decomposition belongs to `container-diagram` (D047-6) and tenancy has no default (D047-7). Software Design ends at consistency units and their boundaries |
| `subdomain-distillation/SKILL.md:10-14, 40` | Runs "early in the Design phase"; Event Storming is listed as Core-only investment | The capability list for classification comes from Big Picture swimlanes and pivotal events (D047-14). Event Storming is the input to classification, not a Core-only extra |
| `bounded-context-mapping/SKILL.md:46-57`; `references/bc-discovery-guide.md:31-32, 49-55` | Event Storming output is the "primary vocabulary source"; four boundary signals | Read the Big Picture boundary hints (pivotal events, swimlanes, actor changes) as evidence for the linguistic signal. They are not a fifth signal and not decisions |
| `domain-event-catalog/SKILL.md:147`; `command-catalog/SKILL.md:129` | Command-disguised-as-event check; "Every Command names its Actor (human role or Policy)" | These match Brandolini's chain. In agent-run mode, each catalogue row also carries its source (the artifact it came from, or "assumption") so the provenance survives transcription |
| `agents/domain-modeler.md:132, 148-156` | Run order: Event Storming steps 3-5 run all three levels back to back; the presentation is addressed to the operator by name | Insert subdomain classification after step 3 (D047-14). State whether each wall is agent-run or human-run. Present hotspots as product-owner questions at the gate, and address "the user" |

## Candidate New Skills/Agents

- **No new skill or agent.** Event Storming stays in `event-storming-facilitation`, owned by `domain-modeler`.
- **New folder content in the existing skill:**
  - `references/agent-run-mode.md` (or a `steps/` file per format, if the procedure grows long): the source-citing and assumption-labelling rules and the open-question output.
  - `templates/event-storming-session.md`, with a source column and a ranked hotspot table. It replaces the inline Output Format.
  - Three `examples/` from the Wave 2 findings: lean Big Picture only, standard Process Modelling, enterprise Software Design with hotspots sent to the product owner.

## Key Terminology

- **Big Picture / Process Modelling / Software Design** — the three formats: explore the whole business, model one process, design the software units.
- **Domain Event** — an orange sticky; a business fact in the past tense.
- **Pivotal Event** — one of the few events that mark a change of phase in the timeline; a boundary hint.
- **Swimlane** — a horizontal lane separating parallel flows on the timeline.
- **Hotspot** — a marked point of missing knowledge, disagreement or pain; a main output.
- **Policy** — a lilac reaction rule: whenever an event happens, issue a command (automated or manual).
- **Read Model** — a green sticky; the information an actor looks at before deciding.
- **Incremental Notation** — adding sticky types only as the session needs them.
- **Arrow Voting** — each participant places a few votes on hotspots to pick the problem to work on.
- **Reverse Narrative** — walking the timeline from the end backwards to find missing events.
- **Agent-run mode** — this plugin's term (D047-8), not Brandolini's: a hypothesis wall built from named artifacts, with assumptions labelled.

## Caveats

- **Recalled with confidence:** the three formats and their purposes; orange past-tense events as the backbone; the Big Picture phases from chaotic exploration through arrow voting; incremental notation; hotspots as outputs; the Process Modelling chain; pivotal events and swimlanes as boundary clues; unlimited modelling space; inviting the people with questions and the people with answers; the facilitator running the process.
- **Uncertain:** the book is a living Leanpub edition, so chapter names and order have changed between versions; no chapter numbers are given here for that reason. The exact hotspot and policy colours differ between Brandolini's own versions and among practitioners. The remote-session guidance is recalled from his later writing and talks, and may not all be in the book. His preference for "rules" or "constraints" over "aggregate" is recalled from talks rather than a fixed passage.
- **No quotations or page numbers.** Everything here is paraphrased from working knowledge, not a fresh re-read.
- **Agent-run mode is this plugin's adaptation, not Brandolini's method.** His method assumes the right people are in the room. Grounding agent-run mode in his work means being honest about what it loses, not claiming his endorsement.
