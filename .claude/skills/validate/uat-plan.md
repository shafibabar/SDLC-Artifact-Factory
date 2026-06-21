# Skill: validate/uat-plan

## Purpose
Produce the User Acceptance Testing Plan — the formal specification of how real users will validate that the product meets their needs in the UAT environment. UAT is not internal testing; it is facilitated testing with the personas the product was built for.

## Inputs
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/ideate/backlog/stories/` (user stories — UAT validates their acceptance criteria)
- `artifacts/quality/e2e/` (E2E scenarios — UAT builds on these)
- `sdlc-config.json` (product_name)

## Output
**File:** `artifacts/validate/uat-plan.md`
**Registers in manifest:** yes

## UAT Rules (enforced)
- UAT participants are real users — not developers, QA engineers, or the PM.
- Every persona has at least one UAT participant.
- UAT is facilitated — a facilitator guides the session but does not tell participants what to click.
- UAT uncovers usability failures, not just functional failures.
- All UAT sessions are recorded or have a note-taker observing.

## Artifact Template

```markdown
# User Acceptance Testing Plan
**Product:** {product_name}
**Phase:** Validate
**Artifact:** UAT Plan
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## UAT Scope

**What UAT will test:**
- User journeys mapped in story-map.md and UX flows
- Acceptance criteria from all READY and DONE user stories
- Usability: can participants complete tasks without instruction beyond the UI?

**What UAT will NOT test:**
- Performance under load (covered by Quality phase)
- Infrastructure resilience (covered by chaos tests)
- Compliance control implementation (covered by compliance tests)

---

## Participants

| Participant | Role / Persona | Organisation | Session date | Recruited by |
|------------|---------------|-------------|-------------|-------------|
| {Name} | Compliance Officer | {Org} | {Date} | PM |
| {Name} | Tenant Administrator | {Org} | {Date} | PM |
| {Name} | External Auditor (read-only) | {Org} | {Date} | PM |

**Minimum:** 1 participant per persona. **Target:** 3 per persona (diminishing returns beyond 5).

---

## UAT Environment

| Attribute | Value |
|-----------|-------|
| Environment URL | https://{product-codename}-uat.{domain} |
| Data | Synthetic — realistic volume and shape; no real customer data |
| Accounts | Pre-provisioned per participant; access removed after UAT |
| Worker Node | Configured to scan a UAT-specific Google Drive test folder |
| Session recording | Loom or Zoom recording; participants consent required |

---

## Session Format (per participant)

| Phase | Duration | Activity |
|-------|---------|---------|
| Introduction | 10 min | Explain UAT purpose; confirm recording consent; set context |
| Warm-up | 5 min | Log in; orient to the product |
| Scenario 1 | 15 min | {Scenario name} — think aloud protocol |
| Scenario 2 | 15 min | {Scenario name} — think aloud protocol |
| Scenario 3 | 15 min | {Scenario name} (if time permits) |
| Debrief | 15 min | Open questions; overall impressions; Net Promoter Score |

**Think Aloud Protocol:** Participants narrate their thoughts as they work. Facilitator does NOT answer "where do I click?" — they observe and note hesitations.

---

## Entry and Exit Criteria

### Entry criteria (UAT can begin)
- [ ] UAT environment is live and stable
- [ ] Pre-UAT hook has passed
- [ ] All participants have been briefed and have signed consent
- [ ] Facilitator has been trained on think-aloud facilitation

### Exit criteria (UAT is complete)
- [ ] All participants have completed all scenarios
- [ ] All critical (blocking) issues have been resolved or formally deferred
- [ ] Acceptance checklist (validate/acceptance-checklist.md) has been completed
- [ ] UAT report has been produced

---

## UAT Defect Classification

| Severity | Definition | Resolution requirement |
|---------|-----------|----------------------|
| **Blocker** | Participant cannot complete the scenario at all | Must fix before release |
| **Major** | Participant completes the scenario but with significant confusion | Fix before release (unless deferred with PM decision) |
| **Minor** | Cosmetic, wording, or low-impact usability issue | Fix in next iteration |
| **Enhancement** | Nice-to-have; not in original scope | Backlog for future sprint |
```

## Quality Checks
- [ ] Participants are real users (not developers or QA)
- [ ] Every persona has at least one named participant
- [ ] UAT environment URL is specified
- [ ] Think-aloud protocol is defined
- [ ] Entry and exit criteria are checkboxes
- [ ] Defect classification table is present with resolution requirements
