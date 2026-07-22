# Fragment Ownership Canvas

Fill-in worksheet for deciding whether a candidate slice should become its
own independently-deployed fragment, and recording the decision once made.
One canvas per fragment. Copy the template, fill in every field, delete
the guidance comments. Expressed as a Miro board spec per
`miro-board-notation`.

---

Color Legend: `gray` = field label, `blue` = filled-in value, `red` =
litmus test failed (boundary not ready).

**Items:**

```markdown
| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| F1 | frame | Fragment Ownership Canvas — <fragment name> | — | — |
| L1 | sticky_note | Bounded Context alignment | F1 | gray |
| V1 | sticky_note | <which Bounded Context this fragment maps to, per bounded-context-mapping/subdomain-distillation> | F1 | blue |
| L2 | sticky_note | Owning team | F1 | gray |
| V2 | sticky_note | <team name, or "not yet assigned — single-operator phase"> | F1 | blue |
| L3 | sticky_note | Independent deployability litmus test | F1 | gray |
| V3 | sticky_note | <yes/no — can this build/test/deploy alone right now, with no coordinated release?> | F1 | blue or red |
| L4 | sticky_note | Composition role | F1 | gray |
| V4 | sticky_note | <host / remote / bidirectional> | F1 | blue |
| L5 | sticky_note | Shared singleton dependencies | F1 | gray |
| V5 | sticky_note | <e.g. react, react-dom, design-system package — with requiredVersion> | F1 | blue |
| L6 | sticky_note | Shell context fields consumed | F1 | gray |
| V6 | sticky_note | <e.g. current user, tenant id, feature flags — or "none"> | F1 | blue |
| L7 | sticky_note | Shell↔fragment contract version | F1 | gray |
| V7 | sticky_note | <semver of the exposed props/events/modules surface> | F1 | blue |
| L8 | sticky_note | Status | F1 | gray |
| V8 | sticky_note | <proposed / active / deprecated> | F1 | blue |
```

**Connectors:** none — this canvas is a filled-in form, not a relationship
diagram. Use a separate board spec if mapping relationships between
multiple fragments' Bounded Contexts.

---

## Completion rules

- **Field 1 (Bounded Context alignment) is required and drives everything
  else** — a fragment proposed before its Bounded Context is modeled
  should not be filled in yet; model the Bounded Context first
  (`bounded-context-mapping`, `subdomain-distillation`), then draw the
  fragment line to match. This repo's actual product doesn't have a
  finalized Context Map yet — this canvas cannot be meaningfully completed
  for it until that happens.
- **Field 3 (litmus test) gates the rest.** A "no" answer (marked `red`)
  means the boundary is not ready — either the boundary is wrong or a
  shared dependency still needs to move before this fragment should exist
  independently. Do not proceed to fields 5–8 with a "no" here; fix the
  boundary first.
- **Field 2 (owning team)** may legitimately read "not yet assigned —
  single-operator phase" for this repo's current state — the fragment
  boundary can be drawn correctly (aligned to a Bounded Context) before a
  second team exists to own it. This is expected during the transition
  period, not an error.
- **Field 5 must list every shared dependency explicitly**, not just
  "React" — per `references/module-federation-config.md`, an incomplete
  singleton list is the most common Module Federation production failure
  mode.
- Re-fill this canvas whenever the Bounded Context it maps to is
  reclassified (`subdomain-distillation`) or its Context Map relationship
  changes — a fragment boundary is only as stable as the domain boundary
  it mirrors.
