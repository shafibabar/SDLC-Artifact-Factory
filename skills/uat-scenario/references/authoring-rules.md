# UAT Scenario Authoring Rules

Self-contained. Read this while drafting scenarios, for the detailed mechanics behind each field of the template. Sources: Hambling, *User Acceptance Testing* (business scenarios, test basis, results wider than pass/fail, evidence, re-test, workaround); Pugh, *Lean-Agile ATDD* (the agreed test is a contract; declarative style; isolate one rule); Adzic, *Specification by Example* (business-language Given/When/Then; key examples); Crispin and Gregory, *Agile Testing* (checking vs testing); Hendrickson, *Explore It!* (exploration is a separate, human activity).

---

## 1. Translating Given/When/Then

| Criterion part | Scenario field | Rule |
|---|---|---|
| `Given` | **Context** and **Preconditions** | A starting state the tester can confirm on screen. Replace anything internal with its visible proxy: "the payment was processed" becomes "the order shows status Paid". |
| `When` | **Steps** | The literal actions a user takes, numbered, one per step, in the user's words. |
| `Then` | **Expected Outcome** | What the tester sees: a label, a message, a row, a downloaded file, an email. One line per `Then` / `And`. |
| `And` / `But` | extra Steps or Outcome lines | Same meaning as the source. Nothing added, nothing dropped. |

**When the translation does not go through cleanly:**

- **The criterion names an internal value** (`Then sensitivity_level = 'restricted'`, `Then a ReportExported event is published`). Find what the user sees because of it (the Restricted label; the file in Downloads). If nothing is visible, the criterion has a gap: write the scenario up to that point, add a note "AC-US-<n> has no observable outcome for <x>; raised with the product owner", and do not invent one.
- **The criterion is silent on a case the scenario needs** (what happens at exactly the cut-off time?). Do not decide it in the scenario. Raise it with the product owner as a change to the acceptance criterion.
- **Someone asks to loosen the check** ("only check the export downloads, not the totals"). The agreed criterion is a contract (Pugh). A change goes back through the same agreement that made it, and the scenario stays as agreed until then.

## 2. Plain-language steps

- Use the words on the screen and the words the user uses. "Mark the invoice as disputed", not "set `status=DISPUTED`".
- One action per step. "Open the order and change the quantity to 3" is two steps.
- No HTTP verbs, endpoints, field names, SQL, log lines or console commands.
- Say *what* the user does, not how the page is built: "choose Friday's menu", not "click the third tab in the header".
- Name the role the story was written for ("the office manager"), not a persona's first name and not "the user".
- No technical wording anywhere in the scenario, not even as a note mapping a line back to the criterion (`← AC: bookings.status = 'confirmed'`). The `Traces to:` line is the link; a reviewer who wants the original wording opens the criterion.

## 3. Business scenarios, not screens

Build each scenario around a realistic piece of work the role does: closing the day's orders, preparing a month-end export, reviewing a new joiner's access. A piece of work may cross several screens and use several criteria of one story. Then check coverage in the other direction: every acceptance criterion of every Must story is reached by at least one scenario. Both directions together give realism and coverage (Hambling).

Do not reuse system-test or automated-test scripts as UAT scenarios. They were built from the technical specification, and re-running them by hand adds nothing (Hambling).

## 4. IDs

- `UAT-<story number><letter>`: `AC-US-5` → `UAT-5a`, `UAT-5b`, `UAT-5c`.
- The letter is always there, so a second scenario never renames the first.
- `Traces to:` lists every criterion the scenario covers (`AC-US-5.1, AC-US-5.2`).
- Re-runs keep the ID and add a run line; they never get a new ID.

## 5. Preconditions, fixtures and environment

- **Name every fixture.** Record, file, account, amount, date: "customer Harbour Foods, invoice INV-2041 for €1,200, due 2026-03-03, status Open".
- **Say how the tester confirms it** before starting: "INV-2041 appears in Invoices with status Open".
- **Seed before the window** and list who seeded it. A fixture created during the scenario is part of the steps, not a precondition.
- **Multi-tenant:** name the tenant on every fixture. An isolation scenario seeds look-alike data in two tenants (same customer name, different amounts) and signs in as a user of one, so leaked data would be visible and recognisable.
- **Environment:** tenant, region, build or release tag. On the canary, the release tag proves which build was tested.
- **Flag state:** every feature flag the outcome depends on, with its value for this tenant. "Flag `bulk-export` on for tenant harbour-uat". A result recorded without it cannot be reproduced.

## 6. Results and evidence

Exactly one of: **Pass**, **Fail**, **Blocked** (reason required: "tenant B fixtures not loaded"), **Not run** (reason optional). Blocked and Not run never count as passed; `uat-plan`'s exit criteria treat them as failing until the scenario is run.

Each run line records: result, tester (name and role), date, environment, flag state, and evidence (screenshot or recording reference). A re-run adds a new run line; it never overwrites the first.

## 7. When a scenario fails

1. Record **Fail** and what was seen instead of the expected outcome, in the tester's words.
2. Open a `feedback-template` record. Put its ID on the run line.
3. Severity is the business impact, on `feedback-template`'s scale, set now from what was seen. Priority (fix urgency) is a separate field. Neither is lowered later to make the numbers work.
4. Write a **workaround** a business user could follow, or "none". A conditional sign-off needs one for each open High.
5. When a fix is deployed, re-run the scenario: a new run line with `Re-test of: <date of the failed run>`, and re-check the scenarios next to it (same screen, same data). Only a passing re-run closes the defect.

What an open defect allows at sign-off is decided by the single rule in `acceptance-sign-off`. Do not write a defect bar into a scenario file. When the product owner asks ("can we still sign off with this High open?"), read that rule and answer with all of it, every severity it covers, not only the one asked about, and say that `acceptance-sign-off` is where it lives.

## 8. Findings outside the scenario

A scripted scenario checks what was specified (Crispin and Gregory). When the tester notices something outside the scenario's Context (a typo on another screen, a slow page, a crash in a different flow):

- Log it as its own `feedback-template` item.
- List its ID under **Found outside this scenario** on the run line.
- Leave this scenario's result as what the scenario itself showed.

Looking for problems nobody specified is exploratory testing, planned and chartered in `uat-plan`, and done by a human (Hendrickson). An agent drafts charters; it does not run them.
