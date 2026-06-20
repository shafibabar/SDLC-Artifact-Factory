# Skill: ideate/moscow-prioritization

## Purpose
Apply MoSCoW prioritisation to all epics and produce a prioritised backlog view. MoSCoW (Must Have, Should Have, Could Have, Won't Have) makes trade-off decisions explicit and shared — preventing silent scope creep and ensuring the MVP is genuinely minimal.

## Inputs
Read before generating:
- `artifacts/ideate/backlog/epics/` — all epic files
- `artifacts/strategy/roadmap.md` — for phase alignment
- `artifacts/strategy/okrs.md` — for OKR alignment
- `sdlc-config.json` — product_name, constraints

## Output
**File:** `artifacts/ideate/moscow.md`
**Registers in manifest:** yes

## MoSCoW Definitions (enforced)
- **Must Have:** Non-negotiable for this release. Without it, the release has no value or is not viable (compliance, legal, safety, or core value). If any Must Have is not delivered, the release fails.
- **Should Have:** Important and expected, but the release is viable without it. Will cause significant pain if absent but there is a workaround.
- **Could Have:** Nice to have. Included if time/budget allows, dropped first if not.
- **Won't Have (this time):** Explicitly agreed to be out of scope for this release. Not a rejection — it's a deferral with documentation. Prevents scope creep by naming what is NOT being built.

## Prioritisation Rules
- No more than 60% of effort in Must Have. If everything is Must Have, the exercise has failed.
- Every Must Have must be traceable to: a compliance requirement, a core user journey step, or a non-negotiable business constraint.
- Won't Have items must be documented with the reason for deferral — not just omitted.

## Process
1. Read all epics, roadmap, and OKRs.
2. For each epic, determine its MoSCoW tier and justify it.
3. Verify the Must Have count is ≤ 60% of total epics.
4. Document Won't Have items with deferral reasons.
5. Produce a prioritised backlog table.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# MoSCoW Prioritisation

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** MoSCoW Prioritisation
**Scope:** {release / MVP / Phase 1}
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Summary

| Tier | Epic count | % of total | Delivery commitment |
|------|-----------|-----------|---------------------|
| Must Have | {n} | {%} | Committed — release fails without these |
| Should Have | {n} | {%} | Planned — dropped only if Must Haves are threatened |
| Could Have | {n} | {%} | Aspirational — included if capacity allows |
| Won't Have | {n} | {%} | Deferred — explicitly excluded from this release |

**Must Have % check:** {n}% — {PASS (≤60%) / FAIL (>60% — review required)}

---

## Must Have — Release is not viable without these

| Epic ID | Epic Title | Justification | OKR linkage |
|---------|-----------|---------------|-------------|
| EP-01 | {title} | {why it is non-negotiable: compliance requirement / core value loop / legal obligation} | {KR ref} |
| EP-02 | {title} | {justification} | {KR ref} |

---

## Should Have — Important but release is viable without them

| Epic ID | Epic Title | Justification | If dropped: impact | OKR linkage |
|---------|-----------|---------------|--------------------|-------------|
| EP-03 | {title} | {why it is important} | {user pain if absent} | {KR ref} |
| EP-04 | {title} | {justification} | {impact if absent} | {KR ref} |

---

## Could Have — Nice to have

| Epic ID | Epic Title | Justification | If included: benefit |
|---------|-----------|---------------|----------------------|
| EP-05 | {title} | {why it adds value} | {benefit if included} |

---

## Won't Have (This Release) — Explicitly deferred

| Item | Reason for deferral | Target phase |
|------|---------------------|-------------|
| {feature or epic} | {explicit reason: out of MVP scope / dependency not ready / deliberate future phase / customer validation needed first} | Phase 2 / Phase 3 / TBD |
| {item} | {reason} | {target phase} |

---

## Prioritisation Decisions Log
{Record significant trade-off decisions made during this prioritisation. Future team members and contractors should be able to understand why these decisions were made.}

| Decision | Rationale | Date | Made by |
|----------|-----------|------|---------|
| {e.g. Natural language querying deferred to Phase 2} | {Requires local LLM infrastructure; adds significant deployment complexity for MVP. Core compliance value does not depend on it.} | {date} | {decision maker} |
```

## Quality Checks
Before writing:
- [ ] Must Have % is ≤ 60% — if over, challenge each Must Have
- [ ] Every Must Have has a specific justification (compliance / core value / legal) — not just "important"
- [ ] Won't Have items are explicitly listed with deferral reasons — not simply omitted
- [ ] All epics from `backlog/epics/` are accounted for in one of the four tiers
- [ ] No undefined ubiquitous language terms
