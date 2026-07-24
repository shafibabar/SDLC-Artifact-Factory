# Acceptance Sign-Off Output Format Template

Self-contained — loadable without reading `SKILL.md` first.

This is the **annotated** version. For a literal, fill-in-and-go copy with no explanatory brackets, use `assets/sign-off-template.md` directly, or run `scripts/scaffold-signoff.sh <product> <release-slice>` to generate a new sign-off doc from it with the checklist already copied in.

---

```markdown
---
name: acceptance-sign-off-[release-slice]
product: [product name]
release-slice: [name/description]
version: 1.0.0
phase: customer-validation
created: [date]
owner: requirements-analyst
---

# Acceptance Sign-Off — [release-slice]

## Sign-Off Criteria Checklist
[Checklist with source citations, including exploratory sessions run/debriefed]

## Sign-Off Authority
- Shafi (product owner)
- [Name, role, company] (customer/design-partner representative)

## Decision: [FULL SIGN-OFF / CONDITIONAL SIGN-OFF / NO-GO]

**Conditions (if conditional):**
- [Issue] — remediation plan: [...] — owner: [...] — target date: [...]

**Blocking items (if no-go):**
- [Issue] — required remediation before re-attempt: [...]

## Rollout Action
[canary-deployment widen/hold/revert instruction; feature-flag-design scope change]

## Follow-Up
[Re-verification plan and date, if conditional or no-go — including any
exploratory charter that needs re-running, not just scripted scenarios]
```
