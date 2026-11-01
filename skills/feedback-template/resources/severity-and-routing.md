# Severity, Categories and Routing

The rule sets every feedback item is cross-checked against before the log is presented. The severity scale lives **only here**: `uat-scenario`, `uat-plan`, `beta-program-design` and `acceptance-sign-off` use these four words and point to this file.

## Severity — a house rule

This scale is **this plugin's own convention**. It is not an industry standard and has no grounding in the research library; its job is that a UAT failure, a check-in finding, an exploratory finding and an ad hoc report all use the same four words. Say so when a user asks where it comes from.

| Severity | Definition |
|---|---|
| **Critical** | A Must flow does not work at all, or data is lost, or there is a security or tenant-isolation exposure |
| **High** | A Must flow works incorrectly in a way that affects its core outcome |
| **Medium** | It works, but with friction, confusing wording, or a minor edge-case error |
| **Low** | Cosmetic or negligible |
| **N/A** | A positive signal, or a positioning item with no defect |

- Set once, at capture, from the impact on the reporter. Never raise it to force attention or lower it to pass an exit criterion.
- **What each severity allows at sign-off** (no-go, conditional, full) is `acceptance-sign-off`'s defect rule. It is not restated here.
- A single Critical needs no second report.

## Categories

| Category | Definition |
|---|---|
| **Bug** | The system breaks a rule the acceptance criteria or specification state |
| **UX friction** | It works as specified but is confusing, slow or needlessly effortful |
| **Missing capability** | The reporter needed something the product does not do at all |
| **Documentation gap** | The reporter could not find or understand guidance for a step |
| **Positioning** | A trial lost, a customer churned, or a choice made against a named alternative ("we went with a spreadsheet") |
| **Positive signal** | Something worked, shown by behaviour (what they did with it), not by a compliment |

## Routing — one owner per item

| Category | Routes to | Why |
|---|---|---|
| Bug in a service, API or domain logic | `backend-engineer` | Owns the services the rule lives in |
| Bug in the user interface | `frontend-engineer` | Owns the front end where it shows |
| Bug in a data pipeline, analytics or data quality | `data-engineer` | Owns pipelines and data-quality rules |
| Bug in deployment, performance, availability or an environment | `platform-engineer` | Owns the running platform |
| Security or tenant-isolation exposure | `security-engineer` | Owns security controls; always Critical |
| UX friction | `ux-architect` | Owns interaction and flow design |
| Missing capability | **requirements-analyst** | A requirement for a later release (`moscow-prioritization`) and an opportunity on `opportunity-solution-tree`; never a silent Must for the current release |
| Missing capability that challenges the positioning or the ICP | requirements-analyst, **escalated to** `product-strategist` | Only then is it a strategy question |
| Positioning | `competitive-analysis` win/loss log **and** flagged to `gtm-strategy` as a possible Positioning Refresh Trigger (product-strategist decides) | Real market contact tests the positioning; never skipped as a one-off preference |
| Documentation gap | requirements-analyst | Owns the customer-facing guidance validated in this phase |
| Any finding that recurs from an earlier release | Its owner above, **and** `risk-register` | A standing exposure, not a one-off to close |
| Positive signal | Logged, no route | Evidence for `acceptance-sign-off` and for the tree |

Where the broken part is unclear, route to the engineer who owns the layer where the symptom appears and say so in the item; that engineer re-routes with a reason. Never route to "engineering" or "the team".

## Checklist before presenting the log

- [ ] One item per finding, each with every field of `../templates/feedback-item.md`
- [ ] Reporter by role and organisation or tenant; no product-specific persona list
- [ ] Context is a specific past event, in the reporter's words
- [ ] No compliment logged as a positive signal; no fluff logged as fact
- [ ] Every idea converted to an underlying need, in the customer's voice
- [ ] Items merged only where the cause is the same; the same symptom with different causes kept apart
- [ ] Severity from the scale above, set at capture, unchanged since
- [ ] Every item has exactly one owner from the routing table, with the specific engineer for a bug
- [ ] Positioning items in the win/loss log and flagged to `gtm-strategy` as a possible Positioning Refresh Trigger
- [ ] Both rollups present: by symptom and cause, and by customer need
- [ ] Patterns need independent reporters with the same cause; each confirmed pattern is named in words for the sign-off
- [ ] Exploratory debrief questions sent back to `uat-plan` as new charters, not logged as items
- [ ] A finding that recurs from an earlier release is also in `risk-register`
