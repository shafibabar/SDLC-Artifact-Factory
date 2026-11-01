# Sign-Off Checklist

Self-contained. Cross-check a drafted sign-off against every line before presenting it to the user. The first block is the evidence the decision is made against; it is copied, unchecked, into every new record by `../scripts/scaffold-signoff.sh`. The second block checks the record itself. `../scripts/validate-signoff.sh` checks the mechanical subset; the rest is judgment, read by hand.

## Evidence (copied into the record)

| # | Item | Evidence comes from | If unchecked |
|---|---|---|---|
| E1 | Every UAT scenario for a Must story has a result, and none is Blocked or Not run | `uat-plan` completion summary; `uat-scenario` results | Run it, or record why not; a Blocked scenario is never a Pass |
| E2 | The pass threshold agreed before execution is met | `uat-plan` exit criteria | A threshold changed after the results is a recorded decision, with who agreed and why |
| E3 | Every planned exploratory session ran and was debriefed; its findings triaged | `uat-plan` charters; session records | Run it, or record it as residual risk |
| E4 | Every acceptance type in scope (OAT, contractual, regulatory) has a result, accepted by its signatory | `uat-plan` acceptance types; `compliance-verification`; `platform-engineer` evidence | That type's scope is held back |
| E5 | Zero open Critical defects | `feedback-template` log | **No-go.** Nothing else |
| E6 | Every open High has a fix plan: owner, target date, workaround, re-test, rollout pace | `feedback-template` log | No fix plan → no-go; with one → conditional at best |
| E7 | All feedback items triaged, scripted and exploratory alike | `feedback-template` log | Triage before deciding |
| E8 | No unaddressed blocking pattern on a Must flow | `feedback-template` pattern aggregation | Treat as High (§ 2 of the skill) |
| E9 | Repeatability: every executor or cohort was set up the same documented way (only when more than one) | `uat-plan` repeatability note; beta onboarding notes | Record as residual risk; it weakens, it does not decide |
| E10 | Beta stage graduation records exist for each stage passed (only when beta is in scope) | `beta-program-design` | Hold the rollout at the last graduated stage |
| E11 | Residual risk evaluated and written down: what is accepted, by whom | `uat-plan` completion summary | Write it before deciding |

## The record itself

- [ ] Frontmatter has `name`, `version`, `phase`, `owner`, `created`, `summary`; `summary` states the release and the outcome.
- [ ] Each evidence line cites where it came from, by artifact path or ID.
- [ ] Both signatories named with role and organisation, each with date and how they agreed, **or** a filled `## Exception: solo operator` block with independence level "none".
- [ ] Every other acceptance type's signatory named (compliance, contract, OAT).
- [ ] At enterprise, each tenant cohort shows whose acceptance it rests on; a refused cohort is held back and its re-attempt is an addendum.
- [ ] Exactly one decision: `FULL SIGN-OFF`, `CONDITIONAL SIGN-OFF` or `NO-GO`, and it matches the defect rule (no open Critical under a sign-off; every open High under a conditional has its full fix plan).
- [ ] Every condition: issue ID, severity, workaround, owner, target date, re-test.
- [ ] Every no-go blocking item says what must change; re-attempt is a new UAT pass.
- [ ] Residual risk lists every Medium or Low accepted, and any repeatability or independence weakness.
- [ ] Rollout action names the canary step and the flag scope, per cohort where they differ, and the path to GA.
- [ ] Follow-up names each re-test (scenario or charter), its date and who re-runs it.
- [ ] No signature recorded by the agent on a person's behalf; conditional dates approved by the user.
- [ ] Only canonical glossary terms; no persona or product rule presented as a general rule.
