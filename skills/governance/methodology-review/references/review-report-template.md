# Methodology Review Report Template

Standard output format for a methodology review, whether produced by the `methodology-compliance-check` hook, an agent self-review, or Shafi's manual review. Copy the template, replace the placeholders, delete the guidance comments.

---

```markdown
---
name: methodology-review-<artifact-name>
version: 1.0.0
phase: <phase of the reviewed artifact>
owner: <reviewing agent, hook, or "shafi">
created: <YYYY-MM-DD>
reviewed_artifact: <path or name of the artifact reviewed>
result: pass | fail
---

# Methodology Review — <Artifact Name>

## Summary

| Field | Value |
|---|---|
| Artifact | <name and path> |
| Producing agent | <agent role> |
| Phase | <phase> |
| Methodologies applicable | <subset of: DDD, Event Storming, TDD, BDD, SOLID> |
| Methodologies not applicable | <subset, with one-line reason each> |
| Result | PASS / FAIL |
| Defects | <count> |
| Warnings | <count> |

## Defects

<!-- One row per defect. A defect blocks the phase gate. If zero defects, state "None." -->

| # | Methodology | Violated check | Evidence (file/section/line) | Remediation required |
|---|---|---|---|---|
| 1 | <e.g. DDD> | <check name from the methodology-review skill tables> | <where the violation appears> | <what the producing agent must change> |

## Warnings

<!-- One row per warning. Warnings are recorded but do not block the gate. If zero, state "None." -->

| # | Methodology | Consideration | Evidence | Suggested improvement |
|---|---|---|---|---|
| 1 | <methodology> | <what was noticed> | <where> | <optional improvement> |

## Ubiquitous Language Check

| Term found in artifact | Canonical? | Canonical form (if drifted) |
|---|---|---|
| <term> | yes / no | <correct form or "-"> |

## Verdict

<One or two sentences: pass and why, or fail and the single most important remediation. On fail, name the agent responsible for remediation and state that the artifact must be re-submitted for review after correction.>
```

---

## Completion rules

- `result: fail` whenever `Defects ≥ 1`; `pass` only at zero defects.
- Every defect row must cite a specific check from the methodology tables in `SKILL.md` — never a free-form objection.
- Warnings recorded here are also appended to the reviewed artifact's frontmatter by the producing agent.
- On fail, the report is handed to the producing agent; the phase gate (`pre-phase-advance` hook) will not pass until a follow-up review of the same artifact records `result: pass`.
