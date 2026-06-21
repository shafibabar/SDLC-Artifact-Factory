# Hook: terminology-drift-detector

## Trigger
Fires on demand when `/sdlc-glossary --check` is run, or when the `sdlc-review` command is run and identifies that the last terminology scan was more than 7 days ago.

## Purpose
Perform a full cross-artifact terminology scan — not just the most recently created artifact (that is `post-artifact-created`'s job). This hook scans all artifacts in the current phase directory and produces a drift report across the full artifact set. Used to catch terminology drift that accumulated over multiple artifact generations.

## Execution

### Step 1: Load all glossary sources

```
Load: CLAUDE.md → Canonical Ubiquitous Language section
Load: artifacts/design/language/*.md → all BC-specific ubiquitous language files
Merge into: combined_glossary = {term: {canonical_name, bc_scope, definition, synonyms[]}}
```

### Step 2: Identify artifact set to scan

If run by `sdlc-review`:
- Scan all artifacts in `artifacts/{current_phase}/`

If run by `/sdlc-glossary --check`:
- Scan all artifacts in `artifacts/` (all phases)

### Step 3: For each artifact, perform drift detection

**Synonym detection:** For each term in `combined_glossary.synonyms[]`, search the artifact for the synonym string. If found, report the canonical term and location.

**Undefined term detection:** Extract noun phrases that appear to be domain concepts (PascalCase compound nouns, terms followed by "domain" or "service" or "event"). Check against `combined_glossary`. If not found, flag as potentially undefined.

**Cross-BC contamination:** For each BC-specific term in the glossary, check whether it appears in artifacts that belong to a different BC without the marker `[ACL]` or `[translation]` nearby.

**Recency check:** Compare artifact creation dates vs. glossary last-updated date. If a glossary term was renamed/added after an artifact was created, that artifact may contain the old term.

### Step 4: Produce consolidated drift report

**File:** `artifacts/core/reviews/terminology-drift-{YYYY-MM-DDTHH-MM}.md`

```markdown
# Terminology Drift Report — Full Scan
**Date:** {date}
**Phase:** {current phase}
**Artifacts scanned:** {N}
**Glossary terms:** {N canonical + N BC-specific}

---

## Summary

| Severity | Count |
|----------|-------|
| DEFECT (cross-BC contamination) | {N} |
| WARNING (synonym used) | {N} |
| INFO (undefined term) | {N} |

---

## DEFECTS — Cross-Context Term Usage

### {artifact path}
| Line | Term used | Belongs to | Canonical term (this context) |
|------|-----------|-----------|-------------------------------|
| {N} | `StorageAsset` | File Domain | `StorageLocation` (Compliance Domain) |

---

## WARNINGS — Synonyms

### {artifact path}
| Line | Synonym used | Canonical term |
|------|-------------|---------------|
| {N} | `data store` | `StorageLocation` |

---

## INFO — Potential Undefined Terms

The following terms appear to be domain concepts but are not in the glossary. If intentional, add them to the appropriate BC language file:
- `ScanJob` (appears in {artifact path}:{line})
- `ExtractionResult` (appears in {artifact path}:{line})

---

## Artifacts with No Drift

{list of artifact paths with CLEAN status}

---

## Recommended Actions

1. Fix DEFECTS: Add ACL translation notes or replace cross-BC terms with context-local terms
2. Fix WARNINGS: Replace synonyms with canonical terms
3. Review INFO items: Add to glossary or confirm they are implementation details (not domain concepts)
```

### Step 5: Update manifest

```json
{
  "last_terminology_scan": "{ISO 8601}",
  "terminology_drift_report": "artifacts/core/reviews/terminology-drift-{timestamp}.md",
  "open_terminology_defects": {N}
}
```
