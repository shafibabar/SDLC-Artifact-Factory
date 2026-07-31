# Ubiquitous Language: Discovery, Curation, and the Term Lifecycle

Companion reference to `SKILL.md`. This file holds the mechanical detail the body points to: the term-definition format, the per-source discovery procedure, the one-language-per-Bounded-Context rules and what happens at context boundaries, the full lifecycle by which a term enters, changes, and retires, and the copy-ready output template.

---

## 1. One Language Per Bounded Context — the full rules

The Ubiquitous Language (Evans) is scoped to exactly one Bounded Context. The same word carrying two meanings in two contexts is not a bug — it is the boundary showing itself. Khononov names the underlying force precisely: a **Bounded Context boundary is a linguistic/model-consistency boundary**, which exists at the point a Ubiquitous Language term's meaning changes. This is a *different force* from an Aggregate boundary (transactional consistency) and from a module/service boundary (deployment). They often nest cleanly — one service, one Bounded Context, several Aggregates — but nothing forces them to align, and conflating them is a category error.

Rules that follow from this:

1. **Never build a single global vocabulary across contexts.** Flattening `asset` (a discovered file in Data Discovery; a compliance evidence item in Audit) into one enterprise-wide definition yields a lowest-common-denominator term that fits neither context. Keep one language per context.
2. **A term is only defined relative to its context.** Every entry names the Bounded Context it belongs to. `DataAsset` in Data Discovery and `DataAsset` in a downstream Graph context are two definitions, even if they look similar.
3. **Meaning changes are handled by translation at the boundary, not by renaming inside.** When a term crosses into another context with a different meaning, the crossing is a Context Map relationship — most commonly an **Anti-Corruption Layer** (ACL) that translates the upstream shape into this context's own terms so the foreign model never leaks in. See `context-map-patterns` and `bounded-context-mapping` for the relationship catalogue.

### Homonyms at the boundary — worked example

`File` in **Data Discovery** is a discovered document (path, storage source, sensitivity classification). `File` in **Compliance/Audit** is an evidence file an auditor submitted. Both are legitimate. The rule is not "pick one"; it is:

- Define each in its own context with its own invariants.
- Record the homonym explicitly in each context's homonym map (see the template below).
- Name the ACL or translation step that runs when data crosses. A discovered `File` becoming audit evidence passes through an ACL that maps `DataAsset` → `EvidenceItem`, dropping fields the Audit context has no word for and renaming those it does.

The failure mode is using both meanings *inside the same context* without a qualifier — that is genuine ambiguity that ships as a bug.

---

## 2. Discovery procedure, per source

Terms are discovered from how domain experts already speak, not invented at a whiteboard. Run these sources in roughly this order.

### 2.1 Direct conversation with domain experts

The primary well. Data Steward and Compliance Officer personas each carry vocabulary the other lacks.

Procedure:

1. Have the expert narrate a real workflow in their own words ("Walk me through what happens when a new Google Drive is connected").
2. Transcribe verbatim. Do **not** paraphrase into engineering terms — paraphrasing is where the first drift enters.
3. Circle every noun and verb that carries domain weight ("classify", "sensitivity", "restricted", "steward", "evidence", "attestation").
4. For each, ask the expert to define it and, critically, to give an example and a counter-example ("What is *not* Restricted?"). Counter-examples surface hidden invariants.
5. Chase every hedge. When an expert says "usually a file is classified within an hour," the word *usually* marks either an undiscovered rule or a hidden second concept. Ask what the exception is and name it.

### 2.2 Event Storming

The structured group technique. Brandolini's color grammar maps directly onto term types:

| Card colour | Meaning | Terms it yields |
|---|---|---|
| **Orange** | Domain Event (something that happened, past tense) | `DataAssetClassified`, `StorageSourceConnected` — the verbs/nouns of what occurs |
| **Blue** | Command (an actor's intent) | `ClassifyDataAsset`, `ConnectStorageSource` — action verbs |
| **Yellow** | Aggregate | `DataAsset`, `StorageSource` — the nouns that receive Commands and emit Events |
| **Pink** | External system | integration-boundary terms |
| **Lilac** | Hotspot / open question | candidate terms not yet agreed |

Every card is a term candidate. The past-tense Domain Events are especially rich because they force the language to name outcomes, not just actions.

### 2.3 Domain Storytelling

Complements Event Storming. Where Event Storming yields discrete events and commands, Domain Storytelling captures the *connective* language — the roles, work objects, and sequencing words ("the Steward *reviews* the *flagged* DataAsset before it is *attested*"). Use it to validate a proposed definition: re-tell the story using the new canonical term and check the expert still recognises their own workflow.

### 2.4 Secondary sources

User stories, job stories, and acceptance criteria. Edge-case terms in acceptance criteria ("Given a DataAsset whose classification has *expired*…") often reveal a concept the language has no word for yet — the "make implicit concepts explicit" signal (Evans). When an unnamed concept keeps recurring as scattered `if` logic or a repeated parameter combination, that is the same signal from the code side: name it before it hardens.

---

## 3. Term-definition format

Every term in the Ubiquitous Language is captured in this exact shape:

```
Term:        [Exact term as used in this Bounded Context — PascalCase for types, sentence case for concepts]
Definition:  [What this term means in this Bounded Context — one or two sentences, no jargon, no implementation]
Type:        [Entity | Value Object | Aggregate Root | Domain Event | Command | Read Model | Policy | Concept]
Synonyms:    [Terms that mean the same thing — BANNED; only the canonical term may be used in code/tests/docs]
Homonyms:    [The same word in another Bounded Context with a different meaning — name the other context]
Invariants:  [Rules that are always true about this term — what must never be violated]
Example:     [One concrete example using real-world data that makes the definition unambiguous]
```

### Worked example

```
Term:        DataAsset
Definition:  A file discovered in a connected storage source that has been classified by
             the system. A DataAsset has a path, a storage source, a sensitivity
             classification, and one or more extracted entity types.
Type:        Aggregate Root
Synonyms:    file, document, record — BANNED in this context; use DataAsset exclusively.
Homonyms:    In the Compliance/Audit context, "asset" means a compliance evidence item,
             not a discovered file. Crossing handled by the Audit ACL (DataAsset →
             EvidenceItem).
Invariants:  A DataAsset always has a sensitivity classification (it may be Unclassified
             until the classification engine runs, but the field always exists).
             A DataAsset always belongs to exactly one StorageSource.
Example:     A PDF at gs://acme-drive/HR/contracts/smith_offer_letter.pdf, classified
             Restricted, containing PersonallyIdentifiableInformation and
             ContractualObligation entity types.
```

Notes on the fields:

- **Definition is in domain terms, never implementation.** "A DataAsset is a row in the `data_assets` table" is a defect — it says nothing about meaning or rules and chains the concept to today's storage.
- **Type is mandatory.** An untyped term is underspecified. Assign one of the DDD types; if it is an Aggregate Root or Entity it must carry at least one invariant.
- **Synonyms are recorded as banned**, not merely noted. A banned synonym is a code-review rejection reason (see `references/drift-detection.md`).

---

## 4. The term lifecycle — enter, change, retire

A Ubiquitous Language is a living artifact. Every term moves through a lifecycle, and each transition has a defined trigger and action.

### 4.1 A term ENTERS the language

Trigger: a domain concept surfaces (any discovery source above) that the language has no agreed word for.

Procedure:

1. Draft the definition in the format above, with the expert who used it.
2. Assign its DDD type and at least one invariant (if Entity/Aggregate Root).
3. Check for a **collision**: does this word already exist in *this* context (making it an accidental homonym-within-context — resolve by qualifier or rename) or in *another* context (a legitimate cross-context homonym — record it in both homonym maps)?
4. Record it in the context's Ubiquitous Language document (the `glossary-management` artifact publishes it).
5. Only after the team agrees may the term appear in code — introducing a term directly in code, unagreed, is how developer dialect starts.

### 4.2 A term CHANGES

Triggers and actions:

| Trigger | Action |
|---|---|
| A definition is consistently misunderstood | Rewrite it; re-validate by re-telling a Domain Story with the new wording |
| Two terms are found to mean the same thing | Choose one canonical term; mark the other banned; **rename in code, tests, APIs, docs** — the change is not done until the rename is done |
| The concept splits (one word, two meanings emerging inside one context) | Introduce a qualifier, or split the Bounded Context if the divergence is real |
| An invariant is discovered | Add it to the term; check existing code still honours it |

A change to a canonical term is a coordinated rename across every medium, never a glossary-only edit. Until code, tests, APIs, and docs all use the new term, the codebase and glossary disagree and the codebase wins — the change has not actually landed.

Never resolve a naming conflict with a version suffix (`DataAssetV2`, `RealDataAsset`, `NewScan`). A version-suffixed name means two competing models are living inside one context. Resolve by evolving the single definition or splitting the context.

### 4.3 A term RETIRES

Trigger: a concept is no longer part of the domain (a feature removed, a workflow discontinued), or a term was merged into another as a banned synonym.

Procedure:

1. Confirm no code, test, API field, or Gherkin scenario still uses it (a retired term still referenced in code is drift — see `references/drift-detection.md`).
2. Move it to a "retired terms" section rather than deleting outright — the record explains why a once-canonical word is now absent, which prevents someone re-introducing it later.
3. If it retired *into* another term (merged as a synonym), leave a banned-synonym entry pointing at the survivor.

---

## 5. Output template — per-Bounded-Context Ubiquitous Language document

Copy this shape when producing the artifact. The frontmatter follows the plugin's artifact standard (`name`, `version`, `phase`, `owner`, `created`).

```markdown
---
name: ubiquitous-language
product: [product name]
bounded-context: [Bounded Context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Ubiquitous Language: [Bounded Context Name]

## Context Boundary
[One paragraph: what this Bounded Context is responsible for and where its boundary lies —
the point at which its terms would start meaning something different.]

## Terms

### [Term]
| Field | Value |
|---|---|
| **Definition** | [definition in domain terms] |
| **Type** | [Entity / Value Object / Aggregate Root / Domain Event / Command / Read Model / Policy / Concept] |
| **Synonyms (banned)** | [list] |
| **Homonyms** | [same word in other contexts + their meanings] |
| **Invariants** | [rules always true] |
| **Example** | [concrete example with real data] |

[Repeat for each term]

## Banned Synonyms Reference
| Banned term | Canonical term |
|---|---|
| file, document, record | DataAsset |

## Homonym Map
| Term | This context meaning | Other context | Other meaning | Boundary mechanism |
|---|---|---|---|---|
| File | discovered document | Compliance/Audit | submitted evidence file | Audit ACL (DataAsset → EvidenceItem) |

## Retired Terms
| Term | Retired on | Reason | Successor (if merged) |
|---|---|---|---|
```

---

## 6. Related references

- `glossary-management` — owns the published glossary artifact and its versioning; this skill feeds it.
- `bounded-context-mapping` / `context-map-patterns` — the relationship catalogue (ACL, Shared Kernel, Conformist…) that governs cross-context term crossings.
- `aggregate-design` — where the DDD types assigned here (Aggregate Root, Entity, Value Object) get their transactional semantics.
- `event-storming` / `domain-storytelling` — the discovery techniques Section 2 draws on.
- `references/drift-detection.md` — the enforcement half of this practice.
