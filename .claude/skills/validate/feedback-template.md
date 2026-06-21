# Skill: validate/feedback-template

## Purpose
Produce the Feedback Capture Template — the standardised form used to collect structured feedback from UAT participants, beta users, and customers. Feedback is useless without structure; structure enables pattern identification. This template ensures every feedback session produces comparable, actionable data.

## Inputs
- `artifacts/validate/uat-plan.md`
- `artifacts/ideate/personas/`
- `artifacts/strategy/north-star.md` (NSM — key questions probe the NSM hypothesis)
- `artifacts/ideate/jtbd.md` (JTBD — feedback probes whether the job was done)

## Output
**File:** `artifacts/validate/feedback-template.md`
**Registers in manifest:** yes

## Feedback Template Rules (enforced)
- Template includes closed-ended (quantitative) and open-ended (qualitative) questions.
- Net Promoter Score is always included (NPS = one standard metric).
- Questions probe JTBD success — not just feature satisfaction.
- Template is usable in three contexts: UAT session, beta check-in, customer interview.
- No leading questions — questions are neutral and do not suggest a preferred answer.

## Artifact Template

```markdown
# Feedback Capture Template
**Product:** {product_name}
**Phase:** Validate
**Artifact:** Feedback Capture Template
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Session Information

| Field | Value |
|-------|-------|
| Participant name | |
| Participant role | |
| Organisation | |
| Session date | |
| Session type | UAT / Beta check-in / Customer interview |
| Facilitator | |
| Observer / note-taker | |

---

## Part 1: Job to Be Done (5 minutes)

*Purpose: understand whether the participant's primary job is being done.*

**Q1.** Before using {product_name}, how did you know what personal data was in your organisation's storage locations? (open-ended)

**Q2.** How much time per week do you spend on compliance-related data tasks today? (estimate)
- [ ] < 1 hour
- [ ] 1–4 hours  
- [ ] 4–8 hours
- [ ] > 8 hours

**Q3.** When you think about your GDPR (or SOC 2) obligations, what keeps you up at night? (open-ended)

---

## Part 2: Task Satisfaction (10 minutes)

*Complete after UAT scenario tasks or after 4+ weeks of beta usage.*

For each task / scenario, rate 1 (very difficult) to 5 (very easy):

| Task | Ease of use (1–5) | Did you succeed? | Comments |
|------|------------------|-----------------|---------|
| Registering a storage location | | Yes / No / Partially | |
| Initiating a scan | | Yes / No / Partially | |
| Finding your compliance posture score | | Yes / No / Partially | |
| Identifying the most critical findings | | Yes / No / Partially | |
| Exporting a compliance report | | Yes / No / Partially | |

---

## Part 3: Value and Outcome (5 minutes)

**Q4.** Has using {product_name} changed how confident you are about your compliance posture? (1 = no change, 5 = significantly more confident)

**Q5.** If {product_name} disappeared tomorrow, how would you feel?
- [ ] Very disappointed
- [ ] Somewhat disappointed
- [ ] Not disappointed (I'd find another way)
- [ ] Relieved

*(Sean Ellis / Product-Market Fit question — target: ≥ 40% "very disappointed")*

**Q6.** What is the single most important thing {product_name} should do that it doesn't do yet? (open-ended)

**Q7.** What, if anything, did {product_name} do that surprised you (positively or negatively)? (open-ended)

---

## Part 4: Net Promoter Score (2 minutes)

**Q8.** On a scale of 0 to 10, how likely are you to recommend {product_name} to a colleague at another organisation who has similar compliance obligations?

`0 (Not at all likely) ─────────────────── 10 (Extremely likely)`

**Q9.** What is the main reason for your score? (open-ended)

*NPS scoring: 9–10 = Promoter; 7–8 = Passive; 0–6 = Detractor*
*Target NPS ≥ 30 for beta; ≥ 50 for GA readiness*

---

## Part 5: Verbatim Capture

During the session, note verbatim quotes that could serve as:
- Customer testimonials (positive)
- Problem validation ("I've always struggled with...")
- Unmet needs ("I wish it would...")

| Quote | Context | Type |
|-------|---------|------|
| | | Testimonial / Problem / Unmet need |

---

## Analysis Notes (facilitator use)

*Complete after the session:*

**Top 3 observations:**
1.
2.
3.

**Surprising moments:**

**Usability issues observed (participant didn't notice / verbalise):**

**Actionable items for the product backlog:**
```

## Quality Checks
- [ ] NPS question is present (Q8/Q9)
- [ ] Sean Ellis PMF question is present (Q5 — "very disappointed")
- [ ] JTBD questions probe the job, not the feature
- [ ] Questions are not leading (no "how much did you love X?")
- [ ] Verbatim capture section is present
- [ ] Facilitator analysis notes section is separate from participant responses
