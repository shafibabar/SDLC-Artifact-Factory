# Analytics Requirements Output Format Template

The full fill-in template for a product's analytics requirements artifact.
Self-contained — loadable without reading `SKILL.md` first.

This is the **annotated** version — every placeholder explains what belongs there and why. For a literal, fill-in-and-go copy with no explanatory brackets, use `assets/analytics-requirements-template.md` directly, or run `scripts/scaffold-analytics-requirements.sh <product>` to generate a new requirements doc from it.

---

```markdown
---
name: analytics-requirements
product: [product name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Analytics Requirements

## Requirements Table
| Question | Decision it informs | Metric | Data source | Refresh cadence | Owner |
|---|---|---|---|---|---|

## Vanity-Metric Review
| Candidate metric | Actionable? | Comparable? | Honest denominator? | Gameable? | Survives disaggregation? | Understandable? | Verdict |
|---|---|---|---|---|---|---|---|

## OKR / Decision Traceability
| Requirement | Traces to (Key Result or named recurring decision) |
|---|---|

## Deferred / Rejected Requests
[Requests that failed the decision test or the vanity-metric check, and why]
```

The **Understandable?** column is new relative to earlier versions of this
template — it records whether a candidate metric passes `SKILL.md`'s sixth
vanity-metric check (can it be explained in one plain sentence a
non-specialist stakeholder could remember and argue about), which is
distinct from the metric already having been restated in Ubiquitous
Language during elicitation. A metric can be precise and still fail this
column if only its author can reason about it.

For any requirement whose **Metric** is retention- or stickiness-flavored,
the **Vanity-Metric Review** row's `Verdict` should note whether a cohort
comparison (segment by start date, compare like-elapsed-time behavior) was
run before the metric was accepted — see `SKILL.md`'s Vanity-Metric
Detection Checklist for why a cumulative total alone can pass every other
column while still hiding declining per-cohort retention.
