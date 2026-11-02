# Finding Terms and the Term Lifecycle

The detail behind `SKILL.md` § 3 and § 5: the procedure for each source, agent-run mode in full, testing terms in sentences, collisions between contexts, and how a term enters, changes and retires. Grounded in Evans (*Domain-Driven Design*), Khononov (*Learning Domain-Driven Design*), Brandolini (*Introducing EventStorming*) and Hofer & Schwentner (*Domain Storytelling*), as summarised in `research/domain-driven-design/`. The examples use several products on purpose.

## 1. Sources, one at a time

### 1.1 Domain experts

The strongest source. With the product owner or an expert they name:

1. Ask them to walk through one real piece of work in their own words ("Tell me about the last time a nurse couldn't make a shift").
2. Write their words down as said. Paraphrasing into engineering words is where the first drift enters.
3. Mark every noun and verb that carries domain weight ("cover", "approve", "rota", "release").
4. For each, ask for a definition, an example and a **counter-example** ("what *isn't* a Shift Swap?"). Counter-examples surface rules nobody stated.
5. Chase every hedge. "Usually the coordinator approves" means there is an exception, and the exception is either a rule or a second concept. Ask what it is and name it.
6. Treat confusion over a word as the first clue that a boundary is near (Khononov Ch. 2).

### 1.2 Event Storming

Read the wall by element, using `event-storming-facilitation`'s legend (colours vary between teams; the element type is what matters):

| Element | Terms it yields |
|---|---|
| Domain Event | Outcomes, in the past tense (`ShiftSwapApproved`). The richest source, because it forces the language to name what happened |
| Command | Action verbs (`RequestShiftSwap`) |
| Actor | Role names (Coordinator, Carer) |
| Read Model | Information names (Rota, Open Shifts) |
| Policy | "Whenever X, then Y" rules, often a term's invariant |
| External system | Words that belong to another model; candidates for translation, not adoption |
| Hotspot | A hotspot that disputes a word is an open language question for the document, not modelling noise |
| Aggregate | Appears only at Software Design level (Brandolini); the noun that receives Commands and emits Domain Events |

Big Picture boundary hints (pivotal events, swimlanes, a change of actor, a word changing meaning) are evidence for where one language ends.

### 1.3 Domain Storytelling

Each sentence is actor – activity – work object, often with a recipient ("the carer sends the swap request *to* the coordinator"). The actors, work objects and verbs, in the storytellers' words, are raw material for the language (Hofer & Schwentner). Two uses:

- **Find terms**, especially the connecting words an event timeline misses (roles, hand-overs, the work object's name at each step).
- **Test a term:** retell the story with the proposed canonical word and check the storyteller still recognises their own work. A work object that changes name or meaning partway through a story is a boundary hint.

### 1.4 Ideate artifacts

Vision, personas, job stories, user stories and acceptance criteria hold the words the user and customers already use. Edge cases in acceptance criteria ("Given a swap whose shift starts in under 12 hours…") often show a concept the language has no name for yet.

## 2. Agent-run mode (D047-8)

The domain-modeler usually runs Design with no domain expert present. Agent-run mode keeps that honest.

**Procedure:**

1. List the artifacts read in the document's `traces-to`.
2. Draft each term from them. In the Source column, cite the artifact for each term (`ideate/job-stories.md`, `design/event-storming-big-picture.md`), or write *assumed*.
3. Mark a definition *assumed* when no artifact states it and nobody has confirmed it.
4. Turn each disputed word, unclear rule or guessed meaning into an open question for the product owner, with what changes depending on the answer and the assumption in use meanwhile. Words the artifacts use interchangeably are candidate synonyms: ask, and don't add them to Banned Synonyms until the answer confirms they are one concept (the hook enforces whatever is in that table).
5. Add a check to run with a person: three to five sentences built from the drafted terms (§ 3) for the product owner, or someone they name, to read aloud, or a short story to be told back in the new terms (§ 1.3). Any sentence that sounds wrong, and any correction, is a finding.
6. Present the questions and the check at the domain-modeler's review gate. Each answer replaces an assumption; record it, and drop the *assumed* mark.

**What it can't claim:** the domain experts' own words, or knowledge no artifact holds. An agent-run language is a hypothesis until the product owner confirms it. A human session stays optional; when held, its words replace the drafted ones.

## 3. Testing terms in sentences

Evans's "modeling out loud" (Ch. 2): say sentences about the domain using only the candidate terms.

- "When a Carer requests a Shift Swap, the Coordinator approves it, and the Rota shows the new Carer." Natural, so keep it.
- "When a Carer requests a Shift Swap, the Coordinator approves the Trade." The word changed mid-sentence: a synonym.
- "The Coordinator approves the Shift Swap unless it's a Bank Shift, in which case the Agency approves it." A rule with no name and a second approver: is "Bank Shift" a term, and is the Agency in this context at all?

A sentence that sounds wrong or clumsy means the model is wrong, not only the word. Evans's "make implicit concepts explicit" (Ch. 9) catches the same thing in the other direction: a rule that keeps appearing as scattered conditions, or a combination of values passed together everywhere, is a concept waiting for a name.

## 4. Collisions between contexts

When a word is about to enter one context's document, check:

1. **Already in this context with another meaning?** That is ambiguity inside one model. Qualify one use ("Bank Shift" and "Contracted Shift"), or take the split to `bounded-context-mapping`.
2. **In another context of the same product?** Ask whether the meaning is the same.
   - **Same meaning:** it is one concept. Either one context owns it and the other uses it through a Context Map relationship, or the two share it deliberately (Shared Kernel; see `context-map-patterns`).
   - **Different meaning:** it is a homonym. Record it in both documents' Homonyms table, with the translation at the boundary. Never ban it in one context because the other uses it differently.
3. **In the plugin glossary?** The plugin's terms (Aggregate, Domain Event, Transactional Outbox, …) describe the design method, not the product's domain. A product term that happens to share a plugin word is recorded only in the product's document. The plugin glossary is never edited for one product (D047-9).

## 5. The term lifecycle

### 5.1 A term enters

1. Draft it in the template's Terms table, with its source.
2. Give it a DDD type. An Entity or Aggregate Root needs at least one rule that always holds.
3. Run the collision check (§ 4).
4. Point the Behaviour column to the event, command or scenario that shows it in action. An Aggregate Root or Policy also gets at least one Given/When/Then in the document's Key Scenarios.
5. Only then may it appear in code. A term introduced in code first is how developer dialect starts.

### 5.2 A term changes

| Trigger | Action |
|---|---|
| A meaning is consistently misunderstood | Rewrite it; retell a story or say the sentences again with the new wording |
| Two words turn out to mean one thing | Choose one; add the other to Banned Synonyms; rename every medium (§ 5.3) |
| One word starts meaning two things in one context | Qualify it, or take the split to `bounded-context-mapping` |
| A rule is discovered | Add it to the term; check that existing scenarios and code honour it |
| A breakthrough reshapes part of the model (Evans Ch. 8) | Rework the affected terms together, not one at a time; re-present to the product owner |

### 5.3 Renaming

A rename is a change to the model, carried out in every medium:

| Medium | What to rename |
|---|---|
| Code | Type, field, function and module names; table and column names (a migration) |
| API | Request and response fields, through `api-contract-design`'s deprecation if already published |
| Events | Unpublished: rename. Published: a new event type, with the old one deprecated, never a `.v2` suffix (`event-schema-design`, D047-1) |
| Tests | Gherkin step text, scenario names, test fixture names (`bdd-feature-file`) |
| Docs | Every artifact; the drift hook flags leftovers under `artifacts/` |

Record progress in the Banned Synonyms table's "Renamed in" column. The rename is done when every medium shows ✔ and a search for the banned word across the code, schemas and feature files returns nothing.

Never settle a naming conflict with a version suffix (`ShiftSwapV2`, `NewPolicy`). It means two models are competing inside one context; evolve the one definition or split the context.

### 5.4 A term retires

1. Confirm no code, API field, event or scenario still uses it. A retired word still in the code is drift.
2. Move it to Retired Terms with the date, the reason and any successor, rather than deleting it. The record explains why the word is absent and stops it coming back.
3. If it merged into another term, also list it under Banned Synonyms, pointing at the survivor.
