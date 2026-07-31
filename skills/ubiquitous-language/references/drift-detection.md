# Terminology Drift: How It Appears, How to Detect It, How to Correct It

Companion reference to `SKILL.md`. The body states that a Ubiquitous Language decays the moment it stops being enforced. This file is the enforcement half: the specific patterns drift takes, the detection techniques for each medium, the correction workflow, and how it wires into the `terminology-drift-detector` hook and `glossary-management`.

---

## 1. What drift is

**Terminology drift** is the widening gap between the words the team *speaks* and the words the code, tests, APIs, and docs actually *use*. Because the Ubiquitous Language is only ubiquitous if it is used identically everywhere (Evans), any medium that starts using a different word has forked the language. The code does not know it has drifted; drift is invisible until someone measures it.

Drift is corrosive rather than catastrophic. No single divergence breaks the system. But each one re-introduces a translation step in someone's head, and translation steps are where semantic bugs are born — a `File` that means "discovered document" to one service and "audit evidence" to another, silently joined on the wrong key.

---

## 2. The patterns drift takes

Drift shows up in recognisable shapes. Learn to spot each.

### 2.1 Synonym creep

Two words for one concept. The team agreed on `DataAsset`, but a new endpoint returns a `file` field, a migration adds a `documents` table, a log line says "record processed". Each author reached for a synonym instead of the canonical term. This is the single most common drift pattern because synonyms feel harmless in isolation.

Symptom in code:
```go
// Drift: three names for one concept across three layers
type FileDTO struct { ... }          // API layer says "file"
func (r *repo) SaveDocument(...)      // persistence layer says "document"
// domain layer correctly says DataAsset
```

### 2.2 Code names diverging from spoken names (developer dialect)

The team says "DataAsset"; the code says `FileRecord`. The concept is right but the *word* is wrong, and the translation lives only in engineers' heads. Every hand-off — a new engineer reading the code, a PM reviewing an artifact, a downstream service consuming an event — re-does that translation and risks getting it wrong. This is Evans' Intention-Revealing Interface failing: the name does not reveal the domain concept.

### 2.3 Definition-by-implementation

The glossary once said "a DataAsset is a classified file"; six months on, the only surviving definition is the struct, and the struct has grown a `legacy_scan_id` field nobody can explain. The concept has drifted to match the storage rather than the domain.

### 2.4 Homonym collapse

A term that was a legitimate cross-context homonym (`asset` in Discovery vs Audit) starts being used interchangeably *inside one context* because someone copied a type across the boundary without the Anti-Corruption Layer. Now one context has two meanings for one word with no qualifier — genuine ambiguity.

### 2.5 Stale/retired-term resurrection

A term retired months ago reappears in a new PR because the author copied an old example. The word is no longer canonical but nothing stopped it returning.

---

## 3. Detection techniques, per medium

Drift hides in different places in each medium; detect it where it lives.

### 3.1 Code (Go)

- **Grep the banned-synonym list against identifiers.** For every banned synonym in the glossary (`file`, `document`, `record` → `DataAsset`), search type names, struct fields, method names, and package names. A hit is a candidate finding.
  ```bash
  # canonical is DataAsset; flag banned synonyms appearing as identifiers
  grep -rniE '\b(FileRecord|DocumentDTO|ScanRecord)\b' --include='*.go' internal/
  ```
- **Compare exported identifiers to the glossary.** Every exported type/method in a domain package should map to a canonical term or a deliberately-internal helper. An exported name matching no glossary term is either a missing term (add it) or drift (rename it).
- **Table and column names.** Migrations are a frequent drift entry point because they are written fast. `documents` table backing a `DataAsset` Aggregate is drift.

### 3.2 API contracts (OpenAPI)

- Field names in request/response schemas must be canonical. `"file_path"` is fine (path is not a banned synonym); a top-level `"file"` object where the domain says `DataAsset` is drift. API drift is the most damaging kind because it leaks the wrong word to *external* consumers, who then encode it in *their* systems.

### 3.3 Tests and Gherkin

- Scenario text is prose and drifts easily. "Given a file that has been scanned" should read "Given a DataAsset that has been classified". Because Gherkin is the executable specification (BDD), drift here means the specification itself speaks a different language than the code it verifies.

### 3.4 Prose artifacts (ADRs, design docs, vision statements)

- These are where synonyms slip in most freely because prose has no compiler. This is exactly what the `terminology-drift-detector` hook exists to catch (see Section 5).

---

## 4. The correction workflow

Detecting drift is only useful if correction is systematic. Follow this loop for every confirmed finding.

1. **Classify the finding.** Is it (a) a synonym that should be renamed to canonical, (b) a genuinely new concept the language is missing a word for, or (c) a homonym that needs a qualifier or an ACL? Misclassifying (b) as (a) — renaming away a real new concept — destroys information, so this step is not optional.
2. **If synonym (a):** rename across *all* media in one coordinated change — code, tests, API schema, Gherkin, docs. A synonym ban is complete only when every medium uses the canonical term. A glossary that bans "file" while `File` types remain has not corrected the drift; it has merely documented that the codebase is winning.
3. **If missing concept (b):** run the discovery/entry procedure in `references/ul-discovery-and-curation.md` Section 4.1 — draft the definition, assign a type, agree it, publish via `glossary-management`, *then* let it into code.
4. **If homonym (c):** record it in both contexts' homonym maps and ensure the Anti-Corruption Layer at the boundary translates it. If the collapse happened *inside* one context, introduce a qualifier or split the context.
5. **Close the loop with `glossary-management`.** Any rename, new term, or retirement updates the published glossary artifact and bumps its version. The practice (this skill) and the artifact (that skill) must end the correction in agreement.
6. **Add a guard so the same drift cannot silently return.** A retired or banned term should be in the drift-detector's watch list; a repeated synonym is a candidate for a grep in CI.

Worked correction — synonym creep from Section 2.1:

```
Finding:   API returns `file`, repo method SaveDocument(), both mean DataAsset.
Class:     (a) synonym.
Action:    Rename FileDTO -> DataAssetResponse; SaveDocument -> SaveDataAsset;
           OpenAPI `file` -> `dataAsset`; Gherkin "a file" -> "a DataAsset";
           add file/document/record to glossary banned-synonyms for this context;
           bump glossary version; add the three synonyms to the drift-detector watch list.
Done-when: grep for the banned synonyms across code/specs/docs returns zero hits.
```

---

## 5. Wiring into governance

Two mechanisms make enforcement automatic rather than dependent on reviewer diligence.

### 5.1 The `terminology-drift-detector` hook

A governance hook (see `CLAUDE.md`, Command and Hook Mechanics) that inspects artifact prose for terminology consistency. It is the right shape for a `prompt`-type or `command`-type hook because the judgment it makes — "does this artifact use a banned synonym or an unknown term?" — is exactly the criteria this skill and `glossary-management` own. It runs as part of the `pre-phase-advance` gate: a phase does not advance while an artifact contains drifted terminology. The hook validates only; it does not rename — correction is the agent's job following Section 4.

Because the hook reads the published glossary to know what is canonical vs banned, the correction loop's step 5 (update `glossary-management`) is what keeps the hook accurate. A drift correction that skips the glossary update leaves the hook blind to the very synonym it should now catch.

### 5.2 Human review gates

The hook cannot see code identifiers or OpenAPI field names as reliably as it sees prose, so the review gates remain load-bearing:

- **Code review** — a banned synonym in any identifier is a rejection reason, not a nit.
- **API contract review** — schema field names must be canonical before the contract is published, because external consumers will encode whatever word ships.
- **Gherkin review** — scenario text must match the code's language, since it is the executable specification.

---

## 6. Severity — not all drift is equal

Triage findings so correction effort goes where the damage is. Drift severity is driven by *blast radius* — how far the wrong word has already propagated — not by how ugly it looks.

| Severity | Where the drift is | Why it ranks here | Correction urgency |
|---|---|---|---|
| **Critical** | Published API field name / Domain Event payload key | External consumers encode the wrong word into *their* systems; the fix later requires a coordinated cross-team migration | Block release; fix before the contract ships |
| **High** | Exported Go type/method in a domain package; table/column name | The wrong word is load-bearing internally and spreads with every new caller | Fix in the current PR |
| **Medium** | Gherkin scenario text; internal (unexported) identifiers | Specification/implementation speak different languages, but blast radius is contained | Fix before the feature merges |
| **Low** | Prose in a design doc/ADR | No compiler or consumer depends on it; the `terminology-drift-detector` hook usually catches it | Fix at next edit; hook-gated |

The ranking has a direct consequence: **API and event-schema drift is always corrected before it ships**, because a published wrong word is the one kind of drift you cannot fix cheaply later — every external consumer has already copied it.

---

## 7. Periodic drift audit

Review gates and the hook catch drift as it is introduced, but accumulated drift from before enforcement was tightened needs a deliberate sweep. Run a drift audit at the start of each Design-phase domain session (the `domain-modeler` entry point):

1. Pull the current banned-synonym list and retired-terms list from the published glossary (`glossary-management`).
2. Grep each banned/retired term across code, migrations, OpenAPI specs, and feature files (Section 3 techniques).
3. For each hit, classify (Section 4 step 1) and either open a correction or, if it is a genuine new concept, run the entry procedure.
4. Record the audit result — zero hits is a passing audit worth recording, because it is evidence the language and the code still agree.

An audit that keeps surfacing the same synonym is a signal the term's canonical form is not intuitive to the team — consider whether the canonical choice was wrong, not just whether the offenders should be renamed.

---

## 8. Related references

- `references/ul-discovery-and-curation.md` — the discovery/curation half; Section 4 there defines the term lifecycle whose "change" and "retire" transitions this file's corrections feed.
- `glossary-management` — owns the published glossary the drift-detector reads and the correction loop updates.
- `bounded-context-mapping` / `context-map-patterns` — the Anti-Corruption Layer that resolves cross-context homonym drift.
- `bdd-feature-file` — Gherkin authoring, where scenario-text drift is prevented at source.
