# Skill: strategy/strategic-roadmap

## Purpose
Produce a phased strategic roadmap that sequences delivery toward the vision, grounded in OKRs. The roadmap communicates what will be built and in what order — not a project plan with dates, but a sequenced bet on how value is best delivered incrementally.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `artifacts/strategy/okrs.md` — must exist
- `sdlc-config.json` — constraints, compliance_frameworks, tenancy_model
- Ask the user: "How many phases should the roadmap cover? What is the rough time horizon per phase?"

## Output
**File:** `artifacts/strategy/roadmap.md`
**Registers in manifest:** yes

## Roadmap Rules (enforced)
- Each phase must deliver standalone value — no phase is purely infrastructure with no user-visible outcome.
- MVP (Phase 1) is the thinnest possible vertical slice that proves the core value proposition.
- Each subsequent phase expands capability based on validated learnings from prior phases.
- Phases are outcome-labelled, not feature-labelled. "Phase 1: Prove detection accuracy" not "Phase 1: Build scanner".
- Compliance and security features are not deferred to later phases — they are designed in from Phase 1.

## Process
1. Read vision, OKRs, and config.
2. Identify the core value loop (the minimum set of capabilities that deliver the primary value to a customer).
3. Define Phase 1 as the MVP: the core value loop, nothing more.
4. Define subsequent phases as expansions: additional user segments, additional capabilities, scale, integrations.
5. For each phase, map to the OKRs it primarily advances.
6. Identify the key risks that each phase must validate before the next begins.
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Strategic Roadmap

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** Strategic Roadmap
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Roadmap Philosophy
{One paragraph on the sequencing logic: why this order, what assumptions are being tested first, what constraints drive the phasing.}

## Summary View

| Phase | Theme | Primary OKR | Key Deliverable | Validates |
|-------|-------|-------------|-----------------|-----------|
| Phase 1 — MVP | {outcome label} | {OKR ref} | {core deliverable} | {assumption being tested} |
| Phase 2 | {outcome label} | {OKR ref} | {core deliverable} | {assumption being tested} |
| Phase 3 | {outcome label} | {OKR ref} | {core deliverable} | {assumption being tested} |

---

## Phase 1 — MVP: {Outcome Label}

**Goal:** {What customer problem is solved by the end of this phase? What can a customer do that they could not before?}

**In scope:**
- {capability 1}
- {capability 2}
- {capability 3}

**Explicitly out of scope:**
- {deferred item 1 — with reason}
- {deferred item 2 — with reason}

**Key OKRs advanced:** {O1, KR1.1, KR1.2}

**Exit criteria (before Phase 2 begins):**
- {measurable criterion 1}
- {measurable criterion 2}

**Compliance/security commitments in this phase:**
- {compliance feature included in Phase 1}

---

## Phase 2: {Outcome Label}

**Goal:** {Customer outcome enabled by Phase 2, building on Phase 1.}

**In scope:**
- {capability 1}
- {capability 2}

**Key OKRs advanced:** {O2, KR2.1}

**Exit criteria:**
- {measurable criterion}

---

## Phase 3: {Outcome Label}

**Goal:** {Customer outcome enabled by Phase 3.}

**In scope:**
- {capability 1}
- {capability 2}

**Key OKRs advanced:** {O3}

**Exit criteria:**
- {measurable criterion}

---

## Risks and Sequencing Rationale

| Risk | Phase where validated | Mitigation |
|------|----------------------|------------|
| {key assumption that could invalidate the roadmap} | Phase {N} | {how it is tested before committing to Phase N+1} |
```

## Quality Checks
Before writing:
- [ ] Phase 1 is a genuine MVP — not a feature-complete product
- [ ] Every phase delivers standalone customer value
- [ ] No phase is purely internal/infrastructure
- [ ] Compliance requirements appear in Phase 1 scope, not deferred
- [ ] Each phase has explicit exit criteria
- [ ] No undefined ubiquitous language terms
