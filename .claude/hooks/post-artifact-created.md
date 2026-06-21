# Hook: post-artifact-created

## Trigger
Fires immediately after any skill completes and writes an artifact to disk.

## Purpose
Register the artifact in the manifest, run a terminology drift scan against the ubiquitous language glossary, and surface any undefined or misused terms. This is the quality gate that runs after every artifact is produced.

## Execution

### Step 1: Register artifact in manifest

```
Read: sdlc-manifest.json
Add to artifacts array:
  {
    "id": "{phase}/{artifact-type}/{slug}",
    "path": "{relative path from product root}",
    "skill": "{skill name that produced it}",
    "phase": "{current phase}",
    "created_at": "{ISO 8601}",
    "status": "complete",
    "dod_items_satisfied": ["{DoD item 1}", "{DoD item 2}"]
  }
Write: sdlc-manifest.json
```

### Step 2: Identify the ubiquitous language sources

```
Always load:
  CLAUDE.md → Canonical Ubiquitous Language section (factory-level terms)
  
If artifacts/design/language/ exists:
  Load all {bc-name}.md files from artifacts/design/language/
  These extend the factory terms with product-specific BC terms
```

### Step 3: Run terminology drift scan

For each term in the ubiquitous language glossary:
1. Scan the newly created artifact for:
   - **Synonyms**: Terms not in the glossary that mean the same as a canonical term
   - **Undefined terms**: Domain-sounding terms used in the artifact that are not in any glossary
   - **Cross-BC contamination**: Terms from one BC's glossary used in an artifact belonging to a different BC, without an explicit ACL translation note
   - **Stale terms**: Terms that were canonical in an earlier phase but have been superseded by a newer definition

### Step 4: Classify drift findings

```
DEFECT: A term from another BC is used directly without ACL translation
         → Flag as: TERMINOLOGY_DEFECT — cross-context term usage
         
WARNING: A synonym is used instead of the canonical term
         → Flag as: TERMINOLOGY_WARNING — synonym detected; suggest canonical term
         
INFO: An undefined term is used (not in any glossary)
      → Flag as: TERMINOLOGY_INFO — term not in glossary; add if intentional
```

### Step 5: Output drift report

If any drift findings exist:

```
Terminology Scan — {artifact path}
────────────────────────────────────────────────────────

{If DEFECTS:}
TERMINOLOGY DEFECTS (must fix — methodology violation):
  Line {N}: "{term used}" — belongs to {BC name} bounded context
            Correct: translate via ACL or use the canonical term from THIS context
            Canonical term (this context): {correct term}

{If WARNINGS:}
TERMINOLOGY WARNINGS (should fix):
  Line {N}: "{synonym used}" — canonical term is "{canonical term}"

{If INFO only:}
New terms detected — add to glossary if these are domain concepts:
  "{term 1}", "{term 2}"

────────────────────────────────────────────────────────
Artifact registered in manifest: {artifact id}
```

If no drift findings:

```
Terminology scan: CLEAN
Artifact registered: {artifact id}
```

### Step 6: Write drift record if defects found

If DEFECTS (not just warnings or info), write a terminology drift record:

**File:** `artifacts/core/reviews/terminology-drift-{timestamp}.md`
**Content:**
```markdown
# Terminology Drift: {artifact path}
**Date:** {date}
**Artifact:** {artifact path}
**Phase:** {phase}

## Defects

{list of defects with line numbers and canonical corrections}

## Status
OPEN — requires correction before phase can advance
```

### Severity guidance
- **DEFECT**: The `sdlc-review` command will surface this as a blocking finding.
- **WARNING**: Non-blocking; the user is encouraged to fix for consistency.
- **INFO**: Informational only; logged to the drift record but no action required.
