# Skill: core/glossary

## Purpose

Manages and validates the SDLC Artifact Factory's canonical Ubiquitous Language. Ensures every artifact uses defined terms consistently. This skill is the single source of truth for terminology across all phases, agents, and bounded contexts.

## Invocation

Invoked by:
- `/sdlc-glossary [query|add|update] [term]`
- The `post-artifact-created` hook — scans every new artifact for terminology drift
- Any skill that generates an artifact — called at the end to self-check before writing the file
- `/sdlc-review` — included in every methodology review

---

## Actions

### Query
When asked to look up a term (e.g. `/sdlc-glossary "Transactional Outbox"`):
1. Search the canonical glossary in `CLAUDE.md` under `## Canonical Ubiquitous Language`.
2. Return the term's definition, its category, and one sentence on correct vs incorrect usage.
3. If the term is not in the canonical glossary, search BC-specific glossaries at `artifacts/design/language/{bc-name}.md`.
4. If found nowhere, report it as an undefined term and suggest adding it.

### Validate (terminology drift scan)
When given an artifact path or artifact content:
1. Extract all noun phrases and technical terms from the artifact.
2. For each term, check against:
   - The canonical glossary in `CLAUDE.md`
   - The BC-specific glossary for the bounded context this artifact belongs to (if applicable)
3. Flag any term that:
   - Is not defined in either glossary (undefined term)
   - Is used in a way inconsistent with its definition (misuse)
   - Is a known synonym for a defined term rather than the canonical term itself (synonym drift)
4. Produce a terminology drift report.

**Report format:**
```markdown
## Terminology Drift Report
**Artifact:** {path}
**Scanned at:** {timestamp}
**Status:** PASS | WARN | FAIL

### Findings
| Term used | Issue | Canonical term | Action |
|-----------|-------|----------------|--------|
| ... | Undefined | — | Define in BC glossary or use existing term |
| ... | Synonym drift | Event-Driven Architecture | Replace with canonical term |
```

Save report to `artifacts/core/reviews/terminology-drift-{timestamp}.md` and update `sdlc-manifest.json` with a warning entry if any findings are WARN or FAIL.

### Add term
When asked to add a new term (e.g. `/sdlc-glossary add "Golden Record" "A single, authoritative..."`):
1. Determine scope: is this a canonical (cross-product) term or a BC-specific term?
   - If the term applies universally across all products → propose adding it to `CLAUDE.md`. Do NOT modify `CLAUDE.md` directly. Present the proposed entry and ask for confirmation.
   - If the term is specific to a bounded context → append it to `artifacts/design/language/{bc-name}.md` directly.
2. Check for conflicts with existing terms before adding.
3. After addition, run a drift scan on the artifact that triggered the need for this term.

### Update term
When asked to update an existing definition:
1. Locate the term in the canonical glossary or BC glossary.
2. Present the current definition and proposed new definition side by side.
3. Ask for confirmation before modifying.
4. After update, run a cross-artifact drift scan to identify artifacts that may need updating.

---

## Terminology Drift Severity

| Severity | Condition | Action |
|----------|-----------|--------|
| INFO | Term is defined and used correctly | No action |
| WARN | Term used is a synonym for a canonical term | Replace synonym with canonical term |
| WARN | Term is defined in a different BC's glossary, used without ACL reference | Flag for review |
| FAIL | Term is completely undefined | Block phase advance until resolved or acknowledged |
| FAIL | Term is used in contradiction to its definition | Block phase advance until resolved or acknowledged |

A FAIL-level finding blocks `/sdlc-next` unless explicitly acknowledged with a justification in `sdlc-manifest.json`.

---

## Cross-Bounded-Context Term Usage

When an artifact in Bounded Context A uses a term defined in Bounded Context B's glossary:
- This is a potential **context leakage** violation.
- The artifact should reference the concept through the BC-A model's translation of it (Anti-Corruption Layer).
- Flag as WARN and suggest the correct ACL-mediated term.
