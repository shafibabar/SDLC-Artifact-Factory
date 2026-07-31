---
name: ubiquitous-language
description: >
  Build and enforce the Ubiquitous Language of a Bounded Context — the single
  shared vocabulary used identically in conversation, Go type and method names,
  Gherkin scenarios, API fields, and docs. Covers term discovery from domain
  experts, Event Storming cards, and Domain Storytelling; the same-language-in-code
  rule (class/method names ARE the language, per Evans' Intention-Revealing
  Interfaces and Model-Driven Design); one-language-per-Bounded-Context and what
  happens at context boundaries (translation, Anti-Corruption Layer); homonyms
  vs synonyms; terminology drift (code names diverging from spoken names) and its
  correction. Distinct from glossary-management: this is the modeling PRACTICE,
  the glossary is the artifact. Used by domain-modeler at the start of every
  Design-phase domain session.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
related: [glossary-management, aggregate-design, bounded-context-mapping, context-map-patterns, event-storming, domain-storytelling]
tags: [design, domain-modeling, ubiquitous-language, ddd, glossary, terminology-drift]
---

# Ubiquitous Language

## Purpose

Ubiquitous Language (Eric Evans, *Domain-Driven Design*) is the shared, precise vocabulary used by everyone working in a Bounded Context — engineers, product managers, and domain experts — in **all** communication: conversations, code, tests, documentation, and APIs.

"Ubiquitous" means the language is used everywhere, **without translation**. A term used differently in code than in conversation, or differently between two engineers, is a defect in the language — not a stylistic difference. Every boundary crossing (engineer ↔ domain expert, service ↔ service, spec ↔ test) that requires translation introduces cost and the opportunity for subtle semantic errors that ship as bugs.

This skill is the **practice** of building and keeping that language alive. It is distinct from `glossary-management`, which owns the **artifact** — the written glossary file, its frontmatter, its versioning. This skill decides what the words are and enforces their use in code; that skill records and publishes them. Do not conflate the two: a glossary with no living practice behind it is shelfware; a practice with no recorded glossary is un-reviewable.

---

## The Language Lives in the Code

Evans' sharpest, most-missed claim: the Ubiquitous Language is not documentation *about* the model — the code **is** the model (Model-Driven Design). A class named `DataAsset`, a method named `Classify(level, classifiedBy)`, a Gherkin step "Given a Restricted DataAsset" — these are not translations of the language, they *are* the language in another medium.

The corollary rule: **the canonical term appears verbatim** in Go type names, struct field names, table names, API field names, and Gherkin scenario text. When code says `FileRecord` but the team says "DataAsset", the translation layer lives in engineers' heads and re-introduces drift at every hand-off. This is Evans' **Intention-Revealing Interface** discipline: a domain expert should predict what `Classify(...)` does from its name alone, with zero knowledge of the implementation. If they cannot, rename before implementing — not after.

Consequence for review: renaming a term is not "just" a glossary edit. A synonym ban is complete only when code, tests, APIs, and docs are all renamed. Until then the codebase and the glossary disagree, and the codebase wins.

---

## One Language Per Bounded Context

The Ubiquitous Language is **scoped to a single Bounded Context**. The same word can legitimately mean different things in different contexts — this is intentional DDD design, not a defect:

| Term | In Data Discovery context | In Compliance/Audit context |
|---|---|---|
| `File` | a document in the customer's storage estate — has a path, type, sensitivity | a compliance evidence file submitted to an auditor |
| `User` | a person who logs into the platform | a data subject whose personal data was discovered |

A Bounded Context boundary is *precisely where the meaning changes*. Khononov's framing sharpens why: a Bounded Context boundary is a **linguistic/model-consistency** boundary (it exists where a term's meaning changes), which is a *different force* from an Aggregate boundary (transactional consistency). When the same word crosses a context boundary with a different meaning, the crossing is handled by **translation** — a Context Map relationship, typically an Anti-Corruption Layer. The defect is using both meanings *inside the same context* without distinguishing them.

Full one-language-per-context rules, the term-definition format, the per-source discovery procedure, and the term lifecycle (how a term enters, changes, and retires) are in **`references/ul-discovery-and-curation.md`**.

---

## Discovering Terms

Terms are discovered, not invented. They surface most reliably from three sources:

| Source | What it surfaces |
|---|---|
| **Direct conversation with domain experts** | The natural words experts already use — the primary well; every other source is a structured way to fish it |
| **Event Storming** | Orange cards (Domain Events) → verbs/nouns for what happens; blue cards (Commands) → action verbs; yellow cards (Aggregates) → the nouns that receive commands and emit events |
| **Domain Storytelling** | The natural-language narration experts give when walking through a workflow — reveals connective terms and roles the card exercise misses |

User stories, job stories, and acceptance criteria are secondary sources — edge-case terms in acceptance criteria often reveal a domain concept the language has no word for yet. When an unnamed concept keeps recurring as scattered conditional logic or a repeated parameter combination, that is Evans' "make implicit concepts explicit" signal: name it, add it, align the team *before* it appears in code.

The step-by-step procedure for harvesting terms from each source — and the exact term-definition format (Term / Definition / Type / Synonyms / Homonyms / Invariants / Example) — is in **`references/ul-discovery-and-curation.md`**.

---

## Homonyms and Synonyms

Two failure shapes, opposite corrections:

- **Synonyms** (two words, one meaning — "file", "document", "record" all meaning `DataAsset`) are the most common source of drift. Two engineers using two words for one concept have two mental models that will diverge in code. **Correction:** choose one canonical term, document the rest as *banned*, enforce the canonical term everywhere.
- **Homonyms** (one word, two meanings in two contexts — `asset` meaning a discovered file here, a compliance evidence item there) are *not* errors; they are boundaries. **Correction:** document them explicitly with each context's meaning and the Anti-Corruption Layer that handles the crossing. A homonym flattened into a single "global" definition produces a vague lowest-common-denominator term that fits nobody.

---

## Detecting and Correcting Drift

A Ubiquitous Language decays the moment it stops being enforced. **Drift** is the gap between the words the team speaks and the words the code, tests, and docs actually use — most often a synonym creeping into a field name, or a code identifier silently diverging from the spoken term.

Enforcement is wired into the delivery flow, not left to goodwill:

- **Code review** — any synonym in a type, field, or variable name is a rejection reason.
- **API contract review** — OpenAPI field names must use the canonical term.
- **Gherkin review** — scenario text must use the canonical term.
- **The `terminology-drift-detector` hook** — flags synonyms and unknown terms in artifact prose automatically.

How drift actually appears (the specific patterns), how to detect it across code/specs/docs, and the full correction workflow — including the loop back to `glossary-management` and the `terminology-drift-detector` hook — are in **`references/drift-detection.md`**.

---

## Language Evolution

The language is never static; it evolves as domain understanding deepens. Common triggers and their actions:

| Trigger | Action |
|---|---|
| Expert uses a term the team hasn't defined | Add it via the discovery process |
| A definition is consistently misunderstood | Rewrite it; validate with a Domain Storytelling session |
| Two terms turn out to mean the same thing | Choose one; ban the other; rename in code |
| A term means different things in different sub-domains | Consider a Bounded Context split, or add a qualifier |
| A concept keeps appearing with no name | Name it; add it; align the team before it reaches code |

Version-suffixed dodges (`DataAssetV2`, `RealDataAsset`) are never the answer — they mean two models are competing inside one context. Resolve the conflict by evolving the single definition or splitting the context.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One term, one meaning | Exactly one definition per Bounded Context | Multiple definitions, or hedged ones ("usually", "generally") |
| No synonyms in use | Synonyms documented as banned; code/docs use only the canonical term | Any synonym in code, API names, or docs |
| Language in the code | Canonical term appears verbatim in types, tables, API fields, Gherkin | Code dialect differs from spoken language |
| Type assigned | Every term has a DDD type (Entity, Value Object, Aggregate Root, Event, Command…) | Untyped terms — underspecified |
| Context-scoped | Language explicitly linked to a named Bounded Context | A "global" glossary with no boundaries |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Global glossary** — one enterprise vocabulary forced on every context | Flattens legitimate homonyms into vague definitions that fit nobody | One language per Bounded Context; document homonyms + their boundary mechanisms |
| **Developer dialect** — code says `FileRecord`, people say "DataAsset" | Translation lives in engineers' heads; every hand-off re-drifts | Canonical term verbatim in types, tables, API fields, Gherkin |
| **Definition by implementation** — "a DataAsset is a row in `data_assets`" | Ties the concept to today's storage; says nothing about meaning or rules | Define in domain terms with invariants; the table is a consequence |
| **Glossary shelfware** — terms defined once, never enforced | The language decays; six months on the glossary describes a dead system | Wire enforcement into code/API/Gherkin review and the drift-detector hook |
| **Banning synonyms without renaming code** — glossary bans "file" while `File` types remain | Glossary and codebase disagree; the codebase wins | A synonym ban is complete only when code, tests, APIs, docs are all renamed |

---

## Output Format

Produce a per-Bounded-Context Ubiquitous Language document. The full copy-ready template — frontmatter, context-boundary paragraph, per-term table, banned-synonyms reference, and homonym map — is in **`references/ul-discovery-and-curation.md`**.
