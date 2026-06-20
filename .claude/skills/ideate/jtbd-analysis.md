# Skill: ideate/jtbd-analysis

## Purpose
Produce a Jobs To Be Done (JTBD) analysis — a structured view of the jobs customers are trying to get done when they hire this product. JTBD analysis forces the product to be defined in terms of customer outcomes, not features. It anchors the backlog to genuine human motivation and reveals underserved job steps that competitors miss.

## Inputs
Read before generating:
- `artifacts/ideate/personas/` — all personas (read all that exist)
- `artifacts/strategy/vision.md` — must exist
- `sdlc-config.json` — product_name

## Output
**File:** `artifacts/ideate/jtbd.md`
**Registers in manifest:** yes

## JTBD Framework Applied
For each persona, identify:
1. **The main job** — the core task they hire the product to accomplish
2. **Job steps** — the sequence of steps required to complete the main job
3. **Desired outcomes** — what success looks like at each job step (speed, reliability, accuracy)
4. **Current pain** — where the current solution fails at each step
5. **Job type** — Functional (what they do), Social (how they want to be perceived), Emotional (how they want to feel)
6. **Related jobs** — adjacent jobs that surface upsell or expansion opportunities

## Process
1. Read all personas and the vision.
2. For each persona, identify their main job and its steps.
3. For each job step, define desired outcomes and current pain.
4. Identify underserved job steps (high importance, low satisfaction with current solution).
5. Map underserved steps to product opportunities.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Jobs To Be Done Analysis

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** JTBD Analysis
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## {Persona 1: Role Name}

### Main Job
> When **{situation/trigger}**, I want to **{main job statement}**, so I can **{ultimate outcome}**.

**Job type:** Functional / Social / Emotional / All three

### Job Map (Steps and Desired Outcomes)

| Step | What they are trying to do | Desired outcome | Current pain / failure | Underserved? |
|------|--------------------------|-----------------|----------------------|--------------|
| 1. {e.g. Define scope} | Identify what data and systems are in compliance scope | Know this quickly and accurately, without manual audit | Requires external consultant; takes weeks | **YES** |
| 2. {e.g. Discover data} | Find all sensitive data across all storage locations | Complete, accurate picture in hours | Manual spot-checking; never complete | **YES** |
| 3. {e.g. Assess risk} | Understand which data is exposed or at risk | Ranked list by severity, instantly | Must cross-reference multiple tools and spreadsheets | **YES** |
| 4. {e.g. Remediate} | Fix the highest-risk issues | Clear action with one-click execution | Manual, undocumented, error-prone | **YES** |
| 5. {e.g. Document for audit} | Produce evidence of compliance posture | Professional, auditor-ready report, instantly | Weeks of manual compilation before each audit | **YES** |

### Social Job
> When **{situation}**, I want to **{be perceived as / demonstrate to others}**, so that **{social outcome}**.

### Emotional Job
> When **{situation}**, I want to **feel {emotional state}**, so that **{peace of mind / confidence}**.

### Related Jobs (Expansion Opportunities)
| Related job | Why it matters | Product opportunity |
|------------|----------------|---------------------|
| {e.g. Train staff on data handling} | CISO is accountable for staff awareness, not just tooling | Integrate training module or partner referral |
| {e.g. Respond to data subject requests} | GDPR requires rapid response to erasure requests | Add DSAR workflow in Phase 2 |

---

## {Persona 2: Role Name}

### Main Job
> When **{situation}**, I want to **{job}**, so I can **{outcome}**.

### Job Map

| Step | What they are trying to do | Desired outcome | Current pain | Underserved? |
|------|--------------------------|-----------------|-------------|--------------|
| {step} | {what} | {outcome} | {pain} | Yes/No |

---

## Underserved Job Steps Summary

{These are the highest-value opportunities for the product to address. Rank by: importance × current dissatisfaction.}

| Job step | Persona | Importance | Current satisfaction | Opportunity score |
|---------|---------|-----------|---------------------|-------------------|
| {step 1} | {persona} | High/Med/Low | High/Med/Low | High/Med/Low |
| {step 2} | {persona} | {importance} | {satisfaction} | {score} |

## Product Opportunity Map

| Underserved job step | Product capability that addresses it | Phase |
|---------------------|--------------------------------------|-------|
| {step} | {capability} | MVP / Phase 2 / Phase 3 |
| {step} | {capability} | {phase} |
```

## Quality Checks
Before writing:
- [ ] All three job types (functional, social, emotional) are addressed for at least the primary persona
- [ ] Each underserved job step has a specific, concrete pain description — not a generic complaint
- [ ] Product opportunity map explicitly links underserved steps to product phases
- [ ] Related jobs (expansion opportunities) are identified
- [ ] No undefined ubiquitous language terms
