# Skill: strategy/okr-set

## Purpose
Generate a set of OKRs (Objectives and Key Results) for a defined planning horizon. OKRs are the bridge between the vision and the roadmap — they define direction (Objectives) and how progress is measured (Key Results).

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `artifacts/strategy/north-star.md` — must exist
- `sdlc-config.json` — product_name, constraints
- Ask the user: "What planning horizon are these OKRs for? (e.g. Q1 2027, H1 2027, Year 1)"

## Output
**File:** `artifacts/strategy/okrs.md`
**Registers in manifest:** yes

## OKR Rules (enforced)
- Each Objective is qualitative, inspiring, and time-bound. It answers "where do we want to go?"
- Each Key Result is quantitative, measurable, and binary (achieved or not by the end of the period). It answers "how do we know we're there?"
- Key Results measure outcomes, not activities. "Launch feature X" is an activity. "Increase metric Y by Z%" is a Key Result.
- 3–5 Objectives per horizon. 2–4 Key Results per Objective.
- Key Results are stretch targets: 70% achievement is considered success.

## Process
1. Read vision and North Star Metric.
2. Identify the top 3–5 strategic themes for the horizon (ask user if unclear).
3. For each theme, write one Objective.
4. For each Objective, derive 2–4 Key Results that are measurable, outcome-oriented, and tied to the North Star Metric or its input metrics.
5. Check every Key Result: is it an outcome or an activity? Rewrite activities as outcomes.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# OKR Set — {Planning Horizon}

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** OKR Set
**Horizon:** {e.g. Q1 2027 | H1 2027 | Year 1}
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## North Star Metric Alignment
> This OKR set is anchored to: **{North Star Metric}**
> Target for this horizon: **{NSM target for this period}**

---

## O1: {Objective 1 — qualitative, inspiring, time-bound}
*Theme: {strategic theme this objective addresses}*

| # | Key Result | Baseline | Target | Measurement |
|---|-----------|---------|--------|-------------|
| KR1.1 | {measurable outcome} | {current value} | {target value} | {how measured} |
| KR1.2 | {measurable outcome} | {current value} | {target value} | {how measured} |
| KR1.3 | {measurable outcome} | {current value} | {target value} | {how measured} |

---

## O2: {Objective 2}
*Theme: {strategic theme}*

| # | Key Result | Baseline | Target | Measurement |
|---|-----------|---------|--------|-------------|
| KR2.1 | {measurable outcome} | {current value} | {target value} | {how measured} |
| KR2.2 | {measurable outcome} | {current value} | {target value} | {how measured} |

---

## O3: {Objective 3}
*Theme: {strategic theme}*

| # | Key Result | Baseline | Target | Measurement |
|---|-----------|---------|--------|-------------|
| KR3.1 | {measurable outcome} | {current value} | {target value} | {how measured} |
| KR3.2 | {measurable outcome} | {current value} | {target value} | {how measured} |

---

## OKR Health Checks
| Check | Status |
|-------|--------|
| All Key Results are outcomes, not activities | ✓ / ✗ |
| All Key Results are measurable with a specific number | ✓ / ✗ |
| No Objective is achievable at 100% without significant effort | ✓ / ✗ |
| OKRs tie to North Star Metric or its input metrics | ✓ / ✗ |
| No more than 5 Objectives | ✓ / ✗ |
```

## Quality Checks
Before writing:
- [ ] Every Key Result has a numeric target (no subjective KRs)
- [ ] No Key Result is an activity ("ship X") rather than an outcome ("achieve Y")
- [ ] All Objectives are inspiring and directional, not task lists
- [ ] At least one KR per Objective ties directly to the North Star Metric
- [ ] No undefined ubiquitous language terms
