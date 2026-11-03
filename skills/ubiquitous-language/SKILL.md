---
name: ubiquitous-language
description: >
  Build and keep the Ubiquitous Language of each Bounded Context in a
  product: one vocabulary used the same way in conversation, the model, code
  identifiers, API fields, Domain Events and Gherkin scenarios. Covers
  finding terms from domain experts, Event Storming and Domain Storytelling,
  or in agent-run mode from named Ideate artifacts with assumed terms
  labelled and open questions sent to the product owner; testing a term by
  saying it in sentences; one language per Bounded Context, homonyms at a
  boundary and the translation that crosses it, versus synonyms to ban;
  finishing a rename across code, API fields, events and tests; and
  terminology drift. Use when defining a context's terms, settling a naming
  dispute between teams, deciding whether two words name one concept or
  two, or checking whether a rename is done. The product's language lives in
  design/<context>/ubiquitous-language.md; glossary-management stays the
  plugin's own vocabulary. Used by domain-modeler after Event Storming and
  subdomain classification.
version: 3.1.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, ubiquitous-language, ddd, bounded-context, homonym, synonym, terminology-drift, agent-run]
produces: ubiquitous-language
domain: domain-modeling
status: stable
related: [glossary-management, aggregate-design, bounded-context-mapping, context-map-patterns, event-storming-facilitation, domain-storytelling, subdomain-distillation, event-schema-design, api-contract-design, bdd-feature-file]
sources:
  - research/domain-driven-design/strategic-design-supplement.md
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
  - research/domain-driven-design/domain-storytelling-hofer-schwentner.md
---

# Ubiquitous Language

## Purpose

The Ubiquitous Language (Evans, *Domain-Driven Design*, Ch. 2) is the one vocabulary a team uses inside a Bounded Context: in speech, in writing, in diagrams and in the code. Evans's claim is stronger than "agree on words": a change in the language *is* a change to the model. Khononov (*Learning Domain-Driven Design*, Ch. 2) adds that the language belongs to the business, so it has no technical jargon, no ambiguous terms and no synonyms.

Three things are easy to confuse. Keep them apart:

| Thing | What it is | Where it lives |
|---|---|---|
| **The language** | How the team and the model actually speak about one Bounded Context | The model, the code, the scenarios, the conversations |
| **The product's language document** | A record of that language, one per Bounded Context | `artifacts/<product>/design/<context>/ubiquitous-language.md` (this skill's artifact) |
| **The plugin glossary** | This plugin's own vocabulary (Aggregate, Transactional Outbox, …) | `glossary-management`; never edited for one product (D047-9) |

A document is a record of the language, not the language (Khononov Ch. 2; Evans Ch. 2). One that stops matching the code is worse than none.

## 1. The Language Lives in the Model and the Code

Evans's Model-Driven Design (Ch. 3–4): the code *is* the model, not a translation of it. So the canonical term appears verbatim in type names, field names, table names, API fields, Domain Event names and Gherkin steps. When the team says "Shift Swap" and the code says `TradeRequest`, the translation lives in people's heads and is redone, and sometimes got wrong, at every hand-off.

Names reveal intention (Evans Ch. 10, Intention-Revealing Interfaces): a domain expert should be able to predict what an operation does from its name alone. If they can't, rename it before it is built. This skill stays stack-neutral (D047-10); how a term becomes a type in a given language is the `go-*` and frontend skills' job.

## 2. One Language per Bounded Context

A term is defined only inside its Bounded Context. Khononov (Ch. 3) is precise about the force: a Bounded Context boundary is a **linguistic and model-consistency** boundary. It sits where a term's meaning changes, which is a different force from an Aggregate's transactional boundary. Two failure shapes, with opposite fixes:

- **Synonyms:** two words, one meaning, in one context ("swap", "trade", "cover request"). Pick one canonical term, record the others as banned, and rename everywhere (§ 5).
- **Homonyms:** one word, two meanings, in two contexts ("Appointment" as a booked time slot in Scheduling and as a billable encounter in Billing). Not an error: it is the boundary showing itself. Each context keeps the word with its own meaning, in its own document, and records the other context's meaning as a homonym. Name the translation that crosses the boundary, a Context Map relationship such as an Anti-Corruption Layer (`context-map-patterns`).

Before banning a word, ask whether the two sides mean the same thing. If they don't, it's a homonym: **neither context is told to stop using its word**, and no single "winning" or broader definition is written. A homonym isn't settled by renaming one side and banning the word there; an argument between teams over a homonym ends when both see that the word means two things, because there are two contexts. (If a context's own people already use a different word, that word may become its term, but as their choice, recorded, not as a fix for the argument.) If one word starts meaning two things *inside* one context, that is a Bounded Context signal: qualify it, or take the split to `bounded-context-mapping`. Once a term must mean two things, the fix is two contexts, not a broader definition (Evans Ch. 14; Khononov Ch. 3). A meaning change in different parts of the *model* is the signal; "subdomain" is the problem-space word and isn't the test.

## 3. Finding Terms

Terms are found, not invented at a desk. Sources, in order of strength:

| Source | What it yields |
|---|---|
| **Domain experts** (the product owner, interviews, a human workshop) | The words people already use. The strongest source; every other one is a way of fishing it |
| **Event Storming** (`event-storming-facilitation`) | Domain Events → outcomes in the past tense; Commands → action verbs; actors → role names; Read Models → information names; policies → "whenever" rules; hotspots that dispute a word → open language questions, not noise. Aggregate names appear only at Software Design level (Brandolini) |
| **Domain Storytelling** (`domain-storytelling`) | Actors, work objects and the verbs between them, in the storytellers' words. Retelling a story with a proposed term tests it (Hofer & Schwentner) |
| **Ideate artifacts** (vision, personas, job stories, acceptance criteria) | Words the user and customers already use; edge cases in acceptance criteria often show a concept with no name yet |

**Agent-run mode (D047-8).** The domain-modeler usually builds the language with no domain expert in the room. It then drafts terms from named artifacts and must not present them as expert language:

1. Every term's Source cites the artifact it came from (`ideate/personas.md`, the Event Storming wall), or says **assumed**.
2. A definition nobody has confirmed is marked *assumed* in the document.
3. Disputed or unclear words become **open questions for the product owner**, presented at the domain-modeler's review gate. The answers replace the assumptions. This includes words the sources use interchangeably ("parcel", "hamper", "box"): whether they name one concept or several is the product owner's call. List them as candidate synonyms with the meaning assumed meanwhile, and add a ban to the Banned Synonyms table only once it is confirmed. A drafted ban picks a winner on a guess, and the drift hook would start enforcing it.
4. Give the product owner (or someone they name) a **check to run with a person**: a handful of sentences using the drafted terms to read aloud (below), or a short story told back in the new terms (Hofer & Schwentner's retelling). Each sentence that sounds wrong to them, and each correction, is a finding.

A human session stays optional. When held, its words replace the drafted ones.

**Test by saying it.** Evans's "modeling out loud" (Ch. 2): say candidate sentences with the terms ("the coordinator approves the Shift Swap, then the rota updates"). A sentence that sounds wrong or clumsy means the model is wrong, not only the word. Evans's "make implicit concepts explicit" (Ch. 9) is the same signal from the other side: a rule that keeps reappearing with no name, as scattered conditions or a repeated combination of values, is a missing term. Name it before it reaches the code.

The full procedure for each source, agent-run mode and the sentence test is in `./references/discovery-and-lifecycle.md` § 1–3.

## 4. Writing a Term Down

Each term records: the term, its DDD type (Entity, Value Object, Aggregate Root, Domain Event, Command, Read Model, Policy or Concept), its meaning *in this context* in domain words (never "a row in table X"), the rules that always hold, where its behaviour lives, and its source.

A word list is not the language: a glossary captures the nouns, and the behaviour (what happens, in what order, under which rules) lives in scenarios, the model and the code (Khononov Ch. 2). So the Behaviour column points to the Domain Event, Command or scenario that shows the term in action, and **every key term (each Aggregate Root and Policy) gets at least one short Given/When/Then scenario** in the document's Key Scenarios section, at every profile, lean included. The scenarios later seed `bdd-feature-file`. The copy-ready document is `./templates/ubiquitous-language.md`: context boundary, terms, key scenarios, banned synonyms with their rename status, homonyms with their translation, open questions and retired terms.

## 5. Changing, Renaming and Retiring a Term

The language changes as understanding deepens. Evans calls the big shifts breakthroughs (Ch. 8). Every change is a change to the model, so:

- **A rename is finished only when every medium uses the new word:** code identifiers, table and column names, API fields, Domain Event names and payload keys, Gherkin scenarios and docs. Until then the document and the code disagree, and the code wins. The Banned Synonyms table tracks rename status per medium, so "is it done?" has a checkable answer. While a rename is outstanding in code, an API or scenarios that already exist, the language work is **not done**: report it as in progress with the open renames listed, never as complete, and don't present the context as ready to leave Design on the strength of the document alone.
- **A published Domain Event or API field can't simply be renamed.** Consumers have copied the old word. For an event, a breaking change is a new event type, never a `.v2` suffix, with the old one deprecated (`event-schema-design`, D047-1). For an API, follow `api-contract-design`'s deprecation.
- **No version-suffixed names** (`AppointmentV2`, `RealPolicy`). A suffix means two models are competing in one context. Evolve the one definition, or split the context.
- **Retire, don't delete.** A term that leaves the domain moves to Retired Terms with its reason and any successor, so nobody brings it back unknowingly.

The enter / change / rename / retire procedure is in `./references/discovery-and-lifecycle.md` § 5.

## 6. Drift

Drift is the gap between the words the team speaks and the words the code, tests and documents use. It's usually a synonym creeping into a field name, or an identifier quietly moving away from the spoken term. Enforcement:

- **The `terminology-drift-detector` hook** reads both vocabularies (D047-9): it warns, without blocking, when a file under `artifacts/` uses a plugin-glossary drift form, or a synonym the product's own language documents ban. Product bans therefore go in the product's document, never in the plugin glossary, where they would hit every other product. A word that is banned in one context but canonical in another isn't flagged outside the banning context, because homonyms are legitimate. It reads the Banned Synonyms table, so a ban that isn't in the table isn't enforced.
- **The hook doesn't see the product's source code, API schemas or feature files.** Review covers them, along with a search for each banned word when a rename is claimed done.

Drift patterns, detection in each medium, the correction loop and severity are in `./references/drift-detection.md`.

## Scale

| Profile | The language document |
|---|---|
| `lean` | Usually one or two Bounded Contexts. One short document each: the terms table (about 8–15 terms), banned synonyms and open questions. Agent-run mode is the norm |
| `standard` | One document per context. Homonyms at each boundary named with their translation. Key Aggregate Roots get an example and a counter-example |
| `enterprise` | As standard, plus rename status tracked per medium for every ban, and retired terms kept. Expect several homonyms across contexts and renames that reach published events |

The methodology isn't skipped at lean: the document is shorter, and the rules are the same.

## Producing the Document

Copy `./resources/ul-checklist.md` and tick it as you go.

1. **Read** the Event Storming output (its words and disputed words), the `subdomain-classification` and the Ideate artifacts. List the candidate Bounded Contexts.
2. **Draft** each context's terms from the sources in § 3, citing a source per term or marking it *assumed*. Test them by saying sentences (§ 3).
3. **Check shared words** across contexts: same meaning (one owner, or a deliberate Shared Kernel) or a homonym (each keeps its word, translation named). Never settle a homonym with a ban.
4. **Write** the document from `./templates/ubiquitous-language.md` to `design/<context>/ubiquitous-language.md`: a scenario for each key term, bans only for confirmed synonyms, open questions with the assumption in use, and sentences for the product owner to read aloud.
5. **Validate, then loop.** Run `./scripts/validate-ubiquitous-language.sh design/<context>/ubiquitous-language.md`. Fix every FAIL and run it again until it exits clean. Then go through the checklist items the script can't judge.
6. **Present** at the domain-modeler's review gate: the open questions and the read-aloud check, not only the path.

**A rename, once the language is in use: plan, validate, execute.** A rename across media is costly to undo, so:
1. **Plan:** list every place the old word lives (code identifiers, tables, API fields, event names, scenarios, docs), and for each the change, or the deprecation route for a published API field or event.
2. **Validate the plan:** search the code, schemas and feature files for the old word and compare the hits with the list; anything found and not listed goes on it. Check that published events get a new event type, never a `.v2`.
3. **Execute,** then record status in the Banned Synonyms table's "Renamed in" column. It is done only when every medium is ✔, the search returns nothing, and the drift hook is quiet.

Full rename procedure: `./references/discovery-and-lifecycle.md` § 5.3.

Worked cases, simplest to hardest: `./examples/01-lean-shift-swap-agent-run.md` (one context, agent-run, a candidate ban waiting on the product owner), `./examples/02-standard-clinic-booking-homonym.md` (a homonym that must not be "fixed" with one global term), `./examples/03-enterprise-insurer-policy-rename.md` (four contexts, and a rename that reaches a published event).

## Gotchas

- **"Pick one definition for the whole product and ban the other."** Say why that's wrong, not only that it is. A ban is for **synonyms**: two words for one meaning *inside one context*. Here it's the reverse, a **homonym**: one word, two meanings, in two contexts, which is the boundary showing itself. Neither context is told to stop using the word, and renaming one side to end an argument is still a ban in disguise. Write each meaning in its own context's document (the product's `design/<context>/ubiquitous-language.md`, not the plugin glossary), note the other meaning as a homonym in each, and name the translation on the Context Map.
- **Banning words the sources merely use interchangeably.** "Parcel", "hamper" and "box" may or may not be one concept; that's the product owner's call. List them as candidate synonyms under Open Questions. A ban in the table is enforced by the drift hook at once.
- **A word list with no behaviour.** Even at lean, each Aggregate Root and Policy gets a Given/When/Then in Key Scenarios.
- **"Mark them confirmed by domain experts" when nobody confirmed them.** Keep *assumed*, cite the source, and give the product owner sentences to read aloud as the cheap check.
- **"The ban is in the document, so we're done."** Not while the code, an API field, an event or a scenario still uses the old word. Report it as in progress with the open renames.
- **Putting a product's ban in the plugin glossary.** It would hit every other product. It goes in the product's own Banned Synonyms table, which the drift hook reads.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **One global term** for a word two contexts use differently | A vague definition that fits neither; the boundary is lost | Homonym: each context keeps its meaning; name the translation |
| **Product terms in the plugin glossary** | `glossary-management` is the plugin's vocabulary; product terms leak into every other product | The product's `design/<context>/ubiquitous-language.md` (D047-9) |
| **Developer dialect:** code says one word, people say another | Translation in people's heads at every hand-off | Canonical term verbatim in code, API, events, scenarios |
| **"Banned" while the code still uses it** | The document and the code disagree; the code wins | Rename every medium; track status in the Banned Synonyms table |
| **Drafted terms presented as expert language** | Assumptions pass the review gate unseen | Source per term; *assumed* marked; open questions to the product owner |
| **A word list as the language** | Nouns without behaviour; rules end up nowhere | Behaviour column pointing to events, commands and scenarios |
| **Definition by implementation** ("a row in `bookings`") | Ties the meaning to today's storage | Domain words and rules; the table is a consequence |
