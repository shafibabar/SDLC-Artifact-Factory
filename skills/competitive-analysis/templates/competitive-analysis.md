# Competitive Analysis — Artifact Template

Self-contained. Copy everything below the line into `artifacts/<product>/strategy/competitive-analysis.md` and replace every `[bracketed]` value. Sections marked *(standard+)* are deleted at lean; sections marked *(enterprise)* are deleted below enterprise. Keep the section order: alternatives and criteria come before any scoring.

---

```markdown
---
name: competitive-analysis
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the strongest alternative and the advantage that survives, e.g. "Most firms stay on spreadsheets; our same-day history import is the one real, valued, defensible difference."]
owner: product-strategist
profile: [lean | standard | enterprise]
traces_to: [strategy/vision-statement.md; strategy/stakeholder-map.md]
---

# Competitive Analysis

## 1. Competitive Alternatives

What the customer would do if this product did not exist. Doing nothing first.

| # | Alternative | Type | What the customer does today | Evidence |
|---|---|---|---|---|
| A1 | Doing nothing | Non-consumption | [how they live with the problem; what eventually forces action] | [source or hypothesis] |
| A2 | No decision (B2B) | Status quo | [which buying-group role defends the status quo, and why] | [source or hypothesis] |
| A3 | [spreadsheet / consultant / in-house script] | Substitute | [...] | [...] |
| A4 | [vendor] | Direct / Indirect / Future entrant | [...] | [...] |

## 2. Buyer's Evaluation Criteria

Written before any scoring, in the buyer's words.

| # | Criterion | Whose (role) | Weight | Where it came from | Table stakes? |
|---|---|---|---|---|---|
| C1 | [criterion] | [buyer / user / approver] | [high / medium / low] | [interviews / lost deals / category / hypothesis] | [yes / no] |

### Category lens *(enterprise, or when the category is open)*

| Candidate category | Criteria it brings | Compared with | Where we stand |
|---|---|---|---|
| [category] | [...] | [...] | [...] |

## 3. Evidence Register

| ID | Claim | Source | Date | Status |
|---|---|---|---|---|
| E1 | [one checkable claim about an alternative] | [user's demo notes / pricing page / model knowledge] | [as-of date] | [verified / user-reported / unverified (model knowledge)] |

**Evidence requested from the user:** [the specific documents or notes that would verify the claims the differentiation points depend on]

## 4. Capability Matrix

Ratings: ✓ strong · ~ partial · ✗ absent · ? unknown. Every cell about an alternative cites an evidence ID.

| Criterion (weight) | [Our product] | A1 Doing nothing | A3 [substitute] | A4 [vendor] |
|---|---|---|---|---|
| C1 [criterion] (high) | [rating] | [rating] [E#] | [rating] [E#] | [rating] [E#] |

## 5. Positioning Map *(standard+)*

**Axes:** [C# — heaviest buyer criterion] (x) × [C# — second heaviest] (y).

[2×2 sketch with every alternative and the product plotted]

**Who shares our space:** [honest statement; if we are not alone, say what that means for the kernel]

## 6. Competitive SWOT *(standard+)*

| Strengths | Weaknesses |
|---|---|
| [on criteria the buyer weights] | [on criteria the buyer weights] |
| **Opportunities** | **Threats** |
| [needs no alternative serves] | [who is moving toward our position; future entrants and bundling] |

## 7. Differentiation Points

| # | Point | Real (evidence) | Valued (criterion) | Defensible (why it can't be copied or bought within the horizon) | Evidence status |
|---|---|---|---|---|---|
| D1 | [...] | [E#] | [C#] | [...] | [verified / hypothesis] |

**Considered and cut:** [points that failed a filter, and which filter]

## 8. Competitive Risks *(standard+)*

| Risk | From | Probability | Impact | Mitigation |
|---|---|---|---|---|
| [...] | [alternative] | [L/M/H] | [L/M/H] | [...] |

## 9. Win/Loss Log *(standard+; lean only if users can choose an alternative)*

| Date | Account / trial | Weighed against | Outcome | Stated reason (source) | Differentiation point |
|---|---|---|---|---|---|
| [YYYY-MM-DD] | [...] | [A#] | [won / lost / no decision] | [...] | [D# confirmed / contradicted / not touched] |

[Or: "No entries yet; starts with [the closed beta / the first design partner]."]
A contradicted point fires `gtm-strategy`'s Positioning Refresh Trigger; a pattern of them goes to the strategy kernel's review trigger.

## 10. Hand-off to the Strategy Kernel

- **Advantage candidates:** [D# — evidence status]
- **The alternative to beat:** [usually A1 or A2, and why]
- **The advantage is not real if:** [the evidence that would show it, and where it will appear — the win/loss log, trial data]
- **Table stakes for requirements:** [C# list]
```
