---
name: ubiquitous-language
description: >
  Teaches how to build, maintain, and enforce a Ubiquitous Language for a
  Bounded Context — including term discovery, definition format, homonym and
  synonym detection, term ownership rules, and how the language evolves as
  domain understanding deepens. Ubiquitous Language is the foundation of all
  DDD work; every other domain-modeling artifact depends on it. Used by the
  domain-modeler agent at the start of every Design phase domain session.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, ubiquitous-language, bounded-context, glossary]
---

# Ubiquitous Language

## Purpose

Ubiquitous Language (Eric Evans, *Domain-Driven Design*) is the shared, precise vocabulary used by everyone working in a Bounded Context — engineers, product managers, and domain experts — in all communication: conversations, code, tests, documentation, and APIs.

The word "ubiquitous" means the language must be used everywhere, without translation. A term used differently in code than in conversation, or differently between two engineers, is a defect in the language — not a stylistic difference.

Without a Ubiquitous Language, every boundary crossing (engineer ↔ domain expert, service ↔ service, spec ↔ test) introduces translation cost and the opportunity for subtle semantic errors that cause real bugs.

---

## One Language Per Bounded Context

Ubiquitous Language is **scoped to a Bounded Context**. The same word can legitimately mean different things in different Bounded Contexts:

| Term | Bounded Context A | Bounded Context B |
|---|---|---|
| `File` | A document in the customer's storage estate — has a path, type, sensitivity classification | A compliance evidence file submitted to an auditor |
| `User` | A person who logs into the platform | A data subject whose personal data is in a discovered file |

This is not a problem — it is intentional DDD design. The Bounded Context boundary is precisely where the meaning changes. What is a defect is using both meanings in the same context without distinguishing them.

---

## Term Discovery

Terms for the Ubiquitous Language are discovered through Event Storming, domain storytelling, and direct conversation with domain experts. The following sources reliably surface terms:

| Source | Terms discovered |
|---|---|
| Event Storming orange cards (Domain Events) | Verbs and nouns that describe what happens in the domain |
| Event Storming blue cards (Commands) | Action verbs — what actors tell the system to do |
| Event Storming yellow cards (Aggregates) | Nouns — the things that receive commands and emit events |
| Domain storytelling | The natural language domain experts use when narrating their workflow |
| User stories and job stories | Nouns and verbs from the "As a / I want to / so that" structure |
| Acceptance criteria | Edge-case terms that often reveal missing domain concepts |

---

## Term Definition Format

Every term in the Ubiquitous Language must be defined using this format:

```
Term:        [Exact term as used in this Bounded Context — PascalCase for types, sentence case for concepts]
Definition:  [What this term means in this Bounded Context — one or two sentences, no jargon]
Type:        [Entity | Value Object | Aggregate Root | Domain Event | Command | Read Model | Policy | Concept]
Synonyms:    [Terms that mean the same thing — these synonyms are BANNED; only the canonical term may be used]
Homonyms:    [The same word used in another Bounded Context with a different meaning — note the other context]
Invariants:  [Rules that are always true about this term — what must never be violated]
Example:     [One concrete example that makes the definition unambiguous]
```

### Example Term Definition

```
Term:        DataAsset
Definition:  A file discovered in a connected storage source that has been classified by
             the system. A DataAsset has a path, a storage source, a sensitivity
             classification, and one or more extracted entity types.
Type:        Aggregate Root
Synonyms:    file, document, record — BANNED in this context; use DataAsset exclusively
Homonyms:    In the Audit context, "asset" means a compliance evidence item, not a
             discovered file.
Invariants:  A DataAsset always has a sensitivity classification (it may be Unclassified
             if the classification engine has not yet run, but the field always exists).
             A DataAsset always belongs to exactly one StorageSource.
Example:     A PDF at gs://acme-drive/HR/contracts/smith_offer_letter.pdf, classified
             as Restricted, containing PersonallyIdentifiableInformation and
             ContractualObligation entity types.
```

---

## Synonym Elimination

Synonyms are the most common source of language drift. When two engineers use two different words for the same concept, their mental models diverge — and the code eventually diverges with them.

**Rule:** Choose one term. Document the synonyms as banned. Enforce the canonical term in all code, tests, APIs, and documentation.

**Enforcement mechanisms:**
- Code review checklist: any synonym in a type name, field name, or variable name is a rejection reason
- API contract review: field names in OpenAPI specs must use the canonical term
- Test file review: scenario descriptions in Gherkin feature files must use the canonical term
- Terminology drift detector hook flags synonyms in artifact prose

---

## Homonym Documentation

Homonyms (same word, different meaning in a different Bounded Context) must be documented to prevent confusion as the system grows. They are not errors — they are boundaries. But they must be explicit.

Every homonym must be listed with:
- The term
- Its meaning in this Bounded Context
- The other Bounded Context(s) where it appears
- The different meaning there
- The Anti-Corruption Layer or translation mechanism that handles the boundary crossing

---

## Language Evolution

A Ubiquitous Language is not static. As the team's understanding of the domain deepens, the language must evolve:

| Trigger | Action |
|---|---|
| Domain expert uses a term the team hasn't defined | Add the term using the discovery process above |
| A term's definition is consistently misunderstood | Rewrite the definition; run a domain storytelling session to validate the new definition |
| Two terms are discovered to mean the same thing | Choose one; document the other as a banned synonym; rename in code |
| A term means different things in different sub-domains | Consider a Bounded Context split; or introduce a qualifier to disambiguate |
| A concept the language has no word for keeps appearing | Name it; add it to the glossary; align the team before it appears in code |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One term, one meaning | Every term has exactly one definition per Bounded Context | Terms with multiple definitions, or definitions that hedge |
| No synonyms in use | All synonyms are documented as banned; code and docs use only canonical terms | Any synonym appearing in code, API names, or documentation |
| Type assigned | Every term has a DDD type (Entity, Value Object, Aggregate Root, etc.) | Terms with no type — these are underspecified |
| Invariants documented | Every Aggregate Root and Entity has at least one invariant | Aggregate Roots with no invariants — they have no rules |
| Concrete example | Every term has a concrete example using real-world data | Abstract definitions that leave room for interpretation |
| Context-scoped | The language is explicitly linked to a named Bounded Context | A "global" glossary with no context boundaries |

---

## Output Format

```markdown
---
artifact: ubiquitous-language
product: [product name]
bounded-context: [Bounded Context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Ubiquitous Language: [Bounded Context Name]

## Context Boundary
[One paragraph describing what this Bounded Context is responsible for and where its boundary lies]

## Terms

### [Term]
| Field | Value |
|---|---|
| **Definition** | [definition] |
| **Type** | [DDD type] |
| **Synonyms (banned)** | [list] |
| **Homonyms** | [term in other contexts and their meanings] |
| **Invariants** | [rules that are always true] |
| **Example** | [concrete example] |

[Repeat for each term]

## Banned Synonyms Reference
| Banned term | Canonical term |
|---|---|

## Homonym Map
| Term | This context meaning | Other context | Other meaning | Boundary mechanism |
|---|---|---|---|---|
```
