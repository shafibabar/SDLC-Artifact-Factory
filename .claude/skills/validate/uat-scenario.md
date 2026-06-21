# Skill: validate/uat-scenario

## Purpose
Produce a UAT Scenario for one user journey — the guided task that a UAT participant attempts during their session. Scenarios are written from the user's perspective (not "navigate to X" but "find out Y"). They test JTBD, not menu navigation.

## Inputs
- `artifacts/validate/uat-plan.md`
- `artifacts/ideate/jtbd.md`
- `artifacts/ideate/backlog/stories/` (user stories with acceptance criteria)
- `artifacts/design/ux/flows/`
- **Argument required:** scenario ID (e.g. `S-01`, `S-02`)

## Output
**File:** `artifacts/validate/scenarios/{id}.md`
**Registers in manifest:** yes

## UAT Scenario Rules (enforced)
- Scenarios start with a JTBD context ("You are a Compliance Officer. You've just been told...") — not "Click on Compliance."
- Tasks are defined as goals, not steps ("Find all files containing GDPR violations" not "Go to Dashboard > Compliance > Findings").
- Success criteria are observable (the facilitator can confirm pass/fail without subjective judgement).
- Facilitator notes are separate from participant instructions.

## Artifact Template

```markdown
# UAT Scenario: {id}

**Product:** {product_name}
**Phase:** Validate
**Artifact:** UAT Scenario
**Scenario ID:** {id}
**Persona:** {persona name}
**JTBD:** {job to be done this scenario tests}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Participant Instructions

*Read aloud to participant — do not show them the facilitator notes*

---

### Context

You are a Compliance Officer at Acme Corp. Your organisation uses {product_name} to monitor your data estate for compliance issues.

Your manager has just asked you to prepare for next week's GDPR audit. You need to understand your current compliance posture and identify the most urgent issues to resolve before the auditor arrives.

---

### Tasks

**Task 1:** Find out what your current GDPR compliance score is.

*[Wait for participant to attempt. Note: do not tell them where to look.]*

**Task 2:** Identify which compliance violations are most urgent (critical severity, open longest).

**Task 3:** Export a summary of your compliance posture that you could share with your manager.

---

### Debrief Questions (after tasks)

1. How confident do you feel in the score you found? Why?
2. Was anything confusing or unclear?
3. How does this compare to how you currently handle this task?
4. On a scale of 1–10, how likely are you to use this feature regularly?

---

## Facilitator Notes

*Not shown to participant*

### Preparation
- Pre-populate the UAT environment with: 1 connected Google Drive, 50 files (of which 10 have GDPR violations), compliance posture score = 74%
- Verify `/api/v1/compliance/posture` returns data before session starts

### Success Criteria (observable)
| Task | Pass | Fail | Observation notes |
|------|------|------|------------------|
| Task 1 | Participant locates posture score (74%) without help within 3 minutes | Participant cannot find score after 3 minutes or finds wrong number | |
| Task 2 | Participant identifies CRITICAL severity findings | Participant cannot filter or sort by severity | |
| Task 3 | Participant downloads or shares report in any format | Participant cannot find export functionality | |

### Probes (use only if participant is stuck for > 2 minutes)
- "What would you expect to find if you were looking for compliance information?"
- "Is there anywhere you haven't looked yet?"
- Do NOT say: "Try clicking on Compliance" or "Look at the dashboard"

### Usability Observations to Watch For
- Does participant scroll past the key metric?
- Does participant look for a "back" button where there isn't one?
- Do they attempt to export and not find the format they expect?
- Any moment of confusion, re-reading, or hesitation → note the trigger
```

## Quality Checks
- [ ] Participant instructions use JTBD context (not "click X")
- [ ] Tasks are stated as goals, not steps
- [ ] Success criteria are observable (facilitator can confirm pass/fail)
- [ ] Facilitator notes are clearly separated from participant instructions
- [ ] UAT environment pre-conditions are specified
- [ ] Probes are listed for when participants are stuck (but don't give answers)
