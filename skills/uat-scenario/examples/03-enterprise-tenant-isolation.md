# Example 3 (enterprise): tenant isolation, flag state, a Blocked run and a stray finding

Self-contained. The hardest case this skill meets: a multi-tenant, multi-region product where a Must story's criterion is an isolation guarantee, fixtures must exist in two tenants, a flag changes the outcome, one run cannot happen, and the tester trips over an unrelated bug.

## Input

**Product:** Claimwise, multi-tenant claims handling for insurers, two regions (eu-west, eu-central). Profile: enterprise.
**Story US-31:** As a claims handler, I want search to return only my insurer's claims, so that no other insurer's customer data is ever shown to me.

**Agreed criterion AC-US-31.1:**

```gherkin
Given insurer Northfield has a claim for policyholder "Jordan Ellis"
And insurer Brightwater has a claim for policyholder "Jordan Ellis"
When a Northfield claims handler searches for "Jordan Ellis"
Then only Northfield's claim is shown
And no Brightwater claim appears in results, suggestions or the claim count
```

**Request from the product owner:** "Brightwater's eu-central tenant won't be ready until next week. Can we run this on Northfield only, and drop the suggestions check because type-ahead is cached anyway?"

## Response to the request

- **Not on one tenant.** With no Brightwater data, a leak could not show, so the scenario would prove nothing. It runs once Brightwater's fixtures exist. Until then its result is **Blocked**, with the reason.
- **Suggestions stay in.** "Results, suggestions or the claim count" is the agreed criterion. Dropping suggestions changes it, so that goes back to the product owner as a change to AC-US-31.1, not into the scenario.

## Output

```markdown
### UAT-31a: Northfield claims handler searches for a policyholder who also exists at another insurer

**Traces to:** AC-US-31.1
**Performed by:** claims handler

**Preconditions and test data** (seeded by requirements-analyst with platform-engineer, before the window):
- Tenant northfield-uat (eu-west): claim CLM-N-5521, policyholder Jordan Ellis, motor, £2,340 — confirm by: Claims list shows CLM-N-5521
- Tenant brightwater-uat (eu-central): claim CLM-B-8803, policyholder Jordan Ellis, home, €18,900 — confirm by: a Brightwater test handler sees CLM-B-8803
- Test handler h.adeyemi@northfield-uat has the Claims Handler role only

**Environment:** northfield-uat · eu-west · build 2026.12.1 (canary wave 1)
**Flags:** `search-typeahead` on for northfield-uat; `cross-region-index` on (platform default)

**Context (Given):** Signed in as the Northfield handler; CLM-N-5521 is in the Claims list.

**Steps (When):**
1. In Search, type "Jordan E" and wait for suggestions.
2. Finish typing "Jordan Ellis" and search.

**Expected Outcome (Then):**
- Suggestions show only Jordan Ellis — CLM-N-5521.
- Results show only CLM-N-5521; nothing with a CLM-B- number, "home", or a € amount.
- The result count reads "1 claim".

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| 2026-12-03 | Kemi Adeyemi (claims handler, Northfield) | Blocked: brightwater-uat fixtures not loaded in eu-central | — | — | — | — |
| 2026-12-08 | Kemi Adeyemi (claims handler, Northfield) | Pass | rec/UAT-31a-2.mp4 | — | — | FB-52 (claim PDF download times out on CLM-N-5521) |
```

`UAT-31b` repeats the work for a Brightwater handler in eu-central, and `UAT-31c` checks the claim count on the dashboard, so the criterion is covered from both sides and in both regions.

## Why it looks like this

- **Look-alike data across two tenants and two regions.** Same policyholder name, different claim numbers, line of business and currency, so any leak is unmistakable on screen.
- **Flag state recorded**, because type-ahead is behind a flag. A Pass with the flag off would not prove the suggestions line.
- **Blocked, with its reason**, until the data existed. `uat-plan`'s exit criteria count it as failing until it runs; marking it Pass to keep the schedule would hide the one scenario that proves isolation.
- **The PDF timeout is FB-52**, outside this scenario's Context. It is triaged on its own; this scenario's result is what the search showed.
- **Nothing exploratory here.** "Try other ways a Brightwater name might leak" is a charter, planned in `uat-plan` and run by a human. The scenario checks the agreed rule; the charter looks for what nobody specified.
