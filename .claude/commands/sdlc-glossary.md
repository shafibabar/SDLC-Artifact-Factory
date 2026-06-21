# Command: /sdlc-glossary

## Purpose
Manage the ubiquitous language for the product. List terms, add new terms, check for drift, and identify term conflicts across bounded contexts. The authoritative command for ubiquitous language governance.

## Usage
```
/sdlc-glossary                        # List all terms in the current product's language
/sdlc-glossary --bc {name}            # List terms for a specific bounded context
/sdlc-glossary --add {bc} "{term}: {definition}"   # Add a new term to a BC glossary
/sdlc-glossary --check                # Run full terminology drift scan across all artifacts
/sdlc-glossary --conflicts            # Show terms that appear in multiple BCs with different meanings
/sdlc-glossary --search {term}        # Look up a specific term
```

## Execution

### `/sdlc-glossary` (list all)

```
Read: CLAUDE.md → Canonical Ubiquitous Language section (factory-level terms)
Read: artifacts/design/language/*.md → BC-specific terms

Output:
═══════════════════════════════════════════════════════════════
Ubiquitous Language — {product_name}
═══════════════════════════════════════════════════════════════

Factory-Level Terms (apply to all bounded contexts):
─────────────────────────────────────────────────────
Bounded Context     — An explicit boundary within which a domain model applies...
Domain Events       — Facts that occurred in the domain, named in past tense...
Read Model          — A projection of domain state optimised for querying...
[{N} terms total]

Bounded Context: File Domain
─────────────────────────────
StorageLocation     — A registered storage resource (Google Drive folder, S3 bucket...)
ScanConfiguration   — The parameters governing how a StorageLocation is scanned...
[{N} terms total]

Bounded Context: Entity Domain
────────────────────────────────
ExtractedEntity     — A named entity identified by the NER model from a file...
GoldenRecord        — The deduplicated, canonical representation of a real-world entity...
[{N} terms total]

Total terms: {N} factory + {N} BC-specific
Run /sdlc-glossary --check to scan for drift.
```

---

### `/sdlc-glossary --add {bc} "{term}: {definition}"`

```
Read: artifacts/design/language/{bc-slug}.md

Validate:
  - Term does not already exist in this BC (exact match)
  - Term does not conflict with a factory-level term unless intentionally contextual
  - Term is not a synonym of an existing term in this BC (flag if likely)
  
If valid:
  Append to artifacts/design/language/{bc-slug}.md:
    ## {Term}
    {definition}
    
    **Synonyms to avoid:** (if any detected)
    **See also:** (if related terms exist)
  
  Output: "Term '{term}' added to {BC name} ubiquitous language."
  
If conflicts detected:
  Output: "Warning: '{term}' may conflict with '{existing_term}' in the {other_bc} context.
           Confirm this is intentional — document the translation in bounded-contexts.md."
```

---

### `/sdlc-glossary --check`

```
Invoke: terminology-drift-detector hook (full scan, all phases)
Output: drift report summary with link to full report
```

---

### `/sdlc-glossary --conflicts`

```
Read: all BC language files
Find: terms that appear in more than one BC

For each conflict:
  Show: term name, BC A definition, BC B definition, divergence notes
  
Output:
───────────────────────────────────────────────────────────────
Term: "Entity"

  File Domain:
    "An entity is a data record extracted from a file — an instance of
    a named entity type (e.g. a specific email address)."

  Entity Domain:
    "Entity (or ExtractedEntity) is a domain object representing a
    detected piece of sensitive information with type, confidence score,
    and source file reference."

  Divergence type: CONTEXTUAL (same concept, different precision)
  ACL translation: Entity (File Domain) → ExtractedEntity (Entity Domain)
  Documented in bounded-contexts.md: YES / NO

Recommendation: Document this divergence in bounded-contexts.md if not already present.
```

---

### `/sdlc-glossary --search {term}`

```
Search: factory glossary + all BC glossaries for {term} (case-insensitive, partial match)

Output:
Found "{term}" in 2 locations:

  [Factory] Ubiquitous Language
    "{canonical definition}"

  [File Domain]
    "{contextual definition for this BC}"
    Synonyms to avoid: {list}
```
