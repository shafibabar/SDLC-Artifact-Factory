# Subdomain Classification Canvas

Fill-in worksheet operationalizing the full classification for one
subdomain — combining `SKILL.md`'s Core/Supporting/Generic classification
with every technique from `references/classification-techniques.md`,
`references/security-sensitive-subdomains.md`, and
`references/legacy-transformation-guidance.md`. One canvas per subdomain.
Copy the template, fill in every field, delete the guidance comments.
Expressed as a Miro board spec per `miro-board-notation`.

---

Color Legend: `gray` = field label, `blue` = filled-in value.

**Items:**

```markdown
| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| F1 | frame | Subdomain Classification Canvas — <subdomain name> | — | — |
| L1 | sticky_note | Classification | F1 | gray |
| V1 | sticky_note | <core / supporting / generic> | F1 | blue |
| L2 | sticky_note | Outsource test (Vernon) | F1 | gray |
| V2 | sticky_note | <yes/no — would you outsource it, and why> | F1 | blue |
| L3 | sticky_note | Complexity vs. strategic importance (Khononov) | F1 | gray |
| V3 | sticky_note | <quadrant: core / complicated-not-core / core-simple / generic> | F1 | blue |
| L4 | sticky_note | Wardley evolution stage (Kaiser) | F1 | gray |
| V4 | sticky_note | <genesis / custom-built / product-rental / commodity> | F1 | blue |
| L5 | sticky_note | Security-sensitive? (Secure by Design) | F1 | gray |
| V5 | sticky_note | <yes/no — which checklist question(s) triggered it, if yes> | F1 | blue |
| L6 | sticky_note | If security-sensitive, which slice needs Core-level rigor | F1 | gray |
| V6 | sticky_note | <the specific slice, or "n/a"> | F1 | blue |
| L7 | sticky_note | Transformation priority (legacy only) | F1 | gray |
| V7 | sticky_note | <tier + rationale, or "n/a — greenfield"> | F1 | blue |
| L8 | sticky_note | Rationale | F1 | gray |
| V8 | sticky_note | <why this classification, in one or two sentences> | F1 | blue |
| L9 | sticky_note | Revisit trigger | F1 | gray |
| V9 | sticky_note | <what would change this classification — e.g. "if this moves to Commodity stage"> | F1 | blue |
```

**Connectors:** none — this canvas is a filled-in form, not a relationship
diagram. Use `references/classification-techniques.md`'s Wardley board spec
separately for a comparative, multi-subdomain view.

---

## Completion rules

- Fields 1–2 and 8–9 (Classification, Outsource test, Rationale, Revisit
  trigger) are always required — every subdomain gets a base classification
  regardless of context.
- Field 3 (Khononov's quadrant) is required whenever the base classification
  is ambiguous between Core and Supporting — it's what disambiguates "hard"
  from "important." If the base classification was obvious, this field may
  be filled in briefly rather than skipped.
- Field 4 (Wardley stage) is required for every subdomain — it's what makes
  the Revisit trigger (field 9) concrete rather than vague. "Revisit if this
  moves toward Commodity" only means something once a current stage is
  recorded.
- Fields 5–6 (security-sensitivity) are required to at least answer
  yes/no — per `security-sensitive-subdomains.md`, this is a separate axis
  from Core/Supporting/Generic and must not be skipped just because the base
  classification is Generic or Supporting. A "no" answer still needs the
  checklist to have actually been run, not assumed.
- Field 7 (transformation priority) is `n/a — greenfield` for a new
  product with no legacy system, and required with a real tier for any
  subdomain being classified as part of an existing system's transformation
  effort (see `legacy-transformation-guidance.md`).
- This canvas is a hypothesis, not a permanent record — re-fill it whenever
  its own Revisit trigger fires, rather than treating a completed canvas as
  final.
